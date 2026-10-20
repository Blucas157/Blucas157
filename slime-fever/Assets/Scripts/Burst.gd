extends Node2D

var particles: Array[Dictionary] = []
var age: float = 0.0
var tint: Color = Color.WHITE

func setup(color: Color, count: int) -> void:
	tint = color
	for i in count:
		particles.append({"p": Vector2.ZERO, "v": Vector2.from_angle(randf() * TAU) * randf_range(100, 400), "s": randf_range(5, 12)})

func _process(delta: float) -> void:
	age += delta
	for p in particles:
		p.p += p.v * delta
		p.v.y += 700.0 * delta
	queue_redraw()
	if age > 0.65:
		queue_free()

func _draw() -> void:
	var color := tint
	color.a = maxf(0.0, 1.0 - age / 0.65)
	for p in particles:
		draw_rect(Rect2(p.p, Vector2.ONE * p.s), color)

