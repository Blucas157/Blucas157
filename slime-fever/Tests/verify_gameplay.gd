extends SceneTree
var checks: int = 0
func _initialize() -> void:
	call_deferred("run_tests")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: " + message)
		quit(1)
	checks += 1
func run_tests() -> void:
	var scene = load("res://Assets/Cenas/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene._start_game()
	await process_frame
	var gm = root.get_node("GameManager")
	gm.save_path = OS.get_environment("SLIME_TEST_SAVE") if OS.has_environment("SLIME_TEST_SAVE") else "user://test-regression-save.cfg"
	gm.best = 0
	var player = scene.get_node("Player")
	scene.get_node("Spawner").set_process(false)
	for item in scene.get_children():
		if item is Area2D and item != player:
			item.queue_free()
	var before: float = player.position.x
	Input.action_press("ui_right")
	await create_timer(0.12).timeout
	Input.action_release("ui_right")
	check(player.position.x > before, "right direction")
	var before_left: float = player.position.x
	Input.action_press("ui_left")
	await create_timer(0.12).timeout
	Input.action_release("ui_left")
	check(player.position.x < before_left, "left direction")
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = root.get_final_transform() * Vector2(205, 1810)
	touch.pressed = true
	Input.parse_input_event(touch)
	await process_frame
	check(player.get_direction() == -1, "touch press")
	touch = InputEventScreenTouch.new()
	touch.index = 0
	touch.position = root.get_final_transform() * Vector2(205, 1810)
	touch.pressed = false
	Input.parse_input_event(touch)
	await process_frame
	check(player.get_direction() == 0, "touch release")
	var coin = load("res://Assets/Cenas/moeda.tscn").instantiate()
	coin.position = Vector2(100, 100)
	scene.add_child(coin)
	coin._on_area_entered(player)
	coin._on_area_entered(player)
	check(gm.score == 10 and gm.coins == 1 and not gm.ended, "coin idempotency")
	for i in 19:
		gm.collect_coin()
	check(gm.fever_left > 0.0 and gm.charge == 0.0 and gm.multiplier == 4, "fever and combo")
	var bomb = load("res://Assets/Cenas/bomba.tscn").instantiate()
	bomb.position = Vector2(100, 100)
	scene.add_child(bomb)
	var score_before: int = gm.score
	bomb._on_area_entered(player)
	check(not gm.ended and gm.score == score_before + 20, "fever bomb")
	var remaining: float = gm.fever_left
	var elapsed: float = gm.elapsed
	scene._toggle_pause()
	await create_timer(0.12).timeout
	check(is_equal_approx(gm.fever_left, remaining) and is_equal_approx(gm.elapsed, elapsed), "pause timers")
	scene._toggle_pause()
	await process_frame
	gm.fever_left = 0.01
	await create_timer(0.04).timeout
	check(gm.grace_left > 0.0, "exit protection")
	gm.grace_left = 0.0
	gm.miss_coin()
	check(gm.combo == 0 and gm.multiplier == 1, "miss resets combo")
	bomb = load("res://Assets/Cenas/bomba.tscn").instantiate()
	bomb.position = Vector2(100, 100)
	scene.add_child(bomb)
	var other := Area2D.new()
	scene.add_child(other)
	bomb._on_area_entered(other)
	check(not gm.ended, "non-player filtering")
	bomb._on_area_entered(player)
	check(gm.ended and scene.result_panel != null, "bomb ends game with result")
	var save := ConfigFile.new()
	check(save.load(gm.save_path) == OK and save.get_value("progress", "best_%d" % gm.mode) == gm.score, "save record")
	scene._restart()
	await process_frame
	await process_frame
	check(not gm.ended and gm.score == 0 and gm.combo == 0, "replay clears run")
	print("PASS: %d checks; directions, touch, scoring, fever, pause, protection, save and replay" % checks)
	scene.queue_free()
	await process_frame
	await process_frame
	quit()







