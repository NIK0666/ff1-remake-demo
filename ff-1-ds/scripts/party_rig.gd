class_name PartyRig
extends Node3D
## Persistent party presentation. Authority over cells and roster lives in GameState;
## this node only turns state into an animated, single-file marching party.

signal stepped(cell: Vector2i, direction: Vector2i)
signal bump_attempted(cell: Vector2i, direction: Vector2i)

var actors: Array[CharacterVisual] = []
var location: LocationBase
var controls_enabled: bool = false
var moving: bool = false
var instant_mode: bool = false

var _step_duration: float = 0.185
var _move_tween: Tween
var _ring: MeshInstance3D
var _leader_marker: MeshInstance3D
var _ring_material: StandardMaterial3D
var _ring_time: float = 0.0


func _ready() -> void:
	_step_duration = float(GameState.game["party"]["step_duration"])
	_build_actors()
	_build_leader_mark()


func _build_actors() -> void:
	for i in GameState.party.size():
		var member: Dictionary = GameState.party[i]
		var actor := CharacterVisual.new()
		actor.name = "Hero_%s" % str(member["id"])
		actor.setup_hero(member, i)
		add_child(actor)
		actors.append(actor)


func _build_leader_mark() -> void:
	_ring_material = StandardMaterial3D.new()
	_ring_material.albedo_color = Color(1.0, 0.83, 0.48, 0.85)
	_ring_material.emission_enabled = true
	_ring_material.emission = Color(GameState.game["party"]["leader_ring_color"])
	_ring_material.emission_energy_multiplier = 1.4
	_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED

	var torus := TorusMesh.new()
	torus.inner_radius = 0.4
	torus.outer_radius = 0.48
	torus.rings = 24
	torus.ring_segments = 8
	_ring = MeshInstance3D.new()
	_ring.name = "LeaderRing"
	_ring.mesh = torus
	_ring.material_override = _ring_material
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)

	_leader_marker = MeshInstance3D.new()
	_leader_marker.name = "LeaderDiamond"
	var diamond := CylinderMesh.new()
	diamond.top_radius = 0.0
	diamond.bottom_radius = 0.1
	diamond.height = 0.18
	diamond.radial_segments = 4
	_leader_marker.mesh = diamond
	_leader_marker.material_override = _ring_material
	_leader_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_leader_marker)


func bind_location(new_location: LocationBase) -> void:
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	moving = false
	location = new_location
	for actor: CharacterVisual in actors:
		actor.walking = false


func place_from_state(snap_facing: bool = true) -> void:
	if location == null:
		return
	for i in actors.size():
		var cell: Vector2i = GameState.trail[mini(i, GameState.trail.size() - 1)]
		actors[i].position = location.cell_to_world(cell)
		actors[i].walking = false
		if snap_facing:
			actors[i].set_facing(Vector3(GameState.facing.x, 0.0, GameState.facing.y), true)
	_tick_leader_mark(0.0, true)


func set_controls_enabled(value: bool) -> void:
	controls_enabled = value


func leader_world_position() -> Vector3:
	if actors.is_empty():
		return global_position
	return actors[0].global_position


func leader_cell() -> Vector2i:
	return GameState.leader_cell


func _process(delta: float) -> void:
	_ring_time += delta
	_tick_leader_mark(delta, false)
	if moving:
		return
	if controls_enabled and location != null and not GameState.party.is_empty():
		var direction := _poll_direction()
		if direction != Vector2i.ZERO:
			_attempt_step(direction)


func _poll_direction() -> Vector2i:
	if Input.is_action_pressed("move_up"):
		return Vector2i(0, -1)
	if Input.is_action_pressed("move_down"):
		return Vector2i(0, 1)
	if Input.is_action_pressed("move_left"):
		return Vector2i(-1, 0)
	if Input.is_action_pressed("move_right"):
		return Vector2i(1, 0)
	return Vector2i.ZERO


func _tick_leader_mark(delta: float, snap: bool) -> void:
	if actors.is_empty() or _ring == null:
		return
	var leader := actors[0]
	_ring.position = leader.position + Vector3(0.0, 0.035, 0.0)
	if not snap:
		_ring.rotation.y += delta * 0.45
	var pulse := 1.0 + sin(_ring_time * 2.4) * 0.045
	_ring.scale = Vector3(pulse, 1.0, pulse)
	var marker_y := 2.35 + sin(_ring_time * 2.1) * 0.06
	_leader_marker.position = leader.position + Vector3(0.0, marker_y, 0.0)
	_leader_marker.rotation.y += delta * 2.0
	_ring_material.albedo_color.a = 0.68 + sin(_ring_time * 3.0) * 0.16


func _attempt_step(direction: Vector2i) -> bool:
	if location == null or direction == Vector2i.ZERO:
		return false
	var target_cell := GameState.leader_cell + direction
	if not location.can_party_stand(target_cell):
		bump_attempted.emit(target_cell, direction)
		return false
	return _commit_and_animate(direction, target_cell, false)


func _commit_and_animate(direction: Vector2i, target_cell: Vector2i, instant: bool) -> bool:
	var starts: Array[Vector3] = []
	for actor: CharacterVisual in actors:
		starts.append(actor.position)
	var old_facing := GameState.facing
	GameState.commit_step(target_cell, direction)

	var targets: Array[Vector3] = []
	for i in actors.size():
		var cell: Vector2i = GameState.trail[mini(i, GameState.trail.size() - 1)]
		targets.append(location.cell_to_world(cell))
		actors[i].set_facing(Vector3(direction.x, 0.0, direction.y))

	if instant:
		for i in actors.size():
			actors[i].position = targets[i]
			actors[i].walking = false
		stepped.emit(target_cell, direction)
		return true

	moving = true
	for actor: CharacterVisual in actors:
		actor.walking = true
	var stagger := float(GameState.game["party"]["follow_stagger"])
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.set_parallel(true)
	for i in actors.size():
		var delay := float(i) * stagger
		var duration := maxf(0.055, _step_duration - delay)
		_move_tween.tween_property(actors[i], "position", targets[i], duration).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_move_tween.finished.connect(_on_step_tween_finished.bind(direction, target_cell, old_facing), CONNECT_ONE_SHOT)
	return true


func _on_step_tween_finished(direction: Vector2i, target_cell: Vector2i, _old_facing: Vector2i) -> void:
	moving = false
	for actor: CharacterVisual in actors:
		actor.walking = false
	stepped.emit(target_cell, direction)


## Test/automation hook: uses the exact same collision validation and state commit,
## but settles the step instantly. Never used by normal gameplay.
func try_step_for_test(direction: Vector2i) -> bool:
	if location == null or moving:
		return false
	var target := GameState.leader_cell + direction
	if not location.can_party_stand(target):
		return false
	return _commit_and_animate(direction, target, true)


func party_ids() -> Array[String]:
	var ids: Array[String] = []
	for member: Dictionary in GameState.party:
		ids.append(str(member["id"]))
	return ids


func party_classes() -> Array[String]:
	var classes: Array[String] = []
	for member: Dictionary in GameState.party:
		classes.append(str(member["class_id"]))
	return classes
