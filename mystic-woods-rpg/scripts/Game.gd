extends Node
## Global state: player stats, progression, quests and save file.

signal stats_changed
signal message(text: String, color: Color)
signal quest_changed
signal leveled_up(new_level: int)
signal items_changed

const SAVE_PATH := "user://mystic_woods_save.cfg"
const MAX_POTIONS := 9
const MP_REGEN := 0.6   # mana points per second
## Active skills (mana cost, cooldown): see Archetypes.SKILLS. Kept here for the orb pickups.
const SKILLS := Archetypes.SKILLS

const QUESTS := [
	{"title": "Primeiros passos", "desc": "Derrote 5 Slimes no Prado", "type": "kill", "target": ["slime"], "count": 5, "gold": 20, "xp": 15},
	{"title": "Cogumelos travessos", "desc": "Derrote 4 Cogumelos", "type": "kill", "target": ["mushroom"], "count": 4, "gold": 25, "xp": 20},
	{"title": "Explorador", "desc": "Descubra 3 regiões do mapa", "type": "discover", "count": 3, "gold": 30, "xp": 30},
	{"title": "Mãos à obra", "desc": "Minere 5 Minérios de Cobre", "type": "gather", "target": ["cobre"], "count": 5, "gold": 25, "xp": 25},
	{"title": "Herbalista", "desc": "Colha 4 Ervas Medicinais", "type": "gather", "target": ["erva"], "count": 4, "gold": 25, "xp": 25},
	{"title": "Caça ao tesouro", "desc": "Abra 4 baús", "type": "chests", "count": 4, "gold": 40, "xp": 30},
	{"title": "Coaxar no pântano", "desc": "Derrote 4 Sapos do Pântano", "type": "kill", "target": ["frog"], "count": 4, "gold": 40, "xp": 40},
	{"title": "Ameaça goblin", "desc": "Derrote 6 Goblins na Floresta", "type": "kill", "target": ["goblin", "goblin_chief"], "count": 6, "gold": 50, "xp": 50},
	{"title": "Uivos na noite", "desc": "Derrote 4 Lobos Sombrios", "type": "kill", "target": ["wolf"], "count": 4, "gold": 50, "xp": 60},
	{"title": "Ossos inquietos", "desc": "Derrote 6 Esqueletos nas Ruínas", "type": "kill", "target": ["skeleton", "skeleton_dark"], "count": 6, "gold": 60, "xp": 70},
	{"title": "Almas perdidas", "desc": "Derrote 4 Fantasmas", "type": "kill", "target": ["ghost"], "count": 4, "gold": 70, "xp": 80},
	{"title": "Teias nas ruínas", "desc": "Derrote 5 Aranhas Espinhosas", "type": "kill", "target": ["spider"], "count": 5, "gold": 70, "xp": 90},
	{"title": "Ferreiro aprendiz", "desc": "Forje uma Picareta de Ferro", "type": "craft", "target": ["picareta_ferro"], "count": 1, "gold": 50, "xp": 80},
	{"title": "Fúria orc", "desc": "Derrote 5 Orcs Guerreiros", "type": "kill", "target": ["orc"], "count": 5, "gold": 90, "xp": 120},
	{"title": "Gigantes de cristal", "desc": "Derrote 3 Golens de Cristal", "type": "kill", "target": ["crystal_elemental"], "count": 3, "gold": 100, "xp": 140},
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
var max_mp := 20          # mana for the magic skills
var mp := 20
var _mp_regen := 0.0
var atk := 6
var defense := 0
var sword_tier := 0
var tool_tier := 0
var armor_tier := 0
var items := {}
var skills: Array = []
var orb_skills: Array = []          # skills taught by orbs (kept when the archetypes are reset)
var skill_slots: Array = ["", "", ""]   # active skill buttons
var archetypes: Array = []          # chosen archetypes (Archetypes.gd), up to three
var arch_ranks := {}                # node id -> rank
var arch_bonus_points := 0
var copied := ""                    # Mago: the spell held by Ctrl+C
var last_cast := ""
var _hp_regen := 0.0
var _nature_t := 0.0
var difficulty := "normal"   # "normal" or "inferno" (Hell Mode)
var pagma_stage := 0         # Overgeared: 0 = nothing, 1 = quest for the tome, 2 = Pagma's Successor
var legend := {}             # forged legendary gear: {"legend_sword": {...}, "legend_armor": {...}}
var pagma_pity := 0          # forges since the last Legendary grade (raises the odds)
var immortal_at := -999.0    # play_time of the last "Vontade de Pagma" (cheating death)
const IMMORTAL_CD := 120.0
var factions := {}        # living world state (Factions.gd)
var chronicle: Array = [] # what happened in the world, newest last
var day_count := 0
var camp_seq := 0
var crafted := {}
var kills := {}
var opened_chests := {}
var broken := {}
var discovered := {}
var explored := PackedByteArray()
var boss_defeated := false
var rivals: Array = []   # see Rivals.gd: {uid, monster, name, level, region, wins, scars, next_at}
var rival_seq := 0
var quest_index := 0
var quest_progress := 0
var player_pos := Vector2.ZERO
var has_saved_pos := false
var world_version := WorldGen.VERSION
var play_time := 0.0
var day_time := 0.3  # 0..1, 0.25 = morning, 0.75 = night


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()


func _process(delta: float) -> void:
	if not get_tree().paused:
		play_time += delta
		var night := night_now()
		# Aura Sagrada / Harmonia (archetype passives): slow life regeneration
		var hp_rate := Archetypes.bonus("hp_regen") / 4.0
		if hp < max_hp and hp > 0 and hp_rate > 0.0:
			_hp_regen += hp_rate * delta
			if _hp_regen >= 1.0:
				heal(int(_hp_regen))
				_hp_regen -= int(_hp_regen)
		var nat := Archetypes.bonus("nature_regen")
		if nat > 0.0 and current_region != "vila":
			_nature_t += delta
			if _nature_t >= 5.0:
				_nature_t = 0.0
				if hp > 0:
					heal(int(nat))
				mp = mini(max_mp, mp + int(nat))
		if mp < max_mp:
			var mult := 1.0 + Archetypes.bonus("mp_regen") / 100.0
			if night and Archetypes.bonus("night_power") > 0.0:
				mult += 0.5
			_mp_regen += MP_REGEN * mult * delta
			if _mp_regen >= 1.0:
				var gain := int(_mp_regen)
				_mp_regen -= gain
				mp = min(max_mp, mp + gain)
				stats_changed.emit()


# ---------------------------------------------------------------- new game / stats
func new_game(seed_value: int = -1) -> void:
	world_seed = seed_value if seed_value >= 0 else randi() % 1000000
	level = 1
	xp = 0
	gold = 0
	potions = 2
	max_hp = 30
	hp = 30
	max_mp = 20
	mp = 20
	atk = 6
	defense = 0
	sword_tier = 0
	tool_tier = 0
	armor_tier = 0
	items = {}
	skills = []
	orb_skills = []
	skill_slots = ["", "", ""]
	archetypes = []
	arch_ranks = {}
	arch_bonus_points = 0
	copied = ""
	last_cast = ""
	difficulty = "normal"
	pagma_stage = 0
	legend = {}
	pagma_pity = 0
	immortal_at = -999.0
	factions = Factions.init_state()
	chronicle = []
	day_count = 0
	camp_seq = 0
	crafted = {}
	kills = {}
	opened_chests = {}
	broken = {}
	discovered = {}
	explored = PackedByteArray()
	explored.resize(WorldGen.W * WorldGen.H)
	boss_defeated = false
	rivals = []
	rival_seq = 0
	quest_index = 0
	quest_progress = 0
	has_saved_pos = false
	play_time = 0.0
	day_time = 0.3
	stats_changed.emit()
	quest_changed.emit()


func xp_to_next() -> int:
	return 20 + (level - 1) * 15 + (level - 1) * (level - 1) * 5


func inferno() -> bool:
	return difficulty == "inferno"


func is_pagma() -> bool:
	return pagma_stage >= 2


func attack_power() -> int:
	return atk + sword_tier * 3 + int(legend.get("legend_sword", {}).get("stat", 0)) + (2 if is_pagma() else 0) \
		+ int(Archetypes.bonus("atk"))


func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next():
		xp -= xp_to_next()
		_level_up()
	stats_changed.emit()


func _level_up() -> void:
	level += 1
	max_hp += 6
	max_mp += 4
	mp = max_mp
	atk += 2
	if level % 2 == 0:
		defense += 1
	hp = max_hp
	leveled_up.emit(level)
	message.emit("NÍVEL %d!  Vida, mana, ataque e defesa aumentaram" % level, Color(1.0, 0.85, 0.3))


func add_gold(amount: int) -> void:
	gold += amount
	stats_changed.emit()


func damage_player(raw: int) -> int:
	var dmg: int = max(1, raw - defense_total())
	if is_pagma() and hp - dmg <= 0 and play_time - immortal_at >= IMMORTAL_CD:
		# Vontade de Pagma (Overgeared): the Successor refuses to fall, once every two minutes
		immortal_at = play_time
		hp = 1
		message.emit("Vontade de Pagma! Você resistiu à morte.", Color(1.0, 0.85, 0.35))
		stats_changed.emit()
		return dmg
	hp = max(0, hp - dmg)
	stats_changed.emit()
	return dmg


func heal(amount: int) -> void:
	hp = min(max_hp, hp + amount)
	stats_changed.emit()


func has_skill(id: String) -> bool:
	return id in skills


func learn_skill(id: String) -> void:
	if not has_skill(id):
		skills.append(id)
		stats_changed.emit()


## Hero's fireball damage: grows with the sword and the level.
func skill_damage(id: String) -> int:
	match id:
		"fireball":
			return int(attack_power() * 1.4) + level * 2
	return attack_power()


## Spends mana for a skill; false (and nothing spent) when there is not enough.
func spend_mana(amount: int) -> bool:
	if mp < amount:
		return false
	mp -= amount
	stats_changed.emit()
	return true


var _drain := 0.0


func drain_heal(amount: float) -> void:
	if hp <= 0:
		return
	_drain += amount
	if _drain >= 1.0:
		heal(int(_drain))
		_drain -= int(_drain)


func restore_mana(amount: int) -> void:
	mp = min(max_mp, mp + amount)
	stats_changed.emit()


func use_potion() -> bool:
	if potions <= 0 or hp >= max_hp:
		return false
	potions -= 1
	heal(int((max_hp * 0.5 + 10) * (1.0 + Archetypes.bonus("potion_heal") / 100.0)))
	return true


func add_potion() -> bool:
	if potions >= MAX_POTIONS:
		return false
	potions += 1
	stats_changed.emit()
	return true


func register_craft(recipe_id: String) -> void:
	crafted[recipe_id] = int(crafted.get(recipe_id, 0)) + 1
	var q := current_quest()
	if not q.is_empty() and q["type"] == "craft" and recipe_id in q["target"]:
		quest_progress += 1
		_check_quest()


# ---------------------------------------------------------------- items
func add_item(id: String, n: int = 1) -> void:
	items[id] = int(items.get(id, 0)) + n
	items_changed.emit()
	var q := current_quest()
	if not q.is_empty() and q["type"] == "gather" and id in q["target"]:
		quest_progress += n
		_check_quest()


func count(id: String) -> int:
	return int(items.get(id, 0))


func has_items(cost: Dictionary) -> bool:
	for id in cost:
		if count(id) < int(cost[id]):
			return false
	return true


func remove_items(cost: Dictionary) -> void:
	for id in cost:
		items[id] = count(id) - int(cost[id])
		if items[id] <= 0:
			items.erase(id)
	items_changed.emit()


func sell(id: String, n: int = 1) -> int:
	n = min(n, count(id))
	if n <= 0:
		return 0
	remove_items({id: n})
	var g: int = int(ItemDB.ITEMS[id]["price"]) * n
	add_gold(g)
	return g


func defense_total() -> int:
	return defense + int(ItemDB.ARMOR_DEF.get(armor_tier, 0)) + int(legend.get("legend_armor", {}).get("stat", 0)) + int(Archetypes.bonus("def"))


## Set by Main every frame (night amount > 0.5) and the hero's region, for passives that need them.
var night_flag := false
var current_region := ""


func night_now() -> bool:
	return night_flag


## Class from the archetypes (Ravendawn style): "Paladino", "Necromante Caçador"...
func class_title() -> String:
	return Archetypes.class_name_of(archetypes)


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


# ---------------------------------------------------------------- rivals
func rival_by_uid(uid: int) -> Dictionary:
	for r in rivals:
		if int(r["uid"]) == uid:
			return r
	return {}


## A monster defeated the hero ("kill") or escaped badly hurt ("flee"). An existing rival grows
## stronger; otherwise a new one is born if there is room. Returns the rival, or {} if none.
func rival_event(monster_id: String, monster_level: int, region: String, kind: String, uid: int = -1) -> Dictionary:
	var r := rival_by_uid(uid)
	if r.is_empty():
		if rivals.size() >= Rivals.MAX or region == "" or region == "vila":
			return {}
		var taken: Array = []
		for o in rivals:
			taken.append(o["name"])
		rival_seq += 1
		r = {"uid": rival_seq, "monster": monster_id, "name": Rivals.make_name(monster_id, taken),
			"level": monster_level, "region": region, "wins": 0, "scars": 0}
		rivals.append(r)
	r["level"] = mini(int(r["level"]) + 1, Rivals.MAX_LEVEL)
	if kind == "kill":
		r["wins"] = int(r["wins"]) + 1
		Factions.gain_xp(Factions.of(monster_id), 10.0)   # the whole faction grows bolder
	else:
		r["scars"] = int(r["scars"]) + 1
	r["next_at"] = play_time + Rivals.RETURN_DELAY
	return r


## A rival ready to come back in this region (not on cooldown), or {}.
func rival_due(region: String) -> Dictionary:
	for r in rivals:
		if r["region"] == region and play_time >= float(r.get("next_at", 0.0)):
			return r
	return {}


func rival_seen(uid: int) -> void:
	var r := rival_by_uid(uid)
	if not r.is_empty():
		r["next_at"] = play_time + Rivals.SEEN_DELAY


func rival_defeated(uid: int) -> Dictionary:
	var r := rival_by_uid(uid)
	if not r.is_empty():
		rivals.erase(r)
	return r


# ---------------------------------------------------------------- save / load
func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func save_game() -> void:
	var cfg := ConfigFile.new()
	for key in ["world_seed", "level", "xp", "gold", "potions", "max_hp", "hp", "max_mp", "mp", "atk", "defense", "sword_tier",
			"tool_tier", "armor_tier", "items", "skills", "orb_skills", "skill_slots", "archetypes", "arch_ranks", "arch_bonus_points", "copied", "difficulty", "pagma_stage", "legend", "pagma_pity", "factions", "chronicle", "day_count", "camp_seq", "crafted",
			"kills", "opened_chests", "broken", "discovered", "explored", "boss_defeated", "rivals", "rival_seq", "quest_index", "quest_progress",
			"player_pos", "play_time", "day_time", "muted", "world_version", "immortal_at"]:
		cfg.set_value("save", key, get(key))
	cfg.save(save_path)


func load_game() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return false
	for key in cfg.get_section_keys("save"):
		set(key, cfg.get_value("save", key))
	hp = clampi(hp, 1, max_hp)
	if not cfg.has_section_key("save", "skills"):
		skills = []
	if not cfg.has_section_key("save", "skill_slots"):
		# before archetypes: the fireball came from the orb and takes the first button
		orb_skills = skills.duplicate()
		skill_slots = ["", "", ""]
		for i in mini(3, skills.size()):
			skill_slots[i] = skills[i]
		archetypes = []
		arch_ranks = {}
		arch_bonus_points = 0
	if not cfg.has_section_key("save", "difficulty"):
		difficulty = "normal"
		pagma_stage = 0
		legend = {}
		pagma_pity = 0
	if not cfg.has_section_key("save", "factions"):
		factions = Factions.init_state()   # saves from before the living world
		chronicle = []
		day_count = 0
		camp_seq = 0
	else:
		# factions added in later versions start fresh
		var fresh := Factions.init_state()
		for fid in fresh:
			if not factions.has(fid):
				factions[fid] = fresh[fid]
	if not cfg.has_section_key("save", "max_mp"):
		max_mp = 20 + 4 * (level - 1)   # saves from before mana existed
		mp = max_mp
	mp = clampi(mp, 0, max_mp)
	if explored.size() != WorldGen.W * WorldGen.H:
		explored = PackedByteArray()
		explored.resize(WorldGen.W * WorldGen.H)
	# a save from a smaller/older map: same hero and items, but back to the village
	has_saved_pos = cfg.get_value("save", "world_version", 1) == WorldGen.VERSION
	world_version = WorldGen.VERSION
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
		"inventory": [KEY_I, KEY_B],
		"skill": [KEY_F, KEY_1, KEY_L],
		"skill2": [KEY_G, KEY_2],
		"skill3": [KEY_V, KEY_3, KEY_C],
		"target": [KEY_T, KEY_R],
	}
	var pads := {
		"attack": JOY_BUTTON_A, "dash": JOY_BUTTON_B, "potion": JOY_BUTTON_X,
		"interact": JOY_BUTTON_Y, "pause": JOY_BUTTON_START, "map": JOY_BUTTON_BACK,
		"inventory": JOY_BUTTON_RIGHT_SHOULDER, "skill": JOY_BUTTON_LEFT_SHOULDER,
		"target": JOY_BUTTON_RIGHT_STICK,
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
