class_name Sheets
## Builds SpriteFrames from the pack's sheet layout and keeps them cached.

const MW := "res://assets/mystic_woods/sprites/"
const DIRS := ["down", "side", "up"]

static var _cache := {}


static func tex(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]


static func region(path: String, rect: Rect2) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex(path)
	a.region = rect
	return a


## Character sheet: rows grouped as [down, side, up] for each animation in `order`,
## followed by single-row animations in `singles`.
## counts: anim -> frame count; fps: anim -> speed; loops: anims that loop.
static func character(path: String, grid: int, order: Array, singles: Array, counts: Dictionary,
		fps: Dictionary, loops: Array) -> SpriteFrames:
	var key := path + str(grid)
	if _cache.has(key):
		return _cache[key]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var row := 0
	for anim in order:
		for d in DIRS:
			var name: String = anim + "_" + d
			_add(sf, name, path, grid, row, counts[anim], fps.get(anim, 8.0), anim in loops)
			row += 1
	for anim in singles:
		_add(sf, anim, path, grid, row, counts[anim], fps.get(anim, 8.0), anim in loops)
		row += 1
	_cache[key] = sf
	return sf


static func strip(path: String, w: int, h: int, count: int, speed: float, loop: bool, row: int = 0) -> SpriteFrames:
	var key := "%s|%d|%d|%d" % [path, w, h, row]
	if _cache.has(key):
		return _cache[key]
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", speed)
	sf.set_animation_loop("default", loop)
	for i in count:
		sf.add_frame("default", region(path, Rect2(i * w, row * h, w, h)))
	_cache[key] = sf
	return sf


static func _add(sf: SpriteFrames, name: String, path: String, grid: int, row: int, count: int, speed: float, loop: bool) -> void:
	sf.add_animation(name)
	sf.set_animation_speed(name, speed)
	sf.set_animation_loop(name, loop)
	for i in count:
		sf.add_frame(name, region(path, Rect2(i * grid, row * grid, grid, grid)))


static func dir_name(v: Vector2) -> String:
	if abs(v.x) > abs(v.y) * 1.05:
		return "side"
	return "down" if v.y >= 0.0 else "up"
