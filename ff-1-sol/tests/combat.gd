extends RefCounted
var flow
var game
var model
var config: Dictionary
var inventory_reference: Dictionary

func run(driver: Node) -> void:
	flow = driver
	game = flow.game
	model = GameState.battle_system
	config = GameState.combat.test
	model.rng.seed = int(config.seed)
	inventory_reference = GameState.session.inventory
	# Resume the actual paid checkpoint created by the service acceptance route.
	var checkpoint := GameState.restore_checkpoint()
	game._load_location("town", checkpoint.spawn, "", checkpoint.facing)
	_check(GameState.session.gold == checkpoint.gold, "Combat preparation starts from paid-night checkpoint")
	await _shop_buy(GameState.rules.test.services.weapon_house, config.equipment_weapon)
	var weapon: Dictionary = GameState.economy.items[config.equipment_weapon]
	var before: Dictionary = GameState.stats("warrior")
	_check(not GameState.equip("white_mage", config.equipment_weapon).ok and GameState.owned(config.equipment_weapon) == int(GameState.rules.n.one), "Incompatible class cannot consume equipment")
	var gear = game.hud.gear
	gear.open_equipment()
	gear.select_hero("warrior")
	gear.rows[config.equipment_weapon].pressed.emit()
	_check(GameState.stats("warrior") == before, "Equipment preview does not alter actual stats")
	gear.action_button.pressed.emit()
	_check(gear.result_ok and GameState.owned(config.equipment_weapon) == int(GameState.rules.n.zero), "Equipping takes one real item from the shared bag")
	_check(GameState.stats("warrior").attack == before.attack + int(weapon.equipment.stats.attack), "Equipped weapon increases effective attack")
	_check(not GameState.sell_item(config.equipment_weapon).ok, "Equipped item cannot also be sold from the bag")
	gear.select_entry("__empty")
	gear.action_button.pressed.emit()
	_check(GameState.stats("warrior") == before and GameState.owned(config.equipment_weapon) == int(GameState.rules.n.one), "Unequipping restores both bag quantity and base stats")
	gear.select_entry(config.equipment_weapon)
	gear.action_button.pressed.emit()
	gear.close()
	await _leave()
	await _shop_buy(GameState.rules.test.services.armor_house, config.equipment_armor)
	var defense_before: int = GameState.stats("warrior").defense
	gear.open_equipment()
	gear.set_mode("armor")
	gear.select_entry(config.equipment_armor)
	gear.action_button.pressed.emit()
	_check(GameState.stats("warrior").defense == defense_before + int(GameState.economy.items[config.equipment_armor].equipment.stats.defense), "Armor increases effective defense")
	gear.row_button.pressed.emit()
	_check(GameState.hero("warrior").row == "back", "Equipment UI changes the individual row")
	await flow._capture("equipment")
	gear.row_button.pressed.emit()
	gear.close()
	await _leave()
	_unit_rules()

	await flow._walk_to(GameState.cell(config.bridge_approach))
	GameState.session.encounters_enabled = true
	var chance: float = GameState.combat.encounters.chance
	var formations: Array = GameState.combat.encounters.formations.duplicate(true)
	GameState.session.encounter_cooldown = int(GameState.rules.n.zero)
	GameState.combat.encounters.chance = GameState.rules.n.zero
	_check(not model.encounter(GameState.cell(config.bridge_entry)), "Zero encounter chance does not launch a battle")
	GameState.combat.encounters.chance = GameState.rules.n.one
	_check(not model.encounter(GameState.cell(GameState.map.town.spawn)), "Encounter rolls cannot start fights outside the bridge")
	GameState.combat.encounters.formations = [config.win_formation]
	var original_cell := GameState.leader()
	await game.request_step(Vector2i.UP)
	GameState.combat.encounters.chance = chance
	GameState.combat.encounters.formations = formations
	GameState.session.encounters_enabled = false
	_check(GameState.in_battle() and is_instance_valid(game.battle_scene), "A real successful bridge step loads separate battle scene")
	await _idle()
	_check(game.battle_scene.has_node("SameCorneliaBridge") and game.battle_scene.camera.current, "Battle uses the same 3D bridge and its own overhead camera")
	_check(not game.world.visible and not game.hud.visible, "Battle suspends town presentation")
	_check(flow._same_party(), "Four original hero nodes enter the battle")
	var leftmost_hero: float = INF
	var rightmost_enemy: float = -INF
	for member in GameState.session.heroes:
		leftmost_hero = minf(leftmost_hero, game.battle_scene.camera.unproject_position(game.battle_scene.actors[member.id].global_position).x)
	for enemy in model.state().enemies:
		rightmost_enemy = maxf(rightmost_enemy, game.battle_scene.camera.unproject_position(game.battle_scene.actors[enemy.id].global_position).x)
	_check(leftmost_hero > rightmost_enemy, "On-screen party is right of all enemies")
	_check(not await game.request_step(Vector2i.DOWN), "World movement is blocked during battle")
	_check(not GameState.toggle_row("warrior").ok and not GameState.equip("warrior", "", "weapon").ok, "Free row and equipment changes are blocked during combat")
	await flow._capture("battle")
	game.battle_scene.ui.choose_command("spell")
	_check(game.battle_scene.ui.option_buttons.has("fire"), "Black magic is available to the thief in command UI")
	await flow._capture("battle_magic")
	var black_charge: int = GameState.hero(config.spell_caster).charges["1"]
	game.battle_scene.ui.target_buttons[model.living(false).front()].pressed.emit()
	await _idle()
	_check(GameState.hero(config.spell_caster).charges["1"] == black_charge - int(GameState.rules.n.one), "Magic target button spends a real level charge in the scene")
	var member := GameState.hero("warrior")
	member.hp -= int(config.injury)
	var wounded := int(member.hp)
	var potion_before := GameState.owned(config.potion)
	game.battle_scene.ui.command_buttons.item.pressed.emit()
	game.battle_scene.ui.option_buttons[config.potion].pressed.emit()
	game.battle_scene.ui.target_buttons[member.id].pressed.emit()
	await _idle()
	_check(GameState.owned(config.potion) == potion_before - int(GameState.rules.n.one), "Battle potion consumes exactly one shared inventory item")
	_check(member.hp > wounded, "Potion restores HP through the actual battle controller")
	var empty_turn: int = model.state().cursor
	_check(not model.act("item", config.potion, member.id).ok and model.state().cursor == empty_turn, "Empty potion stock cannot heal or consume the turn")
	var gold_before: int = GameState.session.gold
	var experience_before: int = GameState.hero("warrior").experience
	await _win(true)
	_check(model.state().result == "victory", "Combat attacks and enemy AI produce a real victory")
	var reward_gold := int(model.state().reward_gold)
	_check(reward_gold > GameState.rules.n.zero and GameState.session.gold == gold_before + reward_gold, "Victory credits actual encounter gold")
	_check(GameState.hero("warrior").experience > experience_before, "Survivors gain experience")
	var rewarded: int = GameState.session.gold
	model._check_outcome()
	_check(GameState.session.gold == rewarded, "Rechecking victory cannot award rewards twice")
	await flow._capture("battle_victory")
	game.battle_scene.ui.result_button.pressed.emit()
	_check(not GameState.in_battle() and GameState.leader() == original_cell + Vector2i.UP, "Victory returns to the same bridge tile")
	_check(GameState.owned(config.potion) == int(GameState.rules.n.zero), "Spent potion stays spent after battle")
	_check(GameState.hero(config.spell_caster).charges["1"] < GameState.combat.classes[config.spell_caster].charges["1"] and GameState.hero(config.white_caster).charges["1"] < GameState.combat.classes[config.white_caster].charges["1"], "White and black charges remain spent after returning to the bridge")
	_check(GameState.session.encounter_cooldown > GameState.rules.n.zero, "Battle exit gives encounter grace steps")
	_check(flow._same_party() and is_same(inventory_reference, GameState.session.inventory), "Battle preserves party and bag object identities")
	var level_before: int = GameState.hero("warrior").level
	var attack_before: int = GameState.stats("warrior").attack
	GameState.grant_experience(int(GameState.combat.levels[int(GameState.rules.n.one)]))
	_check(GameState.hero("warrior").level > level_before and GameState.stats("warrior").attack > attack_before, "JSON experience thresholds produce level and stat growth")

	await _enter(GameState.rules.test.services.inn_house)
	game.hud.service.action_button.pressed.emit()
	_check(game.hud.service.result_ok, "Real victory proceeds into another paid night")
	var paid_checkpoint: Dictionary = GameState.session.checkpoint.duplicate(true)
	_check(GameState.hero("thief").charges == GameState.combat.classes.thief.charges, "Night refills black-magic charges")
	_check(GameState.hero("white_mage").charges == GameState.combat.classes.white_mage.charges, "Night refills white-magic charges")
	await _leave()
	# Change real gear and inventory after the checkpoint; death must undo them.
	GameState.equip("warrior", "", "weapon")
	GameState.equip("warrior", "", "armor")
	await _enter(GameState.rules.test.services.weapon_house)
	GameState.sell_item(config.equipment_weapon)
	await _leave()
	await _enter(GameState.rules.test.services.armor_house)
	GameState.sell_item(config.equipment_armor)
	await _leave()
	await _shop_buy(GameState.rules.test.services.item_house, config.potion)
	await _leave()
	await flow._walk_to(GameState.cell(config.bridge_entry))
	game.start_battle(config.win_formation)
	await _idle()
	var escape_constants: Dictionary = GameState.combat.formulas.escape.constants.duplicate()
	GameState.combat.formulas.escape.constants.min_chance = GameState.rules.n.one
	GameState.combat.formulas.escape.constants.max_chance = GameState.rules.n.one
	var flee_gold: int = GameState.session.gold
	var flee_xp: int = GameState.hero("warrior").experience
	await game.battle_scene.player_action("escape")
	_check(model.state().result == "escape" and GameState.session.gold == flee_gold and GameState.hero("warrior").experience == flee_xp, "Successful escape gives neither gold nor experience")
	game.battle_scene.ui.result_button.pressed.emit()
	GameState.combat.formulas.escape.constants = escape_constants

	game.start_battle(config.win_formation)
	await _idle()
	for hero in GameState.session.heroes:
		hero.hp = int(GameState.rules.n.one)
	for enemy in model.state().enemies:
		enemy.hp = int(config.lethal_hp)
		enemy.max_hp = int(config.lethal_hp)
		enemy.attack = int(config.lethal_attack)
	await _win()
	_check(model.state().result == "defeat", "Enemy damage to all heroes produces party defeat")
	_check(model.state().reward_gold == GameState.rules.n.zero and model.state().reward_experience == GameState.rules.n.zero, "Defeat awards no rewards")
	await flow._capture("battle_defeat")
	_check(GameState.hero("warrior").hp == GameState.rules.n.zero, "Defeat screen waits for confirmation before restoring checkpoint")
	game.battle_scene.ui.result_button.pressed.emit()
	_check(not GameState.in_battle() and GameState.leader() == paid_checkpoint.spawn, "Defeat returns to last paid-night position")
	_check(GameState.session.gold == paid_checkpoint.gold and GameState.session.inventory == paid_checkpoint.inventory, "Defeat restores checkpoint gold and bag")
	for saved in paid_checkpoint.heroes:
		var restored := GameState.hero(saved.id)
		_check(restored.hp == saved.hp and restored.charges == saved.charges and restored.equipment == saved.equipment and restored.experience == saved.experience, "Checkpoint restores HP, charges, equipment and experience: " + saved.id)
	_check(flow._same_party() and is_same(inventory_reference, GameState.session.inventory), "Defeat restoration keeps all original party state objects")
	_check(game.camera.current and game.world.visible and game.hud.visible, "World camera and HUD return after defeat")
	await flow._capture("battle_return")
	GameState.session.encounters_enabled = true

func _unit_rules() -> void:
	model.start(config.weak_formation)
	var enemy_id: String = model.state().enemies.front().id
	var order: Array = model.state().queue
	var previous: float = INF
	for id in order:
		_check(model.effective(id).agility <= previous, "Initiative queue descends by effective agility: " + id)
		previous = model.effective(id).agility
	var outgoing: int = model.physical_damage("warrior", enemy_id, GameState.rules.n.one)
	var incoming: int = model.physical_damage(enemy_id, "warrior", GameState.rules.n.one)
	model.state().active = false
	GameState.toggle_row("warrior")
	model.start(config.weak_formation)
	enemy_id = model.state().enemies.front().id
	_check(model.physical_damage("warrior", enemy_id, GameState.rules.n.one) < outgoing, "Back row lowers outgoing melee damage")
	_check(model.physical_damage(enemy_id, "warrior", GameState.rules.n.one) < incoming, "Back row lowers incoming melee damage")
	var expression: String = GameState.combat.formulas.physical.expression
	GameState.combat.formulas.physical.expression = "attack"
	GameState.formula_cache.erase("physical")
	_check(model.physical_damage("warrior", enemy_id, GameState.rules.n.one) == GameState.stats("warrior").attack, "Changing JSON formula changes the calculation itself")
	GameState.combat.formulas.physical.expression = expression
	GameState.formula_cache.erase("physical")
	model.state().active = false
	GameState.toggle_row("warrior")
	model.start(config.weak_formation)
	var caster := GameState.hero(config.spell_caster)
	var first_level: int = caster.charges["1"]
	var second_level: int = caster.charges["2"]
	var target: String = model.state().enemies.front().id
	_check(model.act("spell", "fire", target).ok, "Known black spell resolves")
	_check(caster.charges["1"] == first_level - int(GameState.rules.n.one) and caster.charges["2"] == second_level, "Magic consumes only a charge of its own level")
	model.state().cursor = model.state().queue.find(config.spell_caster)
	caster.charges["1"] = int(GameState.rules.n.zero)
	var before_hp: int = model.unit(target).hp
	var before_turn: int = model.state().cursor
	_check(not model.act("spell", "fire", target).ok and model.unit(target).hp == before_hp and model.state().cursor == before_turn, "Exhausted charge refuses without damage or losing the turn")
	model.state().cursor = model.state().queue.find(config.white_caster)
	var white := GameState.hero(config.white_caster)
	var saved_hp: int = GameState.hero("warrior").hp
	GameState.hero("warrior").hp -= int(config.injury)
	var white_charge: int = white.charges["1"]
	_check(model.act("spell", "cure", "warrior").ok and white.charges["1"] == white_charge - int(GameState.rules.n.one) and GameState.hero("warrior").hp > saved_hp - int(config.injury), "White healing uses a level charge and restores HP")
	model.state().cursor = model.state().queue.find(config.white_caster)
	GameState.hero("monk").hp = int(GameState.rules.n.zero)
	_check(model.act("spell", "revive", "monk").ok and GameState.hero("monk").hp > GameState.rules.n.zero, "White resurrection targets a lost hero")
	model.state().cursor = model.state().queue.find(config.white_caster)
	var defense_before: int = model.effective("warrior").defense
	var shared_charge: int = white.charges["1"]
	_check(model.act("spell", "protect", "warrior").ok and model.effective("warrior").defense > defense_before and white.charges["1"] == shared_charge - int(GameState.rules.n.one), "Protection increases defense and shares the healing spell's level pool")
	model.state().active = false
	model.start(config.win_formation)
	var frost_caster := GameState.hero(config.spell_caster)
	var frost_charge: int = frost_caster.charges["2"]
	_check(model.act("spell", "frost", "all").ok and frost_caster.charges["2"] == frost_charge - int(GameState.rules.n.one), "Area spell spends one charge for all targets")
	var all_hurt := true
	for enemy in model.state().enemies:
		all_hurt = all_hurt and enemy.hp < enemy.max_hp
	_check(all_hurt, "Area spell actually damages every living enemy")
	model.state().active = false
	var magic_hits: Array[int] = []
	for row in ["front", "back"]:
		var thief := GameState.hero(config.spell_caster)
		thief.row = row
		thief.charges = GameState.combat.classes[thief.id].charges.duplicate(true)
		model.start(config.weak_formation)
		model.rng.seed = int(config.seed)
		var enemy: Dictionary = model.state().enemies.front()
		var before: int = enemy.hp
		model.act("spell", "fire", enemy.id)
		magic_hits.append(before - int(enemy.hp))
		model.state().active = false
	_check(magic_hits.front() == magic_hits.back(), "Rows do not weaken magic damage")
	GameState.hero(config.spell_caster).row = GameState.combat.classes[config.spell_caster].row
	model.start(config.formation)
	model.state().cursor = model.state().queue.find("enemy_1")
	var shaman: Dictionary = model.unit("enemy_1")
	var enemy_charge: int = shaman.charges["1"]
	var party_hp: int = int(GameState.rules.n.zero)
	for hero in GameState.session.heroes:
		party_hp += int(hero.hp)
	_check(model.enemy_turn().ok and shaman.charges["1"] == enemy_charge - int(GameState.rules.n.one), "Enemy spell AI uses its own level charges")
	var after_enemy_hp: int = int(GameState.rules.n.zero)
	for hero in GameState.session.heroes:
		after_enemy_hp += int(hero.hp)
	_check(after_enemy_hp < party_hp, "Enemy magic applies real damage to the party")
	model.state().active = false
	for hero in GameState.session.heroes:
		hero.hp = hero.max_hp
		hero.charges = GameState.combat.classes[hero.id].charges.duplicate(true)
	model.start(config.weak_formation)
	var escape_constants: Dictionary = GameState.combat.formulas.escape.constants.duplicate()
	GameState.combat.formulas.escape.constants.min_chance = GameState.rules.n.zero
	GameState.combat.formulas.escape.constants.max_chance = GameState.rules.n.zero
	var current: String = model.current()
	_check(model.act("escape").ok and model.state().phase == "turn" and model.current() != current, "Failed escape spends the active hero's turn")
	GameState.combat.formulas.escape.constants = escape_constants
	model.state().active = false

func _enter(id: String) -> void:
	for house in GameState.map.town.houses:
		if house.id == id:
			await flow._walk_to(GameState.cell(house.door))
			break
	game.interact()

func _shop_buy(house: String, item: String) -> void:
	await _enter(house)
	game.hud.service.rows[item].pressed.emit()
	game.hud.service.action_button.pressed.emit()
	_check(game.hud.service.result_ok, "Buy combat preparation item through shop UI: " + item)
	game.hud.service.close()

func _leave() -> void:
	game.hud.service.close()
	game.hud.gear.close()
	await flow._walk_to(GameState.cell(GameState.map.house.portals.front().cell))

func _idle() -> void:
	await game.get_tree().process_frame
	while is_instance_valid(game.battle_scene) and game.battle_scene.busy:
		await game.get_tree().process_frame

func _win(use_magic: bool = false) -> void:
	var turns := int(GameState.rules.n.zero)
	while model.state().phase == "turn" and turns < int(config.round_limit):
		await _idle()
		if model.state().phase != "turn":
			break
		_check(model.unit(model.current()).hp > GameState.rules.n.zero, "Lost combatants are skipped by turn order")
		if use_magic and model.current() == config.white_caster and GameState.hero(config.white_caster).charges["1"] > GameState.rules.n.zero:
			await game.battle_scene.player_action("spell", "protect", "warrior")
		else:
			await game.battle_scene.player_action("attack", "", model.living(false).front())
		turns += int(GameState.rules.n.one)
	_check(model.state().phase == "result", "Battle reaches an outcome within the turn limit")

func _check(condition: bool, text: String) -> void:
	flow._check(condition, text)
