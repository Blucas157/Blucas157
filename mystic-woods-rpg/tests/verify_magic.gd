extends SceneTree
## Fireball: the Pyromancer Skeleton throws fireballs, drops the orb, the hero learns and casts it.
## Run: godot --headless --path . -s res://tests/verify_magic.gd   (with xvfb-run and -- <dir>: screenshots)

var main: Node
var game: Node
var failures := 0
var out_dir := ""


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	print(("ok  - " if ok else "FAIL- ") + what)
	if not ok:
		failures += 1


func shot(name: String) -> void:
	if out_dir == "":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func clear_enemies() -> void:
	for e in get_nodes_in_group("enemies"):
		if e != main.boss:
			e.free()


func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
		DirAccess.make_dir_recursive_absolute(out_dir)
	game = root.get_node("Game")
	game.save_path = "user://magic_test_save.cfg"
	game.muted = true
	main = load("res://scenes/main.tscn").instantiate()
	main.touch_override = 1
	root.add_child(main)
	await create_timer(0.3).timeout
	main.start_game(true)
	game.day_time = 0.3
	await create_timer(0.3).timeout
	clear_enemies()
	var p: Node = main.player
	var spot: Vector2 = main.world.cell_to_pos(WorldGen.CENTER + Vector2i(0, 4))
	p.global_position = spot
	main.camera.global_position = spot
	main.camera.reset_smoothing()
	check(not game.has_skill("fireball"), "the hero starts without magic")
	check(not main.touch._buttons().has("skill"), "no magic button before learning")
	p.do_skill()
	check(p.state == "move", "cannot cast an unknown skill")

	# 1) the pyromancer keeps its distance and throws fireballs that burn the hero
	game.hp = game.max_hp
	var e: Node = main.spawn_enemy("skeleton_pyro", spot + Vector2(80, 0), 3)
	await process_frame
	check(e.def["attack"] == "ranged" and e.flame != null, "Esqueleto Piromante: ranged caster with a hand flame")
	var hp0: int = game.hp
	var seen_ball := false
	for k in 60:
		await create_timer(0.1).timeout
		for n in main.fx_layer.get_children():
			if n.get("hostile") == true:
				seen_ball = true
				if k < 40:
					await shot("magic_01_enemy_fireball")
		if game.hp < hp0:
			break
	check(seen_ball, "the pyromancer throws a fireball")
	check(game.hp < hp0, "the fireball burns the hero (%d -> %d)" % [hp0, game.hp])
	check(e.global_position.distance_to(p.global_position) > 40.0, "it keeps its distance")

	# 2) killing it drops the orb; picking it up teaches the fireball
	e.flee_rolled = true
	e.take_hit(99999, Vector2.RIGHT)
	await create_timer(0.3).timeout
	var orb: Node = null
	for n in main.world.entities.get_children():
		if n.get("kind") == "skill":
			orb = n
	check(orb != null, "the pyromancer drops the fire orb")
	await shot("magic_02_orb")
	if orb:
		p.global_position = orb.global_position
		await create_timer(1.0).timeout
	check(game.has_skill("fireball"), "picking up the orb teaches Bola de Fogo")
	check(main.touch._buttons().has("skill"), "the magic button appears")
	clear_enemies()
	await create_timer(1.0).timeout

	# 3) casting: spends mana, flies to the monster, burns it
	game.mp = game.max_mp
	var target: Node = main.spawn_enemy("orc", p.global_position + Vector2(70, 0), 1)
	target.flee_rolled = true
	await process_frame
	p.facing = Vector2.RIGHT
	var hp_t: int = target.hp
	p.do_skill()
	check(game.mp == game.max_mp - int(game.SKILLS["fireball"]["cost"]), "casting spends mana")
	await create_timer(0.15).timeout
	await shot("magic_03_cast")
	await create_timer(0.5).timeout
	await shot("magic_04_burst")
	check(target.hp < hp_t, "the fireball burns the monster (%d -> %d)" % [hp_t, target.hp])

	# 4) no mana, no fireball
	await create_timer(0.8).timeout
	game.mp = 2
	var balls: int = main.fx_layer.get_child_count()
	p.do_skill()
	check(game.mp == 2 and main.fx_layer.get_child_count() == balls, "no mana: nothing is cast")

	# 5) the skill is saved
	game.save_game()
	game.skills = []
	game.load_game()
	check(game.has_skill("fireball"), "learned magic survives save/load")

	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
