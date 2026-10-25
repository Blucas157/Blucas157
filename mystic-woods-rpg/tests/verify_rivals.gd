extends SceneTree
## Rival system: born from a defeat or an escape, saved, returns stronger, rewards when beaten.
## Run: godot --headless --path . -s res://tests/verify_rivals.gd

var main: Node
var game: Node
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	print(("ok  - " if ok else "FAIL- ") + what)
	if not ok:
		failures += 1


func clear_enemies() -> void:
	for e in get_nodes_in_group("enemies"):
		if e != main.boss:
			e.free()


## A spot in the meadow, away from the safe village.
func meadow_pos() -> Vector2:
	var c: Vector2i = WorldGen.CENTER + Vector2i(30, 0)
	for k in 60:
		var cell := c + Vector2i(k, 0)
		if main.world.gen.region_at(cell) not in ["", "vila"] and main.world.gen.walkable(cell):
			return main.world.cell_to_pos(cell)
	return main.world.cell_to_pos(c)


func run() -> void:
	game = root.get_node("Game")
	game.save_path = "user://rival_test_save.cfg"
	game.muted = true
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.touch_override = 0
	root.add_child(scene)
	main = scene
	await create_timer(0.3).timeout
	main.start_game(true)
	await create_timer(0.3).timeout
	clear_enemies()
	var spot := meadow_pos()
	main.player.global_position = spot
	var region: String = main.world.gen.region_at(main.world.pos_to_cell(spot))
	check(region != "vila", "test spot is outside the village (%s)" % region)

	# 1) a goblin defeats the hero -> it becomes a named rival one level up
	var g: Node = main.spawn_enemy("goblin", spot + Vector2(20, 0), 3)
	await process_frame
	main.player.last_hit_by = g
	var note: String = main._rival_from_defeat()
	check(game.rivals.size() == 1, "a defeat creates a rival")
	var r: Dictionary = game.rivals[0] if game.rivals.size() > 0 else {}
	check(r.get("level", 0) == 4 and r.get("wins", 0) == 1, "rival is one level up and remembers the win")
	check(Rivals.title(r) == "Matador do Herói", "title after one win: " + Rivals.title(r))
	check(note.find(r.get("name", "?")) >= 0, "game over screen names the rival")

	# 2) the same rival wins again -> it grows, a new defeat does not create a second rival
	main.player.last_hit_by = g
	main._rival_from_defeat()
	check(game.rivals.size() == 1 and r["wins"] == 2 and r["level"] == 5, "same rival grows (Flagelo, Nv.5)")
	check(Rivals.title(r) == "Flagelo do Herói", "title after two wins: " + Rivals.title(r))
	g.free()

	# 3) saved and loaded
	game.save_game()
	game.rivals = []
	game.load_game()
	check(game.rivals.size() == 1 and game.rivals[0]["name"] == r["name"], "rivals survive save/load")
	r = game.rivals[0]

	# 4) not before its cooldown; then it returns in its region, tougher than a normal goblin
	check(game.rival_due(r["region"]).is_empty(), "rival waits for its cooldown")
	r["next_at"] = 0.0
	check(not game.rival_due(r["region"]).is_empty(), "rival due after the cooldown")
	var plain: Node = main.spawn_enemy("goblin", spot + Vector2(-40, 0), int(r["level"]))
	var e: Node = main.spawn_rival(r, spot + Vector2(40, 0))
	await process_frame
	check(e.is_in_group("rivals"), "returning rival is tagged")
	check(e.max_hp > plain.max_hp and e.atk > plain.atk, "rival is tougher (%d hp vs %d)" % [e.max_hp, plain.max_hp])
	check(e.display_name().begins_with(r["name"]), "rival shows its name: " + e.display_name())
	check(game.rival_due(r["region"]).is_empty(), "no second copy while it is out")
	plain.free()

	# 5) beating it: removed from the list, bonus XP and gold/gem on the ground
	var xp_before: int = game.xp + game.level * 100000
	e.flee_rolled = true   # no escape in this step
	e.take_hit(99999, Vector2.RIGHT)
	await create_timer(0.2).timeout
	check(game.rivals.is_empty(), "defeated rival leaves the list")
	check(game.xp + game.level * 100000 > xp_before, "defeating a rival gives XP")
	var gem := false
	for p in main.world.entities.get_children():
		if p.get("item_id") in ["rubi", "esmeralda"]:
			gem = true
	check(gem, "rival drops a gem")
	clear_enemies()

	# 6) a badly hurt monster escapes and comes back as a scarred rival
	var w: Node = main.spawn_enemy("wolf", spot + Vector2(30, 0), 4)
	await process_frame
	w.flee_chance = 1.0
	w.take_hit(w.max_hp - 2, Vector2.RIGHT)
	check(w.state == "flee", "hurt monster runs away")
	await create_timer(2.2).timeout
	check(game.rivals.size() == 1 and game.rivals[0]["monster"] == "wolf", "the escapee became a rival")
	if game.rivals.size() == 1:
		check(game.rivals[0]["scars"] == 1 and Rivals.title(game.rivals[0]) == "o Marcado", "escape leaves a scar (o Marcado)")

	# 7) at most Rivals.MAX rivals
	for k in 5:
		game.rival_event("bat", 2, region, "kill")
	check(game.rivals.size() == Rivals.MAX, "never more than %d rivals" % Rivals.MAX)

	# 8) the boss never becomes a rival, nor does a defeat in the village
	check(game.rival_event("goblin", 2, "vila", "kill").is_empty(), "no new rivals born in the village")

	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
