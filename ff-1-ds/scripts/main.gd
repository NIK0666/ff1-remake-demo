class_name GameMain
extends Node3D
## Orchestrates the persistent party, the swappable location, the HUD and the
## fade-based scene flow. The party node is never freed on a location change.

signal location_loaded(location_id: String)
signal interaction_changed(interactable: Interactable)

const TOWN_SCRIPT := preload("res://scripts/world/town_builder.gd")
const THRONE_SCRIPT := preload("res://scripts/world/throne_room_builder.gd")
const HOUSE_SCRIPT := preload("res://scripts/world/house_interior_builder.gd")
const SHRINE_SCRIPT := preload("res://scripts/world/chaos_shrine_builder.gd")
const BATTLE_SCENE := preload("res://scenes/battle.tscn")
const ENDING_SCENE := preload("res://scenes/ending.tscn")

var world_host: Node3D
var party: PartyRig
var camera_rig: CameraRig
var hud: GameHUD
var current_location: LocationBase = null
var current_interactable: Interactable = null
var transitioning: bool = false
var gameplay_ready: bool = false
var battle_active: bool = false
var battle_scene: BattleScene = null
var ending_active: bool = false
var ending_scene: DemoEnding = null
var _battle_context: Dictionary = {}
var _pending_story: String = ""
var _active_dialogue_npc_id: String = ""
var _current_dialogue_id: String = ""
var _has_loaded_once: bool = false
var _pending_kind: String = ""


func _ready() -> void:
	world_host = Node3D.new()
	world_host.name = "WorldHost"
	add_child(world_host)

	party = PartyRig.new()
	party.name = "Party"
	add_child(party)

	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)

	hud = GameHUD.new()
	hud.name = "HUD"
	add_child(hud)
	hud.dialogue_closed.connect(_on_dialogue_closed)
	hud.story_finished.connect(_on_story_finished)
	hud.service_closed.connect(_on_service_closed)
	hud.equipment_closed.connect(_on_equipment_closed)

	party.stepped.connect(_on_party_stepped)
	party.bump_attempted.connect(_on_bump_attempted)

	await _load_location(GameState.location_id, GameState.spawn_id, GameState.house_id, true)


func _process(_delta: float) -> void:
	if current_location == null or party == null:
		return
	if transitioning or battle_active or ending_active or hud.is_dialogue_open() or hud.is_service_open() or hud.is_equipment_open():
		return
	_refresh_interaction_target()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if battle_active or ending_active:
		return
	if hud.is_equipment_open():
		get_viewport().set_input_as_handled()
		if event.is_action_pressed("equipment"):
			hud.close_equipment()
		elif event.is_action_pressed("ui_cancel"):
			hud.equipment_cancel()
		elif event.is_action_pressed("interact"):
			hud.equipment_confirm()
		elif event.is_action_pressed("move_up"):
			hud.equipment_move_vertical(-1)
		elif event.is_action_pressed("move_down"):
			hud.equipment_move_vertical(1)
		elif event.is_action_pressed("move_left"):
			hud.equipment_move_horizontal(-1)
		elif event.is_action_pressed("move_right"):
			hud.equipment_move_horizontal(1)
		return
	if event.is_action_pressed("equipment"):
		get_viewport().set_input_as_handled()
		if hud.is_dialogue_open() or hud.is_service_open() or transitioning or current_location == null:
			return
		if party.moving:
			return
		_open_equipment()
		return
	if hud.is_service_open():
		get_viewport().set_input_as_handled()
		if event.is_action_pressed("ui_cancel"):
			hud.close_service()
		elif event.is_action_pressed("interact"):
			hud.service_confirm()
		elif event.is_action_pressed("move_up"):
			hud.service_move(-1)
		elif event.is_action_pressed("move_down"):
			hud.service_move(1)
		elif event.is_action_pressed("move_left"):
			hud.service_toggle_mode()
		elif event.is_action_pressed("move_right"):
			hud.service_toggle_mode()
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if hud.is_dialogue_open():
			hud.advance_dialogue()
			return
		if transitioning or current_location == null:
			return
		if party.moving:
			return
		_refresh_interaction_target()
		if current_interactable != null:
			_activate_interactable(current_interactable)


func _refresh_interaction_target() -> void:
	var found: Interactable = null
	if current_location != null:
		var reach := float(GameState.game["interaction"]["range"])
		found = current_location.nearest_interactable(party.leader_world_position(), reach)
	if found != current_interactable:
		current_interactable = found
		interaction_changed.emit(current_interactable)
		if found == null:
			hud.set_prompt("")
		else:
			hud.set_prompt(found.prompt)


func _activate_interactable(point: Interactable) -> void:
	var action: Dictionary = point.activate()
	if action.is_empty():
		return
	match str(action["kind"]):
		"door":
			_transition_from_payload(action["payload"])
		"npc":
			_open_npc_dialogue(action["payload"])
		"service":
			_open_service(action["payload"])
		"chest":
			_open_chest(action["payload"])
		"locked_door":
			_unlock_door(action["payload"])
		"boss":
			_start_boss(action["payload"])


func _transition_from_payload(payload: Dictionary) -> void:
	var target := str(payload.get("target", ""))
	if target.is_empty():
		return
	var spawn := str(payload.get("spawn", ""))
	var house_key := str(payload.get("house_id", ""))
	_load_location(target, spawn, house_key, false)


func _open_npc_dialogue(payload: Dictionary) -> void:
	var dialogue_id := str(payload.get("dialogue", ""))
	var data := GameState.get_dialogue(dialogue_id)
	if data.is_empty():
		return
	_active_dialogue_npc_id = str(payload.get("npc_id", ""))
	_current_dialogue_id = dialogue_id
	current_interactable = null
	party.set_controls_enabled(false)
	hud.set_prompt("")
	hud.open_dialogue(data)


func _open_service(payload: Dictionary) -> void:
	var service_id := str(payload.get("service_id", ""))
	if service_id.is_empty():
		return
	current_interactable = null
	party.set_controls_enabled(false)
	hud.set_prompt("")
	hud.open_service(service_id)


func _on_service_closed() -> void:
	if not transitioning:
		party.set_controls_enabled(true)
		_refresh_interaction_target()


func _open_equipment() -> void:
	current_interactable = null
	party.set_controls_enabled(false)
	hud.set_prompt("")
	hud.open_equipment()


func _on_equipment_closed() -> void:
	if not transitioning:
		party.set_controls_enabled(true)
		_refresh_interaction_target()


func _open_chest(payload: Dictionary) -> void:
	var chest_id := str(payload.get("chest_id", "shrine_chest"))
	var result := GameState.open_chest(
		chest_id,
		str(payload.get("item_id", "chaos_key")),
		str(payload.get("flag", "shrine_chest_opened"))
	)
	if bool(result.get("ok", false)) and current_location != null:
		if current_location.has_method("on_chest_opened"):
			current_location.on_chest_opened(chest_id)
	hud.show_toast(str(result.get("message", "")))
	_refresh_interaction_target()


func _unlock_door(payload: Dictionary) -> void:
	var door_id := str(payload.get("door_id", "shrine_door"))
	var result := GameState.unlock_door(
		str(payload.get("flag", "shrine_door_opened")),
		str(payload.get("key_id", "chaos_key"))
	)
	if bool(result.get("ok", false)) and current_location != null:
		if current_location.has_method("unlock_door"):
			current_location.unlock_door(door_id)
	hud.show_toast(str(result.get("message", "")))
	_refresh_interaction_target()


func _start_boss(payload: Dictionary) -> void:
	var boss_id := str(payload.get("boss_id", "garland"))
	var encounter := GameState.get_boss_encounter(boss_id)
	if encounter.is_empty() or battle_active:
		return
	current_interactable = null
	hud.set_prompt("")
	_begin_battle(encounter, {"type": "boss", "boss_id": boss_id})
	await _wait_for_battle_start()


func _wait_for_battle_start() -> void:
	while battle_scene == null and battle_active:
		await get_tree().process_frame


func _on_story_finished() -> void:
	if _pending_story == "sarah_rescue":
		GameState.mark_flag("sarah_rescued")
		hud.update_objective(true)
		hud.show_toast(GameState.ui_text("toast_rescued", "Принцесса Сара спасена."))
		_pending_story = ""
		transitioning = false
		party.set_controls_enabled(true)
		_refresh_interaction_target()


func _on_dialogue_closed() -> void:
	if not transitioning:
		party.set_controls_enabled(true)
	var start_ending := false
	if _active_dialogue_npc_id == "king":
		if GameState.has_flag("sarah_rescued"):
			if GameState.mark_flag("king_rescued_spoken"):
				hud.update_objective(true)
				hud.show_toast(GameState.ui_text("toast_king_rescued", "Король благодарит героев."))
				start_ending = true
		elif GameState.mark_flag("king_spoken"):
			hud.update_objective(true)
			hud.show_toast(GameState.ui_text("toast_king", "Король открыл вам правду."))
	_active_dialogue_npc_id = ""
	_current_dialogue_id = ""
	if start_ending and not GameState.has_flag("demo_ending_started"):
		GameState.mark_flag("demo_ending_started")
		_begin_ending()


func _begin_ending() -> void:
	if ending_active or ending_scene != null:
		return
	ending_active = true
	transitioning = true
	current_interactable = null
	interaction_changed.emit(null)
	party.set_controls_enabled(false)
	hud.set_prompt("")
	hud.clear_toast()
	var transition_cfg: Dictionary = GameState.game["transition"]
	await hud.fade_to_black(float(transition_cfg["fade_out_duration"]))
	world_host.visible = false
	party.visible = false
	camera_rig.camera.current = false
	hud.visible = false
	ending_scene = ENDING_SCENE.instantiate() as DemoEnding
	add_child(ending_scene)


func _on_party_stepped(cell: Vector2i, _direction: Vector2i) -> void:
	if current_location == null or battle_active or transitioning:
		return
	for zone: Dictionary in current_location.data.get("zones", []):
		var zone_cell := GameState.to_cell(zone.get("cell", [9999, 9999]))
		if zone_cell != cell:
			continue
		var flag := str(zone.get("flag", ""))
		if flag.is_empty() or GameState.has_flag(flag):
			continue
		GameState.mark_flag(flag)
		if flag == "reached_bridge_end":
			hud.update_objective(true)
			hud.show_toast(GameState.ui_text("toast_bridge", "Мост пройден."))
	if battle_active or transitioning:
		return
	var encounter := GameState.try_start_encounter(cell)
	if not encounter.is_empty():
		_begin_battle(encounter, {"type": "random"})


# ---------------------------------------------------------------------------
# Battle flow
# ---------------------------------------------------------------------------

func _begin_battle(encounter: Dictionary, context: Dictionary = {}) -> void:
	if battle_active or battle_scene != null:
		return
	_battle_context = context.duplicate(true)
	battle_active = true
	current_interactable = null
	interaction_changed.emit(null)
	party.set_controls_enabled(false)
	hud.set_prompt("")
	hud.clear_toast()
	var transition_cfg: Dictionary = GameState.game["transition"]
	await hud.fade_to_black(float(transition_cfg["fade_out_duration"]))
	world_host.visible = false
	party.visible = false
	camera_rig.camera.current = false
	hud.visible = false
	battle_scene = BATTLE_SCENE.instantiate() as BattleScene
	battle_scene.encounter_data = encounter.duplicate(true)
	battle_scene.battle_finished.connect(_on_battle_finished, CONNECT_ONE_SHOT)
	add_child(battle_scene)


func _on_battle_finished(result: Dictionary) -> void:
	if battle_scene == null:
		return
	transitioning = true
	party.set_controls_enabled(false)
	var outcome := str(result.get("result", "victory"))
	GameState.set_post_battle_grace()
	world_host.visible = true
	party.visible = true
	hud.visible = true
	camera_rig.camera.current = true
	var finished_scene := battle_scene
	battle_scene = null
	finished_scene.queue_free()
	await get_tree().process_frame
	if outcome == "defeat":
		var checkpoint := GameState.prepare_defeat_return()
		var checkpoint_location := str(checkpoint.get("location", "town"))
		var checkpoint_spawn := str(checkpoint.get("spawn", "castle_gate"))
		var checkpoint_house := str(checkpoint.get("house_id", ""))
		await _load_location(checkpoint_location, checkpoint_spawn, checkpoint_house, false)
		battle_active = false
		var toast_key := "inn_toast" if checkpoint_location == "house" else "fallback_toast"
		hud.show_toast(str(GameState.combat.get("checkpoint", {}).get(toast_key, "Отряд возвращается к последнему ночлегу.")))
		_battle_context = {}
		return
	await hud.fade_from_black(float(GameState.game["transition"]["fade_in_duration"]))
	transitioning = false
	battle_active = false
	if outcome == "victory" and str(_battle_context.get("type", "")) == "boss":
		GameState.mark_flag("garland_defeated")
		if current_location != null and current_location.has_method("on_boss_defeated"):
			current_location.on_boss_defeated()
		_begin_rescue_story()
		_battle_context = {}
		return
	party.set_controls_enabled(true)
	_refresh_interaction_target()
	_battle_context = {}


func _begin_rescue_story() -> void:
	var raw_lines: Array = GameState.get_cutscene("sarah_rescue")
	var lines: Array[Dictionary] = []
	for raw: Variant in raw_lines:
		if raw is Dictionary:
			lines.append((raw as Dictionary).duplicate(true))
	if lines.is_empty():
		GameState.mark_flag("sarah_rescued")
		hud.update_objective(true)
		party.set_controls_enabled(true)
		_refresh_interaction_target()
		return
	_pending_story = "sarah_rescue"
	current_interactable = null
	interaction_changed.emit(null)
	party.set_controls_enabled(false)
	hud.set_prompt("")
	hud.open_story(lines)


func _on_bump_attempted(_cell: Vector2i, _direction: Vector2i) -> void:
	# A small text-free feedback: the camera gives a barely perceptible nudge.
	if camera_rig == null:
		return
	var tw := create_tween()
	tw.tween_property(camera_rig, "position", camera_rig.position + Vector3(0.06, 0.0, 0.0), 0.05)
	tw.tween_property(camera_rig, "position", camera_rig.position, 0.09)


# ---------------------------------------------------------------------------
# Location flow
# ---------------------------------------------------------------------------

func _load_location(loc_id: String, spawn_name: String, house_key: String = "", initial: bool = false) -> void:
	transitioning = true
	gameplay_ready = false
	if hud.is_service_open():
		hud.close_service(false)
	if hud.is_equipment_open():
		hud.close_equipment(false)
	party.set_controls_enabled(false)
	hud.set_prompt("")
	hud.clear_toast()
	current_interactable = null
	interaction_changed.emit(null)
	var transition_cfg: Dictionary = GameState.game["transition"]
	var fade_out := float(transition_cfg["fade_out_duration"])
	var fade_in := float(transition_cfg["fade_in_duration"])
	var black_hold := float(transition_cfg["black_hold"])
	var loc_data := GameState.get_location(loc_id)
	if loc_data.is_empty():
		push_error("Unknown location: %s" % loc_id)
		return

	if not initial:
		await hud.fade_to_black(fade_out)
		await get_tree().create_timer(black_hold).timeout

	if current_location != null:
		world_host.remove_child(current_location)
		current_location.queue_free()
		current_location = null
		await get_tree().process_frame

	GameState.house_id = house_key
	var script: Script
	match loc_id:
		"town":
			script = TOWN_SCRIPT
		"throne_room":
			script = THRONE_SCRIPT
		"house":
			script = HOUSE_SCRIPT
		"chaos_shrine_1", "chaos_shrine_2":
			script = SHRINE_SCRIPT
		_:
			script = TOWN_SCRIPT
	current_location = script.new() as LocationBase
	current_location.name = _title_for_location(loc_id, house_key)
	current_location.setup(loc_data, house_key)
	world_host.add_child(current_location)
	current_location.build()
	# Let the physics server register the freshly built static geometry.
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

	GameState.apply_spawn(loc_id, spawn_name)
	party.bind_location(current_location)
	party.place_from_state(true)
	camera_rig.apply_location(loc_data)
	camera_rig.set_target(party.actors[0])
	camera_rig.snap_to_target()

	var arrival_toast := ""
	if loc_id == "throne_room":
		var first_throne := GameState.mark_flag("throne_entered")
		hud.update_objective(false)
		if first_throne:
			arrival_toast = GameState.ui_text("toast_throne", "Тронный зал.")
	else:
		hud.update_objective(false)

	await hud.fade_from_black(fade_in)
	hud.show_location_card(current_location.title, current_location.subtitle)
	if not arrival_toast.is_empty():
		hud.show_toast(arrival_toast)
	transitioning = false
	gameplay_ready = true
	party.set_controls_enabled(true)
	_has_loaded_once = true
	location_loaded.emit(loc_id)


func _title_for_location(loc_id: String, house_key: String) -> String:
	match loc_id:
		"town":
			return "CorneliaTown"
		"throne_room":
			return "CastleThroneRoom"
		"house":
			var house := GameState.get_house(house_key)
			return "House_%s" % str(house.get("id", "unknown"))
		"chaos_shrine_1":
			return "ChaosShrine_Floor1"
		"chaos_shrine_2":
			return "ChaosShrine_Floor2"
		_:
			return "Location"


# ---------------------------------------------------------------------------
# Hooks for automated acceptance tests
# ---------------------------------------------------------------------------

func test_try_step(direction: Vector2i) -> bool:
	if transitioning or current_location == null:
		return false
	return party.try_step_for_test(direction)


func test_refresh_interaction() -> Interactable:
	_refresh_interaction_target()
	return current_interactable


func test_interact() -> void:
	if hud.is_dialogue_open():
		hud.advance_dialogue()
		return
	_refresh_interaction_target()
	if current_interactable != null:
		_activate_interactable(current_interactable)


func test_advance_dialogue() -> void:
	if hud.is_dialogue_open():
		hud.advance_dialogue()


func test_service_confirm() -> Dictionary:
	if hud.is_service_open():
		return hud.service_confirm()
	return {}


func test_service_move(delta: int) -> void:
	if hud.is_service_open():
		hud.service_move(delta)


func test_service_toggle_mode() -> void:
	if hud.is_service_open():
		hud.service_toggle_mode()


func test_service_close() -> void:
	if hud.is_service_open():
		hud.close_service()


func test_start_battle(encounter_id: String = "bridge_patrol") -> void:
	var encounter := GameState.get_encounter_by_id(encounter_id)
	if encounter.is_empty() or battle_active:
		return
	await _begin_battle(encounter, {"type": "random"})


func get_battle_context() -> Dictionary:
	return _battle_context.duplicate(true)


func test_open_equipment() -> void:
	if not transitioning and not battle_active:
		_open_equipment()


func test_equipment_move_vertical(delta: int) -> void:
	if hud.is_equipment_open():
		hud.equipment_move_vertical(delta)


func test_equipment_move_horizontal(delta: int) -> void:
	if hud.is_equipment_open():
		hud.equipment_move_horizontal(delta)


func test_equipment_confirm() -> Dictionary:
	if hud.is_equipment_open():
		return hud.equipment_confirm()
	return {}


func test_equipment_close() -> void:
	if hud.is_equipment_open():
		hud.close_equipment()


func is_interaction_available() -> bool:
	return current_interactable != null


func get_party() -> PartyRig:
	return party


func debug_assert_loaded() -> bool:
	return gameplay_ready and current_location != null
