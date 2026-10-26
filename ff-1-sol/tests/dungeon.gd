extends RefCounted
## Complete shrine route through production transitions, interactions and battles.
var flow
var game
var model
var cfg: Dictionary
var captured_entrance := false
var captured_stairs := false

func _check(ok: bool, message: String) -> void:
	flow._check(ok, message)

func _idle() -> void:
	await game.get_tree().process_frame
	while is_instance_valid(game.battle_scene) and game.battle_scene.busy:
		await game.get_tree().process_frame

func _decision() -> Array:
	var actor: String = model.current()
	var living: Array[String] = model.living(true)
	var lowest: String = living.front()
	var injured := int(GameState.rules.n.zero)
	for id in living:
		if float(model.unit(id).hp) / model.unit(id).max_hp < float(model.unit(lowest).hp) / model.unit(lowest).max_hp:
			lowest = id
		if model.unit(id).hp < model.unit(id).max_hp * cfg.heal_fraction:
			injured += int(GameState.rules.n.one)
	if actor == "white_mage":
		if not model.targets("spell", "revive").is_empty() and model.unit(actor).charges["2"] > GameState.rules.n.zero:
			return ["spell", "revive", model.targets("spell", "revive").front()]
		if injured >= GameState.rules.n.two and model.unit(actor).charges["2"] > GameState.rules.n.zero:
			return ["spell", "cura", "all"]
		if injured > GameState.rules.n.zero and model.unit(actor).charges["1"] > GameState.rules.n.zero:
			return ["spell", "cure", lowest]
	if GameState.owned("potion") > GameState.rules.n.zero and model.unit(lowest).hp < model.unit(lowest).max_hp * cfg.potion_fraction:
		return ["item", "potion", lowest]
	if actor == "thief":
		if model.unit(actor).charges["1"] > GameState.rules.n.zero:
			return ["spell", "fire", model.living(false).front()]
		if model.unit(actor).charges["2"] > GameState.rules.n.zero:
			return ["spell", "frost", "all"]
	return ["attack", "", model.living(false).front()]

func _fight() -> void:
	var actions := int(GameState.rules.n.zero)
	await _idle()
	while model.state().phase == "turn" and actions < cfg.max_actions:
		var choice := _decision()
		var result: Dictionary = await game.battle_scene.player_action(choice.front(), choice[int(GameState.rules.n.one)], choice.back())
		_check(result.ok, "Shrine battle command resolves: " + choice.front())
		actions += int(GameState.rules.n.one)
	_check(model.state().phase == "result", "Shrine battle reaches its outcome")

func _balance() -> void:
	var saved_heroes: Array = GameState.session.heroes.duplicate(true)
	var saved_bag: Dictionary = GameState.session.inventory.duplicate(true)
	var saved_gold: int = GameState.session.gold
	var wins: Dictionary = {"bare":int(GameState.rules.n.zero), "equipped":int(GameState.rules.n.zero)}
	for mode in wins:
		for sample in range(int(cfg.balance_seeds)):
			GameState.session.battle = {"active":false}
			GameState.session.inventory.clear()
			GameState.session.inventory.potion = int(cfg.balance_potions)
			for hero in GameState.session.heroes:
				hero.level = int(cfg.balance_level)
				hero.equipment = {"weapon":"", "armor":""}
				hero.row = GameState.combat.classes[hero.id].row
				hero.charges = GameState.combat.classes[hero.id].charges.duplicate(true)
				hero.max_hp = int(GameState.calculate("max_hp", {"base_hp":hero.base_max_hp, "growth":GameState.combat.classes[hero.id].hp_growth, "level":hero.level, "initial_level":GameState.combat.initial_level}))
				hero.hp = hero.max_hp
			if mode == "equipped":
				for entry in cfg.recommended:
					GameState.session.inventory[entry.item] = GameState.owned(entry.item) + int(GameState.rules.n.one)
					GameState.equip(entry.hero, entry.item)
			model.rng.seed = int(cfg.seed) + sample
			model.start(GameState.dungeon.boss.formation, "balance")
			var actions := int(GameState.rules.n.zero)
			while model.state().phase == "turn" and actions < cfg.max_actions:
				if model.is_hero(model.current()):
					var choice := _decision()
					model.act(choice.front(), choice[int(GameState.rules.n.one)], choice.back())
				else:
					model.enemy_turn()
				actions += int(GameState.rules.n.one)
			if model.state().result == "victory":
				wins[mode] += int(GameState.rules.n.one)
			_check(model.state().phase == "result", "Garland balance sample completes: " + mode + " / " + str(sample))
	print("GARLAND BALANCE: level " + str(cfg.balance_level) + "; bare " + str(wins.bare) + "/" + str(cfg.balance_seeds) + "; equipped " + str(wins.equipped) + "/" + str(cfg.balance_seeds))
	_check(wins.equipped >= cfg.required_equipped_wins, "Bought equipment makes Garland consistently beatable at the same level")
	_check(wins.bare <= cfg.max_bare_wins, "Garland is difficult without new equipment at the same level")
	GameState.session.battle = {"active":false}
	for saved in saved_heroes:
		var hero := GameState.hero(saved.id)
		hero.clear()
		hero.merge(saved)
	GameState.session.inventory.clear()
	GameState.session.inventory.merge(saved_bag)
	GameState.session.gold = saved_gold

func _enter_shrine() -> void:
	if not captured_entrance:
		await flow._walk_to(GameState.cell(cfg.entrance_approach))
		await flow._capture("chaos_entrance")
		captured_entrance = true
	await flow._walk_to(GameState.cell(GameState.dungeon.entrance.cell))
	_check(GameState.session.location == "chaos_1", "North-bank entrance loads shrine first floor")
	_check(flow._same_party(), "Original party enters shrine without recreation")
	for hero in GameState.session.heroes:
		_check(game.world.can_walk(hero.cell), "Safe shrine arrival trail: " + hero.id)

func _key_and_stairs() -> void:
	await flow._walk_to(GameState.cell(cfg.chest_approach))
	GameState.session.facing = Vector2i.UP
	var gold: int = GameState.session.gold
	game.interact()
	_check(GameState.owned(GameState.dungeon.chest.item) == int(GameState.rules.n.one) and GameState.session.quest.key_taken, "Chest interaction gives exactly one real key")
	game.interact()
	game.interact()
	_check(GameState.owned(GameState.dungeon.chest.item) == int(GameState.rules.n.one) and GameState.session.gold == gold, "Reopening chest cannot duplicate key or change gold")
	game.interact()
	await flow._capture("chaos_key")
	await flow._walk_to(GameState.cell(cfg.door_approach))
	GameState.session.facing = Vector2i.UP
	game.interact()
	_check(GameState.session.quest.door_open and game.world.can_walk(GameState.cell(GameState.dungeon.door.cell)), "Key interaction opens both visible door and occupancy")
	game.interact()
	if not captured_stairs:
		await flow._walk_to(GameState.cell(cfg.stairs_approach))
		await flow._capture("chaos_stairs")
		captured_stairs = true
	await flow._walk_to(GameState.cell(cfg.stairs_up))
	_check(GameState.session.location == "chaos_2", "First-floor staircase loads the second floor")
	for hero in GameState.session.heroes:
		_check(game.world.can_walk(hero.cell), "Safe stair arrival trail: " + hero.id)

func run(driver: Node) -> void:
	flow = driver
	game = flow.game
	model = GameState.battle_system
	cfg = GameState.dungeon.test
	GameState.session.encounters_enabled = false
	_balance()
	_check(not GameState.open_chaos_chest().ok and not GameState.unlock_chaos_door().ok, "Quest objects cannot be used remotely from town")
	# Earn money using ordinary rewards; buy the stronger blade through the real shop.
	await flow._walk_to(GameState.cell(GameState.combat.test.bridge_entry))
	for fight in range(int(cfg.earn_fights)):
		game.start_battle(cfg.earn_formation)
		await _fight()
		_check(model.state().result == "victory", "Preparatory encounter awards earned shopping money")
		game.battle_scene.ui.result_button.pressed.emit()
	await flow._walk_to(GameState.cell(GameState.map.town.houses[int(GameState.rules.n.one)].door))
	game.interact()
	game.hud.service.select_entry("longsword")
	game.hud.service.action_button.pressed.emit()
	_check(game.hud.service.result_ok, "Stronger blade is bought using encounter gold")
	game.hud.service.close()
	_check(GameState.equip("warrior", "longsword").ok and GameState.equip("thief", "dagger").ok, "Bought blade and previous dagger equip two separate heroes")
	await flow._walk_to(GameState.cell(GameState.map.house.portals.front().cell))
	await flow._walk_to(GameState.cell(GameState.map.town.houses.front().door))
	game.interact()
	game.hud.service.action_button.pressed.emit()
	_check(game.hud.service.result_ok, "Dungeon expedition starts from a real paid night")
	game.hud.service.close()
	await flow._walk_to(GameState.cell(GameState.map.house.portals.front().cell))
	var checkpoint: Dictionary = GameState.session.checkpoint.duplicate(true)
	await _enter_shrine()
	await flow._walk_to(GameState.cell(cfg.door_approach))
	GameState.session.facing = Vector2i.UP
	_check(not await game.request_step(Vector2i.UP), "Key door blocks movement before obtaining key")
	game.interact()
	_check(game.hud.dialog_open and "Нужен ключ" in game.hud.dialog.text and not GameState.session.quest.door_open, "Locked door explains required key without opening")
	await flow._capture("chaos_door_locked")
	game.interact()
	await flow._walk_to(GameState.cell(cfg.view_first))
	await flow._capture("chaos_first")
	await _key_and_stairs()
	await flow._walk_to(GameState.cell(cfg.view_second))
	await flow._capture("chaos_second")
	await flow._walk_to(GameState.cell(cfg.stairs_down))
	_check(GameState.session.location == "chaos_1" and GameState.session.quest.door_open, "Descending staircase preserves unlocked door")
	await flow._walk_to(GameState.cell(GameState.map.chaos_1.portals.front().cell))
	_check(GameState.session.location == "town" and GameState.owned("chaos_key") == int(GameState.rules.n.one), "Dungeon exit retains key in shared town inventory")
	await _enter_shrine()
	_check(game.world.can_walk(GameState.cell(GameState.dungeon.door.cell)), "Reentering reconstructs the already open door")
	await _rare_encounter()
	await flow._walk_to(GameState.cell(cfg.stairs_up))
	# Wipe a prepared injured party to verify rollback of key and door to the inn.
	game.start_battle(GameState.dungeon.boss.formation)
	await _idle()
	for hero in GameState.session.heroes:
		hero.hp = int(GameState.rules.n.one)
	await _fight()
	_check(model.state().result == "defeat", "Shrine defeat uses ordinary enemy damage")
	game.battle_scene.ui.result_button.pressed.emit()
	_check(GameState.session.location == "town" and GameState.leader() == checkpoint.spawn, "Shrine defeat returns to last night in town")
	_check(not GameState.session.quest.key_taken and not GameState.session.quest.door_open and GameState.owned("chaos_key") == int(GameState.rules.n.zero), "Checkpoint restores quest flags and key inventory together")
	_check(GameState.session.gold == checkpoint.gold and not GameState.session.quest.sarah_rescued, "Defeat cannot grant boss rewards or rescue Sarah")
	await _enter_shrine()
	await _key_and_stairs()
	await flow._walk_to(GameState.cell(cfg.boss_approach))
	await game.request_step(Vector2i.UP)
	_check(game.hud.dialog_open and game.hud.dialog.id == "garland", "Approaching Garland starts his introduction")
	_check(not await game.request_step(Vector2i.UP), "Boss introduction blocks world movement")
	game.interact()
	await _idle()
	_check(GameState.in_battle() and model.state().kind == "garland" and game.battle_scene.has_node("ChaosShrineArena"), "Garland introduction loads the shrine boss battle")
	await flow._capture("garland")
	await _fight()
	_check(model.state().result == "victory", "Purchased equipment and normal commands defeat Garland")
	var gold: int = GameState.session.gold
	await flow._capture("garland_victory")
	game.battle_scene.ui.result_button.pressed.emit()
	await game.get_tree().process_frame
	while game.story_busy:
		await game.get_tree().process_frame
	_check(GameState.session.quest.garland_defeated and game.hud.dialog_open and not GameState.session.quest.sarah_rescued, "Boss victory starts Sarah scene before marking rescue complete")
	game.interact()
	_check(game.hud.dialog.id == "sarah" and not GameState.session.quest.sarah_rescued, "Sarah personally thanks the party during the scene")
	await flow._capture("sarah")
	for line in range(GameState.dungeon.story.rescue.size() - int(GameState.rules.n.one)):
		game.interact()
	_check(GameState.session.quest.sarah_rescued and not game.hud.dialog_open, "Sarah is rescued after the complete short scene")
	await flow._walk_to(GameState.cell(cfg.stairs_down))
	await flow._walk_to(GameState.cell(cfg.stairs_up))
	await flow._walk_to(GameState.cell(cfg.boss_trigger))
	_check(not GameState.in_battle() and not game.hud.dialog_open and GameState.session.gold == gold, "Reentering defeated boss chamber does not replay battle or rewards")
	await flow._walk_to(GameState.cell(cfg.sarah_approach))
	game.interact()
	_check(game.hud.dialog_open and game.hud.dialog.id == "sarah" and game.hud.dialog.text == GameState.dungeon.sarah.rescued_text, "Rescued Sarah remains accessible after chamber reentry")
	_check(not game.world.can_walk(GameState.cell(GameState.dungeon.sarah.rescue_cell)), "Rescued Sarah's visible position blocks movement")
	game.interact()
	await flow._walk_to(GameState.cell(cfg.stairs_down))
	await flow._walk_to(GameState.cell(GameState.map.chaos_1.portals.front().cell))
	await flow._walk_to(GameState.cell(GameState.rules.test.castle_door))
	await flow._walk_to(GameState.cell(GameState.rules.test.king_approach))
	game.interact()
	_check(game.hud.dialog.id == "king" and game.hud.dialog.text == GameState.dungeon.story.king_text, "Reentering throne gives the king's new rescue dialogue")
	_check(GameState.session.quest.king_thanked and flow._same_party(), "Rescue quest completes with the four original heroes")
	await flow._capture("king_rescued")
	game.interact()
	GameState.session.encounters_enabled = true

func _rare_encounter() -> void:
	var chance: float = GameState.dungeon.encounters.chance
	_check(chance > GameState.rules.n.zero and chance < GameState.combat.encounters.chance, "Dungeon encounters are rarer than bridge encounters")
	GameState.session.encounters_enabled = true
	GameState.session.encounter_cooldown = int(GameState.rules.n.zero)
	GameState.dungeon.encounters.chance = GameState.rules.n.zero
	_check(not model.encounter(GameState.leader()), "Dungeon zero probability never starts battle")
	GameState.dungeon.encounters.chance = GameState.rules.n.one
	var formations: Array = GameState.dungeon.encounters.formations
	GameState.dungeon.encounters.formations = [GameState.combat.test.weak_formation]
	await game.request_step(Vector2i.UP)
	_check(GameState.in_battle() and model.state().location == "chaos_1", "Successful dungeon step launches random encounter through shared rules")
	await _idle()
	var escape: Dictionary = GameState.combat.formulas.escape.constants.duplicate()
	GameState.combat.formulas.escape.constants.min_chance = GameState.rules.n.one
	GameState.combat.formulas.escape.constants.max_chance = GameState.rules.n.one
	await game.battle_scene.player_action("escape")
	game.battle_scene.ui.result_button.pressed.emit()
	_check(GameState.session.location == "chaos_1" and GameState.session.encounter_cooldown == int(GameState.dungeon.encounters.grace_steps), "Random encounter returns to same dungeon with grace steps")
	GameState.combat.formulas.escape.constants = escape
	GameState.dungeon.encounters.formations = formations
	GameState.dungeon.encounters.chance = chance
	GameState.session.encounters_enabled = false
