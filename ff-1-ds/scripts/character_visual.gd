class_name CharacterVisual
extends Node3D
## Procedural low-poly hero/NPC rig with idle breathing and a simple walk cycle.

var walking: bool = false
var is_npc: bool = false
var target_yaw: float = 0.0
var walk_phase: float = 0.0
var move_blend: float = 0.0
var idle_time: float = 0.0
var walk_cycle_speed: float = 11.0
var turn_smoothing: float = 14.0
var phase_offset: float = 0.0

var body_root: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var cape: Node3D
var head_group: Node3D
var staff_group: Node3D
var marker: Node3D

var _robe: bool = false
var _weapon_swing: Node3D
var _fallen_overlay: StandardMaterial3D


func set_fallen_tint(enabled: bool) -> void:
	if enabled:
		if _fallen_overlay == null:
			_fallen_overlay = StandardMaterial3D.new()
			_fallen_overlay.albedo_color = Color(0.33, 0.31, 0.32, 0.52)
			_fallen_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_fallen_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_fallen_overlay.cull_mode = BaseMaterial3D.CULL_DISABLED
			_fallen_overlay.no_depth_test = false
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh != null:
			mesh.material_overlay = _fallen_overlay if enabled else null


func setup_hero(member: Dictionary, order: int) -> void:
	is_npc = false
	phase_offset = float(order) * 1.7
	walk_cycle_speed = float(GameState.game["party"]["walk_cycle_speed"])
	turn_smoothing = float(GameState.game["party"]["turn_smoothing"])
	var look := str(member.get("look", "warrior"))
	var palette := {
		"primary": Color(str(member.get("color", "#cccccc"))),
		"accent": Color(str(member.get("accent", "#e8c98a"))),
		"dark": Color(str(member.get("dark", "#332a24")))
	}
	match look:
		"warrior":
			_build_warrior(palette)
		"thief":
			_build_thief(palette)
		"monk":
			_build_monk(palette)
		"white_mage":
			_build_white_mage(palette)
		_:
			_build_warrior(palette)
	_make_contact_shadow(0.38, Color(0.06, 0.05, 0.05, 0.3))


func setup_npc(npc: Dictionary) -> void:
	is_npc = true
	phase_offset = 2.1 + float(absi(str(npc.get("id", "")).hash()) % 7) * 0.4
	var look := str(npc.get("look", "resident"))
	match look:
		"guard":
			_build_guard(npc)
		"king":
			_build_king(npc)
		_:
			_build_resident(npc)
	_make_contact_shadow(0.34, Color(0.05, 0.04, 0.04, 0.32))
	_make_interaction_marker()


func setup_enemy(enemy: Dictionary) -> void:
	is_npc = true
	walking = false
	phase_offset = 1.3 + float(absi(str(enemy.get("id", "")).hash()) % 9) * 0.35
	var raw_palette: Dictionary = enemy.get("palette", {
		"primary": "#6f8a4e",
		"accent": "#c7a15d",
		"dark": "#39452c"
	})
	var palette: Dictionary = {
		"primary": Color(str(raw_palette.get("primary", "#6f8a4e"))),
		"accent": Color(str(raw_palette.get("accent", "#c7a15d"))),
		"dark": Color(str(raw_palette.get("dark", "#39452c")))
	}
	match str(enemy.get("look", "goblin")):
		"goblin_archer":
			_build_goblin_archer(palette)
		"goblin_shaman":
			_build_goblin_shaman(palette)
		"goblin_brute":
			_build_goblin_brute(palette)
		"skeleton":
			_build_skeleton(palette)
		"wraith":
			_build_wraith(palette)
		"cultist":
			_build_cultist(palette)
		"garland":
			_build_garland(palette)
		_:
			_build_goblin(palette)
	_make_contact_shadow(0.43, Color(0.04, 0.035, 0.03, 0.38))


func setup_worker(index: int) -> void:
	is_npc = true
	walking = false
	phase_offset = 0.8 + float(index) * 1.1
	var tunics := ["#8a633f", "#65714c", "#776146", "#59646b"]
	var primary := Color(tunics[index % tunics.size()])
	var palette := {
		"primary": primary,
		"accent": Color("#c9a765"),
		"dark": primary.darkened(0.35)
	}
	_make_base(palette, Color("#c9966f").lerp(Color("#9b6c52"), float(index % 3) * 0.2), Color("#4a3a2c"), false, Color("#382a20"))
	cape.visible = false
	_make_tunic_overlay(primary.darkened(0.15), 1.02)
	_add_peasant_hat(primary.darkened(0.3))
	_add_belt_pouches(Color("#4b3528"))
	# A heavy mallet in the right hand.
	var hammer := Node3D.new()
	hammer.name = "WorkHammer"
	hammer.position = Vector3(0.0, -0.69, -0.02)
	hammer.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
	arm_r.add_child(hammer)
	MeshLib.add_cylinder(hammer, 0.035, 0.045, 0.62, Vector3(0.0, -0.24, 0.0), MeshLib.material("#5b402a", 0.92), "HammerHandle", 7)
	MeshLib.add_box(hammer, Vector3(0.3, 0.14, 0.16), Vector3(0.0, -0.57, 0.0), MeshLib.material("#73746f", 0.45, 0.45), "HammerHead")
	MeshLib.add_box(hammer, Vector3(0.07, 0.1, 0.17), Vector3(0.15, -0.57, 0.0), MeshLib.material("#9b9b92", 0.35, 0.5), "HammerFace")
	_make_contact_shadow(0.4, Color(0.05, 0.04, 0.035, 0.35))


func setup_sarah(npc: Dictionary) -> void:
	is_npc = true
	walking = false
	phase_offset = 1.5
	var palette := {
		"primary": Color(str(npc.get("primary", "#e8e2f2"))),
		"accent": Color(str(npc.get("accent", "#d5b16b"))),
		"dark": Color(str(npc.get("dark", "#68758f")))
	}
	_build_sarah(palette)
	_make_contact_shadow(0.4, Color(0.04, 0.035, 0.04, 0.32))


func set_facing(dir: Vector3, snap: bool = false) -> void:
	if dir.length_squared() < 0.001:
		return
	target_yaw = atan2(-dir.x, -dir.z)
	if snap:
		rotation.y = target_yaw


func _process(delta: float) -> void:
	idle_time += delta
	if marker != null:
		marker.position.y = 2.55 + sin(idle_time * 2.0 + phase_offset) * 0.07
	if is_npc:
		if body_root != null:
			body_root.position.y = sin(idle_time * 1.55 + phase_offset) * 0.012
			body_root.rotation.z = sin(idle_time * 0.7 + phase_offset) * 0.008
		if cape != null:
			cape.rotation.x = 0.08 + sin(idle_time * 1.2 + phase_offset) * 0.022
		return

	var target := 1.0 if walking else 0.0
	move_blend = move_toward(move_blend, target, delta * 9.0)
	if walking:
		walk_phase += delta * walk_cycle_speed
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-turn_smoothing * delta))

	var swing := sin(walk_phase + phase_offset) * move_blend
	var step_bounce := absf(sin(walk_phase + phase_offset)) * 0.045 * move_blend
	var idle_breath := sin(idle_time * 1.8 + phase_offset) * 0.008
	body_root.position.y = idle_breath + step_bounce
	body_root.rotation.z = sin(walk_phase + phase_offset) * 0.032 * move_blend

	if leg_l != null:
		leg_l.rotation.x = swing * 0.65
	if leg_r != null:
		leg_r.rotation.x = -swing * 0.65
	if arm_l != null:
		arm_l.rotation.x = -swing * 0.48
	if arm_r != null:
		arm_r.rotation.x = swing * 0.48
	if cape != null:
		cape.rotation.x = 0.09 + move_blend * 0.22 + sin(walk_phase * 0.5 + phase_offset) * 0.05
	if staff_group != null:
		staff_group.rotation.z = sin(walk_phase + phase_offset) * 0.035 * move_blend
	if head_group != null:
		head_group.rotation.y = sin(idle_time * 0.65 + phase_offset) * 0.06


# ---------------------------------------------------------------------------
# Hero styles
# ---------------------------------------------------------------------------

func _build_warrior(palette: Dictionary) -> void:
	var steel := Color("#8a95a3")
	var steel_dark := Color("#59636f")
	var leather := Color("#4c3428")
	var skin := Color("#d4a07b")
	_make_base(palette, skin, leather, false, Color("#74483f"))
	_make_armor_cuirass(steel, palette["accent"])
	_add_pauldron(Vector3(-0.34, 1.34, 0.0), steel, palette["accent"])
	_add_pauldron(Vector3(0.34, 1.34, 0.0), steel, palette["accent"])
	_add_helmet(palette["accent"], steel)
	_add_sword(Vector3(0.48, 1.2, -0.04))
	_add_shield(Vector3(-0.45, 1.12, -0.02), steel_dark, palette["accent"], palette["primary"])
	_add_belt_pouches(palette["dark"])


func _build_thief(palette: Dictionary) -> void:
	var leather := Color("#3b2e25")
	var skin := Color("#c7906b")
	_make_base(palette, skin, leather, false, Color("#3d4f41"))
	_make_tunic_overlay(palette["dark"], 0.94)
	_add_hood(palette["primary"], palette["dark"])
	_add_scarf(palette["accent"])
	_add_dagger(Vector3(0.4, 0.98, 0.02), palette["accent"], false)
	_add_dagger(Vector3(-0.4, 0.98, 0.02), palette["accent"], true)
	_add_belt_pouches(leather)
	# Short, practical cloak.
	cape.scale = Vector3(0.8, 0.7, 0.8)


func _build_monk(palette: Dictionary) -> void:
	var skin := Color("#b57b51")
	var wraps := Color("#e8dcc3")
	var trousers := Color("#5c4432")
	_make_base(palette, skin, trousers, false, Color("#6b4c36"))
	# Replace the tunic with a bare, broad torso.
	MeshLib.add_cylinder(body_root, 0.28, 0.35, 0.66, Vector3(0.0, 1.13, 0.0), MeshLib.material(skin.to_html(false), 0.92), "BareChest", 10)
	MeshLib.add_box(body_root, Vector3(0.64, 0.12, 0.36), Vector3(0.0, 1.35, 0.0), MeshLib.material(skin.to_html(false), 0.92), "ShoulderSkin")
	# Robe knot and sash.
	MeshLib.add_cylinder(body_root, 0.3, 0.3, 0.11, Vector3(0.0, 0.83, 0.0), MeshLib.material("#8b5740"), "Sash", 10)
	MeshLib.add_box(body_root, Vector3(0.1, 0.32, 0.05), Vector3(0.18, 0.68, -0.24), MeshLib.material(wraps.to_html(false)), "SashEnd")
	# Wrapped forearms and fists.
	for side: float in [-1.0, 1.0]:
		var arm: Node3D = arm_r if side > 0.0 else arm_l
		MeshLib.add_cylinder(arm, 0.085, 0.08, 0.3, Vector3(0.0, -0.3, 0.0), MeshLib.material(wraps.to_html(false), 0.95), "Wrap", 8)
		MeshLib.add_sphere(arm, 0.105, Vector3(0.0, -0.47, -0.02), MeshLib.material(skin.to_html(false), 0.9), "Fist", -1.0, 10)
		MeshLib.add_box(arm, Vector3(0.12, 0.1, 0.16), Vector3(0.0, -0.52, -0.02), MeshLib.material(wraps.to_html(false)), "WrapKnuckle")
	_add_pauldron(Vector3(-0.34, 1.34, 0.0), skin, Color("#d9b184"))
	_add_pauldron(Vector3(0.34, 1.34, 0.0), skin, Color("#d9b184"))
	_add_monk_head(palette["accent"])
	_add_prayer_beads(palette["accent"])
	_make_contact_shadow(0.42, Color(0.06, 0.04, 0.03, 0.34))


func _build_white_mage(palette: Dictionary) -> void:
	var robe := Color("#ebe7d9")
	var blue: Color = palette["accent"]
	var gold := Color("#caa95f")
	var skin := Color("#e0b28a")
	_robe = true
	_make_base(palette, skin, blue, true, blue)
	# Flowing robe skirt over the legs.
	MeshLib.add_cylinder(body_root, 0.38, 0.24, 1.0, Vector3(0.0, 0.48, 0.0), MeshLib.material(robe.to_html(false), 0.9), "RobeSkirt", 12)
	MeshLib.add_cylinder(body_root, 0.37, 0.37, 0.06, Vector3(0.0, 0.2, 0.0), MeshLib.material(blue.to_html(false), 0.75), "RobeHem", 12)
	MeshLib.add_box(body_root, Vector3(0.5, 0.1, 0.34), Vector3(0.0, 0.94, 0.0), MeshLib.material(gold.to_html(false), 0.5, 0.25), "Sash")
	MeshLib.add_box(body_root, Vector3(0.1, 0.5, 0.04), Vector3(0.18, 0.7, -0.25), MeshLib.material(blue.to_html(false)), "SashTail")
	# Wide sleeves.
	for side: float in [-1.0, 1.0]:
		var arm: Node3D = arm_r if side > 0.0 else arm_l
		MeshLib.add_cylinder(arm, 0.14, 0.09, 0.5, Vector3(0.0, -0.24, 0.0), MeshLib.material(robe.to_html(false), 0.9), "Sleeve", 8)
		MeshLib.add_sphere(arm, 0.075, Vector3(0.0, -0.48, 0.0), MeshLib.material(skin.to_html(false), 0.9), "Hand", -1.0, 8)
	_add_mage_hat(robe, blue, gold)
	_add_staff(Vector3(0.44, 0.0, 0.04), gold, blue)
	_make_contact_shadow(0.46, Color(0.05, 0.05, 0.07, 0.3))


# ---------------------------------------------------------------------------
# NPC styles
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Bridge enemies
# ---------------------------------------------------------------------------

func _build_goblin(palette: Dictionary) -> void:
	var skin := Color("#7f9b58")
	var leather := Color("#4a3528")
	_make_base(palette, skin, leather, false, Color("#38271f"))
	_add_goblin_head(palette, skin)
	_make_tunic_overlay(palette["dark"], 0.9)
	_add_belt_pouches(leather)
	_add_dagger(Vector3(0.42, 1.0, 0.02), palette["accent"], false)
	_add_dagger(Vector3(-0.4, 0.98, 0.03), palette["accent"], true)
	cape.scale = Vector3(0.65, 0.5, 0.65)


func _build_goblin_archer(palette: Dictionary) -> void:
	var skin := Color("#879f5e")
	var leather := Color("#4a3625")
	_make_base(palette, skin, leather, false, Color("#34251d"))
	_add_goblin_head(palette, skin)
	_make_tunic_overlay(palette["primary"].darkened(0.12), 0.92)
	_add_scarf(palette["accent"])
	_add_belt_pouches(leather)
	cape.scale = Vector3(0.55, 0.55, 0.55)
	# Quiver and arrows on the back.
	MeshLib.add_cylinder(body_root, 0.09, 0.075, 0.62, Vector3(-0.17, 1.2, 0.28), MeshLib.material("#5b3c27", 0.9), "Quiver", 8, Vector3(0.0, 0.0, -18.0))
	for i in 3:
		MeshLib.add_cylinder(body_root, 0.012, 0.01, 0.35, Vector3(-0.25 + float(i) * 0.045, 1.48, 0.29), MeshLib.material("#c7b78e", 0.9), "ArrowShaft", 5)
		MeshLib.add_pyramid(body_root, Vector2(0.05, 0.05), 0.12, Vector3(-0.25 + float(i) * 0.045, 1.68, 0.29), MeshLib.material("#8e989b", 0.5, 0.4), "Arrowhead", Vector3(180.0, 0.0, 0.0))
	# A simple bow held in the left hand.
	var bow := Node3D.new()
	bow.name = "Bow"
	bow.position = Vector3(-0.45, 1.0, -0.02)
	bow.rotation_degrees = Vector3(0.0, 0.0, 12.0)
	body_root.add_child(bow)
	var bow_mesh := TorusMesh.new()
	bow_mesh.inner_radius = 0.34
	bow_mesh.outer_radius = 0.37
	bow_mesh.rings = 24
	bow_mesh.ring_segments = 8
	var ring := MeshInstance3D.new()
	ring.name = "BowArc"
	ring.mesh = bow_mesh
	ring.material_override = MeshLib.material("#6b482b", 0.9)
	ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	bow.add_child(ring)
	MeshLib.add_box(bow, Vector3(0.012, 0.67, 0.012), Vector3(0.0, 0.0, 0.37), MeshLib.material("#d8cfb6", 0.8), "BowString")


func _build_goblin_shaman(palette: Dictionary) -> void:
	var skin := Color("#728a4e")
	_make_base(palette, skin, palette["dark"], true, Color("#2b2438"))
	_add_goblin_head(palette, skin)
	_add_hood(palette["primary"], palette["dark"])
	_add_prayer_beads(palette["accent"])
	# A gnarled staff with a black-magic orb.
	var staff := Node3D.new()
	staff.name = "ShamanStaff"
	staff.position = Vector3(-0.43, 0.98, -0.02)
	staff.rotation_degrees = Vector3(0.0, 0.0, 4.0)
	body_root.add_child(staff)
	MeshLib.add_cylinder(staff, 0.035, 0.045, 1.55, Vector3(0.0, 0.45, 0.0), MeshLib.material("#3d2d24", 0.95), "StaffShaft", 7)
	MeshLib.add_cylinder(staff, 0.1, 0.03, 0.2, Vector3(0.0, 1.27, 0.0), MeshLib.material("#5d4a35", 0.9), "StaffClaw", 6)
	var orb_mat := MeshLib.emissive("#9f6bdd", 1.8)
	MeshLib.add_sphere(staff, 0.13, Vector3(0.0, 1.42, 0.0), orb_mat, "ShadowOrb", -1.0, 12)
	MeshLib.add_omni_light(staff, Vector3(0.0, 1.42, 0.0), "#9f6bdd", 1.4, 2.6, false)
	cape.scale = Vector3(0.85, 0.9, 0.85)


func _build_goblin_brute(palette: Dictionary) -> void:
	var skin := Color("#68834c")
	var leather := Color("#3d2c22")
	_make_base(palette, skin, leather, false, Color("#31231b"))
	body_root.scale = Vector3(1.15, 1.08, 1.12)
	_add_goblin_head(palette, skin)
	_make_tunic_overlay(palette["dark"], 1.0)
	# Rough shoulder fur.
	for side: float in [-1.0, 1.0]:
		MeshLib.add_sphere(body_root, 0.19, Vector3(0.34 * side, 1.4, 0.02), MeshLib.material("#7a6042", 0.98), "FurPauldron", 0.24, 10)
	_add_belt_pouches(leather)
	var club := Node3D.new()
	club.name = "Club"
	club.position = Vector3(0.47, 1.0, -0.02)
	club.rotation_degrees = Vector3(0.0, 0.0, -16.0)
	body_root.add_child(club)
	MeshLib.add_cylinder(club, 0.045, 0.085, 0.72, Vector3(0.0, -0.16, 0.0), MeshLib.material("#5b402b", 0.95), "ClubShaft", 7)
	MeshLib.add_sphere(club, 0.15, Vector3(0.0, 0.22, 0.0), MeshLib.material("#6c5036", 0.94), "ClubHead", 0.2, 9)
	for i in 3:
		var spike := MeshLib.add_pyramid(club, Vector2(0.08, 0.08), 0.18, Vector3(0.0, 0.22 + float(i) * 0.02, -0.12 + float(i) * 0.12), MeshLib.material("#a5a9a0", 0.5, 0.4), "ClubSpike")
		spike.rotation_degrees = Vector3(90.0 - float(i) * 55.0, 0.0, 0.0)
	cape.scale = Vector3(0.7, 0.7, 0.7)


func _add_goblin_head(palette: Dictionary, skin: Color) -> void:
	var skin_mat := MeshLib.material(skin.to_html(false), 0.9)
	for side: float in [-1.0, 1.0]:
		var ear := MeshLib.add_cylinder(head_group, 0.1, 0.0, 0.32, Vector3(0.29 * side, 0.08, 0.01), skin_mat, "GoblinEar", 7)
		ear.rotation_degrees = Vector3(0.0, 0.0, -68.0 * side)
		MeshLib.add_box(head_group, Vector3(0.035, 0.035, 0.02), Vector3(0.072 * side, 0.03, -0.183), MeshLib.material("#f0d98c"), "GoblinEye")
	MeshLib.add_box(head_group, Vector3(0.075, 0.09, 0.09), Vector3(0.0, -0.045, -0.2), skin_mat, "GoblinNose")
	MeshLib.add_box(head_group, Vector3(0.16, 0.035, 0.04), Vector3(0.0, -0.12, -0.17), MeshLib.material("#3a2921"), "GoblinMouth")
	MeshLib.add_box(head_group, Vector3(0.05, 0.045, 0.02), Vector3(-0.045, -0.12, -0.2), MeshLib.material("#e8dfc0"), "GoblinTusk")
	MeshLib.add_box(head_group, Vector3(0.05, 0.045, 0.02), Vector3(0.045, -0.12, -0.2), MeshLib.material("#e8dfc0"), "GoblinTusk")
	# Crude leather cap with a feather.
	MeshLib.add_sphere(head_group, 0.205, Vector3(0.0, 0.085, 0.02), MeshLib.material(palette["dark"].to_html(false), 0.95), "GoblinCap", 0.25, 12)
	MeshLib.add_box(head_group, Vector3(0.05, 0.22, 0.04), Vector3(0.13, 0.27, 0.03), MeshLib.material(palette["accent"].to_html(false), 0.92), "GoblinFeather", Vector3(0.0, 0.0, 24.0))


func _build_skeleton(palette: Dictionary) -> void:
	var bone := Color("#b7b2a0")
	var dark := Color("#343139")
	_make_base(palette, bone, dark, false, Color("#29262d"))
	# Skeletal torso and ribs over the tunic.
	var bone_mat := MeshLib.material(bone.to_html(false), 0.92)
	MeshLib.add_cylinder(body_root, 0.24, 0.29, 0.55, Vector3(0.0, 1.14, -0.015), bone_mat, "SkeletonRibcage", 9)
	for i in 4:
		MeshLib.add_box(body_root, Vector3(0.36, 0.035, 0.04), Vector3(0.0, 0.94 + float(i) * 0.11, -0.25), bone_mat, "SkeletonRib")
	MeshLib.add_box(body_root, Vector3(0.09, 0.58, 0.06), Vector3(0.0, 1.14, -0.27), bone_mat, "SkeletonSpine")
	# Bare skull over the head.
	MeshLib.add_sphere(head_group, 0.2, Vector3(0.0, 0.02, -0.02), bone_mat, "Skull", 0.38, 12)
	MeshLib.add_box(head_group, Vector3(0.17, 0.1, 0.08), Vector3(0.0, -0.13, -0.17), MeshLib.material("#4c4942", 0.95), "SkullJaw")
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(head_group, Vector3(0.07, 0.055, 0.025), Vector3(0.065 * side, 0.0, -0.18), MeshLib.material("#1a171c"), "SkullSocket")
		MeshLib.add_sphere(head_group, 0.025, Vector3(0.065 * side, 0.0, -0.195), MeshLib.emissive("#8e6bd0", 1.0), "SkullEye", -1.0, 6)
	MeshLib.add_box(head_group, Vector3(0.035, 0.07, 0.04), Vector3(0.0, -0.06, -0.2), MeshLib.material("#504b43"), "SkullNose")
	# Tomb-guard pauldrons and a chipped sword.
	for side: float in [-1.0, 1.0]:
		_add_pauldron(Vector3(0.33 * side, 1.35, 0.0), Color("#6e6670"), palette["accent"])
	_add_sword(Vector3(0.48, 1.0, -0.02))
	_add_shield(Vector3(-0.46, 1.1, 0.0), Color("#4e4853"), palette["accent"], palette["primary"])
	cape.scale = Vector3(0.5, 0.45, 0.5)


func _build_wraith(palette: Dictionary) -> void:
	var dark := Color("#211a2b")
	_make_base(palette, Color("#83749a"), dark, true, Color("#1c1624"))
	_add_hood(palette["primary"], palette["dark"])
	for side: float in [-1.0, 1.0]:
		MeshLib.add_sphere(head_group, 0.035, Vector3(0.07 * side, 0.0, -0.19), MeshLib.emissive("#b58ee8", 2.0), "WraithEye", -1.0, 6)
	# Frayed spectral hem and a small soul lamp.
	for i in 5:
		var x := -0.32 + float(i) * 0.16
		var strip := MeshLib.add_box(body_root, Vector3(0.09, 0.7, 0.03), Vector3(x, 0.3, 0.02), MeshLib.transparent(palette["primary"].to_html(false), 0.6), "WraithTatter")
		strip.rotation_degrees = Vector3(0.0, 0.0, -8.0 + float(i) * 4.0)
	var lamp := Node3D.new()
	lamp.name = "SoulLamp"
	lamp.position = Vector3(-0.4, 1.0, 0.0)
	body_root.add_child(lamp)
	MeshLib.add_cylinder(lamp, 0.035, 0.025, 0.8, Vector3(0.0, 0.1, 0.0), MeshLib.material("#3b2b43", 0.9), "WraithStaff", 6)
	MeshLib.add_sphere(lamp, 0.11, Vector3(0.0, 0.55, 0.0), MeshLib.emissive("#a77be0", 2.0), "SoulOrb", -1.0, 10)
	MeshLib.add_omni_light(lamp, Vector3(0.0, 0.55, 0.0), "#9c6cdb", 1.1, 2.4, false)
	cape.scale = Vector3(1.0, 1.0, 1.0)


func _build_cultist(palette: Dictionary) -> void:
	_make_base(palette, Color("#b28d77"), palette["dark"], true, Color("#251b28"))
	_add_hood(palette["primary"], palette["dark"])
	_add_prayer_beads(palette["accent"])
	var staff := Node3D.new()
	staff.name = "CultStaff"
	staff.position = Vector3(-0.43, 0.98, -0.02)
	staff.rotation_degrees = Vector3(0.0, 0.0, 5.0)
	body_root.add_child(staff)
	MeshLib.add_cylinder(staff, 0.035, 0.05, 1.5, Vector3(0.0, 0.45, 0.0), MeshLib.material("#3a2b23", 0.92), "CultStaffShaft", 7)
	MeshLib.add_cylinder(staff, 0.12, 0.03, 0.22, Vector3(0.0, 1.23, 0.0), MeshLib.material("#6a4b34", 0.9), "CultStaffClaw", 6)
	MeshLib.add_sphere(staff, 0.14, Vector3(0.0, 1.4, 0.0), MeshLib.emissive("#cf5e72", 1.8), "CultOrb", -1.0, 12)
	MeshLib.add_omni_light(staff, Vector3(0.0, 1.4, 0.0), "#cf5e72", 1.2, 2.5, false)
	cape.scale = Vector3(0.9, 0.9, 0.9)


func _build_garland(palette: Dictionary) -> void:
	var steel := Color("#5c5964")
	var steel_dark := Color("#35323c")
	var red := Color("#8d3941")
	_make_base(palette, Color("#b7937f"), palette["dark"], false, Color("#2a242c"))
	body_root.scale = Vector3(1.12, 1.08, 1.12)
	_make_armor_cuirass(steel, palette["accent"])
	for side: float in [-1.0, 1.0]:
		_add_pauldron(Vector3(0.36 * side, 1.4, 0.0), steel_dark, palette["accent"])
	_add_helmet(red, steel)
	# Horned crown-helm.
	for side: float in [-1.0, 1.0]:
		var horn := MeshLib.add_cylinder(head_group, 0.06, 0.0, 0.42, Vector3(0.23 * side, 0.24, 0.02), MeshLib.material("#4d4651", 0.5, 0.35), "GarlandHorn", 6)
		horn.rotation_degrees = Vector3(0.0, 0.0, -38.0 * side)
	MeshLib.add_box(head_group, Vector3(0.3, 0.1, 0.04), Vector3(0.0, 0.06, -0.22), MeshLib.emissive("#9e4a52", 0.8), "GarlandVisor")
	# Heavy greatsword.
	var greatsword := Node3D.new()
	greatsword.name = "GarlandGreatsword"
	greatsword.position = Vector3(0.56, 1.02, -0.02)
	greatsword.rotation_degrees = Vector3(8.0, 0.0, -12.0)
	body_root.add_child(greatsword)
	MeshLib.add_cylinder(greatsword, 0.045, 0.035, 0.35, Vector3(0.0, -0.08, 0.0), MeshLib.material("#432d24", 0.92), "GreatswordGrip", 7)
	MeshLib.add_box(greatsword, Vector3(0.46, 0.08, 0.08), Vector3(0.0, 0.12, 0.0), MeshLib.material("#a38554", 0.4, 0.45), "GreatswordGuard")
	MeshLib.add_box(greatsword, Vector3(0.16, 1.25, 0.055), Vector3(0.0, 0.75, 0.0), MeshLib.material("#7e818c", 0.3, 0.65), "GreatswordBlade")
	MeshLib.add_box(greatsword, Vector3(0.07, 0.94, 0.062), Vector3(0.0, 0.68, 0.0), MeshLib.material("#c6c9cd", 0.22, 0.8), "GreatswordEdge")
	MeshLib.add_box(greatsword, Vector3(0.38, 0.045, 0.06), Vector3(0.0, 0.26, 0.0), MeshLib.material(red.to_html(false), 0.85), "GreatswordRune")
	# Long torn crimson cape.
	var cape_overlay := MeshLib.add_box(cape, Vector3(0.7, 1.1, 0.035), Vector3(0.0, -0.48, 0.05), MeshLib.material(red.to_html(false), 0.88), "GarlandCape")
	cape_overlay.rotation_degrees = Vector3(0.12, 0.0, 0.0)
	cape.scale = Vector3(1.0, 1.05, 1.0)
	_add_belt_pouches(palette["dark"])


func _build_sarah(palette: Dictionary) -> void:
	var skin := Color("#e8c7b0")
	var hair := Color("#d8bb74")
	_make_base(palette, skin, palette["dark"], true, Color("#d8d0df"))
	# Long pale-blue skirt with gold trim.
	var skirt_mat := MeshLib.material("#d8d5e8", 0.9)
	MeshLib.add_cylinder(body_root, 0.5, 0.28, 1.05, Vector3(0.0, 0.52, 0.0), skirt_mat, "SarahSkirt", 14)
	MeshLib.add_cylinder(body_root, 0.52, 0.52, 0.055, Vector3(0.0, 0.05, 0.0), MeshLib.material("#c0a25f", 0.6, 0.2), "SarahHemTrim", 14)
	MeshLib.add_cylinder(body_root, 0.31, 0.33, 0.14, Vector3(0.0, 1.44, 0.0), MeshLib.material("#c7a25f", 0.5, 0.3), "SarahCollar", 10)
	MeshLib.add_box(body_root, Vector3(0.06, 0.9, 0.04), Vector3(0.0, 1.05, -0.31), MeshLib.material("#c7a25f", 0.55, 0.3), "SarahBodiceTrim")
	# Hair, circlet and a small crown.
	MeshLib.add_sphere(head_group, 0.215, Vector3(0.0, 0.14, 0.06), MeshLib.material(hair.to_html(false), 0.92), "SarahHair", 0.24, 14)
	MeshLib.add_sphere(head_group, 0.15, Vector3(0.0, 0.26, 0.1), MeshLib.material(hair.lightened(0.08).to_html(false), 0.9), "SarahHairTop", 0.2, 10)
	MeshLib.add_cylinder(head_group, 0.14, 0.11, 0.5, Vector3(0.0, -0.0, 0.18), MeshLib.material(hair.to_html(false), 0.92), "SarahHairBack", 8)
	for i in 3:
		var crown_x := -0.08 + float(i) * 0.08
		MeshLib.add_box(head_group, Vector3(0.035, 0.1, 0.035), Vector3(crown_x, 0.25, -0.05), MeshLib.material("#e2c36e", 0.35, 0.55), "SarahCrownPoint", Vector3(0.0, 0.0, 0.0))
	MeshLib.add_box(head_group, Vector3(0.26, 0.04, 0.06), Vector3(0.0, 0.19, -0.06), MeshLib.material("#e2c36e", 0.35, 0.55), "SarahCirclet")
	# Sleeves and hands.
	for side: float in [-1.0, 1.0]:
		MeshLib.add_cylinder(body_root, 0.12, 0.09, 0.42, Vector3(0.32 * side, 1.12, 0.0), MeshLib.material("#d8d5e8", 0.9), "SarahSleeve", 8)
		MeshLib.add_sphere(body_root, 0.075, Vector3(0.36 * side, 0.9, -0.02), MeshLib.material(skin.to_html(false), 0.9), "SarahHand", -1.0, 8)
	cape.scale = Vector3(0.6, 0.6, 0.6)


func _build_guard(npc: Dictionary) -> void:
	var palette := {
		"primary": Color("#496b8f"),
		"accent": Color(str(npc.get("accent", "#79a6cf"))),
		"dark": Color("#26323d")
	}
	var steel := Color("#89929b")
	var skin := Color("#c89674")
	var leather := Color("#45342b")
	_make_base(palette, skin, leather, false, Color("#4b3a32"))
	_make_armor_cuirass(steel, palette["accent"])
	_add_pauldron(Vector3(-0.34, 1.34, 0.0), steel, palette["accent"])
	_add_pauldron(Vector3(0.34, 1.34, 0.0), steel, palette["accent"])
	_add_helmet(palette["accent"], steel, false)
	_add_spear(Vector3(0.48, 0.0, 0.06), Color("#7e5d38"), steel)
	_add_tabard(palette["primary"], palette["accent"])
	_add_belt_pouches(leather)


func _build_king(npc: Dictionary) -> void:
	var palette := {
		"primary": Color("#7c2230"),
		"accent": Color(str(npc.get("accent", "#e0b75c"))),
		"dark": Color("#3c1d22")
	}
	var skin := Color("#d5a27d")
	var fur := Color("#e6ded0")
	_robe = true
	_make_base(palette, skin, palette["primary"], true, palette["primary"])
	MeshLib.add_cylinder(body_root, 0.42, 0.27, 1.25, Vector3(0.0, 0.65, 0.0), MeshLib.material("#8d2838", 0.86), "RoyalRobe", 12)
	MeshLib.add_cylinder(body_root, 0.43, 0.31, 0.36, Vector3(0.0, 1.25, 0.0), MeshLib.material("#a58548", 0.65, 0.1), "RoyalMantle", 12)
	MeshLib.add_box(body_root, Vector3(1.1, 0.06, 0.5), Vector3(0.0, 1.42, 0.03), MeshLib.material(fur.to_html(false), 0.95), "FurCollar")
	MeshLib.add_box(body_root, Vector3(0.15, 1.2, 0.05), Vector3(0.0, 0.72, -0.35), MeshLib.material(palette["accent"].to_html(false), 0.6, 0.2), "RobeTrim")
	_add_crown(palette["accent"])
	_add_beard(fur)
	_add_scepter(Vector3(0.45, 0.0, 0.0), palette["accent"])
	_make_contact_shadow(0.5, Color(0.05, 0.04, 0.04, 0.34))


func _build_resident(npc: Dictionary) -> void:
	var palette := {
		"primary": Color("#6c7a4c"),
		"accent": Color(str(npc.get("accent", "#9fbf83"))),
		"dark": Color("#3f3b2b")
	}
	var skin := Color("#c18b66")
	var leather := Color("#4a3628")
	_make_base(palette, skin, leather, false, Color("#4e664c"))
	_make_tunic_overlay(Color("#6d7d4f"), 0.9)
	MeshLib.add_box(body_root, Vector3(0.44, 0.1, 0.34), Vector3(0.0, 0.92, 0.0), MeshLib.material(leather.to_html(false)), "Belt")
	_add_peasant_hat(palette["dark"])
	_add_belt_pouches(leather)


# ---------------------------------------------------------------------------
# Shared body construction
# ---------------------------------------------------------------------------

func _make_base(palette: Dictionary, skin: Color, trousers: Color, robe: bool, boot_color: Color) -> void:
	body_root = Node3D.new()
	body_root.name = "Body"
	add_child(body_root)

	var primary: Color = palette["primary"]
	var accent: Color = palette["accent"]
	var dark: Color = palette["dark"]

	if not robe:
		leg_l = _make_leg(-1.0, trousers, boot_color, skin)
		leg_r = _make_leg(1.0, trousers, boot_color, skin)
	else:
		# Legs remain hidden under the robe; pivots still give the gait some life.
		leg_l = Node3D.new()
		leg_l.position = Vector3(-0.14, 0.84, 0.0)
		body_root.add_child(leg_l)
		leg_r = Node3D.new()
		leg_r.position = Vector3(0.14, 0.84, 0.0)
		body_root.add_child(leg_r)

	# Tunic / torso.
	var torso_mat := MeshLib.material(primary.to_html(false), 0.88)
	MeshLib.add_cylinder(body_root, 0.26, 0.31, 0.66, Vector3(0.0, 1.12, 0.0), torso_mat, "Torso", 10)
	MeshLib.add_cylinder(body_root, 0.315, 0.29, 0.12, Vector3(0.0, 1.4, 0.0), MeshLib.material(primary.darkened(0.08).to_html(false), 0.92), "Collar", 10)
	# Belt with a small buckle.
	MeshLib.add_cylinder(body_root, 0.28, 0.28, 0.1, Vector3(0.0, 0.83, 0.0), MeshLib.material(dark.to_html(false), 0.95), "Belt", 10)
	MeshLib.add_box(body_root, Vector3(0.1, 0.09, 0.035), Vector3(0.0, 0.83, -0.275), MeshLib.material(accent.to_html(false), 0.45, 0.35), "Buckle")

	# Arms.
	arm_l = _make_arm(-1.0, primary, skin, accent)
	arm_r = _make_arm(1.0, primary, skin, accent)

	# Neck and head.
	MeshLib.add_cylinder(body_root, 0.075, 0.085, 0.14, Vector3(0.0, 1.51, 0.0), MeshLib.material(skin.to_html(false), 0.9), "Neck", 8)
	head_group = Node3D.new()
	head_group.name = "Head"
	head_group.position = Vector3(0.0, 1.68, 0.0)
	body_root.add_child(head_group)
	MeshLib.add_sphere(head_group, 0.2, Vector3.ZERO, MeshLib.material(skin.to_html(false), 0.9), "HeadSphere", 0.42, 14)
	# Eyes, nose and brows keep the characters readable from a high camera.
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(head_group, Vector3(0.035, 0.03, 0.025), Vector3(0.072 * side, 0.02, -0.183), MeshLib.material("#2b211d"), "Eye")
		MeshLib.add_box(head_group, Vector3(0.055, 0.013, 0.015), Vector3(0.076 * side, 0.08, -0.177), MeshLib.material("#4d3629"), "Brow")
	MeshLib.add_box(head_group, Vector3(0.035, 0.055, 0.03), Vector3(0.0, -0.03, -0.198), MeshLib.material(skin.darkened(0.06).to_html(false)), "Nose")

	# Cape or mantle.
	cape = Node3D.new()
	cape.name = "CapePivot"
	cape.position = Vector3(0.0, 1.39, 0.18)
	body_root.add_child(cape)
	MeshLib.add_box(cape, Vector3(0.55, 0.9, 0.035), Vector3(0.0, -0.44, 0.04), MeshLib.material(dark.to_html(false), 0.92), "Cape", Vector3(0.12, 0.0, 0.0))
	MeshLib.add_box(cape, Vector3(0.58, 0.06, 0.045), Vector3(0.0, -0.01, 0.015), MeshLib.material(accent.to_html(false), 0.55, 0.15), "CapeClasp")


func _make_leg(side: float, trousers: Color, boot_color: Color, _skin: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "LegL" if side < 0.0 else "LegR"
	pivot.position = Vector3(0.13 * side, 0.83, 0.0)
	body_root.add_child(pivot)
	MeshLib.add_cylinder(pivot, 0.09, 0.105, 0.55, Vector3(0.0, -0.28, 0.0), MeshLib.material(trousers.to_html(false), 0.95), "Trouser", 8)
	MeshLib.add_box(pivot, Vector3(0.17, 0.16, 0.3), Vector3(0.0, -0.65, -0.06), MeshLib.material(boot_color.to_html(false), 0.92), "Boot")
	MeshLib.add_box(pivot, Vector3(0.18, 0.05, 0.33), Vector3(0.0, -0.73, -0.07), MeshLib.material("#2a211e"), "Sole")
	return pivot


func _make_arm(side: float, sleeve_color: Color, skin: Color, accent: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "ArmL" if side < 0.0 else "ArmR"
	pivot.position = Vector3(0.33 * side, 1.32, 0.0)
	body_root.add_child(pivot)
	MeshLib.add_cylinder(pivot, 0.085, 0.1, 0.46, Vector3(0.0, -0.24, 0.0), MeshLib.material(sleeve_color.darkened(0.06).to_html(false), 0.9), "UpperArm", 8)
	MeshLib.add_cylinder(pivot, 0.07, 0.075, 0.26, Vector3(0.0, -0.55, -0.02), MeshLib.material(sleeve_color.darkened(0.12).to_html(false), 0.9), "Forearm", 8)
	MeshLib.add_sphere(pivot, 0.084, Vector3(0.0, -0.68, -0.03), MeshLib.material(skin.to_html(false), 0.9), "Hand", -1.0, 8)
	MeshLib.add_cylinder(pivot, 0.086, 0.086, 0.05, Vector3(0.0, -0.62, -0.02), MeshLib.material(accent.to_html(false), 0.7), "Cuff", 8)
	return pivot


func _make_armor_cuirass(steel: Color, accent: Color) -> void:
	MeshLib.add_cylinder(body_root, 0.285, 0.33, 0.5, Vector3(0.0, 1.17, -0.015), MeshLib.material(steel.to_html(false), 0.38, 0.55), "Cuirass", 10)
	MeshLib.add_box(body_root, Vector3(0.22, 0.2, 0.04), Vector3(0.0, 1.22, -0.28), MeshLib.material(steel.lightened(0.12).to_html(false), 0.35, 0.6), "Breastplate")
	MeshLib.add_box(body_root, Vector3(0.07, 0.42, 0.035), Vector3(0.0, 1.14, -0.3), MeshLib.material(accent.to_html(false), 0.4, 0.45), "ChestTrim")
	MeshLib.add_cylinder(body_root, 0.32, 0.32, 0.06, Vector3(0.0, 0.9, 0.0), MeshLib.material("#4b352b"), "ArmorBelt", 10)


func _make_tunic_overlay(color: Color, scale_factor: float) -> void:
	MeshLib.add_cylinder(body_root, 0.23 * scale_factor, 0.29 * scale_factor, 0.5, Vector3(0.0, 1.15, -0.01), MeshLib.material(color.to_html(false), 0.94), "Tunic", 10)


func _add_pauldron(pos: Vector3, metal: Color, accent: Color) -> void:
	var mat := MeshLib.material(metal.to_html(false), 0.42, 0.45)
	MeshLib.add_sphere(body_root, 0.145, pos, mat, "Pauldron", 0.18, 10)
	MeshLib.add_cylinder(body_root, 0.16, 0.11, 0.08, pos + Vector3(0.0, 0.04, 0.0), mat, "PauldronPlate", 8)
	MeshLib.add_cylinder(body_root, 0.15, 0.15, 0.025, pos + Vector3(0.0, -0.03, 0.0), MeshLib.material(accent.to_html(false), 0.45, 0.3), "PauldronTrim", 8)


func _add_helmet(plume_color: Color, steel: Color, plume: bool = true) -> void:
	MeshLib.add_sphere(head_group, 0.215, Vector3(0.0, 0.065, 0.02), MeshLib.material(steel.to_html(false), 0.35, 0.6), "HelmetDome", 0.3, 12)
	MeshLib.add_cylinder(head_group, 0.218, 0.218, 0.055, Vector3(0.0, -0.015, 0.015), MeshLib.material(steel.darkened(0.15).to_html(false), 0.4, 0.55), "HelmetBrow", 12)
	MeshLib.add_box(head_group, Vector3(0.045, 0.17, 0.045), Vector3(0.0, 0.0, -0.19), MeshLib.material(steel.to_html(false), 0.32, 0.65), "NasalGuard")
	MeshLib.add_box(head_group, Vector3(0.05, 0.05, 0.72), Vector3(0.0, 0.19, 0.02), MeshLib.material(plume_color.to_html(false), 0.9), "HelmetRidge")
	if plume:
		MeshLib.add_box(head_group, Vector3(0.12, 0.13, 0.36), Vector3(0.0, 0.26, 0.11), MeshLib.material(plume_color.to_html(false), 0.92), "Plume")
		MeshLib.add_box(head_group, Vector3(0.07, 0.09, 0.26), Vector3(0.0, 0.33, 0.27), MeshLib.material(plume_color.lightened(0.1).to_html(false), 0.92), "PlumeTip", Vector3(-0.35, 0.0, 0.0))


func _add_sword(hand_pos: Vector3) -> void:
	var group := Node3D.new()
	group.name = "Sword"
	group.position = hand_pos
	group.rotation_degrees = Vector3(10.0, 0.0, -14.0)
	body_root.add_child(group)
	MeshLib.add_cylinder(group, 0.032, 0.03, 0.24, Vector3(0.0, -0.08, 0.0), MeshLib.material("#4b2e1f"), "Hilt", 6)
	MeshLib.add_box(group, Vector3(0.24, 0.045, 0.05), Vector3(0.0, 0.06, 0.0), MeshLib.material("#c8a459", 0.45, 0.35), "Crossguard")
	MeshLib.add_box(group, Vector3(0.075, 0.92, 0.022), Vector3(0.0, -0.5, 0.0), MeshLib.material("#ccd3d8", 0.24, 0.8), "Blade")
	MeshLib.add_box(group, Vector3(0.035, 0.7, 0.028), Vector3(0.0, -0.46, 0.0), MeshLib.material("#eff5f7", 0.18, 0.9), "BladeHighlight")
	MeshLib.add_sphere(group, 0.05, Vector3(0.0, 0.02, 0.0), MeshLib.material("#e5c363", 0.35, 0.5), "Pommel", -1.0, 8)


func _add_shield(pos: Vector3, steel: Color, accent: Color, face_color: Color) -> void:
	var group := Node3D.new()
	group.name = "Shield"
	group.position = pos
	group.rotation_degrees = Vector3(0.0, 0.0, 86.0)
	body_root.add_child(group)
	MeshLib.add_cylinder(group, 0.31, 0.31, 0.07, Vector3.ZERO, MeshLib.material(steel.to_html(false), 0.45, 0.45), "ShieldDisc", 12)
	MeshLib.add_cylinder(group, 0.24, 0.24, 0.075, Vector3(0.0, 0.012, 0.0), MeshLib.material(face_color.to_html(false), 0.55, 0.3), "ShieldFace", 12)
	MeshLib.add_sphere(group, 0.08, Vector3(0.0, 0.05, 0.0), MeshLib.material(accent.to_html(false), 0.3, 0.6), "ShieldBoss", 0.09, 8)
	for i in 6:
		var angle := TAU * float(i) / 6.0
		MeshLib.add_sphere(group, 0.018, Vector3(cos(angle) * 0.16, 0.045, sin(angle) * 0.16), MeshLib.material(accent.to_html(false), 0.3, 0.6), "Rivet", -1.0, 6)


func _add_dagger(pos: Vector3, accent: Color, left: bool) -> void:
	var group := Node3D.new()
	group.name = "Dagger"
	group.position = pos
	group.rotation_degrees = Vector3(0.0, 0.0, 25.0 if left else -25.0)
	body_root.add_child(group)
	MeshLib.add_cylinder(group, 0.022, 0.02, 0.18, Vector3(0.0, -0.02, 0.0), MeshLib.material("#4b3426"), "DaggerGrip", 6)
	MeshLib.add_box(group, Vector3(0.13, 0.032, 0.035), Vector3(0.0, 0.08, 0.0), MeshLib.material(accent.to_html(false), 0.4, 0.3), "DaggerGuard")
	MeshLib.add_box(group, Vector3(0.045, 0.38, 0.018), Vector3(0.0, 0.28, 0.0), MeshLib.material("#cbd2d4", 0.25, 0.8), "DaggerBlade")
	MeshLib.add_sphere(group, 0.03, Vector3(0.0, -0.12, 0.0), MeshLib.material(accent.to_html(false), 0.4, 0.3), "DaggerPommel", -1.0, 6)


func _add_hood(primary: Color, dark: Color) -> void:
	MeshLib.add_cylinder(head_group, 0.25, 0.03, 0.36, Vector3(0.0, 0.2, 0.03), MeshLib.material(primary.darkened(0.06).to_html(false), 0.95), "Hood", 8, Vector3(-12.0, 0.0, 0.0))
	MeshLib.add_cylinder(head_group, 0.26, 0.27, 0.09, Vector3(0.0, -0.02, 0.0), MeshLib.material(primary.to_html(false), 0.95), "HoodCollar", 10)
	MeshLib.add_box(head_group, Vector3(0.28, 0.1, 0.055), Vector3(0.0, -0.075, -0.17), MeshLib.material(dark.to_html(false), 0.95), "Mask")
	MeshLib.add_box(head_group, Vector3(0.1, 0.12, 0.06), Vector3(0.0, 0.12, -0.18), MeshLib.material(primary.lightened(0.05).to_html(false), 0.95), "HoodShadow")


func _add_scarf(accent: Color) -> void:
	var scarf := MeshLib.add_box(body_root, Vector3(0.4, 0.14, 0.3), Vector3(0.0, 1.44, 0.0), MeshLib.material(accent.to_html(false), 0.95), "Scarf")
	scarf.rotation_degrees = Vector3(0.0, 0.2, 0.0)
	var tail := MeshLib.add_box(body_root, Vector3(0.11, 0.5, 0.03), Vector3(0.16, 1.22, 0.25), MeshLib.material(accent.to_html(false), 0.95), "ScarfTail")
	tail.rotation_degrees = Vector3(0.12, 0.0, -0.08)


func _add_belt_pouches(leather: Color) -> void:
	MeshLib.add_box(body_root, Vector3(0.17, 0.18, 0.12), Vector3(-0.24, 0.78, 0.04), MeshLib.material(leather.to_html(false), 0.95), "Pouch")
	MeshLib.add_sphere(body_root, 0.045, Vector3(-0.24, 0.87, -0.045), MeshLib.material("#b58b4b", 0.5, 0.2), "PouchClasp", -1.0, 6)


func _add_monk_head(accent: Color) -> void:
	MeshLib.add_sphere(head_group, 0.205, Vector3(0.0, 0.03, 0.0), MeshLib.material("#c68c61", 0.92), "BaldHead", 0.4, 12)
	MeshLib.add_cylinder(head_group, 0.212, 0.212, 0.055, Vector3(0.0, 0.07, 0.0), MeshLib.material(accent.to_html(false), 0.9), "Headband", 12)
	MeshLib.add_box(head_group, Vector3(0.08, 0.11, 0.02), Vector3(0.2, 0.06, 0.08), MeshLib.material(accent.to_html(false), 0.9), "HeadbandTail", Vector3(0.0, 0.0, 0.4))
	MeshLib.add_sphere(head_group, 0.07, Vector3(0.0, 0.22, 0.06), MeshLib.material("#3c2b25", 0.95), "Topknot", 0.1, 8)


func _add_prayer_beads(accent: Color) -> void:
	for i in 7:
		var angle := PI * 0.15 + PI * 0.7 * float(i) / 6.0
		MeshLib.add_sphere(body_root, 0.027, Vector3(cos(angle) * 0.23, 1.18 + sin(angle) * 0.16, -0.26), MeshLib.material(accent.to_html(false), 0.45, 0.2), "Bead", -1.0, 6)


func _add_mage_hat(robe: Color, blue: Color, gold: Color) -> void:
	MeshLib.add_cylinder(head_group, 0.37, 0.37, 0.035, Vector3(0.0, 0.16, 0.0), MeshLib.material(robe.to_html(false), 0.9), "HatBrim", 16)
	MeshLib.add_cylinder(head_group, 0.225, 0.03, 0.42, Vector3(0.0, 0.38, 0.02), MeshLib.material(robe.to_html(false), 0.9), "HatCone", 12, Vector3(-8.0, 0.0, -4.0))
	MeshLib.add_cylinder(head_group, 0.235, 0.235, 0.07, Vector3(0.0, 0.2, 0.01), MeshLib.material(blue.to_html(false), 0.8), "HatBand", 12)
	MeshLib.add_box(head_group, Vector3(0.08, 0.1, 0.02), Vector3(0.0, 0.22, -0.2), MeshLib.material(gold.to_html(false), 0.4, 0.3), "HatGem")
	MeshLib.add_sphere(head_group, 0.028, Vector3(0.0, 0.22, -0.212), MeshLib.material("#78a8d8"), "HatGemBlue", -1.0, 6)


func _add_staff(pos: Vector3, gold: Color, blue: Color) -> void:
	staff_group = Node3D.new()
	staff_group.name = "Staff"
	staff_group.position = pos
	body_root.add_child(staff_group)
	MeshLib.add_cylinder(staff_group, 0.035, 0.03, 2.05, Vector3(0.0, 1.02, 0.0), MeshLib.material("#7d5a36", 0.85), "StaffShaft", 8)
	MeshLib.add_cylinder(staff_group, 0.055, 0.055, 0.08, Vector3(0.0, 1.75, 0.0), MeshLib.material(gold.to_html(false), 0.4, 0.4), "StaffBand", 8)
	var orb := MeshLib.add_sphere(staff_group, 0.14, Vector3(0.0, 2.2, 0.0), MeshLib.emissive(blue.lightened(0.28).to_html(false), 1.9), "StaffOrb", 0.28, 12)
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 2.2, 0.0)
	light.light_color = blue.lightened(0.35)
	light.light_energy = 0.65
	light.omni_range = 3.2
	light.shadow_enabled = false
	staff_group.add_child(light)


func _add_tabard(primary: Color, accent: Color) -> void:
	MeshLib.add_box(body_root, Vector3(0.45, 0.7, 0.035), Vector3(0.0, 0.98, 0.28), MeshLib.material(primary.to_html(false), 0.94), "TabardBack")
	MeshLib.add_box(body_root, Vector3(0.38, 0.46, 0.035), Vector3(0.0, 0.87, -0.29), MeshLib.material(primary.to_html(false), 0.94), "TabardFront")
	MeshLib.add_box(body_root, Vector3(0.08, 0.34, 0.04), Vector3(0.0, 0.86, -0.3), MeshLib.material(accent.to_html(false), 0.5, 0.2), "TabardStripe")


func _add_spear(pos: Vector3, wood: Color, steel: Color) -> void:
	var group := Node3D.new()
	group.name = "Spear"
	group.position = pos
	group.rotation_degrees = Vector3(0.0, 0.0, -6.0)
	body_root.add_child(group)
	MeshLib.add_cylinder(group, 0.027, 0.024, 2.35, Vector3(0.0, 1.2, 0.0), MeshLib.material(wood.to_html(false), 0.9), "Shaft", 6)
	MeshLib.add_box(group, Vector3(0.075, 0.34, 0.04), Vector3(0.0, 2.48, 0.0), MeshLib.material(steel.to_html(false), 0.3, 0.75), "Spearhead")
	MeshLib.add_box(group, Vector3(0.14, 0.06, 0.08), Vector3(0.0, 2.3, 0.0), MeshLib.material("#c9a45d", 0.4, 0.3), "SpearCollar")
	MeshLib.add_box(group, Vector3(0.16, 0.28, 0.03), Vector3(0.0, 2.55, 0.1), MeshLib.material("#7fa2c2", 0.8), "SpearPennant")


func _add_crown(gold: Color) -> void:
	MeshLib.add_cylinder(head_group, 0.215, 0.205, 0.1, Vector3(0.0, 0.22, 0.0), MeshLib.material(gold.to_html(false), 0.28, 0.72), "CrownBand", 10)
	for i in 5:
		var angle := TAU * float(i) / 5.0
		MeshLib.add_cylinder(head_group, 0.032, 0.004, 0.16, Vector3(cos(angle) * 0.18, 0.34, sin(angle) * 0.18), MeshLib.material(gold.to_html(false), 0.3, 0.7), "CrownSpike", 6)
	MeshLib.add_sphere(head_group, 0.035, Vector3(0.0, 0.18, -0.2), MeshLib.material("#b93a47", 0.3, 0.2), "CrownJewel", -1.0, 8)
	MeshLib.add_box(head_group, Vector3(0.36, 0.06, 0.36), Vector3(0.0, 0.18, 0.0), MeshLib.material("#e2c574", 0.3, 0.65), "CrownCap")


func _add_beard(fur: Color) -> void:
	var beard := MeshLib.add_cylinder(head_group, 0.15, 0.02, 0.36, Vector3(0.0, -0.2, -0.14), MeshLib.material(fur.to_html(false), 0.98), "Beard", 7, Vector3(-10.0, 0.0, 0.0))
	beard.scale = Vector3(1.0, 1.0, 0.55)
	MeshLib.add_box(head_group, Vector3(0.22, 0.05, 0.04), Vector3(0.0, -0.02, -0.18), MeshLib.material(fur.to_html(false), 0.98), "Mustache")


func _add_scepter(pos: Vector3, gold: Color) -> void:
	var group := Node3D.new()
	group.name = "Scepter"
	group.position = pos
	group.rotation_degrees = Vector3(0.0, 0.0, -5.0)
	body_root.add_child(group)
	MeshLib.add_cylinder(group, 0.025, 0.023, 1.5, Vector3(0.0, 0.78, 0.0), MeshLib.material(gold.to_html(false), 0.35, 0.6), "ScepterShaft", 6)
	MeshLib.add_sphere(group, 0.12, Vector3(0.0, 1.58, 0.0), MeshLib.emissive("#f0cc76", 0.9), "ScepterOrb", 0.22, 10)
	MeshLib.add_cylinder(group, 0.07, 0.04, 0.12, Vector3(0.0, 1.45, 0.0), MeshLib.material(gold.to_html(false), 0.3, 0.6), "ScepterCup", 8)


func _add_peasant_hat(color: Color) -> void:
	MeshLib.add_cylinder(head_group, 0.28, 0.28, 0.035, Vector3(0.0, 0.16, 0.0), MeshLib.material(color.lightened(0.15).to_html(false), 0.98), "HatBrim", 12)
	MeshLib.add_cylinder(head_group, 0.19, 0.15, 0.13, Vector3(0.0, 0.23, 0.0), MeshLib.material(color.to_html(false), 0.98), "HatCrown", 10)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_contact_shadow(radius: float, color: Color) -> void:
	var plane := MeshLib.add_plane(self, Vector2(radius * 2.0, radius * 2.0), Vector3(0.0, 0.025, 0.0), _shadow_material(color), "ContactShadow")
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _shadow_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return mat


func _make_interaction_marker() -> void:
	marker = Node3D.new()
	marker.name = "InteractionMarker"
	marker.position = Vector3(0.0, 2.55, 0.0)
	add_child(marker)
	var mat := MeshLib.emissive("#f2d087", 1.4)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 0.14
	mesh.height = 0.22
	mesh.radial_segments = 4
	var top := MeshInstance3D.new()
	top.mesh = mesh
	top.material_override = mat
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.add_child(top)
	var bottom := MeshInstance3D.new()
	bottom.mesh = mesh
	bottom.material_override = mat
	bottom.rotation_degrees = Vector3(180.0, 0.0, 0.0)
	bottom.position.y = -0.22
	bottom.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.add_child(bottom)
	# A readable exclamation mark makes NPC talk affordance obvious from afar.
	var glyph := Label3D.new()
	glyph.name = "TalkGlyph"
	glyph.text = "!"
	glyph.font_size = 96
	glyph.pixel_size = 0.009
	glyph.modulate = Color("#f6d68b")
	glyph.outline_modulate = Color("#24170e")
	glyph.outline_size = 14
	glyph.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	glyph.position = Vector3(0.0, 0.48, 0.0)
	glyph.no_depth_test = false
	marker.add_child(glyph)
