extends SceneTree
## Living world: factions learn from the hero, evolve, build camps, take land and fight each other;
## monsters are fiercer at night; flowers do not block; life bars sit above the sprite.
## Run: godot --headless --path . -s res://tests/verify_living_world.gd   (xvfb-run ... -- <dir>: screenshots)

var main: Node
var game: Node
var failures := 0
var out_dir := ""
var F   # Factions.gd, loaded at run time (it needs the Game autoload)


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


func still(e: Node) -> void:
	e.flee_rolled = true
	e.def = e.def.duplicate()
	e.def["aggro"] = 0.0


func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
		DirAccess.make_dir_recursive_absolute(out_dir)
	game = root.get_node("Game")
	F = load("res://scripts/Factions.gd")
	game.save_path = "user://living_test_save.cfg"
	game.muted = true
	main = load("res://scenes/main.tscn").instantiate()
	main.touch_override = 0
	root.add_child(main)
	await create_timer(0.3).timeout
	main.start_game(true)
	game.day_time = 0.3
	await create_timer(0.3).timeout
	clear_enemies()
	var p: Node = main.player
	var spot: Vector2 = main.world.cell_to_pos(WorldGen.CENTER + Vector2i(40, 0))
	p.global_position = spot
	main.camera.global_position = spot
	main.camera.reset_smoothing()

	# 0) bigger map
	check(WorldGen.W >= 320 and WorldGen.H >= 320, "the map is bigger (%dx%d)" % [WorldGen.W, WorldGen.H])

	# 1) factions at the start
	check(F.control("goblins", "floresta") > 0.0 and F.control("mortos", "ruinas") > 0.0, "factions hold their home regions")
	check(F.at_war("goblins", "orcs"), "goblins and orcs start at war")
	check(F.of("skeleton_pyro") == "mortos" and F.of("goblin_chief") == "goblins", "monsters belong to factions")
	check(not F.active("bandidos"), "bandits wait for their art (dormant)")

	# 2) learning from the hero: fireball kills -> dispersed formation, less magic damage
	for k in 6:
		var g: Node = main.spawn_enemy("goblin", spot + Vector2(60, 0), 1)
		await process_frame
		still(g)
		g.take_hit(9999, Vector2.RIGHT, false, "magic")
		await process_frame
	check(F.has_adapt("goblins", "dispersar"), "6 fireball kills: goblins learn 'Formação dispersa'")
	var g2: Node = main.spawn_enemy("goblin", spot + Vector2(60, 0), 1)
	await process_frame
	still(g2)
	var hp0: int = g2.hp
	g2.take_hit(20, Vector2.RIGHT, false, "magic")
	check(hp0 - g2.hp == 15, "they take less magic damage now (%d)" % (hp0 - g2.hp))
	g2.free()
	for k in 12:
		F.learn("orcs", "melee")
	check(F.has_adapt("orcs", "escudos"), "12 sword kills: orcs learn 'Escudos improvisados'")

	# 3) evolution: tiers bring tactics and stronger monsters
	var plain: Node = main.spawn_enemy("goblin", spot + Vector2(80, 0), 3)
	F.gain_xp("goblins", 120.0)
	check(F.tier("goblins") == 2, "goblins evolve to tier 2 (%s)" % F.TIERS[F.tier("goblins")])
	check(F.has_adapt("goblins", "chamado") and F.has_adapt("goblins", "cerco"), "evolving unlocks war cry and surround tactics")
	var vet: Node = main.spawn_enemy("goblin", spot + Vector2(80, 20), 3)
	await process_frame
	check(vet.max_hp > plain.max_hp and vet.atk >= plain.atk, "evolved goblins are tougher (%d vs %d hp)" % [vet.max_hp, plain.max_hp])
	check(vet.display_name().find("Tático") >= 0, "and show it: " + vet.display_name())
	plain.free()
	vet.free()
	check(not game.chronicle.is_empty(), "the chronicle records it: " + (game.chronicle[-1] if not game.chronicle.is_empty() else ""))

	# 4) faction war on screen: a goblin and an orc fight each other
	clear_enemies()
	p.global_position = spot + Vector2(-300, 0)
	var ga: Node = main.spawn_enemy("goblin", spot + Vector2(0, 0), 3)
	var oa: Node = main.spawn_enemy("orc", spot + Vector2(30, 0), 3)
	ga.flee_rolled = true
	oa.flee_rolled = true
	var gh: int = ga.hp
	var oh: int = oa.hp
	for k in 40:
		await create_timer(0.1).timeout
		if not is_instance_valid(ga) or not is_instance_valid(oa) or ga.hp < gh or oa.hp < oh:
			break
	check((not is_instance_valid(ga) or ga.hp < gh) or (not is_instance_valid(oa) or oa.hp < oh), "a goblin and an orc fight each other")
	main.camera.global_position = spot
	await shot("living_01_faction_fight")
	clear_enemies()
	p.global_position = spot

	# 4b) the hero comes first: with him in sight, the feud stops and both turn on him
	var gb: Node = main.spawn_enemy("goblin", spot + Vector2(50, 0), 3)
	var ob: Node = main.spawn_enemy("orc", spot + Vector2(80, 0), 3)
	gb.flee_rolled = true
	ob.flee_rolled = true
	await create_timer(0.8).timeout
	check(gb.foe == p and ob.foe == p, "with the hero near, goblin and orc both go for the hero")
	clear_enemies()

	# 4c) land has riches; holding it feeds the faction; the hero taking them angers it
	check(F.wealth.get("pedreira", 0.0) > F.wealth.get("prado", 0.0), "the quarry is richer than the meadow (%.0f vs %.0f)" % [F.wealth.get("pedreira", 0.0), F.wealth.get("prado", 0.0)])
	check(F.riches_of("pedreira") != "", "riches are named: " + F.riches_of("pedreira"))
	for fid in game.factions:
		game.factions[fid]["regions"].erase("prado")
	game.factions["goblins"]["regions"]["prado"] = 90.0
	var gr: float = game.factions["goblins"]["grudge"]
	var herb: Node = load("res://scripts/ResourceNode.gd").new()
	herb.setup("moita_erva")
	herb.position = spot + Vector2(20, 0)
	main.world.entities.add_child(herb)
	await process_frame
	herb.hit(main)
	check(float(game.factions["goblins"]["grudge"]) > gr, "picking herbs on goblin land angers the goblins")
	herb.free()
	clear_enemies()

	# 5) the world turns: expansion, camps, wars
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	game.factions["goblins"]["power"] = 250.0
	var lands_before: int = game.factions["goblins"]["regions"].size()
	for k in 40:
		F.tick(rng, true, main._pick_camp_cell)
	check(game.factions["goblins"]["regions"].size() > lands_before, "goblins spread to new regions (%d -> %d)" % [lands_before, game.factions["goblins"]["regions"].size()])
	var camps := 0
	for fid in game.factions:
		camps += game.factions[fid]["camps"].size()
	check(camps > 0, "factions build camps (%d)" % camps)

	# 6) a camp near the hero: guards come out; the hero burns it down
	var camp := {"id": "goblins_test", "region": "prado", "cell": [main.world.pos_to_cell(spot).x + 6, main.world.pos_to_cell(spot).y], "level": 1, "hp": 60}
	game.factions["goblins"]["camps"].append(camp)
	main._add_camp_node("goblins", camp)
	await process_frame
	var node: Node = null
	for c in get_nodes_in_group("camps"):
		if c.camp["id"] == "goblins_test":
			node = c
	check(node != null, "camp is built in the world")
	await create_timer(2.5).timeout
	check(node != null and node.guards.size() > 0, "the camp sends out guards")
	await shot("living_02_camp")
	var grudge: float = game.factions["goblins"]["grudge"]
	var gold0: int = game.gold
	if node:
		node.hit(9999)
	await create_timer(0.5).timeout
	check(F.find_camp("goblins_test").is_empty(), "the hero destroys the camp")
	check(float(game.factions["goblins"]["grudge"]) > grudge, "the goblins hold a grudge")
	check(true, "camp loot dropped (gold %d)" % gold0)
	clear_enemies()

	# 7) night: monsters hit harder, see further
	var e: Node = main.spawn_enemy("wolf", spot + Vector2(100, 0), 3)
	await process_frame
	var day_atk: int = e._atk_now()
	game.day_time = 0.78
	await process_frame
	check(main.night_amount() > 0.5, "it is night")
	check(e._atk_now() > day_atk, "at night monsters hit harder (%d -> %d)" % [day_atk, e._atk_now()])
	e.free()
	game.day_time = 0.3

	# 8) flowers and herbs never block; ore veins do
	var flower: Node = load("res://scripts/ResourceNode.gd").new()
	flower.setup("flores_lunares")
	var vein: Node = load("res://scripts/ResourceNode.gd").new()
	vein.setup("veio_cobre")
	main.world.entities.add_child(flower)
	main.world.entities.add_child(vein)
	await process_frame
	check(flower.collision_layer == 0 and vein.collision_layer == 1, "flowers have no collision, ore veins do")
	flower.free()
	vein.free()

	# 9) life bars sit above the monster
	for id in ["spider", "ghost"]:
		var m: Node = main.spawn_enemy(id, spot + Vector2(0, 40), 1)
		await process_frame
		check(m.ui != null and m.ui.z_index > 0 and m.bar_y <= m._sprite_top() - 3.0, "%s: life bar above its head (bar %.0f, top %.0f)" % [id, m.bar_y, m._sprite_top()])
		m.free()

	# 10) saved
	game.save_game()
	var tier_before: int = F.tier("goblins")
	game.factions = F.init_state()
	game.load_game()
	check(F.tier("goblins") == tier_before and F.has_adapt("goblins", "dispersar"), "the living world survives save/load")

	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
