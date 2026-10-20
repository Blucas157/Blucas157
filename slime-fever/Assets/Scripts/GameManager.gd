extends Node

signal score_changed(value: int)
signal game_ended
signal fever_started
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
var coins: int = 0
var muted: bool = false
var save_path: String = "user://slime.cfg"

func _ready() -> void:
	var save := ConfigFile.new()
	if save.load(save_path) == OK:
		best = maxi(0, int(save.get_value("progress", "best", 0)))
		muted = bool(save.get_value("settings", "muted", false))

func _process(delta: float) -> void:
	if ended or not started:
		return
	elapsed += delta
	grace_left = maxf(0.0, grace_left - delta)
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
	var points := 10 * multiplier
	add_score(points)
	if fever_left <= 0.0:
		charge = minf(100.0, charge + 5.0)
		if charge >= 100.0:
			charge = 0.0
			fever_left = 6.0
			fever_count += 1
			fever_started.emit()
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

func end_game() -> void:
	if ended or not started:
		return
	ended = true
	best = maxi(best, score)
	save_progress()
	game_ended.emit()

func save_progress() -> void:
	var save := ConfigFile.new()
	save.set_value("progress", "best", best)
	save.set_value("settings", "muted", muted)
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

func update_ui() -> void:
	score_changed.emit(score)




