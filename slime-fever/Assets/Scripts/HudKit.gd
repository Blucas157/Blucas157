class_name HudKit
extends RefCounted
## Interface kit generated with PixelLab: nine-slice frames, pixel font and button feedback.

const NAVY := Color("07112a")
const MINT := Color("a3ffce")
const GOLD := Color("ffd45c")
const SKY := Color("a9cbd6")
const CORAL := Color("ff816b")

# name: [texture, slice left, top, right, bottom, content left, top, right, bottom]
const SKINS := {
	"primary": ["res://Assets/UI/btn_primary.png", 40, 36, 40, 48, 40, 18, 40, 38],
	"gold": ["res://Assets/UI/btn_gold.png", 24, 24, 24, 36, 32, 14, 32, 30],
	"frame": ["res://Assets/UI/btn_secondary.png", 112, 80, 112, 80, 52, 34, 52, 38],
	"square": ["res://Assets/UI/btn_square.png", 54, 54, 54, 54, 18, 14, 18, 22],
	"bar": ["res://Assets/UI/bar_frame.png", 56, 40, 56, 40, 26, 22, 26, 24],
	"panel": ["res://Assets/UI/panel.png", 168, 168, 168, 168, 110, 128, 110, 128],
}

static var _font: FontFile
static var _theme: Theme

static func font() -> FontFile:
	if _font == null:
		_font = load("res://Assets/UI/slime_fever.ttf")
		# 16 px bitmap glyphs: keep them sharp at the 1080x1920 viewport.
		_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_font.hinting = TextServer.HINTING_NONE
		_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_font.fallbacks = [ThemeDB.fallback_font]
	return _font

static func theme() -> Theme:
	if _theme == null:
		_theme = Theme.new()
		_theme.default_font = font()
		_theme.default_font_size = 48
		for type in ["Label", "Button"]:
			_theme.set_color("font_outline_color", type, NAVY)
			_theme.set_constant("outline_size", type, 14)
		_theme.set_color("font_color", "Label", Color.WHITE)
		_theme.set_color("font_shadow_color", "Label", Color(0.0, 0.02, 0.08, 0.6))
		_theme.set_constant("shadow_offset_x", "Label", 0)
		_theme.set_constant("shadow_offset_y", "Label", 6)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			_theme.set_color(state, "Button", Color.WHITE)
	return _theme

static func skin(name: String, tint: Color = Color.WHITE) -> StyleBoxTexture:
	var data: Array = SKINS[name]
	var box := StyleBoxTexture.new()
	box.texture = load(data[0])
	box.texture_margin_left = data[1]
	box.texture_margin_top = data[2]
	box.texture_margin_right = data[3]
	box.texture_margin_bottom = data[4]
	box.content_margin_left = data[5]
	box.content_margin_top = data[6]
	box.content_margin_right = data[7]
	box.content_margin_bottom = data[8]
	box.modulate_color = tint
	return box

static func label(text: String, font_size: int, color: Color = Color.WHITE, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var item := Label.new()
	item.text = text
	item.horizontal_alignment = align
	item.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	return item

static func panel(name: String) -> PanelContainer:
	var item := PanelContainer.new()
	item.add_theme_stylebox_override("panel", skin(name))
	item.mouse_filter = Control.MOUSE_FILTER_STOP
	return item

static func button(text: String, skin_name: String, min_size: Vector2, callback: Callable, font_size: int = 64) -> Button:
	var item := Button.new()
	item.text = text
	item.custom_minimum_size = min_size
	item.add_theme_font_size_override("font_size", font_size)
	var normal := skin(skin_name)
	var pressed := skin(skin_name, Color(0.78, 0.82, 0.86))
	# Text sinks into the bevel while held.
	pressed.content_margin_top += 10
	pressed.content_margin_bottom -= 10
	item.add_theme_stylebox_override("normal", normal)
	item.add_theme_stylebox_override("hover", skin(skin_name, Color(1.12, 1.12, 1.12)))
	item.add_theme_stylebox_override("pressed", pressed)
	item.add_theme_stylebox_override("hover_pressed", pressed)
	item.add_theme_stylebox_override("disabled", skin(skin_name, Color(0.5, 0.5, 0.55)))
	item.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	item.pressed.connect(callback)
	add_press_feel(item)
	return item

static func icon_button(icon: Texture2D, callback: Callable) -> Button:
	var item := button("", "square", Vector2(150, 150), callback)
	item.icon = icon
	item.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	item.focus_mode = Control.FOCUS_NONE
	return item

static func add_press_feel(item: Control) -> void:
	item.resized.connect(func(): item.pivot_offset = item.size / 2.0)
	if item is BaseButton:
		item.button_down.connect(func(): squash(item, 0.92, 0.06))
		item.button_up.connect(func(): squash(item, 1.0, 0.18))

static func squash(item: Control, target: float, duration: float) -> void:
	if not item.is_inside_tree():
		return
	var tween := item.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "scale", Vector2.ONE * target, duration)

static func pop(item: Control, amount: float = 1.18) -> void:
	if not item.is_inside_tree():
		return
	item.pivot_offset = item.size / 2.0
	item.scale = Vector2.ONE * amount
	var tween := item.create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "scale", Vector2.ONE, 0.45)

static func icon_row(texture: Texture2D, icon_scale: float, text: String, font_size: int, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var picture := TextureRect.new()
	picture.texture = texture
	picture.custom_minimum_size = texture.get_size() * icon_scale
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(picture)
	row.add_child(label(text, font_size, color))
	return row
