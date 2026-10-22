extends Control
## Destiny board screen: node map on top, details of the selected node at the bottom.
## Built in code like the rest of the UI; Main opens it from the menu.

signal closed
signal bought(id: String)

const NODE_SIZE := Vector2(170, 170)
const ROOT_POS := Vector2(540, 1450)
const LOCKED := Color(1, 1, 1, 0.16)

var selected: String = "reach"
var buttons: Dictionary = {}
var levels: Dictionary = {}
var links: Control
var wallet_label: Label
var detail_icon: TextureRect
var detail_name: Label
var detail_info: Label
var detail_effect: Label
var buy_button: Button
var close_button: Button

func _ready() -> void:
	size = Vector2(1080, 1920)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = HudKit.theme()
	var back := ColorRect.new()
	back.color = Color(0.02, 0.04, 0.1, 0.94)
	back.size = size
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	_place(HudKit.label("PAINEL DE DESTINO", 80, HudKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 40), Vector2(1080, 100))
	var wallet_row := HudKit.icon_row(load("res://Assets/moeda/Moeda_0001.png"), 2.0, "", 56, HudKit.GOLD)
	wallet_label = wallet_row.get_child(1)
	_place(wallet_row, Vector2(0, 150), Vector2(1080, 80))
	_place(HudKit.label("Leve um nó ao nível %d para abrir o próximo" % GameManager.DESTINY_UNLOCK, 32, HudKit.SKY, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 250), Vector2(1080, 60))
	links = _place(Control.new(), Vector2.ZERO, size)
	links.mouse_filter = Control.MOUSE_FILTER_IGNORE
	links.draw.connect(_draw_links)
	for i in GameManager.BRANCHES.size():
		var branch: Dictionary = GameManager.BRANCHES[i]
		_place(HudKit.label(branch.name, 32, branch.color, HORIZONTAL_ALIGNMENT_CENTER), Vector2(60 + i * 330, 370), Vector2(300, 50))
	var root := TextureRect.new()
	var slime := AtlasTexture.new()
	slime.atlas = load("res://Assets/SlimeReactions/collect_00.png")
	slime.region = Rect2(12, 14, 28, 23)
	root.texture = slime
	root.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	root.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(root, ROOT_POS - Vector2(70, 60), Vector2(140, 120))
	for id in GameManager.DESTINY:
		_build_node(id)
	_build_details()
	close_button = _place(HudKit.button("VOLTAR", "primary", Vector2(440, 120), func(): closed.emit(), 56), Vector2(320, 1790)) as Button
	refresh()

func _place(item: Control, at: Vector2, dimensions: Vector2 = Vector2.ZERO) -> Control:
	item.position = at
	if dimensions != Vector2.ZERO:
		item.size = dimensions
	add_child(item)
	return item

func _build_node(id: String) -> void:
	var node: Dictionary = GameManager.DESTINY[id]
	var button := HudKit.button("", "square", NODE_SIZE, _select.bind(id), 32)
	button.focus_mode = Control.FOCUS_NONE
	_place(button, node.pos - NODE_SIZE / 2.0)
	var icon := TextureRect.new()
	icon.texture = load(node.icon)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.position = Vector2(37, 30)
	icon.size = Vector2(96, 96)
	button.add_child(icon)
	var level := HudKit.label("", 32, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	level.position = Vector2(0, NODE_SIZE.y - 20)
	level.size = Vector2(NODE_SIZE.x, 44)
	button.add_child(level)
	buttons[id] = button
	levels[id] = level

func _build_details() -> void:
	var panel := HudKit.panel("frame")
	_place(panel, Vector2(30, 1530), Vector2(1020, 250))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	detail_icon = TextureRect.new()
	detail_icon.custom_minimum_size = Vector2(96, 96)
	detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(detail_icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	detail_name = HudKit.label("", 48)
	text.add_child(detail_name)
	detail_info = HudKit.label("", 32, HudKit.SKY)
	detail_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(detail_info)
	detail_effect = HudKit.label("", 32, HudKit.MINT)
	detail_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(detail_effect)
	# Text wraps instead of widening the panel, so the button stays inside the frame.
	text.custom_minimum_size.x = 520
	detail_name.clip_text = true
	buy_button = HudKit.button("", "gold", Vector2(250, 140), _buy, 40)
	buy_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(buy_button)

func _select(id: String) -> void:
	selected = id
	refresh()
	HudKit.pop(buttons[id], 1.08)

func _buy() -> void:
	if GameManager.destiny_buy(selected):
		bought.emit(selected)
		refresh()
		HudKit.pop(buttons[selected], 1.2)
		HudKit.pop(wallet_label, 1.15)

## Redraws every node, line and the detail panel from GameManager.
func refresh() -> void:
	wallet_label.text = GameManager.big_number(GameManager.wallet)
	for id in buttons:
		var state := GameManager.destiny_state(id)
		var lv := GameManager.upgrade_level(id)
		var button: Button = buttons[id]
		HudKit.apply_skin(button, "gold" if id == selected else ("primary" if state == "max" else "square"))
		button.modulate = Color(1, 1, 1, 0.45) if state in ["locked", "boss"] else Color.WHITE
		var level: Label = levels[id]
		level.text = "CHEFÃO" if state == "boss" else "%d/%d" % [lv, GameManager.DESTINY_MAX]
		level.add_theme_color_override("font_color", HudKit.GOLD if state == "max" else (HudKit.CORAL if state == "boss" else Color.WHITE))
	links.queue_redraw()
	_refresh_details()

func _refresh_details() -> void:
	var node: Dictionary = GameManager.DESTINY[selected]
	var lv := GameManager.upgrade_level(selected)
	var state := GameManager.destiny_state(selected)
	detail_icon.texture = load(node.icon)
	detail_name.text = "%s  NV %d" % [node.name, lv]
	detail_name.add_theme_font_size_override("font_size", 48 if detail_name.text.length() <= 14 else 40)
	detail_info.text = node.info
	match state:
		"boss":
			detail_effect.text = "Derrote o chefão: " + GameManager.BOSSES[node.boss].name.capitalize()
		"locked":
			detail_effect.text = "Leve %s ao nível %d" % [GameManager.DESTINY[node.parent].name, GameManager.DESTINY_UNLOCK]
		"max":
			detail_effect.text = GameManager.destiny_effect(selected, lv) + "  (máximo)"
		_:
			detail_effect.text = GameManager.destiny_effect(selected, lv) + "  ->  " + GameManager.destiny_effect(selected, lv + 1)
	var cost := GameManager.destiny_cost(selected)
	if state == "max":
		buy_button.text = "MÁXIMO"
	elif state == "open":
		buy_button.text = "MELHORAR\n" + GameManager.big_number(cost)
	else:
		buy_button.text = "TRAVADO"
	buy_button.disabled = not GameManager.destiny_can_buy(selected)
	HudKit.apply_skin(buy_button, "gold" if not buy_button.disabled else "square")

## Lines root -> branch starts -> children; lit in the branch colour once the child is open.
func _draw_links() -> void:
	for id in GameManager.DESTINY:
		var node: Dictionary = GameManager.DESTINY[id]
		var from: Vector2 = ROOT_POS if node.parent == "" else GameManager.DESTINY[node.parent].pos
		var branch: int = roundi((node.pos.x - 210.0) / 330.0)
		var lit := GameManager.destiny_state(id) in ["open", "max"]
		var color: Color = GameManager.BRANCHES[branch].color if lit else LOCKED
		links.draw_line(from, node.pos, Color(0.01, 0.02, 0.06), 22.0)
		links.draw_line(from, node.pos, color, 12.0)
