extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run_tests")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
func run_tests() -> void:
	var gm = root.get_node("GameManager")
	gm.save_path = OS.get_environment("SLIME_TEST_SAVE") if OS.has_environment("SLIME_TEST_SAVE") else "user://test-destiny-save.cfg"
	for id in gm.DESTINY:
		gm.destiny[id] = 0
	gm.abilities.clear()
	# Layout: three branch roots open, the rest locked behind their parent.
	check(gm.destiny_state("reach") == "open" and gm.destiny_state("fever") == "open" and gm.destiny_state("shield") == "open", "branch roots start open")
	check(gm.destiny_state("speed") == "locked" and gm.destiny_state("magnet") == "locked", "next nodes start locked")
	check(gm.destiny_state("revive") == "boss", "boss node waits for its boss")
	# Costs rise every level; buying needs the coins.
	gm.wallet = 0
	check(not gm.destiny_buy("reach"), "no coins, no level")
	gm.wallet = 1000000
	var first: int = gm.destiny_cost("reach")
	check(first == 30 and gm.destiny_buy("reach") and gm.wallet == 1000000 - 30, "level 1 costs the base price")
	check(gm.destiny_cost("reach") > first, "next level costs more")
	# Albion rule: level 5 opens the child.
	while gm.upgrade_level("reach") < gm.DESTINY_UNLOCK:
		gm.destiny_buy("reach")
	check(gm.destiny_state("speed") == "open", "level 5 opens the next node")
	# Max level.
	while gm.destiny_buy("reach"):
		pass
	check(gm.upgrade_level("reach") == gm.DESTINY_MAX and gm.destiny_state("reach") == "max" and gm.destiny_cost("reach") == -1, "stops at level 25")
	# Boss nodes: beaten boss + parent at 5.
	gm.abilities.append("revive")
	check(gm.destiny_state("revive") == "locked", "boss node still needs its parent")
	gm.destiny["shield"] = 5
	gm.destiny["resist"] = 5
	gm.destiny["treasure"] = 5
	check(gm.destiny_state("revive") == "open", "boss beaten and parent at 5 opens it")
	# Effects stay within their caps at level 25.
	check(gm.reach_scale(25) <= 2.0 and gm.speed_bonus(25) <= 1.31 and gm.auto_magnet_gap(25) >= 15.0, "effects capped at max level")
	check(gm.revive_count(0) == 1 and gm.revive_count(20) == 3, "second chance grows to 3 per run")
	check(gm.treasure_bonus(10) > 1.7, "treasure grows the chest")
	check(gm.destiny_effect("fever", 0) != "" and gm.destiny_effect("revive", 10) == "2 por partida", "effect text")
	check(gm.big_number(999) == "999" and gm.big_number(1234) == "1,2 mil" and gm.big_number(25000) == "25 mil" and gm.big_number(2500000) == "2,5 mi", "big numbers")
	# Resistance keeps the combo; shield level grants a starting shield.
	gm.reset_game()
	gm.started = true
	gm.destiny["resist"] = 40
	for i in 6:
		gm.collect_coin()
	gm.miss_coin()
	check(gm.combo == 6, "full resistance keeps the combo")
	gm.destiny["shield"] = 40
	gm.items["start_shield"] = 0
	gm.shield = 0
	var used: Array = gm.apply_start_items()
	check(gm.shield == 1 and used.has("ESCUDO DA SORTE"), "shield node grants a starting shield")
	# Old 5-level saves migrate to the board (each level is worth 3).
	var legacy := ConfigFile.new()
	legacy.set_value("upgrades", "magnet", 2)
	legacy.set_value("upgrades", "speed", 5)
	legacy.save("user://test-legacy-save.cfg")
	var fresh = load("res://Assets/Scripts/GameManager.gd").new()
	fresh.save_path = "user://test-legacy-save.cfg"
	root.add_child(fresh)
	check(fresh.upgrade_level("magnet") == 6 and fresh.upgrade_level("speed") == 15, "old upgrades become board levels")
	fresh.queue_free()
	# Board screen: opens from the menu, buys, closes.
	gm.reset_game()
	for id in gm.DESTINY:
		gm.destiny[id] = 0
	gm.wallet = 500
	var scene = load("res://Assets/Cenas/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene._show_destiny()
	await process_frame
	var board = scene.destiny_board
	check(is_instance_valid(board) and not scene.menu_panel.visible, "board opens over the menu")
	board._select("fever")
	board._buy()
	await process_frame
	check(gm.upgrade_level("fever") == 1 and gm.wallet == 465 and board.levels["fever"].text == "1/25", "board buys a level and refreshes")
	board._select("magnet")
	check(board.buy_button.disabled, "locked node cannot be bought")
	board.closed.emit()
	await process_frame
	check(not is_instance_valid(scene.destiny_board) and scene.menu_panel.visible, "board closes back to the menu")
	var save := ConfigFile.new()
	check(save.load(gm.save_path) == OK and int(save.get_value("destiny", "fever")) == 1, "board levels saved")
	print("DESTINY: %d failures; unlock rule, costs, max, boss nodes, effects, migration, board UI, save" % failures)
	quit(1 if failures else 0)
