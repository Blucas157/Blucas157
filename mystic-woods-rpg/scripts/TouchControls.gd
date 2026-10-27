extends Control
## On-screen controls for phones/tablets (multi-touch): a floating joystick on the left half and
## thumb-sized action buttons on the right, with icons, cooldown ring and potion count.

const FONT := preload("res://assets/ui/pixel_font.ttf")
const UI_ICONS := preload("res://assets/ui/icons.png")
const TOUCH := preload("res://assets/ui/touch.png")   # PixelLab create_ui_asset: wooden rims
## regions in touch.png
const R_BASE := Rect2(17, 17, 77, 77)
const R_KNOB := Rect2(131, 26, 29, 29)
const R_BIG := Rect2(183, 33, 55, 55)
const R_MED := Rect2(21, 146, 39, 39)
const R_MID := Rect2(129, 149, 33, 33)
const R_SMALL := Rect2(178, 153, 25, 25)
const FIREBALL := preload("res://assets/vfx/fireball.png")
const STICK_R := 34.0       # how far the knob travels
const DEAD_ZONE := 0.18     # fraction of STICK_R ignored around the centre
const HIT_PAD := 8.0        # buttons accept touches a little outside their circle
const INK := Color(0.09, 0.11, 0.19)

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
	var b := {
		"attack": [Vector2(s.x - 50, s.y - 52), 27.0],
		"dash": [Vector2(s.x - 110, s.y - 30), 19.0],
		"interact": [Vector2(s.x - 104, s.y - 88), 16.0],
		"potion": [Vector2(s.x - 42, s.y - 116), 16.0],
		"bag": [Vector2(s.x - 158, 17), 12.0],
		"map": [Vector2(s.x - 130, 17), 12.0],
		"pause": [Vector2(s.x - 102, 17), 12.0],
	}
	# the magic button shows up once the hero has learned a skill
	if Game.has_skill("fireball"):
		b["skill"] = [Vector2(s.x - 100, s.y - 136), 16.0]
		b["target"] = [Vector2(s.x - 150, s.y - 118), 12.0]
	return b


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
			# a tap on a monster locks the spell target on it (on the left half the first finger is
			# the joystick's, so there a tap locks only while the stick is already held)
			var stick_zone := p.x < screen().x * 0.5 and p.y > 68.0 and stick_finger == -1
			if not map_only and not stick_zone and Game.has_skill("fireball") and _tap_lock(p):
				get_viewport().set_input_as_handled()
				return
			# anywhere on the left half (below the stats panel) grabs the joystick there
			if not map_only and p.x < screen().x * 0.5 and p.y > 68.0 and stick_finger == -1:
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


## Screen point -> world; locks the monster under the finger (generous radius for thumbs).
func _tap_lock(screen_pos: Vector2) -> bool:
	var world_pos := get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	var best: Node = null
	var bd := 18.0
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = e.hurt_center().distance_to(world_pos)
		if e.alive() and d < bd:
			bd = d
			best = e
	if best == null:
		return false
	main.player.lock_on(best)
	return true


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
		"skill":
			p.do_skill()
		"target":
			p.cycle_target()
		"bag":
			main.open_inventory()
		"map":
			main.toggle_map()
		"pause":
			main.set_paused(not get_tree().paused)


func _process(delta: float) -> void:
	pulse += delta
	# redraw every frame: when a menu opens this clears the buttons instead of leaving a stale image
	queue_redraw()
	if not _active():
		return
	# holding the attack button keeps swinging, like holding the key
	if pressed.has("attack") and main.player:
		main.player.do_attack()


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
	var a := 1.0 if stick_finger != -1 else 0.6
	_sprite(R_BASE, o, Color(1, 1, 1, 0.85 * a))
	var knob := o
	if stick_finger != -1:
		knob = o + (stick_pos - o).limit_length(STICK_R)
	_sprite(R_KNOB, knob, Color(1, 1, 1, a))


## Draws a region of touch.png at 1:1, centred on c.
func _sprite(region: Rect2, c: Vector2, col := Color.WHITE) -> void:
	draw_texture_rect_region(TOUCH, Rect2((c - region.size / 2.0).round(), region.size), region, col)


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
		"skill":
			usable = Game.mp >= int(Game.SKILLS["fireball"]["cost"]) and p.skill_cd <= 0.0
		"interact":
			glow = main.hud.hint != ""
	if glow:
		var g := 0.5 + 0.5 * sin(pulse * 6.0)
		draw_circle(c, r + 3.0 + g * 2.0, Color(1.0, 0.85, 0.4, 0.25 + 0.25 * g))
	var tint := Color(1, 1, 1, 0.9)
	if on:
		tint = Color(0.72, 0.72, 0.8, 1.0)   # pressed: darker and one pixel lower
		c += Vector2(0, 1)
	elif not usable:
		tint = Color(0.6, 0.6, 0.65, 0.6)
	var region := R_SMALL
	match name:
		"attack":
			region = R_BIG
		"dash":
			region = R_MED
		"interact", "potion", "skill":
			region = R_MID
	_sprite(region, c, tint)
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
		"target":
			_draw_crosshair(c, Color(1.0, 0.4, 0.32) if p.target_locked else Color(1, 1, 1, 0.85))
		"skill":
			draw_texture_rect_region(FIREBALL, Rect2(c - Vector2(11, 11), Vector2(22, 22)), Rect2(24 * (int(pulse * 12.0) % 8), 0, 24, 24), Color(1, 1, 1, ia))
			_badge(c + Vector2(r - 3, r - 4), str(int(Game.SKILLS["fireball"]["cost"])))
		"bag":
			draw_texture_rect_region(Sheets.tex(ItemDB.ICONS), Rect2(c - Vector2(7, 7), Vector2(14, 14)), ItemDB.icon_index_rect(38))
		"map":
			draw_texture_rect_region(Sheets.tex(ItemDB.ICONS), Rect2(c - Vector2(7, 7), Vector2(14, 14)), ItemDB.icon_index_rect(39))
		"pause":
			draw_rect(Rect2(c + Vector2(-4, -4), Vector2(3, 8)), Color.WHITE)
			draw_rect(Rect2(c + Vector2(1, -4), Vector2(3, 8)), Color.WHITE)


func _draw_crosshair(c: Vector2, col: Color) -> void:
	draw_arc(c, 5.0, 0, TAU, 16, col, 1.0)
	for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(c + d * 3.0, c + d * 8.0, col, 1.0)


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
