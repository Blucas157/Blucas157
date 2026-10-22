extends Area2D

@export var min_speed: float = 500.0
@export var max_speed: float = 900.0
@export var is_bomb: bool = false
var drift: float = 0.0
var art: Sprite2D
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
	if is_bomb and ResourceLoader.exists("res://Assets/New/bomb.png"):
		$AnimatedSprite2D.hide()
		art = Sprite2D.new()
		art.texture = load("res://Assets/New/bomb.png")
		add_child(art)

func _process(delta: float) -> void:
	if GameManager.ended or not GameManager.started:
		return
	position.y += speed * delta
	position.x += drift * delta
	age += delta
	if art:
		# Swing like a lit fuse; drifting bombs lean into their motion.
		art.rotation = sin(age * 7.0 + position.x) * 0.18 + drift * 0.0015
	if is_bomb and not startled:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player and position.y > player.position.y - 280 and position.y < player.position.y - 100 and absf(position.x - player.position.x) < 260:
			startled = true
			player.react_startle()
	if not is_bomb and GameManager.fever_left > 0.0 and position.y > 1250.0:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player and absf(player.position.x - position.x) < 210.0:
			position.x = move_toward(position.x, player.position.x, 1000.0 * delta)
	if position.y > 2050:
		if not is_bomb:
			GameManager.miss_coin()
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if resolved or GameManager.ended or not area.is_in_group("player"):
		return
	resolved = true
	var main := get_tree().current_scene
	if is_bomb:
		if GameManager.fever_left > 0.0:
			GameManager.add_score(20)
			main.explode(position, 3.0)
			main.juice(position, Color("a3ffce"), "+20", 2)
		elif GameManager.grace_left > 0.0:
			main.juice(position, Color("92c9ff"), "PROTEGIDO", 0)
		else:
			main.explode(position, 5.0, true)
			main.juice(position, Color("ff816b"), "POW!", 3)
			GameManager.end_game()
	else:
		var points := GameManager.collect_coin()
		main.juice(position, Color("ffe497"), "+%d" % points, 1)
		area.react_collect()
	queue_free()




