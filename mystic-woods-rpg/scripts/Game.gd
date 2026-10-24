extends Node
## Global state: player stats, progression, quests and save file.

signal stats_changed
signal message(text: String, color: Color)
signal quest_changed
signal leveled_up(new_level: int)

const SAVE_PATH := "user://mystic_woods_save.cfg"
const MAX_POTIONS := 9

const QUESTS := [
	{"title": "Primeiros passos", "desc": "Derrote 5 Slimes no Prado", "type": "kill", "target": ["slime"], "count": 5, "gold": 20, "xp": 15},
	{"title": "Cogumelos travessos", "desc": "Derrote 4 Cogumelos", "type": "kill", "target": ["mushroom"], "count": 4, "gold": 25, "xp": 20},
	{"title": "Explorador", "desc": "Descubra 3 regiões do mapa", "type": "discover", "count": 3, "gold": 30, "xp": 30},
	{"title": "Caça ao tesouro", "desc": "Abra 4 baús", "type": "chests", "count": 4, "gold": 40, "xp": 30},
	{"title": "Ameaça goblin", "desc": "Derrote 6 Goblins na Floresta", "type": "kill", "target": ["goblin", "goblin_chief"], "count": 6, "gold": 50, "xp": 50},
	{"title": "Ossos inquietos", "desc": "Derrote 6 Esqueletos nas Ruínas", "type": "kill", "target": ["skeleton", "skeleton_dark"], "count": 6, "gold": 60, "xp": 70},
	{"title": "Almas perdidas", "desc": "Derrote 4 Fantasmas", "type": "kill", "target": ["ghost"], "count": 4, "gold": 70, "xp": 80},
	{"title": "Coração de pedra", "desc": "Derrote 2 Golens na Pedreira", "type": "kill", "target": ["golem"], "count": 2, "gold": 90, "xp": 120},
	{"title": "O Ent Ancião", "desc": "Vença o chefe no Coração da Floresta", "type": "kill", "target": ["treant"], "count": 1, "gold": 300, "xp": 400},
]

var save_path := SAVE_PATH
var muted := false

var world_seed := 0
var level := 1
var xp := 0
var gold := 0
var potions := 2
var max_hp := 30
var hp := 30
var atk := 6
var defense := 0
var sword_tier := 0
var kills := {}
var opened_chests := {}
var broken := {}
var discovered := {}
var explored := PackedByteArray()
var boss_defeated := false
var quest_index := 0
var quest_progress := 0
var player_pos := Vector2.ZERO
var has_saved_pos := false
var play_time := 0.0
var day_time := 0.3  # 0..1, 0.25 = morning, 0.75 = night


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()


func _process(delta: float) -> void:
	if not get_tree().paused:
		play_time += delta


# ---------------------------------------------------------------- new game / stats
func new_game(seed_value: int = -1) -> void:
	world_seed = seed_value if seed_value >= 0 else randi() % 1000000
	level = 1
	xp = 0
	gold = 0
	potions = 2
	max_hp = 30
	hp = 30
	atk = 6
	defense = 0
	sword_tier = 0
	kills = {}
	opened_chests = {}
	broken = {}
	discovered = {}
	explored = PackedByteArray()
	explored.resize(WorldGen.W * WorldGen.H)
	boss_defeated = false
	quest_index = 0
	quest_progress = 0
	has_saved_pos = false
	play_time = 0.0
	day_time = 0.3
	stats_changed.emit()
	quest_changed.emit()


func xp_to_next() -> int:
	return 20 + (level - 1) * 15 + (level - 1) * (level - 1) * 5


func attack_power() -> int:
	return atk + sword_tier * 3


func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next():
		xp -= xp_to_next()
		_level_up()
	stats_changed.emit()


func _level_up() -> void:
	level += 1
	max_hp += 6
	atk += 2
	if level % 2 == 0:
		defense += 1
	hp = max_hp
	leveled_up.emit(level)
	message.emit("NÍVEL %d!  Vida, ataque e defesa aumentaram" % level, Color(1.0, 0.85, 0.3))


func add_gold(amount: int) -> void:
	gold += amount
	stats_changed.emit()


func damage_player(raw: int) -> int:
	var dmg: int = max(1, raw - defense)
	hp = max(0, hp - dmg)
	stats_changed.emit()
	return dmg


func heal(amount: int) -> void:
	hp = min(max_hp, hp + amount)
	stats_changed.emit()


func use_potion() -> bool:
	if potions <= 0 or hp >= max_hp:
		return false
	potions -= 1
	heal(int(max_hp * 0.5) + 10)
	return true


func add_potion() -> bool:
	if potions >= MAX_POTIONS:
		return false
	potions += 1
	stats_changed.emit()
	return true


# ---------------------------------------------------------------- quests
func current_quest() -> Dictionary:
	if quest_index < QUESTS.size():
		return QUESTS[quest_index]
	return {}


func quest_text() -> String:
	var q := current_quest()
	if q.is_empty():
		return "Todas as missões completas!\nExplore o mundo livremente."
	var count: int = q["count"]
	return "%s\n%s (%d/%d)" % [q["title"], q["desc"], min(quest_progress, count), count]


func register_kill(monster_id: String) -> void:
	kills[monster_id] = int(kills.get(monster_id, 0)) + 1
	if monster_id == "treant":
		boss_defeated = true
	var q := current_quest()
	if not q.is_empty() and q["type"] == "kill" and monster_id in q["target"]:
		quest_progress += 1
		_check_quest()


func register_chest(chest_id: String) -> void:
	opened_chests[chest_id] = true
	var q := current_quest()
	if not q.is_empty() and q["type"] == "chests":
		quest_progress += 1
		_check_quest()


func register_region(region: String) -> bool:
	if discovered.has(region):
		return false
	discovered[region] = true
	var q := current_quest()
	if not q.is_empty() and q["type"] == "discover":
		quest_progress = _explored_count()
		_check_quest()
	return true


func _explored_count() -> int:
	var n := 0
	for r in discovered:
		if r != "vila" and r != "prado":
			n += 1
	return n


func _check_quest() -> void:
	var q := current_quest()
	if q.is_empty():
		return
	if quest_progress >= int(q["count"]):
		gold += int(q["gold"])
		message.emit("Missão completa: %s  (+%d ouro, +%d XP)" % [q["title"], q["gold"], q["xp"]], Color(0.55, 1.0, 0.55))
		quest_index += 1
		quest_progress = 0
		var next := current_quest()
		if not next.is_empty():
			if next["type"] == "discover":
				quest_progress = _explored_count()
			elif next["type"] == "chests":
				quest_progress = 0
		add_xp(int(q["xp"]))
		if not next.is_empty() and quest_progress >= int(next["count"]):
			_check_quest()
	quest_changed.emit()
	stats_changed.emit()


# ---------------------------------------------------------------- save / load
func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func save_game() -> void:
	var cfg := ConfigFile.new()
	for key in ["world_seed", "level", "xp", "gold", "potions", "max_hp", "hp", "atk", "defense", "sword_tier",
			"kills", "opened_chests", "broken", "discovered", "explored", "boss_defeated", "quest_index", "quest_progress",
			"player_pos", "play_time", "day_time", "muted"]:
		cfg.set_value("save", key, get(key))
	cfg.save(save_path)


func load_game() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return false
	for key in cfg.get_section_keys("save"):
		set(key, cfg.get_value("save", key))
	hp = clampi(hp, 1, max_hp)
	if explored.size() != WorldGen.W * WorldGen.H:
		explored = PackedByteArray()
		explored.resize(WorldGen.W * WorldGen.H)
	has_saved_pos = true
	stats_changed.emit()
	quest_changed.emit()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


# ---------------------------------------------------------------- input map
func _setup_input() -> void:
	var keys := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"attack": [KEY_J, KEY_SPACE, KEY_Z],
		"dash": [KEY_K, KEY_SHIFT, KEY_X],
		"potion": [KEY_Q, KEY_H],
		"interact": [KEY_E, KEY_ENTER],
		"pause": [KEY_ESCAPE, KEY_P],
		"map": [KEY_M, KEY_TAB],
	}
	var pads := {
		"attack": JOY_BUTTON_A, "dash": JOY_BUTTON_B, "potion": JOY_BUTTON_X,
		"interact": JOY_BUTTON_Y, "pause": JOY_BUTTON_START, "map": JOY_BUTTON_BACK,
		"move_left": JOY_BUTTON_DPAD_LEFT, "move_right": JOY_BUTTON_DPAD_RIGHT,
		"move_up": JOY_BUTTON_DPAD_UP, "move_down": JOY_BUTTON_DPAD_DOWN,
	}
	var axes := {
		"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.3)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
		if pads.has(action):
			var jb := InputEventJoypadButton.new()
			jb.button_index = pads[action]
			InputMap.action_add_event(action, jb)
		if axes.has(action):
			var ja := InputEventJoypadMotion.new()
			ja.axis = axes[action][0]
			ja.axis_value = axes[action][1]
			InputMap.action_add_event(action, ja)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", mouse)
