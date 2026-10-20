extends Node2D

@onready var hud: CanvasLayer = $HUD
var menu_panel: PanelContainer
var sound_button: Button
var result_panel: PanelContainer
var score_label: Label
var combo_label: Label
var pattern_label: Label
var fever_label: Label
var bar: ProgressBar
var pause_panel: PanelContainer
var sounds: Array[AudioStreamPlayer] = []
var sound_cursor: int = 0
var was_fever: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Gameplay nodes inherit the pausable mode, while UI stays active.
	$Player.process_mode = Node.PROCESS_MODE_PAUSABLE
	$Spawner.process_mode = Node.PROCESS_MODE_PAUSABLE
	GameManager.reset_game()
	GameManager.game_ended.connect(_show_result)
	GameManager.fever_started.connect(_fever_start)
	$Player.collision_layer = 1
	$Player.collision_mask = 2
	$Camera2D.position = Vector2(540, 960)
	$Chao_Visual.hide()
	$Cenario_Background/Fundo_Parede.hide()
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
	$HUD/ScoreLabel.hide()
	_make_label("SLIME FEVER", Vector2(40, 35), Vector2(650, 65), 44, Color("a3ffce"))
	score_label = _make_label("0", Vector2(40, 102), Vector2(650, 100), 86, Color.WHITE)
	combo_label = _make_label("", Vector2(45, 208), Vector2(900, 50), 32, Color("ffe497"))
	bar = ProgressBar.new()
	bar.position = Vector2(45, 280)
	bar.size = Vector2(990, 24)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _style(Color("12273e"), Color("426679")))
	bar.add_theme_stylebox_override("fill", _style(Color("7fffd0"), Color("a3ffce")))
	hud.add_child(bar)
	fever_label = _make_label("", Vector2(45, 318), Vector2(990, 50), 30, Color("a3ffce"))
	pattern_label = _make_label("", Vector2(45, 370), Vector2(990, 40), 25, Color("a9cbd6"))
	var pause := _button("II", Vector2(750, 35), Vector2(130, 125), _toggle_pause)
	pause.add_theme_font_size_override("font_size", 32)
	sound_button = _button("SOM", Vector2(900, 35), Vector2(135, 125), _toggle_sound)
	sound_button.add_theme_font_size_override("font_size", 24)
	_make_label("TOQUE OU CLIQUE\nA/D OU SETAS", Vector2(350, 1780), Vector2(380, 100), 24, Color("d9fff1"), true)
	_add_direction(Vector2(205, 1810), -1)
	_add_direction(Vector2(875, 1810), 1)
	for i in 6:
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		sounds.append(audio)
	_show_menu()

func _process(_delta: float) -> void:
	if not is_instance_valid(score_label):
		return
	score_label.text = str(GameManager.score)
	sound_button.text = "MUDO" if GameManager.muted else "SOM"
	pattern_label.text = $Spawner.current_pattern
	combo_label.text = "x%d  •  %d SEGUIDAS     RECORDE %d" % [GameManager.multiplier, GameManager.combo, GameManager.best]
	var fever: bool = GameManager.fever_left > 0.0
	bar.value = GameManager.fever_left / 6.0 * 100.0 if fever else GameManager.charge
	fever_label.text = "FEBRE! BOMBAS VIRAM PONTOS  %.1fs" % GameManager.fever_left if fever else "COLETE MOEDAS PARA ATIVAR A FEBRE"
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
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color("081320"))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(label)
	return label

func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(18)
	return style

func _button(text: String, at: Vector2, dimensions: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.position = at
	button.custom_minimum_size = dimensions
	button.add_theme_font_size_override("font_size", 42)
	button.add_theme_stylebox_override("normal", _style(Color("17394c"), Color("76c9b8")))
	button.add_theme_stylebox_override("pressed", _style(Color("287b6c"), Color("b6ffdb")))
	button.pressed.connect(callback)
	hud.add_child(button)
	return button

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
	var popup := _make_label(text, at - Vector2(140, 100), Vector2(280, 70), 45, color, true)
	popup.add_to_group("run_effects")
	var tween := popup.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 100, 0.65)
	tween.tween_property(popup, "modulate:a", 0.0, 0.65)
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

func warn_bomb(x: float) -> void:
	var warning := _make_label("!", Vector2(x - 35, 390), Vector2(70, 70), 60, Color("ffb28a"), true)
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
		pause_panel = PanelContainer.new()
		pause_panel.position = Vector2(140, 700)
		pause_panel.size = Vector2(800, 300)
		pause_panel.add_theme_stylebox_override("panel", _style(Color("10263a"), Color("a3ffce")))
		hud.add_child(pause_panel)
		var resume := Button.new()
		resume.text = "PAUSADO\nCONTINUAR"
		resume.add_theme_font_size_override("font_size", 50)
		resume.pressed.connect(_toggle_pause)
		pause_panel.add_child(resume)

func _show_result() -> void:
	_clear_controls()
	result_panel = PanelContainer.new()
	result_panel.position = Vector2(130, 550)
	result_panel.size = Vector2(820, 650)
	result_panel.add_theme_stylebox_override("panel", _style(Color("10263a"), Color("a3ffce")))
	hud.add_child(result_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 35)
	result_panel.add_child(content)
	var label := Label.new()
	label.text = "FIM DE JOGO\n%d PONTOS\nRECORDE %d\n\nTEMPO %ds  •  SEQUÊNCIA %d\nFEBRES %d" % [GameManager.score, GameManager.best, int(GameManager.elapsed), GameManager.best_combo, GameManager.fever_count]
	if not GameManager.save_ok:
		label.text += "\nProgresso só nesta sessão"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 40)
	content.add_child(label)
	var replay := Button.new()
	replay.text = "JOGAR DE NOVO"
	replay.custom_minimum_size.y = 130
	replay.add_theme_font_size_override("font_size", 44)
	replay.pressed.connect(_restart)
	content.add_child(replay)
	replay.grab_focus()

func _restart() -> void:
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
	$Player.position.x = 540.0
	$Player.reset_visual()
	for node in get_children():
		if node is Area2D and node != $Player:
			node.queue_free()
	if is_instance_valid(result_panel):
		result_panel.queue_free()
	_start_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and GameManager.started and not GameManager.ended:
		if not get_tree().paused:
			_toggle_pause()





func _show_menu() -> void:
	menu_panel = PanelContainer.new()
	menu_panel.position = Vector2(120, 590)
	menu_panel.size = Vector2(840, 620)
	menu_panel.add_theme_stylebox_override("panel", _style(Color("10263a"), Color("a3ffce")))
	hud.add_child(menu_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 36)
	menu_panel.add_child(column)
	var intro := Label.new()
	intro.text = "SLIME FEVER\n\nPegue moedas. Desvie das bombas.\n20 moedas ativam a FEBRE!\n\nSegure as setas na tela\nou use A/D e as setas do teclado."
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.add_theme_font_size_override("font_size", 36)
	column.add_child(intro)
	var play := Button.new()
	play.text = "JOGAR"
	play.custom_minimum_size.y = 130
	play.add_theme_font_size_override("font_size", 48)
	play.pressed.connect(_start_game)
	column.add_child(play)
	play.grab_focus()

func _start_game() -> void:
	if GameManager.started:
		return
	_clear_controls()
	if is_instance_valid(menu_panel):
		menu_panel.hide()
		menu_panel.queue_free()
	GameManager.started = true


func _exit_tree() -> void:
	for audio in sounds:
		if is_instance_valid(audio):
			audio.stop()
			audio.stream = null
