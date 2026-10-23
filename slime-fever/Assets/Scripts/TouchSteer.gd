extends Node2D
## Mobile steering: hold a finger anywhere below the HUD and the slime walks to its x.
## The slime keeps its normal speed, so the coin routes stay as fair as with the arrows.

const TOP_LIMIT := 240.0
const DEAD_ZONE := 14.0
# Within this distance the slime slows down, so it settles under the finger.
const EASE_DISTANCE := 60.0
const MARKER_Y := 1735.0

var enabled: bool = false
var finger: int = -1
var target_x: float = 540.0
var age: float = 0.0

func _ready() -> void:
	add_to_group("touch_steer")
	z_index = 4

func active() -> bool:
	return enabled and finger >= 0

func clear_input() -> void:
	finger = -1

## -1..1 toward the finger, easing off near it.
func direction_to(x: float) -> float:
	var dx := target_x - x
	if absf(dx) < DEAD_ZONE:
		return 0.0
	return clampf(dx / EASE_DISTANCE, -1.0, 1.0)

func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if get_tree().paused or GameManager.ended or not GameManager.started:
		clear_input()
		return
	if event is InputEventScreenTouch:
		var at := _to_world(event.position)
		if event.pressed and not event.canceled:
			# Touches on the top HUD (pause, sound) are for the buttons.
			if finger < 0 and at.y > TOP_LIMIT:
				finger = event.index
				target_x = at.x
		elif event.index == finger:
			finger = -1
	elif event is InputEventScreenDrag and event.index == finger:
		target_x = _to_world(event.position).x

func _to_world(point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * point

func _process(delta: float) -> void:
	age += delta
	if get_tree().paused or GameManager.ended or not GameManager.started:
		clear_input()
	queue_redraw()

func _draw() -> void:
	if not active():
		return
	# Soft ring on the floor where the slime is heading.
	var pulse := 1.0 + sin(age * 10.0) * 0.08
	var at := Vector2(target_x, MARKER_Y)
	draw_circle(at, 34.0 * pulse, Color(0.64, 1.0, 0.8, 0.16))
	draw_arc(at, 34.0 * pulse, 0, TAU, 32, Color(0.64, 1.0, 0.8, 0.75), 4.0)
