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
	await get_tree().create_timer(0.3).timeout
	battle._begin_target_select("АТАКА", battle._living(battle.enemies))
	await get_tree().create_timer(0.25).timeout
	print("[BATTLE-STATES] target ring=", battle.is_target_ring_visible(), " label=", battle.get_unit_label_text(battle.enemies[0]), " action=", battle.hud.get_action_text())
	await _shot("22_battle_target.png")
	battle._cancel_target()
	await get_tree().process_frame
	GameState.party[2]["hp"] = 0
	GameState.party_status_changed.emit()
	battle._mark_ko(battle.heroes[2])
	await get_tree().create_timer(0.5).timeout
	print("[BATTLE-STATES] fallen label=", battle.get_unit_label_text(battle.heroes[2]), " rotation=", battle.heroes[2].visual.rotation_degrees, " scale=", battle.heroes[2].visual.scale)
	await _shot("23_battle_fallen.png")
	get_tree().quit(0)


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("res://screenshots/%s" % file_name)
	print("[BATTLE-STATES] saved %s" % file_name)
