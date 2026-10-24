extends Node2D
## Turns WorldGen data into tile layers, y-sorted props, chests and the minimap image.

const TILE := 16
const MW := Sheets.MW

const SRC_GRASS := 0
const SRC_PLAINS := 1
const SRC_WATER := 2
const SRC_DECOR := 3
const SRC_WALLS := 4
const SRC_FENCE := 5
const SRC_LILY := 6
const SRC_WDECO := 7

const OBJ := {
	# type: [region in objects.png, feet point inside region, collider size (0 = none)]
	"tree_a": [Rect2(0, 80, 48, 64), Vector2(24, 57), Vector2(14, 8)],
	"tree_a_berry": [Rect2(48, 80, 48, 64), Vector2(24, 57), Vector2(14, 8)],
	"tree_b": [Rect2(0, 144, 48, 64), Vector2(24, 57), Vector2(14, 8)],
	"tree_b_berry": [Rect2(48, 144, 48, 64), Vector2(24, 57), Vector2(14, 8)],
	"bush": [Rect2(96, 112, 32, 32), Vector2(16, 29), Vector2(24, 8)],
	"tall_bush": [Rect2(128, 96, 32, 48), Vector2(16, 45), Vector2(12, 6)],
	"log": [Rect2(96, 96, 32, 16), Vector2(16, 13), Vector2(26, 7)],
	"log_flower": [Rect2(96, 80, 32, 16), Vector2(16, 13), Vector2(26, 7)],
	"long_log": [Rect2(96, 144, 48, 16), Vector2(24, 13), Vector2(40, 7)],
	"stump_s": [Rect2(160, 88, 32, 24), Vector2(16, 20), Vector2(14, 7)],
	"stump_b": [Rect2(160, 112, 32, 32), Vector2(16, 26), Vector2(20, 9)],
	"rock1": [Rect2(0, 16, 16, 16), Vector2(8, 13), Vector2(12, 7)],
	"rock2": [Rect2(16, 16, 16, 16), Vector2(8, 13), Vector2(12, 7)],
	"rock3": [Rect2(32, 16, 16, 16), Vector2(8, 13), Vector2(12, 7)],
	"sign": [Rect2(0, 0, 16, 16), Vector2(8, 14), Vector2(8, 5)],
	"well": [Rect2(16, 0, 16, 16), Vector2(8, 14), Vector2(12, 7)],
	"barrel": [Rect2(48, 0, 16, 16), Vector2(8, 14), Vector2(10, 6)],
	"crate": [Rect2(80, 0, 16, 16), Vector2(8, 14), Vector2(12, 6)],
	"pot": [Rect2(64, 0, 16, 16), Vector2(8, 14), Vector2(10, 6)],
	"grave": [Rect2(96, 0, 16, 16), Vector2(8, 14), Vector2(10, 6)],
	"skull": [Rect2(112, 0, 16, 16), Vector2(8, 13), Vector2.ZERO],
	"bigskull": [Rect2(128, 0, 16, 16), Vector2(8, 14), Vector2(12, 6)],
	"bench": [Rect2(48, 16, 32, 16), Vector2(16, 14), Vector2(28, 6)],
	"palm1": [Rect2(128, 80, 16, 16), Vector2(8, 14), Vector2.ZERO],
	"palm2": [Rect2(144, 80, 16, 16), Vector2(8, 14), Vector2.ZERO],
}
const BREAKABLE := ["pot", "crate", "barrel"]

var gen: WorldGen
var ground: TileMapLayer
var overlay: TileMapLayer
var entities: Node2D
var minimap_image: Image
var minimap_texture: ImageTexture


func build(world_seed: int) -> void:
	gen = WorldGen.new()
	gen.generate(world_seed)
	var ts := _make_tileset()
	ground = TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = ts
	add_child(ground)
	entities = Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	add_child(entities)
	# walls, fences and cliffs sort with the characters (walk behind a fence, in front of it)
	overlay = TileMapLayer.new()
	overlay.name = "Overlay"
	overlay.tile_set = ts
	overlay.y_sort_enabled = true
	entities.add_child(overlay)
	_paint_ground()
	_paint_overlay()
	_spawn_objects()
	_spawn_resources()
	_spawn_npcs()
	_spawn_chests()
	_make_minimap()


func cell_to_pos(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE + TILE / 2.0, c.y * TILE + TILE / 2.0)


func pos_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


func world_rect() -> Rect2:
	return Rect2(0, 0, WorldGen.W * TILE, WorldGen.H * TILE)


# ---------------------------------------------------------------- tileset
func _atlas(ts: TileSet, id: int, path: String, cols: int, rows: int, solid: Callable) -> TileSetAtlasSource:
	var src := TileSetAtlasSource.new()
	src.texture = Sheets.tex(path)
	src.texture_region_size = Vector2i(TILE, TILE)
	for y in rows:
		for x in cols:
			var c := Vector2i(x, y)
			src.create_tile(c)
	ts.add_source(src, id)
	for y in rows:
		for x in cols:
			var c := Vector2i(x, y)
			if solid.call(c):
				_solid(src, c)
	return src


func _solid(src: TileSetAtlasSource, c: Vector2i, shrink: float = 0.0) -> void:
	var td := src.get_tile_data(c, 0)
	td.add_collision_polygon(0)
	var h := TILE / 2.0 - shrink
	td.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]))


func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	var none := func(_c: Vector2i) -> bool: return false
	var all := func(_c: Vector2i) -> bool: return true
	_atlas(ts, SRC_GRASS, MW + "tilesets/grass.png", 1, 1, none)
	# plains: rows 0-3 dirt (walkable), 4-7 cliffs, 8-11 rocks (solid)
	_atlas(ts, SRC_PLAINS, MW + "tilesets/plains.png", 6, 12, func(c: Vector2i) -> bool: return c.y >= 4)
	# animated water: water1..6 are the frames, laid side by side
	var frames: Array[Image] = []
	for i in range(1, 7):
		var img := Sheets.tex(MW + "tilesets/water%d.png" % i).get_image()
		img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		frames.append(img)
	var combo := Image.create(96 * 6, 64, false, Image.FORMAT_RGBA8)
	for i in frames.size():
		combo.blit_rect(frames[i], Rect2i(0, 0, 96, 64), Vector2i(96 * i, 0))
	var wsrc := TileSetAtlasSource.new()
	wsrc.texture = ImageTexture.create_from_image(combo)
	wsrc.texture_region_size = Vector2i(TILE, TILE)
	for c in [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
			Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 0), Vector2i(5, 0), Vector2i(4, 1), Vector2i(5, 1)]:
		wsrc.create_tile(c)
		wsrc.set_tile_animation_separation(c, Vector2i(5, 0))
		wsrc.set_tile_animation_frames_count(c, 6)
		wsrc.set_tile_animation_speed(c, 5.0)
	ts.add_source(wsrc, SRC_WATER)
	for c in [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
			Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 0), Vector2i(5, 0), Vector2i(4, 1), Vector2i(5, 1)]:
		_solid(wsrc, c)
	_atlas(ts, SRC_DECOR, MW + "tilesets/decor_16x16.png", 4, 5, none)
	_atlas(ts, SRC_WALLS, MW + "tilesets/walls/walls.png", 8, 8, all)
	_atlas(ts, SRC_FENCE, MW + "tilesets/fences.png", 4, 4, all)
	_atlas(ts, SRC_LILY, MW + "tilesets/water_lillies.png", 6, 1, none)
	_atlas(ts, SRC_WDECO, MW + "tilesets/water_decorations.png", 6, 2, none)
	return ts


# ---------------------------------------------------------------- painting
func _paint_ground() -> void:
	for y in WorldGen.H:
		for x in WorldGen.W:
			var c := Vector2i(x, y)
			match gen.t_at(c):
				WorldGen.T.GRASS:
					if gen.decor.has(c):
						ground.set_cell(c, SRC_DECOR, gen.decor[c])
					else:
						ground.set_cell(c, SRC_GRASS, Vector2i.ZERO)
				WorldGen.T.DIRT:
					var t := gen.blob_at(c, WorldGen.T.DIRT)
					ground.set_cell(c, SRC_PLAINS, t if t.x >= 0 else Vector2i(2, 1))
				WorldGen.T.ROCK:
					var t := gen.blob_at(c, WorldGen.T.ROCK)
					ground.set_cell(c, SRC_PLAINS, (t if t.x >= 0 else Vector2i(2, 1)) + Vector2i(0, 8))
	for r in gen.ponds:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var col := 2
				if x == r.position.x: col = 1
				elif x == r.end.x - 1: col = 3
				var row := 1
				if y == r.position.y: row = 0
				elif y == r.end.y - 1: row = 2
				ground.set_cell(Vector2i(x, y), SRC_WATER, Vector2i(col, row))
	for ip in gen.islands:
		for oy in 2:
			for ox in 2:
				ground.set_cell(ip + Vector2i(ox, oy), SRC_WATER, Vector2i(4 + ox, oy))


func _paint_overlay() -> void:
	for r in gen.cliffs:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var col := 2
				if x == r.position.x: col = 1
				elif x == r.end.x - 1: col = 3
				var row := 5
				if y == r.position.y: row = 4
				elif y == r.end.y - 1: row = 6
				overlay.set_cell(Vector2i(x, y), SRC_PLAINS, Vector2i(col, row))
	for r in gen.ruins:
		var gx := r.position.x + r.size.x / 2
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var edge := x == r.position.x or y == r.position.y or x == r.end.x - 1 or y == r.end.y - 1
				if not edge:
					continue
				if y == r.end.y - 1 and (x == gx or x == gx - 1):
					continue
				var col := 2
				if x == r.position.x: col = 1
				elif x == r.end.x - 1: col = 3
				var row := 1
				if y == r.position.y: row = 0
				elif y == r.end.y - 1: row = 2
				if row == 1 and col == 2:
					continue
				overlay.set_cell(Vector2i(x, y), SRC_WALLS, Vector2i(col, row))
	for p in gen.pillars:
		for k in 3:
			overlay.set_cell(p + Vector2i(0, k), SRC_WALLS, Vector2i(0, k))
	var fence_set := {}
	for f in gen.fences:
		fence_set[f] = true
	for f in gen.fences:
		var l := fence_set.has(f + Vector2i(-1, 0))
		var rr := fence_set.has(f + Vector2i(1, 0))
		var u := fence_set.has(f + Vector2i(0, -1))
		var d := fence_set.has(f + Vector2i(0, 1))
		var col := 0
		if l and rr: col = 2
		elif rr: col = 1
		elif l: col = 3
		var row := 3
		if u and d: row = 1
		elif d: row = 0
		elif u: row = 2
		overlay.set_cell(f, SRC_FENCE, Vector2i(col, row))
	for e in gen.lilies:
		overlay.set_cell(e[0], SRC_LILY if e[2] == "lily" else SRC_WDECO, e[1])


func _spawn_objects() -> void:
	var tex := Sheets.tex(MW + "objects/objects.png")
	for o in gen.objects:
		var type: String = o["type"]
		var def: Array = OBJ[type]
		var cell: Vector2i = o["cell"]
		var foot: Vector2i = WorldGen.OBJ_FOOT.get(type, Vector2i(1, 1))
		var pos := Vector2(cell.x * TILE + (TILE / 2.0 if foot.x % 2 == 1 or foot.x == 0 else 0.0), cell.y * TILE + 13)
		var key := "%d_%d" % [cell.x, cell.y]
		if type in BREAKABLE and Game.broken.has(key):
			continue
		var node: Node2D
		var size: Vector2 = def[2]
		if size == Vector2.ZERO:
			node = Node2D.new()
		else:
			var body := StaticBody2D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = size
			shape.shape = rect
			shape.position = Vector2(0, -size.y / 2.0 + 2)
			body.add_child(shape)
			node = body
		node.position = pos
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.region_enabled = true
		spr.region_rect = def[0]
		spr.centered = false
		spr.offset = -def[1]
		node.add_child(spr)
		if type in ["sign", "well"] and gen.region_at(cell) == "vila":
			node.add_to_group("interactables")
			node.set_meta("type", type)
		if type in BREAKABLE:
			node.add_to_group("breakables")
			node.set_meta("key", key)
			node.set_meta("type", type)
		entities.add_child(node)


func _spawn_resources() -> void:
	for r in gen.resources:
		var node := preload("res://scripts/ResourceNode.gd").new()
		node.setup(r["type"])
		node.position = cell_to_pos(r["cell"]) + Vector2(0, 6)
		entities.add_child(node)


func _spawn_npcs() -> void:
	for n in gen.npcs:
		for part in [["station", n["station_cell"]], ["npc", n["cell"]]]:
			var body := StaticBody2D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(14, 7)
			shape.shape = rect
			shape.position = Vector2(0, -3)
			body.add_child(shape)
			var spr := Sprite2D.new()
			var file: String = n["type"] + ("_station" if part[0] == "station" else "")
			spr.texture = Sheets.tex("res://assets/npcs/%s.png" % file)
			spr.offset = Vector2(0, -spr.texture.get_height() / 2.0 + 3)
			body.add_child(spr)
			body.position = cell_to_pos(part[1]) + Vector2(0, 6)
			body.add_to_group("interactables")
			body.set_meta("type", n["type"])
			if part[0] == "npc":
				body.set_meta("npc", true)
				var tw := spr.create_tween().set_loops()
				tw.tween_property(spr, "scale:y", 1.04, 0.6)
				tw.tween_property(spr, "scale:y", 1.0, 0.6)
			entities.add_child(body)


func _spawn_chests() -> void:
	for ch in gen.chests:
		var chest := preload("res://scripts/Chest.gd").new()
		chest.chest_id = ch["id"]
		chest.tier = ch["tier"]
		chest.boss_chest = ch.get("boss", false)
		chest.position = cell_to_pos(ch["cell"]) + Vector2(0, 5)
		entities.add_child(chest)


# ---------------------------------------------------------------- minimap
func _make_minimap() -> void:
	minimap_image = Image.create(WorldGen.W, WorldGen.H, false, Image.FORMAT_RGBA8)
	var cols := {
		WorldGen.T.GRASS: Color("509b66"), WorldGen.T.DIRT: Color("9d7658"),
		WorldGen.T.WATER: Color("4d8ab3"), WorldGen.T.ROCK: Color("414b66"),
	}
	for y in WorldGen.H:
		for x in WorldGen.W:
			var c := Vector2i(x, y)
			var col: Color = cols[gen.t_at(c)]
			if gen.region_at(c) == "floresta" and col == cols[WorldGen.T.GRASS]:
				col = Color("3f8a55")
			minimap_image.set_pixel(x, y, col)
	for r in gen.cliffs:
		minimap_image.fill_rect(r, Color("2f6b2a"))
	for r in gen.ruins:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if x == r.position.x or y == r.position.y or x == r.end.x - 1 or y == r.end.y - 1:
					minimap_image.set_pixel(x, y, Color("8f9ab0"))
	for o in gen.objects:
		if String(o["type"]).begins_with("tree"):
			var c: Vector2i = o["cell"]
			minimap_image.set_pixel(c.x, c.y, Color("1f5a24"))
			if c.y > 0:
				minimap_image.set_pixel(c.x, c.y - 1, Color("2a6a2c"))
	for f in gen.fences:
		minimap_image.set_pixel(f.x, f.y, Color("755338"))
	for r in gen.resources:
		var c: Vector2i = r["cell"]
		minimap_image.set_pixel(c.x, c.y, Color("d99945") if String(r["type"]).begins_with("veio") else Color("bc4952"))
	minimap_texture = ImageTexture.create_from_image(minimap_image)
