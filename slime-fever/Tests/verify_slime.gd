extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run_tests")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run_tests() -> void:
	var scene = load("res://Assets/Cenas/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene._start_game()
	await process_frame
	var gm = root.get_node("GameManager")
	gm.muted = true
	gm.save_path = "user://test-animation-save.cfg"
	var player = scene.get_node("Player")
	scene.get_node("Spawner").set_process(false)
	var sprite = player.sprite
	var original_shape = player.get_node("CollisionShape2D").shape
	var original_scale = player.scale
	for name in ["collect", "startle", "fever", "defeat"]:
		check(sprite.sprite_frames.get_frame_count(name) == 7, "Missing frames: " + name)
	player.react_collect()
	check(sprite.animation == "collect", "Collect reaction")
	var x: float = player.position.x
	Input.action_press("ui_right")
	player._process(0.1)
	Input.action_release("ui_right")
	check(player.position.x > x and sprite.animation == "collect", "Movement continues during reaction")
	player.react_startle()
	check(sprite.animation == "startle", "Startle overrides collect")
	player.react_collect()
	check(sprite.animation == "startle", "Collect must not interrupt fear")
	gm.fever_left = 6.0
	player._fever()
	player.react_startle()
	player.react_collect()
	check(sprite.animation == "fever", "Fever priority")
	scene._toggle_pause()
	var frame: int = sprite.frame
	await create_timer(0.15).timeout
	check(sprite.frame == frame, "Animation respects pause")
	scene._toggle_pause()
	gm.fever_left = 0
	gm.ended = true
	player._defeat()
	await create_timer(0.9).timeout
	check(sprite.animation == "defeat" and not sprite.is_playing(), "Defeat ends without looping")
	check(sprite.scale.y < 0.6, "Defeat collapses visual only")
	check(player.scale == original_scale and player.get_node("CollisionShape2D").shape == original_shape, "Collision remains unchanged")
	print("Animation checks: %d failures" % failures)
	quit(1 if failures else 0)


