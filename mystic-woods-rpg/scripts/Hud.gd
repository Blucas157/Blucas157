extends CanvasLayer
## In-game HUD and menus (title, pause, world map, game over). Everything is built in code.

const FONT := preload("res://assets/ui/pixel_font.ttf")
const ICONS := preload("res://assets/ui/icons.png")
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


func _style_buttons() -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": Color("33418a"), "hover": Color("425b9e"), "pressed": Color("1d235d"),
			"focus": Color("425b9e"), "disabled": Color("414b66")}[state]
		sb.border_color = Color("1d235d") if state != "focus" else Color("d99945")
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(2)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		theme_ui.set_stylebox(state, "Button", sb)
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
	if fog_dirty and fog_texture:
		fog_texture.update(fog_image)
		fog_dirty = false
	draw_root.queue_redraw()


# ---------------------------------------------------------------- messages
func toast(text: String, color: Color = Color.WHITE) -> void:
	toasts.append({"text": text, "color": color, "t": 3.2})
	if toasts.size() > 3:
		toasts.pop_front()


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


func _icon(i: int, pos: Vector2) -> void:
	draw_root.draw_texture_rect_region(ICONS, Rect2(pos, Vector2(16, 16)), Rect2(i * 16, 0, 16, 16))


func _draw_hud() -> void:
	if main == null or not main.playing:
		return
	var sz := screen_size()
	# --- stats panel
	_panel(Rect2(4, 4, 124, 40))
	_text(Vector2(9, 15), "Nv %d" % Game.level, 8, Color("ffe9a8"))
	_text(Vector2(40, 15), "%d/%d" % [Game.hp, Game.max_hp], 8)
	_bar(Rect2(9, 19, 113, 6), float(Game.hp) / Game.max_hp, Color("bc4952"))
	_bar(Rect2(9, 29, 113, 3), float(Game.xp) / Game.xp_to_next(), Color("65b1b8"))
	_icon(0, Vector2(8, 32))
	_text(Vector2(22, 42), str(Game.attack_power()), 8)
	_icon(1, Vector2(40, 32))
	_text(Vector2(54, 42), str(Game.defense), 8)
	_icon(3, Vector2(70, 32))
	_text(Vector2(85, 42), str(Game.gold), 8, Color("ffd479"))
	# --- quest tracker
	var q := Game.quest_text().split("\n")
	_text(Vector2(6, 56), q[0], 8, Color("ffe9a8"))
	if q.size() > 1:
		_text(Vector2(6, 66), q[1], 8, Color(0.85, 0.9, 1.0))
	# --- potion counter (bottom-left)
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
		_text(Vector2(0, sz.y - 40), hint, 8, Color("ffe9a8"), HORIZONTAL_ALIGNMENT_CENTER, sz.x)
	# --- region banner
	if banner_t > 0.0:
		var a: float = min(1.0, banner_t) * min(1.0, (3.0 - banner_t) * 3.0)
		var c := Color(1, 1, 1, a)
		var bx := 134.0
		var bw2 := sz.x - bx - 90.0
		draw_root.draw_rect(Rect2(bx, 74, bw2, 26), Color(0.09, 0.11, 0.19, 0.55 * a))
		draw_root.draw_string_outline(FONT, Vector2(bx, 93), banner, HORIZONTAL_ALIGNMENT_CENTER, bw2, 16, 4, Color(0.09, 0.11, 0.19, a))
		draw_root.draw_string(FONT, Vector2(bx, 93), banner, HORIZONTAL_ALIGNMENT_CENTER, bw2, 16, c)
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
		_text(Vector2(0, 14), "MAPA DO MUNDO  -  [M] fechar", 8, Color("ffe9a8"), HORIZONTAL_ALIGNMENT_CENTER, sz.x)


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


func _menu_box(title: String, subtitle: String = "", h: float = 200.0) -> VBoxContainer:
	clear_menu()
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.04, 0.08, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(shade)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(220, h)
	box.position = Vector2(-110, -h / 2.0)
	menu_root.add_child(box)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 32)
	t.add_theme_color_override("font_color", Color("ffe9a8"))
	t.add_theme_constant_override("outline_size", 6)
	box.add_child(t)
	if subtitle != "":
		var s := Label.new()
		s.text = subtitle
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.add_theme_font_size_override("font_size", 8)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(s)
	return box


func _button(box: Container, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func(): Sfx.play("select"); cb.call())
	box.add_child(b)
	return b


func show_title() -> void:
	var box := _menu_box("Mystic Woods", "Um RPG de mundo aberto\n\nWASD/Setas mover  -  J/Espaço atacar  -  K/Shift esquivar\nE interagir  -  Q poção  -  M mapa  -  Esc pausa", 220)
	(menu_root.get_child(0) as ColorRect).color = Color(0.03, 0.04, 0.08, 0.35)
	var first: Button
	if Game.has_save():
		first = _button(box, "Continuar", func(): main.start_game(false))
	var nb := _button(box, "Novo jogo", func(): main.start_game(true))
	if first == null:
		first = nb
	_button(box, "Som: " + ("desligado" if Game.muted else "ligado"), func(): Game.muted = not Game.muted; show_title())
	first.call_deferred("grab_focus")


func show_pause() -> void:
	var stats := "Nível %d  -  XP %d/%d\nAtaque %d  -  Defesa %d  -  Ouro %d\nMonstros derrotados: %d  -  Baús: %d\nTempo de jogo: %d min" % [
		Game.level, Game.xp, Game.xp_to_next(), Game.attack_power(), Game.defense, Game.gold,
		_total_kills(), Game.opened_chests.size(), int(Game.play_time / 60.0)]
	var box := _menu_box("Pausa", stats, 220)
	var cont := _button(box, "Continuar", func(): main.set_paused(false))
	_button(box, "Salvar jogo", func(): Game.save_game(); toast("Jogo salvo", Color(0.6, 1, 0.6)); main.set_paused(false))
	_button(box, "Som: " + ("desligado" if Game.muted else "ligado"), func(): Game.muted = not Game.muted; show_pause())
	_button(box, "Sair para o título", func(): main.quit_to_title())
	cont.call_deferred("grab_focus")


func _total_kills() -> int:
	var n := 0
	for k in Game.kills:
		n += int(Game.kills[k])
	return n


func show_game_over() -> void:
	var box := _menu_box("Você caiu...", "Você acorda na Vila do Bosque.\nMetade do ouro carregado ficou para trás.", 160)
	var b := _button(box, "Renascer na vila", func(): main.respawn())
	b.call_deferred("grab_focus")


func show_victory() -> void:
	var box := _menu_box("Vitória!", "O Ent Ancião foi derrotado e a floresta está em paz.\nUm baú lendário apareceu na arena. Continue explorando!", 160)
	var b := _button(box, "Continuar", func(): main.set_paused(false))
	b.call_deferred("grab_focus")
