extends Node

var main: GameMain


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while not main.gameplay_ready:
		await get_tree().process_frame
	GameState.encounters_enabled = false
	GameState.mark_flag("king_spoken")
	await main._load_location("chaos_shrine_1", "entry", "", false)
	await get_tree().create_timer(3.6).timeout
	for i in 6:
		main.test_try_step(Vector2i(0, -1))
		await get_tree().process_frame
	await get_tree().create_timer(1.2).timeout
	await _shot("16_shrine_floor1.png")
	await main._load_location("chaos_shrine_2", "from_floor1", "", false)
	await get_tree().create_timer(3.6).timeout
	for i in 8:
		main.test_try_step(Vector2i(0, -1))
		await get_tree().process_frame
	await get_tree().create_timer(1.2).timeout
	await _shot("17_shrine_boss_room.png")
	await main._start_boss({"boss_id": "garland"})
	var battle := main.battle_scene
	while battle == null or battle.phase != "command":
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	await _shot("18_garland_battle.png")
	for enemy: BattleUnit in battle.enemies:
		enemy.enemy_hp = 0
	battle._check_battle_end()
	while battle.phase != "victory":
		await get_tree().process_frame
	battle.test_confirm_selection()
	while main.battle_active:
		await get_tree().process_frame
	while not main.hud.is_story_open():
		await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	main.hud.advance_dialogue()
	await get_tree().create_timer(0.3).timeout
	await _shot("19_sarah_rescue.png")
	print("[SHRINE-CAPTURE] done")
	get_tree().quit(0)


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("res://screenshots/%s" % file_name)
	print("[SHRINE-CAPTURE] saved %s" % file_name)
