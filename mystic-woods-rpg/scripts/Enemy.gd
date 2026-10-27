extends CharacterBody2D
## Generic monster driven by MonsterDB data: wander, chase, attack, stagger, die and drop loot.

const FX := preload("res://shaders/sprite_fx.gdshader")
const FONT := preload("res://assets/ui/pixel_font.ttf")

var id := ""
var def := {}
var lvl := 1
var max_hp := 10
var hp := 10
var atk := 3
var speed := 40.0
var radius := 6.0
var grid := 32
var is_boss := false
var home := Vector2.ZERO
var state := "idle"   # idle, wander, chase, attack, hurt, dead
var facing := Vector2.DOWN
var main: Node
var player: Node2D
var sprite: AnimatedSprite2D
var mat: ShaderMaterial
var think_t := 0.0
var wander_target := Vector2.ZERO
var attack_cd := 0.0
var hit_done := false
var lunge_v := Vector2.ZERO
var knock := Vector2.ZERO
var flash_t := 0.0
var bar_t := 0.0
var t := 0.0
var engaged := false
var summon_marks := [0.75, 0.5, 0.25]
var rival := {}          # set for a returning rival (see Rivals.gd)
var flee_rolled := false
var flee_t := 0.0
var flee_chance := -1.0  # tests force it; < 0 uses the Rivals defaults
var flame: AnimatedSprite2D   # fire casters hold a small flame (vfx_workbench loop)
var ui: Node2D                # life bar / name, above the sprite
var bar_y := -20.0
## living world (Factions.gd)
var faction := ""
var foe = null                # who it fights: the hero, or a monster of a faction at war with it
var foe_t := 0.0
var last_kind := "melee"      # how it was last hurt: melee / magic / faction:<id>
var regroup_t := 0.0
var regroup_used := false
var slot := 0                 # its side when surrounding a target (cerco)
var hero_lock := 0.0          # after the hero hits it, it ignores everything else for a while
var curse_t := 0.0            # Maldição (Bruxaria): slower and takes more damage
var root_t := 0.0             # Raízes (Espiritual): cannot move
static var _top_cache := {}   # monster id -> highest opaque pixel of its idle frame (local y)


func setup(monster_id: String, level: int, pos: Vector2, p_main: Node) -> void:
	id = monster_id
	def = MonsterDB.get_def(id)
	lvl = level
	position = pos
	home = pos
	main = p_main
	var mult := 1.0 + 0.22 * (lvl - 1)
	max_hp = int(round(float(def["hp"]) * mult))
	hp = max_hp
	atk = int(round(float(def["atk"]) * (1.0 + 0.15 * (lvl - 1))))
	speed = def["speed"]
	radius = def["radius"]
	grid = def["grid"]
	is_boss = def.get("boss", false)
	faction = Factions.of(id) if not is_boss else ""
	if faction != "":
		var m: Array = Factions.stat_mult(faction)
		max_hp = int(round(max_hp * float(m[0])))
		hp = max_hp
		atk = int(round(atk * float(m[1])))
		speed *= float(m[2])
	if Game.inferno() and not is_boss:
		max_hp = int(round(max_hp * 1.5))
		hp = max_hp
		atk = int(round(atk * 1.35))
		speed *= 1.08
	elif Game.inferno():
		max_hp = int(round(max_hp * 1.3))
		hp = max_hp
		atk = int(round(atk * 1.2))
	slot = randi() % 4
	think_t = randf_range(0.2, 2.0)
	t = randf() * 10.0


## Turn this monster into a returning rival: its own level, much tougher, bigger, named.
func apply_rival(r: Dictionary) -> void:
	rival = r
	lvl = int(r["level"])
	var mult := 1.0 + 0.22 * (lvl - 1)
	max_hp = int(round(float(def["hp"]) * mult * 1.8))
	hp = max_hp
	atk = int(round(float(def["atk"]) * (1.0 + 0.15 * (lvl - 1)) * 1.25))
	speed *= 1.1


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 0 if def["behavior"] in ["ghost", "fly"] else 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	shape.position = Vector2(0, -2)
	add_child(shape)
	sprite = AnimatedSprite2D.new()
	var fps := {"idle": 6.0, "move": float(def.get("fps_move", 10.0)), "attack": float(def.get("fps_attack", 10.0)),
		"damaged": 10.0, "death": 8.0}
	sprite.sprite_frames = Sheets.character(def["path"], grid, ["idle", "move", "attack", "damaged"], ["death"],
		def["frames"], fps, ["idle", "move"])
	sprite.offset = Vector2(0, grid / 2.0 - float(def["feet"]))
	mat = ShaderMaterial.new()
	mat.shader = FX
	mat.set_shader_parameter("hue_shift", float(def.get("hue", 0.0)))
	var tint: Color = def.get("tint", Color.WHITE)
	mat.set_shader_parameter("tint", tint)
	sprite.material = mat
	sprite.modulate.a = float(def.get("alpha", 1.0))
	add_child(sprite)
	scale = Vector2.ONE * float(def.get("scale", 1.0)) * (1.15 if not rival.is_empty() else 1.0)
	if not rival.is_empty():
		add_to_group("rivals")
		# a faint crimson cast marks rivals in the crowd
		mat.set_shader_parameter("tint", Color(1.12, 0.9, 0.9))
	if def.get("flame", false):
		flame = AnimatedSprite2D.new()
		flame.sprite_frames = Sheets.strip("res://assets/vfx/flame.png", 16, 23, 8, 10.0, true)
		flame.centered = false
		flame.offset = Vector2(-8, -16)
		flame.position = Vector2(9, -13)
		flame.play("default")
		add_child(flame)
	ui = Node2D.new()
	ui.z_index = 20
	ui.draw.connect(_draw_ui)
	add_child(ui)
	bar_y = _sprite_top() - 5.0
	sprite.frame_changed.connect(_on_frame_changed)
	sprite.animation_finished.connect(_on_anim_finished)
	_play("idle")


func alive() -> bool:
	return state != "dead"


## Local y of the top of the drawn monster (first opaque row of its first idle frame).
func _sprite_top() -> float:
	var key := id + ("|%d" % grid)
	if not _top_cache.has(key):
		var top := float(grid) * 0.6
		var tex := sprite.sprite_frames.get_frame_texture("idle_down" if sprite.sprite_frames.has_animation("idle_down") else sprite.animation, 0)
		if tex:
			var img := tex.get_image()
			if img:
				var used := img.get_used_rect()
				if used.size.y > 0:
					top = float(grid) / 2.0 - float(used.position.y)
		_top_cache[key] = top
	# sprite is centred: the frame top sits at offset.y - grid/2
	return (sprite.offset.y - float(_top_cache[key]))


## Distance from a point to the monster's body (a column from its feet to its chest), so low
## shots and orbiting spirits hit tall monsters too.
func body_distance(p: Vector2) -> float:
	var a := global_position + Vector2(0, -2)
	var b := hurt_center()
	var ab := b - a
	var t := 0.0 if ab.length_squared() < 0.01 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func hurt_center() -> Vector2:
	return global_position + Vector2(0, -float(def["feet"]) * 0.35 * scale.y)


func display_name() -> String:
	if not rival.is_empty():
		return "%s Nv.%d" % [Rivals.full_name(rival), lvl]
	if def.get("miniboss", false):
		return "%s (Mini-chefe) Nv.%d" % [def["name"], lvl]
	var adj: String = Factions.TIER_ADJ[Factions.tier(faction)] if faction != "" else ""
	if adj != "":
		return "%s %s Nv.%d" % [def["name"], adj, lvl]
	return "%s Nv.%d" % [def["name"], lvl]


func _play(anim: String) -> void:
	var d := Sheets.dir_name(facing)
	sprite.flip_h = d == "side" and facing.x < 0.0
	var name := anim + "_" + d
	if sprite.animation != name or not sprite.is_playing():
		sprite.play(name)


func _physics_process(delta: float) -> void:
	t += delta
	attack_cd -= delta
	flash_t = max(0.0, flash_t - delta)
	mat.set_shader_parameter("flash", 1.0 if flash_t > 0.0 else 0.0)
	if bar_t > 0.0:
		bar_t -= delta
		ui.queue_redraw()
	if state == "dead" or player == null:
		return
	foe_t -= delta
	hero_lock -= delta
	curse_t -= delta
	root_t -= delta
	sprite.self_modulate = Color(0.75, 0.5, 1.15) if curse_t > 0.0 else (Color(0.6, 1.1, 0.6) if root_t > 0.0 else Color.WHITE)
	if foe_t <= 0.0:
		foe_t = 0.4
		_pick_foe()
	if not _foe_ok():
		foe = player
	var to_p: Vector2 = foe.global_position - global_position
	var dist := to_p.length()
	var player_ok: bool = _foe_ok()
	var night: float = main.night_amount() if main else 0.0
	var aggro := float(def["aggro"]) * (1.0 + 0.6 * night)
	var spd := speed * (1.0 + 0.2 * night)
	match state:
		"idle", "wander":
			if player_ok and dist < aggro:
				state = "chase"
				if is_boss and not engaged:
					engaged = true
					main.boss_engaged(self)
			think_t -= delta
			if think_t <= 0.0:
				think_t = randf_range(1.5, 3.5)
				if randf() < 0.6:
					wander_target = home + Vector2(randf_range(-48, 48), randf_range(-48, 48))
					state = "wander"
				else:
					state = "idle"
			if state == "wander":
				var to_w := wander_target - global_position
				if to_w.length() < 4.0:
					state = "idle"
					velocity = Vector2.ZERO
				else:
					velocity = to_w.normalized() * speed * 0.45 * _gait()
			else:
				velocity = Vector2.ZERO
		"chase":
			var leash := 240.0 if is_boss else 300.0
			if not player_ok or dist > aggro * 2.0 or global_position.distance_to(home) > leash:
				state = "wander"
				wander_target = home
				think_t = 3.0
				velocity = Vector2.ZERO
				if is_boss:
					# the boss goes back to its arena and recovers
					engaged = false
					hp = max_hp
					summon_marks = [0.75, 0.5, 0.25]
			elif regroup_t > 0.0:
				# tactical retreat: back off, then return to the fight
				regroup_t -= delta
				velocity = -to_p.normalized() * spd
			elif _feint_wait():
				# feint: circle just out of reach while the hero's dodge lasts
				velocity = to_p.normalized().orthogonal() * spd * 0.6 + (-to_p.normalized() * spd * 0.3 if dist < float(def["reach"]) + 6.0 else Vector2.ZERO)
			elif def["attack"] == "ranged":
				# casters keep their distance and throw from afar
				var keep := float(def.get("keep_away", 50.0))
				if dist <= float(def["reach"]) and attack_cd <= 0.0:
					_start_attack(to_p)
				elif dist < keep:
					velocity = -to_p.normalized() * spd * 0.8
				elif dist > float(def["reach"]) * 0.85:
					velocity = to_p.normalized() * spd
				else:
					velocity = to_p.normalized().orthogonal() * spd * 0.4 * (1.0 if fmod(t, 6.0) < 3.0 else -1.0)
			elif dist <= float(def["reach"]) + 4.0 and attack_cd <= 0.0:
				_start_attack(to_p)
			else:
				var dir := to_p.normalized()
				if Factions.has_adapt(faction, "cerco") and dist > float(def["reach"]) * 2.0:
					# surround: head for its own side of the target instead of queueing behind the others
					var side: Vector2 = foe.global_position + Vector2.from_angle(to_p.angle() + PI + (slot - 1.5) * 0.9) * float(def["reach"])
					dir = (side - global_position).normalized()
				if def["behavior"] == "fly":
					dir = (dir + dir.orthogonal() * sin(t * 5.0) * 0.8).normalized()
				if dist <= float(def["reach"]):
					dir = Vector2.ZERO
				velocity = dir * spd * _gait() + _spread()
		"attack":
			velocity = lunge_v
			lunge_v = lunge_v.move_toward(Vector2.ZERO, 500.0 * delta)
		"hurt":
			velocity = Vector2.ZERO
		"flee":
			_flee_step(delta, to_p)
	if root_t > 0.0:
		velocity = Vector2.ZERO
	elif curse_t > 0.0:
		velocity *= 0.6
	velocity += knock
	knock = knock.move_toward(Vector2.ZERO, 600.0 * delta)
	move_and_slide()
	if collision_mask == 0 and main:
		global_position = global_position.clamp(Vector2(64, 64), main.world.world_rect().size - Vector2(64, 64))
	if state in ["idle", "wander", "chase", "flee"]:
		if velocity.length() > 3.0:
			facing = velocity.normalized()
		if state == "chase" and velocity.length() <= 3.0:
			facing = to_p.normalized()
		_play("move" if velocity.length() > 3.0 or (def["behavior"] == "fly") else "idle")
	if flame:
		flame.position.x = -9.0 if sprite.flip_h else 9.0


## Who to fight. The hero always comes first: when he is in sight, factions at war drop their
## feud and all turn on him. Only with the hero away do they fight each other, over the land.
func _pick_foe() -> void:
	foe = player
	if faction == "" or hero_lock > 0.0:
		return
	var night: float = main.night_amount() if main else 0.0
	var reach := float(def["aggro"]) * 1.2
	if player and player.alive() and player.global_position.distance_to(global_position) < reach * (1.0 + 0.6 * night):
		return
	var best := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or not e.alive() or not Factions.at_war(faction, e.faction):
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d < reach and d < best:
			best = d
			foe = e


func _foe_ok() -> bool:
	if foe == null or not is_instance_valid(foe):
		return false
	return foe.alive()


func _foe_is_hero() -> bool:
	return foe == player


## Fintas: wait for the hero's dodge to end before swinging.
func _feint_wait() -> bool:
	return _foe_is_hero() and Factions.has_adapt(faction, "finta") and (player.state == "dash" or player.invuln > 0.3)


## Formação dispersa: keep a little room from friends so one explosion cannot catch them all.
func _spread() -> Vector2:
	if not Factions.has_adapt(faction, "dispersar"):
		return Vector2.ZERO
	var push := Vector2.ZERO
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and e.faction == faction:
			var d: Vector2 = global_position - e.global_position
			if d.length() < 22.0 and d.length() > 0.1:
				push += d.normalized() * (22.0 - d.length()) * 2.0
	return push


func _gait() -> float:
	# slimes and mushrooms move in hops: fast in the air frames, nearly still on landing
	if def["behavior"] == "hop" and sprite.animation.begins_with("move"):
		return 1.7 if sprite.frame in [1, 2, 3, 4] else 0.1
	return 1.0


func _start_attack(to_p: Vector2) -> void:
	state = "attack"
	hit_done = false
	facing = to_p.normalized()
	var night: float = main.night_amount() if main else 0.0
	attack_cd = float(def["cooldown"]) * randf_range(0.9, 1.2) * (1.0 - 0.25 * night)
	velocity = Vector2.ZERO
	_play("attack")


func _on_frame_changed() -> void:
	if state != "attack":
		return
	var hf: int = def["hit_frame"]
	if sprite.frame == hf - 1 and def.has("lunge"):
		lunge_v = facing * float(def["lunge"])
	if sprite.frame >= hf and not hit_done:
		hit_done = true
		_do_hit()


func _do_hit() -> void:
	if not _foe_ok():
		return
	if not _foe_is_hero():
		_hit_monster(foe)
		return
	player.last_hit_by = self
	var d := player.global_position.distance_to(global_position)
	if player.state == "dash" and d <= (float(def["reach"]) + 12.0) * scale.x and faction != "":
		# the hero dodged this one: the faction takes note
		if Factions.learn(faction, "dodge") != "":
			main.faction_learned(faction)
	if def["attack"] == "ranged":
		var from := hurt_center() + facing * 8.0
		var ball: Node = main.cast_fireball(from, player.global_position + Vector2(0, -8) - from, _atk_now(), true, self)
		ball.faction = faction
		Sfx.play("swing", 0.6)
		return
	if def["attack"] == "aoe":
		var r := float(def["aoe"]) * scale.x
		main.shockwave(global_position, r, Color(0.9, 0.85, 0.7) if id != "mushroom" else Color(0.85, 0.75, 0.3))
		if id in ["golem", "treant"]:
			Sfx.play("slam")
			main.shake(4.0 if is_boss else 2.5, 0.2)
		if d <= r:
			player.take_damage(_atk_now(), global_position)
	else:
		if d <= (float(def["reach"]) + 8.0) * scale.x:
			player.take_damage(_atk_now(), global_position)


## At night monsters hit harder (and see further, run faster and attack more often).
func _atk_now() -> int:
	var night: float = main.night_amount() if main else 0.0
	return int(round(atk * (1.0 + 0.2 * night)))


## Monster against monster (factions at war).
func _hit_monster(e: Node) -> void:
	var d: float = e.global_position.distance_to(global_position)
	if def["attack"] == "ranged":
		var from := hurt_center() + facing * 8.0
		var ball: Node = main.cast_fireball(from, e.hurt_center() - from, atk, true, self)
		ball.faction = faction
		return
	var r := float(def.get("aoe", def["reach"])) + 10.0
	if d <= r * scale.x:
		e.take_hit(atk, (e.global_position - global_position).normalized(), false, "faction:" + faction)


func _on_anim_finished() -> void:
	match state:
		"attack", "hurt":
			if state != "flee":
				state = "chase"
		"dead":
			var tw := create_tween()
			tw.tween_interval(0.6 if not is_boss else 2.0)
			tw.tween_property(self, "modulate:a", 0.0, 0.6)
			tw.tween_callback(queue_free)


func take_hit(dmg: int, dir: Vector2, crit: bool = false, kind: String = "melee") -> void:
	if state == "dead":
		return
	last_kind = kind
	if not kind.begins_with("faction"):
		# hit by the hero: he is the enemy now, whatever else is around
		foe = player
		hero_lock = 4.0
		if state in ["idle", "wander"]:
			state = "chase"
	var blocked := false
	if kind == "melee" and Factions.has_adapt(faction, "escudos"):
		dmg = int(ceil(dmg * 0.8))
		if randf() < 0.25:
			dmg = int(ceil(dmg * 0.5))
			blocked = true
	elif kind == "magic" and Factions.has_adapt(faction, "dispersar"):
		dmg = int(ceil(dmg * 0.75))
	if blocked:
		main.float_text(hurt_center() + Vector2(0, -20), "Bloqueou!", Color(0.75, 0.85, 1.0))
	if curse_t > 0.0:
		dmg = int(ceil(dmg * 1.25))
	if not kind.begins_with("faction"):
		# Ceifador (Bruxaria): the hero finishes off the badly hurt
		if Archetypes.bonus("execute") > 0.0 and not is_boss and hp - dmg > 0 and float(hp - dmg) / max_hp < Archetypes.bonus("execute") / 100.0:
			dmg = hp
			main.float_text(hurt_center() + Vector2(0, -24), "Executado!", Color(0.8, 0.5, 1.0))
		# Dreno (Bruxaria): part of the damage heals the hero
		if Archetypes.bonus("drain") > 0.0:
			Game.drain_heal(dmg * Archetypes.bonus("drain") / 100.0)
	if Factions.has_adapt(faction, "chamado") and not kind.begins_with("faction"):
		_call_for_help()
	if Factions.has_adapt(faction, "recuo") and not regroup_used and float(hp - dmg) / max_hp < 0.35 and hp - dmg > 0:
		regroup_used = true
		regroup_t = 1.2
	hp -= dmg
	flash_t = 0.12
	bar_t = 3.0
	Sfx.play("hit", 1.3 if crit else 1.0)
	main.float_text(hurt_center() + Vector2(0, -10), str(dmg) + ("!" if crit else ""),
		Color(1.0, 0.85, 0.2) if crit else Color.WHITE)
	main.vfx("hit", hurt_center(), randf() * TAU, Color.WHITE, null, 0.6)
	knock = dir * 160.0 * (1.0 - float(def.get("knock_resist", 0.0)))
	if not engaged and is_boss:
		engaged = true
		main.boss_engaged(self)
	if state in ["idle", "wander"]:
		state = "chase"
	if hp <= 0:
		_die()
		return
	if state == "flee":
		return
	if _try_flee():
		return
	if is_boss:
		_check_summons()
		main.hud.update_boss(self)
	elif float(def.get("knock_resist", 0.0)) < 0.8 or randf() < 0.25:
		state = "hurt"
		_play("damaged")


## Grito de guerra: friends of the same faction nearby join the fight.
func _call_for_help() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and e.faction == faction and e.state in ["idle", "wander"] and e.global_position.distance_to(global_position) < 160.0:
			e.state = "chase"


## Badly hurt monsters may run for it once; if they get away they come back as rivals.
func _try_flee() -> bool:
	if flee_rolled or is_boss or float(hp) / max_hp > Rivals.FLEE_HP:
		return false
	flee_rolled = true
	if rival.is_empty() and Game.rivals.size() >= Rivals.MAX:
		return false
	if _region() in ["", "vila"]:
		return false
	var chance := flee_chance if flee_chance >= 0.0 else (Rivals.FLEE_CHANCE_RIVAL if not rival.is_empty() else Rivals.FLEE_CHANCE)
	if randf() >= chance:
		return false
	state = "flee"
	flee_t = 1.6
	collision_mask = 0
	main.float_text(hurt_center() + Vector2(0, -16), Rivals.taunt(rival, "flee"), Color(1.0, 0.6, 0.5))
	return true


func _flee_step(delta: float, to_p: Vector2) -> void:
	flee_t -= delta
	velocity = -to_p.normalized() * speed * 1.7
	modulate.a = clampf(flee_t / 0.8, 0.0, 1.0)
	if flee_t <= 0.0:
		_escaped()


func _escaped() -> void:
	state = "dead"
	remove_from_group("enemies")
	var r := Game.rival_event(id, lvl, _region(), "flee", int(rival.get("uid", -1)))
	if not r.is_empty():
		main.rival_escaped(r)
	queue_free()


func _region() -> String:
	if main == null or main.world == null:
		return ""
	return main.world.gen.region_at(main.world.pos_to_cell(global_position))


func _check_summons() -> void:
	var ratio := float(hp) / max_hp
	while not summon_marks.is_empty() and ratio <= summon_marks[0]:
		summon_marks.pop_front()
		main.hud.toast("O Ent Ancião chama a floresta!", Color(0.6, 1.0, 0.5))
		for k in 3:
			var a := TAU * k / 3.0 + randf()
			main.spawn_enemy("mushroom" if k < 2 else "goblin", global_position + Vector2(cos(a), sin(a)) * 40.0, max(1, lvl - 2))


func _die() -> void:
	state = "dead"
	velocity = Vector2.ZERO
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	sprite.flip_h = false
	sprite.play("death")
	Sfx.play("death")
	main.vfx("puff", hurt_center())
	if last_kind.begins_with("faction:"):
		# killed in a faction war: the winners grow, the hero gets no reward for it
		var winner := last_kind.substr(8)
		Factions.gain_xp(winner, 2.0)
		Factions.skirmish_won(winner, faction, _region())
		var ws := Factions.st(winner)
		if not ws.is_empty():
			ws["kills"] = int(ws["kills"]) + 1
		var ls := Factions.st(faction)
		if not ls.is_empty():
			ls["losses"] = int(ls["losses"]) + 1
		for d in ItemDB.DROPS.get(id, []):
			if randf() < float(d[1]) * 0.5:
				main.drop_material(global_position, d[0], 1)
		return
	var xp := int(round(float(def["xp"]) * (1.0 + 0.2 * (lvl - 1)) * (1.5 if Game.inferno() else 1.0)))
	main.float_text(hurt_center() + Vector2(0, -18), "+%d XP" % xp, Color(0.55, 0.85, 1.0))
	Game.add_xp(xp)
	Game.register_kill(id)
	if faction != "":
		# they remember how they were beaten, and get angrier with the hero
		var fs := Factions.st(faction)
		fs["losses"] = int(fs["losses"]) + 1
		fs["grudge"] = float(fs["grudge"]) + 1.0
		Factions.gain_xp(faction, 1.0)
		Factions.hero_won_on(faction, _region())
		if Factions.learn(faction, last_kind) != "":
			main.faction_learned(faction)
	# Sede de Sangue (Guerra) and Pacto (Bruxaria)
	if Archetypes.bonus("lifesteal_kill") > 0.0 and Game.hp > 0:
		Game.heal(int(Archetypes.bonus("lifesteal_kill")))
	if Archetypes.bonus("mp_on_kill") > 0.0:
		Game.restore_mana(int(Archetypes.bonus("mp_on_kill")))
	var g: Array = def["gold"]
	var bonus := 1.5 if Game.inferno() else 1.0   # Hell Mode: harder, but richer
	var gold := int(randi_range(int(g[0]), int(g[1])) * (1.0 + 0.15 * (lvl - 1)) * bonus)
	main.drop_loot(global_position, gold, (0.08 if not is_boss else 1.0) * bonus, 0.15 * bonus)
	if id == "guardiao_pagma" and Game.pagma_stage == 1:
		main.drop_pagma_tome(global_position)
	for d in ItemDB.DROPS.get(id, []):
		if randf() < float(d[1]) * (1.3 if Game.inferno() else 1.0):
			main.drop_material(global_position, d[0], 1)
	if def.has("teaches") and not Game.has_skill(def["teaches"]):
		main.drop_skill(global_position, def["teaches"])
	if flame:
		flame.queue_free()
		flame = null
	if is_boss:
		main.boss_defeated(self)
	if not rival.is_empty():
		main.rival_defeated(self)


## Life bar and rival name live on their own child node drawn above the sprite (and above
## neighbours), placed just over the top of the monster's real silhouette.
func _draw_ui() -> void:
	if state == "dead" or is_boss:
		return
	var y := bar_y
	if not rival.is_empty():
		# rivals always show their name and life
		var label: String = rival["name"]
		var lw := FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		ui.draw_string_outline(FONT, Vector2(-lw / 2.0, y - 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(0.09, 0.11, 0.19))
		ui.draw_string(FONT, Vector2(-lw / 2.0, y - 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.55, 0.45))
		bar_t = maxf(bar_t, 0.1)
	if bar_t <= 0.0:
		return
	# mini-bosses and rivals get a wider bar with a gold frame so they read as a bigger threat
	var mini: bool = def.get("miniboss", false) or not rival.is_empty()
	var w := 28.0 if mini else 16.0
	ui.draw_rect(Rect2(-w / 2 - 1, y - 1, w + 2, 4), Color(0.85, 0.6, 0.27) if mini else Color(0.09, 0.11, 0.19))
	ui.draw_rect(Rect2(-w / 2, y, w, 2), Color(0.09, 0.11, 0.19))
	ui.draw_rect(Rect2(-w / 2, y, w * clamp(float(hp) / max_hp, 0.0, 1.0), 2), Color(0.74, 0.29, 0.32))
