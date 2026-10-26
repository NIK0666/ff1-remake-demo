extends RefCounted
## Battle rules mutate only GameState.session; scene nodes never own combat HP.
var rng := RandomNumberGenerator.new()
var pending_event: Dictionary = {}

func encounter(at: Vector2i) -> bool:
	var s: Dictionary = GameState.session
	if s.quest.demo_complete:
		return false
	if not s.encounters_enabled or (s.location != "town" and not s.location.begins_with("chaos_")) or GameState.in_battle():
		return false
	if s.encounter_cooldown > GameState.rules.n.zero:
		s.encounter_cooldown -= int(GameState.rules.n.one)
		return false
	if s.location.begins_with("chaos_"):
		return GameState.inside(at, GameState.map[s.location].encounter_region) and rng.randf() < GameState.dungeon.encounters.chance
	return GameState.inside(at, GameState.combat.encounters.region) and rng.randf() < GameState.combat.encounters.chance

func start(formation: Array = [], kind: String = "") -> void:
	assert(not GameState.in_battle())
	if formation.is_empty():
		var choices: Array = GameState.dungeon.encounters.formations if GameState.session.location.begins_with("chaos_") else GameState.combat.encounters.formations
		formation = choices[rng.randi_range(int(GameState.rules.n.zero), choices.size() - int(GameState.rules.n.one))]
	var enemies: Array = []
	for enemy_kind in formation:
		var enemy: Dictionary = GameState.combat.enemies[enemy_kind].duplicate(true)
		enemy.id = "enemy_" + str(enemies.size())
		enemy.side = "enemy"
		if not enemy.get("boss", false):
			enemy.name += " " + str(enemies.size() + int(GameState.rules.n.one))
		enemies.append(enemy)
	GameState.session.battle = {"active":true, "enemies":enemies, "queue":[], "cursor":int(GameState.rules.n.zero), "round":int(GameState.rules.n.zero), "result":"", "phase":"turn", "log":["На северном мосту появились враги."], "buffs":{}, "reward_gold":int(GameState.rules.n.zero), "reward_experience":int(GameState.rules.n.zero)}
	state().kind = kind
	state().location = GameState.session.location
	state().last_action = {}
	if state().location.begins_with("chaos_"):
		state().log = [GameState.dungeon.boss.text if kind == "garland" else GameState.dungeon.encounters.opening]
	_new_round()
	_check_outcome()

func state() -> Dictionary:
	return GameState.session.battle

func unit(id: String) -> Dictionary:
	var member := GameState.hero(id)
	if not member.is_empty():
		return member
	for enemy in state().get("enemies", []):
		if enemy.id == id:
			return enemy
	return {}

func is_hero(id: String) -> bool:
	return not GameState.hero(id).is_empty()

func effective(id: String) -> Dictionary:
	var result: Dictionary = GameState.stats(id) if is_hero(id) else unit(id).duplicate()
	result.defense += state().get("buffs", {}).get(id, GameState.rules.n.zero)
	return result

func living(heroes: bool) -> Array[String]:
	var result: Array[String] = []
	var group: Array = GameState.session.heroes if heroes else state().enemies
	for actor in group:
		if actor.hp > GameState.rules.n.zero:
			result.append(actor.id)
	return result

func current() -> String:
	if not state().get("active", false) or state().get("phase", "") != "turn" or state().queue.is_empty():
		return ""
	return state().queue[int(state().cursor)]

func _new_round() -> void:
	state().round += int(GameState.rules.n.one)
	var queue: Array[String] = living(true)
	queue.append_array(living(false))
	queue.sort_custom(_faster)
	state().queue = queue
	state().cursor = int(GameState.rules.n.zero)

func _faster(a: String, b: String) -> bool:
	var first: int = effective(a).agility
	var second: int = effective(b).agility
	if first != second:
		return first > second
	if is_hero(a) != is_hero(b):
		return is_hero(a)
	return a < b

func _advance() -> void:
	if state().phase != "turn":
		return
	state().cursor += int(GameState.rules.n.one)
	while state().cursor < state().queue.size():
		if unit(current()).hp > GameState.rules.n.zero:
			return
		state().cursor += int(GameState.rules.n.one)
	_new_round()

func spells(id: String) -> Array:
	return GameState.combat.classes[id].spells if is_hero(id) else unit(id).spells

func targets(command: String, ability: String = "", actor_id: String = "") -> Array[String]:
	if actor_id.is_empty():
		actor_id = current()
	if actor_id.is_empty():
		return []
	var friendly := is_hero(actor_id)
	var kind := "enemy"
	if command == "spell" and GameState.combat.spells.has(ability):
		kind = GameState.combat.spells[ability].target
	elif command == "item" and GameState.combat.items.has(ability):
		kind = GameState.combat.items[ability].target
	if kind == "fallen_ally":
		var result: Array[String] = []
		for member in GameState.session.heroes:
			if member.hp <= GameState.rules.n.zero:
				result.append(member.id)
		return result
	return living(not friendly) if kind in ["enemy", "all_enemies"] else living(friendly)

func physical_damage(attacker: String, defender: String, variance: float) -> int:
	return int(GameState.calculate("physical", {"attack":effective(attacker).attack, "defense":effective(defender).defense, "variance":variance, "outgoing":GameState.combat.rows[unit(attacker).row].outgoing, "incoming":GameState.combat.rows[unit(defender).row].incoming}))

func _variance() -> float:
	return rng.randf_range(GameState.combat.variance.min, GameState.combat.variance.max)

func _log(text: String) -> void:
	state().log.append(text)

func _hit(id: String, damage: int, source: String) -> void:
	var target := unit(id)
	var before := int(target.hp)
	target.hp = maxi(int(GameState.rules.n.zero), int(target.hp) - damage)
	var actual := before - int(target.hp)
	pending_event.effects.append({"id":id, "kind":"damage", "amount":actual, "fell":target.hp <= GameState.rules.n.zero})
	_log(source + " → " + target.name + ": −" + str(actual) + " HP" + (" · пал." if target.hp <= GameState.rules.n.zero else "."))

func _heal(id: String, amount: int, source: String) -> void:
	var target := unit(id)
	var before := int(target.hp)
	target.hp = mini(int(target.max_hp), before + amount)
	pending_event.effects.append({"id":id, "kind":"heal", "amount":int(target.hp) - before, "fell":false})
	_log(source + " → " + target.name + ": +" + str(int(target.hp) - before) + " HP.")

func act(command: String, ability: String = "", target_id: String = "") -> Dictionary:
	var actor_id := current()
	if actor_id.is_empty():
		return GameState._result(false, "Сейчас нет активного хода.")
	var actor := unit(actor_id)
	var names := {"attack":"Атака", "spell":"Магия", "item":"Предмет", "escape":"Бегство"}
	var title: String = names.get(command, command)
	if command == "spell" and GameState.combat.spells.has(ability):
		title = GameState.combat.spells[ability].name
	elif command == "item" and GameState.economy.items.has(ability):
		title = GameState.economy.items[ability].name
	pending_event = {"actor":actor_id, "command":command, "ability":ability, "title":actor.name + " · " + title, "effects":[]}
	var candidates := targets(command, ability, actor_id)
	if command == "escape":
		if not is_hero(actor_id):
			return GameState._result(false, "Враг не может выбрать эту команду.")
		var party_agility: float = GameState.rules.n.zero
		var enemy_agility: float = GameState.rules.n.zero
		for id in living(true):
			party_agility = maxf(party_agility, effective(id).agility)
		for id in living(false):
			enemy_agility = maxf(enemy_agility, effective(id).agility)
		var chance := GameState.calculate("escape", {"party_agility":party_agility, "enemy_agility":enemy_agility})
		if rng.randf() < chance:
			_finish("escape")
		else:
			_log(actor.name + ": не удалось убежать.")
	elif command == "attack":
		if not candidates.has(target_id):
			return GameState._result(false, "Выберите живого врага.")
		_hit(target_id, physical_damage(actor_id, target_id, _variance()), actor.name)
	elif command == "spell":
		if not spells(actor_id).has(ability):
			return GameState._result(false, "Герой не знает этого заклинания.")
		var spell: Dictionary = GameState.combat.spells[ability]
		if int(actor.charges.get(spell.level, GameState.rules.n.zero)) <= GameState.rules.n.zero:
			return GameState._result(false, "Нет зарядов уровня " + spell.level + ". Нужен ночлег.")
		if candidates.is_empty() or (not spell.target.begins_with("all_") and not candidates.has(target_id)):
			return GameState._result(false, "Для этого заклинания нет подходящей цели.")
		actor.charges[spell.level] -= int(GameState.rules.n.one)
		var chosen: Array[String] = []
		if spell.target.begins_with("all_"):
			chosen.assign(candidates)
		else:
			chosen.append(target_id)
		for id in chosen:
			match spell.effect:
				"damage":
					var damage := int(GameState.calculate("magic", {"power":spell.power, "magic":effective(actor_id).magic, "resistance":effective(id).resistance, "variance":_variance()}))
					_hit(id, damage, spell.name)
				"heal":
					_heal(id, int(GameState.calculate("healing", {"power":spell.power, "spirit":effective(actor_id).spirit})), spell.name)
				"guard":
					state().buffs[id] = int(state().buffs.get(id, GameState.rules.n.zero)) + int(spell.power)
					pending_event.effects.append({"id":id, "kind":"guard", "amount":int(spell.power), "fell":false})
					_log(spell.name + ": защита " + unit(id).name + " усилена до конца боя.")
				"revive":
					unit(id).hp = int(GameState.calculate("revive", {"max_hp":unit(id).max_hp, "fraction":spell.fraction}))
					pending_event.effects.append({"id":id, "kind":"revive", "amount":int(unit(id).hp), "fell":false})
					_log(spell.name + ": " + unit(id).name + " снова в строю.")
	elif command == "item":
		if not is_hero(actor_id) or not GameState.combat.items.has(ability) or GameState.owned(ability) <= GameState.rules.n.zero:
			return GameState._result(false, "В сумке нет этого боевого предмета.")
		if not candidates.has(target_id) or unit(target_id).hp >= unit(target_id).max_hp:
			return GameState._result(false, "Выберите живого раненого спутника.")
		var remaining := GameState.owned(ability) - int(GameState.rules.n.one)
		if remaining == int(GameState.rules.n.zero):
			GameState.session.inventory.erase(ability)
		else:
			GameState.session.inventory[ability] = remaining
		_heal(target_id, int(GameState.combat.items[ability].power), GameState.economy.items[ability].name)
	else:
		return GameState._result(false, "Неизвестная команда.")
	_check_outcome()
	_advance()
	state().last_action = pending_event.duplicate(true)
	return GameState._result(true, str(state().log.back()))

func enemy_turn() -> Dictionary:
	var id := current()
	if id.is_empty() or is_hero(id):
		return GameState._result(false, "Сейчас ход партии.")
	var actor := unit(id)
	for spell_id in spells(id):
		var spell: Dictionary = GameState.combat.spells[spell_id]
		if actor.charges.get(spell.level, GameState.rules.n.zero) > GameState.rules.n.zero:
			var choices := targets("spell", spell_id)
			return act("spell", spell_id, choices[rng.randi_range(int(GameState.rules.n.zero), choices.size() - int(GameState.rules.n.one))])
	var choices := targets("attack")
	return act("attack", "", choices[rng.randi_range(int(GameState.rules.n.zero), choices.size() - int(GameState.rules.n.one))])

func _check_outcome() -> void:
	if state().phase != "turn":
		return
	if living(true).is_empty():
		_finish("defeat")
	elif living(false).is_empty():
		_finish("victory")

func _finish(outcome: String) -> void:
	if state().phase == "result":
		return
	state().phase = "result"
	state().result = outcome
	if outcome == "victory":
		var gold := int(GameState.rules.n.zero)
		var experience := int(GameState.rules.n.zero)
		for enemy in state().enemies:
			gold += int(enemy.gold)
			experience += int(enemy.experience)
		experience = int(GameState.calculate("experience", {"total":experience, "survivors":living(true).size()}))
		GameState.session.gold += gold
		GameState.grant_experience(experience)
		state().reward_gold = gold
		state().reward_experience = experience
		_log("Победа! +" + str(gold) + " G; +" + str(experience) + " опыта каждому выжившему.")
	elif outcome == "defeat":
		_log("Партия погибла. Возвращение к последнему ночлегу.")
	else:
		_log("Удалось убежать. Награды за этот бой нет.")
