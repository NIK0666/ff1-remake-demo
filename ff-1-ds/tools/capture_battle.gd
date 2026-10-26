extends Node

var main: GameMain


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while not main.gameplay_ready:
		await get_tree().process_frame
	GameState.encounters_enabled = false
	GameState.inventory["potion"] = 2
	GameState.party_status_changed.emit()
	await main.test_start_battle("bridge_patrol")
	var battle := main.battle_scene
	while battle == null or battle.phase != "command":
		await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("res://screenshots/11_bridge_battle.png")
	print("[BATTLE-CAPTURE] saved res://screenshots/11_bridge_battle.png (%dx%d)" % [image.get_width(), image.get_height()])
	get_tree().quit(0)
