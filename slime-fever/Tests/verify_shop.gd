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
	for id in gm.DESTINY:
		gm.destiny[id] = 0
	# Board effects grow with the level (buying is covered by verify_destiny.gd).
	check(gm.magnet_duration(5) > gm.magnet_duration(0) and gm.magnet_radius(5) > gm.magnet_radius(0), "magnet levels last longer and reach farther")
	check(gm.powerup_gap(5) < gm.powerup_gap(0), "luck makes power-ups more frequent")
	gm.destiny["fever"] = 2
	gm.reset_game()
	gm.started = true
	var before: int = gm.wallet
	for i in 20:
		gm.collect_coin()
	check(gm.wallet == before + 20 and gm.earned == 20, "each caught coin goes straight to the wallet")
	check(is_equal_approx(gm.fever_left, gm.fever_duration(2)) and gm.fever_duration(2) > gm.BASE_FEVER, "fever level lengthens the fever")
	gm.collect_powerup("magnet")
	check(is_equal_approx(gm.magnet_left, gm.magnet_duration()), "magnet power-up starts its timer")
	gm.end_game()
	gm.bank_run()
	check(gm.wallet == before + 20, "ending the run does not count coins twice")
	# Saved and loaded back.
	var save := ConfigFile.new()
	check(save.load(gm.save_path) == OK and int(save.get_value("progress", "wallet")) == gm.wallet and int(save.get_value("destiny", "fever")) == 2, "wallet and board levels saved")
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
	gm.items["start_magnet"] = 0
	scene._show_shop()
	await process_frame
	scene._buy_item("start_magnet")
	await process_frame
	check(gm.item_count("start_magnet") == 1 and gm.wallet == 960 and scene.shop_wallet_label.text == "960", "shop buys and refreshes")
	scene._close_shop()
	await process_frame
	check(not is_instance_valid(scene.shop_panel) and scene.menu_wallet_label.text == "960", "shop closes and menu shows the wallet")
	# Menu items: stocked, capped, used automatically at the next start.
	scene._close_shop()
	gm.wallet = 1000
	for id in gm.ITEMS:
		gm.items[id] = 0
	check(gm.buy_item("start_shield") and gm.buy_item("start_magnet") and gm.wallet == 1000 - 60 - 40, "start items cost coins")
	while gm.buy_item("start_shield"):
		pass
	check(gm.item_count("start_shield") == 3 and not gm.can_buy_item("start_shield"), "start items stack up to 3")
	scene._start_game()
	await process_frame
	check(gm.shield == 1 and gm.magnet_left > 0.0 and gm.item_count("start_shield") == 2 and gm.item_count("start_magnet") == 0, "start items used once at the start")
	# A shield absorbs one bomb, then bombs hurt again.
	var bomb = load("res://Assets/Cenas/bomba.tscn").instantiate()
	bomb.position = player.position
	scene.add_child(bomb)
	gm.grace_left = 0.0
	bomb._on_area_entered(player)
	check(not gm.ended and gm.shield == 0 and gm.grace_left > 0.0, "shield absorbs a bomb")
	# Run mini-shop: opens at a level-up when affordable, items act immediately.
	gm.wallet = 200
	gm.magnet_left = 0.0
	scene._show_run_shop()
	await process_frame
	check(is_instance_valid(scene.run_shop_panel) and paused, "reward mini-shop opens paused")
	scene._buy_run_item("shield")
	scene._buy_run_item("double")
	scene._buy_run_item("magnet_now")
	check(gm.shield == 1 and gm.double_left > 0.0 and gm.magnet_left > 0.0 and gm.wallet == 200 - 40 - 35 - 25, "mini-shop items work right away")
	check(not gm.can_buy_run_item("shield"), "only one shield at a time")
	await process_frame
	scene._close_run_shop()
	await process_frame
	check(not paused and not is_instance_valid(scene.run_shop_panel), "mini-shop resumes the run")
	var wallet_now: int = gm.wallet
	gm.collect_coin()
	check(gm.wallet == wallet_now + 2, "double coins count twice")
	gm.wallet = 0
	scene._show_run_shop()
	await process_frame
	check(not is_instance_valid(scene.run_shop_panel) and not paused, "no mini-shop when nothing is affordable")
	# Collecting upgrades.
	check(gm.reach_scale(5) > gm.reach_scale(0) and gm.speed_bonus(5) > gm.speed_bonus(0), "reach and speed grow")
	gm.destiny["reach"] = 12
	var coin = load("res://Assets/Cenas/moeda.tscn").instantiate()
	scene.add_child(coin)
	check(coin.get_node("CollisionShape2D").shape.radius > 10.0 * 1.4, "reach widens the coin pickup")
	# Skins: buy once, equip any time, recolours the slime.
	gm.wallet = 1000
	gm.skins_owned = ["verde"]
	check(gm.buy_skin("azul") and gm.skin == "azul" and gm.wallet == 850, "buying a skin equips it")
	check(not gm.buy_skin("azul") and gm.wallet == 850, "a skin is bought only once")
	gm.equip_skin("verde")
	check(gm.skin == "verde", "switch back to an owned skin")
	gm.equip_skin("ouro")
	check(gm.skin == "verde", "cannot equip a skin not owned")
	gm.equip_skin("azul")
	player.apply_skin()
	check(is_equal_approx(player.sprite.material.get_shader_parameter("hue_shift"), gm.SKINS.azul.hue), "slime sprite uses the skin hue")
	save = ConfigFile.new()
	check(save.load(gm.save_path) == OK and save.get_value("skins", "equipped") == "azul" and Array(save.get_value("skins", "owned")).has("azul") and int(save.get_value("items", "start_shield")) == 2, "items and skins saved")
	print("SHOP: %d failures; prices, levels, effects, banking, save, magnet pull, power-up, shop UI" % failures)
	quit(1 if failures else 0)
