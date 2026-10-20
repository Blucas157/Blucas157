extends SceneTree
var failures := 0
var fever_signals := 0
func _initialize() -> void:
	call_deferred("run_tests")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func tap(button: Button) -> void:
	var point := root.get_final_transform() * button.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame
func run_tests() -> void:
	var scene = load("res://Assets/Cenas/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var gm = root.get_node("GameManager")
	gm.save_path = OS.get_environment("SLIME_TEST_SAVE") if OS.has_environment("SLIME_TEST_SAVE") else "user://test-flow-save.cfg"
	gm.fever_started.connect(func(): fever_signals += 1)
	check(not gm.started and scene.menu_panel.visible, "menu initially visible")
	var x: float = scene.get_node("Player").position.x
	Input.action_press("ui_right")
	await create_timer(0.1).timeout
	Input.action_release("ui_right")
	check(gm.elapsed == 0.0 and scene.get_node("Player").position.x == x, "menu freezes game")
	var play = scene.play_button
	await tap(play)
	check(gm.started, "native touch activates play GUI")
	scene.get_node("Spawner").set_process(false)
	for i in 19:
		gm.collect_coin()
	check(fever_signals == 0, "no fever signal before 20 coins")
	gm.collect_coin()
	check(fever_signals == 1 and gm.fever_count == 1 and gm.best_combo == 20, "fever and stats")
	var was_muted: bool = gm.muted
	await tap(scene.sound_button)
	check(gm.muted != was_muted, "native touch activates sound GUI")
	scene._toggle_pause()
	check(paused, "pause")
	var resume = scene.resume_button
	await tap(resume)
	check(not paused, "touch resumes while game paused")
	check(not scene.sounds[0].stream_paused, "audio resumes")
	for i in 20:
		gm.end_game()
		scene._restart()
		await process_frame
		await process_frame
		check(gm.started and not gm.ended and gm.score == 0, "replay reset")
		check(scene.get_node("Player").sprite.position == Vector2.ZERO, "visual reset")
	check(get_nodes_in_group("direction_buttons").size() == 2, "no duplicate controls")
	check(gm.fever_started.get_connections().size() == 3, "no duplicate signal connections")
	print("FLOW: %d failures; touch GUI, menu, stats, audio and 20 replays" % failures)
	quit(1 if failures else 0)

