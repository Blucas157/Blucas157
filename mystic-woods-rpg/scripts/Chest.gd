extends StaticBody2D
## Treasure chest. Opens with the interact key; loot scales with the tier of its region.

var chest_id := ""
var tier := 0
var boss_chest := false
var opened := false
var sprite: AnimatedSprite2D
var shape: CollisionShape2D


func _ready() -> void:
	add_to_group("chests")
	collision_layer = 1
	collision_mask = 0
	shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 7)
	shape.shape = rect
	shape.position = Vector2(0, -3)
	add_child(shape)
	sprite = AnimatedSprite2D.new()
	var path := Sheets.MW + ("objects/chest_02.png" if tier >= 2 else "objects/chest_01.png")
	sprite.sprite_frames = Sheets.strip(path, 16, 16, 4, 10.0, false)
	sprite.offset = Vector2(0, -7)
	add_child(sprite)
	opened = Game.opened_chests.has(chest_id)
	sprite.frame = 3 if opened else 0
	if boss_chest:
		set_available(Game.boss_defeated)


func set_available(on: bool) -> void:
	visible = on
	shape.set_deferred("disabled", not on)


func can_open() -> bool:
	return visible and not opened


func open(main: Node) -> void:
	if not can_open():
		return
	opened = true
	sprite.play("default")
	Sfx.play("chest")
	Game.register_chest(chest_id)
	var gold := randi_range(10, 20) * (tier + 1)
	var bonus := ""
	if boss_chest:
		gold = 250
		Game.sword_tier += 2
		Game.max_hp += 20
		Game.heal(Game.max_hp)
		bonus = "Espada Lendária (+6 ataque) e +20 de vida máxima!"
	else:
		var r := randf()
		if tier >= 1 and r < 0.3:
			Game.sword_tier += 1
			bonus = "Espada melhorada! Ataque +3"
		elif r < 0.55:
			Game.max_hp += 5
			Game.heal(5)
			bonus = "Cristal de Vida! Vida máxima +5"
	if tier >= 1 or randf() < 0.5:
		main.drop_item(global_position + Vector2(0, 6), "potion")
	main.drop_coins(global_position + Vector2(0, 4), gold)
	main.hud.toast("Baú aberto: %d de ouro" % gold + ("\n" + bonus if bonus != "" else ""), Color(1.0, 0.85, 0.35))
	Game.stats_changed.emit()
	Game.save_game()
