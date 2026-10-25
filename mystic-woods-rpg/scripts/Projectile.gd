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


func _ready() -> void:
	var a := AnimatedSprite2D.new()
	a.sprite_frames = Sheets.strip("res://assets/vfx/fireball.png", 24, 24, 8, 12.0, true)
	a.play("default")
	a.scale = Vector2(0.75, 0.75)
	add_child(a)


func _physics_process(delta: float) -> void:
	var step := vel * delta
	position += step
	travelled += step.length()
	if travelled >= RANGE:
		burst()
		return
	if hostile:
		var p: Node = main.player
		if p and p.alive() and (p.global_position + Vector2(0, -8)).distance_to(global_position) <= 9.0:
			burst()
	else:
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.alive() and e.hurt_center().distance_to(global_position) <= 6.0 + e.radius:
				burst()
				return


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
	else:
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.alive() and e.hurt_center().distance_to(global_position) <= SPLASH + e.radius:
				e.take_hit(dmg, (e.global_position - global_position).normalized())
	queue_free()
