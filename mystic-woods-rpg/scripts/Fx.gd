extends Node2D
## Short-lived visual effects: floating numbers, shock rings and dust puffs.

var kind := "text"
var text := ""
var color := Color.WHITE
var radius := 20.0
var life := 0.0
var max_life := 0.7
static var font: Font


func _ready() -> void:
	z_index = 20 if kind == "text" else 0
	match kind:
		"text":
			max_life = 0.8
		"ring":
			max_life = 0.35
			z_index = -1
		"dust":
			max_life = 0.32
			var a := AnimatedSprite2D.new()
			a.sprite_frames = Sheets.strip(Sheets.MW + "particles/dust_particles_01.png", 12, 12, 4, 12.0, false)
			a.play("default")
			a.position = Vector2(0, -5)
			add_child(a)


func _process(delta: float) -> void:
	life += delta
	if life >= max_life:
		queue_free()
		return
	if kind == "text":
		position.y -= 26.0 * delta
	queue_redraw()


func _draw() -> void:
	var k := life / max_life
	match kind:
		"text":
			if font == null:
				font = load("res://assets/ui/pixel_font.ttf")
			var a := 1.0 if k < 0.6 else 1.0 - (k - 0.6) / 0.4
			var size := 8
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			var c := color
			c.a = a
			draw_string_outline(font, Vector2(-w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0.09, 0.11, 0.19, a))
			draw_string(font, Vector2(-w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)
		"ring":
			var c2 := color
			c2.a = 0.8 * (1.0 - k)
			var r := radius * (0.3 + 0.7 * k)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, c2, 2.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
