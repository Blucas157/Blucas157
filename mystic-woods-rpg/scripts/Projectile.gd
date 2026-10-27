extends Node2D
## A fireball (vfx_workbench art): flies straight and bursts on the first target it touches or at
## the end of its range, burning everything inside the burst. The hero's hurts monsters; a
## monster's (hostile) hurts the hero.

const RANGE := 170.0
const SPLASH := 18.0

var main: Node
var source: Node = null
var vel := Vector2.ZERO
var dmg := 10
var hostile := false
var travelled := 0.0
var faction := ""         # a monster's fireball also burns monsters of factions at war with it
var homing = null   # a locked/aimed monster: the fireball bends toward it
const TURN := 5.0          # radians per second
var kind := "fire"         # "fire" (bursts) or "arrow" (Arqueria: no burst, may pierce)
var pierce := false
var hit_list: Array = []


func _ready() -> void:
	if kind == "arrow":
		rotation = vel.angle()
		return
	var a := AnimatedSprite2D.new()
	a.sprite_frames = Sheets.strip("res://assets/vfx/fireball.png", 24, 24, 8, 12.0, true)
	a.play("default")
	a.scale = Vector2(0.75, 0.75)
	add_child(a)


func _physics_process(delta: float) -> void:
	if is_instance_valid(homing) and homing.alive():
		var want: float = (homing.hurt_center() - global_position).angle()
		var ang := vel.angle()
		vel = Vector2.from_angle(ang + clampf(wrapf(want - ang, -PI, PI), -TURN * delta, TURN * delta)) * vel.length()
	var step := vel * delta
	position += step
	travelled += step.length()
	if kind == "arrow":
		_arrow_step()
		return
	if travelled >= RANGE:
		burst()
		return
	if hostile:
		var p: Node = main.player
		if p and p.alive() and (p.global_position + Vector2(0, -8)).distance_to(global_position) <= 9.0:
			burst()
			return
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.alive() and Factions.at_war(faction, e.faction) and e.hurt_center().distance_to(global_position) <= 6.0 + e.radius:
				burst()
				return
	else:
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.alive() and e.hurt_center().distance_to(global_position) <= 6.0 + e.radius:
				burst()
				return


func _arrow_step() -> void:
	if travelled >= RANGE * 1.25:
		queue_free()
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.alive() and not e in hit_list and e.body_distance(global_position) <= 5.0 + e.radius:
			hit_list.append(e)
			var d := dmg
			if is_instance_valid(source) and source.has_method("dmg_mult") and randf() < source.crit_chance():
				d = int(d * 1.8)
			e.take_hit(d, vel.normalized(), d > dmg, "melee")
			if not pierce:
				queue_free()
				return


func _draw() -> void:
	if kind != "arrow":
		return
	# a small arrow pointing along +x (the node is rotated to its flight)
	var ink := Color(0.09, 0.11, 0.19)
	draw_line(Vector2(-7, 0), Vector2(5, 0), ink, 3.0)
	draw_line(Vector2(-7, 0), Vector2(5, 0), Color("9d7658"), 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(8, 0), Vector2(4, -3), Vector2(4, 3)]), Color("b6bec8"))
	draw_line(Vector2(-8, -2), Vector2(-5, 0), Color("ffffff"), 1.0)
	draw_line(Vector2(-8, 2), Vector2(-5, 0), Color("ffffff"), 1.0)


func burst() -> void:
	main.vfx("fireburst", global_position)
	Sfx.play("hit", 0.7)
	main.shake(1.5, 0.1)
	if hostile:
		var p: Node = main.player
		if p and p.alive() and (p.global_position + Vector2(0, -8)).distance_to(global_position) <= SPLASH:
			if is_instance_valid(source):
				p.last_hit_by = source
			p.take_damage(dmg, global_position)
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.alive() and Factions.at_war(faction, e.faction) and e.hurt_center().distance_to(global_position) <= SPLASH + e.radius:
				e.take_hit(dmg, (e.global_position - global_position).normalized(), false, "faction:" + faction)
	else:
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.alive() and e.hurt_center().distance_to(global_position) <= SPLASH + e.radius:
				e.take_hit(dmg, (e.global_position - global_position).normalized(), false, "magic")
		for c in get_tree().get_nodes_in_group("camps"):
			if (c.global_position + Vector2(0, -12)).distance_to(global_position) <= SPLASH + 10.0:
				c.hit(dmg)
	queue_free()
