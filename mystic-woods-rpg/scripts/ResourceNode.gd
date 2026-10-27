extends StaticBody2D
## Ore vein or plant. Ores are mined with sword/pickaxe swings, plants are picked (E or a swing).
## Both regrow after a while.

var type := ""
var def := {}
var hits_left := 0
var depleted := false
var regrow_t := 0.0
var sprite: Sprite2D
var shake_t := 0.0


func setup(t: String) -> void:
	type = t
	def = ItemDB.RESOURCES[t]


func _ready() -> void:
	add_to_group("resources")
	collision_mask = 0
	# flowers, herbs, mushrooms and bushes are walked through; only ore veins and trees block
	collision_layer = 1 if ItemDB.resource_solid(type) else 0
	if ItemDB.resource_solid(type):
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(16, 7) if is_ore() else Vector2(10, 5)
		shape.shape = rect
		shape.position = Vector2(0, -3)
		add_child(shape)
	sprite = Sprite2D.new()
	sprite.texture = Sheets.tex(ItemDB.NODES)
	sprite.region_enabled = true
	sprite.offset = Vector2(0, -13)
	add_child(sprite)
	_refresh()


func is_ore() -> bool:
	return def.get("ore", false)


func _refresh() -> void:
	hits_left = max(1, int(def["hits"]))
	var frame: int = def["frame"]
	if depleted:
		frame = def["empty"]
	sprite.visible = frame >= 0
	if frame >= 0:
		sprite.region_rect = ItemDB.node_rect(frame)
	modulate.a = 1.0


func _process(delta: float) -> void:
	if shake_t > 0.0:
		shake_t -= delta
		sprite.position.x = (1.0 if int(shake_t * 40.0) % 2 == 0 else -1.0) if shake_t > 0.0 else 0.0
	if depleted:
		regrow_t -= delta
		if regrow_t <= 0.0:
			depleted = false
			_refresh()


func can_pick() -> bool:
	return not depleted and not is_ore()


## Called by a sword swing (ores and plants) or by interacting (plants).
func hit(main: Node) -> void:
	if depleted:
		return
	if is_ore():
		var need: int = def["tier"]
		if Game.tool_tier < need:
			main.hud.toast("Precisa de %s" % ItemDB.TOOL_NAMES[need], Color(1, 0.7, 0.6))
			shake_t = 0.15
			Sfx.play("hit", 0.6)
			return
		hits_left -= 2 if Game.tool_tier >= 3 else 1
		shake_t = 0.15
		Sfx.play("break", 1.4)
		main.spawn_dust(global_position)
		if hits_left > 0:
			return
	else:
		Sfx.play("coin", 0.8)
	_harvest(main)


func _harvest(main: Node) -> void:
	var a: Array = def["amount"]
	var n := randi_range(int(a[0]), int(a[1]))
	if is_ore() and Game.tool_tier >= 3 and randf() < 0.35:
		n += 1
	main.drop_material(global_position + Vector2(0, -4), def["item"], n)
	depleted = true
	regrow_t = float(def["regrow"]) * randf_range(0.8, 1.2)
	_refresh()
