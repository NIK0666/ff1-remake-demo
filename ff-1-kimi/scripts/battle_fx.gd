extends Node3D

var data: Dictionary
var math: Dictionary
var visuals
var fx: Dictionary
var active_marker: Node3D
var cursor_marker: Node3D
var clock: float = 0.0


func _init(config: Dictionary, factory) -> void:
	data = config
	math = data.settings.math
	visuals = factory
	fx = data.battle.effects


func _ready() -> void:
	name = "BattleEffects"
	active_marker = _marker("ActiveMarker", "fx_active")
	cursor_marker = _marker("TargetCursor", "fx_cursor")


func _marker(marker_name: String, material_name: String) -> Node3D:
	var root: Node3D = visuals.group(self, marker_name, Vector3.ZERO)
	var ring: MeshInstance3D = visuals.unshadowed(visuals.torus(root, Vector3.UP * float(fx.ring_height), fx.ring_inner, fx.ring_outer, material_name))
	ring.scale.y = float(fx.ring_flatten)
	var arrow: MeshInstance3D = visuals.unshadowed(visuals.tapered(root, Vector3.UP * float(fx.arrow_height), fx.arrow_radius, fx.arrow_length, material_name, math.zero))
	arrow.rotation.x = PI
	arrow.name = "Arrow"
	root.hide()
	return root


func _process(delta: float) -> void:
	clock += delta
	for marker in [active_marker, cursor_marker]:
		var arrow: Node3D = marker.get_node("Arrow")
		arrow.position.y = float(fx.arrow_height) * float(marker.get_meta("height", math.one)) + sin(clock * float(fx.bob_speed)) * float(fx.bob_amount)


func _place(marker: Node3D, model: Node3D) -> void:
	marker.position = model.position * Vector3(math.one, math.zero, math.one)
	marker.set_meta("height", model.scale.y)
	marker.show()


func mark_active(model: Node3D) -> void:
	_place(active_marker, model)


func clear_active() -> void:
	active_marker.hide()


func point(model: Node3D) -> void:
	_place(cursor_marker, model)


func clear_cursor() -> void:
	cursor_marker.hide()


func float_text(origin: Vector3, text_value: String, color_name: String) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = int(fx.number_size)
	label.pixel_size = float(fx.number_pixel)
	label.outline_size = int(fx.number_outline)
	label.modulate = visuals.color(color_name)
	label.outline_modulate = visuals.color("shadow")
	label.position = origin * Vector3(math.one, math.zero, math.one) + Vector3.UP * float(fx.number_height)
	add_child(label)
	var tween: Tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y + float(fx.number_rise), float(fx.number_time))
	tween.parallel().tween_property(label, "modulate:a", math.zero, float(fx.number_time) * math.half).set_delay(float(fx.number_time) * math.half)
	tween.tween_callback(label.queue_free)


func _flash(mesh: MeshInstance3D, grow: float, duration: float) -> void:
	visuals.unshadowed(mesh)
	var tween: Tween = create_tween()
	tween.tween_property(mesh, "scale", mesh.scale * grow, duration)
	tween.parallel().tween_property(mesh, "transparency", math.one, duration)
	tween.tween_callback(mesh.queue_free)


func burst(origin: Vector3, color_name: String) -> void:
	var radius: float = float(fx.burst_radius)
	var mesh: MeshInstance3D = visuals.sphere(self, origin * Vector3(math.one, math.zero, math.one) + Vector3.UP * radius, radius, radius * math.double, color_name)
	mesh.scale = Vector3.ONE * float(fx.burst_start)
	_flash(mesh, float(fx.burst_grow) / float(fx.burst_start), float(fx.burst_time))


func bolt(origin: Vector3) -> void:
	var height: float = float(fx.bolt_height)
	var base: Vector3 = origin * Vector3(math.one, math.zero, math.one)
	_flash(visuals.cylinder(self, base + Vector3.UP * height * math.half, fx.bolt_radius, height, "magic_lightning"), math.one, float(fx.burst_time))
	burst(origin, "magic_lightning")


func sparkles(origin: Vector3, color_name: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(clock * float(math.percent))
	var base: Vector3 = origin * Vector3(math.one, math.zero, math.one)
	for index in range(int(fx.sparkle_count)):
		var start: Vector3 = base + Vector3(rng.randf_range(-float(fx.sparkle_spread), float(fx.sparkle_spread)), rng.randf_range(math.zero, float(fx.sparkle_rise)), rng.randf_range(-float(fx.sparkle_spread), float(fx.sparkle_spread)))
		var mote: MeshInstance3D = visuals.unshadowed(visuals.sphere(self, start, fx.sparkle_radius, float(fx.sparkle_radius) * math.double, color_name))
		var tween: Tween = create_tween()
		tween.tween_property(mote, "position:y", start.y + float(fx.sparkle_rise), float(fx.burst_time))
		tween.parallel().tween_property(mote, "transparency", math.one, float(fx.burst_time))
		tween.tween_callback(mote.queue_free)


func column(origin: Vector3, color_name: String) -> void:
	var height: float = float(fx.column_height)
	var mesh: MeshInstance3D = visuals.cylinder(self, origin * Vector3(math.one, math.zero, math.one) + Vector3.UP * height * math.half, fx.column_radius, height, color_name)
	_flash(mesh, math.one, float(fx.burst_time) * math.double)
	sparkles(origin, color_name)


func blink(model: Node3D) -> void:
	var tween: Tween = create_tween()
	for index in range(int(fx.blink_count)):
		tween.tween_callback(model.hide)
		tween.tween_interval(float(fx.blink_interval))
		tween.tween_callback(model.show)
		tween.tween_interval(float(fx.blink_interval))


func shake(model: Node3D, home: Vector3) -> void:
	var tween: Tween = create_tween()
	for side in [math.one, math.zero - math.one, math.zero]:
		tween.tween_property(model, "position", home + Vector3.RIGHT * float(fx.shake_distance) * side, float(fx.blink_interval))


func vanish(model: Node3D) -> void:
	var tween: Tween = create_tween()
	for index in range(int(fx.blink_count)):
		tween.tween_callback(model.hide)
		tween.tween_interval(float(fx.blink_interval))
		tween.tween_callback(model.show)
		tween.tween_interval(float(fx.blink_interval))
	tween.tween_method(func(value: float) -> void: visuals.fade(model, value), math.zero, math.one, float(fx.vanish_time))
	tween.tween_callback(model.hide)


func hop(model: Node3D, home: Vector3) -> Tween:
	var tween: Tween = create_tween()
	tween.tween_property(model, "position", home + Vector3.UP * float(fx.hop_height), float(fx.hop_time))
	tween.tween_property(model, "position", home, float(fx.hop_time))
	return tween


func move(model: Node3D, destination: Vector3, duration: float) -> Tween:
	var tween: Tween = create_tween()
	tween.tween_property(model, "position", destination, duration)
	return tween
