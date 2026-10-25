extends SceneTree
## Gameplay checks: movement, combat, every monster, loot, chests, quests, death and save/load.
## Run: godot --headless --path . -s res://tests/verify_game.gd

var failures := 0
var main: Node


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
	else:
		print("ok  - ", label)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func press(action: String, seconds: float) -> void:
	Input.action_press(action)
	await create_timer(seconds).timeout
	Input.action_release(action)


func clear_enemies(keep_boss := true) -> void:
	for e in get_nodes_in_group("enemies"):
		if keep_boss and e == main.boss:
			continue
		e.free()


func kill(e: Node, max_swings := 60) -> int:
	var p: Node = main.player
	var swings := 0
	while is_instance_valid(e) and e.alive() and swings < max_swings:
		p.global_position = e.global_position + Vector2(0, 14)
		p.facing = Vector2.UP
		p.state = "move"
		p.attack_cd = 0.0
		p.invuln = 5.0
		p.do_attack()
		swings += 1
		await create_timer(0.3).timeout
	return swings


func run() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.cfg"
	game.muted = true
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.auto_title = false
	scene.touch_override = 0
	root.add_child(scene)
	current_scene = scene
	main = scene
	await frames(2)
	main.start_game(true)
	game.world_seed = game.world_seed
	await frames(10)
	var p: Node = main.player
	check(p != null and p.alive(), "player spawned")
	check(main.current_region == "vila", "starts in the village")
	check(main.boss != null and main.boss.id == "treant", "boss waits in the forest heart")
	clear_enemies()

	# movement
	var start: Vector2 = p.global_position
	await press("move_right", 0.5)
	check(p.global_position.x > start.x + 20.0, "walks right (%.1f px)" % (p.global_position.x - start.x))
	await press("move_down", 0.3)
	check(p.global_position.y > start.y + 5.0, "walks down")
	var before_dash: Vector2 = p.global_position
	p.facing = Vector2.LEFT
	p.do_dash()
	await create_timer(0.3).timeout
	check(p.global_position.x < before_dash.x - 20.0, "dash moves fast")

	# every monster can be spawned, animates, fights and dies with loot
	var arena: Vector2 = main.world.cell_to_pos(WorldGen.CENTER + Vector2i(0, 2))
	for id in MonsterDB.DATA:
		if id == "treant":
			continue
		clear_enemies()
		var xp_before: int = game.xp + game.level * 100000
		var gold_before: int = game.gold
		var e: Node = main.spawn_enemy(id, arena + Vector2(0, -30), 1)
		await frames(3)
		var sf: SpriteFrames = e.sprite.sprite_frames
		var anims_ok := true
		for a in ["idle_down", "idle_side", "idle_up", "move_down", "move_side", "move_up", "attack_down",
				"attack_side", "attack_up", "damaged_down", "damaged_side", "damaged_up", "death"]:
			if not sf.has_animation(a) or sf.get_frame_count(a) == 0:
				anims_ok = false
		check(anims_ok, "%s has all 13 animations" % id)
		var swings := await kill(e)
		check(not is_instance_valid(e) or not e.alive(), "%s defeated in %d swings" % [id, swings])
		await create_timer(1.6).timeout
		check(game.xp + game.level * 100000 > xp_before, "%s gives XP" % id)
		check(game.gold > gold_before, "%s drops coins that are collected" % id)

	# quest 1 counts slimes
	check(game.kills.get("slime", 0) >= 1, "kills are recorded")
	clear_enemies()
	game.quest_index = 0
	game.quest_progress = 0
	for i in 5:
		game.register_kill("slime")
	check(game.quest_index == 1, "first quest completes after 5 slimes")

	# monsters hurt the player
	p.invuln = 0.0
	var hp_before: int = game.hp
	var gob: Node = main.spawn_enemy("goblin", p.global_position + Vector2(18, 0), 3)
	await create_timer(2.5).timeout
	check(game.hp < hp_before, "goblin hits the player (%d -> %d)" % [hp_before, game.hp])
	clear_enemies()

	# potion
	game.hp = 5
	game.potions = 1
	p.do_potion()
	check(game.hp > 5 and game.potions == 0, "potion heals")

	# mana: spend for skills, not below zero, regenerates over time
	check(game.max_mp >= 20 and game.mp == game.max_mp, "hero starts with full mana (%d)" % game.max_mp)
	check(game.spend_mana(15) and game.mp == game.max_mp - 15, "spending mana")
	check(not game.spend_mana(game.max_mp), "cannot spend more mana than there is")
	var mp_before: int = game.mp
	await create_timer(2.0).timeout
	check(game.mp > mp_before, "mana regenerates (%d -> %d)" % [mp_before, game.mp])

	# village chest
	var chest: Node = null
	for c in get_nodes_in_group("chests"):
		if c.chest_id == "vila":
			chest = c
	check(chest != null, "village chest exists")
	if chest:
		p.global_position = chest.global_position + Vector2(0, 14)
		await frames(2)
		var g0: int = game.gold
		main.interact(p)
		await create_timer(1.5).timeout
		check(chest.opened and game.opened_chests.has("vila"), "chest opens")
		check(game.gold > g0, "chest gold collected (%d -> %d)" % [g0, game.gold])

	# breakable pot
	var pot: Node = null
	for b in get_nodes_in_group("breakables"):
		pot = b
		break
	if pot:
		var key: String = pot.get_meta("key")
		p.global_position = pot.global_position + Vector2(0, 12)
		p.facing = Vector2.UP
		p.state = "move"
		p.attack_cd = 0.0
		p.do_attack()
		await create_timer(0.4).timeout
		check(not is_instance_valid(pot) and game.broken.has(key), "pots and crates break")

	# region discovery
	var ruins_pos: Vector2 = main.world.cell_to_pos(WorldGen.POIS["ruinas"])
	p.global_position = ruins_pos
	await create_timer(0.6).timeout
	check(main.current_region == "ruinas" and game.discovered.has("ruinas"), "discovers the ruins")
	check(game.explored[WorldGen.POIS["ruinas"].y * WorldGen.W + WorldGen.POIS["ruinas"].x] == 1, "fog of war revealed")

	# spawner fills the world around the player
	clear_enemies()
	for i in 12:
		main._spawner()
	check(get_nodes_in_group("enemies").size() > 5, "spawner populates the region (%d)" % get_nodes_in_group("enemies").size())
	clear_enemies()

	# boss fight
	var boss: Node = main.boss
	boss.hp = 30
	var bswings := await kill(boss, 80)
	check(not boss.alive(), "boss defeated (%d swings)" % bswings)
	await create_timer(3.0).timeout
	check(game.boss_defeated, "boss flag saved")
	check(paused, "victory screen pauses")
	main.set_paused(false)
	var bchest: Node = null
	for c in get_nodes_in_group("chests"):
		if c.boss_chest:
			bchest = c
	check(bchest != null and bchest.visible, "legendary chest appears")

	# death and respawn
	clear_enemies(false)
	p.invuln = 0.0
	game.hp = 1
	p.take_damage(50, p.global_position + Vector2(10, 0))
	await create_timer(2.0).timeout
	check(paused and not p.alive(), "game over screen")
	main.respawn()
	await frames(2)
	check(p.alive() and game.hp == game.max_hp and main.world.pos_to_cell(p.global_position).distance_to(WorldGen.CENTER) < 4, "respawns in the village")

	# mining, gathering and crafting
	clear_enemies(false)
	var ore: Node = null
	var plant: Node = null
	for r in get_nodes_in_group("resources"):
		if ore == null and r.type == "veio_cobre":
			ore = r
		if plant == null and r.type == "moita_erva":
			plant = r
	check(ore != null and plant != null, "copper veins and herb bushes exist")
	if ore:
		var c0: int = game.count("cobre")
		for i in 4:
			p.global_position = ore.global_position + Vector2(0, 14)
			p.facing = Vector2.UP
			p.state = "move"
			p.attack_cd = 0.0
			p.do_attack()
			await create_timer(0.35).timeout
		await create_timer(1.2).timeout
		check(ore.depleted and game.count("cobre") > c0, "mining copper (%d -> %d)" % [c0, game.count("cobre")])
	if plant:
		var e0: int = game.count("erva")
		p.global_position = plant.global_position + Vector2(0, 12)
		await frames(2)
		main.interact(p)
		await create_timer(1.2).timeout
		check(plant.depleted and game.count("erva") > e0, "picking herbs")
	# iron needs a pickaxe
	var iron: Node = null
	for r in get_nodes_in_group("resources"):
		if r.type == "veio_ferro":
			iron = r
			break
	if iron:
		game.tool_tier = 0
		iron.hit(main)
		iron.hit(main)
		iron.hit(main)
		iron.hit(main)
		check(not iron.depleted, "iron needs a copper pickaxe")
	game.items["cobre"] = 10
	game.gold = 500
	var pick: Dictionary = ItemDB.RECIPES["ferreiro"][0]
	check(main.craft(pick) and game.tool_tier == 1 and game.count("cobre") == 5, "forging a copper pickaxe")
	check(main.recipe_state(pick) != "", "pickaxe cannot be forged twice")
	game.items["erva"] = 2
	game.items["gosma"] = 1
	game.potions = 0
	check(main.craft(ItemDB.RECIPES["alquimista"][0]) and game.potions == 1, "alchemist brews a potion")
	var g1: int = game.gold
	game.items["rubi"] = 2
	game.sell("rubi", 2)
	check(game.gold == g1 + 100 and game.count("rubi") == 0, "merchant buys items")
	for kind in ["ferreiro", "alquimista", "mercador"]:
		main.hud.show_shop(kind)
		await frames(2)
	main.hud.show_inventory()
	await frames(2)
	main.set_paused(false)
	check(get_nodes_in_group("interactables").size() >= 8, "village NPCs present")
	var drop_ok := false
	for i in 20:
		var e2: Node = main.spawn_enemy("skeleton", p.global_position + Vector2(0, -20), 1)
		e2.hp = 1
		e2.take_hit(5, Vector2.UP)
	await create_timer(1.5).timeout
	check(game.count("osso") > 0, "skeletons drop bones (%d)" % game.count("osso"))

	# pause and map
	main.set_paused(true)
	check(paused, "pause works")
	main.set_paused(false)
	main.toggle_map()
	check(paused and main.hud.map_open, "map opens")
	main.toggle_map()
	check(not paused, "map closes")

	# save / load
	game.gold = 777
	game.level = 4
	game.player_pos = p.global_position
	game.save_game()
	game.gold = 1
	game.level = 1
	check(game.load_game() and game.gold == 777 and game.level == 4 and game.boss_defeated, "save and load")
	main.start_game(false)
	await frames(5)
	check(main.boss == null, "boss stays defeated after loading")
	game.delete_save()
	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
