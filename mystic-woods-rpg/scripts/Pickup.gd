extends Node2D
## Coins, potions and hearts that bounce out of monsters and chests and fly to the player.

var kind := "coin"
var value := 1
var vel := Vector2.ZERO
var z := 0.0
var vz := 0.0
var age := 0.0
var player: Node2D
var sprite: Node2D


func _ready() -> void:
	if kind == "coin":
		var a := AnimatedSprite2D.new()
		a.sprite_frames = Sheets.strip("res://assets/ui/coin.png", 10, 10, 4, 10.0, true)
		a.play("default")
		a.frame = randi() % 4
		sprite = a
	else:
		var s := Sprite2D.new()
		s.texture = Sheets.tex(Sheets.MW + "objects/objects.png")
		s.region_enabled = true
		s.region_rect = Rect2(144, 64, 16, 16) if kind == "potion" else Rect2(128, 32, 16, 16)
		sprite = s
	sprite.position = Vector2(0, -5)
	add_child(sprite)
	vz = randf_range(70.0, 120.0)


func _process(delta: float) -> void:
	age += delta
	z += vz * delta
	vz -= 320.0 * delta
	if z <= 0.0:
		z = 0.0
		vz = -vz * 0.45 if abs(vz) > 25.0 else 0.0
		vel *= 0.6
	position += vel * delta
	vel = vel.move_toward(Vector2.ZERO, 60.0 * delta)
	sprite.position.y = -5.0 - z
	if player and age > 0.45 and player.alive():
		var to := player.global_position + Vector2(0, -6) - global_position
		var d := to.length()
		var magnet := 46.0 if kind == "coin" else 22.0
		if d < 8.0:
			_collect()
			return
		if d < magnet:
			position += to.normalized() * (60.0 + (magnet - d) * 5.0) * delta
	if age > 45.0:
		queue_free()
	elif age > 40.0:
		visible = int(age * 8.0) % 2 == 0


func _collect() -> void:
	match kind:
		"coin":
			Game.add_gold(value)
			Sfx.play("coin")
		"potion":
			if not Game.add_potion():
				Game.heal(15)
			Sfx.play("potion")
		"heart":
			Game.heal(8)
			Sfx.play("potion", 1.3)
	queue_free()
