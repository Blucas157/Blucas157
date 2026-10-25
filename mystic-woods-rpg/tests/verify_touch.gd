extends SceneTree
## Phone controls: simulated multi-touch on the joystick and buttons.
## Run: godot --headless --path . -s res://tests/verify_touch.gd
## With a display (xvfb-run) and an output dir it also saves screenshots:
##      godot --path . -s res://tests/verify_touch.gd -- <out_dir>

var main: Node
var touch: Control
var failures := 0
var out_dir := ""


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	print(("ok  - " if ok else "FAIL- ") + what)
	if not ok:
		failures += 1


func tap(pos: Vector2, finger: int, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = finger
	ev.position = pos
	ev.pressed = down
	touch._input(ev)


func drag(pos: Vector2, finger: int) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = finger
	ev.position = pos
	touch._input(ev)


func shot(name: String) -> void:
	if out_dir == "":
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("saved ", name)


func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
		DirAccess.make_dir_recursive_absolute(out_dir)
	var game = root.get_node("Game")
	game.save_path = "user://touch_test_save.cfg"
	game.muted = true
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.touch_override = 1
	root.add_child(scene)
	main = scene
	await create_timer(0.5).timeout
	main.start_game(true)
	game.day_time = 0.3
	touch = main.touch
	await create_timer(0.5).timeout
	for e in get_nodes_in_group("enemies"):
		if e != main.boss:
			e.free()
	main.player.global_position = main.world.cell_to_pos(WorldGen.CENTER + Vector2i(0, 2))
	main.camera.global_position = main.player.global_position
	main.camera.reset_smoothing()
	await create_timer(0.4).timeout
	check(touch.visible, "touch controls visible on a touch device")
	await shot("touch_01_idle")

	# joystick: grab on the left half, push right, the hero walks right
	var start: Vector2 = main.player.global_position
	var o: Vector2 = touch.stick_home()
	tap(o, 0, true)
	drag(o + Vector2(touch.STICK_R, 0), 0)
	check(main.player.touch_move.x > 0.9, "full push right gives full speed (%.2f)" % main.player.touch_move.x)
	drag(o + Vector2(touch.STICK_R * 0.1, 0), 0)
	check(main.player.touch_move == Vector2.ZERO, "inside the dead zone the hero stands still")
	drag(o + Vector2(touch.STICK_R * 0.6, 0), 0)
	var half: float = main.player.touch_move.x
	check(half > 0.3 and half < 0.8, "half push walks slower (%.2f)" % half)
	drag(o + Vector2(touch.STICK_R * 2.0, 0), 0)
	await create_timer(0.6).timeout
	await shot("touch_02_walking")
	check(main.player.global_position.x > start.x + 20.0, "hero walked right with the joystick")
	tap(o + Vector2(touch.STICK_R, 0), 0, false)
	check(main.player.touch_move == Vector2.ZERO, "releasing the stick stops the hero")

	# attack with a second finger while the first one steers
	var b: Dictionary = touch._buttons()
	tap(o, 0, true)
	drag(o + Vector2(0, touch.STICK_R), 0)
	tap(b["attack"][0], 1, true)
	check(main.player.state == "attack", "attack button swings (multi-touch with the stick)")
	await shot("touch_03_attack")
	tap(b["attack"][0], 1, false)
	tap(o, 0, false)
	await create_timer(0.5).timeout

	# dodge: invulnerable dash, then the cooldown ring
	tap(b["dash"][0], 2, true)
	check(main.player.state == "dash", "dodge button dashes")
	check(main.player.invuln > 0.0, "dodge gives invulnerability")
	tap(b["dash"][0], 2, false)
	await create_timer(0.2).timeout
	check(main.player.dash_cd > 0.0, "dodge is on cooldown right after")
	await shot("touch_04_dodge_cooldown")
	await create_timer(0.6).timeout

	# potion
	game.hp = 5
	var pots: int = game.potions
	tap(b["potion"][0], 3, true)
	tap(b["potion"][0], 3, false)
	check(game.potions == pots - 1 and game.hp > 5, "potion button drinks a potion")

	# backpack opens a menu; the controls hide and ignore touches meanwhile
	tap(b["bag"][0], 4, true)
	tap(b["bag"][0], 4, false)
	check(paused, "backpack button opens the backpack (game paused)")
	check(not touch._active(), "controls hidden while a menu is open")
	var before: String = main.player.state
	tap(b["attack"][0], 5, true)
	check(main.player.state == before, "attack ignored behind the menu")
	tap(b["attack"][0], 5, false)
	await shot("touch_05_backpack")
	main.set_paused(false)

	# map: only its own button stays usable to close it
	tap(b["map"][0], 6, true)
	tap(b["map"][0], 6, false)
	check(main.hud.map_open, "map button opens the map")
	tap(b["map"][0], 6, true)
	tap(b["map"][0], 6, false)
	check(not main.hud.map_open, "map button closes the map")

	# near the village sign the interact button glows and the hint drops the key name
	var sign := get_first_node_in_group("interactables")
	if sign:
		main.player.global_position = sign.global_position + Vector2(0, 14)
		await create_timer(0.3).timeout
		check(main.hud.hint != "", "interaction hint near an interactable")
		await shot("touch_06_interact")

	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
