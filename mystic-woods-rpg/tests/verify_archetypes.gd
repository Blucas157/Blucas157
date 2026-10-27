extends SceneTree
## Archetypes (Ravendawn style): points per level, up to three trees, class names, every active
## skill and the main passives, reset and save.
## Run: godot --headless --path . -s res://tests/verify_archetypes.gd   (xvfb-run ... -- <dir>: screenshots)

var main: Node
var game: Node
var A
var failures := 0
var out_dir := ""
var spot := Vector2.ZERO


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	print(("ok  - " if ok else "FAIL- ") + what)
	if not ok:
		failures += 1


func shot(name: String) -> void:
	if out_dir == "":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func clear_enemies() -> void:
	for e in get_nodes_in_group("enemies"):
		if e != main.boss:
			e.free()


func dummy(off: Vector2, id := "orc") -> Node:
	var e: Node = main.spawn_enemy(id, spot + off, 3)
	e.flee_rolled = true
	e.def = e.def.duplicate()
	e.def["aggro"] = 0.0
	e.max_hp = 9999
	e.hp = 9999
	e.atk = 0   # harmless training dummy
	return e


func ready_to_cast(p: Node) -> void:
	p.state = "move"
	p.skill_cd = 0.0
	p.skill_cds.clear()
	game.mp = game.max_mp


func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
		DirAccess.make_dir_recursive_absolute(out_dir)
	game = root.get_node("Game")
	A = load("res://scripts/Archetypes.gd")
	game.save_path = "user://arch_test_save.cfg"
	game.muted = true
	main = load("res://scenes/main.tscn").instantiate()
	main.touch_override = 1
	root.add_child(main)
	await create_timer(0.3).timeout
	main.start_game(true)
	game.day_time = 0.3
	await create_timer(0.3).timeout
	clear_enemies()
	var p: Node = main.player
	spot = main.world.cell_to_pos(WorldGen.CENTER + Vector2i(40, 0))
	p.global_position = spot
	main.camera.global_position = spot
	main.camera.reset_smoothing()

	# 1) points and the pyramid
	game.level = 12
	check(A.points_free() == 11, "one point per level (11 at level 12)")
	check(A.can_learn("g_grito").begins_with("Precisa"), "advanced tiers need points in the tree first")
	var atk0: int = game.attack_power()
	check(A.learn("g_giro") and game.has_skill("golpe_giratorio") and game.skill_slots[0] == "golpe_giratorio", "Guerra: Golpe Giratório learned and put on button 1")
	for k in 3:
		A.learn("g_forca")
	check(game.attack_power() == atk0 + 6, "Força Bruta 3/3: +6 attack")
	check(A.learn("g_grito"), "after 4 points the advanced skill opens (Grito de Guerra)")
	check(game.class_title() == "Guerreiro", "one archetype: " + game.class_title())
	var hp0: int = game.max_hp
	A.learn("s_luz")
	A.learn("s_bencao")
	check(game.max_hp == hp0 + 6, "Bênção: +6 max life")
	check(game.class_title() == "Paladino", "Guerra + Sagrado: " + game.class_title())
	A.learn("a_flecha")
	check(game.class_title() == "Patrulheiro Sagrado", "three archetypes: " + game.class_title())
	check(A.can_learn("m_fogo").begins_with("Máx. 3 arquétipos"), "a fourth archetype is refused")
	check(A.points_free() == 11 - 8, "points spent (%d left)" % A.points_free())

	# 2) every active skill does its job
	game.level = 40
	var all := ["guerra", "arqueria", "sagrado"]
	game.archetypes = []
	for arch in A.ORDER:
		for id in A.nodes_of(arch):
			if A.NODES[id]["kind"] == "active":
				game.learn_skill(A.NODES[id]["skill"])
	game.archetypes = all
	# Golpe Giratório hits all around
	var e1: Node = dummy(Vector2(20, 0))
	var e2: Node = dummy(Vector2(-20, 0))
	await process_frame
	ready_to_cast(p)
	check(p.cast("golpe_giratorio") and e1.hp < 9999 and e2.hp < 9999, "Golpe Giratório hits on both sides")
	clear_enemies()
	# Grito de Guerra boosts damage
	ready_to_cast(p)
	var before: int = p.phys_damage(1.0)
	p.cast("grito_guerra")
	check(p.buff_atk_t > 0.0 and p.dmg_mult() >= 1.29, "Grito de Guerra: +30% damage")
	p.buff_atk_t = 0.0
	# Flecha Certeira pierces two in a row
	var a1: Node = dummy(Vector2(40, -8))
	var a2: Node = dummy(Vector2(70, -8))
	await process_frame
	ready_to_cast(p)
	p.target = null
	p.target_locked = false
	p.facing = Vector2.RIGHT
	p.cast("flecha")
	await create_timer(0.5).timeout
	check(a1.hp < 9999 and a2.hp < 9999, "Flecha Certeira pierces through two monsters")
	clear_enemies()
	await process_frame
	ready_to_cast(p)
	p.facing = Vector2.RIGHT
	var arrows: int = main.fx_layer.get_child_count()
	p.cast("chuva_flechas")
	check(main.fx_layer.get_child_count() - arrows == 5, "Chuva de Flechas: five arrows")
	await create_timer(0.6).timeout
	# Explosão Arcana on the locked target
	var t1: Node = dummy(Vector2(90, 0))
	await process_frame
	p.lock_on(t1)
	ready_to_cast(p)
	p.cast("explosao_arcana")
	check(t1.hp < 9999, "Explosão Arcana bursts on the locked target")
	clear_enemies()
	# Luz Curativa heals
	ready_to_cast(p)
	game.hp = 5
	p.cast("luz_curativa")
	check(game.hp > 5, "Luz Curativa heals (%d)" % game.hp)
	# Julgamento: double against the undead
	var undead: Node = dummy(Vector2(20, 0), "skeleton")
	var living: Node = dummy(Vector2(-20, 0), "orc")
	await process_frame
	ready_to_cast(p)
	p.cast("julgamento")
	check((9999 - undead.hp) > (9999 - living.hp), "Julgamento hurts the undead more (%d vs %d)" % [9999 - undead.hp, 9999 - living.hp])
	clear_enemies()
	# Muralha de Escudo: much less damage taken
	ready_to_cast(p)
	game.hp = game.max_hp
	p.invuln = 0.0
	p.take_damage(20, p.global_position + Vector2(10, 0))
	var normal_loss: int = game.max_hp - game.hp
	game.hp = game.max_hp
	p.cast("muralha")
	p.invuln = 0.0
	p.take_damage(20, p.global_position + Vector2(10, 0))
	check(game.max_hp - game.hp < normal_loss, "Muralha de Escudo: less damage (%d vs %d)" % [game.max_hp - game.hp, normal_loss])
	p.wall_t = 0.0
	game.hp = game.max_hp
	# Investida: charges forward and hits
	await create_timer(1.0).timeout
	var c1: Node = dummy(Vector2(40, 0))
	await process_frame
	p.lock_on(c1)
	ready_to_cast(p)
	var x0: float = p.global_position.x
	p.cast("investida")
	await create_timer(0.4).timeout
	check(p.global_position.x > x0 + 30.0 and c1.hp < 9999, "Investida charges forward and hits")
	clear_enemies()
	p.global_position = spot
	# Maldição and Raízes
	var m1: Node = dummy(Vector2(40, 0))
	await process_frame
	p.lock_on(m1)
	ready_to_cast(p)
	p.cast("maldicao")
	check(m1.curse_t > 0.0, "Maldição curses the target")
	var hp_c: int = m1.hp
	m1.take_hit(20, Vector2.RIGHT)
	check(hp_c - m1.hp == 25, "cursed monsters take +25% damage")
	ready_to_cast(p)
	p.cast("raizes")
	check(m1.root_t > 0.0, "Raízes root the target")
	clear_enemies()
	# Espíritos Famintos
	ready_to_cast(p)
	var s1: Node = dummy(Vector2(26, -8))
	await process_frame
	p.cast("espiritos")
	check(p.spirits.size() == 3, "three hungry spirits circle the hero")
	await create_timer(1.6).timeout
	check(s1.hp < 9999, "the spirits bite what they touch")
	clear_enemies()
	# Tempestade
	var st1: Node = dummy(Vector2(60, 0))
	var st2: Node = dummy(Vector2(-60, 0))
	await process_frame
	ready_to_cast(p)
	p.cast("tempestade")
	check(st1.hp < 9999 and st2.hp < 9999, "Tempestade strikes several monsters")
	await create_timer(0.1).timeout
	await shot("arch_01_storm")
	clear_enemies()

	# 3) touch buttons follow the slots
	game.skill_slots = ["golpe_giratorio", "flecha", "luz_curativa"]
	var b: Dictionary = main.touch._buttons()
	check(b.has("skill0") and b.has("skill1") and b.has("skill2"), "three skill buttons on screen")
	ready_to_cast(p)
	var ev := InputEventScreenTouch.new()
	ev.index = 2
	ev.position = b["skill2"][0]
	ev.pressed = true
	game.hp = 10
	main.touch._input(ev)
	ev.pressed = false
	main.touch._input(ev)
	check(game.hp > 10, "the third button casts what is equipped (Luz Curativa)")
	await create_timer(0.2).timeout
	await shot("arch_02_buttons")

	# 4) the archetype screen
	main.set_paused(true)
	main.hud.arch_tab = "sagrado"
	main.hud.show_archetypes()
	await create_timer(0.3).timeout
	await shot("arch_03_screen")
	main.set_paused(false)

	# 4b) Copista (Ctrl+C / Ctrl+V): copy the Pyromancer's fireball and paste it
	clear_enemies()
	game.level = 30
	A.reset()
	game.skills = []
	game.skill_slots = ["", "", ""]
	check(A.learn("c_copiar") and A.learn("c_colar"), "Copista: Copiar and Colar learned")
	check(game.class_title() == "Copista", "class: " + game.class_title())
	var pyro: Node = dummy(Vector2(80, 0), "skeleton_pyro")
	await process_frame
	p.lock_on(pyro)
	ready_to_cast(p)
	check(not game.has_skill("fireball"), "the hero does not know the fireball")
	p.cast("copiar")
	check(game.copied == "fireball", "Ctrl+C on the Pyromancer copies the Bola de Fogo")
	ready_to_cast(p)
	var balls: int = main.fx_layer.get_child_count()
	check(p.cast("colar") and main.fx_layer.get_child_count() > balls, "Ctrl+V casts the copied fireball")
	await create_timer(0.8).timeout
	check(pyro.hp < 9999, "the pasted fireball burns")
	clear_enemies()
	var spider: Node = dummy(Vector2(60, 0), "spider")
	await process_frame
	p.lock_on(spider)
	ready_to_cast(p)
	p.cast("copiar")
	check(game.copied == "raizes", "Ctrl+C on a spider copies its web (Raízes)")
	clear_enemies()
	A.learn("c_memoria")
	A.learn("c_memoria")
	check(A.learn("c_massa"), "Colar em Massa opens after 4 points")
	game.copied = "fireball"
	ready_to_cast(p)
	var before_mass: int = main.fx_layer.get_child_count()
	check(p.cast("colar_massa") and main.fx_layer.get_child_count() - before_mass == 3, "Colar em Massa: three fireballs")
	await create_timer(0.6).timeout
	A.learn("c_reflexo")
	game.copied = ""
	var shooter: Node = dummy(Vector2(70, 0), "skeleton_pyro")
	await process_frame
	p.invuln = 0.0
	main.cast_fireball(p.global_position + Vector2(20, -8), Vector2.LEFT, 10, true, shooter)
	await create_timer(0.5).timeout
	check(game.copied == "fireball", "Reflexo Copiado: the fireball that hit the hero was copied")
	clear_enemies()
	A.learn("c_reflexo")
	check(A.learn("c_tudo"), "capstone Copiar Tudo (Ctrl+A)")
	var golem: Node = dummy(Vector2(50, 0), "golem")
	await process_frame
	p.lock_on(golem)
	ready_to_cast(p)
	p.buff_atk_t = 0.0
	p.cast("copiar")
	check(game.copied == "muralha" and p.buff_atk_t > 0.0, "Ctrl+A: copies the golem's stone skin and its strength")
	p.buff_atk_t = 0.0
	clear_enemies()
	game.skill_slots = ["copiar", "colar", "colar_massa"]
	main.set_paused(true)
	main.hud.arch_tab = "copista"
	main.hud.show_archetypes()
	await create_timer(0.3).timeout
	await shot("arch_04_copista")
	main.set_paused(false)
	await create_timer(0.2).timeout
	await shot("arch_05_copista_buttons")

	# 4c) Mago: learns every spell (Grimório, Biblioteca), Míssil Arcano and Teleporte
	A.reset()
	game.skills = []
	game.skill_slots = ["", "", ""]
	check(A.learn("o_missil") and game.class_title() == "Mago", "Mago: Míssil Arcano (class %s)" % game.class_title())
	var mt: Node = dummy(Vector2(90, 20))
	await process_frame
	p.lock_on(mt)
	ready_to_cast(p)
	p.facing = Vector2.UP
	p.cast("missil_arcano")
	await create_timer(0.9).timeout
	check(mt.hp < 9999, "the arcane missile homes in on the target")
	clear_enemies()
	A.learn("g_giro")
	A.learn("s_luz")
	check(game.archetypes.size() == 3, "three archetypes (Mago, Guerra, Sagrado)")
	check(A.can_learn("a_flecha").begins_with("Máx"), "a fourth archetype's spell is closed without the Grimório")
	A.learn("o_grimorio")
	check(A.can_learn("a_flecha") == "" and A.learn("a_flecha") and game.has_skill("flecha"), "Grimório: learns Flecha Certeira from Arqueria anyway")
	check(game.archetypes.size() == 3 and not "arqueria" in game.archetypes, "the class keeps its three archetypes")
	check(A.can_learn("p_tempestade") != "", "advanced foreign spells still need the Biblioteca")
	A.learn("o_sabedoria")
	A.learn("o_sabedoria")
	check(A.learn("o_teleporte"), "Teleporte opens")
	p.global_position = spot
	ready_to_cast(p)
	p.target = null
	p.target_locked = false
	p.facing = Vector2.RIGHT
	var tx0: float = p.global_position.x
	p.cast("teleporte")
	check(p.global_position.x > tx0 + 30.0, "Teleporte blinks ahead (%.0f px)" % (p.global_position.x - tx0))
	p.global_position = spot
	A.learn("o_grimorio")
	check(A.can_learn("c_copiar") == "", "the Grimório can even learn the Copista's Ctrl+C")
	check(A.learn("o_biblioteca"), "capstone Biblioteca Infinita")
	check(A.can_learn("p_tempestade") == "" and A.learn("p_tempestade"), "Biblioteca Infinita: any spell of any archetype")
	game.level = 12

	# 5) reset gives the points back, keeps the orb skill; saved
	game.level = 12
	game.skills.append("fireball")
	game.orb_skills.append("fireball")
	A.reset()
	check(A.points_free() == 11 and game.archetypes.is_empty(), "reset returns every point")
	check(game.has_skill("fireball") and not game.has_skill("golpe_giratorio") and game.copied == "", "reset removes skills and the copy, keeps the orb's fireball")
	var hp_b: int = game.max_hp
	A.learn("s_luz")
	A.learn("s_bencao")
	A.reset()
	check(game.max_hp == hp_b, "reset takes passive life back")
	A.learn("e_muralha")
	A.learn("e_pele")
	game.save_game()
	game.arch_ranks = {}
	game.archetypes = []
	game.load_game()
	check(A.rank("e_pele") == 1 and game.class_title() == "Guardião", "archetypes survive save/load")

	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
