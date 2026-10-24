extends SceneTree
## Renders screenshots of the main places (needs a display; e.g. xvfb-run).
## Run: godot --path . -s res://tests/screenshots.gd -- <out_dir>

var main: Node
var out_dir := "user://shots"


func _initialize() -> void:
	call_deferred("run")


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name)


func get_tree_paused(p: bool) -> void:
	paused = p


func goto(cell: Vector2i, settle := 0.6) -> void:
	main.player.global_position = main.world.cell_to_pos(cell)
	main.camera.global_position = main.player.global_position
	main.camera.reset_smoothing()
	await create_timer(settle).timeout


func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var game = root.get_node("Game")
	game.save_path = "user://shots_save.cfg"
	game.muted = true
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.touch_override = 0
	root.add_child(scene)
	main = scene
	await create_timer(1.5).timeout
	await shot("01_title")
	main.start_game(true)
	game.world_seed = game.world_seed
	game.day_time = 0.3
	await create_timer(1.0).timeout
	for e in get_nodes_in_group("enemies"):
		if e != main.boss:
			e.free()
	await goto(WorldGen.CENTER + Vector2i(0, 2), 1.0)
	await shot("02_village")
	# monster parade next to the player
	var base: Vector2 = main.player.global_position + Vector2(0, 50)
	var ids := ["slime", "mushroom", "bat", "ghost", "skeleton", "goblin", "golem", "slime_fire", "goblin_chief",
		"orc", "wolf", "spider", "frog", "crystal_elemental"]
	for i in ids.size():
		var row := 0 if i < 9 else 1
		var col := i if i < 9 else i - 9
		var e: Node = main.spawn_enemy(ids[i], base + Vector2(-170 + col * 42 + row * 40, row * 44 - 20), 1)
		e.set_physics_process(false)
		e.sprite.play("idle_down")
	await create_timer(0.4).timeout
	await shot("03_monsters")
	for e in get_nodes_in_group("enemies"):
		if e != main.boss:
			e.free()
	for key in ["prado", "floresta", "ruinas", "pedreira", "pantano"]:
		var c: Vector2i
		if key == "prado":
			c = WorldGen.CENTER + Vector2i(26, 14)
		elif key == "floresta":
			c = WorldGen.CENTER + Vector2i(55, -12)
		else:
			c = WorldGen.POIS[key]
		# find a walkable cell near the spot
		for r in 12:
			var found := false
			for oy in range(-r, r + 1):
				for ox in range(-r, r + 1):
					if not found and main.world.gen.walkable(c + Vector2i(ox, oy)):
						c = c + Vector2i(ox, oy)
						found = true
			if found:
				break
		await goto(c, 1.2)
		await shot("04_" + key)
	# boss arena
	await goto(main.world.gen.boss_cell + Vector2i(-6, 0), 0.4)
	main.boss.global_position = main.player.global_position + Vector2(70, -10)
	await create_timer(1.5).timeout
	main.player.invuln = 99.0
	await shot("05_boss")
	# night
	game.day_time = 0.75
	await goto(WorldGen.CENTER + Vector2i(4, 6), 0.8)
	await shot("06_night")
	game.day_time = 0.3
	main.toggle_map()
	await create_timer(0.2).timeout
	await shot("07_map")
	main.toggle_map()
	main.set_paused(true)
	await shot("08_pause")
	main.set_paused(false)
	# resources near the quarry, shops and backpack
	for id in ["cobre", "ferro", "carvao", "erva", "gosma", "osso", "cristal", "pele_lobo", "seda_aranha", "frutinhas"]:
		game.items[id] = 6
	game.gold = 120
	var best: Node = null
	for r in get_nodes_in_group("resources"):
		if r.type == "veio_cristal":
			best = r
			break
	if best:
		main.player.global_position = best.global_position + Vector2(-30, 20)
		main.camera.global_position = main.player.global_position
		main.camera.reset_smoothing()
		await create_timer(0.8).timeout
		await shot("09_mining")
	await goto(WorldGen.CENTER + Vector2i(-4, -3), 1.0)
	await shot("10_village_npcs")
	get_tree_paused(true)
	main.hud.show_shop("ferreiro")
	await shot("11_blacksmith")
	main.hud.show_shop("alquimista")
	await shot("12_alchemist")
	main.hud.show_inventory()
	await shot("13_backpack")
	main.set_paused(false)
	game.delete_save()
	quit(0)
