extends Node

signal score_changed(value: int)
signal game_ended
signal fever_started
signal level_up(level: int)
signal coin_tier_up(top_value: int)
const MODES := ["FÁCIL", "MÉDIO", "DIFÍCIL"]
# Per mode: starting fall speed and bomb spacing (higher = calmer).
const MODE_SPEED := [0.88, 1.0, 1.15]
const MODE_BOMB_GAP := [1.35, 1.0, 0.75]
# Every LEVEL_POINTS the run speeds up and bombs get denser.
const LEVEL_POINTS := 5000
const MAX_LEVEL := 6
const LEVEL_SPEED := 0.07
const LEVEL_BOMB_GAP := 0.9
# Keeps a coin step plus reaction time inside the shortest row interval.
const MAX_SPEED := 1.45
# Coin value at the x4 multiplier: 3+ fevers raise it to 75, 5+ to 100.
const COIN_TOP := [40, 75, 100]
# Shop: every collected coin adds 1 to the saved wallet. New upgrades only need an
# entry here plus whatever reads their level.
const UPGRADES := {
	"magnet": {"name": "ÍMÃ", "icon": "res://Assets/UI/icon_magnet.png", "prices": [60, 150, 300, 500, 800]},
	"fever": {"name": "FEBRE", "icon": "res://Assets/UI/icon_fever.png", "prices": [80, 180, 350, 600, 900]},
	"luck": {"name": "SORTE", "icon": "res://Assets/UI/icon_luck.png", "prices": [70, 160, 320, 550, 850]},
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
var upgrades: Dictionary = {"magnet": 0, "fever": 0, "luck": 0}
var magnet_left: float = 0.0
var banked: bool = false
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
	return MODE_BOMB_GAP[mode] * pow(LEVEL_BOMB_GAP, level)

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
	wallet -= price(id)
	upgrades[id] = upgrade_level(id) + 1
	save_progress()
	wallet_changed.emit(wallet)
	return true

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

## Moves this run's coins into the wallet once, when the run ends or is abandoned.
func bank_run() -> void:
	if banked or not started:
		return
	banked = true
	wallet += coins
	save_progress()
	wallet_changed.emit(wallet)

func coin_tier() -> int:
	if fever_count >= 5:
		return 2
	return 1 if fever_count >= 3 else 0

func coin_points() -> int:
	return roundi(COIN_TOP[coin_tier()] * multiplier / 4.0)

func _process(delta: float) -> void:
	if ended or not started:
		return
	elapsed += delta
	grace_left = maxf(0.0, grace_left - delta)
	magnet_left = maxf(0.0, magnet_left - delta)
	if fever_left > 0.0:
		fever_left = maxf(0.0, fever_left - delta)
		if fever_left == 0.0:
			grace_left = 0.6

func collect_coin() -> int:
	if ended or not started:
		return 0
	coins += 1
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
	var reached := mini(MAX_LEVEL, score / LEVEL_POINTS)
	if reached > level:
		level = reached
		level_up.emit(level)

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
	banked = false

func update_ui() -> void:
	score_changed.emit(score)




