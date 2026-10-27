extends SceneTree
## Hell Mode (difficulty) and Pagma's Successor (legendary blacksmith quest and forge).
## Run: godot --headless --path . -s res://tests/verify_inferno_pagma.gd   (xvfb-run ... -- <dir>: screenshots)

var main: Node
var game: Node
var F
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
	F = load("res://scripts/Factions.gd")
	game.save_path = "user://inferno_test_save.cfg"
	game.muted = true
	main = load("res://scenes/main.tscn").instantiate()
	main.touch_override = 1
	root.add_child(main)
	await create_timer(0.3).timeout
	main.hud.show_new_game()
	await create_timer(0.3).timeout
	await shot("ip_01_new_game")

	# 1) normal world for reference
	main.start_game(true, "normal")
	await create_timer(0.3).timeout
	clear_enemies()
	var spot: Vector2 = main.world.cell_to_pos(WorldGen.CENTER + Vector2i(40, 0))
	main.player.global_position = spot
	var g_norm: Node = main.spawn_enemy("goblin", spot + Vector2(80, 0), 3)
	var hp_norm: int = g_norm.max_hp
	var atk_norm: int = g_norm.atk
	check(not game.inferno() and F.tier("goblins") == 0, "normal mode: factions start wild")

	# 2) Hell Mode
	main.start_game(true, "inferno")
	game.day_time = 0.3
	await create_timer(0.3).timeout
	clear_enemies()
	main.player.global_position = spot
	check(game.inferno(), "Hell Mode chosen at the new game")
	check(F.tier("goblins") >= 1 and F.tier("orcs") >= 1, "factions start organised (tier %d)" % F.tier("goblins"))
	var g_hell: Node = main.spawn_enemy("goblin", spot + Vector2(80, 0), 3)
	await process_frame
	check(g_hell.max_hp >= int(hp_norm * 1.4) and g_hell.atk > atk_norm, "monsters are much tougher (%d hp vs %d)" % [g_hell.max_hp, hp_norm])
	g_hell.free()
	for k in 3:
		F.learn("goblins", "magic")
	check(F.has_adapt("goblins", "dispersar"), "factions learn twice as fast (3 fireball kills)")
	var xp0: int = game.xp + game.level * 100000
	var e: Node = main.spawn_enemy("slime", spot + Vector2(40, 0), 1)
	await process_frame
	e.flee_rolled = true
	var base_xp := int(round(float(e.def["xp"])))
	e.take_hit(9999, Vector2.RIGHT)
	await process_frame
	check(game.xp + game.level * 100000 - xp0 >= int(base_xp * 1.5) - 1, "more XP per kill (+50%)")
	await create_timer(0.3).timeout
	await shot("ip_02_inferno_hud")

	# 3) the legend of Pagma: offered by the blacksmith from level 3 (Hell Mode)
	game.level = 2
	check(not main._offer_pagma_quest(), "too early for the legend at level 2")
	game.level = 3
	check(main._offer_pagma_quest() and game.pagma_stage == 1, "the blacksmith tells the legend (quest starts)")
	var lam: Dictionary = {}
	for r in ItemDB.RECIPES["ferreiro"]:
		if r["id"] == "lamina_pagma":
			lam = r
	check(main.recipe_state(lam) == "Só o Sucessor de Pagma", "Pagma's forge locked before the tome")
	var tome_cell: Vector2i = main.pagma_cell()
	check(main.world.gen.region_at(tome_cell) == "ruinas", "the tome lies in the ruins")

	# 4) the guardian appears near the ruin; beating it drops the tome; taking it makes the Successor
	main.player.global_position = main.world.cell_to_pos(tome_cell) + Vector2(0, 120)
	main.camera.global_position = main.player.global_position
	main.camera.reset_smoothing()
	await create_timer(0.6).timeout
	var guard: Node = main._pagma_guardian
	check(is_instance_valid(guard) and guard.id == "guardiao_pagma", "the Guardian of Pagma appears")
	await shot("ip_03_guardian")
	if is_instance_valid(guard):
		guard.take_hit(99999, Vector2.UP)
	await create_timer(0.4).timeout
	var tome: Node = null
	for p in main.world.entities.get_children():
		if p.get("kind") == "pagma":
			tome = p
	check(tome != null, "the Guardian drops the Tome of Pagma")
	var atk_before: int = game.attack_power()
	if tome:
		main.player.global_position = tome.global_position
		await create_timer(1.0).timeout
	check(game.is_pagma(), "taking the tome makes the hero Pagma's Successor")
	check(game.attack_power() == atk_before + 2, "Successor: +2 attack")
	clear_enemies()

	# 5) legendary forge: grade roll, named item, keeps the best
	for id in lam["cost"]:
		game.add_item(id, int(lam["cost"][id]) * 4)
	game.gold = 5000
	check(main.recipe_state(lam) == "", "the Successor can forge Pagma's Blade")
	check(main.craft(lam), "forging Pagma's Blade")
	var sw: Dictionary = game.legend.get("legend_sword", {})
	check(not sw.is_empty() and int(sw["stat"]) >= 8 and String(sw["name"]).begins_with("Lâmina de Pagma, "), "a named legendary blade: %s [%s] +%d" % [sw.get("name", "?"), ItemDB.GRADES[int(sw.get("grade", 0))][0], int(sw.get("stat", 0))])
	check(game.attack_power() >= atk_before + 2 + 8, "its attack counts (%d)" % game.attack_power())
	var best: int = int(sw["stat"])
	for k in 3:
		main.craft(lam)
	check(int(game.legend["legend_sword"]["stat"]) >= best, "re-forging never loses the best blade")
	var odds: Array = main.grade_odds()
	game.pagma_pity = 5
	check(float(main.grade_odds()[3]) > float(odds[3]), "each forge without a Legendary raises its odds")
	main.set_paused(true)
	main.hud.show_shop("ferreiro")
	await create_timer(0.3).timeout
	await shot("ip_04_pagma_forge")
	main.set_paused(false)

	# 6) Vontade de Pagma: survives a deadly blow once every two minutes
	game.hp = 5
	main.player.invuln = 0.0
	game.damage_player(9999)
	check(game.hp == 1, "Vontade de Pagma: survives a deadly blow with 1 HP")
	game.damage_player(9999)
	check(game.hp == 0, "but not twice in a row")
	game.hp = game.max_hp

	# 7) saved
	game.save_game()
	var keep_name: String = game.legend["legend_sword"]["name"]
	game.legend = {}
	game.pagma_stage = 0
	game.difficulty = "normal"
	game.load_game()
	check(game.inferno() and game.is_pagma() and game.legend["legend_sword"]["name"] == keep_name, "difficulty, class and legendary gear survive save/load")

	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
