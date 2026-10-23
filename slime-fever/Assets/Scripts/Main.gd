extends Node2D

const COIN_FRAMES := 7
const BAR_INSET := Vector2(26, 22)
# PixelLab VFX sheets: frame size, columns, frame count, fps and the effect's centre.
const VFX := {
	"explosion": {"sheet": "res://Assets/VFX/explosion.png", "size": Vector2(80, 87), "cols": 4, "frames": 10, "fps": 10.0, "anchor": Vector2(43, 54)},
	"boss_hit": {"sheet": "res://Assets/VFX/boss_hit.png", "size": Vector2(64, 64), "cols": 3, "frames": 6, "fps": 14.0, "anchor": Vector2(32, 32)},
	"boss_death": {"sheet": "res://Assets/VFX/boss_death.png", "size": Vector2(155, 179), "cols": 4, "frames": 12, "fps": 12.0, "anchor": Vector2(72, 77)},
}
# Boss animation strips: 9 frames of 128x128 each (PixelLab animate-with-text).
const BOSS_ANIMS := {"throw": 16.0, "hurt": 16.0, "death": 10.0}
const BOSS_FRAME := 128
# Where the boss's hands are, relative to its centre, for bombs it throws.
const BOSS_HANDS := [Vector2(-170, 40), Vector2(170, 40)]
# Time the bomb swell and blast play before the result card covers it.
const RESULT_DELAY := 1.2

@onready var hud: CanvasLayer = $HUD
var ui: Control
var hud_top: Control
var menu_panel: Control
var play_button: Button
var pause_button: Button
var sound_button: Button
var resume_button: Button
var replay_button: Button
var shop_button: Button
var shop_close_button: Button
var shop_buttons: Dictionary = {}
const SHOP_TABS := {"items": "ITENS", "skins": "VISUAL"}
var shop_tabs: Dictionary = {}
var shop_tab: String = "items"
var destiny_board: Control
var destiny_button: Button
var run_shop_panel: Control
var run_shop_continue: Button
var shield_icon: TextureRect
var double_badge: HBoxContainer
var double_label: Label
var menu_button: Button
var result_menu_button: Button
var result_panel: Control
var score_label: Label
var best_label: Label
var combo_label: Label
var level_label: Label
var mode_buttons: Array[Button] = []
var menu_best_label: Label
var menu_wallet_label: Label
var shop_panel: Control
var shop_list: VBoxContainer
var shop_wallet_label: Label
var magnet_badge: HBoxContainer
var magnet_label: Label
var multiplier_badge: PanelContainer
var multiplier_label: Label
var pattern_label: Label
var fever_label: Label
var fever_box: Control
var fever_fill: ColorRect
var fever_shine: ColorRect
var coin_icon: TextureRect
var coin_frames: Array[Texture2D] = []
var sound_icon: Texture2D
var mute_icon: Texture2D
var pause_panel: Control
var sounds: Array[AudioStreamPlayer] = []
var sound_cursor: int = 0
var was_fever: bool = false
var shown_score: int = 0
var shown_multiplier: int = 1
var best_before_run: int = 0
var ui_time: float = 0.0
var touch_steer: Node2D
var vfx_frames: Dictionary = {}
var boss_throw_ready: float = 0.0
var boss_hand: int = 0
var backdrop: TextureRect
var boss_sprite: AnimatedSprite2D
var boss_bar: Control
var boss_name_label: Label
var boss_fill: ColorRect
var boss_time_label: Label
var boss_bob: Tween
const BOSS_POS := Vector2(540, 650)
const BOSS_BAR_WIDTH := 600.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Gameplay nodes inherit the pausable mode, while UI stays active.
	$Player.process_mode = Node.PROCESS_MODE_PAUSABLE
	$Spawner.process_mode = Node.PROCESS_MODE_PAUSABLE
	GameManager.reset_game()
	GameManager.game_ended.connect(_show_result)
	GameManager.fever_started.connect(_fever_start)
	GameManager.level_up.connect(_level_up)
	GameManager.coin_tier_up.connect(_coin_tier_up)
	GameManager.powerup_collected.connect(_powerup_collected)
	GameManager.boss_started.connect(_boss_started)
	GameManager.boss_hit.connect(_boss_hit)
	GameManager.boss_defeated.connect(_boss_defeated)
	GameManager.boss_escaped.connect(_boss_escaped)
	GameManager.revived.connect(func(): _banner("SEGUNDA CHANCE!", HudKit.GOLD))
	$Player.collision_layer = 1
	$Player.collision_mask = 2
	$Camera2D.position = Vector2(540, 960)
	backdrop = TextureRect.new()
	backdrop.texture = load("res://Assets/New/cave.png")
	backdrop.size = Vector2(1080, 1920)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.material = ShaderMaterial.new()
	backdrop.material.shader = preload("res://Assets/Shaders/zone_hue.gdshader")
	$Cenario_Background.add_child(backdrop)
	_set_zone_tint(false)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.05, 0.12, 0.34)
	shade.size = Vector2(1080, 1920)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Cenario_Background.add_child(shade)
	for i in COIN_FRAMES:
		coin_frames.append(load("res://Assets/moeda/Moeda_%04d.png" % (i + 1)))
	sound_icon = load("res://Assets/UI/icon_sound.png")
	mute_icon = load("res://Assets/UI/icon_mute.png")
	ui = Control.new()
	ui.size = Vector2(1080, 1920)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = HudKit.theme()
	hud.add_child(ui)
	# Gameplay readouts; hidden behind the menu and result screens.
	hud_top = Control.new()
	hud_top.size = ui.size
	hud_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud_top)
	_build_scoreboard()
	_build_fever_bar()
	pattern_label = _place(HudKit.label("", 32, HudKit.SKY, HORIZONTAL_ALIGNMENT_CENTER), Vector2(40, 490), Vector2(1000, 60)) as Label
	magnet_badge = _place(HudKit.icon_row(load("res://Assets/UI/icon_magnet.png"), 2.0, "", 48, Color("ff9db0")), Vector2(810, 476), Vector2(240, 80)) as HBoxContainer
	magnet_label = magnet_badge.get_child(1)
	magnet_badge.hide()
	double_badge = _place(HudKit.icon_row(load("res://Assets/UI/icon_double.png"), 2.0, "", 48, HudKit.GOLD), Vector2(30, 476), Vector2(240, 80)) as HBoxContainer
	double_label = double_badge.get_child(1)
	double_badge.hide()
	shield_icon = _place(TextureRect.new(), Vector2(720, 478), Vector2(76, 76)) as TextureRect
	shield_icon.texture = load("res://Assets/UI/icon_shield.png")
	shield_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shield_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shield_icon.hide()
	var touch := GameManager.touch_controls()
	_place(HudKit.label("ARRASTE O DEDO" if touch else "SETAS OU A/D", 32, HudKit.SKY, HORIZONTAL_ALIGNMENT_CENTER), Vector2(240, 1770), Vector2(600, 80))
	touch_steer = preload("res://Assets/Scripts/TouchSteer.gd").new()
	touch_steer.enabled = touch
	touch_steer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(touch_steer)
	_build_boss()
	# PC keeps the on-screen arrows; touch screens drag instead.
	if not touch:
		_add_direction(Vector2(205, 1810), -1)
		_add_direction(Vector2(875, 1810), 1)
	for i in 6:
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		sounds.append(audio)
	_show_menu()

func _place(item: Control, at: Vector2, dimensions: Vector2 = Vector2.ZERO) -> Control:
	item.position = at
	if dimensions != Vector2.ZERO:
		item.size = dimensions
	hud_top.add_child(item)
	return item

func _build_scoreboard() -> void:
	var plate := HudKit.panel("frame")
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(plate, Vector2(24, 28), Vector2(680, 196))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(row)
	coin_icon = TextureRect.new()
	coin_icon.texture = coin_frames[0]
	coin_icon.custom_minimum_size = Vector2(96, 96)
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(coin_icon)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", -8)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(column)
	score_label = HudKit.label("0", 80)
	column.add_child(score_label)
	best_label = HudKit.label("RECORDE 0", 32, HudKit.GOLD)
	column.add_child(best_label)
	pause_button = _place(HudKit.icon_button(load("res://Assets/UI/icon_pause.png"), _toggle_pause), Vector2(728, 36)) as Button
	sound_button = _place(HudKit.icon_button(sound_icon, _toggle_sound), Vector2(906, 36)) as Button
	multiplier_badge = HudKit.panel("gold")
	multiplier_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(multiplier_badge, Vector2(30, 246), Vector2(176, 96))
	multiplier_label = HudKit.label("x1", 48, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	multiplier_badge.add_child(multiplier_label)
	combo_label = _place(HudKit.label("", 48), Vector2(232, 246), Vector2(560, 96)) as Label
	level_label = _place(HudKit.label("", 32, HudKit.SKY, HORIZONTAL_ALIGNMENT_RIGHT), Vector2(700, 246), Vector2(350, 96)) as Label

func _build_fever_bar() -> void:
	var slime := TextureRect.new()
	slime.texture = load("res://Assets/SlimeReactions/fever_00.png")
	slime.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(slime, Vector2(4, 334), Vector2(150, 150))
	slime.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fever_box = _place(Control.new(), Vector2(150, 364), Vector2(906, 104))
	fever_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", HudKit.skin("bar"))
	frame.size = fever_box.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fever_box.add_child(frame)
	fever_fill = ColorRect.new()
	fever_fill.position = BAR_INSET
	fever_fill.size = Vector2(0, fever_box.size.y - BAR_INSET.y * 2.0)
	fever_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fever_box.add_child(fever_fill)
	fever_shine = ColorRect.new()
	fever_shine.position = BAR_INSET
	fever_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fever_box.add_child(fever_shine)
	fever_label = HudKit.label("", 32, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	fever_label.size = fever_box.size
	fever_box.add_child(fever_label)

func _process(delta: float) -> void:
	if not is_instance_valid(score_label):
		return
	ui_time += delta
	hud_top.visible = GameManager.started and not is_instance_valid(result_panel) and not is_instance_valid(run_shop_panel)
	if GameManager.score != shown_score:
		if GameManager.score > shown_score:
			HudKit.pop(score_label, 1.12)
		shown_score = GameManager.score
	score_label.text = str(GameManager.score)
	best_label.text = "RECORDE %d" % maxi(GameManager.best, GameManager.score)
	level_label.text = "%s  NV %d  Z%d" % [GameManager.mode_name(), GameManager.level + 1, GameManager.zone + 1]
	boss_bar.visible = GameManager.boss_active
	pattern_label.visible = not GameManager.boss_active
	if GameManager.boss_active:
		boss_fill.size.x = BOSS_BAR_WIDTH * float(GameManager.boss_hp) / GameManager.boss_max
		boss_time_label.text = "%ds" % ceili(GameManager.boss_left)
	coin_icon.texture = coin_frames[int(ui_time * 10.0) % COIN_FRAMES]
	sound_button.icon = mute_icon if GameManager.muted else sound_icon
	if pattern_label.text != $Spawner.current_pattern:
		pattern_label.text = $Spawner.current_pattern
		HudKit.pop(pattern_label, 1.1)
	if GameManager.multiplier != shown_multiplier:
		shown_multiplier = GameManager.multiplier
		HudKit.pop(multiplier_badge, 1.25)
	multiplier_label.text = "x%d" % GameManager.multiplier
	combo_label.text = "%d SEGUIDAS" % GameManager.combo if GameManager.combo > 0 else "PEGUE MOEDAS"
	var fever: bool = GameManager.fever_left > 0.0
	var ratio := GameManager.fever_left / GameManager.fever_duration() if fever else GameManager.charge / 100.0
	magnet_badge.visible = GameManager.magnet_left > 0.0
	double_badge.visible = GameManager.double_left > 0.0
	double_label.text = "%.0fs" % ceilf(GameManager.double_left)
	shield_icon.visible = GameManager.shield > 0
	magnet_label.text = "%.1fs" % GameManager.magnet_left
	# Blink in the last second so the end of the magnet is not a surprise.
	magnet_badge.modulate.a = 0.35 if GameManager.magnet_left < 1.0 and int(GameManager.magnet_left * 10) % 2 == 0 else 1.0
	var inner := fever_box.size - BAR_INSET * 2.0
	fever_fill.size = Vector2(inner.x * clampf(ratio, 0.0, 1.0), inner.y)
	fever_shine.size = Vector2(fever_fill.size.x, 10)
	var blink := fever and GameManager.fever_left <= 1.5 and int(GameManager.fever_left * 10) % 2 == 0
	if fever:
		fever_fill.color = Color.WHITE if blink else HudKit.GOLD.lerp(Color("ff9d4d"), 0.5 + 0.5 * sin(ui_time * 12.0))
		fever_shine.color = Color(1, 1, 1, 0.55)
		fever_label.text = "FEBRE!  %.1fs" % GameManager.fever_left
		fever_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		fever_fill.color = Color("37d39a")
		fever_shine.color = Color(HudKit.MINT, 0.9)
		fever_label.text = "FEBRE  %d/20" % int(GameManager.charge / 5.0)
		fever_label.add_theme_color_override("font_color", HudKit.MINT if GameManager.charge >= 75.0 else Color.WHITE)
	var sprite := $Player/AnimatedSprite2D
	if fever:
		sprite.modulate = Color("a3ffdf") if GameManager.fever_left > 1.5 or int(GameManager.fever_left * 10) % 2 == 0 else Color.WHITE
	elif GameManager.grace_left > 0.0:
		sprite.modulate = Color("92c9ff")
	else:
		sprite.modulate = Color.WHITE
	if was_fever and not fever:
		_tone(380, 0.16, 0.2)
	was_fever = fever

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		_toggle_pause()

func _make_label(text: String, at: Vector2, dimensions: Vector2, font_size: int, color: Color, centered: bool = false) -> Label:
	var label := HudKit.label(text, font_size, color, HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT)
	_place(label, at, dimensions)
	return label as Label

func _add_direction(at: Vector2, direction: int) -> void:
	var button := Node2D.new()
	button.set_script(preload("res://Assets/Scripts/DirectionButton.gd"))
	button.direction = direction
	button.position = at
	hud.add_child(button)

func juice(at: Vector2, color: Color, text: String, kind: int) -> void:
	var burst := Node2D.new()
	burst.set_script(preload("res://Assets/Scripts/Burst.gd"))
	burst.process_mode = Node.PROCESS_MODE_PAUSABLE
	burst.position = at
	burst.z_index = 10
	add_child(burst)
	burst.add_to_group("run_effects")
	burst.setup(color, 18 if kind >= 2 else 8)
	var popup := _make_label(text, at - Vector2(200, 110), Vector2(400, 90), 80 if kind >= 2 else 64, color, true)
	popup.add_to_group("run_effects")
	popup.pivot_offset = popup.size / 2.0
	popup.scale = Vector2(0.6, 0.6)
	var tween := popup.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	tween.set_parallel(true)
	tween.tween_property(popup, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "position:y", popup.position.y - 110, 0.7).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 0.0, 0.3).set_delay(0.4)
	tween.chain().tween_callback(popup.queue_free)
	if kind == 1:
		_tone(650 + mini(GameManager.combo, 15) * 35, 0.09, 0.16)
	elif kind == 2:
		$Camera2D.start_shake(4)
		_tone(400, 0.14, 0.2)
	elif kind == 3:
		$Camera2D.start_shake(12)
		_tone(90, 0.3, 0.3)

func _fever_start() -> void:
	juice($Player.position, Color("a3ffce"), "FEBRE!", 2)
	HudKit.pop(fever_box, 1.08)

func warn_bomb(x: float) -> void:
	var warning := _make_label("!", Vector2(x - 50, 560), Vector2(100, 110), 96, HudKit.CORAL, true)
	warning.add_to_group("run_effects")
	var tween := warning.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	tween.tween_property(warning, "modulate:a", 0.0, 0.65)
	tween.tween_callback(warning.queue_free)

func _tone(hz: float, duration: float, volume: float) -> void:
	if GameManager.muted or sounds.is_empty():
		return
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = 22050
	var count := int(duration * 22050)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		var envelope := sin(PI * float(i) / count)
		var value := int(sin(TAU * hz * i / 22050.0) * envelope * volume * 28000)
		bytes.encode_s16(i * 2, value)
	wave.data = bytes
	var player := sounds[sound_cursor % sounds.size()]
	sound_cursor += 1
	player.stop()
	player.stream = wave
	player.play()

func _toggle_sound() -> void:
	GameManager.muted = not GameManager.muted
	if GameManager.muted:
		for player in sounds:
			player.stop()
	GameManager.save_progress()

func _clear_controls() -> void:
	for button in get_tree().get_nodes_in_group("direction_buttons"):
		button.clear_input()
	if touch_steer:
		touch_steer.clear_input()

## Full-screen dimmed layer with a centered column; blocks clicks to the HUD below.
func _overlay(dim: float) -> Array:
	var layer := Control.new()
	layer.size = ui.size
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.03, 0.09, dim)
	shade.size = ui.size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(shade)
	var center := CenterContainer.new()
	center.size = ui.size
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(column)
	# Cards pop in; containers own the position, so animate scale and alpha.
	column.resized.connect(func(): column.pivot_offset = column.size / 2.0)
	column.scale = Vector2(0.85, 0.85)
	layer.modulate.a = 0.0
	var tween := layer.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(layer, "modulate:a", 1.0, 0.18)
	tween.tween_property(column, "scale", Vector2.ONE, 0.35)
	return [layer, column]

func _card(column: VBoxContainer, separation: int) -> VBoxContainer:
	var card := HudKit.panel("panel")
	card.custom_minimum_size.x = 900
	column.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", separation)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)
	return content

func _centered(item: Control) -> Control:
	item.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return item

func _toggle_pause() -> void:
	_clear_controls()
	if GameManager.ended or not GameManager.started:
		return
	# Esc or losing focus while the mini-shop is open just closes it.
	if is_instance_valid(run_shop_panel):
		_close_run_shop()
		return
	if get_tree().paused:
		get_tree().paused = false
		for audio in sounds:
			audio.stream_paused = false
		if is_instance_valid(pause_panel):
			pause_panel.queue_free()
	else:
		get_tree().paused = true
		for audio in sounds:
			audio.stream_paused = true
		Input.action_release("ui_left")
		Input.action_release("ui_right")
		var parts := _overlay(0.62)
		pause_panel = parts[0]
		var content := _card(parts[1], 40)
		content.add_child(HudKit.label("PAUSADO", 96, HudKit.MINT, HORIZONTAL_ALIGNMENT_CENTER))
		resume_button = _centered(HudKit.button("CONTINUAR", "primary", Vector2(620, 170), _toggle_pause, 64)) as Button
		content.add_child(resume_button)
		menu_button = _centered(HudKit.button("MENU PRINCIPAL", "frame", Vector2(620, 160), _back_to_menu, 48)) as Button
		content.add_child(menu_button)
		content.add_child(HudKit.label("ESC TAMBÉM CONTINUA", 32, HudKit.SKY, HORIZONTAL_ALIGNMENT_CENTER))

func _stat(row: HBoxContainer, value: String, caption: String) -> void:
	var box := HudKit.panel("square")
	box.custom_minimum_size = Vector2(210, 180)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(box)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)
	box.add_child(column)
	column.add_child(HudKit.label(value, 64, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(HudKit.label(caption, 32, HudKit.SKY, HORIZONTAL_ALIGNMENT_CENTER))

func explode(at: Vector2, size: float, flash: bool = false) -> void:
	play_vfx("explosion", at, size, flash)

func _vfx_frames(name: String) -> SpriteFrames:
	if not vfx_frames.has(name):
		var info: Dictionary = VFX[name]
		var frames := SpriteFrames.new()
		frames.add_animation("boom")
		frames.set_animation_loop("boom", false)
		frames.set_animation_speed("boom", info.fps)
		var sheet: Texture2D = load(info.sheet)
		for i in info.frames:
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(Vector2(i % info.cols, i / info.cols) * info.size, info.size)
			frames.add_frame("boom", frame)
		vfx_frames[name] = frames
	return vfx_frames[name]

## One-shot PixelLab effect centred on `at`; optional white screen flash.
func play_vfx(name: String, at: Vector2, size: float, flash: bool = false) -> void:
	var blast := AnimatedSprite2D.new()
	blast.sprite_frames = _vfx_frames(name)
	blast.centered = false
	blast.offset = -VFX[name].anchor
	blast.scale = Vector2.ONE * size
	blast.position = at
	blast.z_index = 20
	blast.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(blast)
	blast.add_to_group("run_effects")
	blast.animation_finished.connect(blast.queue_free)
	blast.play("boom")
	if flash:
		var white := ColorRect.new()
		white.color = Color(1, 0.95, 0.8, 0.7)
		white.size = ui.size
		white.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(white)
		white.add_to_group("run_effects")
		var fade := white.create_tween()
		fade.tween_property(white, "modulate:a", 0.0, 0.25)
		fade.tween_callback(white.queue_free)

func _show_result() -> void:
	_clear_controls()
	await get_tree().create_timer(RESULT_DELAY).timeout
	# A replay during the blast already started a new run.
	if not GameManager.ended or is_instance_valid(result_panel):
		return
	var parts := _overlay(0.55)
	result_panel = parts[0]
	var column: VBoxContainer = parts[1]
	column.add_child(HudKit.label("FIM DE JOGO", 112, HudKit.CORAL, HORIZONTAL_ALIGNMENT_CENTER))
	var content := _card(column, 26)
	content.add_child(HudKit.label("%s  -  NÍVEL %d  -  ZONA %d" % [GameManager.mode_name(), GameManager.level + 1, GameManager.zone + 1], 32, HudKit.SKY, HORIZONTAL_ALIGNMENT_CENTER))
	var total := HudKit.label("0", 128, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	content.add_child(total)
	var final_score := GameManager.score
	var count := total.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	count.tween_method(func(v: int): total.text = str(v), 0, final_score, 0.9)
	if final_score > best_before_run:
		var record := _centered(HudKit.panel("gold"))
		record.mouse_filter = Control.MOUSE_FILTER_IGNORE
		record.add_child(HudKit.label("NOVO RECORDE!", 48, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
		content.add_child(record)
		count.tween_callback(func(): HudKit.pop(record, 1.3))
	else:
		content.add_child(HudKit.label("RECORDE %d" % GameManager.best, 48, HudKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	if GameManager.coins > 0:
		content.add_child(HudKit.icon_row(coin_frames[0], 1.5, "+%d MOEDAS  (%d)" % [GameManager.earned, GameManager.wallet], 32, HudKit.GOLD))
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 20)
	content.add_child(stats)
	_stat(stats, "%ds" % int(GameManager.elapsed), "TEMPO")
	_stat(stats, str(GameManager.best_combo), "COMBO")
	_stat(stats, str(GameManager.fever_count), "FEBRES")
	if not GameManager.save_ok:
		content.add_child(HudKit.label("Progresso só nesta sessão", 32, HudKit.CORAL, HORIZONTAL_ALIGNMENT_CENTER))
	replay_button = _centered(HudKit.button("JOGAR DE NOVO", "gold", Vector2(680, 160), _restart, 64)) as Button
	content.add_child(replay_button)
	result_menu_button = _centered(HudKit.button("MENU PRINCIPAL", "frame", Vector2(680, 160), _back_to_menu, 48)) as Button
	content.add_child(result_menu_button)
	replay_button.grab_focus()

func _restart() -> void:
	_reset_run()
	_start_game()

## Leaves the current run (paused or finished) and shows the main menu.
## An unfinished run is abandoned: its score does not count as a record.
func _back_to_menu() -> void:
	# Coins caught in an abandoned run still go to the wallet.
	GameManager.bank_run()
	_reset_run()
	if not is_instance_valid(menu_panel):
		_show_menu()

## Clears everything a run leaves behind, without starting a new one.
func _reset_run() -> void:
	for audio in sounds:
		audio.stop()
		audio.stream = null
		audio.stream_paused = false
	for effect in get_tree().get_nodes_in_group("run_effects"):
		effect.queue_free()
	_clear_controls()
	get_tree().paused = false
	Input.action_release("ui_left")
	Input.action_release("ui_right")
	GameManager.reset_game()
	$Spawner.pending.clear()
	$Spawner.clock = 0.1
	$Spawner.last_x = 540.0
	$Spawner.last_pattern = ""
	$Spawner.current_pattern = "APRENDA A COLETAR"
	$Spawner.pattern_count = 0
	$Spawner.reset_hazards()
	$Player.position.x = 540.0
	$Player.reset_visual()
	for node in get_children():
		if node is Area2D and node != $Player:
			node.queue_free()
	if is_instance_valid(result_panel):
		result_panel.queue_free()
	if is_instance_valid(pause_panel):
		pause_panel.queue_free()
	if is_instance_valid(run_shop_panel):
		run_shop_panel.queue_free()
	if boss_bob and boss_bob.is_valid():
		boss_bob.kill()
	boss_sprite.hide()
	_set_zone_tint(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and GameManager.started and not GameManager.ended:
		if not get_tree().paused:
			_toggle_pause()

func _show_menu() -> void:
	var parts := _overlay(0.45)
	menu_panel = parts[0]
	var column: VBoxContainer = parts[1]
	column.add_theme_constant_override("separation", 0)
	# PixelLab title logo at 6x; it floats and breathes inside a fixed stage.
	var logo_stage := Control.new()
	logo_stage.custom_minimum_size = Vector2(760, 500)
	logo_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_centered(logo_stage))
	var logo := TextureRect.new()
	logo.texture = load("res://Assets/UI/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.size = logo.texture.get_size() * 6.0
	logo.position = (logo_stage.custom_minimum_size - logo.size) / 2.0
	logo.pivot_offset = logo.size / 2.0
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_stage.add_child(logo)
	var drift := logo.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	drift.tween_property(logo, "position:y", -12.0, 1.1).as_relative()
	drift.tween_property(logo, "position:y", 12.0, 1.1).as_relative()
	var breathe := logo.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	breathe.tween_property(logo, "scale", Vector2(1.03, 0.98), 0.8)
	breathe.tween_property(logo, "scale", Vector2.ONE, 0.8)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 30
	column.add_child(spacer)
	var content := _card(column, 22)
	content.add_child(HudKit.icon_row(coin_frames[0], 2.0, "Pegue as moedas", 48, Color.WHITE))
	content.add_child(HudKit.icon_row(load("res://Assets/New/bomb.png"), 2.0, "Desvie das bombas", 48, Color.WHITE))
	content.add_child(HudKit.label("20 moedas = FEBRE!", 48, HudKit.MINT, HORIZONTAL_ALIGNMENT_CENTER))
	content.add_child(HudKit.label("Chefão a cada %d níveis!" % GameManager.BOSS_EVERY, 32, HudKit.CORAL, HORIZONTAL_ALIGNMENT_CENTER))
	var modes := HBoxContainer.new()
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	modes.add_theme_constant_override("separation", 16)
	content.add_child(modes)
	mode_buttons.clear()
	for i in GameManager.MODES.size():
		var choice := HudKit.button(GameManager.MODES[i], "square", Vector2(210, 120), _select_mode.bind(i), 32)
		modes.add_child(choice)
		mode_buttons.append(choice)
	play_button = _centered(HudKit.button("JOGAR", "primary", Vector2(620, 180), _start_game, 80)) as Button
	content.add_child(play_button)
	menu_best_label = HudKit.label("", 48, HudKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	content.add_child(menu_best_label)
	var shop_row := HBoxContainer.new()
	shop_row.alignment = BoxContainer.ALIGNMENT_CENTER
	shop_row.add_theme_constant_override("separation", 24)
	content.add_child(shop_row)
	shop_button = HudKit.button("LOJA", "frame", Vector2(240, 140), _show_shop, 40)
	shop_row.add_child(shop_button)
	destiny_button = HudKit.button("DESTINO", "gold", Vector2(260, 140), _show_destiny, 40)
	shop_row.add_child(destiny_button)
	var wallet_row := HudKit.icon_row(coin_frames[0], 2.0, "", 48, HudKit.GOLD)
	menu_wallet_label = wallet_row.get_child(1)
	shop_row.add_child(wallet_row)
	_refresh_modes()
	play_button.grab_focus()

func _select_mode(index: int) -> void:
	GameManager.set_mode(index)
	_refresh_modes()
	HudKit.pop(mode_buttons[index], 1.12)

func _refresh_modes() -> void:
	for i in mode_buttons.size():
		HudKit.apply_skin(mode_buttons[i], "gold" if i == GameManager.mode else "square")
	menu_best_label.text = "RECORDE %d" % GameManager.best if GameManager.best > 0 else "SEM RECORDE AINDA"
	menu_wallet_label.text = GameManager.big_number(GameManager.wallet)

func _powerup_collected(kind: String) -> void:
	if kind == "magnet":
		_tone(880, 0.12, 0.2)
		_tone(1320, 0.16, 0.16)
		HudKit.pop(magnet_badge, 1.3)

## Menu shop: shopkeeper on top, three tabs below. Rows are rebuilt after every action.
func _show_shop() -> void:
	if is_instance_valid(shop_panel):
		return
	if is_instance_valid(menu_panel):
		menu_panel.hide()
	var parts := _overlay(0.45)
	shop_panel = parts[0]
	var column: VBoxContainer = parts[1]
	column.add_theme_constant_override("separation", 0)
	var keeper := TextureRect.new()
	keeper.texture = load("res://Assets/UI/shopkeeper.png")
	keeper.custom_minimum_size = keeper.texture.get_size() * 3.0
	keeper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	keeper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_centered(keeper))
	var bob := keeper.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	bob.tween_property(keeper, "scale", Vector2(1.0, 0.97), 0.7)
	bob.tween_property(keeper, "scale", Vector2.ONE, 0.7)
	keeper.resized.connect(func(): keeper.pivot_offset = Vector2(keeper.size.x / 2.0, keeper.size.y))
	var content := _card(column, 18)
	var wallet_row := HudKit.icon_row(coin_frames[0], 2.0, "", 64, HudKit.GOLD)
	shop_wallet_label = wallet_row.get_child(1)
	content.add_child(wallet_row)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 12)
	content.add_child(tabs)
	shop_tabs.clear()
	for tab in SHOP_TABS:
		var tab_button := HudKit.button(SHOP_TABS[tab], "square", Vector2(260, 100), _select_shop_tab.bind(tab), 40)
		tabs.add_child(tab_button)
		shop_tabs[tab] = tab_button
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(680, 750)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	shop_list = VBoxContainer.new()
	shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_list.add_theme_constant_override("separation", 12)
	scroll.add_child(shop_list)
	shop_close_button = _centered(HudKit.button("VOLTAR", "primary", Vector2(520, 140), _close_shop, 64)) as Button
	content.add_child(shop_close_button)
	_select_shop_tab(shop_tab)

func _select_shop_tab(tab: String) -> void:
	shop_tab = tab
	for id in shop_tabs:
		HudKit.apply_skin(shop_tabs[id], "gold" if id == tab else "square")
	_fill_shop()

func _fill_shop() -> void:
	shop_wallet_label.text = str(GameManager.wallet)
	for child in shop_list.get_children():
		child.queue_free()
	shop_buttons.clear()
	match shop_tab:
		"items":
			for id in GameManager.ITEMS:
				var info: Dictionary = GameManager.ITEMS[id]
				var have := GameManager.item_count(id)
				var full: bool = have >= info.max
				shop_buttons[id] = _shop_row(load(info.icon), info.name, "%s  (%d/%d)" % [info.info, have, info.max],
					"CHEIO" if full else str(info.price), "gold", GameManager.can_buy_item(id), _buy_item.bind(id))
			shop_list.add_child(HudKit.label("Usados sozinhos ao começar a partida", 32, HudKit.SKY, HORIZONTAL_ALIGNMENT_CENTER))
		"skins":
			for id in GameManager.SKINS:
				var info: Dictionary = GameManager.SKINS[id]
				# Only the slime, without the frame's empty margin.
				var preview := AtlasTexture.new()
				preview.atlas = load("res://Assets/SlimeReactions/collect_00.png")
				preview.region = Rect2(12, 14, 28, 23)
				var worn: bool = GameManager.skin == id
				var owned: bool = GameManager.owns_skin(id)
				var label: String = "EM USO" if worn else ("USAR" if owned else str(info.price))
				var enabled: bool = not worn and (owned or GameManager.wallet >= info.price)
				var buy := _shop_row(preview, info.name, "Equipado" if worn else ("Comprado" if owned else ""),
					label, "primary" if owned else "gold", enabled, _pick_skin.bind(id))
				var icon: TextureRect = buy.get_parent().get_child(0)
				icon.material = ShaderMaterial.new()
				icon.material.shader = preload("res://Assets/Shaders/slime_hue.gdshader")
				icon.material.set_shader_parameter("hue_shift", info.hue)
				shop_buttons[id] = buy

## One shop line: icon, name and detail, and an action button on the right.
func _shop_row(icon: Texture2D, title: String, detail: String, action: String, skin_name: String, enabled: bool, callback: Callable) -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	shop_list.add_child(row)
	var picture := TextureRect.new()
	picture.texture = icon
	picture.custom_minimum_size = Vector2(96, 96)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(picture)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 4)
	row.add_child(text)
	text.add_child(HudKit.label(title, 48))
	if detail != "":
		var info_label := HudKit.label(detail, 32, HudKit.SKY)
		info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(info_label)
	var button := HudKit.button(action, skin_name if enabled else "square", Vector2(190, 110), callback, 40)
	button.disabled = not enabled
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(button)
	return button

func _shop_bought() -> void:
	_tone(990, 0.1, 0.2)
	_tone(1480, 0.14, 0.18)
	_fill_shop()
	HudKit.pop(shop_wallet_label, 1.2)

func _buy_item(id: String) -> void:
	if GameManager.buy_item(id):
		_shop_bought()

func _pick_skin(id: String) -> void:
	if GameManager.owns_skin(id):
		GameManager.equip_skin(id)
		_tone(700, 0.08, 0.15)
		_fill_shop()
	elif GameManager.buy_skin(id):
		_shop_bought()
	$Player.apply_skin()

func _show_destiny() -> void:
	if is_instance_valid(destiny_board):
		return
	if is_instance_valid(menu_panel):
		menu_panel.hide()
	destiny_board = preload("res://Assets/Scripts/DestinyBoard.gd").new()
	destiny_board.closed.connect(_close_destiny)
	destiny_board.bought.connect(func(_id):
		_tone(990, 0.1, 0.2)
		_tone(1480, 0.14, 0.18))
	ui.add_child(destiny_board)

func _close_destiny() -> void:
	if is_instance_valid(destiny_board):
		destiny_board.queue_free()
	if is_instance_valid(menu_panel):
		menu_panel.show()
	_refresh_modes()

func _close_shop() -> void:
	if is_instance_valid(shop_panel):
		shop_panel.queue_free()
	if is_instance_valid(menu_panel):
		menu_panel.show()
	_refresh_modes()

## Mini-shop at each level-up: pauses the run, sells items that act right away.
func _show_run_shop() -> void:
	if GameManager.ended or not GameManager.started or is_instance_valid(run_shop_panel):
		return
	if GameManager.wallet < GameManager.cheapest_run_item():
		return
	if is_instance_valid(pause_panel):
		pause_panel.queue_free()
	_clear_controls()
	get_tree().paused = true
	for audio in sounds:
		audio.stream_paused = true
	var parts := _overlay(0.6)
	run_shop_panel = parts[0]
	var column: VBoxContainer = parts[1]
	column.add_child(HudKit.label("VITÓRIA!", 96, HudKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(HudKit.label("LOJINHA  -  ZONA %d" % (GameManager.zone + 1), 48, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	var content := _card(column, 20)
	var wallet_row := HudKit.icon_row(coin_frames[0], 2.0, "", 64, HudKit.GOLD)
	shop_wallet_label = wallet_row.get_child(1)
	content.add_child(wallet_row)
	shop_list = VBoxContainer.new()
	shop_list.add_theme_constant_override("separation", 20)
	content.add_child(shop_list)
	run_shop_continue = _centered(HudKit.button("CONTINUAR", "primary", Vector2(560, 150), _close_run_shop, 64)) as Button
	content.add_child(run_shop_continue)
	_fill_run_shop()

func _fill_run_shop() -> void:
	shop_wallet_label.text = str(GameManager.wallet)
	for child in shop_list.get_children():
		child.queue_free()
	shop_buttons.clear()
	for id in GameManager.RUN_ITEMS:
		var info: Dictionary = GameManager.RUN_ITEMS[id]
		shop_buttons[id] = _shop_row(load(info.icon), info.name, info.info, str(info.price), "gold",
			GameManager.can_buy_run_item(id), _buy_run_item.bind(id))

func _buy_run_item(id: String) -> void:
	if GameManager.buy_run_item(id):
		_tone(990, 0.1, 0.2)
		_tone(1480, 0.14, 0.18)
		_fill_run_shop()
		HudKit.pop(shop_wallet_label, 1.2)

func _close_run_shop() -> void:
	if is_instance_valid(run_shop_panel):
		run_shop_panel.queue_free()
	_clear_controls()
	get_tree().paused = false
	for audio in sounds:
		audio.stream_paused = false

func _level_up(level: int) -> void:
	# Boss levels announce the boss instead.
	if (level + 1) % GameManager.BOSS_EVERY != 0:
		_banner("NÍVEL %d!  MAIS RÁPIDO" % (level + 1), HudKit.CORAL)
	$Camera2D.start_shake(6)
	_tone(520, 0.12, 0.2)
	_tone(780, 0.18, 0.2)

func _build_boss() -> void:
	boss_sprite = AnimatedSprite2D.new()
	boss_sprite.animation_finished.connect(func():
		if boss_sprite.animation != "death":
			boss_sprite.play("idle"))
	boss_sprite.scale = Vector2(4, 4)
	boss_sprite.position = BOSS_POS
	# Behind the falling items, so bombs stay readable over the boss.
	boss_sprite.z_index = -1
	boss_sprite.hide()
	add_child(boss_sprite)
	boss_bar = _place(Control.new(), Vector2(40, 470), Vector2(1000, 90))
	boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_name_label = HudKit.label("", 32, HudKit.CORAL)
	boss_name_label.size = Vector2(760, 40)
	boss_bar.add_child(boss_name_label)
	boss_time_label = HudKit.label("", 32, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	boss_time_label.position = Vector2(760, 0)
	boss_time_label.size = Vector2(240, 40)
	boss_bar.add_child(boss_time_label)
	var back := ColorRect.new()
	back.color = Color(0.05, 0.02, 0.08, 0.85)
	back.position = Vector2(194, 46)
	back.size = Vector2(BOSS_BAR_WIDTH + 12, 34)
	boss_bar.add_child(back)
	boss_fill = ColorRect.new()
	boss_fill.color = Color("ff5a6e")
	boss_fill.position = Vector2(200, 52)
	boss_fill.size = Vector2(BOSS_BAR_WIDTH, 22)
	boss_bar.add_child(boss_fill)
	boss_bar.hide()

func _boss_started(index: int) -> void:
	var info: Dictionary = GameManager.BOSSES[index]
	boss_sprite.sprite_frames = _boss_frames(index)
	boss_sprite.play("idle")
	boss_throw_ready = 0.0
	boss_sprite.modulate = Color.WHITE
	boss_sprite.scale = Vector2(4, 4)
	boss_sprite.position = BOSS_POS - Vector2(0, 700)
	boss_sprite.show()
	boss_name_label.text = "CHEFÃO: " + info.name
	if boss_bob and boss_bob.is_valid():
		boss_bob.kill()
	# Drops in, then hovers.
	boss_bob = boss_sprite.create_tween()
	boss_bob.tween_property(boss_sprite, "position", BOSS_POS, 0.9).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	boss_bob.tween_callback(func():
		boss_bob = boss_sprite.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		boss_bob.tween_property(boss_sprite, "position:y", BOSS_POS.y - 18.0, 0.8)
		boss_bob.tween_property(boss_sprite, "position:y", BOSS_POS.y + 6.0, 0.8))
	_banner("CHEFÃO: " + info.name, HudKit.CORAL)
	_banner("DEVOLVA AS BOMBAS DOURADAS!", HudKit.GOLD)
	$Camera2D.start_shake(10)
	_tone(110, 0.35, 0.3)

func _boss_frames(index: int) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_frame("default", load(GameManager.BOSSES[index].art))
	frames.rename_animation("default", "idle")
	for anim in BOSS_ANIMS:
		var sheet: Texture2D = load("res://Assets/Boss/boss%d_%s.png" % [index + 1, anim])
		frames.add_animation(anim)
		frames.set_animation_loop(anim, false)
		frames.set_animation_speed(anim, BOSS_ANIMS[anim])
		for i in sheet.get_width() / BOSS_FRAME:
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(i * BOSS_FRAME, 0, BOSS_FRAME, BOSS_FRAME)
			frames.add_frame(anim, frame)
	return frames

## A bomb spawned during the fight is hidden for a moment while a copy flies from the
## boss's hand to the spot where it starts falling, so the boss visibly throws it.
func boss_lob(bomb: Node2D) -> void:
	if not GameManager.boss_active or not boss_sprite.visible or boss_sprite.animation == "death":
		return
	if ui_time >= boss_throw_ready and boss_sprite.animation == "idle":
		boss_sprite.play("throw")
		boss_throw_ready = ui_time + 0.7
	boss_hand = 1 - boss_hand
	var hand: Vector2 = boss_sprite.position + BOSS_HANDS[boss_hand]
	bomb.visible = false
	var shot := Sprite2D.new()
	shot.texture = load("res://Assets/New/bomb.png")
	shot.scale = Vector2(3, 3)
	shot.z_index = 12
	shot.position = hand
	shot.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(shot)
	shot.add_to_group("run_effects")
	var arc := shot.create_tween()
	arc.tween_method(func(t: float):
		if not is_instance_valid(bomb):
			return
		shot.position = hand.lerp(bomb.position, t) + Vector2(0, -140.0 * sin(PI * t))
		shot.rotation = t * TAU, 0.0, 1.0, 0.24)
	arc.tween_callback(func():
		if is_instance_valid(bomb):
			bomb.visible = true
		shot.queue_free())

## The slime hurls a caught glowing bomb at the boss.
func throw_back(from: Vector2) -> void:
	_tone(660, 0.08, 0.18)
	var shot := Sprite2D.new()
	shot.texture = load("res://Assets/New/bomb.png")
	shot.scale = Vector2(3, 3)
	shot.position = from
	shot.z_index = 15
	shot.modulate = Color(1.0, 0.9, 0.5)
	shot.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(shot)
	shot.add_to_group("run_effects")
	var target := boss_sprite.position if GameManager.boss_active else Vector2(from.x, 300)
	var fly := shot.create_tween().set_parallel(true)
	fly.tween_property(shot, "position", target, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fly.tween_property(shot, "rotation", TAU * 2.0, 0.35)
	fly.chain().tween_callback(func():
		play_vfx("boss_hit", target, 5.0)
		explode(target, 2.5)
		shot.queue_free()
		GameManager.hit_boss())

func _boss_hit(hp: int) -> void:
	$Camera2D.start_shake(8)
	_tone(180, 0.15, 0.25)
	juice(boss_sprite.position + Vector2(0, 120), HudKit.GOLD, "ACERTOU!" if hp > 0 else "K.O.!", 0)
	if hp > 0:
		boss_sprite.play("hurt")
	# Red flash plus a recoil, so every boss visibly takes the hit.
	var flash := boss_sprite.create_tween()
	flash.tween_property(boss_sprite, "modulate", Color(1, 0.3, 0.3), 0.05)
	flash.tween_property(boss_sprite, "modulate", Color.WHITE, 0.25)
	var recoil := boss_sprite.create_tween()
	recoil.tween_property(boss_sprite, "offset:y", -10.0, 0.06)
	recoil.tween_property(boss_sprite, "offset:y", 0.0, 0.25).set_trans(Tween.TRANS_BACK)

func _boss_defeated(chest: int, ability: String) -> void:
	if boss_bob and boss_bob.is_valid():
		boss_bob.kill()
	# Death animation with small blasts, then the big PixelLab defeat explosion.
	boss_sprite.play("death")
	var at := boss_sprite.position
	var finale := boss_sprite.create_tween()
	for i in 3:
		finale.tween_callback(func(): play_vfx("boss_hit", at + Vector2(randf_range(-160, 160), randf_range(-140, 120)), 4.0))
		finale.tween_interval(0.25)
	finale.tween_callback(func():
		play_vfx("boss_death", at, 5.0, true)
		$Camera2D.start_shake(14)
		_tone(70, 0.45, 0.3))
	finale.set_parallel(true)
	finale.tween_property(boss_sprite, "modulate:a", 0.0, 0.7).set_delay(0.2)
	finale.tween_property(boss_sprite, "scale", Vector2(4.8, 2.4), 0.7).set_trans(Tween.TRANS_BACK)
	finale.chain().tween_callback(boss_sprite.hide)
	# Celebration once the defeat explosion is over (timers pause with the game).
	var zone_text := "ZONA %d: %s" % [GameManager.zone + 1, GameManager.zone_name()]
	get_tree().create_timer(1.2, false).timeout.connect(func():
		_banner("VITÓRIA!  +%d MOEDAS" % chest, HudKit.GOLD)
		if ability != "":
			_banner("NOVO PODER: " + GameManager.ABILITIES[ability].name, HudKit.MINT)
		_banner(zone_text, Color.WHITE)
		_show_chest()
		_set_zone_tint(true)
		_tone(523, 0.12, 0.22)
		_tone(784, 0.2, 0.2))
	get_tree().create_timer(3.4, false).timeout.connect(_show_run_shop)

func _boss_escaped() -> void:
	if boss_bob and boss_bob.is_valid():
		boss_bob.kill()
	var away := boss_sprite.create_tween()
	away.tween_property(boss_sprite, "position:y", -400.0, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	away.tween_callback(boss_sprite.hide)
	_banner("O CHEFÃO FUGIU!", HudKit.CORAL)

func _show_chest() -> void:
	var chest := TextureRect.new()
	chest.texture = load("res://Assets/UI/chest.png")
	chest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chest.size = chest.texture.get_size() * 5.0
	chest.position = Vector2(540, 1420) - chest.size / 2.0
	chest.pivot_offset = chest.size / 2.0
	chest.scale = Vector2(0.2, 0.2)
	chest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_top.add_child(chest)
	chest.add_to_group("run_effects")
	var pop := chest.create_tween()
	pop.tween_property(chest, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	pop.tween_interval(1.2)
	pop.tween_property(chest, "modulate:a", 0.0, 0.4)
	pop.tween_callback(chest.queue_free)

## Each zone recolours the cave.
func _set_zone_tint(animated: bool) -> void:
	var info := GameManager.zone_info()
	var material := backdrop.material as ShaderMaterial
	if not animated:
		material.set_shader_parameter("hue_shift", info.hue)
		material.set_shader_parameter("saturation", info.sat)
		return
	var from_hue: float = material.get_shader_parameter("hue_shift")
	var from_sat: float = material.get_shader_parameter("saturation")
	var fade := backdrop.create_tween()
	fade.tween_method(func(t: float):
		material.set_shader_parameter("hue_shift", lerpf(from_hue, info.hue, t))
		material.set_shader_parameter("saturation", lerpf(from_sat, info.sat, t)), 0.0, 1.0, 1.2)

func _coin_tier_up(top_value: int) -> void:
	_banner("MOEDAS VALEM ATÉ %d!" % top_value, HudKit.GOLD)
	_tone(990, 0.2, 0.2)

## Big centered message that pops in and floats away.
func _banner(text: String, color: Color) -> void:
	# Stack under banners that are still on screen.
	var stack := get_tree().get_nodes_in_group("banners").size()
	# The pixel font is about 0.7 em per glyph: shrink long lines to stay on screen.
	var font_size := 64
	for candidate in [64, 48, 32]:
		font_size = candidate
		if text.length() * 0.7 * candidate <= 1020.0:
			break
	# Below the boss while one is on screen, so it stays visible.
	var top := 980 if boss_sprite.visible else 700
	var banner := _make_label(text, Vector2(0, top + stack * 130), Vector2(1080, 120), font_size, color, true)
	banner.add_to_group("run_effects")
	banner.add_to_group("banners")
	banner.pivot_offset = banner.size / 2.0
	banner.scale = Vector2(0.4, 0.4)
	var tween := banner.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	tween.tween_property(banner, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.1)
	tween.tween_property(banner, "position:y", banner.position.y - 80.0, 0.5)
	tween.parallel().tween_property(banner, "modulate:a", 0.0, 0.5)
	tween.tween_callback(banner.queue_free)

func _start_game() -> void:
	if GameManager.started:
		return
	_clear_controls()
	best_before_run = GameManager.best
	if is_instance_valid(shop_panel):
		shop_panel.queue_free()
	if is_instance_valid(destiny_board):
		destiny_board.queue_free()
	if is_instance_valid(menu_panel):
		menu_panel.hide()
		menu_panel.queue_free()
	GameManager.started = true
	var used := GameManager.apply_start_items()
	if not used.is_empty():
		_banner(" + ".join(used), HudKit.MINT)

func _exit_tree() -> void:
	for audio in sounds:
		if is_instance_valid(audio):
			audio.stop()
			audio.stream = null
