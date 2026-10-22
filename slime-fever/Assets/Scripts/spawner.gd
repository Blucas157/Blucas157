extends Node2D

@export var moeda_scene: PackedScene
@export var bomba_scene: PackedScene
@export var run_seed: int = 0
const FALL_TIME := 1.7
const SPAWN_Y := 410.0
const PLAYER_Y := 1640.0
const ROW_INTERVAL := 0.72
const SAFE_MARGIN := 185.0
# Bomb rain: free x, own timing, own speed and optional drift, kept off the coin route.
const BOMB_MIN_X := 90.0
const BOMB_MAX_X := 990.0
const CONTACT_WINDOW := 0.45
# Rows spawn on the first frame after their timer, so queued landings can slip a little.
const TIMING_SLACK := 0.15
const MAX_CLUSTER := 3
const POWERUP_SCENE := preload("res://Assets/Cenas/ima.tscn")
const REFLECT_SCENE := preload("res://Assets/Cenas/bomba_brilhante.tscn")
# During a boss fight every REFLECT_EVERY-th route coin is a glowing bomb to throw back.
const REFLECT_EVERY := 4
const BOSS_BOMB_GAP := 0.85
# First power-up comes this many seconds after bombs start.
const FIRST_POWERUP := 6.0
var rng := RandomNumberGenerator.new()
var clock: float = 0.1
var pending: Array[Dictionary] = []
var last_x: float = 540.0
var last_pattern: String = ""
var pattern_count: int = 0
var current_pattern: String = "APRENDA A COLETAR"
var time: float = 0.0
var bomb_clock: float = 0.0
var burst_left: int = 0
var powerup_clock: float = FIRST_POWERUP
var boss_rows: int = 0
var arrivals: Array[Dictionary] = []
var bomb_arrivals: Array[Dictionary] = []
var dry_run: bool = false
var history: Array[Dictionary] = []
signal row_spawned(row: Dictionary)

func _ready() -> void:
	if run_seed == 0:
		rng.randomize()
		run_seed = int(rng.seed)
	else:
		rng.seed = run_seed

func _process(delta: float) -> void:
	if GameManager.ended or not GameManager.started:
		return
	step(delta)

func step(delta: float) -> void:
	time += delta
	clock -= delta
	if clock <= 0.0:
		# Never burst multiple rows after a slow frame: retain a readable interval.
		clock = spawn_item().interval
	if difficulty() > 0:
		powerup_clock -= delta
		if powerup_clock <= 0.0:
			_queue_powerup()
	bomb_clock -= delta
	if bomb_clock <= 0.0:
		bomb_clock = _next_bomb_gap() * GameManager.bomb_gap_scale() * (BOSS_BOMB_GAP if GameManager.boss_active else 1.0)
		_drop_bomb()

func reset_hazards() -> void:
	time = 0.0
	bomb_clock = 0.0
	burst_left = 0
	powerup_clock = FIRST_POWERUP
	boss_rows = 0
	arrivals.clear()
	bomb_arrivals.clear()
	history.clear()

func difficulty() -> int:
	if GameManager.elapsed > 45.0:
		return 2
	return 1 if GameManager.elapsed > 8.0 else 0

## 0 when bombs start, 1 about 80 s later.
func pace() -> float:
	return clampf((GameManager.elapsed - 8.0) / 80.0, 0.0, 1.0)

func build_pattern(kind: String, start_x: float) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var path: Array[float] = []
	var at := start_x
	var mirror := -1.0 if rng.randf() < 0.5 else 1.0
	for i in 7:
		var desired := 540.0
		match kind:
			"ARCO":
				desired = 540.0 + mirror * sin(float(i) / 6.0 * PI) * 360.0
			"ZIGUE-ZAGUE":
				desired = 540.0 + mirror * [0.0, 180.0, 360.0, 180.0, 0.0, -180.0, 0.0][i]
			"CORREDOR":
				desired = 540.0 + mirror * 180.0
			"TROCA DE LADO":
				desired = (180.0 if i < 3 else 900.0) if mirror > 0 else (900.0 if i < 3 else 180.0)
			"CHUVA CALMA":
				desired = start_x
		at = clampf(move_toward(at, desired, 180.0), 180.0, 900.0)
		path.append(at)
	for i in path.size():
		var previous := start_x if i == 0 else path[i - 1]
		var next := path[i] if i == path.size() - 1 else path[i + 1]
		rows.append({"coin_x": path[i], "pattern": kind, "previous_x": previous, "next_x": next})
	# Recovery window keeps the last reachable target before the next pattern.
	for i in 2:
		rows.append({"coin_x": path[-1], "pattern": "RESPIRO", "previous_x": path[-1], "next_x": path[-1]})
	# Speed is fixed per pattern, so queued landing times stay exact for the bomb check.
	var speed := GameManager.speed_scale()
	for row in rows:
		row.fall = FALL_TIME / speed
		row.interval = ROW_INTERVAL / speed
	return rows

func _plan() -> void:
	var kind := "CHUVA CALMA"
	if GameManager.elapsed > 8.0:
		var options := ["ARCO", "ZIGUE-ZAGUE", "CORREDOR", "TROCA DE LADO"]
		options.erase(last_pattern)
		kind = options[rng.randi_range(0, options.size() - 1)]
	# Patterns are queued ahead so bombs can see where future coins will land.
	var start_x: float = pending[-1].coin_x if not pending.is_empty() else last_x
	pending.append_array(build_pattern(kind, start_x))
	last_pattern = kind
	pattern_count += 1

func spawn_item() -> Dictionary:
	if pending.is_empty():
		_plan()
	var row: Dictionary = pending.pop_front()
	current_pattern = row.pattern
	last_x = row.coin_x
	arrivals.append({"arrive": time + row.fall, "coin_x": row.coin_x})
	var scene := moeda_scene
	if row.get("powerup", "") != "":
		scene = POWERUP_SCENE
	elif GameManager.boss_active:
		# Rides the coin route, so a throwable bomb is always reachable and bomb-free.
		boss_rows += 1
		if boss_rows % REFLECT_EVERY == 0:
			scene = REFLECT_SCENE
	_spawn(scene, row.coin_x, false, row.fall)
	row_spawned.emit(row)
	return row

## Coins already falling plus the queued ones, in order, with landing times and the
## horizontal stretch the player may cover between the previous and next coin.
func coin_windows(horizon: float) -> Array[Dictionary]:
	while pending.size() < int(ceil(horizon * GameManager.MAX_SPEED / ROW_INTERVAL)) + 2:
		_plan()
	arrivals.assign(arrivals.filter(func(w): return w.arrive > time - 1.0))
	var line: Array[Dictionary] = arrivals.duplicate()
	var spawn_at := time + clock
	for row in pending:
		line.append({"arrive": spawn_at + row.fall, "coin_x": row.coin_x})
		spawn_at += row.interval
	var list: Array[Dictionary] = []
	for i in line.size():
		var x: float = line[i].coin_x
		var previous: float = line[i - 1].coin_x if i > 0 else x
		var next: float = line[i + 1].coin_x if i + 1 < line.size() else x
		list.append({"arrive": line[i].arrive, "low": minf(previous, minf(x, next)), "high": maxf(previous, maxf(x, next))})
	return list

## Swaps a queued coin for a power-up: it rides the coin route, so bombs never cover it.
func _queue_powerup() -> void:
	if GameManager.magnet_left > 0.0:
		powerup_clock = 3.0
		return
	powerup_clock = GameManager.powerup_gap() * rng.randf_range(0.8, 1.2)
	while pending.size() < 4:
		_plan()
	pending[3].powerup = "magnet"

func _next_bomb_gap() -> float:
	if burst_left > 0:
		burst_left -= 1
		return rng.randf_range(0.08, 0.2)
	var p := pace()
	if difficulty() > 0 and rng.randf() < 0.1 + 0.15 * p:
		burst_left = rng.randi_range(1, 2)
	return rng.randf_range(lerpf(0.55, 0.3, p), lerpf(1.3, 0.7, p))

## Random bomb that never lands on the coin route; empty when nothing fair fits.
func pick_bomb() -> Dictionary:
	var p := pace()
	var speed := GameManager.speed_scale()
	var windows := coin_windows(2.6)
	bomb_arrivals.assign(bomb_arrivals.filter(func(b): return b.arrive > time))
	for attempt in 10:
		var fall := rng.randf_range(lerpf(1.6, 1.25, p), lerpf(2.5, 1.9, p)) / speed
		var drift := 0.0 if rng.randf() < 0.5 else rng.randf_range(-110.0, 110.0)
		var land := rng.randf_range(BOMB_MIN_X, BOMB_MAX_X)
		var start := clampf(land - drift * fall, BOMB_MIN_X, BOMB_MAX_X)
		land = start + drift * fall
		if is_clear(land, drift, time + fall, windows):
			return {"start_x": start, "land_x": land, "drift": drift, "fall": fall, "arrive": time + fall}
	return {}

func is_clear(land: float, drift: float, arrive: float, windows: Array) -> bool:
	if land < BOMB_MIN_X or land > BOMB_MAX_X:
		return false
	# Drift moves the bomb while it crosses the player's row.
	var window := CONTACT_WINDOW + TIMING_SLACK
	var spread := absf(drift) * window
	for w in windows:
		if absf(w.arrive - arrive) <= window and land + spread >= w.low - SAFE_MARGIN and land - spread <= w.high + SAFE_MARGIN:
			return false
	var cluster := 0
	for b in bomb_arrivals:
		if absf(b.arrive - arrive) < 0.3:
			cluster += 1
	return cluster < MAX_CLUSTER

func _drop_bomb() -> void:
	if difficulty() == 0:
		return
	var bomb := pick_bomb()
	if bomb.is_empty():
		return
	bomb_arrivals.append(bomb)
	_spawn(bomba_scene, bomb.start_x, true, bomb.fall, bomb.drift)

func _spawn(scene: PackedScene, x: float, bomb: bool, fall: float = FALL_TIME, drift: float = 0.0) -> void:
	if dry_run:
		history.append({"bomb": bomb, "powerup": scene == POWERUP_SCENE, "reflect": scene == REFLECT_SCENE, "x": x, "fall": fall, "drift": drift, "time": time})
		return
	if not scene:
		return
	var item := scene.instantiate() as Area2D
	item.process_mode = Node.PROCESS_MODE_PAUSABLE
	item.position = Vector2(x, SPAWN_Y)
	# Coins share one travel time so rows never overtake; bombs bring their own.
	item.min_speed = (PLAYER_Y - SPAWN_Y) / fall
	item.max_speed = item.min_speed
	item.drift = drift
	get_parent().add_child(item)
	if bomb:
		get_tree().current_scene.warn_bomb(x)


