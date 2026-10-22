extends Node

signal score_changed(value: int)
signal game_ended
signal fever_started
signal level_up(level: int)
signal boss_started(index: int)
signal boss_hit(hp: int)
signal boss_defeated(chest: int, ability: String)
signal boss_escaped
signal revived
signal coin_tier_up(top_value: int)
const MODES := ["FÁCIL", "MÉDIO", "DIFÍCIL"]
# Per mode: starting fall speed and bomb spacing (higher = calmer).
const MODE_SPEED := [0.88, 1.0, 1.15]
const MODE_BOMB_GAP := [1.35, 1.0, 0.75]
# Every LEVEL_POINTS the run speeds up and bombs get denser, with no level cap;
# MAX_SPEED and MIN_BOMB_GAP keep later levels fair.
const LEVEL_POINTS := 1000
const LEVEL_SPEED := 0.06
const LEVEL_BOMB_GAP := 0.94
const MIN_BOMB_GAP := 0.5
# A mini boss arrives every BOSS_EVERY levels. Beating it moves the run to the next zone.
const BOSS_EVERY := 5
const BOSS_TIME := 45.0
const BOSSES := [
	{"name": "TOUPEIRA BOMBARDEIRA", "art": "res://Assets/Boss/boss1.png", "ability": "revive"},
	{"name": "GOLEM DE CRISTAL", "art": "res://Assets/Boss/boss2.png", "ability": "auto_magnet"},
	{"name": "REI SLIME", "art": "res://Assets/Boss/boss3.png", "ability": "golden_fever"},
]
const ZONES := [
	{"name": "CAVERNA AZUL", "hue": 0.0, "sat": 1.0},
	{"name": "GRUTA DE CRISTAL", "hue": -0.17, "sat": 1.25},
	{"name": "COVIL DO REI", "hue": 0.38, "sat": 1.2},
]
# Unlocked forever the first time their boss falls.
const ABILITIES := {
	"revive": {"name": "SEGUNDA CHANCE", "icon": "res://Assets/UI/icon_shield.png", "info": "1 vez por partida, sobrevive a uma bomba"},
	"auto_magnet": {"name": "ÍMÃ AUTOMÁTICO", "icon": "res://Assets/UI/icon_magnet.png", "info": "Liga o ímã sozinho a cada 40 s"},
	"golden_fever": {"name": "FEBRE DOURADA", "icon": "res://Assets/UI/icon_fever.png", "info": "Na febre, moedas valem o dobro"},
}
const AUTO_MAGNET_GAP := 40.0
# Keeps a coin step plus reaction time inside the shortest row interval.
const MAX_SPEED := 1.45
# Coin value at the x4 multiplier: 3+ fevers raise it to 75, 5+ to 100.
const COIN_TOP := [40, 75, 100]
# Shop: every collected coin adds 1 to the saved wallet the moment it is caught.
# New entries only need a line here plus whatever reads them.
# Permanent upgrades, 5 levels each.
const UPGRADES := {
	"magnet": {"name": "ÍMÃ", "icon": "res://Assets/UI/icon_magnet.png", "prices": [60, 150, 300, 500, 800]},
	"fever": {"name": "FEBRE", "icon": "res://Assets/UI/icon_fever.png", "prices": [80, 180, 350, 600, 900]},
	"luck": {"name": "SORTE", "icon": "res://Assets/UI/icon_luck.png", "prices": [70, 160, 320, 550, 850]},
	"reach": {"name": "ALCANCE", "icon": "res://Assets/UI/icon_reach.png", "prices": [50, 120, 250, 450, 700]},
	"speed": {"name": "AGILIDADE", "icon": "res://Assets/UI/icon_speed.png", "prices": [60, 140, 280, 480, 750]},
}
# Bought in the menu shop, used up automatically when the next run starts.
const ITEMS := {
	"start_shield": {"name": "ESCUDO INICIAL", "icon": "res://Assets/UI/icon_shield.png", "price": 60, "max": 3, "info": "Começa com escudo"},
	"start_magnet": {"name": "ÍMÃ INICIAL", "icon": "res://Assets/UI/icon_magnet.png", "price": 40, "max": 3, "info": "Começa com ímã ligado"},
}
# Mini-shop offered at each level-up; effects apply right away.
const RUN_ITEMS := {
	"shield": {"name": "ESCUDO", "icon": "res://Assets/UI/icon_shield.png", "price": 40, "info": "Aguenta 1 bomba"},
	"magnet_now": {"name": "ÍMÃ AGORA", "icon": "res://Assets/UI/icon_magnet.png", "price": 25, "info": "Liga o ímã"},
	"double": {"name": "MOEDAS x2", "icon": "res://Assets/UI/icon_double.png", "price": 35, "info": "20 s de moedas em dobro"},
}
const DOUBLE_TIME := 20.0
# Slime colours: hue shift applied to the green sprite. Bought once, equipped any time.
const SKINS := {
	"verde": {"name": "VERDE", "hue": 0.0, "price": 0},
	"azul": {"name": "AZUL", "hue": 0.3, "price": 150},
	"roxo": {"name": "ROXO", "hue": 0.47, "price": 250},
	"rosa": {"name": "ROSA", "hue": 0.62, "price": 300},
	"ouro": {"name": "OURO", "hue": 0.84, "price": 500},
}
const BASE_FEVER := 6.0
const BASE_MAGNET := 5.0
const BASE_POWERUP_GAP := 22.0
signal powerup_collected(kind: String)
signal wallet_changed(value: int)
var score: int = 0
var ended: bool = false
var started: bool = false
var best_combo: int = 0
var fever_count: int = 0
var save_ok: bool = true
var combo: int = 0
var multiplier: int = 1
var charge: float = 0.0
var fever_left: float = 0.0
var grace_left: float = 0.0
var elapsed: float = 0.0
var best: int = 0
var bests: Array[int] = [0, 0, 0]
var mode: int = 1
var level: int = 0
var wallet: int = 0
var upgrades: Dictionary = {}
var items: Dictionary = {}
var skins_owned: Array = ["verde"]
var skin: String = "verde"
var magnet_left: float = 0.0
var double_left: float = 0.0
var shield: int = 0
# Coins added to the wallet during this run (doubled ones count twice).
var earned: int = 0
var abilities: Array = []
var best_zone: int = 0
# Run progress through zones and bosses.
var zone: int = 0
var boss_active: bool = false
var boss_index: int = 0
var boss_hp: int = 0
var boss_max: int = 0
var boss_left: float = 0.0
var revive_used: bool = false
var auto_magnet_clock: float = AUTO_MAGNET_GAP
var coins: int = 0
var muted: bool = false
var save_path: String = "user://slime.cfg"

func _ready() -> void:
	var save := ConfigFile.new()
	if save.load(save_path) == OK:
		# Records from before difficulty modes count as MÉDIO.
		var legacy := maxi(0, int(save.get_value("progress", "best", 0)))
		for i in MODES.size():
			bests[i] = maxi(0, int(save.get_value("progress", "best_%d" % i, legacy if i == 1 else 0)))
		muted = bool(save.get_value("settings", "muted", false))
		mode = clampi(int(save.get_value("settings", "mode", 1)), 0, MODES.size() - 1)
		wallet = maxi(0, int(save.get_value("progress", "wallet", 0)))
		for id in UPGRADES:
			upgrades[id] = clampi(int(save.get_value("upgrades", id, 0)), 0, UPGRADES[id].prices.size())
		for id in ITEMS:
			items[id] = clampi(int(save.get_value("items", id, 0)), 0, ITEMS[id].max)
		for id in save.get_value("skins", "owned", ["verde"]):
			if SKINS.has(id) and not skins_owned.has(id):
				skins_owned.append(id)
		for id in save.get_value("abilities", "unlocked", []):
			if ABILITIES.has(id) and not abilities.has(id):
				abilities.append(id)
		best_zone = maxi(0, int(save.get_value("progress", "best_zone", 0)))
		var worn: String = save.get_value("skins", "equipped", "verde")
		skin = worn if skins_owned.has(worn) else "verde"
	best = bests[mode]

func set_mode(value: int) -> void:
	if started and not ended:
		return
	mode = clampi(value, 0, MODES.size() - 1)
	best = bests[mode]
	save_progress()

func mode_name() -> String:
	return MODES[mode]

func speed_scale() -> float:
	return minf(MAX_SPEED, MODE_SPEED[mode] * (1.0 + LEVEL_SPEED * level))

func bomb_gap_scale() -> float:
	return MODE_BOMB_GAP[mode] * maxf(MIN_BOMB_GAP, pow(LEVEL_BOMB_GAP, level))

func has_ability(id: String) -> bool:
	return abilities.has(id)

func zone_info(z: int = -1) -> Dictionary:
	return ZONES[(zone if z < 0 else z) % ZONES.size()]

func zone_name(z: int = -1) -> String:
	var at := zone if z < 0 else z
	var info := zone_info(at)
	# Zones repeat with a lap number after the last one.
	var lap := at / ZONES.size()
	return info.name if lap == 0 else "%s %d" % [info.name, lap + 1]

## Each zone makes coins worth more, in points and in the wallet.
func zone_bonus() -> float:
	return 1.0 + 0.5 * zone

func start_boss() -> void:
	if boss_active or ended or not started:
		return
	boss_active = true
	boss_index = zone % BOSSES.size()
	boss_max = 4 + 2 * zone
	boss_hp = boss_max
	boss_left = BOSS_TIME
	boss_started.emit(boss_index)

## A thrown-back bomb lands on the boss.
func hit_boss() -> void:
	if not boss_active or ended:
		return
	boss_hp -= 1
	boss_hit.emit(boss_hp)
	if boss_hp <= 0:
		_defeat_boss()

func _defeat_boss() -> void:
	boss_active = false
	var chest := 60 * (zone + 1)
	wallet += chest
	earned += chest
	var ability: String = BOSSES[boss_index].ability
	if has_ability(ability):
		ability = ""
	else:
		abilities.append(ability)
	zone += 1
	best_zone = maxi(best_zone, zone)
	save_progress()
	wallet_changed.emit(wallet)
	boss_defeated.emit(chest, ability)

## SEGUNDA CHANCE: the first lethal bomb of a run is survived.
func use_revive() -> bool:
	if not has_ability("revive") or revive_used:
		return false
	revive_used = true
	grace_left = 2.0
	revived.emit()
	return true

func upgrade_level(id: String) -> int:
	return upgrades.get(id, 0)

func max_level(id: String) -> int:
	return UPGRADES[id].prices.size()

## Price of the next level, or -1 when maxed.
func price(id: String) -> int:
	var lv := upgrade_level(id)
	return UPGRADES[id].prices[lv] if lv < max_level(id) else -1

func can_buy(id: String) -> bool:
	var cost := price(id)
	return cost >= 0 and wallet >= cost

func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	_spend(price(id))
	upgrades[id] = upgrade_level(id) + 1
	save_progress()
	return true

func _spend(amount: int) -> void:
	wallet -= amount
	wallet_changed.emit(wallet)

func item_count(id: String) -> int:
	return items.get(id, 0)

func can_buy_item(id: String) -> bool:
	return item_count(id) < ITEMS[id].max and wallet >= ITEMS[id].price

func buy_item(id: String) -> bool:
	if not can_buy_item(id):
		return false
	_spend(ITEMS[id].price)
	items[id] = item_count(id) + 1
	save_progress()
	return true

## Uses one of each stocked start item; returns the ids that were used.
func apply_start_items() -> Array:
	var used := []
	if item_count("start_shield") > 0:
		items["start_shield"] -= 1
		shield = 1
		used.append("start_shield")
	if item_count("start_magnet") > 0:
		items["start_magnet"] -= 1
		magnet_left = magnet_duration()
		used.append("start_magnet")
	if not used.is_empty():
		save_progress()
	return used

func can_buy_run_item(id: String) -> bool:
	if not started or ended or wallet < RUN_ITEMS[id].price:
		return false
	match id:
		"shield":
			return shield == 0
		"magnet_now":
			return magnet_left <= 0.0
		"double":
			return double_left <= 0.0
	return true

func buy_run_item(id: String) -> bool:
	if not can_buy_run_item(id):
		return false
	_spend(RUN_ITEMS[id].price)
	match id:
		"shield":
			shield = 1
		"magnet_now":
			magnet_left = magnet_duration()
		"double":
			double_left = DOUBLE_TIME
	save_progress()
	return true

## A shield absorbs one bomb; returns false when there is none.
func use_shield() -> bool:
	if shield <= 0:
		return false
	shield -= 1
	grace_left = 1.0
	return true

func cheapest_run_item() -> int:
	var low := 1 << 30
	for id in RUN_ITEMS:
		low = mini(low, RUN_ITEMS[id].price)
	return low

func owns_skin(id: String) -> bool:
	return skins_owned.has(id)

func buy_skin(id: String) -> bool:
	if owns_skin(id) or wallet < SKINS[id].price:
		return false
	_spend(SKINS[id].price)
	skins_owned.append(id)
	skin = id
	save_progress()
	return true

func equip_skin(id: String) -> void:
	if owns_skin(id):
		skin = id
		save_progress()

func skin_hue() -> float:
	return SKINS[skin].hue

## Coin pickup radius multiplier.
func reach_scale(lv: int = -1) -> float:
	return 1.0 + 0.15 * (upgrade_level("reach") if lv < 0 else lv)

func speed_bonus(lv: int = -1) -> float:
	return 1.0 + 0.05 * (upgrade_level("speed") if lv < 0 else lv)

func fever_duration(lv: int = -1) -> float:
	return BASE_FEVER + 0.8 * (upgrade_level("fever") if lv < 0 else lv)

func magnet_duration(lv: int = -1) -> float:
	return BASE_MAGNET + 1.5 * (upgrade_level("magnet") if lv < 0 else lv)

## Horizontal reach of the pull, in game pixels.
func magnet_radius(lv: int = -1) -> float:
	return 240.0 + 45.0 * (upgrade_level("magnet") if lv < 0 else lv)

## Seconds between power-ups on the coin route.
func powerup_gap(lv: int = -1) -> float:
	return BASE_POWERUP_GAP * pow(0.84, upgrade_level("luck") if lv < 0 else lv)

func collect_powerup(kind: String) -> void:
	if ended or not started:
		return
	if kind == "magnet":
		magnet_left = magnet_duration()
	powerup_collected.emit(kind)

## Coins reach the wallet as they are caught; this stores them when a run ends or is left.
func bank_run() -> void:
	if started:
		save_progress()

func coin_tier() -> int:
	if fever_count >= 5:
		return 2
	return 1 if fever_count >= 3 else 0

func coin_points() -> int:
	return roundi(COIN_TOP[coin_tier()] * multiplier / 4.0 * zone_bonus())

func _process(delta: float) -> void:
	if ended or not started:
		return
	elapsed += delta
	grace_left = maxf(0.0, grace_left - delta)
	magnet_left = maxf(0.0, magnet_left - delta)
	double_left = maxf(0.0, double_left - delta)
	if has_ability("auto_magnet"):
		auto_magnet_clock -= delta
		if auto_magnet_clock <= 0.0:
			auto_magnet_clock = AUTO_MAGNET_GAP
			magnet_left = maxf(magnet_left, magnet_duration())
			powerup_collected.emit("magnet")
	if boss_active:
		boss_left = maxf(0.0, boss_left - delta)
		if boss_left == 0.0:
			boss_active = false
			boss_escaped.emit()
	if fever_left > 0.0:
		fever_left = maxf(0.0, fever_left - delta)
		if fever_left == 0.0:
			grace_left = 0.6

func collect_coin() -> int:
	if ended or not started:
		return 0
	coins += 1
	var gain := (2 if double_left > 0.0 else 1) * (1 + zone)
	if fever_left > 0.0 and has_ability("golden_fever"):
		gain *= 2
	earned += gain
	wallet += gain
	wallet_changed.emit(wallet)
	combo += 1
	best_combo = maxi(best_combo, combo)
	multiplier = mini(4, 1 + combo / 5)
	var points := coin_points()
	add_score(points)
	if fever_left <= 0.0:
		charge = minf(100.0, charge + 5.0)
		if charge >= 100.0:
			charge = 0.0
			fever_left = fever_duration()
			var tier := coin_tier()
			fever_count += 1
			fever_started.emit()
			if coin_tier() > tier:
				coin_tier_up.emit(COIN_TOP[coin_tier()])
	return points

func miss_coin() -> void:
	if started and not ended and fever_left <= 0.0:
		combo = 0
		multiplier = 1

func add_score(amount: int) -> void:
	if ended or not started:
		return
	score += amount
	score_changed.emit(score)
	var reached := score / LEVEL_POINTS
	if reached > level:
		level = reached
		level_up.emit(level)
		# The HUD shows level + 1, so bosses arrive on NV 5, 10, 15...
		if (level + 1) % BOSS_EVERY == 0:
			start_boss()

func end_game() -> void:
	if ended or not started:
		return
	ended = true
	best = maxi(best, score)
	bests[mode] = best
	bank_run()
	save_progress()
	game_ended.emit()

func save_progress() -> void:
	var save := ConfigFile.new()
	for i in MODES.size():
		save.set_value("progress", "best_%d" % i, bests[i])
	save.set_value("settings", "muted", muted)
	save.set_value("settings", "mode", mode)
	save.set_value("progress", "wallet", wallet)
	for id in UPGRADES:
		save.set_value("upgrades", id, upgrade_level(id))
	for id in ITEMS:
		save.set_value("items", id, item_count(id))
	save.set_value("skins", "owned", skins_owned)
	save.set_value("skins", "equipped", skin)
	save.set_value("abilities", "unlocked", abilities)
	save.set_value("progress", "best_zone", best_zone)
	save_ok = save.save(save_path) == OK

func reset_game() -> void:
	started = false
	best_combo = 0
	fever_count = 0
	score = 0
	ended = false
	combo = 0
	multiplier = 1
	charge = 0.0
	fever_left = 0.0
	grace_left = 0.0
	elapsed = 0.0
	coins = 0
	level = 0
	magnet_left = 0.0
	double_left = 0.0
	shield = 0
	earned = 0
	zone = 0
	boss_active = false
	boss_hp = 0
	boss_left = 0.0
	revive_used = false
	auto_magnet_clock = AUTO_MAGNET_GAP

func update_ui() -> void:
	score_changed.emit(score)




