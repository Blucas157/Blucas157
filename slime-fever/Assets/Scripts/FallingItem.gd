extends Area2D

@export var min_speed: float = 500.0
@export var max_speed: float = 900.0
@export var is_bomb: bool = false
## Power-up id ("magnet"); empty for coins and bombs.
@export var kind: String = ""
# PixelLab bomb strips, 48x48 frames: lit fuse loop and the swell into the explosion.
const FUSE_SHEET := "res://Assets/VFX/bomb_fuse.png"
const DETONATE_SHEET := "res://Assets/VFX/bomb_detonate.png"
const BOMB_FRAME := 48
static var bomb_frames: SpriteFrames
var drift: float = 0.0
var art: AnimatedSprite2D
var age: float = 0.0
var speed: float
var resolved: bool = false
var startled: bool = false

func _ready() -> void:
	speed = randf_range(min_speed, max_speed)
	collision_layer = 2
	collision_mask = 1
	area_entered.connect(_on_area_entered)
	if is_bomb:
		$CollisionShape2D.shape = $CollisionShape2D.shape.duplicate()
		$CollisionShape2D.shape.radius = 10.0
	else:
		# ALCANCE upgrade: coins and power-ups can be caught from farther away.
		$CollisionShape2D.shape = $CollisionShape2D.shape.duplicate()
		$CollisionShape2D.shape.radius *= GameManager.reach_scale()
	if is_bomb:
		art = $AnimatedSprite2D
		art.sprite_frames = _bomb_frames()
		# The bomb body sits 4 px below the centre of its 48 px frame.
		art.offset = Vector2(0, -4)
		art.play("fuse")
		art.frame = randi() % art.sprite_frames.get_frame_count("fuse")

static func _bomb_frames() -> SpriteFrames:
	if bomb_frames == null:
		bomb_frames = SpriteFrames.new()
		bomb_frames.remove_animation("default")
		for anim in [["fuse", FUSE_SHEET, 12.0, true], ["detonate", DETONATE_SHEET, 24.0, false]]:
			var sheet: Texture2D = load(anim[1])
			bomb_frames.add_animation(anim[0])
			bomb_frames.set_animation_speed(anim[0], anim[2])
			bomb_frames.set_animation_loop(anim[0], anim[3])
			for i in sheet.get_width() / BOMB_FRAME:
				var frame := AtlasTexture.new()
				frame.atlas = sheet
				frame.region = Rect2(i * BOMB_FRAME, 0, BOMB_FRAME, BOMB_FRAME)
				bomb_frames.add_frame(anim[0], frame)
	return bomb_frames

## Stops the bomb, plays its swell and hands over to the explosion effect.
func _detonate(size: float, flash: bool) -> void:
	speed = 0.0
	drift = 0.0
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	art.rotation = 0.0
	art.play("detonate")
	var swell := create_tween()
	swell.tween_property(art, "scale", Vector2(1.35, 1.35), 0.2)
	await art.animation_finished
	get_tree().current_scene.explode(global_position, size, flash)
	queue_free()

func _process(delta: float) -> void:
	if GameManager.ended or not GameManager.started:
		return
	position.y += speed * delta
	position.x += drift * delta
	age += delta
	if art and art.animation == "fuse":
		# Swing like a lit fuse; drifting bombs lean into their motion.
		art.rotation = sin(age * 7.0 + position.x) * 0.18 + drift * 0.0015
	if is_bomb and not startled:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player and position.y > player.position.y - 280 and position.y < player.position.y - 100 and absf(position.x - player.position.x) < 260:
			startled = true
			player.react_startle()
	if kind != "":
		# Power-ups bob so they stand out from the coins.
		$Sprite2D.scale = Vector2.ONE * (1.0 + sin(age * 9.0) * 0.08)
	elif not is_bomb:
		_pull(delta)
	if position.y > 2050:
		if not is_bomb and kind == "":
			GameManager.miss_coin()
		queue_free()

## Fever and the magnet drag nearby coins sideways toward the slime.
func _pull(delta: float) -> void:
	var reach := 0.0
	if GameManager.fever_left > 0.0 and position.y > 1250.0:
		reach = 210.0
	if GameManager.magnet_left > 0.0 and position.y > 900.0:
		reach = maxf(reach, GameManager.magnet_radius())
	if reach <= 0.0:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and absf(player.position.x - position.x) < reach:
		position.x = move_toward(position.x, player.position.x, 1400.0 * delta)

func _on_area_entered(area: Area2D) -> void:
	if resolved or GameManager.ended or not area.is_in_group("player"):
		return
	resolved = true
	var main := get_tree().current_scene
	if is_bomb:
		if GameManager.fever_left > 0.0:
			GameManager.add_score(20)
			main.juice(position, Color("a3ffce"), "+20", 2)
			_detonate(3.0, false)
			return
		elif GameManager.grace_left > 0.0:
			main.juice(position, Color("92c9ff"), "PROTEGIDO", 0)
		elif GameManager.use_shield():
			main.juice(position, Color("8ff0ff"), "ESCUDO!", 2)
			_detonate(2.5, false)
			return
		else:
			main.juice(position, Color("ff816b"), "POW!", 3)
			GameManager.end_game()
			_detonate(5.0, true)
			return
	elif kind != "":
		GameManager.collect_powerup(kind)
		main.juice(position, Color("ff9db0"), "ÍMÃ!", 0)
	else:
		var points := GameManager.collect_coin()
		main.juice(position, Color("ffe497"), "+%d" % points, 1)
		area.react_collect()
	queue_free()




