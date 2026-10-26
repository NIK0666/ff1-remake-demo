class_name CameraRig
extends Node3D
## Fixed-angle top-down follow camera. Smoothly trails the party leader.
## Locations may override framing (wide town vs. closer interiors).

var camera: Camera3D
var target_node: Node3D
var follow_smoothing: float = 6.5
var target_height: float = 1.35
var lead_amount: float = 0.8
var distance: float = 23.0
var pitch_degrees: float = 47.0
var yaw_degrees: float = 18.0
var _look_offset: Vector3 = Vector3(0.0, 1.35, 0.0)
var _current_look: Vector3 = Vector3.ZERO
var _has_target: bool = false


func _ready() -> void:
	var cfg: Dictionary = GameState.game["camera"]
	follow_smoothing = float(cfg["smoothing"])
	target_height = float(cfg["target_height"])
	lead_amount = float(cfg["lead"])
	distance = float(cfg["distance"])
	pitch_degrees = float(cfg["pitch_degrees"])
	yaw_degrees = float(cfg["yaw_degrees"])
	_look_offset = Vector3(0.0, target_height, 0.0)

	camera = Camera3D.new()
	camera.name = "GameCamera"
	camera.fov = float(cfg["fov"])
	camera.near = 0.15
	camera.far = float(cfg["far"])
	camera.current = true
	add_child(camera)
	camera.rotation = Vector3.ZERO


func apply_location(location_data: Dictionary) -> void:
	var defaults: Dictionary = GameState.game["camera"]
	distance = float(defaults["distance"])
	pitch_degrees = float(defaults["pitch_degrees"])
	yaw_degrees = float(defaults["yaw_degrees"])
	lead_amount = float(defaults["lead"])
	camera.fov = float(defaults["fov"])
	var override: Dictionary = location_data.get("camera", {})
	distance = float(override.get("distance", distance))
	pitch_degrees = float(override.get("pitch_degrees", pitch_degrees))
	yaw_degrees = float(override.get("yaw_degrees", yaw_degrees))
	lead_amount = float(override.get("lead", lead_amount))
	camera.fov = float(override.get("fov", camera.fov))


func set_target(node: Node3D) -> void:
	target_node = node
	_has_target = target_node != null


func snap_to_target() -> void:
	if target_node == null:
		return
	var look_target := _target_look_point()
	position = look_target + _camera_offset()
	_look_at_point(look_target)
	_current_look = look_target
	_has_target = true


func _process(delta: float) -> void:
	if target_node == null:
		return
	if not _has_target:
		snap_to_target()
		return
	var look_target := _target_look_point()
	var smoothing := 1.0 - exp(-follow_smoothing * delta)
	_current_look = _current_look.lerp(look_target, smoothing)
	var desired := _current_look + _camera_offset()
	position = position.lerp(desired, 1.0 - exp(-follow_smoothing * 1.3 * delta))
	_look_at_point(_current_look)


func _target_look_point() -> Vector3:
	if target_node == null:
		return _look_offset
	var lead := Vector3(float(GameState.facing.x), 0.0, float(GameState.facing.y)) * lead_amount
	return target_node.global_position + _look_offset + lead


func _camera_offset() -> Vector3:
	var pitch := deg_to_rad(pitch_degrees)
	var yaw := deg_to_rad(yaw_degrees)
	var horizontal := cos(pitch) * distance
	return Vector3(sin(yaw) * horizontal, sin(pitch) * distance, cos(yaw) * horizontal)


func _look_at_point(point: Vector3) -> void:
	camera.global_position = global_position
	camera.look_at(point, Vector3.UP)
