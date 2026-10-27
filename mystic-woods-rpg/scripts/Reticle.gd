extends Node2D
## Target reticle drawn on the hero's current target: four corner brackets that close in and pulse.
## White and faint while it is only the nearest monster; red and gold when the hero locked it.

var player: Node
var t := 0.0
var shown_on = null   # untyped: the monster may already be freed
var snap := 0.0   # 1 -> 0 right after the target changes: the brackets close in from wider


func _ready() -> void:
	z_index = 30


func _process(delta: float) -> void:
	t += delta
	var target = player.target if player else null
	visible = is_instance_valid(target) and target.alive()
	if not visible:
		shown_on = null
		return
	if target != shown_on:
		shown_on = target
		snap = 1.0
	snap = maxf(0.0, snap - delta * 5.0)
	global_position = target.hurt_center().round()
	queue_redraw()


func _draw() -> void:
	var target = shown_on
	if not is_instance_valid(target):
		return
	var locked: bool = player.target_locked
	var r := roundf(float(target.radius) * target.scale.x + 6.0 + snap * 8.0 + (sin(t * 6.0) * 1.0 if locked else 0.0))
	var col := Color(1.0, 0.32, 0.25) if locked else Color(1, 1, 1, 0.55)
	var ink := Color(0.09, 0.11, 0.19, 0.9 if locked else 0.5)
	var arm := 4.0
	var bars: Array = []
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var c := Vector2(sx * r, sy * r)
			bars.append(Rect2(Vector2(minf(c.x, c.x - sx * arm), c.y), Vector2(arm + 1, 1)))
			bars.append(Rect2(Vector2(c.x, minf(c.y, c.y - sy * arm)), Vector2(1, arm + 1)))
	# dark backing first so the brackets read on grass and on sand
	for b in bars:
		draw_rect(b.grow(1), ink)
	for b in bars:
		draw_rect(b, col)
	if locked:
		# a gold dot over the head says "locked"
		draw_rect(Rect2(Vector2(-1, -r - 5), Vector2(3, 3)), ink)
		draw_rect(Rect2(Vector2(0, -r - 4), Vector2(1, 1)), Color(1.0, 0.85, 0.35))
