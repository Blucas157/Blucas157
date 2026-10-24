extends CharacterBody2D
## Generic monster driven by MonsterDB data: wander, chase, attack, stagger, die and drop loot.

const FX := preload("res://shaders/sprite_fx.gdshader")

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
	think_t = randf_range(0.2, 2.0)
	t = randf() * 10.0


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
	scale = Vector2.ONE * float(def.get("scale", 1.0))
	sprite.frame_changed.connect(_on_frame_changed)
	sprite.animation_finished.connect(_on_anim_finished)
	_play("idle")


func alive() -> bool:
	return state != "dead"


func hurt_center() -> Vector2:
	return global_position + Vector2(0, -float(def["feet"]) * 0.35 * scale.y)


func display_name() -> String:
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
		queue_redraw()
	if state == "dead" or player == null:
		return
	var to_p := player.global_position - global_position
	var dist := to_p.length()
	var player_ok: bool = player.alive()
	match state:
		"idle", "wander":
			if player_ok and dist < float(def["aggro"]):
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
			if not player_ok or dist > float(def["aggro"]) * 2.0 or global_position.distance_to(home) > leash:
				state = "wander"
				wander_target = home
				think_t = 3.0
				velocity = Vector2.ZERO
				if is_boss:
					# the boss goes back to its arena and recovers
					engaged = false
					hp = max_hp
					summon_marks = [0.75, 0.5, 0.25]
			elif dist <= float(def["reach"]) + 4.0 and attack_cd <= 0.0:
				_start_attack(to_p)
			else:
				var dir := to_p.normalized()
				if def["behavior"] == "fly":
					dir = (dir + dir.orthogonal() * sin(t * 5.0) * 0.8).normalized()
				if dist <= float(def["reach"]):
					dir = Vector2.ZERO
				velocity = dir * speed * _gait()
		"attack":
			velocity = lunge_v
			lunge_v = lunge_v.move_toward(Vector2.ZERO, 500.0 * delta)
		"hurt":
			velocity = Vector2.ZERO
	velocity += knock
	knock = knock.move_toward(Vector2.ZERO, 600.0 * delta)
	move_and_slide()
	if collision_mask == 0 and main:
		global_position = global_position.clamp(Vector2(64, 64), main.world.world_rect().size - Vector2(64, 64))
	if state in ["idle", "wander", "chase"]:
		if velocity.length() > 3.0:
			facing = velocity.normalized()
		if state == "chase" and velocity.length() <= 3.0:
			facing = to_p.normalized()
		_play("move" if velocity.length() > 3.0 or (def["behavior"] == "fly") else "idle")


func _gait() -> float:
	# slimes and mushrooms move in hops: fast in the air frames, nearly still on landing
	if def["behavior"] == "hop" and sprite.animation.begins_with("move"):
		return 1.7 if sprite.frame in [1, 2, 3, 4] else 0.1
	return 1.0


func _start_attack(to_p: Vector2) -> void:
	state = "attack"
	hit_done = false
	facing = to_p.normalized()
	attack_cd = float(def["cooldown"]) * randf_range(0.9, 1.2)
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
	if player == null or not player.alive():
		return
	var d := player.global_position.distance_to(global_position)
	if def["attack"] == "aoe":
		var r := float(def["aoe"]) * scale.x
		main.shockwave(global_position, r, Color(0.9, 0.85, 0.7) if id != "mushroom" else Color(0.85, 0.75, 0.3))
		if id in ["golem", "treant"]:
			Sfx.play("slam")
			main.shake(4.0 if is_boss else 2.5, 0.2)
		if d <= r:
			player.take_damage(atk, global_position)
	else:
		if d <= (float(def["reach"]) + 8.0) * scale.x:
			player.take_damage(atk, global_position)


func _on_anim_finished() -> void:
	match state:
		"attack", "hurt":
			state = "chase"
		"dead":
			var tw := create_tween()
			tw.tween_interval(0.6 if not is_boss else 2.0)
			tw.tween_property(self, "modulate:a", 0.0, 0.6)
			tw.tween_callback(queue_free)


func take_hit(dmg: int, dir: Vector2, crit: bool = false) -> void:
	if state == "dead":
		return
	hp -= dmg
	flash_t = 0.12
	bar_t = 3.0
	Sfx.play("hit", 1.3 if crit else 1.0)
	main.float_text(hurt_center() + Vector2(0, -10), str(dmg) + ("!" if crit else ""),
		Color(1.0, 0.85, 0.2) if crit else Color.WHITE)
	knock = dir * 160.0 * (1.0 - float(def.get("knock_resist", 0.0)))
	if not engaged and is_boss:
		engaged = true
		main.boss_engaged(self)
	if state in ["idle", "wander"]:
		state = "chase"
	if hp <= 0:
		_die()
		return
	if is_boss:
		_check_summons()
		main.hud.update_boss(self)
	elif float(def.get("knock_resist", 0.0)) < 0.8 or randf() < 0.25:
		state = "hurt"
		_play("damaged")


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
	var xp := int(round(float(def["xp"]) * (1.0 + 0.2 * (lvl - 1))))
	main.float_text(hurt_center() + Vector2(0, -18), "+%d XP" % xp, Color(0.55, 0.85, 1.0))
	Game.add_xp(xp)
	Game.register_kill(id)
	var g: Array = def["gold"]
	var gold := int(randi_range(int(g[0]), int(g[1])) * (1.0 + 0.15 * (lvl - 1)))
	main.drop_loot(global_position, gold, 0.08 if not is_boss else 1.0, 0.15)
	for d in ItemDB.DROPS.get(id, []):
		if randf() < float(d[1]):
			main.drop_material(global_position, d[0], 1)
	if is_boss:
		main.boss_defeated(self)


func _draw() -> void:
	if bar_t <= 0.0 or state == "dead" or is_boss:
		return
	var w := 16.0
	var y := {32: -20.0, 48: -30.0, 64: -42.0}.get(grid, -56.0) as float
	draw_rect(Rect2(-w / 2 - 1, y - 1, w + 2, 4), Color(0.09, 0.11, 0.19))
	draw_rect(Rect2(-w / 2, y, w * clamp(float(hp) / max_hp, 0.0, 1.0), 2), Color(0.74, 0.29, 0.32))
