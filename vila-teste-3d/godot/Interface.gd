extends CanvasLayer
## Interface da vila: cartao do treinador, botao de menu e botao de busca.

const AZUL_ESCURO := Color("17253d")
const BORDA := Color("3a5a86")


func _ready() -> void:
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)
	raiz.add_child(_cartao())
	var menu := _botao_redondo(Menu.new())
	_ancorar(menu, 0.5, 1.0, Vector2(-36, -18))
	raiz.add_child(menu)
	var lupa := _botao_redondo(Lupa.new())
	_ancorar(lupa, 1.0, 1.0, Vector2(-92, -18))
	raiz.add_child(lupa)


func _ancorar(c: Control, ax: float, ay: float, off: Vector2) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	# cresce para cima a partir da borda de baixo
	c.grow_vertical = Control.GROW_DIRECTION_BEGIN
	c.offset_left = off.x
	c.offset_right = off.x
	c.offset_top = off.y
	c.offset_bottom = off.y


func _estilo(cor: Color, raio: int, borda := 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = cor
	s.set_corner_radius_all(raio)
	s.set_border_width_all(borda)
	s.border_color = BORDA
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 6
	s.anti_aliasing = true
	return s


func _retrato(arquivo: String, tam: int) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(tam, tam)
	p.add_theme_stylebox_override("panel", _estilo(Color("2c4a75"), tam / 2, 3))
	p.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var t := TextureRect.new()
	t.texture = load("res://ui/" + arquivo)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.offset_top = 4
	p.add_child(t)
	return p


func _cartao() -> Control:
	var c := PanelContainer.new()
	var est := _estilo(Color(AZUL_ESCURO, 0.93), 22)
	est.content_margin_left = 12
	est.content_margin_right = 12
	est.content_margin_top = 10
	est.content_margin_bottom = 10
	c.add_theme_stylebox_override("panel", est)
	_ancorar(c, 0.0, 1.0, Vector2(18, -14))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	c.add_child(h)
	h.add_child(_retrato("retrato_treinador.png", 70))
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(150, 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	var nome := Label.new()
	nome.text = "Treinador · Nv. 1"
	nome.add_theme_font_size_override("font_size", 19)
	v.add_child(nome)
	var barra := ProgressBar.new()
	barra.value = 62
	barra.show_percentage = false
	barra.custom_minimum_size = Vector2(150, 14)
	barra.add_theme_stylebox_override("background", _estilo(Color("0e1828"), 7, 0))
	var fill := _estilo(Color("4cc35a"), 7, 0)
	fill.shadow_size = 0
	barra.add_theme_stylebox_override("fill", fill)
	v.add_child(barra)
	var perfil := Label.new()
	perfil.text = "Perfil"
	perfil.add_theme_font_size_override("font_size", 15)
	perfil.add_theme_color_override("font_color", Color("b9c8de"))
	v.add_child(perfil)
	h.add_child(_retrato("retrato_criatura.png", 66))
	return c


func _botao_redondo(icone: Control) -> Control:
	var b := Panel.new()
	b.custom_minimum_size = Vector2(72, 72)
	b.add_theme_stylebox_override("panel", _estilo(Color(AZUL_ESCURO, 0.93), 36))
	icone.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(icone)
	return b


class Menu extends Control:
	func _draw() -> void:
		var c := size / 2
		for dy in [-11, 0, 11]:
			draw_line(c + Vector2(-15, dy), c + Vector2(15, dy), Color.WHITE, 4.5, true)


class Lupa extends Control:
	func _draw() -> void:
		var c := size / 2 + Vector2(-4, -4)
		draw_arc(c, 12, 0, TAU, 32, Color.WHITE, 4.5, true)
		draw_line(c + Vector2(9, 9), c + Vector2(19, 19), Color.WHITE, 5.5, true)
