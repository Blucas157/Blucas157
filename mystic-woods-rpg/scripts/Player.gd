extends CharacterBody2D
## The hero: 8-way movement, sword attack, dash, potions and interaction.

signal died

const SPEED := 92.0
const DASH_SPEED := 250.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 0.55
const FX := preload("res://shaders/sprite_fx.gdshader")

var main: Node
var facing := Vector2.DOWN
var state := "move"   # move, attack, dash, dead
var attack_hit_done := false
var attack_cd := 0.0
var dash_t := 0.0
var dash_cd := 0.0
var dash_dir := Vector2.ZERO
var dust_t := 0.0
var invuln := 0.0
var knock := Vector2.ZERO
var flash_t := 0.0
var touch_move := Vector2.ZERO
var sprite: AnimatedSprite2D
var mat: ShaderMaterial


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	shape.position = Vector2(0, -3)
	add_child(shape)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Sheets.character(Sheets.MW + "characters/player.png", 48, ["idle", "move", "attack"], ["death"],
		{"idle": 6, "move": 6, "attack": 4, "death": 3}, {"idle": 7.0, "move": 11.0, "attack": 15.0, "death": 5.0}, ["idle", "move"])
	sprite.offset = Vector2(0, -19)
	mat = ShaderMaterial.new()
	mat.shader = FX
	sprite.material = mat
	add_child(sprite)
	sprite.animation_finished.connect(_on_anim_finished)
	sprite.frame_changed.connect(_on_frame_changed)
	sprite.play("idle_down")


func alive() -> bool:
	return state != "dead"


func input_vector() -> Vector2:
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if touch_move.length() > 0.1:
		v = touch_move
	return v.limit_length(1.0)


func _physics_process(delta: float) -> void:
	attack_cd -= delta
	dash_cd -= delta
	invuln -= delta
	flash_t = max(0.0, flash_t - delta)
	mat.set_shader_parameter("flash", 1.0 if flash_t > 0.0 else 0.0)
	sprite.modulate.a = 0.45 if invuln > 0.0 and state != "dash" and state != "dead" and int(invuln * 18.0) % 2 == 0 else 1.0
	var input := input_vector()
	match state:
		"dead":
			velocity = Vector2.ZERO
		"dash":
			dash_t -= delta
			velocity = dash_dir * DASH_SPEED
			dust_t -= delta
			if dust_t <= 0.0:
				dust_t = 0.04
				if main:
					main.spawn_dust(global_position)
			if dash_t <= 0.0:
				state = "move"
		"attack":
			velocity = input * SPEED * 0.25 + knock
		_:
			if input.length() > 0.1:
				facing = input.normalized()
			velocity = input * SPEED + knock
			_play_dir("move" if input.length() > 0.1 else "idle")
	knock = knock.move_toward(Vector2.ZERO, 700.0 * delta)
	move_and_slide()


func _play_dir(anim: String) -> void:
	var d := Sheets.dir_name(facing)
	sprite.flip_h = d == "side" and facing.x < 0.0
	var name := anim + "_" + d
	if sprite.animation != name or not sprite.is_playing():
		sprite.play(name)


func _unhandled_input(event: InputEvent) -> void:
	if state == "dead" or get_tree().paused:
		return
	if event.is_action_pressed("attack"):
		do_attack()
	elif event.is_action_pressed("dash"):
		do_dash()
	elif event.is_action_pressed("potion"):
		do_potion()
	elif event.is_action_pressed("interact"):
		do_interact()
	elif event.is_action_pressed("inventory") and main:
		main.open_inventory()


func do_attack() -> void:
	if state != "move" or attack_cd > 0.0:
		return
	var input := input_vector()
	if input.length() > 0.1:
		facing = input.normalized()
	state = "attack"
	attack_hit_done = false
	attack_cd = 0.32
	_play_dir("attack")
	sprite.frame = 0
	Sfx.play("swing")


func do_dash() -> void:
	if state != "move" or dash_cd > 0.0:
		return
	var input := input_vector()
	dash_dir = input.normalized() if input.length() > 0.1 else facing.normalized()
	facing = dash_dir
	state = "dash"
	dash_t = DASH_TIME
	dash_cd = DASH_COOLDOWN
	invuln = max(invuln, DASH_TIME + 0.05)
	_play_dir("move")
	Sfx.play("dash")
	_buzz(25)


func do_potion() -> void:
	if Game.use_potion():
		Sfx.play("potion")
		if main:
			main.float_text(global_position + Vector2(0, -28), "+VIDA", Color(0.5, 1.0, 0.5))
	elif main:
		main.hud.toast("Sem poções" if Game.potions <= 0 else "Vida cheia", Color(1, 0.7, 0.6))


func do_interact() -> void:
	if main:
		main.interact(self)


func attack_dir() -> Vector2:
	match Sheets.dir_name(facing):
		"side":
			return Vector2(sign(facing.x), 0)
		"up":
			return Vector2.UP
	return Vector2.DOWN


func _on_frame_changed() -> void:
	if state == "attack" and not attack_hit_done and sprite.frame >= 1:
		attack_hit_done = true
		_apply_attack()


func _apply_attack() -> void:
	var dir := attack_dir()
	var center := global_position + Vector2(0, -8) + dir * 14.0
	var hit_any := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.alive():
			continue
		if e.hurt_center().distance_to(center) <= 18.0 + e.radius:
			var dmg := Game.attack_power() + randi_range(0, 2)
			var crit := randf() < 0.1
			if crit:
				dmg = int(dmg * 1.8)
			e.take_hit(dmg, (e.global_position - global_position).normalized(), crit)
			hit_any = true
	for r in get_tree().get_nodes_in_group("resources"):
		if (r.global_position + Vector2(0, -6)).distance_to(center) <= 18.0 and main:
			r.hit(main)
			hit_any = true
	for b in get_tree().get_nodes_in_group("breakables"):
		if (b.global_position + Vector2(0, -6)).distance_to(center) <= 20.0 and main:
			main.break_object(b)
			hit_any = true
	if hit_any and main:
		main.shake(1.5, 0.08)
		_buzz(15)


func _on_anim_finished() -> void:
	if state == "attack":
		state = "move"
		_play_dir("idle")
	elif state == "dead":
		died.emit()


func take_damage(amount: int, from: Vector2) -> void:
	if state == "dead" or state == "dash" or invuln > 0.0:
		return
	var dmg := Game.damage_player(amount)
	invuln = 0.9
	flash_t = 0.12
	knock = (global_position - from).normalized() * 170.0
	Sfx.play("hurt")
	_buzz(60)
	if main:
		main.float_text(global_position + Vector2(0, -28), str(dmg), Color(1.0, 0.35, 0.35))
		main.shake(3.0, 0.15)
	if Game.hp <= 0:
		_die()


## Short phone vibration as feedback (touch devices only; needs the VIBRATE permission on export).
func _buzz(ms: int) -> void:
	if main and main.is_touch():
		Input.vibrate_handheld(ms)


func _die() -> void:
	state = "dead"
	sprite.flip_h = false
	sprite.play("death")
	Sfx.play("death")


func revive(at: Vector2) -> void:
	global_position = at
	state = "move"
	invuln = 2.0
	knock = Vector2.ZERO
	facing = Vector2.DOWN
	_play_dir("idle")
