extends Node2D
## Game flow: title, world building, spawning, day/night, regions, interactions and menus.

const WorldScript := preload("res://scripts/World.gd")
const PlayerScript := preload("res://scripts/Player.gd")
const EnemyScript := preload("res://scripts/Enemy.gd")
const PickupScript := preload("res://scripts/Pickup.gd")
const FxScript := preload("res://scripts/Fx.gd")
const HudScript := preload("res://scripts/Hud.gd")
const TouchScript := preload("res://scripts/TouchControls.gd")

const DAY_LENGTH := 360.0
const TITLE_SEED := 4242
const BOSS_LEVEL := 10

var world: Node2D
var fx_layer: Node2D
var player: CharacterBody2D
var camera: Camera2D
var hud: CanvasLayer
var touch: Control
var canvas_mod: CanvasModulate
var playing := false
var current_region := ""
var boss: Node = null
var rng := RandomNumberGenerator.new()
var touch_override := -1   # tests: 0 = desktop, 1 = touch
var auto_title := true
var _spawn_t := 0.0
var _region_t := 0.0
var _save_t := 0.0
var _regen_t := 0.0
var _shake := 0.0
var _shake_t := 0.0
var _title_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	canvas_mod = CanvasModulate.new()
	add_child(canvas_mod)
	hud = HudScript.new()
	hud.main = self
	add_child(hud)
	touch = TouchScript.new()
	touch.main = self
	hud.add_child(touch)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(camera)
	if auto_title:
		call_deferred("go_to_title")


func is_touch() -> bool:
	if touch_override >= 0:
		return touch_override == 1
	return DisplayServer.is_touchscreen_available()


# ---------------------------------------------------------------- flow
func go_to_title() -> void:
	playing = false
	get_tree().paused = false
	_build_world(TITLE_SEED)
	player.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	camera.global_position = player.global_position
	camera.reset_smoothing()
	touch.visible = false
	hud.show_title()


func start_game(new_game: bool) -> void:
	if new_game:
		Game.new_game()
	elif not Game.load_game():
		Game.new_game()
	_build_world(Game.world_seed)
	if Game.has_saved_pos and world.gen.walkable(world.pos_to_cell(Game.player_pos)):
		player.global_position = Game.player_pos
	if not Game.boss_defeated:
		boss = spawn_enemy("treant", world.cell_to_pos(world.gen.boss_cell), BOSS_LEVEL)
	hud.setup_fog(world.minimap_image, Game.explored)
	camera.global_position = player.global_position
	camera.reset_smoothing()
	playing = true
	touch.visible = is_touch()
	if is_touch():
		InputMap.action_erase_events("attack")
		for k in [KEY_J, KEY_SPACE, KEY_Z]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event("attack", ev)
	hud.clear_menu()
	get_tree().paused = false
	current_region = ""
	_region_t = 0.0
	Game.save_game()
	if new_game:
		hud.toast("Bem-vindo a Mystic Woods! Leia a placa da vila [E]", Color(1, 0.95, 0.7))


func _build_world(seed_value: int) -> void:
	if world:
		world.free()
	world = WorldScript.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	move_child(world, 0)
	world.build(seed_value)
	fx_layer = Node2D.new()
	fx_layer.z_index = 10
	world.add_child(fx_layer)
	player = PlayerScript.new()
	player.main = self
	player.position = world.cell_to_pos(WorldGen.CENTER + Vector2i(0, 2))
	world.entities.add_child(player)
	player.died.connect(_on_player_died)
	var r: Rect2 = world.world_rect()
	camera.limit_left = int(r.position.x)
	camera.limit_top = int(r.position.y)
	camera.limit_right = int(r.end.x)
	camera.limit_bottom = int(r.end.y)
	boss = null


func set_paused(p: bool) -> void:
	get_tree().paused = p
	if p:
		hud.show_pause()
	else:
		hud.clear_menu()
		hud.map_open = false


func toggle_map() -> void:
	if not playing or (get_tree().paused and not hud.map_open):
		return
	hud.map_open = not hud.map_open
	get_tree().paused = hud.map_open


func quit_to_title() -> void:
	Game.player_pos = player.global_position
	Game.save_game()
	go_to_title()


func respawn() -> void:
	Game.gold -= Game.gold / 2
	Game.hp = Game.max_hp
	Game.stats_changed.emit()
	var spot: Vector2 = world.cell_to_pos(WorldGen.CENTER + Vector2i(0, 2))
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != boss and e.global_position.distance_to(spot) < 400.0:
			e.queue_free()
	player.revive(spot)
	camera.global_position = spot
	camera.reset_smoothing()
	hud.clear_menu()
	get_tree().paused = false
	Game.player_pos = spot
	Game.save_game()


func _on_player_died() -> void:
	await get_tree().create_timer(0.6).timeout
	get_tree().paused = true
	hud.show_game_over()


func _unhandled_input(event: InputEvent) -> void:
	if not playing:
		return
	if event.is_action_pressed("pause") and player.alive():
		if hud.map_open:
			toggle_map()
		else:
			set_paused(not get_tree().paused)
	elif event.is_action_pressed("map") and player.alive():
		toggle_map()


# ---------------------------------------------------------------- loop
func _process(delta: float) -> void:
	if world == null:
		return
	_update_shake(delta)
	if not playing:
		_title_t += delta
		var c: Vector2 = world.cell_to_pos(WorldGen.CENTER)
		camera.global_position = c + Vector2(cos(_title_t * 0.15), sin(_title_t * 0.15)) * 140.0
		canvas_mod.color = Color.WHITE
		return
	camera.global_position = player.global_position + Vector2(0, -8)
	if get_tree().paused:
		return
	Game.day_time = fmod(Game.day_time + delta / DAY_LENGTH, 1.0)
	canvas_mod.color = _sky_color()
	_region_t -= delta
	if _region_t <= 0.0:
		_region_t = 0.25
		_update_region()
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = 0.7
		_spawner()
	_regen_t -= delta
	if _regen_t <= 0.0:
		_regen_t = 1.0
		if current_region == "vila" and Game.hp < Game.max_hp and player.alive():
			Game.heal(1)
	_save_t += delta
	if _save_t > 45.0:
		_save_t = 0.0
		Game.player_pos = player.global_position
		Game.save_game()
	hud.hint = _hint_text()


func night_amount() -> float:
	var t := Game.day_time
	return smoothstep(0.58, 0.68, t) * (1.0 - smoothstep(0.9, 0.98, t))


func _sky_color() -> Color:
	var t := Game.day_time
	var dusk: float = clamp(1.0 - abs(t - 0.58) / 0.06, 0.0, 1.0)
	var c := Color.WHITE.lerp(Color(1.0, 0.82, 0.68), dusk * 0.8)
	return c.lerp(Color(0.45, 0.5, 0.8), night_amount() * 0.85)


func _update_region() -> void:
	var cell: Vector2i = world.pos_to_cell(player.global_position)
	hud.reveal(world.minimap_image, Game.explored, cell, 12)
	var r: String = world.gen.region_at(cell)
	if r != current_region:
		current_region = r
		hud.show_banner(WorldGen.REGION_NAMES.get(r, r))
		if Game.register_region(r) and r != "vila":
			hud.toast("Nova região descoberta!", Color(0.6, 0.9, 1.0))


func _spawner() -> void:
	var count := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == boss:
			continue
		if e.global_position.distance_to(player.global_position) > 620.0 and e.state != "chase":
			e.queue_free()
			continue
		count += 1
	var night := night_amount() > 0.5
	var cap := 14 + (5 if night else 0)
	if count >= cap:
		return
	var pc: Vector2i = world.pos_to_cell(player.global_position)
	var cell: Vector2i = world.gen.find_spawn_cell(pc, 15.0, 22.0, rng)
	if cell.x < 0:
		return
	var region: String = world.gen.region_at(cell)
	if not MonsterDB.SPAWNS.has(region):
		return
	var lvl: int = world.gen.level_at(cell)
	var id := _pick_monster(region, lvl)
	if night and rng.randf() < 0.3:
		id = "ghost"
	var group := 1
	if id in ["slime", "slime_poison", "bat", "mushroom"]:
		group = rng.randi_range(1, 3)
	for k in group:
		spawn_enemy(id, world.cell_to_pos(cell) + Vector2(rng.randf_range(-12, 12), rng.randf_range(-12, 12)) * float(k), lvl)


func _pick_monster(region: String, lvl: int) -> String:
	var options: Array = []
	var total := 0
	for e in MonsterDB.SPAWNS[region]:
		if lvl >= int(e[2]):
			options.append(e)
			total += int(e[1])
	var pick := rng.randi_range(1, max(1, total))
	for e in options:
		pick -= int(e[1])
		if pick <= 0:
			return e[0]
	return options[0][0]


func spawn_enemy(id: String, pos: Vector2, lvl: int) -> Node:
	var e := EnemyScript.new()
	e.setup(id, lvl, pos, self)
	e.player = player
	world.entities.add_child(e)
	return e


# ---------------------------------------------------------------- interaction
func _nearest_interactable() -> Node:
	var best: Node = null
	var best_d := 26.0
	for c in get_tree().get_nodes_in_group("chests"):
		if c.can_open():
			var d: float = c.global_position.distance_to(player.global_position)
			if d < best_d:
				best_d = d
				best = c
	for s in get_tree().get_nodes_in_group("interactables"):
		var d2: float = s.global_position.distance_to(player.global_position)
		if d2 < best_d:
			best_d = d2
			best = s
	return best


func _hint_text() -> String:
	var n := _nearest_interactable()
	if n == null:
		return ""
	if n.is_in_group("chests"):
		return "[E] Abrir baú"
	return "[E] Ler placa" if n.get_meta("type") == "sign" else "[E] Beber da fonte"


func interact(_p: Node) -> void:
	var n := _nearest_interactable()
	if n == null:
		return
	if n.is_in_group("chests"):
		n.open(self)
	elif n.get_meta("type") == "sign":
		Sfx.play("select")
		hud.toast("Missão: " + Game.quest_text().replace("\n", " - "), Color(1, 0.95, 0.7))
		hud.toast("Dica: a fonte da vila cura e salva o jogo. Baús guardam espadas e cristais!", Color(0.85, 0.9, 1.0))
	else:
		Game.heal(Game.max_hp)
		Game.player_pos = player.global_position
		Game.save_game()
		Sfx.play("potion")
		hud.toast("Água fresca! Vida restaurada e jogo salvo.", Color(0.6, 1.0, 0.7))


func break_object(b: Node) -> void:
	if not is_instance_valid(b) or b.is_queued_for_deletion():
		return
	Sfx.play("break")
	Game.broken[b.get_meta("key")] = true
	spawn_dust(b.global_position)
	drop_loot(b.global_position, rng.randi_range(1, 4), 0.06, 0.15)
	b.queue_free()


# ---------------------------------------------------------------- loot and effects
func drop_loot(pos: Vector2, gold: int, potion_chance: float, heart_chance: float) -> void:
	drop_coins(pos, gold)
	if rng.randf() < potion_chance:
		drop_item(pos, "potion")
	if rng.randf() < heart_chance:
		drop_item(pos, "heart")


func drop_coins(pos: Vector2, amount: int) -> void:
	if amount <= 0:
		return
	var n: int = min(8, amount)
	for i in n:
		var v: int = amount / n + (1 if i < amount % n else 0)
		drop_item(pos, "coin", v)


func drop_item(pos: Vector2, kind: String, value: int = 1) -> void:
	var p := PickupScript.new()
	p.kind = kind
	p.value = value
	p.player = player
	p.position = pos
	p.vel = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(20.0, 55.0)
	world.entities.call_deferred("add_child", p)


func _fx(kind: String, pos: Vector2) -> Node2D:
	var f := FxScript.new()
	f.kind = kind
	f.position = pos
	return f


func float_text(pos: Vector2, text: String, color: Color) -> void:
	var f := _fx("text", pos + Vector2(rng.randf_range(-4, 4), 0))
	f.text = text
	f.color = color
	fx_layer.add_child(f)


func shockwave(pos: Vector2, radius: float, color: Color) -> void:
	var f := _fx("ring", pos)
	f.radius = radius
	f.color = color
	fx_layer.add_child(f)


func spawn_dust(pos: Vector2) -> void:
	world.entities.add_child(_fx("dust", pos))


func shake(amount: float, time: float) -> void:
	_shake = max(_shake, amount)
	_shake_t = max(_shake_t, time)


func _update_shake(delta: float) -> void:
	if _shake_t > 0.0:
		_shake_t -= delta
		camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)).round()
	else:
		camera.offset = Vector2.ZERO
		_shake = 0.0


# ---------------------------------------------------------------- boss
func boss_engaged(b: Node) -> void:
	hud.update_boss(b)
	hud.show_banner(b.def["name"])
	Sfx.play("boss")


func boss_defeated(_b: Node) -> void:
	Game.boss_defeated = true
	for c in get_tree().get_nodes_in_group("chests"):
		if c.boss_chest:
			c.set_available(true)
	Game.save_game()
	await get_tree().create_timer(2.5).timeout
	if playing:
		get_tree().paused = true
		hud.show_victory()
