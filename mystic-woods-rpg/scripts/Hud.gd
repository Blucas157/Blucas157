extends CanvasLayer
## In-game HUD and menus (title, pause, world map, game over). Everything is built in code.

const FONT := preload("res://assets/ui/pixel_font.ttf")
const ICONS := preload("res://assets/ui/icons.png")
const STATUS := preload("res://assets/ui/hud_status.png")
const MENU_KIT := preload("res://assets/ui/menu_kit.png")   # PixelLab create_ui_asset: wooden menu kit
const KIT_WINDOW := Rect2(8, 8, 143, 134)
const KIT_PLAQUE := Rect2(158, 10, 90, 26)
const KIT_INSET := Rect2(158, 48, 90, 60)
const KIT_BUTTON := Rect2(10, 155, 93, 34)   # PixelLab create_ui_asset: wooden frames
## regions in hud_status.png: [region, inner rect relative to the region]
const ST_PANEL := Rect2(8, 8, 161, 65)
const ST_PORTRAIT := Rect2(188, 18, 47, 49)
const ST_BAR_BIG := [Rect2(8, 95, 161, 17), Rect2(6, 5, 149, 5)]
const ST_BAR_MID := [Rect2(8, 125, 161, 15), Rect2(5, 5, 151, 5)]
const ST_BAR_SMALL := [Rect2(8, 153, 161, 10), Rect2(4, 4, 153, 2)]
const HERO_SHEET := "res://assets/mystic_woods/sprites/characters/player.png"
const HP_COL := Color("bc4952")
const MP_COL := Color("2c65b5")
const XP_COL := Color("e9ce7c")
const DARK := Color(0.09, 0.11, 0.19, 0.86)
const EDGE := Color(0.79, 0.70, 0.64)

var main: Node
var draw_root: Control
var menu_root: Control
var theme_ui: Theme
var toasts: Array = []
var banner := ""
var banner_t := 0.0
var hint := ""
var boss: Node = null
var fog_image: Image
var fog_texture: ImageTexture
var fog_dirty := false
var map_open := false
var touch: Control
var loot_feed: Array = []   # {id, n, t}


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme_ui = Theme.new()
	theme_ui.default_font = FONT
	theme_ui.default_font_size = 16
	_style_buttons()
	draw_root = Control.new()
	draw_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw_root.draw.connect(_draw_hud)
	add_child(draw_root)
	menu_root = Control.new()
	menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_root.theme = theme_ui
	add_child(menu_root)
	Game.message.connect(toast)


## Wooden 9-slice from menu_kit.png (PixelLab create_ui_asset). m = border kept 1:1, pad = content margin.
func _kit(region: Rect2, m: float, pad: Vector4 = Vector4(-1, -1, -1, -1), tint := Color.WHITE) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = MENU_KIT
	sb.region_rect = region
	sb.set_texture_margin_all(m)
	sb.modulate_color = tint
	if pad.x >= 0.0:
		sb.content_margin_left = pad.x
		sb.content_margin_top = pad.y
		sb.content_margin_right = pad.z
		sb.content_margin_bottom = pad.w
	return sb


func _style_buttons() -> void:
	var pad := Vector4(10, 4, 10, 5)
	theme_ui.set_stylebox("normal", "Button", _kit(KIT_BUTTON, 8, pad))
	theme_ui.set_stylebox("hover", "Button", _kit(KIT_BUTTON, 8, pad, Color(1.18, 1.12, 1.0)))
	theme_ui.set_stylebox("pressed", "Button", _kit(KIT_BUTTON, 8, Vector4(10, 5, 10, 4), Color(0.72, 0.72, 0.8)))
	theme_ui.set_stylebox("disabled", "Button", _kit(KIT_BUTTON, 8, pad, Color(0.6, 0.6, 0.65, 0.8)))
	# keyboard/pad focus: a gold frame over the button
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color("e9ce7c")
	focus.set_border_width_all(1)
	focus.set_corner_radius_all(3)
	focus.set_expand_margin_all(1)
	theme_ui.set_stylebox("focus", "Button", focus)
	theme_ui.set_color("font_color", "Button", Color.WHITE)
	theme_ui.set_color("font_focus_color", "Button", Color("ffe9a8"))
	theme_ui.set_color("font_hover_color", "Button", Color("ffe9a8"))
	theme_ui.set_constant("outline_size", "Button", 3)
	theme_ui.set_color("font_outline_color", "Button", Color("171c31"))
	theme_ui.set_constant("outline_size", "Label", 4)
	theme_ui.set_color("font_outline_color", "Label", Color("171c31"))


func screen_size() -> Vector2:
	return draw_root.size


func _process(delta: float) -> void:
	for t in toasts:
		t["t"] -= delta
	toasts = toasts.filter(func(t): return t["t"] > 0.0)
	banner_t = max(0.0, banner_t - delta)
	for l in loot_feed:
		l["t"] -= delta
	loot_feed = loot_feed.filter(func(l): return l["t"] > 0.0)
	if fog_dirty and fog_texture:
		fog_texture.update(fog_image)
		fog_dirty = false
	draw_root.queue_redraw()


# ---------------------------------------------------------------- messages
func toast(text: String, color: Color = Color.WHITE) -> void:
	toasts.append({"text": text, "color": color, "t": 3.2})
	if toasts.size() > 3:
		toasts.pop_front()


func loot(id: String, n: int) -> void:
	for l in loot_feed:
		if l["id"] == id:
			l["n"] += n
			l["t"] = 3.0
			return
	loot_feed.append({"id": id, "n": n, "t": 3.0})
	if loot_feed.size() > 5:
		loot_feed.pop_front()


func show_banner(text: String) -> void:
	banner = text
	banner_t = 3.0


func update_boss(b: Node) -> void:
	boss = b


# ---------------------------------------------------------------- fog of war minimap
func setup_fog(source: Image, explored: PackedByteArray) -> void:
	fog_image = Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	fog_image.fill(Color(0.06, 0.07, 0.12))
	for y in source.get_height():
		for x in source.get_width():
			if explored[y * source.get_width() + x] == 1:
				fog_image.set_pixel(x, y, source.get_pixel(x, y))
	fog_texture = ImageTexture.create_from_image(fog_image)


func reveal(source: Image, explored: PackedByteArray, c: Vector2i, r: int) -> void:
	var w := source.get_width()
	for y in range(c.y - r, c.y + r + 1):
		for x in range(c.x - r, c.x + r + 1):
			if x < 0 or y < 0 or x >= w or y >= source.get_height():
				continue
			if explored[y * w + x] == 1 or Vector2(x - c.x, y - c.y).length() > r:
				continue
			explored[y * w + x] = 1
			fog_image.set_pixel(x, y, source.get_pixel(x, y))
			fog_dirty = true


# ---------------------------------------------------------------- drawing
func _text(pos: Vector2, s: String, size_px: int = 8, col: Color = Color.WHITE, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_root.draw_string_outline(FONT, pos, s, align, width, size_px, 3, Color("171c31"))
	draw_root.draw_string(FONT, pos, s, align, width, size_px, col)


func _panel(r: Rect2) -> void:
	draw_root.draw_rect(r, DARK)
	draw_root.draw_rect(r, Color("171c31"), false, 1.0)


func _bar(r: Rect2, ratio: float, col: Color) -> void:
	draw_root.draw_rect(r.grow(1), Color("171c31"))
	draw_root.draw_rect(r, Color("242a3d"))
	draw_root.draw_rect(Rect2(r.position, Vector2(r.size.x * clamp(ratio, 0.0, 1.0), r.size.y)), col)
	draw_root.draw_rect(Rect2(r.position, Vector2(r.size.x * clamp(ratio, 0.0, 1.0), 1)), col.lightened(0.35))


## Nine-slice of a hud_status.png region: corners stay 1:1, edges and middle stretch.
func _nine(src: Rect2, dst: Rect2, m: float) -> void:
	var xs := [0.0, m, src.size.x - m, src.size.x]
	var xd := [0.0, m, dst.size.x - m, dst.size.x]
	var ys := [0.0, m, src.size.y - m, src.size.y]
	var yd := [0.0, m, dst.size.y - m, dst.size.y]
	for j in 3:
		for i in 3:
			var s := Rect2(src.position + Vector2(xs[i], ys[j]), Vector2(xs[i + 1] - xs[i], ys[j + 1] - ys[j]))
			var d := Rect2(dst.position + Vector2(xd[i], yd[j]), Vector2(xd[i + 1] - xd[i], yd[j + 1] - yd[j]))
			draw_root.draw_texture_rect_region(STATUS, d, s)


## A wooden bar frame (stretched in width only) with its fill.
func _frame_bar(piece: Array, dst: Rect2, ratio: float, col: Color) -> void:
	var src: Rect2 = piece[0]
	var inner: Rect2 = piece[1]
	var cap := 8.0
	draw_root.draw_texture_rect_region(STATUS, Rect2(dst.position, Vector2(cap, src.size.y)), Rect2(src.position, Vector2(cap, src.size.y)))
	draw_root.draw_texture_rect_region(STATUS, Rect2(dst.position + Vector2(cap, 0), Vector2(dst.size.x - 2 * cap, src.size.y)),
		Rect2(src.position + Vector2(cap, 0), Vector2(src.size.x - 2 * cap, src.size.y)))
	draw_root.draw_texture_rect_region(STATUS, Rect2(dst.position + Vector2(dst.size.x - cap, 0), Vector2(cap, src.size.y)),
		Rect2(src.end - Vector2(cap, src.size.y), Vector2(cap, src.size.y)))
	var w := dst.size.x - (src.size.x - inner.size.x)
	var fill := Rect2(dst.position + inner.position, Vector2(roundf(w * clampf(ratio, 0.0, 1.0)), inner.size.y))
	if fill.size.x <= 0.0:
		return
	draw_root.draw_rect(fill, col)
	draw_root.draw_rect(Rect2(fill.position, Vector2(fill.size.x, 1)), col.lightened(0.35))
	if inner.size.y > 3:
		draw_root.draw_rect(Rect2(fill.position + Vector2(0, fill.size.y - 1), Vector2(fill.size.x, 1)), col.darkened(0.3))


func _icon(i: int, pos: Vector2) -> void:
	draw_root.draw_texture_rect_region(ICONS, Rect2(pos, Vector2(16, 16)), Rect2(i * 16, 0, 16, 16))


func _draw_hud() -> void:
	if main == null or not main.playing:
		return
	var sz := screen_size()
	# --- stats panel: portrait + level, life, mana (for the magic skills), experience, stats
	_nine(ST_PANEL, Rect2(3, 3, 160, 63), 8)
	var pf := Rect2(Vector2(7, 6), ST_PORTRAIT.size)
	draw_root.draw_texture_rect_region(STATUS, pf, ST_PORTRAIT)
	# hero's head and shoulders at 2x inside the round frame
	draw_root.draw_texture_rect_region(Sheets.tex(HERO_SHEET), Rect2(pf.position + Vector2(7, 9), Vector2(32, 30)), Rect2(17, 21, 16, 15))
	_text(Vector2(pf.position.x, pf.end.y + 2), "Nv %d" % Game.level, 8, Color("ffe9a8"), HORIZONTAL_ALIGNMENT_CENTER, pf.size.x)
	var sbx := 56.0
	var sbw := 103.0
	_frame_bar(ST_BAR_BIG, Rect2(sbx, 6, sbw, 17), float(Game.hp) / Game.max_hp, HP_COL)
	_frame_bar(ST_BAR_MID, Rect2(sbx, 22, sbw, 15), float(Game.mp) / max(1, Game.max_mp), MP_COL)
	_frame_bar(ST_BAR_SMALL, Rect2(sbx, 36, sbw, 10), float(Game.xp) / Game.xp_to_next(), XP_COL)
	_text(Vector2(sbx, 18), "%d/%d" % [Game.hp, Game.max_hp], 8, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, sbw)
	_text(Vector2(sbx, 33), "%d/%d" % [Game.mp, Game.max_mp], 8, Color(0.8, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER, sbw)
	_icon(0, Vector2(sbx - 1, 45))
	_text(Vector2(sbx + 14, 57), str(Game.attack_power()), 8)
	_icon(1, Vector2(sbx + 31, 45))
	_text(Vector2(sbx + 46, 57), str(Game.defense_total()), 8)
	_icon(3, Vector2(sbx + 62, 45))
	_text(Vector2(sbx + 77, 57), str(Game.gold), 8, Color("ffd479"))
	# --- quest tracker
	var q := Game.quest_text().split("\n")
	_text(Vector2(6, 78), q[0], 8, Color("ffe9a8"))
	if q.size() > 1:
		_text(Vector2(6, 88), q[1], 8, Color(0.85, 0.9, 1.0))
	# --- potion counter (bottom-left; on phones the potion button shows the count instead)
	var touch_ui: bool = main.is_touch()
	if not touch_ui:
		var py := sz.y - 8
		draw_root.draw_texture_rect_region(Sheets.tex(Sheets.MW + "objects/objects.png"), Rect2(4, py - 16, 16, 16), Rect2(144, 64, 16, 16))
		_text(Vector2(21, py - 4), "x%d  [Q]" % Game.potions, 8)
	# --- minimap (top-right)
	if fog_texture and not map_open:
		var mr := Rect2(sz.x - 80, 4, 76, 76)
		_panel(mr.grow(2))
		var pc: Vector2 = main.player.global_position / 16.0
		var src := Rect2(pc - Vector2(38, 38), Vector2(76, 76))
		draw_root.draw_texture_rect_region(fog_texture, mr, src)
		_map_markers(mr, src, 1.0)
		draw_root.draw_rect(Rect2(mr.position + mr.size / 2.0 - Vector2(1, 1), Vector2(3, 3)), Color.WHITE)
		_text(Vector2(sz.x - 80, 92), WorldGen.REGION_NAMES.get(main.current_region, ""), 8, Color(0.9, 1.0, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 76)
		var night: float = main.night_amount()
		_text(Vector2(sz.x - 80, 102), "Noite" if night > 0.5 else "Dia", 8, Color(0.7, 0.75, 1.0) if night > 0.5 else Color(1, 0.95, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 76)
	# --- boss bar
	if boss and is_instance_valid(boss) and boss.alive() and boss.engaged:
		var bw := 220.0
		var br := Rect2((sz.x - bw) / 2.0, sz.y - 22, bw, 7)
		_text(Vector2(br.position.x, br.position.y - 4), boss.display_name(), 8, Color("ffb0a0"), HORIZONTAL_ALIGNMENT_CENTER, bw)
		_bar(br, float(boss.hp) / boss.max_hp, Color("9e2e46"))
	# --- interaction hint
	if hint != "":
		# phones show the action next to the glowing "!" button instead of a key name
		var shown := hint.replace("[E] ", "") if touch_ui else hint
		_text(Vector2(0, sz.y - 40), shown, 8, Color("ffe9a8"), HORIZONTAL_ALIGNMENT_CENTER, sz.x)
	# --- region banner
	if banner_t > 0.0:
		var a: float = min(1.0, banner_t) * min(1.0, (3.0 - banner_t) * 3.0)
		var c := Color(1, 1, 1, a)
		var bx := 134.0
		var bw2 := sz.x - bx - 90.0
		draw_root.draw_rect(Rect2(bx, 74, bw2, 26), Color(0.09, 0.11, 0.19, 0.55 * a))
		draw_root.draw_string_outline(FONT, Vector2(bx, 93), banner, HORIZONTAL_ALIGNMENT_CENTER, bw2, 16, 4, Color(0.09, 0.11, 0.19, a))
		draw_root.draw_string(FONT, Vector2(bx, 93), banner, HORIZONTAL_ALIGNMENT_CENTER, bw2, 16, c)
	# --- loot feed (bottom right; above the thumb buttons on phones)
	var ly := sz.y - (140.0 if touch_ui else 20.0)
	for i in range(loot_feed.size() - 1, -1, -1):
		var l: Dictionary = loot_feed[i]
		var a2: float = min(1.0, l["t"] * 2.0)
		var txt := "+%d %s" % [l["n"], ItemDB.item_name(l["id"])]
		var w := FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		draw_root.draw_rect(Rect2(sz.x - w - 30, ly - 11, w + 26, 15), Color(0.09, 0.11, 0.19, 0.6 * a2))
		draw_root.draw_texture_rect_region(Sheets.tex(ItemDB.ICONS), Rect2(sz.x - w - 28, ly - 11, 16, 16), ItemDB.icon_rect(l["id"]), Color(1, 1, 1, a2))
		draw_root.draw_string(FONT, Vector2(sz.x - w - 8, ly), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, a2))
		ly -= 17.0
	# --- toasts
	var ty := 118.0
	for t in toasts:
		for line in String(t["text"]).split("\n"):
			var col: Color = t["color"]
			col.a = min(1.0, t["t"] * 2.0)
			draw_root.draw_string_outline(FONT, Vector2(0, ty), line, HORIZONTAL_ALIGNMENT_CENTER, sz.x, 8, 3, Color(0.09, 0.11, 0.19, col.a))
			draw_root.draw_string(FONT, Vector2(0, ty), line, HORIZONTAL_ALIGNMENT_CENTER, sz.x, 8, col)
			ty += 11.0
	# --- big map
	if map_open:
		draw_root.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.03, 0.04, 0.08, 0.8))
		var side: float = min(sz.x, sz.y) - 30.0
		var mr2 := Rect2((sz.x - side) / 2.0, 20, side, side)
		_panel(mr2.grow(3))
		draw_root.draw_texture_rect(fog_texture, mr2, false)
		var src2 := Rect2(0, 0, WorldGen.W, WorldGen.H)
		_map_markers(mr2, src2, side / WorldGen.W)
		var pp: Vector2 = mr2.position + main.player.global_position / 16.0 * (side / WorldGen.W)
		draw_root.draw_rect(Rect2(pp - Vector2(2, 2), Vector2(5, 5)), Color.WHITE)
		draw_root.draw_rect(Rect2(pp - Vector2(2, 2), Vector2(5, 5)), Color("171c31"), false, 1.0)
		_text(Vector2(0, 14), "MAPA DO MUNDO" if touch_ui else "MAPA DO MUNDO  -  [M] fechar", 8, Color("ffe9a8"), HORIZONTAL_ALIGNMENT_CENTER, sz.x)


func _map_markers(dest: Rect2, src: Rect2, _s: float) -> void:
	var to_dest := func(cell: Vector2) -> Vector2:
		return dest.position + (cell - src.position) / src.size * dest.size
	var explored: PackedByteArray = Game.explored
	for key in WorldGen.POIS:
		var c: Vector2i = WorldGen.POIS[key]
		if explored.size() > 0 and explored[c.y * WorldGen.W + c.x] == 0:
			continue
		var p: Vector2 = to_dest.call(Vector2(c))
		if dest.has_point(p):
			var col := Color("9e2e46") if key == "coracao" and not Game.boss_defeated else Color("d99945")
			draw_root.draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), col)
	for ch in main.world.gen.chests:
		var c2: Vector2i = ch["cell"]
		if Game.opened_chests.has(ch["id"]) or (explored.size() > 0 and explored[c2.y * WorldGen.W + c2.x] == 0):
			continue
		if ch.get("boss", false) and not Game.boss_defeated:
			continue
		var p2: Vector2 = to_dest.call(Vector2(c2))
		if dest.has_point(p2):
			draw_root.draw_rect(Rect2(p2 - Vector2(1, 1), Vector2(2, 2)), Color("ffd479"))
	var vc := Vector2(WorldGen.CENTER)
	var pv: Vector2 = to_dest.call(vc)
	if dest.has_point(pv):
		draw_root.draw_rect(Rect2(pv - Vector2(2, 2), Vector2(4, 4)), Color("65b1b8"))


# ---------------------------------------------------------------- menus
func clear_menu() -> void:
	for c in menu_root.get_children():
		c.queue_free()


## Wooden window centred on screen with the title on a plaque across its top edge.
## Returns the box the caller fills (subtitle label already in it).
func _window(title: String, w: float, h: float, shade_alpha := 0.55) -> VBoxContainer:
	clear_menu()
	var sz := screen_size()
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.04, 0.08, shade_alpha)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(shade)
	h = minf(h, sz.y - 18.0)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _kit(KIT_WINDOW, 18, Vector4(16, 20, 16, 14)))
	panel.position = ((sz - Vector2(w, h)) / 2.0 + Vector2(0, 6)).round()
	panel.size = Vector2(w, h)
	menu_root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	# title plaque straddling the top of the frame
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 16)
	t.add_theme_color_override("font_color", Color("ffe9a8"))
	t.add_theme_constant_override("outline_size", 4)
	var pw := maxf(96.0, FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 34.0)
	var plaque := PanelContainer.new()
	plaque.add_theme_stylebox_override("panel", _kit(KIT_PLAQUE, 10, Vector4(10, 2, 10, 3)))
	plaque.position = Vector2(roundf(panel.position.x + (w - pw) / 2.0), panel.position.y - 12.0)
	plaque.size = Vector2(pw, 26)
	plaque.add_child(t)
	menu_root.add_child(plaque)
	return box


## Recessed dark panel (stats, descriptions) inside a window.
func _inset(parent: Container) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _kit(KIT_INSET, 8, Vector4(8, 5, 8, 5)))
	parent.add_child(p)
	return p


func _menu_box(title: String, subtitle: String = "", h: float = 200.0) -> VBoxContainer:
	var box := _window(title, 300.0, h)
	if subtitle != "":
		var s := Label.new()
		s.text = subtitle
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.add_theme_font_size_override("font_size", 8)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_inset(box).add_child(s)
	return box


func _button(box: Container, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func(): Sfx.play("select"); cb.call())
	box.add_child(b)
	return b


func show_title() -> void:
	var hints := "WASD/Setas mover  -  J/Espaço atacar  -  K/Shift esquivar\nE interagir  -  Q poção  -  F magia  -  M mapa  -  Esc pausa"
	if main and main.is_touch():
		hints = "Joystick: mover  -  Espada: atacar  -  Setas: esquivar\n!: interagir  -  Toque no monstro: mirar a magia"
	var box := _menu_box("Mystic Woods", "Um RPG de mundo aberto\n\n" + hints, 220)
	(menu_root.get_child(0) as ColorRect).color = Color(0.03, 0.04, 0.08, 0.3)
	var first: Button
	if Game.has_save():
		first = _button(box, "Continuar", func(): main.start_game(false))
	var nb := _button(box, "Novo jogo", func(): main.start_game(true))
	if first == null:
		first = nb
	_button(box, "Som: " + ("desligado" if Game.muted else "ligado"), func(): Game.muted = not Game.muted; show_title())
	first.call_deferred("grab_focus")


func show_pause() -> void:
	var box := _window("Pausa", 300.0, 236.0)
	# --- stats: level + experience bar, then attack / defence / gold, then the counters
	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 3)
	_inset(box).add_child(stats)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	stats.add_child(top)
	top.add_child(_small("Nível %d" % Game.level, Color("ffe9a8")))
	var xp := ProgressBar.new()
	xp.show_percentage = false
	xp.max_value = Game.xp_to_next()
	xp.value = Game.xp
	xp.custom_minimum_size = Vector2(0, 6)
	xp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("171c31")
	bg.set_border_width_all(1)
	bg.border_color = Color("0b0e1a")
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("e9ce7c")
	xp.add_theme_stylebox_override("background", bg)
	xp.add_theme_stylebox_override("fill", fill)
	top.add_child(xp)
	top.add_child(_small("XP %d/%d" % [Game.xp, Game.xp_to_next()], Color(0.85, 0.9, 1.0)))
	var mid := HBoxContainer.new()
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 4)
	stats.add_child(mid)
	for it in [[0, str(Game.attack_power()), Color.WHITE], [1, str(Game.defense_total()), Color.WHITE],
			[3, str(Game.gold), Color("ffd479")]]:
		mid.add_child(_ui_icon(int(it[0])))
		var l := _small(it[1], it[2])
		l.custom_minimum_size = Vector2(34, 0)
		mid.add_child(l)
	var low := _small("Monstros: %d   -   Baús: %d   -   Tempo: %d min" % [_total_kills(), Game.opened_chests.size(), int(Game.play_time / 60.0)],
		Color(0.8, 0.84, 0.95))
	low.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_child(low)
	# --- buttons: continue on top, four in a grid, quit below (all fit on a phone screen)
	var cont := _button(box, "Continuar", func(): main.set_paused(false))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	box.add_child(grid)
	for b in [_button(grid, "Mochila", func(): show_inventory()),
			_button(grid, "Rivais (%d)" % Game.rivals.size(), func(): show_rivals()),
			_button(grid, "Salvar jogo", func(): Game.save_game(); toast("Jogo salvo", Color(0.6, 1, 0.6)); main.set_paused(false)),
			_button(grid, "Som: " + ("desligado" if Game.muted else "ligado"), func(): Game.muted = not Game.muted; show_pause())]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(box, "Sair para o título", func(): main.quit_to_title())
	cont.call_deferred("grab_focus")


func _ui_icon(i: int) -> TextureRect:
	var tr := TextureRect.new()
	var a := AtlasTexture.new()
	a.atlas = ICONS
	a.region = Rect2(i * 16, 0, 16, 16)
	tr.texture = a
	tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	return tr


func _total_kills() -> int:
	var n := 0
	for k in Game.kills:
		n += int(Game.kills[k])
	return n


func show_game_over(note: String = "") -> void:
	var text := "Você acorda na Vila do Bosque.\nMetade do ouro carregado ficou para trás."
	if note != "":
		text = note + "\n\n" + text
	var box := _menu_box("Você caiu...", text, 180 if note != "" else 160)
	var b := _button(box, "Renascer na vila", func(): main.respawn())
	b.call_deferred("grab_focus")


func show_victory() -> void:
	var box := _menu_box("Vitória!", "O Ent Ancião foi derrotado e a floresta está em paz.\nUm baú lendário apareceu na arena. Continue explorando!", 160)
	var b := _button(box, "Continuar", func(): main.set_paused(false))
	b.call_deferred("grab_focus")


# ---------------------------------------------------------------- inventory and shops
func _panel_box(title: String) -> VBoxContainer:
	clear_menu()
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.04, 0.08, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(shade)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _kit(KIT_WINDOW, 18, Vector4(14, 12, 14, 12)))
	var w := minf(screen_size().x - 16.0, 420.0)
	panel.position = Vector2(roundf((screen_size().x - w) / 2.0), 6)
	panel.size = Vector2(w, screen_size().y - 12.0)
	menu_root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 16)
	t.add_theme_color_override("font_color", Color("ffe9a8"))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var gold := Label.new()
	gold.text = "Ouro: %d" % Game.gold
	gold.add_theme_font_size_override("font_size", 8)
	gold.add_theme_color_override("font_color", Color("ffd479"))
	head.add_child(gold)
	var close := Button.new()
	close.text = "Fechar"
	close.add_theme_font_size_override("font_size", 8)
	close.pressed.connect(func(): Sfx.play("select"); main.set_paused(false))
	head.add_child(close)
	close.call_deferred("grab_focus")
	return box


func _scroll(box: VBoxContainer) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 3)
	sc.add_child(list)
	return list


func _icon_rect(id: String) -> TextureRect:
	var tr := TextureRect.new()
	var a := AtlasTexture.new()
	a.atlas = Sheets.tex(ItemDB.ICONS)
	a.region = ItemDB.icon_rect(id)
	tr.texture = a
	tr.custom_minimum_size = Vector2(16, 16)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	return tr


func _small(text: String, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 3)
	return l


func show_inventory() -> void:
	var box := _panel_box("Mochila")
	box.add_child(_small("Espada: +%d ATK   %s   Armadura: +%d DEF   Poções: %d" % [
		Game.sword_tier * 3, ItemDB.TOOL_NAMES[Game.tool_tier], int(ItemDB.ARMOR_DEF.get(Game.armor_tier, 0)), Game.potions],
		Color(0.85, 0.9, 1.0)))
	var list := _scroll(box)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	list.add_child(grid)
	if Game.items.is_empty():
		list.add_child(_small("Vazia. Minere veios, colha plantas e derrote monstros!", Color(0.8, 0.8, 0.8)))
	for id in ItemDB.ITEMS:
		if Game.count(id) <= 0:
			continue
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(170, 16)
		row.add_child(_icon_rect(id))
		row.add_child(_small("%s  x%d" % [ItemDB.item_name(id), Game.count(id)]))
		grid.add_child(row)


func show_rivals() -> void:
	var box := _panel_box("Rivais")
	var list := _scroll(box)
	if Game.rivals.is_empty():
		list.add_child(_small("Nenhum rival... por enquanto.", Color(0.85, 0.9, 1.0)))
		list.add_child(_small("Monstros que te derrotarem ou fugirem feridos vão lembrar de você e voltar mais fortes.", Color(0.8, 0.8, 0.8)))
		return
	for r in Game.rivals:
		var def := MonsterDB.get_def(r["monster"])
		list.add_child(_small(Rivals.full_name(r), Color(1.0, 0.6, 0.5)))
		list.add_child(_small("   %s  Nv.%d  -  %s" % [def["name"], r["level"], WorldGen.REGION_NAMES.get(r["region"], r["region"])], Color(0.85, 0.9, 1.0)))
		list.add_child(_small("   " + Rivals.history(r), Color(0.75, 0.75, 0.8)))


func show_shop(kind: String) -> void:
	if kind == "mercador":
		_show_merchant()
		return
	var title := "Ferreiro" if kind == "ferreiro" else "Alquimista"
	var box := _panel_box(title)
	box.add_child(_small("Forjas e ferramentas com os minérios que você coletar." if kind == "ferreiro"
		else "Poções e tônicos com plantas e partes de monstros.", Color(0.85, 0.9, 1.0)))
	var list := _scroll(box)
	for r in ItemDB.RECIPES[kind]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		list.add_child(row)
		var ic := TextureRect.new()
		var at := AtlasTexture.new()
		at.atlas = Sheets.tex(ItemDB.ICONS)
		at.region = ItemDB.icon_index_rect(int(r.get("icon", 38)))
		ic.texture = at
		ic.custom_minimum_size = Vector2(16, 16)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		row.add_child(ic)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 0)
		row.add_child(info)
		info.add_child(_small("%s  -  %s" % [r["name"], r["desc"]], Color("ffe9a8")))
		var costs := HBoxContainer.new()
		costs.add_theme_constant_override("separation", 2)
		info.add_child(costs)
		for id in r["cost"]:
			costs.add_child(_icon_rect(id))
			var have := Game.count(id)
			var need: int = r["cost"][id]
			costs.add_child(_small("%d/%d " % [have, need], Color(0.6, 1, 0.6) if have >= need else Color(1, 0.6, 0.6)))
		costs.add_child(_small("%d ouro" % r["gold"], Color("ffd479") if Game.gold >= int(r["gold"]) else Color(1, 0.6, 0.6)))
		var why: String = main.recipe_state(r)
		var b := Button.new()
		b.text = "Criar" if why == "" else why
		b.disabled = why != ""
		b.add_theme_font_size_override("font_size", 8)
		b.custom_minimum_size = Vector2(70, 0)
		b.pressed.connect(func():
			if main.craft(r):
				show_shop(kind))
		row.add_child(b)


func _show_merchant() -> void:
	var box := _panel_box("Mercador")
	var top := HBoxContainer.new()
	box.add_child(top)
	top.add_child(_small("Poção de Vida: 25 ouro (você tem %d)" % Game.potions, Color(0.85, 0.9, 1.0)))
	var buy := Button.new()
	buy.text = "Comprar"
	buy.add_theme_font_size_override("font_size", 8)
	buy.pressed.connect(func(): main.buy_potion(); _show_merchant())
	top.add_child(buy)
	box.add_child(_small("Vender materiais:", Color("ffe9a8")))
	var list := _scroll(box)
	var any := false
	for id in ItemDB.ITEMS:
		if Game.count(id) <= 0:
			continue
		any = true
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		list.add_child(row)
		row.add_child(_icon_rect(id))
		var l := _small("%s x%d  (%d ouro cada)" % [ItemDB.item_name(id), Game.count(id), ItemDB.ITEMS[id]["price"]])
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		for amount in [1, -1]:
			var b := Button.new()
			b.text = "Vender 1" if amount == 1 else "Vender tudo"
			b.add_theme_font_size_override("font_size", 8)
			b.pressed.connect(func():
				Game.sell(id, 1 if amount == 1 else Game.count(id))
				Sfx.play("coin")
				_show_merchant())
			row.add_child(b)
	if not any:
		list.add_child(_small("Nada para vender ainda.", Color(0.8, 0.8, 0.8)))
