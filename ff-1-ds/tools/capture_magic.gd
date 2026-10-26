extends Node

var main: GameMain


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while not main.gameplay_ready:
		await get_tree().process_frame
	GameState.encounters_enabled = false
	await main.test_start_battle("bridge_patrol")
	var battle := main.battle_scene
	while battle == null or battle.phase != "command":
		await get_tree().process_frame
	for enemy: BattleUnit in battle.enemies:
		enemy.enemy_data["max_hp"] = 500
		enemy.enemy_hp = 500
	var guard := 0
	while battle != null and not battle.battle_over and battle.active_unit != null and battle.active_unit.member_id != "lira" and guard < 30:
		if battle.phase == "command":
			battle.test_confirm_selection()
			await get_tree().process_frame
			if battle.phase == "target":
				battle.test_confirm_selection()
			guard += 1
		await get_tree().create_timer(0.12).timeout
	while battle != null and battle.phase != "command":
		await get_tree().process_frame
	if battle != null and battle.active_unit != null and battle.active_unit.member_id == "lira":
		battle.test_move_selection(1)
		battle.test_confirm_selection()
		while battle.phase != "spell":
			await get_tree().process_frame
		await get_tree().create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.save_png("res://screenshots/13_white_magic.png")
		print("[MAGIC-CAPTURE] saved res://screenshots/13_white_magic.png (%dx%d)" % [image.get_width(), image.get_height()])
	else:
		print("[MAGIC-CAPTURE] Lira turn was not reached")
	get_tree().quit(0)
