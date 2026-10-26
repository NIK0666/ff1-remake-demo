class_name BattleUnit
extends RefCounted
## One combatant. Hero HP, equipment, rows and spell charges always come from
## GameState; only enemy HP/charges and transient visual state live here.

var is_hero: bool = false
var member_id: String = ""
var enemy_key: String = ""
var enemy_data: Dictionary = {}
var name_suffix: String = ""
var enemy_hp: int = 0
var enemy_charges: Dictionary = {}
var visual: CharacterVisual
var base_position: Vector3 = Vector3.ZERO
var formation_slot: Vector3 = Vector3.ZERO


static func make_hero(hero_id: String) -> BattleUnit:
	var unit := BattleUnit.new()
	unit.is_hero = true
	unit.member_id = hero_id
	return unit


static func make_enemy(template_key: String, template: Dictionary) -> BattleUnit:
	var unit := BattleUnit.new()
	unit.is_hero = false
	unit.enemy_key = template_key
	unit.enemy_data = template.duplicate(true)
	unit.enemy_hp = int(template.get("max_hp", 1))
	var slots: Dictionary = template.get("spell_slots", {})
	for school: Variant in slots.keys():
		var levels: Dictionary = slots[school]
		var copied: Dictionary = {}
		for level: Variant in levels.keys():
			copied[str(level)] = int(levels[level])
		unit.enemy_charges[str(school)] = copied
	return unit


func id_key() -> String:
	return member_id if is_hero else enemy_key


func display_name() -> String:
	if is_hero:
		return str(GameState.member_by_id(member_id).get("name", member_id))
	return str(enemy_data.get("name", enemy_key)) + name_suffix


func class_display() -> String:
	if is_hero:
		return str(GameState.member_by_id(member_id).get("class_name", ""))
	return "ВРАГ"


func row() -> String:
	if is_hero:
		return GameState.get_member_row(member_id)
	return str(enemy_data.get("row", "front"))


func row_label() -> String:
	var ui: Dictionary = GameState.combat.get("ui", {})
	return str(ui.get("back" if row() == "back" else "front", "ЗАДНИЙ" if row() == "back" else "ПЕРЕДНИЙ"))


func max_hp() -> int:
	if is_hero:
		return int(GameState.member_by_id(member_id).get("max_hp", 1))
	return int(enemy_data.get("max_hp", 1))


func hp() -> int:
	if is_hero:
		return int(GameState.member_by_id(member_id).get("hp", 0))
	return enemy_hp


func is_alive() -> bool:
	if is_hero:
		return not GameState.is_member_lost(GameState.member_by_id(member_id))
	return enemy_hp > 0


func stats() -> Dictionary:
	if is_hero:
		return GameState.get_effective_stats(member_id)
	var raw: Dictionary = enemy_data.get("stats", {})
	return {
		"attack": int(raw.get("attack", 0)),
		"defense": int(raw.get("defense", 0)),
		"agility": int(raw.get("agility", 0)),
		"magic": int(raw.get("magic", 0))
	}


func agility() -> int:
	return int(stats().get("agility", 0))


func spells() -> Array[String]:
	var result: Array[String] = []
	var raw: Array = GameState.member_by_id(member_id).get("spells", []) if is_hero else enemy_data.get("spells", [])
	for spell_id: Variant in raw:
		result.append(str(spell_id))
	return result


func charge(school: String, level: int) -> int:
	if is_hero:
		return GameState.get_spell_charges(member_id, school, level)
	var levels: Dictionary = enemy_charges.get(school, {})
	return int(levels.get(str(level), 0))


func max_charge(school: String, level: int) -> int:
	var slots: Dictionary = GameState.member_by_id(member_id).get("spell_slots", {}) if is_hero else enemy_data.get("spell_slots", {})
	var levels: Dictionary = slots.get(school, {})
	return int(levels.get(str(level), 0))


func consume_charge(school: String, level: int) -> bool:
	if is_hero:
		return GameState.consume_spell_charge(member_id, school, level)
	var levels: Dictionary = enemy_charges.get(school, {})
	var current := int(levels.get(str(level), 0))
	if current <= 0:
		return false
	levels[str(level)] = current - 1
	enemy_charges[school] = levels
	return true


func castable_spells() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for spell_id: String in spells():
		var spell := GameState.get_spell(spell_id)
		if spell.is_empty():
			continue
		var school := str(spell.get("school", "white"))
		var level := int(spell.get("level", 1))
		if charge(school, level) <= 0:
			continue
		var entry := spell.duplicate(true)
		entry["id"] = spell_id
		entry["charges"] = charge(school, level)
		entry["max_charges"] = max_charge(school, level)
		result.append(entry)
	return result


func take_damage(amount: int) -> int:
	var damage := maxi(0, amount)
	if is_hero:
		return GameState.damage_member(member_id, damage)
	var before := enemy_hp
	enemy_hp = maxi(0, enemy_hp - damage)
	return before - enemy_hp


func heal(amount: int) -> int:
	var value := maxi(0, amount)
	if is_hero:
		return GameState.heal_member(member_id, value)
	var before := enemy_hp
	enemy_hp = mini(max_hp(), enemy_hp + value)
	return enemy_hp - before


func xp_reward() -> int:
	return 0 if is_hero else int(enemy_data.get("xp", 0))


func gold_reward() -> int:
	return 0 if is_hero else int(enemy_data.get("gold", 0))
