extends Node2D

@export var direction: int = -1
var touches: Dictionary = {}
var mouse_held: bool = false
var box: StyleBoxFlat

func _ready() -> void:
	add_to_group("direction_buttons")
	z_index = 5
	box = StyleBoxFlat.new()
	box.set_border_width_all(5)
	box.set_corner_radius_all(18)

func is_held() -> bool:
	return mouse_held or not touches.is_empty()

func clear_input() -> void:
	touches.clear()
	mouse_held = false

func _contains(point: Vector2) -> bool:
	var local := get_global_transform_with_canvas().affine_inverse() * point
	return Rect2(-125, -90, 250, 180).has_point(local)

func _input(event: InputEvent) -> void:
	# GUI gets the emulated mouse from touch; arrows already handle the native touch.
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if get_tree().paused or GameManager.ended or not GameManager.started:
		clear_input()
		return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled and _contains(event.position):
			touches[event.index] = true
		else:
			touches.erase(event.index)
	elif event is InputEventScreenDrag:
		if _contains(event.position):
			touches[event.index] = true
		else:
			touches.erase(event.index)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_held = event.pressed and _contains(event.position)
	elif event is InputEventMouseMotion:
		mouse_held = (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and _contains(event.position)

func _process(_delta: float) -> void:
	if get_tree().paused or GameManager.ended or not GameManager.started:
		clear_input()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		clear_input()

func _draw() -> void:
	var held := is_held()
	box.border_color = Color("a3ffce") if held else Color("51858c")
	box.bg_color = Color("26756a") if held else Color("172d40")
	draw_style_box(box, Rect2(-125, -90, 250, 180))
	var arrow := PackedVector2Array([
		Vector2(-43, 0), Vector2(7, -40), Vector2(7, -17),
		Vector2(44, -17), Vector2(44, 17), Vector2(7, 17), Vector2(7, 40)
	])
	for i in arrow.size():
		arrow[i].x *= -direction
		arrow[i].y += 6.0 if held else 0.0
	draw_colored_polygon(arrow, Color("e5fff1"))


