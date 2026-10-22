extends Node2D

const COIN_FRAMES := 7
const FEVER_TIME := 6.0
const BAR_INSET := Vector2(26, 22)
# PixelLab VFX sheet: 10 frames of 80x87 in 4 columns, blast centre at (43, 54).
const EXPLOSION_FRAMES := 10
const EXPLOSION_SIZE := Vector2(80, 87)
const EXPLOSION_ANCHOR := Vector2(43, 54)
# Time the defeat blast plays before the result card covers it.
const RESULT_DELAY := 1.0

@onready var hud: CanvasLayer = $HUD
var ui: Control
var hud_top: Control
var menu_panel: Control
var play_button: Button
var pause_button: Button
var sound_button: Button
var resume_button: Button
var replay_button: Button
var menu_button: Button
var result_menu_button: Button
var result_panel: Control
var score_label: Label
var best_label: Label
var combo_label: Label
var level_label: Label
var mode_buttons: Array[Button] = []
var menu_best_label: Label
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
var explosion_frames: SpriteFrames

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
	$Player.collision_layer = 1
	$Player.collision_mask = 2
	$Camera2D.position = Vector2(540, 960)
	var backdrop := TextureRect.new()
	backdrop.texture = load("res://Assets/New/cave.png")
	backdrop.size = Vector2(1080, 1920)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Cenario_Background.add_child(backdrop)
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
	_place(HudKit.label("SETAS OU A/D", 32, HudKit.SKY, HORIZONTAL_ALIGNMENT_CENTER), Vector2(330, 1770), Vector2(420, 80))
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
	hud_top.visible = GameManager.started and not is_instance_valid(result_panel)
	if GameManager.score != shown_score:
		if GameManager.score > shown_score:
			HudKit.pop(score_label, 1.12)
		shown_score = GameManager.score
	score_label.text = str(GameManager.score)
	best_label.text = "RECORDE %d" % maxi(GameManager.best, GameManager.score)
	level_label.text = "%s  NV %d" % [GameManager.mode_name(), GameManager.level + 1]
	coin_icon.texture = coin_frames[int(ui_time * 10.0) % COIN_FRAMES]
	sound_button.icon = mute_icon if GameManager.muted else sound_icon
	if pattern_label.text != $Spawner.current_pattern:
		pattern_label.text = $Spawner.current_pattern
		HudKit.pop(pattern_label, 1.1)
	if GameManager.multiplier != shown_multiplier:
		shown_multiplier = GameManager.multiplier
		HudKit.pop(multiplier_badge, 1.25)
	multiplier_label.text = "x%d" % GameManager.multiplier
	combo_label.text = "%d SEGUIDAS" % GameManager.combo if GameManager.combo > 0 else "PEGUE AS MOEDAS"
	var fever: bool = GameManager.fever_left > 0.0
	var ratio := GameManager.fever_left / FEVER_TIME if fever else GameManager.charge / 100.0
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
	if explosion_frames == null:
		explosion_frames = SpriteFrames.new()
		explosion_frames.add_animation("boom")
		explosion_frames.set_animation_loop("boom", false)
		explosion_frames.set_animation_speed("boom", 10.0)
		var sheet: Texture2D = load("res://Assets/VFX/explosion.png")
		for i in EXPLOSION_FRAMES:
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(Vector2(i % 4, i / 4) * EXPLOSION_SIZE, EXPLOSION_SIZE)
			explosion_frames.add_frame("boom", frame)
	var blast := AnimatedSprite2D.new()
	blast.sprite_frames = explosion_frames
	blast.centered = false
	blast.offset = -EXPLOSION_ANCHOR
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
	content.add_child(HudKit.label("PONTOS  -  %s  NÍVEL %d" % [GameManager.mode_name(), GameManager.level + 1], 32, HudKit.SKY, HORIZONTAL_ALIGNMENT_CENTER))
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
	content.add_child(HudKit.label("A cada %d pontos fica mais rápido" % GameManager.LEVEL_POINTS, 32, HudKit.SKY, HORIZONTAL_ALIGNMENT_CENTER))
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
	content.add_child(HudKit.label("Segure as setas ou use A/D", 32, HudKit.SKY, HORIZONTAL_ALIGNMENT_CENTER))
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

func _level_up(level: int) -> void:
	_banner("NÍVEL %d!  MAIS RÁPIDO" % (level + 1), HudKit.CORAL)
	$Camera2D.start_shake(6)
	_tone(520, 0.12, 0.2)
	_tone(780, 0.18, 0.2)

func _coin_tier_up(top_value: int) -> void:
	_banner("MOEDAS VALEM ATÉ %d!" % top_value, HudKit.GOLD)
	_tone(990, 0.2, 0.2)

## Big centered message that pops in and floats away.
func _banner(text: String, color: Color) -> void:
	var banner := _make_label(text, Vector2(0, 700), Vector2(1080, 120), 64, color, true)
	banner.add_to_group("run_effects")
	banner.pivot_offset = banner.size / 2.0
	banner.scale = Vector2(0.4, 0.4)
	var tween := banner.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	tween.tween_property(banner, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.1)
	tween.tween_property(banner, "position:y", 620.0, 0.5)
	tween.parallel().tween_property(banner, "modulate:a", 0.0, 0.5)
	tween.tween_callback(banner.queue_free)

func _start_game() -> void:
	if GameManager.started:
		return
	_clear_controls()
	best_before_run = GameManager.best
	if is_instance_valid(menu_panel):
		menu_panel.hide()
		menu_panel.queue_free()
	GameManager.started = true

func _exit_tree() -> void:
	for audio in sounds:
		if is_instance_valid(audio):
			audio.stop()
			audio.stream = null
