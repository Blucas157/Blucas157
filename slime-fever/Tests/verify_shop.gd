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
	gm.save_path = OS.get_environment("SLIME_TEST_SAVE") if OS.has_environment("SLIME_TEST_SAVE") else "user://test-shop-save.cfg"
	for id in gm.UPGRADES:
		gm.upgrades[id] = 0
	# Buying: needs enough coins, spends them, stops at the max level.
	gm.wallet = 10
	check(not gm.can_buy("magnet") and not gm.buy("magnet") and gm.wallet == 10, "cannot buy without coins")
	gm.wallet = 5000
	check(gm.buy("magnet") and gm.upgrade_level("magnet") == 1 and gm.wallet == 5000 - 60, "first magnet level costs 60")
	while gm.buy("magnet"):
		pass
	check(gm.upgrade_level("magnet") == gm.max_level("magnet") and gm.price("magnet") == -1, "magnet stops at max level")
	check(gm.wallet == 5000 - 60 - 150 - 300 - 500 - 800, "all magnet levels charged once")
	# Effects grow with the level.
	check(gm.magnet_duration(5) > gm.magnet_duration(0) and gm.magnet_radius(5) > gm.magnet_radius(0), "magnet upgrades last longer and reach farther")
	check(gm.powerup_gap(5) < gm.powerup_gap(0), "luck makes power-ups more frequent")
	gm.upgrades["fever"] = 2
	gm.reset_game()
	gm.started = true
	for i in 20:
		gm.collect_coin()
	check(is_equal_approx(gm.fever_left, gm.BASE_FEVER + 1.6), "fever upgrade lengthens the fever")
	gm.collect_powerup("magnet")
	check(is_equal_approx(gm.magnet_left, gm.magnet_duration()), "magnet power-up starts its timer")
	# Coins go to the wallet once per run.
	var before: int = gm.wallet
	gm.end_game()
	gm.bank_run()
	check(gm.wallet == before + 20, "20 coins banked once")
	# Saved and loaded back.
	var save := ConfigFile.new()
	check(save.load(gm.save_path) == OK and int(save.get_value("progress", "wallet")) == gm.wallet and int(save.get_value("upgrades", "magnet")) == 5 and int(save.get_value("upgrades", "fever")) == 2, "wallet and upgrades saved")
	# Magnet pulls a nearby coin sideways toward the slime, and not a far one.
	var scene = load("res://Assets/Cenas/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene._start_game()
	scene.get_node("Spawner").set_process(false)
	var player = scene.get_node("Player")
	gm.collect_powerup("magnet")
	var near = load("res://Assets/Cenas/moeda.tscn").instantiate()
	near.position = Vector2(player.position.x + 200, 1000)
	near.min_speed = 1.0
	near.max_speed = 1.0
	scene.add_child(near)
	var far = load("res://Assets/Cenas/moeda.tscn").instantiate()
	far.position = Vector2(player.position.x - gm.magnet_radius() - 120, 1000)
	far.min_speed = 1.0
	far.max_speed = 1.0
	scene.add_child(far)
	var far_x: float = far.position.x
	await create_timer(0.1).timeout
	check(near.position.x < player.position.x + 200 - 50, "magnet pulls a near coin")
	check(is_equal_approx(far.position.x, far_x), "coins out of reach stay put")
	# Power-up item: grants the magnet and does not count as a coin.
	gm.magnet_left = 0.0
	var item = load("res://Assets/Cenas/ima.tscn").instantiate()
	item.position = player.position
	scene.add_child(item)
	gm.collect_coin()
	var coins_before: int = gm.coins
	var combo_before: int = gm.combo
	item._on_area_entered(player)
	check(gm.magnet_left > 0.0 and gm.coins == coins_before and gm.combo == combo_before, "power-up item grants magnet, keeps combo")
	# Shop UI: opening, buying and closing from the menu.
	scene._back_to_menu()
	await process_frame
	gm.wallet = 1000
	gm.upgrades["luck"] = 0
	scene._show_shop()
	await process_frame
	scene._buy("luck")
	await process_frame
	check(gm.upgrade_level("luck") == 1 and gm.wallet == 930 and scene.shop_wallet_label.text == "930", "shop buys and refreshes")
	scene._close_shop()
	await process_frame
	check(not is_instance_valid(scene.shop_panel) and scene.menu_wallet_label.text == "930", "shop closes and menu shows the wallet")
	print("SHOP: %d failures; prices, levels, effects, banking, save, magnet pull, power-up, shop UI" % failures)
	quit(1 if failures else 0)
