extends Area2D

@export var walk_speed: float = 850.0
@export var run_speed: float = 850.0
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var visual_time: float = 0.0
var reaction: String = ""
var reaction_left: float = 0.0
var startle_cooldown: float = 0.0
var collapse: Tween

func _ready() -> void:
	add_to_group("player")
	sprite.sprite_frames = sprite.sprite_frames.duplicate()
	for name in ["collect", "startle", "fever", "defeat"]:
		var frames := sprite.sprite_frames
		frames.add_animation(name)
		frames.set_animation_loop(name, name == "fever")
		frames.set_animation_speed(name, 18.0 if name == "collect" else (10.0 if name == "defeat" else 14.0))
		for i in 7:
			var path := "res://Assets/SlimeReactions/%s_%02d.png" % [name, i]
			if ResourceLoader.exists(path):
				frames.add_frame(name, load(path))
	GameManager.game_ended.connect(_defeat)
	GameManager.fever_started.connect(_fever)
	sprite.play("idle_west")

func _process(delta: float) -> void:
	visual_time += delta
	queue_redraw()
	if GameManager.ended or not GameManager.started:
		return
	var direction := get_direction()
	position.x = clampf(position.x + direction * walk_speed * delta, 80.0, 1000.0)
	reaction_left = maxf(0.0, reaction_left - delta)
	startle_cooldown = maxf(0.0, startle_cooldown - delta)
	var animation := "idle_west"
	if GameManager.fever_left > 0.0:
		animation = "fever"
	elif reaction_left > 0.0:
		animation = reaction
	elif not is_zero_approx(direction):
		animation = "run"
	if sprite.sprite_frames.get_frame_count(animation) > 0:
		sprite.play(animation)
	if animation in ["run", "idle_west"]:
		if not is_zero_approx(direction):
			sprite.flip_h = direction > 0.0
	else:
		sprite.flip_h = false
	var stretch := sin(visual_time * 20.0) * 0.055 if not is_zero_approx(direction) else 0.0
	sprite.scale = sprite.scale.lerp(Vector2(1.0 + stretch, 1.0 - stretch), 1.0 - exp(-15.0 * delta))
	sprite.rotation = lerp_angle(sprite.rotation, direction * 0.05, 1.0 - exp(-15.0 * delta))

func react_collect() -> void:
	if GameManager.ended or GameManager.fever_left > 0.0 or (reaction == "startle" and reaction_left > 0.0):
		return
	reaction = "collect"
	reaction_left = 7.0 / 18.0
	sprite.stop()
	sprite.play(reaction)

func react_startle() -> void:
	if GameManager.ended or GameManager.fever_left > 0.0 or startle_cooldown > 0.0:
		return
	reaction = "startle"
	reaction_left = 0.5
	startle_cooldown = 1.3
	sprite.play(reaction)

func _fever() -> void:
	reaction_left = 0.0
	sprite.flip_h = false
	sprite.play("fever")

func _defeat() -> void:
	reaction_left = 0.0
	sprite.flip_h = false
	sprite.rotation = 0.0
	sprite.scale = Vector2.ONE
	sprite.play("defeat")
	if collapse and collapse.is_valid():
		collapse.kill()
	collapse = create_tween().set_parallel(true)
	collapse.tween_property(sprite, "scale", Vector2(1.3, 0.45), 0.55).set_delay(0.2)
	collapse.tween_property(sprite, "position:y", 8.0, 0.55).set_delay(0.2)

func _draw() -> void:
	# Local visual only: no changes to the Area2D scale or collision shape.
	if GameManager.fever_left > 0.0 and not GameManager.ended:
		var pulse := 1.0 + sin(visual_time * 8.0) * 0.08
		draw_arc(Vector2(0, 6), 17.0 * pulse, 0, TAU, 32, Color(0.5, 1, 0.8, 0.45), 1.0)
	if GameManager.magnet_left > 0.0 and not GameManager.ended:
		# Shows the magnet's reach (game pixels divided by this node's scale).
		var reach := GameManager.magnet_radius() / scale.x
		var spin := visual_time * 2.0
		for i in 8:
			var start := spin + i * TAU / 8.0
			draw_arc(Vector2(0, 2), reach, start, start + TAU / 14.0, 8, Color(1.0, 0.45, 0.6, 0.85), 1.6)

func get_direction() -> float:
	var left := Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A)
	var right := Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D)
	for button in get_tree().get_nodes_in_group("direction_buttons"):
		if button.is_held():
			if button.direction < 0:
				left = true
			else:
				right = true
	return float(right) - float(left)



func reset_visual() -> void:
	if collapse and collapse.is_valid():
		collapse.kill()
	reaction = ""
	reaction_left = 0.0
	startle_cooldown = 0.0
	sprite.position = Vector2.ZERO
	sprite.rotation = 0.0
	sprite.scale = Vector2.ONE
	sprite.modulate = Color.WHITE
	sprite.play("idle_west")
