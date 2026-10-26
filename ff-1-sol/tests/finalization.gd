extends RefCounted
var flow
var game
var model
var cfg: Dictionary

func _check(ok: bool, message: String) -> void:
	flow._check(ok, message)

func _idle() -> void:
	await game.get_tree().process_frame
	while is_instance_valid(game.battle_scene) and game.battle_scene.busy:
		await game.get_tree().process_frame

func _capture_now(label: String) -> void:
	if not flow.screenshots:
		return
	await RenderingServer.frame_post_draw
	_check(game.get_viewport().get_texture().get_image().save_png("res://docs/" + label + ".png") == OK, "Screenshot: " + label)

func _counts() -> Dictionary:
	var result: Dictionary = GameState.session.inventory.duplicate()
	for hero in GameState.session.heroes:
		for id in hero.equipment.values():
			if not id.is_empty():
				result[id] = int(result.get(id, GameState.rules.n.zero)) + int(GameState.rules.n.one)
	return result

func before_rescue(driver: Node) -> void:
	flow = driver
	game = flow.game
	model = GameState.battle_system
	cfg = GameState.polish.test
	GameState.session.encounters_enabled = false
	var saved_heroes: Array = GameState.session.heroes.duplicate(true)
	var saved_bag: Dictionary = GameState.session.inventory.duplicate(true)
	var saved_gold: int = GameState.session.gold
	game.start_ending()
	_check(not is_instance_valid(game.ending_scene) and not GameState.session.quest.demo_complete, "Ending cannot start before Sarah rescue and royal thanks")
	var mage := GameState.hero("white_mage")
	mage.hp = int(GameState.rules.n.zero)
	game._process(GameState.rules.n.zero)
	_check(game.actors.back().get_node("FallenMarker").visible, "Fallen world hero has explicit marker and spectral appearance")
	mage.hp = mage.max_hp
	game._process(GameState.rules.n.zero)
	_check(not game.actors.back().get_node("FallenMarker").visible, "Restored hero loses fallen marker")
	for item in cfg.gear:
		GameState.session.inventory[item] = GameState.owned(item) + int(GameState.rules.n.one)
	var gear = game.hud.gear
	gear.open_equipment()
	gear.select_hero("warrior")
	gear.set_mode("weapon")
	var old_weapon: String = GameState.hero("warrior").equipment.weapon
	gear.activate()
	_check(GameState.hero("warrior").equipment.weapon == old_weapon and gear.action_button.disabled, "Opening equipment cannot accidentally remove a worn item")
	var counts := _counts()
	gear.best_button.pressed.emit()
	_check(GameState.hero("warrior").equipment.weapon == "longsword" and GameState.hero("warrior").equipment.armor == "chain", "Best-equipment button equips stronger compatible bag items")
	_check(_counts() == counts, "Quick equipment conserves every bag and worn item")
	var optimized: Dictionary = GameState.hero("warrior").equipment.duplicate()
	gear.best_button.pressed.emit()
	_check(GameState.hero("warrior").equipment == optimized and _counts() == counts, "Repeated best-equipment click never downgrades or duplicates items")
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_3
	gear.handle_event(key)
	_check(gear.member_id == "monk", "Equipment keyboard shortcut selects the third hero")
	gear.select_hero("warrior")
	gear.select_entry("dagger")
	await flow._capture("equipment_polished")
	gear.close()
	await flow._walk_to(GameState.cell(GameState.combat.test.bridge_entry))
	for hero in GameState.session.heroes:
		hero.hp = int(hero.max_hp)
		hero.charges = GameState.combat.classes[hero.id].charges.duplicate(true)
	GameState.session.inventory.potion = int(cfg.potions)
	game.start_battle(cfg.formation)
	await _idle()
	var scene = game.battle_scene
	var attacker: String = model.current()
	var target: String = model.living(false).front()
	var hp: int = model.unit(target).hp
	var duration: float = GameState.polish.battle.test_seconds
	if flow.screenshots:
		GameState.polish.battle.test_seconds = cfg.effect_capture_seconds
	scene.ui.target_buttons[target].pressed.emit()
	_check(scene.busy and scene.active_actor() == attacker and model.current() != attacker, "Animation highlights its actual actor after logical queue advances")
	await scene.action_impact
	var event: Dictionary = model.state().last_action
	_check(event.actor == attacker and event.effects.front().id == target and event.effects.front().amount == hp - model.unit(target).hp, "Damage event reports actual actor, target and HP lost")
	_check(not scene.effect_nodes.is_empty() and attacker == scene.display_actor, "Impact shows floating number and action effects for the acting unit")
	await _capture_now("battle_action")
	await _idle()
	GameState.polish.battle.test_seconds = duration
	var victim := GameState.hero("warrior")
	victim.hp = int(GameState.rules.n.one)
	var enemy: String = model.living(false).front()
	model.state().cursor = model.state().queue.find(enemy)
	scene.busy = true
	scene.display_actor = enemy
	scene.impact_done = false
	_check(model.act("attack", "", victim.id).ok, "A real enemy attack can fell the prepared injured hero")
	await scene._animate(model.state().last_action)
	scene.busy = false
	scene.display_actor = ""
	scene.refresh_view()
	_check(victim.hp == GameState.rules.n.zero, "Enemy damage reduces the injured hero to zero HP")
	_check(scene.actors[victim.id].visible, "Fallen hero remains visible in the formation")
	_check(absf(scene.actors[victim.id].rotation_degrees.x - GameState.polish.actor.fall_angle) < GameState.rules.test.position_tolerance and scene.actors[victim.id].scale.distance_to(Vector3.ONE * GameState.polish.battle.actor_scale) < GameState.rules.test.position_tolerance, "Fallen hero lies down at full model scale: " + str(scene.actors[victim.id].rotation_degrees.x))
	_check("ПАЛ" in scene.labels[victim.id].text, "Fallen battle hero has an explicit status label")
	await flow._capture("battle_fallen")
	model.state().cursor = model.state().queue.find("white_mage")
	scene.refresh_view()
	await scene.player_action("spell", "revive", victim.id)
	_check(victim.hp > GameState.rules.n.zero and scene.actors[victim.id].rotation.x == GameState.rules.n.zero, "Revive restores the fallen model's upright pose")
	model.state().cursor = model.state().queue.find("white_mage")
	scene.refresh_view()
	if flow.screenshots:
		GameState.polish.battle.test_seconds = cfg.effect_capture_seconds
	scene.player_action("spell", "cure", victim.id)
	await scene.action_impact
	_check(model.state().last_action.effects.front().kind == "heal", "Healing has its own presentation event")
	await _capture_now("battle_healing")
	await _idle()
	GameState.polish.battle.test_seconds = duration
	model.state().cursor = model.state().queue.find("thief")
	GameState.hero("thief").charges["1"] = int(GameState.rules.n.zero)
	scene.refresh_view()
	scene.ui.choose_command("spell")
	_check(scene.ui.option_buttons.fire.disabled, "Exhausted spell is visibly disabled in the command menu")
	scene.ui.choose_command("item")
	GameState.hero("white_mage").hp = GameState.hero("white_mage").max_hp
	scene.ui.refresh()
	_check(scene.ui.target_buttons.white_mage.disabled, "Potion menu disables fully healed targets")
	var constants: Dictionary = GameState.combat.formulas.escape.constants.duplicate()
	GameState.combat.formulas.escape.constants.min_chance = GameState.rules.n.one
	GameState.combat.formulas.escape.constants.max_chance = GameState.rules.n.one
	await scene.player_action("escape")
	var hidden := true
	for label in scene.labels.values():
		hidden = hidden and not label.visible
	_check(hidden, "Model name labels cannot overlap the battle result panel")
	scene.ui.result_button.pressed.emit()
	GameState.combat.formulas.escape.constants = constants
	for saved in saved_heroes:
		var hero := GameState.hero(saved.id)
		hero.clear()
		hero.merge(saved)
	GameState.session.inventory.clear()
	GameState.session.inventory.merge(saved_bag)
	GameState.session.gold = saved_gold
	game._load_location("town", GameState.session.checkpoint.spawn, "", GameState.session.checkpoint.facing)
	_check(flow._same_party(), "Equipment and battle presentation keep all original hero nodes")
	await flow._walk_to(GameState.cell(GameState.map.town.houses[int(GameState.rules.n.one)].door))
	_check(game.world.has_node("SideCabinet") and not game.world.can_walk(GameState.cell(cfg.side_blocked_cell)), "House side obstacle has matching visible furniture")
	await flow._capture("weapon_interior")
	await flow._walk_to(GameState.cell(GameState.map.house.portals.front().cell))

func after_rescue() -> void:
	_check(is_instance_valid(game.ending_scene), "Closing the rescued-Sarah king dialogue automatically starts construction")
	if not is_instance_valid(game.ending_scene):
		return
	var scene = game.ending_scene
	var gold: int = GameState.session.gold
	var bag: Dictionary = GameState.session.inventory.duplicate(true)
	_check(not await game.request_step(Vector2i.RIGHT) and game.story_busy, "Construction scene blocks world movement")
	game.start_battle(GameState.combat.test.weak_formation)
	_check(not GameState.in_battle(), "Construction scene blocks battle entry")
	_check(scene.workers.size() == int(cfg.worker_count) and scene.camera.current and not game.hud.visible, "Construction uses four animated workers and a dedicated camera")
	var captured := false
	var frames := int(GameState.rules.n.zero)
	while scene.phase != "complete" and frames < cfg.ending_frame_budget:
		if not captured and scene.phase == "building" and scene.built_segments >= int(GameState.rules.n.two):
			await flow._capture("bridge_building")
			captured = true
		await game.get_tree().process_frame
		frames += int(GameState.rules.n.one)
	_check(scene.phase == "complete" and scene.built_segments == GameState.polish.ending.segments.size(), "Workers finish every bridge span before the final card")
	_check(GameState.session.quest.bridge_built and GameState.session.quest.demo_complete and scene.ui.continue_button.visible, "Construction ends with Demo Complete screen and persistent completion flags")
	_check(GameState.session.gold == gold and GameState.session.inventory == bag and flow._same_party(), "Ending preserves earned gold, bag and the original party")
	await flow._capture("demo_complete")
	scene.ui.continue_button.pressed.emit()
	_check(not is_instance_valid(game.ending_scene) and game.camera.current and game.world.visible and game.hud.visible and not game.story_busy, "Final card returns cleanly to throne exploration")
	for index in game.actors.size():
		_check(game.actors[index].position == GameState.ground(GameState.session.heroes[index].cell) and game.actors[index].rotation.x == GameState.rules.n.zero, "Ending restores world pose and position: " + GameState.session.heroes[index].id)
	game.interact()
	game.interact()
	_check(not is_instance_valid(game.ending_scene), "Repeat king conversation cannot replay construction")
	await flow._walk_to(GameState.cell(GameState.map.throne.portals.front().cell))
	await flow._walk_to(GameState.cell(GameState.rules.test.bridge_view))
	_check(game.world.bridge_root.get_meta("finished") and not model.encounter(GameState.leader()), "Finished royal bridge persists in town and peaceful epilogue has no random fights")
	await flow._capture("bridge_complete")
