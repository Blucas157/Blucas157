extends Control
## On-screen controls for phones/tablets (multi-touch): a floating joystick on the left half and
## thumb-sized action buttons on the right, with icons, cooldown ring and potion count.

const FONT := preload("res://assets/ui/pixel_font.ttf")
const UI_ICONS := preload("res://assets/ui/icons.png")
const STICK_R := 34.0       # how far the knob travels
const DEAD_ZONE := 0.18     # fraction of STICK_R ignored around the centre
const HIT_PAD := 8.0        # buttons accept touches a little outside their circle
const INK := Color(0.09, 0.11, 0.19)
const BLUE := Color(0.2, 0.25, 0.54)

var main: Node
var stick_finger := -1
var stick_origin := Vector2.ZERO
var stick_pos := Vector2.ZERO
var pressed := {}   # button name -> finger
var pulse := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Screen size in viewport pixels. A Control under a CanvasLayer can report a zero size,
## which used to push every button off-screen, so read the viewport instead.
func screen() -> Vector2:
	return get_viewport_rect().size


func stick_home() -> Vector2:
	return Vector2(62, screen().y - 62)


## name -> [centre, radius]; laid out for the right thumb, menu buttons along the top
func _buttons() -> Dictionary:
	var s := screen()
	return {
		"attack": [Vector2(s.x - 50, s.y - 52), 25.0],
		"dash": [Vector2(s.x - 108, s.y - 30), 18.0],
		"interact": [Vector2(s.x - 102, s.y - 88), 15.0],
		"potion": [Vector2(s.x - 42, s.y - 114), 15.0],
		"bag": [Vector2(s.x - 154, 16), 11.0],
		"map": [Vector2(s.x - 128, 16), 11.0],
		"pause": [Vector2(s.x - 102, 16), 11.0],
	}


## Menus (pause, backpack, shops) take the screen; the big map keeps only its own button.
func _active() -> bool:
	return visible and main != null and main.playing and (not get_tree().paused or main.hud.map_open)


func _input(event: InputEvent) -> void:
	if not _active():
		if stick_finger != -1 or not pressed.is_empty():
			_release_all()
		return
	var map_only: bool = main.hud.map_open
	if event is InputEventScreenTouch:
		var p: Vector2 = event.position
		if event.pressed:
			var btns := _buttons()
			for name in btns:
				if map_only and name != "map":
					continue
				var b: Array = btns[name]
				if p.distance_to(b[0]) <= b[1] + HIT_PAD:
					pressed[name] = event.index
					_fire(name)
					get_viewport().set_input_as_handled()
					queue_redraw()
					return
			# anywhere on the left half (below the stats panel) grabs the joystick there
			if not map_only and p.x < screen().x * 0.5 and p.y > 50.0 and stick_finger == -1:
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
		if v.length() < DEAD_ZONE:
			main.player.touch_move = Vector2.ZERO
		else:
			# rescale past the dead zone so a small push walks slowly and a full push runs
			main.player.touch_move = v.normalized() * inverse_lerp(DEAD_ZONE, 1.0, minf(v.length(), 1.0))
		get_viewport().set_input_as_handled()
		queue_redraw()


func _release_all() -> void:
	stick_finger = -1
	pressed.clear()
	if main and main.player:
		main.player.touch_move = Vector2.ZERO
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
		"bag":
			main.open_inventory()
		"map":
			main.toggle_map()
		"pause":
			main.set_paused(not get_tree().paused)


func _process(delta: float) -> void:
	pulse += delta
	if not _active():
		return
	# holding the attack button keeps swinging, like holding the key
	if pressed.has("attack") and main.player:
		main.player.do_attack()
	queue_redraw()


# ---------------------------------------------------------------- drawing
func _draw() -> void:
	if not _active():
		return
	var map_only: bool = main.hud.map_open
	if not map_only:
		_draw_stick()
	var btns := _buttons()
	for name in btns:
		if map_only and name != "map":
			continue
		var b: Array = btns[name]
		_draw_button(name, b[0], b[1])


func _draw_stick() -> void:
	var o := stick_origin if stick_finger != -1 else stick_home()
	var a := 1.0 if stick_finger != -1 else 0.55
	draw_circle(o, STICK_R + 4.0, Color(INK, 0.32 * a))
	draw_arc(o, STICK_R + 4.0, 0, TAU, 40, Color(1, 1, 1, 0.35 * a), 1.5)
	# direction ticks so the base reads as a pad even before it is touched
	for k in 4:
		var d := Vector2.RIGHT.rotated(k * TAU / 4.0)
		draw_line(o + d * (STICK_R - 6.0), o + d * (STICK_R - 1.0), Color(1, 1, 1, 0.3 * a), 1.5)
	var knob := o
	if stick_finger != -1:
		knob = o + (stick_pos - o).limit_length(STICK_R)
	draw_circle(knob, 13.0, Color(BLUE, 0.75 * a))
	draw_arc(knob, 13.0, 0, TAU, 28, Color(1, 1, 1, 0.7 * a), 1.5)


func _draw_button(name: String, c: Vector2, r: float) -> void:
	var on := pressed.has(name)
	var p: Node = main.player
	var usable := true
	var glow := false
	match name:
		"dash":
			usable = p.dash_cd <= 0.0 and p.state == "move"
		"potion":
			usable = Game.potions > 0
		"interact":
			glow = main.hud.hint != ""
	var fill := Color(BLUE, 0.7 if on else 0.42)
	if not usable:
		fill = Color(INK, 0.45)
	if glow:
		var g := 0.5 + 0.5 * sin(pulse * 6.0)
		draw_circle(c, r + 3.0 + g * 2.0, Color(1.0, 0.85, 0.4, 0.25 + 0.25 * g))
	draw_circle(c, r, fill)
	draw_arc(c, r, 0, TAU, 36, Color(1, 1, 1, 0.75 if usable else 0.35), 1.5)
	var ia := 1.0 if usable else 0.45
	match name:
		"attack":
			draw_texture_rect_region(UI_ICONS, Rect2(c - Vector2(12, 12), Vector2(24, 24)), Rect2(0, 0, 16, 16), Color(1, 1, 1, ia))
		"dash":
			_draw_dodge(c, ia)
			if p.dash_cd > 0.0:
				# cooldown ring empties clockwise as the dodge recharges
				var left: float = clampf(p.dash_cd / p.DASH_COOLDOWN, 0.0, 1.0)
				draw_arc(c, r - 2.5, -PI / 2.0, -PI / 2.0 + TAU * left, 32, Color(1.0, 0.85, 0.4, 0.9), 2.5)
		"interact":
			_label(c + Vector2(0, 5), "!", 16, Color(1.0, 0.92, 0.6, 1.0 if glow else 0.6))
		"potion":
			draw_texture_rect_region(Sheets.tex(ItemDB.ICONS), Rect2(c - Vector2(8, 9), Vector2(16, 16)), ItemDB.icon_index_rect(35), Color(1, 1, 1, ia))
			_badge(c + Vector2(r - 3, r - 4), str(Game.potions))
		"bag":
			draw_texture_rect_region(Sheets.tex(ItemDB.ICONS), Rect2(c - Vector2(7, 7), Vector2(14, 14)), ItemDB.icon_index_rect(38))
		"map":
			draw_texture_rect_region(Sheets.tex(ItemDB.ICONS), Rect2(c - Vector2(7, 7), Vector2(14, 14)), ItemDB.icon_index_rect(39))
		"pause":
			draw_rect(Rect2(c + Vector2(-4, -4), Vector2(3, 8)), Color.WHITE)
			draw_rect(Rect2(c + Vector2(1, -4), Vector2(3, 8)), Color.WHITE)


func _draw_dodge(c: Vector2, a: float) -> void:
	# two chevrons: a quick step aside
	var col := Color(1, 1, 1, a)
	for k in 2:
		var x := -5.0 + k * 6.0
		draw_polyline(PackedVector2Array([c + Vector2(x, -6), c + Vector2(x + 5, 0), c + Vector2(x, 6)]), col, 2.0)


func _badge(at: Vector2, text: String) -> void:
	var w: float = maxf(10.0, FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 5.0)
	draw_rect(Rect2(at - Vector2(w / 2.0, 6), Vector2(w, 11)), INK)
	draw_rect(Rect2(at - Vector2(w / 2.0, 6), Vector2(w, 11)), Color(1, 1, 1, 0.6), false, 1.0)
	_label(at + Vector2(0, 3), text, 8, Color.WHITE)


func _label(at: Vector2, text: String, size_px: int, col: Color) -> void:
	var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	draw_string(FONT, at - Vector2(w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)
