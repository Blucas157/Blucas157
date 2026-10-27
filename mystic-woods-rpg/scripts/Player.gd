extends CharacterBody2D
## The hero: 8-way movement, sword attack, dash, potions and interaction.

signal died

const SPEED := 92.0
const DASH_SPEED := 250.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 0.55
const FX := preload("res://shaders/sprite_fx.gdshader")

var main: Node
var facing := Vector2.DOWN
var state := "move"   # move, attack, dash, dead
var attack_hit_done := false
var attack_cd := 0.0
var dash_t := 0.0
var dash_cd := 0.0
var skill_cd := 0.0
var skill_cds := {}        # skill id -> cooldown left
var buff_atk_t := 0.0      # Grito de Guerra
var wall_t := 0.0          # Muralha de Escudo
var charge_t := 0.0        # Investida
var charge_dir := Vector2.ZERO
var charged: Array = []
var spirits: Array = []    # Espíritos Famintos
var spirit_t := 0.0
var spirit_bites := {}
## Spell target: the nearest monster in range (soft), or the one the hero locked (tap / target button).
var target = null   # untyped on purpose: a monster can be freed while it is the target
var target_locked := false
const TARGET_RANGE := 150.0    # soft target: nearest monster within this
const LOCK_RANGE := 230.0      # a locked target is kept until it dies or gets this far
var dash_dir := Vector2.ZERO
var dust_t := 0.0
var invuln := 0.0
var knock := Vector2.ZERO
var flash_t := 0.0
var touch_move := Vector2.ZERO
var last_hit_by: Node = null   # the monster that landed the last blow (rivals remember it)
var sprite: AnimatedSprite2D
var mat: ShaderMaterial


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	shape.position = Vector2(0, -3)
	add_child(shape)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Sheets.character(Sheets.MW + "characters/player.png", 48, ["idle", "move", "attack"], ["death"],
		{"idle": 6, "move": 6, "attack": 4, "death": 3}, {"idle": 7.0, "move": 11.0, "attack": 15.0, "death": 5.0}, ["idle", "move"])
	sprite.offset = Vector2(0, -19)
	mat = ShaderMaterial.new()
	mat.shader = FX
	sprite.material = mat
	add_child(sprite)
	sprite.animation_finished.connect(_on_anim_finished)
	sprite.frame_changed.connect(_on_frame_changed)
	sprite.play("idle_down")


func alive() -> bool:
	return state != "dead"


func input_vector() -> Vector2:
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if touch_move.length() > 0.1:
		v = touch_move
	return v.limit_length(1.0)


func _physics_process(delta: float) -> void:
	attack_cd -= delta
	skill_cd -= delta
	for k in skill_cds:
		skill_cds[k] = float(skill_cds[k]) - delta
	buff_atk_t -= delta
	wall_t -= delta
	_update_spirits(delta)
	_update_target()
	dash_cd -= delta
	invuln -= delta
	flash_t = max(0.0, flash_t - delta)
	mat.set_shader_parameter("flash", 1.0 if flash_t > 0.0 else 0.0)
	sprite.self_modulate = Color(0.7, 0.85, 1.4) if wall_t > 0.0 else (Color(1.25, 0.85, 0.8) if buff_atk_t > 0.0 else Color.WHITE)
	sprite.modulate.a = 0.45 if invuln > 0.0 and state != "dash" and state != "dead" and int(invuln * 18.0) % 2 == 0 else 1.0
	var input := input_vector()
	match state:
		"dead":
			velocity = Vector2.ZERO
		"dash":
			dash_t -= delta
			velocity = dash_dir * DASH_SPEED
			dust_t -= delta
			if dust_t <= 0.0:
				dust_t = 0.04
				if main:
					main.spawn_dust(global_position)
			if dash_t <= 0.0:
				state = "move"
		"charge":
			# Investida: shield first, knocking down whatever stands in the way
			charge_t -= delta
			velocity = charge_dir * 260.0
			for e in _enemies_near(global_position + Vector2(0, -8), 14.0):
				if not e in charged:
					charged.append(e)
					e.knock = charge_dir * 260.0
					_hit(e, phys_damage(1.0, e), charge_dir, "melee")
			if charge_t <= 0.0:
				state = "move"
		"attack":
			velocity = input * move_speed() * 0.25 + knock
		_:
			if input.length() > 0.1:
				facing = input.normalized()
			velocity = input * move_speed() + knock
			_play_dir("move" if input.length() > 0.1 else "idle")
	knock = knock.move_toward(Vector2.ZERO, 700.0 * delta)
	move_and_slide()


func move_speed() -> float:
	return SPEED * (1.0 + Archetypes.bonus("speed") / 100.0)


func _play_dir(anim: String) -> void:
	var d := Sheets.dir_name(facing)
	sprite.flip_h = d == "side" and facing.x < 0.0
	var name := anim + "_" + d
	if sprite.animation != name or not sprite.is_playing():
		sprite.play(name)


func _unhandled_input(event: InputEvent) -> void:
	if state == "dead" or get_tree().paused:
		return
	if event.is_action_pressed("attack"):
		do_attack()
	elif event.is_action_pressed("dash"):
		do_dash()
	elif event.is_action_pressed("skill"):
		do_skill(0)
	elif event.is_action_pressed("skill2"):
		do_skill(1)
	elif event.is_action_pressed("skill3"):
		do_skill(2)
	elif event.is_action_pressed("target"):
		cycle_target()
	elif event.is_action_pressed("potion"):
		do_potion()
	elif event.is_action_pressed("interact"):
		do_interact()
	elif event.is_action_pressed("inventory") and main:
		main.open_inventory()


func do_attack() -> void:
	if state != "move" or attack_cd > 0.0:
		return
	var input := input_vector()
	if input.length() > 0.1:
		facing = input.normalized()
	state = "attack"
	attack_hit_done = false
	attack_cd = 0.32
	_play_dir("attack")
	sprite.frame = 0
	Sfx.play("swing")


## Active skills (Archetypes.gd): each button casts what is equipped in its slot.
func do_skill(slot: int = 0) -> void:
	if main == null:
		return
	var sk: String = Game.skill_slots[slot] if slot < Game.skill_slots.size() else ""
	if sk == "":
		if Game.skills.is_empty():
			main.hud.toast("Você ainda não conhece nenhuma magia", Color(0.8, 0.85, 1.0))
		else:
			main.hud.toast("Botão vazio: equipe uma habilidade em Arquétipos", Color(0.8, 0.85, 1.0))
		return
	cast(sk)


func cd_left(sk: String) -> float:
	return maxf(0.0, float(skill_cds.get(sk, 0.0)))


func cast(sk: String) -> bool:
	if state != "move" or main == null or skill_cd > 0.0 or cd_left(sk) > 0.0 or not Game.has_skill(sk):
		return false
	var d: Dictionary = Archetypes.SKILLS[sk]
	if not Game.spend_mana(int(d["cost"])):
		main.hud.toast("Mana insuficiente", Color(0.55, 0.7, 1.0))
		return false
	skill_cds[sk] = float(d["cd"])
	skill_cd = 0.25
	var input := input_vector()
	if input.length() > 0.1:
		facing = input.normalized()
	var origin := global_position + Vector2(0, -8)
	var dir := facing.normalized()
	if _target_ok(target):
		dir = (target.hurt_center() - origin).normalized()
		facing = dir
	if sk != "investida":
		state = "attack"
		attack_hit_done = true   # no sword hit on a cast
		attack_cd = 0.32
		_play_dir("attack")
		sprite.frame = 0
	var color: Color = Archetypes.DATA[d["arch"]]["color"]
	match sk:
		"fireball":
			var ball: Node = main.cast_fireball(origin + dir * 8.0, dir, spell_damage(1.0), false, self)
			if _target_ok(target):
				ball.homing = target
			Sfx.play("swing", 0.8)
		"golpe_giratorio":
			for k in 4:
				main.vfx("slash", origin, dir.angle() + k * PI / 2.0, Color.WHITE, null, 0.95)
			for e in _enemies_near(origin, 34.0):
				_hit(e, phys_damage(1.3, e), (e.global_position - global_position).normalized(), "melee")
			Sfx.play("swing", 0.7)
			main.shake(2.0, 0.1)
		"grito_guerra":
			buff_atk_t = 8.0
			main.float_text(global_position + Vector2(0, -30), "GRITO DE GUERRA!", color)
			main.vfx("heal", Vector2(0, 2), 0.0, Color(1.4, 0.5, 0.4), self)
			Sfx.play("boss", 1.3)
		"flecha":
			var arrow: Node = main.cast_arrow(origin + dir * 8.0, dir, phys_damage(1.2), self)
			arrow.pierce = true
			Sfx.play("swing", 1.4)
		"chuva_flechas":
			for k in 5:
				main.cast_arrow(origin + dir * 8.0, dir.rotated((k - 2) * 0.2), phys_damage(0.9), self)
			Sfx.play("swing", 1.3)
		"explosao_arcana":
			var at := origin + dir * 48.0
			if _target_ok(target) and target.global_position.distance_to(global_position) < 170.0:
				at = target.hurt_center()
			main.vfx("fireburst", at, 0.0, Color(0.75, 0.65, 1.4), null, 1.1)
			for e in _enemies_near(at, 38.0):
				_hit(e, spell_damage(1.6), (e.global_position - at).normalized(), "magic")
			main.shake(2.5, 0.15)
			Sfx.play("hit", 0.6)
		"luz_curativa":
			var amount := int(Game.max_hp * 0.3)
			Game.heal(amount)
			main.float_text(global_position + Vector2(0, -28), "+%d" % amount, Color(1.0, 0.95, 0.6))
			main.vfx("heal", Vector2(0, 2), 0.0, Color(1.4, 1.25, 0.6), self)
			Sfx.play("potion", 1.2)
		"julgamento":
			for k in 6:
				main.vfx("hit", origin + Vector2.from_angle(TAU * k / 6.0) * 30.0, 0.0, Color(1.4, 1.3, 0.6), null, 0.8)
			for e in _enemies_near(origin, 50.0):
				var dm := phys_damage(1.2, e) * (2 if e.faction == "mortos" else 1)
				_hit(e, dm, (e.global_position - global_position).normalized(), "magic")
			main.shake(2.0, 0.12)
			Sfx.play("level", 1.4)
		"muralha":
			wall_t = 5.0
			main.float_text(global_position + Vector2(0, -30), "MURALHA!", color)
			Sfx.play("break", 0.7)
		"investida":
			state = "charge"
			charge_t = 0.28
			charge_dir = dir
			charged.clear()
			invuln = maxf(invuln, 0.35)
			_play_dir("move")
			Sfx.play("dash", 0.8)
		"maldicao":
			var at2 := origin + dir * 40.0
			if _target_ok(target) and target.global_position.distance_to(global_position) < 170.0:
				at2 = target.hurt_center()
			main.vfx("puff", at2, 0.0, Color(0.9, 0.5, 1.3), null, 1.6)
			for e in _enemies_near(at2, 50.0):
				e.curse_t = 6.0
				main.vfx("puff", e.hurt_center(), 0.0, Color(0.8, 0.4, 1.2), null, 0.8)
			Sfx.play("death", 1.4)
		"espiritos":
			_summon_spirits()
			Sfx.play("select", 0.6)
		"raizes":
			var at3 := origin + dir * 40.0
			if _target_ok(target) and target.global_position.distance_to(global_position) < 170.0:
				at3 = target.hurt_center()
			for e in _enemies_near(at3, 50.0):
				e.root_t = 3.0
				main.vfx("heal", Vector2(0, 2), 0.0, Color(0.5, 1.3, 0.5), e)
			main.vfx("heal", at3 + Vector2(0, 8), 0.0, Color(0.5, 1.3, 0.5), null, 1.3)
			Sfx.play("break", 1.2)
		"tempestade":
			var list: Array = []
			for e in get_tree().get_nodes_in_group("enemies"):
				if e.alive() and e.global_position.distance_to(global_position) < 150.0:
					list.append(e)
			list.sort_custom(func(a, b): return a.global_position.distance_to(global_position) < b.global_position.distance_to(global_position))
			for e in list.slice(0, 3):
				main.vfx("bolt", e.hurt_center(), 0.0, Color(0.7, 0.95, 1.4))
				main.vfx("hit", e.hurt_center(), randf() * TAU, Color(0.7, 0.95, 1.4), null, 0.9)
				_hit(e, spell_damage(1.2), Vector2.DOWN, "magic")
			main.shake(3.0, 0.15)
			Sfx.play("slam", 1.6)
	return true


func _enemies_near(at: Vector2, r: float) -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.alive() and e.body_distance(at) <= r + e.radius:
			out.append(e)
	return out


func _hit(e: Node, dmg: int, dir: Vector2, kind: String) -> void:
	e.take_hit(maxi(1, dmg), dir, false, kind)


## Damage multipliers from archetype passives and buffs.
func dmg_mult(e = null) -> float:
	var m := 1.0
	if buff_atk_t > 0.0:
		m *= 1.3
	if Archetypes.bonus("fury") > 0.0 and Game.hp < Game.max_hp / 2:
		m *= 1.25
	if Game.night_now() and Archetypes.bonus("night_power") > 0.0:
		m *= 1.2
	if e != null and is_instance_valid(e) and Archetypes.bonus("far_dmg") > 0.0 and e.global_position.distance_to(global_position) > 60.0:
		m *= 1.0 + Archetypes.bonus("far_dmg") / 100.0
	return m


func phys_damage(mult: float, e = null) -> int:
	return int(round((Game.attack_power() + randi_range(0, 2)) * mult * dmg_mult(e)))


func spell_damage(mult: float) -> int:
	return int(round(Game.skill_damage("fireball") * mult * (1.0 + Archetypes.bonus("spell_dmg") / 100.0) * dmg_mult()))


func crit_chance() -> float:
	return 0.1 + Archetypes.bonus("crit") / 100.0


## Espíritos Famintos: three spirits circle the hero and bite whatever they touch.
func _summon_spirits() -> void:
	for sp in spirits:
		if is_instance_valid(sp):
			sp.queue_free()
	spirits.clear()
	spirit_t = 8.0
	for k in 3:
		var a := AnimatedSprite2D.new()
		a.sprite_frames = Sheets.strip("res://assets/vfx/fireball.png", 24, 24, 8, 12.0, true)
		a.play("default")
		a.scale = Vector2(0.55, 0.55)
		a.modulate = Color(0.75, 0.55, 1.4, 0.9)
		a.z_index = 5
		add_child(a)
		spirits.append(a)


func _update_spirits(delta: float) -> void:
	if spirits.is_empty():
		return
	spirit_t -= delta
	if spirit_t <= 0.0:
		for sp in spirits:
			if is_instance_valid(sp):
				sp.queue_free()
		spirits.clear()
		return
	for k in spirits.size():
		var sp: Node2D = spirits[k]
		sp.position = Vector2(0, -8) + Vector2.from_angle(spirit_t * 4.0 + TAU * k / 3.0) * 26.0
		for e in _enemies_near(sp.global_position, 8.0):
			var key: int = e.get_instance_id()
			if float(spirit_bites.get(key, 0.0)) <= spirit_t:
				spirit_bites[key] = spirit_t - 0.5
				_hit(e, phys_damage(0.6), (e.global_position - global_position).normalized(), "magic")


func _target_ok(e) -> bool:
	return is_instance_valid(e) and e.is_in_group("enemies") and e.alive()


func _update_target() -> void:
	if target_locked:
		if _target_ok(target) and target.global_position.distance_to(global_position) <= LOCK_RANGE:
			return
		target_locked = false
	target = _nearest_enemy(TARGET_RANGE)


func _nearest_enemy(within: float) -> Node:
	var best: Node = null
	var bd := within
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = e.global_position.distance_to(global_position)
		if e.alive() and d < bd:
			bd = d
			best = e
	return best


## Locks the spell target on this monster (tapped on screen).
func lock_on(e) -> void:
	if _target_ok(e):
		target = e
		target_locked = true


## Target button / key: locks the nearest monster, then cycles through the others by distance;
## past the last one it unlocks.
func cycle_target() -> void:
	var list: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.alive() and e.global_position.distance_to(global_position) <= LOCK_RANGE:
			list.append(e)
	list.sort_custom(func(a, b): return a.global_position.distance_to(global_position) < b.global_position.distance_to(global_position))
	if list.is_empty():
		target_locked = false
		target = null
		if main:
			main.hud.toast("Nenhum alvo por perto", Color(0.8, 0.85, 1.0))
		return
	if not target_locked or not _target_ok(target):
		lock_on(list[0])
		return
	var i: int = list.find(target)
	if i == list.size() - 1:
		target_locked = false
		target = _nearest_enemy(TARGET_RANGE)
	else:
		lock_on(list[i + 1])


func do_dash() -> void:
	if state != "move" or dash_cd > 0.0:
		return
	var input := input_vector()
	dash_dir = input.normalized() if input.length() > 0.1 else facing.normalized()
	facing = dash_dir
	state = "dash"
	dash_t = DASH_TIME
	dash_cd = DASH_COOLDOWN * (1.0 - Archetypes.bonus("dash_cd") / 100.0)
	invuln = max(invuln, DASH_TIME + 0.05)
	_play_dir("move")
	Sfx.play("dash")
	_buzz(25)


func do_potion() -> void:
	if Game.use_potion():
		Sfx.play("potion")
		if main:
			main.float_text(global_position + Vector2(0, -28), "+VIDA", Color(0.5, 1.0, 0.5))
			main.vfx("heal", Vector2(0, 2), 0.0, Color.WHITE, self)
	elif main:
		main.hud.toast("Sem poções" if Game.potions <= 0 else "Vida cheia", Color(1, 0.7, 0.6))


func do_interact() -> void:
	if main:
		main.interact(self)


func attack_dir() -> Vector2:
	match Sheets.dir_name(facing):
		"side":
			return Vector2(sign(facing.x), 0)
		"up":
			return Vector2.UP
	return Vector2.DOWN


func _on_frame_changed() -> void:
	if state == "attack" and not attack_hit_done and sprite.frame >= 1:
		attack_hit_done = true
		_apply_attack()


func _apply_attack() -> void:
	var dir := attack_dir()
	var center := global_position + Vector2(0, -8) + dir * 14.0
	if main:
		main.vfx("slash", global_position + Vector2(0, -8) + dir * 3.0, dir.angle(), Color.WHITE, null, 0.85)
	var hit_any := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.alive():
			continue
		if e.hurt_center().distance_to(center) <= 18.0 + e.radius:
			var dmg := phys_damage(1.0, e)
			var crit := randf() < crit_chance()
			if crit:
				dmg = int(dmg * 1.8)
			e.take_hit(dmg, (e.global_position - global_position).normalized(), crit)
			hit_any = true
	for r in get_tree().get_nodes_in_group("resources"):
		if (r.global_position + Vector2(0, -6)).distance_to(center) <= 18.0 and main:
			r.hit(main)
			hit_any = true
	for c in get_tree().get_nodes_in_group("camps"):
		if (c.global_position + Vector2(0, -12)).distance_to(center) <= 22.0:
			c.hit(Game.attack_power())
			hit_any = true
	for b in get_tree().get_nodes_in_group("breakables"):
		if (b.global_position + Vector2(0, -6)).distance_to(center) <= 20.0 and main:
			main.break_object(b)
			hit_any = true
	if hit_any and main:
		main.shake(1.5, 0.08)
		_buzz(15)


func _on_anim_finished() -> void:
	if state == "attack":
		state = "move"
		_play_dir("idle")
	elif state == "dead":
		died.emit()


func take_damage(amount: int, from: Vector2) -> void:
	if state == "dead" or state == "dash" or state == "charge" or invuln > 0.0:
		return
	if wall_t > 0.0:
		amount = int(ceil(amount * 0.4))   # Muralha de Escudo
	# Contra-ataque (Escudo): sometimes half of the blow goes back
	if Archetypes.bonus("counter") > 0.0 and is_instance_valid(last_hit_by) and last_hit_by.alive() \
			and last_hit_by.global_position.distance_to(global_position) < 50.0 and randf() < Archetypes.bonus("counter") / 100.0:
		last_hit_by.take_hit(maxi(1, amount / 2), (last_hit_by.global_position - global_position).normalized(), false, "melee")
		if main:
			main.float_text(global_position + Vector2(0, -36), "Contra!", Color(0.6, 0.85, 1.0))
	var dmg := Game.damage_player(amount)
	invuln = 0.9
	flash_t = 0.12
	if Archetypes.bonus("steadfast") <= 0.0:
		knock = (global_position - from).normalized() * 170.0
	Sfx.play("hurt")
	_buzz(60)
	if main:
		main.float_text(global_position + Vector2(0, -28), str(dmg), Color(1.0, 0.35, 0.35))
		main.vfx("hit", global_position + Vector2(0, -10), 0.0, Color(1.0, 0.55, 0.55), null, 0.6)
		main.shake(3.0, 0.15)
	if Game.hp <= 0:
		_die()


## Short phone vibration as feedback (touch devices only; needs the VIBRATE permission on export).
func _buzz(ms: int) -> void:
	if main and main.is_touch():
		Input.vibrate_handheld(ms)


func _die() -> void:
	state = "dead"
	sprite.flip_h = false
	sprite.play("death")
	Sfx.play("death")


func revive(at: Vector2) -> void:
	global_position = at
	state = "move"
	invuln = 2.0
	knock = Vector2.ZERO
	facing = Vector2.DOWN
	_play_dir("idle")
