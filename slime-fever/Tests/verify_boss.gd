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
	gm.save_path = OS.get_environment("SLIME_TEST_SAVE") if OS.has_environment("SLIME_TEST_SAVE") else "user://test-boss-save.cfg"
	gm.abilities.clear()
	gm.best_zone = 0
	gm.muted = true
	var scene = load("res://Assets/Cenas/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene._start_game()
	scene.get_node("Spawner").set_process(false)
	var player = scene.get_node("Player")
	# The boss arrives on HUD level 5 (level index 4), not before.
	var started: Array = []
	gm.boss_started.connect(func(i): started.append(i))
	gm.add_score(gm.LEVEL_POINTS * 3)
	check(not gm.boss_active and started.is_empty(), "no boss before NV 5")
	gm.add_score(gm.LEVEL_POINTS)
	check(gm.boss_active and started == [0] and gm.boss_hp == gm.boss_max and gm.boss_max == 4, "first boss at NV 5 with 4 hits")
	await create_timer(1.0).timeout
	check(scene.boss_sprite.visible and scene.boss_bar.visible, "boss and its health bar are shown")
	# Catching a glowing bomb throws it back and damages the boss; it does not hurt the slime.
	var glowing = load("res://Assets/Cenas/bomba_brilhante.tscn").instantiate()
	glowing.position = player.position
	scene.add_child(glowing)
	glowing._on_area_entered(player)
	await create_timer(0.6).timeout
	check(not gm.ended and gm.boss_hp == gm.boss_max - 1, "thrown-back bomb hits the boss")
	# Defeat: chest coins, first-time ability, next zone, reward shop.
	var wallet_before: int = gm.wallet
	gm.wallet = maxi(gm.wallet, 100)
	wallet_before = gm.wallet
	var rewards: Array = []
	gm.boss_defeated.connect(func(chest, ability): rewards.append([chest, ability]))
	while gm.boss_active:
		gm.hit_boss()
	check(rewards == [[60, "revive"]] and gm.wallet == wallet_before + 60, "boss 1 gives 60 coins and SEGUNDA CHANCE")
	check(gm.zone == 1 and gm.best_zone == 1 and gm.has_ability("revive"), "victory moves to zone 2 and unlocks the power")
	check(gm.zone_bonus() > 1.0, "zone 2 coins are worth more")
	await create_timer(2.6).timeout
	check(is_instance_valid(scene.run_shop_panel) and paused, "reward mini-shop opens after the victory")
	scene._close_run_shop()
	await process_frame
	# Second boss is the crystal golem, tougher; an ability already owned is not given twice.
	gm.add_score(gm.LEVEL_POINTS * 5)
	check(gm.boss_active and gm.boss_index == 1 and gm.boss_max == 6, "zone 2 boss is the golem with 6 hits")
	# Running out of time: the boss escapes without a reward.
	gm.boss_left = 0.01
	await create_timer(0.1).timeout
	check(not gm.boss_active and gm.zone == 1, "boss escapes when time runs out")
	# SEGUNDA CHANCE survives one bomb per run.
	gm.grace_left = 0.0
	gm.shield = 0
	var bomb = load("res://Assets/Cenas/bomba.tscn").instantiate()
	bomb.position = player.position
	scene.add_child(bomb)
	bomb._on_area_entered(player)
	check(not gm.ended and gm.revive_used and gm.grace_left > 0.0, "second chance saves the slime once")
	# Auto magnet and golden fever.
	gm.abilities.append("auto_magnet")
	gm.magnet_left = 0.0
	gm.auto_magnet_clock = 0.05
	await create_timer(0.15).timeout
	check(gm.magnet_left > 0.0, "auto magnet switches itself on")
	gm.abilities.append("golden_fever")
	gm.fever_left = 3.0
	gm.double_left = 0.0
	var before: int = gm.wallet
	gm.collect_coin()
	check(gm.wallet == before + 2 * (1 + gm.zone), "golden fever doubles coins (zone bonus included)")
	# Saved.
	var save := ConfigFile.new()
	check(save.load(gm.save_path) == OK and Array(save.get_value("abilities", "unlocked")).has("revive") and int(save.get_value("progress", "best_zone")) >= 1, "abilities and best zone saved")
	# A replay starts back in zone 1 with the boss hidden.
	gm.end_game()
	scene._restart()
	await process_frame
	check(gm.zone == 0 and not gm.boss_active and not scene.boss_sprite.visible and not gm.revive_used, "replay resets zone and boss")
	print("BOSS: %d failures; boss timing, throw-back, victory rewards, zones, escape, powers, save" % failures)
	quit(1 if failures else 0)
