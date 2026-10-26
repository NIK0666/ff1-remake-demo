extends Node

var main: GameMain


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while not main.gameplay_ready:
		await get_tree().process_frame
	GameState.encounters_enabled = false

	await main.test_start_battle("bridge_patrol")
	var victory_battle := main.battle_scene
	while victory_battle == null or victory_battle.phase != "command":
		await get_tree().process_frame
	for enemy: BattleUnit in victory_battle.enemies:
		enemy.enemy_hp = 0
	victory_battle._check_battle_end()
	while victory_battle.phase != "victory":
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var victory_image := get_viewport().get_texture().get_image()
	victory_image.save_png("res://screenshots/14_victory.png")
	print("[ENDING-CAPTURE] saved res://screenshots/14_victory.png")
	victory_battle.test_confirm_selection()
	while main.battle_active:
		await get_tree().process_frame

	await main.test_start_battle("bridge_patrol")
	var defeat_battle := main.battle_scene
	while defeat_battle == null or defeat_battle.phase != "command":
		await get_tree().process_frame
	for member_id: String in ["brandt", "shade", "kai", "lira"]:
		GameState.set_member_hp(member_id, 0)
	defeat_battle._check_battle_end()
	while defeat_battle.phase != "defeat":
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var defeat_image := get_viewport().get_texture().get_image()
	defeat_image.save_png("res://screenshots/15_party_defeated.png")
	print("[ENDING-CAPTURE] saved res://screenshots/15_party_defeated.png")
	get_tree().quit(0)
