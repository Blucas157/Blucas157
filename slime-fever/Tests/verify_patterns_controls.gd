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
func echo_motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
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
	# Web regression: the browser echoes a finger's moves as real mouse motion with the
	# left button set and never sends the release; the arrow must not stay held.
	touch(3, true, Vector2(205, 1810))
	echo_motion(Vector2(208, 1812))
	touch(3, false, Vector2(208, 1812))
	await process_frame
	check(not left.is_held() and player.get_direction() == 0, "web touch echo does not stick LEFT")
	touch(4, true, Vector2(875, 1810))
	echo_motion(Vector2(870, 1808))
	await process_frame
	check(player.get_direction() == 1, "RIGHT works after the echo")
	touch(4, false, Vector2(870, 1808))
	await process_frame
	check(player.get_direction() == 0, "nothing held after both fingers lift")
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
	for seed_value in 100:
		director.rng.seed = seed_value
		var start_x := 540.0
		for iteration in 20:
			var kind: String = pattern_names[iteration % pattern_names.size()]
			var rows: Array = director.build_pattern(kind, start_x)
			check(rows.size() == 9, "pattern includes two recovery rows")
			for row in rows:
				rows_tested += 1
				check(absf(row.coin_x - row.previous_x) <= 180.01, "reachable coin step")
				# Budget holds at the fastest allowed speed, not only the default one.
				check(absf(row.coin_x - row.previous_x) / 850.0 + 0.25 < director.ROW_INTERVAL / gm.MAX_SPEED, "reaction plus travel budget")
				check(row.coin_x >= 180 and row.coin_x <= 900, "coin within arena")
			start_x = rows[-1].coin_x
	# Bomb rain: simulate whole runs without nodes and audit every bomb against every coin.
	var bombs_tested: int = 0
	var landing_slots := {}
	var fall_min := 99.0
	var fall_max := 0.0
	var drifting := 0
	var powerups := 0
	var reflects := 0
	var bursts := 0
	director.dry_run = true
	for seed_value in 40:
		director.rng.seed = 1000 + seed_value
		director.reset_hazards()
		director.pending.clear()
		director.clock = 0.1
		director.last_x = 540.0
		gm.elapsed = 0.0
		# Cover every mode and sweep the speed levels during the run.
		gm.mode = seed_value % 3
		gm.level = 0
		for frame in 90 * 30:
			gm.elapsed += 1.0 / 30.0
			gm.level = mini(12, frame / (30 * 6))
			# Every fourth run is spent in a boss fight, adding glowing bombs to the route.
			gm.boss_active = seed_value % 4 == 0
			director.step(1.0 / 30.0)
		var coins: Array = []
		var bombs: Array = []
		powerups += director.history.filter(func(h): return h.powerup).size()
		reflects += director.history.filter(func(h): return h.reflect).size()
		for item in director.history:
			(bombs if item.bomb else coins).append(item)
		check(coins.size() > 100, "coins keep flowing")
		var last_bomb_time := -9.0
		for bomb in bombs:
			bombs_tested += 1
			check(bomb.time > 8.0, "first 8 s stay bomb-free")
			var land: float = bomb.x + bomb.drift * bomb.fall
			var arrive: float = bomb.time + bomb.fall
			check(land >= director.BOMB_MIN_X - 0.01 and land <= director.BOMB_MAX_X + 0.01, "bomb lands inside arena")
			landing_slots[int(land / 30.0)] = true
			fall_min = minf(fall_min, bomb.fall)
			fall_max = maxf(fall_max, bomb.fall)
			if bomb.drift != 0.0:
				drifting += 1
			if bomb.time - last_bomb_time < 0.21:
				bursts += 1
			last_bomb_time = bomb.time
			var spread: float = absf(bomb.drift) * director.CONTACT_WINDOW
			for i in coins.size():
				var coin: Dictionary = coins[i]
				var coin_arrive: float = coin.time + coin.fall
				if absf(coin_arrive - arrive) > director.CONTACT_WINDOW:
					continue
				var previous: float = coins[i - 1].x if i > 0 else 540.0
				var next: float = coins[i + 1].x if i + 1 < coins.size() else coin.x
				var low: float = minf(previous, minf(coin.x, next))
				var high: float = maxf(previous, maxf(coin.x, next))
				check(land + spread < low - director.SAFE_MARGIN or land - spread > high + director.SAFE_MARGIN, "bomb clear of coin route")
	director.dry_run = false
	director.reset_hazards()
	gm.mode = 1
	gm.level = 0
	check(bombs_tested > 2000, "test set exercises hazards")
	check(landing_slots.size() >= 28, "bombs use the whole width, not lanes")
	check(fall_max - fall_min > 0.8, "bomb speeds vary")
	check(drifting > bombs_tested / 4, "some bombs drift sideways")
	check(bursts > 50, "bursts break the rhythm")
	# Power-ups replace route coins, so the same bomb audit above already covers them.
	check(powerups >= 40, "power-ups appear on the coin route (%d)" % powerups)
	check(reflects >= 100, "boss fights put glowing bombs on the coin route (%d)" % reflects)
	gm.boss_active = false
	print("BOMB RAIN: %d bombs, %d landing slots, fall %.2f-%.2fs, %d drifting, %d burst drops" % [bombs_tested, landing_slots.size(), fall_min, fall_max, drifting, bursts])
	gm.elapsed = 60.0
	director.pending.clear()
	director.spawn_item()
	await process_frame
	check(director.pattern_count >= 1, "live director creates pattern")
	print("RESULT: %d checks, %d failures; %d rows, %d bombs; touch/mouse/keyboard at 3 viewport sizes" % [checks, failures, rows_tested, bombs_tested])
	quit(1 if failures > 0 else 0)



