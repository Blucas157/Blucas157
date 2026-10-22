extends Node2D

@export var direction: int = -1
var touches: Dictionary = {}
var mouse_held: bool = false
# Fingers currently on the screen, anywhere. Shared by both arrows.
static var fingers_down: Dictionary = {}
var face: Texture2D = preload("res://Assets/UI/btn_arrow.png")

func _ready() -> void:
	add_to_group("direction_buttons")
	z_index = 5

func is_held() -> bool:
	return mouse_held or not touches.is_empty()

func clear_input() -> void:
	touches.clear()
	mouse_held = false

func _contains(point: Vector2) -> bool:
	var local := get_global_transform_with_canvas().affine_inverse() * point
	return Rect2(-125, -112, 250, 224).has_point(local)

func _input(event: InputEvent) -> void:
	# GUI gets the emulated mouse from touch; arrows already handle the native touch.
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			fingers_down[event.index] = true
			# A finger takes over from any mouse state.
			mouse_held = false
		else:
			fingers_down.erase(event.index)
	# Web browsers also report finger moves as mouse motion carrying the touch's
	# pressed button, with no release when the finger lifts; that left an arrow
	# stuck as held. While a finger is down, mouse events are only that echo.
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and not fingers_down.is_empty():
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
	# Only shown while playing, so menus and shops are not covered.
	visible = GameManager.started and not GameManager.ended and not get_tree().paused
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		clear_input()

func _draw() -> void:
	var held := is_held()
	# The PixelLab arrow points left; mirror it for the right button and sink it while held.
	var size := face.get_size()
	var squash := Vector2(0.94, 0.9) if held else Vector2.ONE
	draw_set_transform(Vector2(0, 10 if held else 0), 0.0, Vector2(-direction, 1) * squash)
	draw_texture(face, -size / 2.0, Color(1.25, 1.35, 1.3) if held else Color(1, 1, 1, 0.92))
	draw_set_transform(Vector2.ZERO)
