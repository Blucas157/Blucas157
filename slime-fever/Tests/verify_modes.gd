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
	gm.save_path = OS.get_environment("SLIME_TEST_SAVE") if OS.has_environment("SLIME_TEST_SAVE") else "user://test-modes-save.cfg"
	# Coin value at x1 and x4 for each fever tier.
	gm.mode = 1
	gm.reset_game()
	gm.started = true
	var expected := {0: [10, 40], 3: [19, 75], 5: [25, 100]}
	for fevers in expected:
		gm.fever_count = fevers
		gm.multiplier = 1
		check(gm.coin_points() == expected[fevers][0], "x1 coin with %d fevers" % fevers)
		gm.multiplier = 4
		check(gm.coin_points() == expected[fevers][1], "x4 coin with %d fevers" % fevers)
	# Third and fifth fevers announce the new coin value once.
	gm.reset_game()
	gm.started = true
	var tiers: Array = []
	gm.coin_tier_up.connect(func(v): tiers.append(v))
	for i in 20 * 6:
		gm.collect_coin()
		gm.fever_left = 0.0
	check(gm.fever_count == 6, "six fevers collected")
	check(tiers == [75, 100], "tier announcements %s" % [tiers])
	# Levels every LEVEL_POINTS, without a cap; speed has its own cap.
	gm.reset_game()
	gm.started = true
	var levels: Array = []
	gm.level_up.connect(func(l): levels.append(l))
	gm.add_score(gm.LEVEL_POINTS - 1)
	check(gm.level == 0, "no level before the first threshold")
	gm.add_score(1)
	check(gm.level == 1 and levels == [1], "level 1 at the threshold")
	gm.boss_started.connect(func(_i): gm.boss_active = false)
	gm.add_score(gm.LEVEL_POINTS * 40)
	check(gm.level == 41, "levels keep going")
	# Modes order and speed cap.
	gm.level = 0
	var speeds: Array = []
	var gaps: Array = []
	for m in 3:
		gm.mode = m
		speeds.append(gm.speed_scale())
		gaps.append(gm.bomb_gap_scale())
	check(speeds[0] < speeds[1] and speeds[1] < speeds[2], "harder modes fall faster")
	check(gaps[0] > gaps[1] and gaps[1] > gaps[2], "harder modes drop bombs closer together")
	gm.mode = 0
	var easy_start: float = gm.speed_scale()
	gm.level = 1
	check(gm.speed_scale() > easy_start and gm.bomb_gap_scale() < gaps[0], "a level in easy speeds up and adds bombs")
	gm.mode = 2
	gm.level = 200
	check(gm.speed_scale() <= gm.MAX_SPEED, "speed cap")
	check(gm.bomb_gap_scale() >= gm.MODE_BOMB_GAP[2] * gm.MIN_BOMB_GAP - 0.0001, "bomb density cap")
	# Records are kept per mode and survive a reload.
	gm.reset_game()
	gm.bests.fill(0)
	gm.set_mode(0)
	gm.started = true
	gm.add_score(300)
	gm.end_game()
	gm.reset_game()
	gm.set_mode(2)
	check(gm.best == 0, "hard record separate from easy")
	gm.set_mode(0)
	check(gm.best == 300, "easy record kept")
	var save := ConfigFile.new()
	check(save.load(gm.save_path) == OK and int(save.get_value("progress", "best_0")) == 300 and int(save.get_value("settings", "mode")) == 0, "records and mode saved")
	print("MODES: %d failures; coin tiers, levels, mode scaling, per-mode records" % failures)
	quit(1 if failures else 0)
