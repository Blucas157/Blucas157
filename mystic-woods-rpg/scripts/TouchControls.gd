extends Control
## On-screen joystick and buttons for phones/tablets (multi-touch).

const FONT := preload("res://assets/ui/pixel_font.ttf")

var main: Node
var stick_finger := -1
var stick_origin := Vector2.ZERO
var stick_pos := Vector2.ZERO
var pressed := {}   # button name -> finger
const STICK_R := 30.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _buttons() -> Dictionary:
	var s := size
	return {
		"attack": [Vector2(s.x - 46, s.y - 48), 22.0, "ATK"],
		"dash": [Vector2(s.x - 98, s.y - 30), 15.0, "ESQ"],
		"interact": [Vector2(s.x - 92, s.y - 78), 14.0, "E"],
		"potion": [Vector2(s.x - 40, s.y - 100), 13.0, "Q"],
		"map": [Vector2(s.x - 98, 14), 10.0, "M"],
		"pause": [Vector2(s.x - 122, 14), 10.0, "II"],
	}


func _input(event: InputEvent) -> void:
	if not visible or main == null or not main.playing:
		return
	if event is InputEventScreenTouch:
		var p: Vector2 = event.position
		if event.pressed:
			for name in _buttons():
				var b: Array = _buttons()[name]
				if p.distance_to(b[0]) <= b[1] + 6.0:
					pressed[name] = event.index
					_fire(name)
					get_viewport().set_input_as_handled()
					queue_redraw()
					return
			if p.x < size.x * 0.5 and stick_finger == -1 and not get_tree().paused:
				stick_finger = event.index
				stick_origin = p
				stick_pos = p
				get_viewport().set_input_as_handled()
		else:
			if event.index == stick_finger:
				stick_finger = -1
				main.player.touch_move = Vector2.ZERO
			for name in pressed.keys():
				if pressed[name] == event.index:
					pressed.erase(name)
		queue_redraw()
	elif event is InputEventScreenDrag and event.index == stick_finger:
		stick_pos = event.position
		var v: Vector2 = (stick_pos - stick_origin) / STICK_R
		main.player.touch_move = v.limit_length(1.0) if v.length() > 0.2 else Vector2.ZERO
		get_viewport().set_input_as_handled()
		queue_redraw()


func _fire(name: String) -> void:
	var p: Node = main.player
	match name:
		"attack":
			p.do_attack()
		"dash":
			p.do_dash()
		"interact":
			p.do_interact()
		"potion":
			p.do_potion()
		"map":
			main.toggle_map()
		"pause":
			main.set_paused(not get_tree().paused)


func _process(_delta: float) -> void:
	if pressed.has("attack") and main and main.player:
		main.player.do_attack()


func _draw() -> void:
	if main == null or not main.playing:
		return
	if stick_finger != -1:
		draw_circle(stick_origin, STICK_R, Color(0.09, 0.11, 0.19, 0.35))
		draw_arc(stick_origin, STICK_R, 0, TAU, 32, Color(1, 1, 1, 0.35), 1.5)
		var knob := stick_origin + (stick_pos - stick_origin).limit_length(STICK_R)
		draw_circle(knob, 11.0, Color(1, 1, 1, 0.45))
	else:
		var hint := Vector2(56, size.y - 56)
		draw_arc(hint, STICK_R, 0, TAU, 32, Color(1, 1, 1, 0.18), 1.5)
	for name in _buttons():
		var b: Array = _buttons()[name]
		var on := pressed.has(name)
		draw_circle(b[0], b[1], Color(0.2, 0.25, 0.54, 0.55 if on else 0.35))
		draw_arc(b[0], b[1], 0, TAU, 32, Color(1, 1, 1, 0.5), 1.5)
		var w := FONT.get_string_size(b[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		draw_string(FONT, b[0] + Vector2(-w / 2.0, 3), b[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.85))
