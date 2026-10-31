extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run_tests")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
func touch(index: int, pressed: bool, point: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = root.get_final_transform() * point
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func drag(index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = root.get_final_transform() * point
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func load_scene(touch_mode: int) -> Node:
	var gm = root.get_node("GameManager")
	gm.touch_override = touch_mode
	var scene = load("res://Assets/Cenas/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene._start_game()
	scene.get_node("Spawner").set_process(false)
	return scene
func run_tests() -> void:
	var gm = root.get_node("GameManager")
	gm.save_path = OS.get_environment("SLIME_TEST_SAVE") if OS.has_environment("SLIME_TEST_SAVE") else "user://test-touch-save.cfg"
	gm.muted = true
	for id in gm.UPGRADES:
		gm.upgrades[id] = 0
	# PC: arrows on screen, no drag steering.
	var scene = await load_scene(0)
	check(get_nodes_in_group("direction_buttons").size() == 2 and not scene.touch_steer.enabled, "PC keeps the arrows")
	scene.queue_free()
	await process_frame
	await process_frame
	# Mobile: no arrows; a held finger pulls the slime to its x and it stops there.
	scene = await load_scene(1)
	var player = scene.get_node("Player")
	check(get_nodes_in_group("direction_buttons").is_empty() and scene.touch_steer.enabled, "mobile hides the arrows")
	player.position.x = 540.0
	touch(0, true, Vector2(900, 1300))
	await create_timer(0.15).timeout
	check(player.position.x > 560.0 and player.get_direction() > 0.0, "finger on the right moves the slime right")
	await create_timer(0.8).timeout
	check(absf(player.position.x - 900.0) < 20.0 and player.get_direction() == 0.0, "slime stops under the finger")
	drag(0, Vector2(250, 1000))
	await create_timer(0.15).timeout
	check(player.get_direction() < 0.0, "dragging left turns it around")
	await create_timer(0.9).timeout
	check(absf(player.position.x - 250.0) < 20.0, "slime follows the drag")
	touch(0, false, Vector2(250, 1000))
	var x_after: float = player.position.x
	await create_timer(0.2).timeout
	check(player.get_direction() == 0.0 and is_equal_approx(player.position.x, x_after), "lifting the finger stops the slime")
	# Speed is the slime's own: crossing the arena takes as long as with the arrows.
	player.position.x = 100.0
	touch(1, true, Vector2(1000, 1300))
	await create_timer(0.3).timeout
	var moved: float = player.position.x - 100.0
	check(moved < player.walk_speed * gm.speed_bonus() * 0.36, "drag never outruns the normal speed")
	touch(1, false, Vector2(1000, 1300))
	# Touches on the top HUD are for its buttons, not steering.
	touch(2, true, Vector2(900, 120))
	await process_frame
	check(not scene.touch_steer.active(), "HUD touches do not steer")
	touch(2, false, Vector2(900, 120))
	# Pause releases the finger.
	touch(3, true, Vector2(300, 1300))
	await process_frame
	scene._toggle_pause()
	await process_frame
	check(not scene.touch_steer.active(), "pause releases the steering finger")
	scene._toggle_pause()
	touch(3, false, Vector2(300, 1300))
	# A second finger does not steal the steering.
	touch(4, true, Vector2(800, 1300))
	touch(5, true, Vector2(200, 1300))
	await process_frame
	check(scene.touch_steer.finger == 4 and is_equal_approx(scene.touch_steer.target_x, 800.0), "first finger keeps control")
	touch(5, false, Vector2(200, 1300))
	touch(4, false, Vector2(800, 1300))
	gm.touch_override = -1
	print("TOUCH: %d failures; PC arrows, mobile drag, stop, follow, speed cap, HUD, pause, multitouch" % failures)
	quit(1 if failures else 0)
