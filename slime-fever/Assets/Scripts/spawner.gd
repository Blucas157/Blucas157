extends Node2D

@export var moeda_scene: PackedScene
@export var bomba_scene: PackedScene
@export var run_seed: int = 0
const LANES := [180.0, 360.0, 540.0, 720.0, 900.0]
const FALL_TIME := 1.7
const SPAWN_Y := 410.0
const PLAYER_Y := 1640.0
const ROW_INTERVAL := 0.72
const SAFE_MARGIN := 185.0
var rng := RandomNumberGenerator.new()
var clock: float = 0.1
var pending: Array[Dictionary] = []
var last_x: float = 540.0
var last_pattern: String = ""
var pattern_count: int = 0
var current_pattern: String = "APRENDA A COLETAR"
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
	clock -= delta
	if clock <= 0.0:
		# Never burst multiple rows after a slow frame: retain a readable interval.
		clock = ROW_INTERVAL
		spawn_item()

func build_pattern(kind: String, start_x: float, difficulty: int) -> Array[Dictionary]:
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
		var low := minf(previous, minf(path[i], next))
		var high := maxf(previous, maxf(path[i], next))
		var bombs: Array[float] = []
		# First/last rows protect the seam with the neighboring pattern.
		if difficulty > 0 and kind != "CHUVA CALMA" and i > 0 and i < 6:
			var candidates: Array[float] = []
			for lane in LANES:
				if lane < low - SAFE_MARGIN or lane > high + SAFE_MARGIN:
					candidates.append(lane)
			if not candidates.is_empty():
				var pick := rng.randi_range(0, candidates.size() - 1)
				bombs.append(candidates[pick])
				if difficulty >= 2 and kind == "CORREDOR" and candidates.size() > 1:
					bombs.append(candidates[(pick + 1) % candidates.size()])
		rows.append({"coin_x": path[i], "bombs": bombs, "pattern": kind, "previous_x": previous, "next_x": next})
	# Recovery window preserves the last reachable target, without bombs.
	for i in 2:
		rows.append({"coin_x": path[-1], "bombs": [], "pattern": "RESPIRO", "previous_x": path[-1], "next_x": path[-1]})
	return rows

func _plan() -> void:
	var kind := "CHUVA CALMA"
	var difficulty := 0
	if GameManager.elapsed > 8.0:
		difficulty = 2 if GameManager.elapsed > 45.0 else 1
		var options := ["ARCO", "ZIGUE-ZAGUE", "CORREDOR", "TROCA DE LADO"]
		options.erase(last_pattern)
		kind = options[rng.randi_range(0, options.size() - 1)]
	pending = build_pattern(kind, last_x, difficulty)
	last_pattern = kind
	pattern_count += 1

func spawn_item() -> void:
	if pending.is_empty():
		_plan()
	var row: Dictionary = pending.pop_front()
	current_pattern = row.pattern
	last_x = row.coin_x
	_spawn(moeda_scene, row.coin_x, false)
	for x in row.bombs:
		_spawn(bomba_scene, x, true)
	row_spawned.emit(row)

func _spawn(scene: PackedScene, x: float, bomb: bool) -> void:
	if not scene:
		return
	var item := scene.instantiate() as Area2D
	item.process_mode = Node.PROCESS_MODE_PAUSABLE
	item.position = Vector2(x, SPAWN_Y)
	# Every row shares one travel time: faster later rows cannot overtake earlier ones.
	item.min_speed = (PLAYER_Y - SPAWN_Y) / FALL_TIME
	item.max_speed = item.min_speed
	get_parent().add_child(item)
	if bomb:
		get_tree().current_scene.warn_bomb(x)


