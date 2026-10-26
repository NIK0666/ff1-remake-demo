extends Node

var main: GameMain


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while not main.gameplay_ready:
		await get_tree().process_frame
	GameState.encounters_enabled = false
	GameState.inventory["bronze_sword"] = 1
	GameState.inventory["iron_dagger"] = 1
	GameState.inventory["leather_armor"] = 1
	GameState.inventory["cloth_robe"] = 1
	GameState.inventory["oak_staff"] = 1
	GameState.equip_item("brandt", "weapon", "bronze_sword")
	GameState.equip_item("brandt", "armor", "leather_armor")
	await get_tree().process_frame
	main.test_open_equipment()
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("res://screenshots/12_equipment.png")
	print("[EQUIP-CAPTURE] saved res://screenshots/12_equipment.png (%dx%d)" % [image.get_width(), image.get_height()])
	main.test_equipment_confirm()
	await get_tree().create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	var choice := get_viewport().get_texture().get_image()
	choice.save_png("res://screenshots/24_equipment_choice.png")
	print("[EQUIP-CAPTURE] saved res://screenshots/24_equipment_choice.png")
	get_tree().quit(0)
