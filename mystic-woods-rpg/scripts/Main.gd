extends Node2D
## Game flow: title, world building, spawning, day/night, regions, interactions and menus.

const WorldScript := preload("res://scripts/World.gd")
const PlayerScript := preload("res://scripts/Player.gd")
const EnemyScript := preload("res://scripts/Enemy.gd")
const PickupScript := preload("res://scripts/Pickup.gd")
const FxScript := preload("res://scripts/Fx.gd")
const ProjectileScript := preload("res://scripts/Projectile.gd")
const ReticleScript := preload("res://scripts/Reticle.gd")
const CampScript := preload("res://scripts/Camp.gd")
const WORLD_TICK := 12.0   # seconds between steps of the living-world simulation
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
var _world_t := WORLD_TICK
var _was_night := false
var _raid_done_day := -1


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


func start_game(new_game: bool, difficulty := "normal") -> void:
	if new_game:
		Game.new_game()
		Game.difficulty = difficulty
		if Game.inferno():
			Factions.apply_inferno()
	elif not Game.load_game():
		Game.new_game()
	_build_world(Game.world_seed)
	if Game.has_saved_pos and world.gen.walkable(world.pos_to_cell(Game.player_pos)):
		player.global_position = Game.player_pos
	if not Game.boss_defeated:
		boss = spawn_enemy("treant", world.cell_to_pos(world.gen.boss_cell), BOSS_LEVEL)
	hud.setup_fog(world.minimap_image, Game.explored)
	Factions.set_wealth(world.gen.resources, func(c): return world.gen.region_at(c))
	_spawn_camps()
	_was_night = night_amount() > 0.5
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
		hud.toast("Bem-vindo a Mystic Woods! Leia a placa da vila " + ("(botão !)" if is_touch() else "[E]"), Color(1, 0.95, 0.7))


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
	var reticle := ReticleScript.new()
	reticle.player = player
	fx_layer.add_child(reticle)
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
	var note := _rival_from_defeat()
	await get_tree().create_timer(0.6).timeout
	get_tree().paused = true
	hud.show_game_over(note)


## The monster that struck the last blow becomes (or grows as) a rival. Returns a line for the
## game over screen, or "" when nothing happened.
func _rival_from_defeat() -> String:
	# the attacker may already be gone (despawned or freed), so check before using it
	if not is_instance_valid(player.last_hit_by):
		player.last_hit_by = null
		return ""
	var k: Node = player.last_hit_by
	player.last_hit_by = null
	if k.is_boss or not k.alive():
		return ""
	var region: String = world.gen.region_at(world.pos_to_cell(k.global_position))
	var was_rival: bool = not k.rival.is_empty()
	var r := Game.rival_event(k.id, k.lvl, region, "kill", int(k.rival.get("uid", -1)))
	if r.is_empty():
		return ""
	k.rival = r
	k.ui.queue_redraw()
	Game.save_game()
	var who := Rivals.full_name(r)
	if was_rival:
		return "%s ficou ainda mais forte (Nv.%d)." % [who, r["level"]]
	return "%s: \"%s\"\nEle agora é seu rival e vai te procurar." % [who, Rivals.taunt(r, "kill")]


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
	var before := Game.day_time
	Game.day_time = fmod(Game.day_time + delta / DAY_LENGTH, 1.0)
	if Game.day_time < before:
		Game.day_count += 1
	_check_nightfall()
	Game.night_flag = night_amount() > 0.5
	Game.current_region = current_region
	_world_t -= delta
	if _world_t <= 0.0:
		_world_t = WORLD_TICK
		world_tick()
	canvas_mod.color = _sky_color()
	_region_t -= delta
	if _region_t <= 0.0:
		_region_t = 0.25
		_update_region()
		_check_pagma()
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
	if _try_spawn_rival():
		return
	var night := night_amount() > 0.5
	var cap := 14 + (5 if night else 0) + (4 if Game.inferno() else 0)
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
	if _try_skirmish(region, cell, lvl):
		return
	if _try_vein_guard(region, lvl):
		return
	var id := _pick_monster(region, lvl)
	if night and rng.randf() < 0.3:
		id = "ghost"
	# evolved factions field their elites more often
	var fid := Factions.of(id)
	if fid != "" and Factions.DATA[fid]["elite"] != "" and rng.randf() < 0.06 * Factions.tier(fid):
		id = Factions.DATA[fid]["elite"]
	var group := 1
	if id in ["slime", "slime_poison", "bat", "mushroom"]:
		group = rng.randi_range(1, 3)
	for k in group:
		spawn_enemy(id, world.cell_to_pos(cell) + Vector2(rng.randf_range(-12, 12), rng.randf_range(-12, 12)) * float(k), lvl)


func _pick_monster(region: String, lvl: int) -> String:
	var options: Array = []
	var total := 0
	# a region's spawns follow who rules it (Factions): their monsters come more, beaten ones less
	for e in MonsterDB.SPAWNS[region]:
		if lvl >= int(e[2]):
			var w := maxi(1, int(round(float(e[1]) * Factions.spawn_mult(e[0], region) * 4.0)))
			options.append([e[0], w])
			total += w
	var pick := rng.randi_range(1, max(1, total))
	for e in options:
		pick -= int(e[1])
		if pick <= 0:
			return e[0]
	return options[0][0]


# ---------------------------------------------------------------- living world (Factions.gd)
func world_tick() -> void:
	for ev in Factions.tick(rng, night_amount() > 0.5, _pick_camp_cell):
		hud.toast(ev["text"], ev["color"])
		if ev["kind"] == "camp":
			_add_camp_node(ev["fid"], ev["camp"])
		elif ev["kind"] == "war" or ev["kind"] == "expand":
			_sync_camps()
	_try_raid()


## Where a new camp can stand in a region: walkable, not on a road, far from the hero.
func _pick_camp_cell(region: String) -> Vector2i:
	var g: WorldGen = world.gen
	var pc: Vector2i = world.pos_to_cell(player.global_position)
	for _i in 300:
		var c := Vector2i(rng.randi_range(12, WorldGen.W - 12), rng.randi_range(12, WorldGen.H - 12))
		if g.region_at(c) != region or Vector2(c - pc).length() < 30.0:
			continue
		var ok := true
		for oy in range(-2, 3):
			for ox in range(-2, 3):
				var q := c + Vector2i(ox, oy)
				if not g.walkable(q) or g.reserved[g.idx(q)] == 1:
					ok = false
		if ok:
			return c
	return Vector2i(-1, -1)


func _spawn_camps() -> void:
	for n in get_tree().get_nodes_in_group("camps"):
		n.free()
	for fid in Game.factions:
		for c in Game.factions[fid]["camps"]:
			_add_camp_node(fid, c)


func _add_camp_node(fid: String, camp: Dictionary) -> void:
	var node := CampScript.new()
	node.main = self
	node.fid = fid
	node.camp = camp
	node.position = world.cell_to_pos(Vector2i(int(camp["cell"][0]), int(camp["cell"][1])))
	world.entities.add_child(node)


## Camps whose land was lost disappear from the map.
func _sync_camps() -> void:
	for n in get_tree().get_nodes_in_group("camps"):
		if Factions.find_camp(n.camp["id"]).is_empty():
			n.queue_free()


func camp_destroyed(node: Node) -> void:
	var c := Factions.camp_destroyed(node.fid, node.camp["id"])
	var lv := int(c.get("level", 1))
	var pos: Vector2 = node.global_position
	vfx("fireburst", pos + Vector2(0, -10))
	shake(3.0, 0.2)
	Sfx.play("break")
	drop_coins(pos, 20 + 25 * lv)
	Game.add_xp(25 * lv)
	drop_material(pos, "rubi" if rng.randf() < 0.3 else "esmeralda", 1)
	hud.show_banner("Acampamento destruído!")
	hud.toast("%s vai querer vingança... (+%d XP)" % [Factions.DATA[node.fid]["name"], 25 * lv], Color(1.0, 0.75, 0.4))
	node.queue_free()
	Game.save_game()


## The hero mined a vein or picked plants: on a faction's land they take it badly.
var _plunder_warned := {}


func resource_harvested(node: Node) -> void:
	var region: String = world.gen.region_at(world.pos_to_cell(node.global_position))
	var fid := Factions.plundered(region)
	if fid == "":
		return
	if not _plunder_warned.has(fid + region):
		_plunder_warned[fid + region] = true
		hud.toast("Estas riquezas são de %s... eles vão querer de volta!" % Factions.DATA[fid]["name"], Color(1.0, 0.6, 0.45))
	# whoever of them is around comes for the thief
	var near := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.faction == fid and e.global_position.distance_to(node.global_position) < 240.0:
			e.state = "chase"
			e.foe = player
			e.hero_lock = 4.0
			near += 1
	if near == 0 and rng.randf() < 0.35:
		var members: Array = Factions.DATA[fid]["members"]
		var a := rng.randf() * TAU
		var e2 := spawn_enemy(members[rng.randi() % members.size()], node.global_position + Vector2(cos(a), sin(a)) * 120.0,
			world.gen.level_at(world.pos_to_cell(node.global_position)))
		e2.state = "chase"


func faction_learned(fid: String) -> void:
	var s := Factions.st(fid)
	var a: String = s["adapt"][-1]
	hud.toast("%s se adaptou: %s!" % [Factions.DATA[fid]["name"], Factions.ADAPT[a]["name"]], Color(1.0, 0.6, 0.5))


## Nightfall warning (monsters are more aggressive at night).
func _check_nightfall() -> void:
	var night := night_amount() > 0.5
	if night and not _was_night:
		hud.show_banner("A noite caiu...")
		hud.toast("Os monstros estão mais agressivos e em maior número!", Color(0.75, 0.7, 1.0))
	_was_night = night


## On land a faction rules, some of its monsters stand guard over the ore veins near the hero.
func _try_vein_guard(region: String, lvl: int) -> bool:
	var fid := Factions.ruler(region)
	if fid == "" or Factions.control(fid, region) < 40.0 or not Factions.active(fid) or rng.randf() > 0.3:
		return false
	var veins: Array = []
	for r in get_tree().get_nodes_in_group("resources"):
		var d: float = r.global_position.distance_to(player.global_position)
		if r.is_ore() and d > 150.0 and d < 330.0:
			veins.append(r)
	if veins.is_empty():
		return false
	var v: Node = veins[rng.randi() % veins.size()]
	var members: Array = Factions.DATA[fid]["members"]
	var e := spawn_enemy(members[rng.randi() % members.size()], v.global_position + Vector2(rng.randf_range(-16, 16), 14), lvl)
	e.home = v.global_position
	return true


## Two factions at war that both hold the region: sometimes their war parties meet near the hero.
func _try_skirmish(region: String, cell: Vector2i, lvl: int) -> bool:
	if rng.randf() > 0.12:
		return false
	var here: Array = []
	for fid in Game.factions:
		if Factions.active(fid) and Factions.control(fid, region) >= 20.0:
			here.append(fid)
	for a in here:
		for b in here:
			if Factions.at_war(a, b):
				var base: Vector2 = world.cell_to_pos(cell)
				for side in [[a, -36.0], [b, 36.0]]:
					var members: Array = Factions.DATA[side[0]]["members"]
					for k in rng.randi_range(2, 3):
						var id: String = members[rng.randi() % members.size()]
						spawn_enemy(id, base + Vector2(float(side[1]) + rng.randf_range(-10, 10), rng.randf_range(-24, 24)), lvl)
				hud.toast("%s e %s disputam %s pelas riquezas (%s)!" % [Factions.DATA[a]["name"], Factions.DATA[b]["name"],
					WorldGen.REGION_NAMES[region], Factions.riches_of(region)], Color(1.0, 0.65, 0.5))
				return true
	return false


## Once a night, a faction with a grudge against the hero may march on the village gates.
func _try_raid() -> void:
	if night_amount() < 0.5 or _raid_done_day == Game.day_count:
		return
	var fid := Factions.raid_candidate(rng)
	if fid == "":
		return
	var gate: Vector2 = world.cell_to_pos(WorldGen.CENTER + Vector2i(0, 14))
	if player.global_position.distance_to(gate) > 450.0:
		return   # they march when the hero is home to see it
	_raid_done_day = Game.day_count
	var members: Array = Factions.DATA[fid]["members"]
	var n := 3 + Factions.tier(fid)
	for k in n:
		var id: String = members[rng.randi() % members.size()]
		var e := spawn_enemy(id, gate + Vector2(rng.randf_range(-40, 40), rng.randf_range(0, 30)), maxi(1, Game.level))
		e.state = "chase"
	Factions.st(fid)["grudge"] = float(Factions.st(fid)["grudge"]) * 0.5
	Factions.chronicle("%s atacou os portões da Vila do Bosque!" % Factions.DATA[fid]["name"])
	hud.show_banner("Invasão!")
	hud.toast("%s atacam os portões da vila!" % Factions.DATA[fid]["name"], Color(1.0, 0.45, 0.4))
	Sfx.play("boss")


# ---------------------------------------------------------------- Sucessor de Pagma (Overgeared)
const PAGMA_LEVEL := 4
var _pagma_guardian: Node = null


## The legendary quest starts at the blacksmith once the hero has some experience.
func _offer_pagma_quest() -> bool:
	if Game.pagma_stage != 0 or Game.level < (PAGMA_LEVEL - 1 if Game.inferno() else PAGMA_LEVEL):
		return false
	Game.pagma_stage = 1
	Factions.chronicle("O Ferreiro contou ao herói a lenda de Pagma, o ferreiro lendário.")
	hud.show_banner("Missão lendária: O Legado de Pagma")
	hud.toast("Ferreiro: \"Pagma forjava armas que os deuses temiam. Seu tomo está perdido nas Ruínas Antigas...\"", Color(1.0, 0.9, 0.6))
	hud.toast("Um Guardião protege o Tomo de Pagma. Siga a estrela dourada no mapa.", Color(1.0, 0.85, 0.4))
	Sfx.play("level")
	Game.save_game()
	return true


## Where the tome lies: the ruin farthest from the village.
func pagma_cell() -> Vector2i:
	var best := Vector2i(WorldGen.POIS["ruinas"])
	var bd := 0.0
	for r in world.gen.ruins:
		var c: Vector2i = r.position + r.size / 2
		var d := Vector2(c - WorldGen.CENTER).length()
		if d > bd:
			bd = d
			best = c
	return best


func _check_pagma() -> void:
	if Game.pagma_stage != 1 or not player.alive():
		return
	if is_instance_valid(_pagma_guardian) and _pagma_guardian.alive():
		return
	var spot: Vector2 = world.cell_to_pos(pagma_cell())
	if player.global_position.distance_to(spot) > 300.0:
		return
	for p in world.entities.get_children():
		if p.get("kind") == "pagma":
			return   # the tome is already lying there
	var lvl := maxi(world.gen.level_at(pagma_cell()) + 3, Game.level + 2)
	_pagma_guardian = spawn_enemy("guardiao_pagma", spot, lvl)
	_pagma_guardian.flee_rolled = true
	hud.show_banner("Guardião de Pagma")
	hud.toast("\"Só o digno herdará a forja de Pagma!\"", Color(1.0, 0.85, 0.4))
	Sfx.play("boss")


func drop_pagma_tome(pos: Vector2) -> void:
	var p := PickupScript.new()
	p.kind = "pagma"
	p.item_id = "tomo_pagma"
	p.player = player
	p.position = pos
	world.entities.call_deferred("add_child", p)


func become_pagma() -> void:
	Game.pagma_stage = 2
	Factions.chronicle("O herói se tornou o Sucessor de Pagma.")
	hud.show_banner("Sucessor de Pagma!")
	hud.toast("Classe lendária: +2 de ataque, forja lendária no Ferreiro e Vontade de Pagma (resiste à morte a cada 2 min).", Color(1.0, 0.85, 0.4))
	vfx("fireburst", player.global_position + Vector2(0, -8), 0.0, Color(1.0, 0.9, 0.5))
	Sfx.play("level")
	Game.stats_changed.emit()
	Game.save_game()


## Grade odds for the next legendary forge; each forge without a Legendary raises its chance.
func grade_odds() -> Array:
	var o: Array = ItemDB.GRADE_ODDS.duplicate()
	var bonus := 4.0 * Game.pagma_pity + (3.0 if Game.inferno() else 0.0)
	o[3] = float(o[3]) + bonus
	o[0] = maxf(5.0, float(o[0]) - bonus)
	return o


func _forge_legend(r: Dictionary) -> void:
	var odds := grade_odds()
	var total := 0.0
	for v in odds:
		total += float(v)
	var pick := rng.randf() * total
	var grade := 0
	for i in odds.size():
		pick -= float(odds[i])
		if pick <= 0.0:
			grade = i
			break
	Game.pagma_pity = 0 if grade == 3 else Game.pagma_pity + 1
	var g: Array = ItemDB.GRADES[grade]
	var titles: Array = ItemDB.LEGEND_TITLES[r["kind"]]
	var item := {"name": "%s, %s" % [r["name"], titles[rng.randi() % titles.size()]], "grade": grade,
		"stat": int(round(float(r["value"]) * float(g[1]))), "icon": r["icon"]}
	var cur: Dictionary = Game.legend.get(r["kind"], {})
	var what := "ataque" if r["kind"] == "legend_sword" else "defesa"
	if cur.is_empty() or int(item["stat"]) >= int(cur["stat"]):
		Game.legend[r["kind"]] = item
		hud.show_banner("Forja %s!" % g[0])
		hud.toast("%s [%s]: +%d de %s" % [item["name"], g[0], item["stat"], what], g[2])
	else:
		hud.toast("Saiu %s [%s] (+%d)... você manteve %s (+%d)." % [item["name"], g[0], item["stat"], cur["name"], cur["stat"]], Color(0.85, 0.85, 0.9))
	if grade == 3:
		Factions.chronicle("O Sucessor de Pagma forjou um item Lendário: %s." % item["name"])
		# legendary gear draws envious eyes: every faction wants it
		for fid in Game.factions:
			Game.factions[fid]["grudge"] = float(Game.factions[fid]["grudge"]) + 8.0
		vfx("fireburst", player.global_position + Vector2(0, -10), 0.0, Color(1.0, 0.95, 0.6))


# ---------------------------------------------------------------- rivals
## A rival whose cooldown is over may come back while the hero walks its home region.
func _try_spawn_rival() -> bool:
	if not get_tree().get_nodes_in_group("rivals").is_empty() or current_region in ["", "vila"]:
		return false
	var r := Game.rival_due(current_region)
	if r.is_empty() or rng.randf() > 0.25:
		return false
	var pc: Vector2i = world.pos_to_cell(player.global_position)
	var cell: Vector2i = world.gen.find_spawn_cell(pc, 9.0, 14.0, rng)
	if cell.x < 0:
		return false
	spawn_rival(r, world.cell_to_pos(cell))
	return true


func spawn_rival(r: Dictionary, pos: Vector2) -> Node:
	var e := EnemyScript.new()
	e.setup(r["monster"], int(r["level"]), pos, self)
	e.apply_rival(r)
	e.player = player
	world.entities.add_child(e)
	Game.rival_seen(int(r["uid"]))
	hud.show_banner(Rivals.full_name(r))
	hud.toast("%s: \"%s\"" % [r["name"], Rivals.taunt(r, "appear")], Color(1.0, 0.6, 0.5))
	Sfx.play("boss")
	return e


func rival_escaped(r: Dictionary) -> void:
	hud.toast("%s fugiu... e vai voltar!" % Rivals.full_name(r), Color(1.0, 0.6, 0.5))
	Game.save_game()


func rival_defeated(e: Node) -> void:
	var r := Game.rival_defeated(int(e.rival["uid"]))
	if r.is_empty():
		return
	var lvl := int(r["level"])
	var xp := 30 * lvl
	_rival_reward(e.global_position, 25 + 15 * lvl, xp)
	float_text(e.hurt_center() + Vector2(0, -30), Rivals.taunt(r, "defeated"), Color(1.0, 0.6, 0.5))
	hud.toast("Rival derrotado: %s!  (+%d XP)" % [Rivals.full_name(r), xp], Color(1.0, 0.85, 0.3))
	Game.save_game()


## Rival reward on top of the normal loot: a pile of gold, bonus XP and a gem.
func _rival_reward(pos: Vector2, gold: int, xp: int) -> void:
	drop_coins(pos, gold)
	Game.add_xp(xp)
	drop_material(pos, "rubi" if rng.randf() < 0.5 else "esmeralda", 1)


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
	for r in get_tree().get_nodes_in_group("resources"):
		if r.can_pick():
			var d3: float = r.global_position.distance_to(player.global_position)
			if d3 < best_d:
				best_d = d3
				best = r
	return best


const NPC_HINTS := {"sign": "[E] Ler placa", "well": "[E] Beber da fonte", "ferreiro": "[E] Ferreiro",
	"alquimista": "[E] Alquimista", "mercador": "[E] Mercador"}


func _hint_text() -> String:
	var n := _nearest_interactable()
	if n == null:
		return ""
	if n.is_in_group("chests"):
		return "[E] Abrir baú"
	if n.is_in_group("resources"):
		return "[E] Colher " + ItemDB.item_name(n.def["item"])
	return NPC_HINTS.get(n.get_meta("type"), "[E]")


func interact(_p: Node) -> void:
	var n := _nearest_interactable()
	if n == null:
		return
	if n.is_in_group("chests"):
		n.open(self)
		return
	if n.is_in_group("resources"):
		n.hit(self)
		return
	var t: String = n.get_meta("type")
	match t:
		"sign":
			Sfx.play("select")
			hud.toast("Missão: " + Game.quest_text().replace("\n", " - "), Color(1, 0.95, 0.7))
			hud.toast("Dica: minere e colha recursos e leve ao Ferreiro e à Alquimista!", Color(0.85, 0.9, 1.0))
		"well":
			Game.heal(Game.max_hp)
			Game.player_pos = player.global_position
			Game.save_game()
			Sfx.play("potion")
			hud.toast("Água fresca! Vida restaurada e jogo salvo.", Color(0.6, 1.0, 0.7))
		"ferreiro", "alquimista", "mercador":
			Sfx.play("select")
			if t == "ferreiro" and _offer_pagma_quest():
				return
			get_tree().paused = true
			hud.show_shop(t)


func open_inventory() -> void:
	if not playing or get_tree().paused:
		return
	get_tree().paused = true
	hud.show_inventory()


func recipe_state(r: Dictionary) -> String:
	## "" if it can be crafted, otherwise the reason
	if r.get("pagma", false) and not Game.is_pagma():
		return "Só o Sucessor de Pagma"
	if r["kind"] in ["tool", "sword", "armor"] and Game.crafted.has(r["id"]):
		return "Já forjado"
	if r["kind"] == "tool" and Game.tool_tier >= int(r["value"]):
		return "Já possui"
	if r["kind"] == "armor" and Game.armor_tier >= int(r["value"]):
		return "Já possui"
	if r["kind"] == "potion" and Game.potions >= Game.MAX_POTIONS:
		return "Poções cheias"
	if not Game.has_items(r["cost"]):
		return "Faltam materiais"
	if Game.gold < int(r["gold"]):
		return "Falta ouro"
	return ""


func craft(r: Dictionary) -> bool:
	var why := recipe_state(r)
	if why != "":
		hud.toast(why, Color(1, 0.7, 0.6))
		return false
	Game.remove_items(r["cost"])
	Game.gold -= int(r["gold"])
	match r["kind"]:
		"tool":
			Game.tool_tier = int(r["value"])
		"sword":
			Game.sword_tier += int(ItemDB.SWORD_UPGRADES.get(int(r["value"]), 1))
		"armor":
			Game.armor_tier = int(r["value"])
		"legend_sword", "legend_armor":
			_forge_legend(r)
		"potion":
			Game.potions = min(Game.MAX_POTIONS, Game.potions + int(r["value"]))
		"stat":
			match r["value"]:
				"atk":
					Game.atk += 1
				"hp":
					Game.max_hp += 5
					Game.heal(5)
				"def":
					Game.defense += 1
	Sfx.play("level" if r["kind"] in ["tool", "sword", "armor", "legend_sword", "legend_armor"] else "potion")
	if not r["kind"].begins_with("legend"):
		hud.toast("%s pronto! %s" % [r["name"], r["desc"]], Color(0.6, 1.0, 0.6))
	Game.register_craft(r["id"])
	Game.stats_changed.emit()
	Game.save_game()
	return true


func buy_potion() -> void:
	if Game.gold < 25 or Game.potions >= Game.MAX_POTIONS:
		hud.toast("Falta ouro" if Game.gold < 25 else "Poções cheias", Color(1, 0.7, 0.6))
		return
	Game.gold -= 25
	Game.potions += 1
	Game.stats_changed.emit()
	Sfx.play("coin")


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


## A fireball from the hero (hostile = false) or from a monster (hostile = true).
func cast_fireball(pos: Vector2, dir: Vector2, dmg: int, hostile: bool, source: Node) -> Node2D:
	var f := ProjectileScript.new()
	f.main = self
	f.source = source
	f.position = pos
	f.vel = dir.normalized() * (150.0 if not hostile else 95.0)
	f.dmg = dmg
	f.hostile = hostile
	fx_layer.add_child(f)
	return f


## Arqueria: an arrow from the hero (no burst; pierce set by the caller).
func cast_arrow(pos: Vector2, dir: Vector2, dmg: int, source: Node) -> Node2D:
	var f := ProjectileScript.new()
	f.main = self
	f.source = source
	f.kind = "arrow"
	f.position = pos
	f.vel = dir.normalized() * 280.0
	f.dmg = dmg
	fx_layer.add_child(f)
	return f


## The glowing orb that teaches a magic skill when picked up.
func drop_skill(pos: Vector2, skill: String) -> void:
	var p := PickupScript.new()
	p.kind = "skill"
	p.item_id = skill
	p.player = player
	p.position = pos
	p.vel = Vector2.from_angle(rng.randf() * TAU) * 20.0
	world.entities.call_deferred("add_child", p)


func drop_material(pos: Vector2, id: String, amount: int) -> void:
	for i in amount:
		var p := PickupScript.new()
		p.kind = "item"
		p.item_id = id
		p.value = 1
		p.player = player
		p.position = pos
		p.vel = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(15.0, 45.0)
		world.entities.call_deferred("add_child", p)


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


## One of the vfx_workbench strips (Fx.SHEETS); returns it so callers can turn or tint it.
func vfx(kind: String, pos: Vector2, rot := 0.0, tint := Color.WHITE, parent: Node = null, size := 1.0) -> Node2D:
	var f := _fx(kind, pos)
	f.rotation = rot
	f.scale = Vector2(size, size)
	f.color = tint
	(parent if parent else fx_layer).add_child(f)
	return f


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
