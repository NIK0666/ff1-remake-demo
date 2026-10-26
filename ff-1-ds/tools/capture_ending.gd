extends Node


func _ready() -> void:
	var ending: DemoEnding = load("res://scenes/ending.tscn").instantiate()
	add_child(ending)
	await get_tree().create_timer(0.8).timeout
	var slab: Node3D = ending.get_node_or_null("EndingFinalSlab")
	print("[ENDING-CAPTURE] slab=", slab, " pos=", slab.position if slab else Vector3.ZERO, " visible=", slab.visible if slab else false, " children=", slab.get_child_count() if slab else -1)
	await get_tree().create_timer(3.4).timeout
	print("[ENDING-CAPTURE] later pos=", slab.position if slab else Vector3.ZERO, " screen=", ending.get_node("EndingCamera").unproject_position(slab.global_position) if ending.has_node("EndingCamera") and slab else Vector2.ZERO)
	await _shot("20_bridge_construction.png")
	while not ending.is_final_visible():
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	await _shot("21_demo_complete.png")
	print("[ENDING-CAPTURE] done")
	get_tree().quit(0)


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("res://screenshots/%s" % file_name)
	print("[ENDING-CAPTURE] saved %s" % file_name)
