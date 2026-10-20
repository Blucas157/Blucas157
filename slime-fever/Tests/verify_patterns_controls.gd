extends SceneTree
var checks: int = 0
var failures: int = 0
var scene: Node
var player: Node
var left: Node
var right: Node
func _initialize() -> void:
	call_deferred("run_tests")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
func touch(index: int, pressed: bool, point: Vector2, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.canceled = canceled
	event.position = root.get_final_transform() * point
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func drag(index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = root.get_final_transform() * point
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func mouse(pressed: bool, point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = root.get_final_transform() * point
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func run_tests() -> void:
	scene = load("res://Assets/Cenas/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene._start_game()
	await process_frame
	var gm = root.get_node("GameManager")
	gm.save_path = "user://test-v03-save.cfg"
	gm.muted = true
	var director = scene.get_node("Spawner")
	director.set_process(false)
	player = scene.get_node("Player")
	left = get_nodes_in_group("direction_buttons")[0]
	right = get_nodes_in_group("direction_buttons")[1]
	for dimensions in [Vector2i(450, 800), Vector2i(1280, 720), Vector2i(360, 780)]:
		root.size = dimensions
		await process_frame
		touch(0, true, Vector2(205, 1810))
		await process_frame
		check(player.get_direction() == -1, "left touch at %s" % dimensions)
		touch(1, true, Vector2(875, 1810))
		await process_frame
		check(player.get_direction() == 0, "opposing fingers cancel")
		touch(0, false, Vector2(500, 500))
		await process_frame
		check(player.get_direction() == 1, "right remains after left release outside")
		touch(1, false, Vector2(875, 1810), true)
		await process_frame
		check(player.get_direction() == 0, "canceled touch clears")
		touch(2, true, Vector2(205, 1810))
		drag(2, Vector2(875, 1810))
		await process_frame
		check(player.get_direction() == 1, "drag left to right")
		drag(2, Vector2(540, 1400))
		await process_frame
		check(player.get_direction() == 0, "drag outside stops")
		touch(2, false, Vector2(540, 1400))
		mouse(true, Vector2(875, 1810))
		await process_frame
		check(player.get_direction() == 1, "mouse click right")
		mouse(false, Vector2(540, 1400))
		await process_frame
		check(player.get_direction() == 0, "mouse release outside")
	key(KEY_A, true)
	await process_frame
	check(player.get_direction() == -1, "physical A")
	mouse(true, Vector2(205, 1810))
	mouse(false, Vector2(205, 1810))
	await process_frame
	check(player.get_direction() == -1, "mouse release must not cancel held A")
	key(KEY_A, false)
	key(KEY_D, true)
	await process_frame
	check(player.get_direction() == 1, "physical D")
	key(KEY_D, false)
	key(KEY_LEFT, true)
	await process_frame
	check(player.get_direction() == -1, "keyboard arrow left")
	key(KEY_LEFT, false)
	key(KEY_RIGHT, true)
	await process_frame
	check(player.get_direction() == 1, "keyboard arrow right")
	key(KEY_RIGHT, false)
	touch(0, true, Vector2(205, 1810))
	await process_frame
	scene._toggle_pause()
	await process_frame
	check(not left.is_held() and not right.is_held(), "pause clears virtual buttons")
	var elapsed: float = gm.elapsed
	var position_before: Vector2 = player.position
	await create_timer(0.1).timeout
	check(gm.elapsed == elapsed and player.position == position_before, "pause freezes simulation")
	scene._toggle_pause()
	await process_frame
	check(player.get_direction() == 0, "resume requires new touch")
	touch(0, false, Vector2(205, 1810))
	player.position.x = 540
	Input.action_press("ui_right")
	player._process(1.0)
	Input.action_release("ui_right")
	check(player.position.x == 1000, "right boundary")
	Input.action_press("ui_left")
	player._process(2.0)
	Input.action_release("ui_left")
	check(player.position.x == 80, "left boundary")
	var pattern_names := ["ARCO", "ZIGUE-ZAGUE", "CORREDOR", "TROCA DE LADO", "CHUVA CALMA"]
	var rows_tested: int = 0
	var bombs_tested: int = 0
	for seed_value in 100:
		director.rng.seed = seed_value
		var start_x := 540.0
		for iteration in 20:
			var kind: String = pattern_names[iteration % pattern_names.size()]
			var rows: Array = director.build_pattern(kind, start_x, 2)
			check(rows.size() == 9, "pattern includes two recovery rows")
			for row in rows:
				rows_tested += 1
				check(absf(row.coin_x - row.previous_x) <= 180.01, "reachable coin step")
				check(absf(row.coin_x - row.previous_x) / 850.0 + 0.25 < director.ROW_INTERVAL, "reaction plus travel budget")
				check(row.coin_x >= 180 and row.coin_x <= 900, "coin within arena")
				# Conservative horizontal witness covers the entire path before and after contact.
				var low: float = minf(row.previous_x, minf(row.coin_x, row.next_x))
				var high: float = maxf(row.previous_x, maxf(row.coin_x, row.next_x))
				for bomb_x in row.bombs:
					bombs_tested += 1
					check(bomb_x < low - director.SAFE_MARGIN or bomb_x > high + director.SAFE_MARGIN, "bomb clear of witness path")
				check(row.bombs.size() <= 2, "bomb density cap")
			check(rows[0].bombs.is_empty() and rows[6].bombs.is_empty() and rows[7].bombs.is_empty() and rows[8].bombs.is_empty(), "safe seams and recovery")
			start_x = rows[-1].coin_x
	check(bombs_tested > 1000, "test set exercises hazards")
	gm.elapsed = 60.0
	director.pending.clear()
	director.spawn_item()
	await process_frame
	check(director.pattern_count >= 1, "live director creates pattern")
	print("RESULT: %d checks, %d failures; %d rows, %d bombs; touch/mouse/keyboard at 3 viewport sizes" % [checks, failures, rows_tested, bombs_tested])
	quit(1 if failures > 0 else 0)



