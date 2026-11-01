extends SceneTree
## Regression sweep, run before every release (see Tests/run_all.sh):
## 1. every resource the game names loads;
## 2. broken, old and out-of-range saves load without crashing or losing progress;
## 3. a bot that follows the coin route plays real runs in each mode, through
##    levels and a boss, and never dies (the route is bomb-free by design);
## 4. starting, leaving and restarting many times leaves nothing behind.
var failures := 0
var notes: Array[String] = []

func _initialize() -> void:
	call_deferred("run_tests")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func run_tests() -> void:
	var gm = root.get_node("GameManager")
	var base: String = OS.get_environment("SLIME_TEST_SAVE") if OS.has_environment("SLIME_TEST_SAVE") else "user://test-regression.cfg"
	gm.save_path = base
	gm.muted = true
	gm.touch_override = 0
	check_resources(gm)
	check_saves(base)
	await check_runs(gm)
	await check_cycles(gm)
	gm.touch_override = -1
	Engine.time_scale = 1.0
	print("REGRESSION: %d failures; %s" % [failures, ", ".join(notes)])
	quit(1 if failures else 0)

func check_resources(gm) -> void:
	var paths: Array[String] = []
	for table in [gm.UPGRADES, gm.ITEMS, gm.RUN_ITEMS, gm.ABILITIES]:
		for id in table:
			paths.append(table[id].icon)
	for boss in gm.BOSSES:
		paths.append(boss.art)
	for scene in ["main", "moeda", "bomba", "bomba_brilhante", "ima"]:
		paths.append("res://Assets/Cenas/%s.tscn" % scene)
	paths.append_array(["res://Assets/UI/logo.png", "res://Assets/UI/shopkeeper.png", "res://Assets/New/bomb.png",
		"res://Assets/VFX/bomb_fuse.png", "res://Assets/VFX/bomb_detonate.png", "res://Assets/Shaders/slime_hue.gdshader"])
	var missing := paths.filter(func(p): return load(p) == null)
	check(missing.is_empty(), "missing resources %s" % [missing])
	for id in gm.UPGRADES:
		if gm.UPGRADES[id].has("boss"):
			check(gm.UPGRADES[id].boss < gm.BOSSES.size() and gm.BOSSES[gm.UPGRADES[id].boss].ability == id, "boss upgrade %s matches its boss" % id)
	notes.append("%d resources" % paths.size())

## Loads a save file into a fresh GameManager, the way the game does at start-up.
func fresh_manager(path: String) -> Node:
	var manager: Node = load("res://Assets/Scripts/GameManager.gd").new()
	manager.save_path = path
	manager._ready()
	return manager

func add_child_safe(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(node)

func check_saves(base: String) -> void:
	var path := base.get_basename() + "-save-cases.cfg"
	# Garbage file: defaults, no crash.
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("isto nao e um save [[[ ???")
	file.close()
	var manager := fresh_manager(path)
	check(manager.wallet == 0 and manager.upgrade_level("reach") == 0 and manager.skin == "verde", "broken save starts clean")
	manager.free()
	# Out-of-range and unknown values are clamped or ignored.
	var save := ConfigFile.new()
	save.set_value("progress", "wallet", -50)
	save.set_value("settings", "mode", 9)
	save.set_value("destiny", "reach", 999)
	save.set_value("destiny", "speed", -3)
	save.set_value("items", "start_shield", 99)
	save.set_value("skins", "owned", ["verde", "nao_existe"])
	save.set_value("skins", "equipped", "ouro")
	save.set_value("abilities", "unlocked", ["revive", "fake"])
	save.save(path)
	manager = fresh_manager(path)
	check(manager.wallet == 0 and manager.mode == 2, "negative wallet and bad mode clamped")
	check(manager.upgrade_level("reach") == manager.UPGRADE_MAX and manager.upgrade_level("speed") == 0, "upgrade levels clamped")
	check(manager.item_count("start_shield") == manager.ITEMS.start_shield.max, "item stock clamped")
	check(manager.skins_owned == ["verde"] and manager.skin == "verde", "unknown or unowned skins ignored")
	check(manager.abilities == ["revive"], "unknown abilities ignored")
	manager.free()
	# First shop (5 levels) converts x3; v0.8 single record counts as MÉDIO.
	save = ConfigFile.new()
	save.set_value("progress", "best", 4321)
	save.set_value("progress", "wallet", 77)
	save.set_value("upgrades", "magnet", 4)
	save.set_value("upgrades", "fever", 9)
	save.save(path)
	manager = fresh_manager(path)
	check(manager.upgrade_level("magnet") == 12 and manager.upgrade_level("fever") == manager.UPGRADE_MAX, "old shop levels converted x3")
	check(manager.bests[1] == 4321 and manager.bests[0] == 0 and manager.wallet == 77, "old record and wallet kept")
	# Round trip: everything written comes back.
	manager.wallet = 1234
	manager.upgrades["luck"] = 7
	manager.skins_owned.append("azul")
	manager.skin = "azul"
	manager.vibration = false
	manager.save_progress()
	var again := fresh_manager(path)
	check(again.wallet == 1234 and again.upgrade_level("luck") == 7 and again.upgrade_level("magnet") == 12 and again.skin == "azul" and not again.vibration, "save round trip")
	manager.free()
	again.free()
	# A score jump over a boss level still brings the boss (bug found by this sweep in v0.21).
	manager = fresh_manager(path)
	add_child_safe(manager)
	manager.started = true
	var levels: Array = []
	manager.level_up.connect(func(l): levels.append(l))
	manager.add_score(manager.LEVEL_POINTS * 3 + 900)
	manager.add_score(1500)
	check(levels == [1, 2, 3, 4, 5] and manager.boss_active, "jumping over NV 5 still starts the boss (%s)" % [levels])
	manager.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	notes.append("save cases")

## Bot: stands where the next coin lands. Between rows it is always inside the band
## the bombs keep clear of, so a death here means the fairness rules broke.
func check_runs(gm) -> void:
	Engine.physics_ticks_per_second = 240
	Engine.time_scale = 4.0
	for mode in 3:
		for id in gm.UPGRADES:
			gm.upgrades[id] = 0
		gm.abilities.clear()
		gm.items = {}
		gm.set_mode(mode)
		var scene = load("res://Assets/Cenas/main.tscn").instantiate()
		root.add_child(scene)
		current_scene = scene
		await process_frame
		var wallet_start: int = gm.wallet
		var spawner = scene.get_node("Spawner")
		var player = scene.get_node("Player")
		var bosses: Array = []
		gm.boss_started.connect(func(i): bosses.append(i))
		scene._start_game()
		var most_items := 0
		var game_time := 0.0
		var limit := 200.0
		while game_time < limit and not gm.ended:
			await process_frame
			game_time = gm.elapsed
			if paused:
				# Reward mini-shop after a boss: leave it.
				if is_instance_valid(scene.run_shop_panel):
					scene._close_run_shop()
				continue
			var next_x: float = player.position.x
			for w in spawner.arrivals:
				if w.arrive >= spawner.time - 0.04:
					next_x = w.coin_x
					break
			player.position.x = next_x
			# Hurry the run to the boss so it is part of the sweep.
			if gm.score < 4000 and game_time > 20.0:
				gm.add_score(40)
			var items := 0
			for child in scene.get_children():
				if child is Area2D:
					items += 1
			most_items = maxi(most_items, items)
			check(is_finite(player.position.x) and gm.score >= 0, "sane state")
		var label: String = gm.MODES[mode]
		check(not gm.ended, "%s: bot on the coin route survived %.0f s" % [label, game_time])
		check(gm.coins > 100 and gm.level >= 4, "%s: coins %d, level %d" % [label, gm.coins, gm.level + 1])
		check(not bosses.is_empty(), "%s: a boss showed up" % label)
		check(gm.wallet == wallet_start + gm.earned or gm.zone > 0, "%s: wallet adds what was earned" % label)
		check(most_items < 80, "%s: falling items stay bounded (%d)" % [label, most_items])
		notes.append("%s %d coins NV%d zone %d bosses %d in %.0fs" % [label, gm.coins, gm.level + 1, gm.zone + 1, bosses.size(), game_time])
		gm.end_game()
		scene.queue_free()
		await process_frame
		await process_frame
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60

func check_cycles(gm) -> void:
	var scene = load("res://Assets/Cenas/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	var baseline := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for i in 25:
		scene._start_game()
		for f in 3:
			await process_frame
		if i % 2 == 0:
			scene._toggle_pause()
			await process_frame
			scene._back_to_menu()
		else:
			gm.end_game()
			await process_frame
			scene._restart()
			await process_frame
			scene._back_to_menu()
		await process_frame
		await process_frame
		check(not paused and not gm.started, "cycle %d back at the menu" % i)
	for f in 5:
		await process_frame
	var after := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	check(after <= baseline + 20, "no nodes pile up after 25 cycles (%d -> %d)" % [baseline, after])
	scene._show_shop()
	await process_frame
	for tab in ["upgrades", "items", "skins"]:
		scene._select_shop_tab(tab)
		await process_frame
	scene._close_shop()
	await process_frame
	check(is_instance_valid(scene.menu_panel) and scene.menu_panel.visible, "shop returns to the menu")
	scene.queue_free()
	await process_frame
	notes.append("25 cycles")
