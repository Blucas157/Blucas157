class_name WorldGen
## Deterministic open-world generator. Produces plain data that World.gd turns into nodes.

const W := 200
const H := 200
const CENTER := Vector2i(100, 100)

enum T { GRASS, DIRT, WATER, ROCK }

const REGION_NAMES := {
	"vila": "Vila do Bosque",
	"prado": "Prado Verdejante",
	"floresta": "Floresta Sombria",
	"ruinas": "Ruínas Antigas",
	"pedreira": "Pedreira Rochosa",
	"pantano": "Pântano dos Lírios",
	"coracao": "Coração da Floresta",
}

const POIS := {
	"ruinas": Vector2i(100, 30),
	"coracao": Vector2i(172, 100),
	"pedreira": Vector2i(30, 100),
	"pantano": Vector2i(100, 168),
}

var seed_value := 0
var rng := RandomNumberGenerator.new()
var terrain := PackedByteArray()
var blocked := PackedByteArray()   # 1 = solid (water, rock, cliff, walls, fences, objects)
var reserved := PackedByteArray()  # 1 = keep free of objects (paths, plaza, arena)
var cliffs: Array[Rect2i] = []
var ponds: Array[Rect2i] = []
var ruins: Array[Rect2i] = []
var pillars: Array[Vector2i] = []
var fences: Array[Vector2i] = []
var objects: Array = []   # {type, cell}
var chests: Array = []    # {id, cell, tier}
var resources: Array = [] # {type, cell}
var npcs: Array = []      # {type, cell, station, station_cell}
var islands: Array[Vector2i] = []
var lilies: Array = []    # [cell, atlas coords, source]
var decor: Dictionary = {} # cell -> atlas coords in decor_16x16
var noise := FastNoiseLite.new()
var warp := FastNoiseLite.new()
var boss_cell := Vector2i(172, 100)


func generate(s: int) -> void:
	seed_value = s
	rng.seed = s
	noise.seed = s
	noise.frequency = 0.06
	warp.seed = s + 17
	warp.frequency = 0.02
	terrain.resize(W * H)
	terrain.fill(T.GRASS)
	blocked.resize(W * H)
	blocked.fill(0)
	reserved.resize(W * H)
	reserved.fill(0)
	_border()
	_village()
	_paths()
	_boss_arena()
	_quarry_rocks()
	_dirt_patches()
	_cleanup_autotile(T.DIRT)
	_cleanup_autotile(T.ROCK)
	_ponds()
	_cliffs()
	_ruins()
	_objects()
	_resources()
	_chests()
	_decor()


# ---------------------------------------------------------------- helpers
func idx(c: Vector2i) -> int:
	return c.y * W + c.x


func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < W and c.y < H


func t_at(c: Vector2i) -> int:
	if not inside(c):
		return T.ROCK
	return terrain[idx(c)]


func set_t(c: Vector2i, v: int) -> void:
	if inside(c):
		terrain[idx(c)] = v


func is_blocked(c: Vector2i) -> bool:
	if not inside(c):
		return true
	return blocked[idx(c)] == 1 or terrain[idx(c)] == T.WATER or terrain[idx(c)] == T.ROCK


func walkable(c: Vector2i) -> bool:
	return inside(c) and not is_blocked(c)


func region_at(c: Vector2i) -> String:
	var d := Vector2(c - CENTER).length()
	if d < 13.0:
		return "vila"
	if Vector2(c - boss_cell).length() < 13.0:
		return "coracao"
	if d < 40.0 + warp.get_noise_2d(c.x, c.y) * 8.0:
		return "prado"
	var a := atan2(float(c.y - CENTER.y), float(c.x - CENTER.x)) + warp.get_noise_2d(c.x * 2.0, c.y * 2.0) * 0.5
	if a > -PI / 4.0 and a <= PI / 4.0:
		return "floresta"
	if a > PI / 4.0 and a <= 3.0 * PI / 4.0:
		return "pantano"
	if a > -3.0 * PI / 4.0 and a <= -PI / 4.0:
		return "ruinas"
	return "pedreira"


func level_at(c: Vector2i) -> int:
	var d := Vector2(c - CENTER).length()
	return clampi(1 + int(max(0.0, d - 14.0) / 9.0), 1, 12)


func _free_rect(r: Rect2i, margin: int, allow_reserved: bool = false) -> bool:
	for y in range(r.position.y - margin, r.end.y + margin):
		for x in range(r.position.x - margin, r.end.x + margin):
			var c := Vector2i(x, y)
			if not inside(c) or x < 4 or y < 4 or x >= W - 4 or y >= H - 4:
				return false
			if terrain[idx(c)] != T.GRASS or blocked[idx(c)] == 1:
				return false
			if not allow_reserved and reserved[idx(c)] == 1:
				return false
	return true


func _block_rect(r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if inside(Vector2i(x, y)):
				blocked[idx(Vector2i(x, y))] = 1


func _reserve_disc(c: Vector2i, r: int) -> void:
	for y in range(c.y - r, c.y + r + 1):
		for x in range(c.x - r, c.x + r + 1):
			var p := Vector2i(x, y)
			if inside(p) and Vector2(p - c).length() <= r + 0.3:
				reserved[idx(p)] = 1


# ---------------------------------------------------------------- terrain
func _border() -> void:
	for y in H:
		for x in W:
			var e: int = min(min(x, y), min(W - 1 - x, H - 1 - y))
			var th := 3 + int((noise.get_noise_2d(x * 3.0, y * 3.0) + 1.0) * 1.5)
			if e < th:
				set_t(Vector2i(x, y), T.ROCK)


func _village() -> void:
	_reserve_disc(CENTER, 12)
	for y in range(CENTER.y - 5, CENTER.y + 6):
		for x in range(CENTER.x - 6, CENTER.x + 7):
			var p := Vector2i(x, y)
			if Vector2(p - CENTER).length() < 5.6:
				set_t(p, T.DIRT)
	# fence ring with four gates
	var r := 10
	for x in range(CENTER.x - r, CENTER.x + r + 1):
		for y in [CENTER.y - r, CENTER.y + r]:
			if abs(x - CENTER.x) > 1:
				fences.append(Vector2i(x, y))
	for y in range(CENTER.y - r + 1, CENTER.y + r):
		for x in [CENTER.x - r, CENTER.x + r]:
			if abs(y - CENTER.y) > 1:
				fences.append(Vector2i(x, y))
	for f in fences:
		blocked[idx(f)] = 1
	var c := CENTER
	var props := [
		["sign", c + Vector2i(-2, -3)], ["well", c + Vector2i(3, -2)], ["barrel", c + Vector2i(-7, -7)],
		["barrel", c + Vector2i(-6, -7)], ["crate", c + Vector2i(7, -7)], ["crate", c + Vector2i(7, -6)],
		["pot", c + Vector2i(-7, 6)], ["pot", c + Vector2i(-6, 7)], ["pot", c + Vector2i(6, 7)],
		["bench", c + Vector2i(-4, 3)], ["tree_b", c + Vector2i(-7, -3)], ["tree_b_berry", c + Vector2i(7, 3)],
		["bush", c + Vector2i(6, -3)], ["stump_s", c + Vector2i(-7, 3)],
	]
	for p in props:
		_place(p[0], p[1], true)
	chests.append({"id": "vila", "cell": c + Vector2i(1, 6), "tier": 0})
	blocked[idx(c + Vector2i(1, 6))] = 1
	for n in [["ferreiro", c + Vector2i(-5, -5), c + Vector2i(-3, -5)],
			["alquimista", c + Vector2i(5, -5), c + Vector2i(3, -5)],
			["mercador", c + Vector2i(-4, 6), c + Vector2i(-2, 6)]]:
		npcs.append({"type": n[0], "cell": n[1], "station_cell": n[2]})
		blocked[idx(n[1])] = 1
		blocked[idx(n[2])] = 1


func _carve_path(a: Vector2i, b: Vector2i) -> void:
	var p := Vector2(a)
	var target := Vector2(b)
	var dir := (target - p).normalized()
	var steps := 0
	while p.distance_to(target) > 1.5 and steps < 600:
		steps += 1
		var want := (target - p).normalized()
		dir = (dir + want * 0.35 + Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6)) * 0.35).normalized()
		p += dir
		var c := Vector2i(roundi(p.x), roundi(p.y))
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				var q := c + Vector2i(ox, oy)
				if q.x > 5 and q.y > 5 and q.x < W - 6 and q.y < H - 6:
					set_t(q, T.DIRT)
		_reserve_disc(c, 2)


func _paths() -> void:
	for key in POIS:
		_carve_path(CENTER, POIS[key])
	# a loop road connecting the outer regions
	var keys := ["ruinas", "coracao", "pantano", "pedreira"]
	for i in keys.size():
		if rng.randf() < 0.75:
			var a: Vector2i = POIS[keys[i]]
			var b: Vector2i = POIS[keys[(i + 1) % keys.size()]]
			_carve_path(a, b)


func _boss_arena() -> void:
	boss_cell = POIS["coracao"]
	_reserve_disc(boss_cell, 9)
	for y in range(boss_cell.y - 8, boss_cell.y + 9):
		for x in range(boss_cell.x - 8, boss_cell.x + 9):
			var p := Vector2i(x, y)
			var d := Vector2(p - boss_cell).length()
			if d < 6.5 + noise.get_noise_2d(x * 4.0, y * 4.0) * 1.5:
				set_t(p, T.DIRT)
	# ring of berry trees around the arena (entrance to the west)
	for k in 22:
		var a := TAU * k / 22.0
		var p := boss_cell + Vector2i(roundi(cos(a) * 11.0), roundi(sin(a) * 10.0))
		if cos(a) < -0.85:
			continue
		_place("tree_a_berry" if k % 2 == 0 else "tree_b_berry", p, true)


func _quarry_rocks() -> void:
	for y in range(6, H - 6):
		for x in range(6, W - 6):
			var c := Vector2i(x, y)
			if reserved[idx(c)] == 1:
				continue
			var r := region_at(c)
			var n := noise.get_noise_2d(x * 1.3, y * 1.3)
			var th := 0.06 if r == "pedreira" else 0.62
			if r == "vila" or (r == "prado" and n < 0.7):
				continue
			if n > th and t_at(c) == T.GRASS:
				set_t(c, T.ROCK)


func _dirt_patches() -> void:
	for y in range(6, H - 6):
		for x in range(6, W - 6):
			var c := Vector2i(x, y)
			if t_at(c) != T.GRASS:
				continue
			var n := noise.get_noise_2d(x * 2.1 + 500.0, y * 2.1)
			var r := region_at(c)
			var th := 0.5 if r in ["ruinas", "pedreira"] else 0.62
			if n > th:
				set_t(c, T.DIRT)


## Pattern for the pack's terrain layout (plains.png). Returns Vector2i(-1,-1) if not drawable.
static func blob_tile(n: bool, e: bool, s: bool, w: bool, ne: bool, nw: bool, se: bool, sw: bool) -> Vector2i:
	if not n and not s and not e and not w:
		return Vector2i(0, 3)
	if not e and not w:
		if n and s:
			return Vector2i(0, 1)
		return Vector2i(0, 0) if s else Vector2i(0, 2)
	if not n and not s:
		if e and w:
			return Vector2i(2, 3)
		return Vector2i(1, 3) if e else Vector2i(3, 3)
	var col := 2
	if not w:
		col = 1
	elif not e:
		col = 3
	var row := 1
	if not n:
		row = 0
	elif not s:
		row = 2
	if col == 2 and row == 1:
		var miss := []
		if not nw: miss.append("nw")
		if not ne: miss.append("ne")
		if not sw: miss.append("sw")
		if not se: miss.append("se")
		if miss.is_empty():
			return Vector2i(2, 1)
		if miss.size() == 1:
			match miss[0]:
				"se": return Vector2i(4, 0)
				"sw": return Vector2i(5, 0)
				"ne": return Vector2i(4, 1)
				"nw": return Vector2i(5, 1)
		if miss.size() == 2:
			if "nw" in miss and "se" in miss:
				return Vector2i(4, 2)
			if "ne" in miss and "sw" in miss:
				return Vector2i(5, 2)
		return Vector2i(-1, -1)
	# edges / outer corners: the diagonal between two present sides must be present
	if n and e and not ne: return Vector2i(-1, -1)
	if n and w and not nw: return Vector2i(-1, -1)
	if s and e and not se: return Vector2i(-1, -1)
	if s and w and not sw: return Vector2i(-1, -1)
	return Vector2i(col, row)


func blob_at(c: Vector2i, kind: int) -> Vector2i:
	return blob_tile(t_at(c + Vector2i(0, -1)) == kind, t_at(c + Vector2i(1, 0)) == kind,
		t_at(c + Vector2i(0, 1)) == kind, t_at(c + Vector2i(-1, 0)) == kind,
		t_at(c + Vector2i(1, -1)) == kind, t_at(c + Vector2i(-1, -1)) == kind,
		t_at(c + Vector2i(1, 1)) == kind, t_at(c + Vector2i(-1, 1)) == kind)


func _cleanup_autotile(kind: int) -> void:
	_smooth(kind, 2)
	var bad: Array[Vector2i] = []
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			if terrain[idx(c)] == kind and blob_at(c, kind).x < 0:
				bad.append(c)
	var guard := 0
	while not bad.is_empty() and guard < 400:
		guard += 1
		var touched := {}
		var filled := false
		# first try to round shapes off by filling the missing diagonals
		for c in bad:
			if t_at(c) != kind or blob_at(c, kind).x >= 0:
				continue
			for d in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
				var q: Vector2i = c + d
				if inside(q) and t_at(c + Vector2i(d.x, 0)) == kind and t_at(c + Vector2i(0, d.y)) == kind \
						and t_at(q) != kind and reserved[idx(q)] == 0 and t_at(q) != T.WATER:
					set_t(q, kind)
					filled = true
					_touch(touched, q)
		# what still cannot be drawn becomes grass
		if not filled:
			for c in bad:
				if t_at(c) == kind and blob_at(c, kind).x < 0:
					set_t(c, T.GRASS)
					_touch(touched, c)
		bad.clear()
		for c in touched:
			if t_at(c) == kind and blob_at(c, kind).x < 0:
				bad.append(c)


func _touch(set: Dictionary, c: Vector2i) -> void:
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var q := c + Vector2i(ox, oy)
			if inside(q):
				set[q] = true


## Majority filter: removes specks and thin diagonal chains before autotiling.
func _smooth(kind: int, passes: int) -> void:
	for _p in passes:
		var next := terrain.duplicate()
		for y in range(1, H - 1):
			for x in range(1, W - 1):
				var c := Vector2i(x, y)
				if reserved[idx(c)] == 1 and kind == T.ROCK:
					continue
				var n := 0
				for oy in range(-1, 2):
					for ox in range(-1, 2):
						if t_at(c + Vector2i(ox, oy)) == kind:
							n += 1
				if terrain[idx(c)] == kind and n <= 3:
					next[idx(c)] = T.GRASS
				elif terrain[idx(c)] == T.GRASS and n >= 6:
					next[idx(c)] = kind
		terrain = next


func _ponds() -> void:
	var tries := 900
	for _i in tries:
		var c := Vector2i(rng.randi_range(8, W - 18), rng.randi_range(8, H - 14))
		var r := region_at(c)
		var chance := {"pantano": 1.0, "prado": 0.25, "floresta": 0.2, "ruinas": 0.12, "pedreira": 0.1}
		if rng.randf() > chance.get(r, 0.0):
			continue
		var size := Vector2i(rng.randi_range(3, 9), rng.randi_range(3, 7))
		if r == "pantano":
			size = Vector2i(rng.randi_range(4, 12), rng.randi_range(3, 8))
		var rect := Rect2i(c, size)
		if not _free_rect(rect, 2):
			continue
		ponds.append(rect)
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				set_t(Vector2i(x, y), T.WATER)
		# island in big ponds, lilies and rocks in water
		if size.x >= 7 and size.y >= 6 and rng.randf() < 0.6:
			var ip := rect.position + Vector2i(rng.randi_range(2, size.x - 4), rng.randi_range(2, size.y - 4))
			islands.append(ip)
		for y in range(rect.position.y + 1, rect.end.y - 1):
			for x in range(rect.position.x + 1, rect.end.x - 1):
				if rng.randf() < 0.12:
					if rng.randf() < 0.35:
						lilies.append([Vector2i(x, y), Vector2i(rng.randi_range(0, 5), rng.randi_range(0, 1)), "deco"])
					else:
						lilies.append([Vector2i(x, y), Vector2i(rng.randi_range(0, 5), 0), "lily"])


func _cliffs() -> void:
	for _i in 260:
		var c := Vector2i(rng.randi_range(8, W - 14), rng.randi_range(8, H - 12))
		var r := region_at(c)
		if r in ["vila", "coracao"]:
			continue
		var rect := Rect2i(c, Vector2i(rng.randi_range(3, 6), rng.randi_range(3, 5)))
		if not _free_rect(rect, 1):
			continue
		cliffs.append(rect)
		_block_rect(rect)


func _ruins() -> void:
	var made := 0
	for _i in 600:
		if made >= 14:
			break
		var c := Vector2i(rng.randi_range(10, W - 20), rng.randi_range(8, 70))
		if region_at(c) != "ruinas":
			continue
		var rect := Rect2i(c, Vector2i(rng.randi_range(5, 9), rng.randi_range(4, 7)))
		if not _free_rect(rect, 2, false):
			continue
		ruins.append(rect)
		made += 1
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var p := Vector2i(x, y)
				var edge := x == rect.position.x or y == rect.position.y or x == rect.end.x - 1 or y == rect.end.y - 1
				if edge:
					blocked[idx(p)] = 1
				else:
					reserved[idx(p)] = 1
		# doorway in the bottom wall
		var gx := rect.position.x + rect.size.x / 2
		for x in [gx - 1, gx]:
			blocked[idx(Vector2i(x, rect.end.y - 1))] = 0
		# a chest inside half of the ruins, graves elsewhere
		var inner := rect.position + Vector2i(1 + rng.randi_range(0, rect.size.x - 3), 1 + rng.randi_range(0, rect.size.y - 4))
		if made % 2 == 1:
			chests.append({"id": "ruina_%d" % made, "cell": inner, "tier": 2})
			blocked[idx(inner)] = 1
		else:
			_place("grave", inner, true)
	# lone pillars
	for _i in 120:
		var c := Vector2i(rng.randi_range(10, W - 10), rng.randi_range(8, 80))
		if region_at(c) == "ruinas" and _free_rect(Rect2i(c, Vector2i(1, 3)), 1):
			pillars.append(c)
			_block_rect(Rect2i(c, Vector2i(1, 3)))


# ---------------------------------------------------------------- objects
const OBJ_FOOT := {
	# type -> footprint in cells blocked around the anchor (w, h), anchor = bottom-centre cell
	"tree_a": Vector2i(2, 1), "tree_a_berry": Vector2i(2, 1), "tree_b": Vector2i(2, 1), "tree_b_berry": Vector2i(2, 1),
	"bush": Vector2i(2, 1), "tall_bush": Vector2i(1, 1), "log": Vector2i(2, 1), "log_flower": Vector2i(2, 1),
	"long_log": Vector2i(3, 1), "stump_s": Vector2i(1, 1), "stump_b": Vector2i(2, 1), "rock1": Vector2i(1, 1),
	"rock2": Vector2i(1, 1), "rock3": Vector2i(1, 1), "sign": Vector2i(1, 1), "well": Vector2i(1, 1),
	"barrel": Vector2i(1, 1), "crate": Vector2i(1, 1), "pot": Vector2i(1, 1), "grave": Vector2i(1, 1),
	"bigskull": Vector2i(1, 1), "bench": Vector2i(2, 1), "skull": Vector2i(0, 0), "palm1": Vector2i(0, 0), "palm2": Vector2i(0, 0),
}


func _place(type: String, cell: Vector2i, force: bool = false) -> bool:
	var foot: Vector2i = OBJ_FOOT.get(type, Vector2i(1, 1))
	var area := Rect2i(cell.x - foot.x / 2, cell.y - max(foot.y, 1) + 1, max(foot.x, 1), max(foot.y, 1))
	if not force:
		# keep one free cell around so the player can walk between objects
		for y in range(area.position.y - 1, area.end.y + 1):
			for x in range(area.position.x - 1, area.end.x + 1):
				var p := Vector2i(x, y)
				if not inside(p) or is_blocked(p) or reserved[idx(p)] == 1:
					return false
		if t_at(cell) != T.GRASS and not type in ["skull", "grave", "rock1", "rock2", "rock3"]:
			return false
	if foot.x > 0:
		_block_rect(area)
	objects.append({"type": type, "cell": cell})
	return true


func _objects() -> void:
	var tables := {
		"prado": [0.03, [["tree_a", 3], ["tree_b", 3], ["tree_a_berry", 1], ["bush", 3], ["rock1", 1], ["rock2", 1], ["log_flower", 1], ["stump_s", 1]]],
		"floresta": [0.14, [["tree_a", 5], ["tree_b", 5], ["tree_a_berry", 1], ["tree_b_berry", 1], ["tall_bush", 3], ["bush", 2], ["log", 1], ["long_log", 1], ["stump_b", 1], ["stump_s", 1]]],
		"ruinas": [0.035, [["grave", 4], ["skull", 3], ["bigskull", 1], ["tree_b", 1], ["rock3", 1], ["pot", 1]]],
		"pedreira": [0.04, [["rock1", 3], ["rock2", 3], ["rock3", 3], ["tree_b", 1], ["crate", 1], ["barrel", 1]]],
		"pantano": [0.05, [["palm1", 2], ["palm2", 2], ["log", 2], ["bush", 2], ["tall_bush", 2], ["tree_a", 1], ["stump_s", 2]]],
		"coracao": [0.02, [["bush", 1]]],
	}
	for y in range(5, H - 5):
		for x in range(5, W - 5):
			var c := Vector2i(x, y)
			var r := region_at(c)
			if not tables.has(r):
				continue
			var tab: Array = tables[r]
			if rng.randf() > float(tab[0]):
				continue
			var total := 0
			for e in tab[1]:
				total += int(e[1])
			var pick := rng.randi_range(1, total)
			for e in tab[1]:
				pick -= int(e[1])
				if pick <= 0:
					_place(e[0], c)
					break
	# breakable pots/crates scattered (loot)
	for _i in 70:
		var c := Vector2i(rng.randi_range(10, W - 10), rng.randi_range(10, H - 10))
		if region_at(c) != "vila":
			_place("pot" if rng.randf() < 0.6 else "crate", c)


func _resources() -> void:
	for y in range(6, H - 6):
		for x in range(6, W - 6):
			var c := Vector2i(x, y)
			var r := region_at(c)
			if not ItemDB.RESOURCE_SPAWNS.has(r):
				continue
			var tab: Array = ItemDB.RESOURCE_SPAWNS[r]
			if rng.randf() > float(tab[0]):
				continue
			if not walkable(c) or reserved[idx(c)] == 1 or t_at(c) != T.GRASS:
				continue
			var free := true
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					if is_blocked(c + Vector2i(ox, oy)):
						free = false
			if not free:
				continue
			var total := 0
			for e in tab[1]:
				total += int(e[1])
			var pick := rng.randi_range(1, total)
			for e in tab[1]:
				pick -= int(e[1])
				if pick <= 0:
					resources.append({"type": e[0], "cell": c})
					blocked[idx(c)] = 1
					break


func _chests() -> void:
	var n := 0
	for _i in 4000:
		if n >= 26:
			break
		var c := Vector2i(rng.randi_range(8, W - 8), rng.randi_range(8, H - 8))
		var r := region_at(c)
		if r == "vila" or not walkable(c) or reserved[idx(c)] == 1 or t_at(c) != T.GRASS:
			continue
		# keep chests apart
		var ok := true
		for ch in chests:
			if Vector2(ch["cell"] - c).length() < 18.0:
				ok = false
				break
		if not ok:
			continue
		var tier := clampi(level_at(c) / 3, 0, 3)
		chests.append({"id": "bau_%d_%d" % [c.x, c.y], "cell": c, "tier": tier})
		blocked[idx(c)] = 1
		n += 1
	# big reward next to the boss arena
	var bc := boss_cell + Vector2i(0, -4)
	chests.append({"id": "chefe", "cell": bc, "tier": 4, "boss": true})


func _decor() -> void:
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			if terrain[idx(c)] != T.GRASS or blocked[idx(c)] == 1:
				continue
			var r := rng.randf()
			var reg := region_at(c)
			if r < 0.08:
				decor[c] = Vector2i(rng.randi_range(0, 3), 0)          # grass tufts
			elif r < 0.10:
				decor[c] = Vector2i(rng.randi_range(0, 3), 2)          # flowers
			elif r < 0.11:
				decor[c] = Vector2i(rng.randi_range(0, 3), 1)          # pebbles
			elif r < 0.118 and reg in ["floresta", "pantano", "coracao"]:
				decor[c] = Vector2i(rng.randi_range(0, 3), 3)          # mushrooms


func find_spawn_cell(around: Vector2i, rmin: float, rmax: float, rng2: RandomNumberGenerator) -> Vector2i:
	for _i in 20:
		var a := rng2.randf() * TAU
		var d := rng2.randf_range(rmin, rmax)
		var c := around + Vector2i(roundi(cos(a) * d), roundi(sin(a) * d))
		if walkable(c) and walkable(c + Vector2i(1, 0)) and walkable(c + Vector2i(0, -1)) and region_at(c) != "vila":
			return c
	return Vector2i(-1, -1)
