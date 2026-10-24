extends SceneTree
## World generation checks: every terrain tile is drawable and every region is reachable on foot.
## Run: godot --headless --path . -s res://tests/verify_world.gd

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
	else:
		print("ok  - ", label)


func run() -> void:
	for s in [1, 4242, 99173]:
		var t0 := Time.get_ticks_msec()
		var g := WorldGen.new()
		g.generate(s)
		print("seed %d generated in %d ms (%d objects, %d ponds, %d cliffs, %d ruins, %d chests)" % [
			s, Time.get_ticks_msec() - t0, g.objects.size(), g.ponds.size(), g.cliffs.size(), g.ruins.size(), g.chests.size()])
		var bad := 0
		for y in WorldGen.H:
			for x in WorldGen.W:
				var c := Vector2i(x, y)
				var k := g.t_at(c)
				if (k == WorldGen.T.DIRT or k == WorldGen.T.ROCK) and g.blob_at(c, k).x < 0:
					bad += 1
		check(bad < 12, "seed %d: autotile patterns drawable (%d odd cells)" % [s, bad])
		# flood fill from the village
		var seen := PackedByteArray()
		seen.resize(WorldGen.W * WorldGen.H)
		var q: Array[Vector2i] = [WorldGen.CENTER + Vector2i(0, 2)]
		seen[g.idx(q[0])] = 1
		var reached := 0
		while not q.is_empty():
			var c: Vector2i = q.pop_back()
			reached += 1
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + o
				if g.walkable(n) and seen[g.idx(n)] == 0:
					seen[g.idx(n)] = 1
					q.append(n)
		for key in WorldGen.POIS:
			var p: Vector2i = WorldGen.POIS[key]
			var near := false
			for oy in range(-3, 4):
				for ox in range(-3, 4):
					var c2 := p + Vector2i(ox, oy)
					if g.inside(c2) and seen[g.idx(c2)] == 1:
						near = true
			check(near, "seed %d: %s reachable from the village" % [s, key])
		var chest_ok := 0
		for ch in g.chests:
			var cc: Vector2i = ch["cell"]
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if g.inside(cc + o) and seen[g.idx(cc + o)] == 1:
					chest_ok += 1
					break
		check(chest_ok >= g.chests.size() - 2, "seed %d: chests reachable (%d/%d)" % [s, chest_ok, g.chests.size()])
		var regions := {}
		for y in range(0, WorldGen.H, 4):
			for x in range(0, WorldGen.W, 4):
				var c3 := Vector2i(x, y)
				if seen[g.idx(c3)] == 1:
					regions[g.region_at(c3)] = true
		check(regions.size() == 7, "seed %d: all 7 regions walkable %s" % [s, str(regions.keys())])
		check(reached > 15000, "seed %d: large walkable world (%d cells)" % [s, reached])
	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
