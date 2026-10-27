extends Node2D
## A faction camp (Factions.gd): bonfire, war banner in the faction's colour and some props.
## While the hero is near it sends out guards; the banner can be cut down (sword or fireball)
## to burn the camp, which weakens the faction and makes it hold a grudge.

const OBJ_TEX := "res://assets/mystic_woods/sprites/objects/objects.png"
const PROPS := {
	"camp": [["log", Vector2(-18, 10)], ["crate", Vector2(20, 6)], ["barrel", Vector2(24, -8)], ["stump_s", Vector2(-22, -10)]],
	"grave": [["grave", Vector2(-18, 8)], ["bigskull", Vector2(18, 8)], ["grave", Vector2(22, -10)], ["skull", Vector2(-20, -10)]],
	"nest": [["bigskull", Vector2(-16, 8)], ["skull", Vector2(18, 10)], ["skull", Vector2(22, -6)], ["rock3", Vector2(-22, -10)]],
	"den": [["log", Vector2(-18, 8)], ["rock1", Vector2(18, 8)], ["rock2", Vector2(22, -8)], ["stump_s", Vector2(-22, -10)]],
}

var main: Node
var fid := ""
var camp: Dictionary = {}
var guards: Array = []
var guard_t := 2.0
var flash_t := 0.0
var t := 0.0


func _ready() -> void:
	add_to_group("camps")
	z_index = 0
	var props: Array = PROPS.get(Factions.DATA[fid].get("props", "camp"), PROPS["camp"])
	for p in props:
		var o: Array = main.world.OBJ[p[0]]
		var s := Sprite2D.new()
		s.texture = Sheets.tex(OBJ_TEX)
		s.region_enabled = true
		s.region_rect = o[0]
		s.centered = false
		s.offset = -o[1] + p[1]
		add_child(s)
	var fire := AnimatedSprite2D.new()
	fire.sprite_frames = Sheets.strip("res://assets/vfx/flame.png", 16, 23, 8, 10.0, true)
	fire.centered = false
	fire.offset = Vector2(-8, -16)
	fire.position = Vector2(0, 8)
	fire.play("default")
	add_child(fire)


func level() -> int:
	return int(camp.get("level", 1))


func max_hp() -> int:
	return 60 * level()


func _process(delta: float) -> void:
	t += delta
	flash_t = maxf(0.0, flash_t - delta)
	queue_redraw()
	if main == null or not main.playing or main.player == null:
		return
	guards = guards.filter(func(g): return is_instance_valid(g) and g.alive())
	var near: bool = main.player.global_position.distance_to(global_position) < 260.0
	guard_t -= delta
	if near and guard_t <= 0.0:
		guard_t = 4.0
		if guards.size() < 1 + 2 * level():
			_spawn_guard()


func _spawn_guard() -> void:
	var members: Array = Factions.DATA[fid]["members"]
	if members.is_empty():
		return
	var id: String = members[randi() % members.size()]
	var elite: String = Factions.DATA[fid]["elite"]
	if elite != "" and randf() < 0.08 * Factions.tier(fid):
		id = elite
	var cell: Vector2i = main.world.pos_to_cell(global_position)
	var lvl: int = main.world.gen.level_at(cell) + level() - 1
	var a := randf() * TAU
	var e: Node = main.spawn_enemy(id, global_position + Vector2(cos(a), sin(a)) * 30.0, lvl)
	e.home = global_position
	guards.append(e)


## Hit by the hero (sword or fireball).
func hit(dmg: int) -> void:
	camp["hp"] = int(camp.get("hp", max_hp())) - dmg
	flash_t = 0.12
	main.float_text(global_position + Vector2(0, -34), str(dmg), Color.WHITE)
	main.vfx("hit", global_position + Vector2(0, -18), randf() * TAU, Color(1.0, 0.8, 0.6), null, 0.6)
	Sfx.play("hit", 0.8)
	# the camp calls everyone home
	for g in guards:
		if is_instance_valid(g) and g.state in ["idle", "wander"]:
			g.state = "chase"
	if int(camp["hp"]) <= 0:
		main.camp_destroyed(self)


func _draw() -> void:
	# war banner: dark pole, cloth in the faction colour that waves, a pennant per camp level
	var col: Color = Factions.DATA[fid]["color"]
	if flash_t > 0.0:
		col = Color.WHITE
	var ink := Color(0.09, 0.11, 0.19)
	var pole := Vector2(0, -2)
	draw_rect(Rect2(pole + Vector2(-2, -36), Vector2(4, 37)), ink)
	draw_rect(Rect2(pole + Vector2(-1, -35), Vector2(2, 35)), Color("755338"))
	var wave := roundf(sin(t * 4.0))
	var cloth := Rect2(pole + Vector2(1, -34 + wave * 0.0), Vector2(12, 9))
	draw_rect(cloth.grow(1), ink)
	draw_rect(cloth, col)
	draw_rect(Rect2(cloth.position + Vector2(0, 7), Vector2(12, 2)), col.darkened(0.3))
	draw_rect(Rect2(cloth.end.x - 2.0 + wave, cloth.position.y + 2, 2, 5), col.lightened(0.2))
	for k in level():
		draw_rect(Rect2(pole + Vector2(-5 - k * 3, -36), Vector2(2, 2)), Color("e9ce7c"))
	# life bar once damaged
	var hp := int(camp.get("hp", max_hp()))
	if hp < max_hp():
		var w := 26.0
		draw_rect(Rect2(-w / 2 - 1, -46, w + 2, 4), Color(0.85, 0.6, 0.27))
		draw_rect(Rect2(-w / 2, -45, w, 2), ink)
		draw_rect(Rect2(-w / 2, -45, w * clampf(float(hp) / max_hp(), 0.0, 1.0), 2), Color(0.74, 0.29, 0.32))
