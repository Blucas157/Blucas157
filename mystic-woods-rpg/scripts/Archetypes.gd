class_name Archetypes
## Archetypes (inspired by Ravendawn): seven skill trees shaped like a pyramid. The hero earns a
## point per level, can pick up to three archetypes, and their combination names the class.
## Each tree: tier 1 = an active skill, tier 2 = two passives (3 ranks), tier 3 = an advanced
## active, tier 4 = a capstone passive. A tier opens after enough points in that tree.
## State lives in Game (archetypes, arch_ranks, skills, skill_slots); this file holds the rules.

const MAX_ARCHETYPES := 3
const TIER_NEED := [0, 1, 4, 6]   # points spent in the tree to open tiers 1..4
const SLOTS := 3                  # active skill buttons

## id -> name, colour, class title (alone) and adjective (as third archetype)
const DATA := {
	"guerra": {"name": "Guerra", "color": Color("bc4952"), "title": "Guerreiro", "adj": "de Guerra",
		"desc": "Lâmina e fúria: golpes em área e força bruta."},
	"arqueria": {"name": "Arqueria", "color": Color("53a03b"), "title": "Arqueiro", "adj": "Caçador",
		"desc": "Flechas de longe, críticos e mobilidade."},
	"magia": {"name": "Magia", "color": Color("bc6924"), "title": "Feiticeiro", "adj": "Arcano",
		"desc": "Fogo e explosões arcanas, muita mana."},
	"sagrado": {"name": "Sagrado", "color": Color("e9ce7c"), "title": "Clérigo", "adj": "Sagrado",
		"desc": "Cura, vida extra e luz contra mortos-vivos."},
	"escudo": {"name": "Escudo", "color": Color("4d8ab3"), "title": "Guardião", "adj": "Protetor",
		"desc": "Defesa, bloqueio, contra-ataque e investida."},
	"bruxaria": {"name": "Bruxaria", "color": Color("8a4fb3"), "title": "Bruxo", "adj": "Sombrio",
		"desc": "Maldições, espíritos famintos e roubo de vida."},
	"espiritual": {"name": "Espiritual", "color": Color("509b66"), "title": "Xamã", "adj": "Espiritual",
		"desc": "Raízes, tempestades e a força da natureza."},
	# the scholar who can learn every spell there is
	"mago": {"name": "Mago", "color": Color("425b9e"), "title": "Mago", "adj": "Erudito",
		"desc": "O estudioso das magias: mísseis arcanos, teleporte e magias aprendidas de todos os arquétipos."},
	# inspired by "Conquering Dungeons With Copy Paste!" (Ctrl+C / Ctrl+V)
	"copista": {"name": "Copista", "color": Color("65b1b8"), "title": "Copista", "adj": "Copista",
		"desc": "Ctrl+C, Ctrl+V: copia as magias dos monstros e lança como se fossem suas."},
}
const ORDER := ["guerra", "arqueria", "magia", "sagrado", "escudo", "bruxaria", "espiritual", "mago", "copista"]

## Two archetypes -> class name (key: the two ids in ORDER order joined by "+")
const PAIRS := {
	"guerra+arqueria": "Patrulheiro", "guerra+magia": "Cavaleiro Arcano", "guerra+sagrado": "Paladino",
	"guerra+escudo": "Cavaleiro", "guerra+bruxaria": "Cavaleiro da Morte", "guerra+espiritual": "Berserker",
	"arqueria+magia": "Arqueiro Arcano", "arqueria+sagrado": "Caçador Sagrado", "arqueria+escudo": "Sentinela",
	"arqueria+bruxaria": "Caçador Sombrio", "arqueria+espiritual": "Guardião da Floresta",
	"magia+sagrado": "Sacerdote", "magia+escudo": "Mago de Batalha", "magia+bruxaria": "Necromante",
	"magia+espiritual": "Elementalista", "sagrado+escudo": "Templário", "sagrado+bruxaria": "Inquisidor",
	"sagrado+espiritual": "Druida", "escudo+bruxaria": "Cavaleiro Sombrio", "escudo+espiritual": "Guardião Ancestral",
	"bruxaria+espiritual": "Xamã Sombrio",
	"guerra+mago": "Espadachim Arcano", "arqueria+mago": "Arqueiro Rúnico", "magia+mago": "Arquimago",
	"sagrado+mago": "Oráculo", "escudo+mago": "Guardião Rúnico", "bruxaria+mago": "Lich",
	"espiritual+mago": "Sábio dos Espíritos",
	"guerra+copista": "Lâmina Copista", "arqueria+copista": "Arqueiro Copista", "magia+copista": "Feiticeiro Copista",
	"sagrado+copista": "Clérigo Copista", "escudo+copista": "Escudo Espelho", "bruxaria+copista": "Ladrão de Almas",
	"espiritual+copista": "Eco dos Espíritos", "mago+copista": "Mago Copista",
}

## Ctrl+C: what each monster's magic becomes when the Mago copies it.
const COPY_FROM := {
	"skeleton_pyro": "fireball", "ghost": "maldicao", "skeleton": "golpe_giratorio", "skeleton_dark": "golpe_giratorio",
	"guardiao_pagma": "julgamento", "goblin": "flecha", "goblin_chief": "grito_guerra", "orc": "investida",
	"wolf": "investida", "bat": "espiritos", "spider": "raizes", "golem": "muralha", "crystal_elemental": "explosao_arcana",
	"slime": "maldicao", "slime_fire": "fireball", "slime_poison": "maldicao", "mushroom": "raizes", "frog": "flecha",
	"treant": "tempestade",
}

## Nodes. kind: active (skill id) or passive (stat, per rank). ranks: max rank.
## icon: [archetype colour disc] + glyph drawn by the UI (see SkillIcons in Hud).
const NODES := {
	# --- Guerra
	"g_giro": {"arch": "guerra", "tier": 1, "kind": "active", "skill": "golpe_giratorio", "ranks": 1, "name": "Golpe Giratório",
		"desc": "Gira a espada e acerta todos ao redor (130% do ataque)."},
	"g_forca": {"arch": "guerra", "tier": 2, "kind": "passive", "stat": "atk", "per": 2, "ranks": 3, "name": "Força Bruta",
		"desc": "+2 de ataque por nível."},
	"g_sangue": {"arch": "guerra", "tier": 2, "kind": "passive", "stat": "lifesteal_kill", "per": 2, "ranks": 3, "name": "Sede de Sangue",
		"desc": "Cura 2 de vida por monstro derrotado, por nível."},
	"g_grito": {"arch": "guerra", "tier": 3, "kind": "active", "skill": "grito_guerra", "ranks": 1, "name": "Grito de Guerra",
		"desc": "+30% de ataque por 8 segundos."},
	"g_furia": {"arch": "guerra", "tier": 4, "kind": "passive", "stat": "fury", "per": 1, "ranks": 1, "name": "Fúria",
		"desc": "Com menos da metade da vida: +25% de dano."},
	# --- Arqueria
	"a_flecha": {"arch": "arqueria", "tier": 1, "kind": "active", "skill": "flecha", "ranks": 1, "name": "Flecha Certeira",
		"desc": "Flecha rápida que atravessa inimigos (120% do ataque)."},
	"a_olho": {"arch": "arqueria", "tier": 2, "kind": "passive", "stat": "crit", "per": 5, "ranks": 3, "name": "Olho de Águia",
		"desc": "+5% de chance de crítico por nível."},
	"a_pes": {"arch": "arqueria", "tier": 2, "kind": "passive", "stat": "dash_cd", "per": 12, "ranks": 3, "name": "Pés Leves",
		"desc": "Esquiva recarrega 12% mais rápido por nível."},
	"a_chuva": {"arch": "arqueria", "tier": 3, "kind": "active", "skill": "chuva_flechas", "ranks": 1, "name": "Chuva de Flechas",
		"desc": "Cinco flechas em leque."},
	"a_cacador": {"arch": "arqueria", "tier": 4, "kind": "passive", "stat": "far_dmg", "per": 25, "ranks": 1, "name": "Caçador",
		"desc": "+25% de dano em alvos longe (mais de 60 px)."},
	# --- Magia
	"m_fogo": {"arch": "magia", "tier": 1, "kind": "active", "skill": "fireball", "ranks": 1, "name": "Bola de Fogo",
		"desc": "Projétil que explode e persegue o alvo travado."},
	"m_mente": {"arch": "magia", "tier": 2, "kind": "passive", "stat": "max_mp", "per": 6, "ranks": 3, "name": "Mente Arcana",
		"desc": "+6 de mana máxima por nível."},
	"m_fluxo": {"arch": "magia", "tier": 2, "kind": "passive", "stat": "mp_regen", "per": 25, "ranks": 3, "name": "Fluxo de Mana",
		"desc": "+25% de regeneração de mana por nível."},
	"m_explosao": {"arch": "magia", "tier": 3, "kind": "active", "skill": "explosao_arcana", "ranks": 1, "name": "Explosão Arcana",
		"desc": "Explode o ponto do alvo (ou à sua frente) com 160% do dano mágico."},
	"m_ignicao": {"arch": "magia", "tier": 4, "kind": "passive", "stat": "spell_dmg", "per": 25, "ranks": 1, "name": "Ignição",
		"desc": "+25% de dano de todas as magias."},
	# --- Sagrado
	"s_luz": {"arch": "sagrado", "tier": 1, "kind": "active", "skill": "luz_curativa", "ranks": 1, "name": "Luz Curativa",
		"desc": "Cura 30% da vida máxima."},
	"s_bencao": {"arch": "sagrado", "tier": 2, "kind": "passive", "stat": "max_hp", "per": 6, "ranks": 3, "name": "Bênção",
		"desc": "+6 de vida máxima por nível."},
	"s_aura": {"arch": "sagrado", "tier": 2, "kind": "passive", "stat": "hp_regen", "per": 1, "ranks": 3, "name": "Aura Sagrada",
		"desc": "Regenera 1 de vida a cada 4 s por nível."},
	"s_julgamento": {"arch": "sagrado", "tier": 3, "kind": "active", "skill": "julgamento", "ranks": 1, "name": "Julgamento",
		"desc": "Luz ao redor (120% do ataque); dano dobrado em mortos-vivos."},
	"s_santuario": {"arch": "sagrado", "tier": 4, "kind": "passive", "stat": "potion_heal", "per": 50, "ranks": 1, "name": "Santuário",
		"desc": "Poções curam 50% a mais."},
	# --- Escudo
	"e_muralha": {"arch": "escudo", "tier": 1, "kind": "active", "skill": "muralha", "ranks": 1, "name": "Muralha de Escudo",
		"desc": "Recebe 60% menos dano por 5 segundos."},
	"e_pele": {"arch": "escudo", "tier": 2, "kind": "passive", "stat": "def", "per": 1, "ranks": 3, "name": "Pele de Ferro",
		"desc": "+1 de defesa por nível."},
	"e_contra": {"arch": "escudo", "tier": 2, "kind": "passive", "stat": "counter", "per": 10, "ranks": 3, "name": "Contra-ataque",
		"desc": "10% de chance por nível de devolver metade do dano corpo a corpo."},
	"e_investida": {"arch": "escudo", "tier": 3, "kind": "active", "skill": "investida", "ranks": 1, "name": "Investida",
		"desc": "Avança com o escudo, derrubando e ferindo quem estiver no caminho."},
	"e_inabalavel": {"arch": "escudo", "tier": 4, "kind": "passive", "stat": "steadfast", "per": 1, "ranks": 1, "name": "Inabalável",
		"desc": "Não é empurrado ao apanhar e ganha +10% de vida máxima."},
	# --- Bruxaria
	"b_maldicao": {"arch": "bruxaria", "tier": 1, "kind": "active", "skill": "maldicao", "ranks": 1, "name": "Maldição",
		"desc": "Inimigos na área ficam 40% mais lentos e levam +25% de dano por 6 s."},
	"b_dreno": {"arch": "bruxaria", "tier": 2, "kind": "passive", "stat": "drain", "per": 5, "ranks": 3, "name": "Dreno",
		"desc": "Cura 5% do dano causado por nível."},
	"b_pacto": {"arch": "bruxaria", "tier": 2, "kind": "passive", "stat": "mp_on_kill", "per": 2, "ranks": 3, "name": "Pacto",
		"desc": "Cada monstro derrotado devolve 2 de mana por nível."},
	"b_espiritos": {"arch": "bruxaria", "tier": 3, "kind": "active", "skill": "espiritos", "ranks": 1, "name": "Espíritos Famintos",
		"desc": "Três espíritos giram ao seu redor por 8 s ferindo quem tocarem."},
	"b_ceifador": {"arch": "bruxaria", "tier": 4, "kind": "passive", "stat": "execute", "per": 15, "ranks": 1, "name": "Ceifador",
		"desc": "Golpes executam monstros com menos de 15% de vida."},
	# --- Espiritual
	"p_raizes": {"arch": "espiritual", "tier": 1, "kind": "active", "skill": "raizes", "ranks": 1, "name": "Raízes",
		"desc": "Prende os inimigos na área por 3 segundos."},
	"p_harmonia": {"arch": "espiritual", "tier": 2, "kind": "passive", "stat": "speed", "per": 6, "ranks": 3, "name": "Espírito Animal",
		"desc": "+6% de velocidade por nível."},
	"p_natureza": {"arch": "espiritual", "tier": 2, "kind": "passive", "stat": "nature_regen", "per": 1, "ranks": 3, "name": "Harmonia",
		"desc": "Fora da vila, regenera 1 de vida e 1 de mana a cada 5 s por nível."},
	"p_tempestade": {"arch": "espiritual", "tier": 3, "kind": "active", "skill": "tempestade", "ranks": 1, "name": "Tempestade",
		"desc": "Raios atingem até 3 inimigos próximos (120% do dano mágico)."},
	"p_comunhao": {"arch": "espiritual", "tier": 4, "kind": "passive", "stat": "night_power", "per": 20, "ranks": 1, "name": "Comunhão",
		"desc": "À noite: +20% de dano e mana regenera 50% mais rápido."},
	# --- Mago: learns every spell
	"o_missil": {"arch": "mago", "tier": 1, "kind": "active", "skill": "missil_arcano", "ranks": 1, "name": "Míssil Arcano",
		"desc": "Projétil arcano barato e rápido que persegue o alvo (70% do dano mágico)."},
	"o_grimorio": {"arch": "mago", "tier": 2, "kind": "passive", "stat": "foreign", "per": 1, "ranks": 3, "name": "Grimório",
		"desc": "Por nível: aprende 1 habilidade inicial de qualquer arquétipo, além dos seus 3."},
	"o_sabedoria": {"arch": "mago", "tier": 2, "kind": "passive", "stat": "spell_dmg", "per": 8, "ranks": 3, "name": "Sabedoria",
		"desc": "+8% de dano de todas as magias por nível."},
	"o_teleporte": {"arch": "mago", "tier": 3, "kind": "active", "skill": "teleporte", "ranks": 1, "name": "Teleporte",
		"desc": "Some e reaparece alguns passos à frente, intocável por um instante."},
	"o_biblioteca": {"arch": "mago", "tier": 4, "kind": "passive", "stat": "foreign_all", "per": 1, "ranks": 1, "name": "Biblioteca Infinita",
		"desc": "Aprende QUALQUER habilidade ativa de todos os arquétipos, sem limite."},
	# --- Copista (Ctrl+C / Ctrl+V)
	"c_copiar": {"arch": "copista", "tier": 1, "kind": "active", "skill": "copiar", "ranks": 1, "name": "Copiar (Ctrl+C)",
		"desc": "Copia a magia do monstro na mira (ou a última que você usou). A Bola de Fogo do Piromante, a teia da aranha, a pele de pedra do golem..."},
	"c_colar": {"arch": "copista", "tier": 1, "kind": "active", "skill": "colar", "ranks": 1, "name": "Colar (Ctrl+V)",
		"desc": "Lança a magia copiada, mesmo sem conhecê-la. Custa a mana dela."},
	"c_memoria": {"arch": "copista", "tier": 2, "kind": "passive", "stat": "paste_power", "per": 1, "ranks": 3, "name": "Memória Arcana",
		"desc": "Por nível: o que você cola custa 15% menos mana e causa 10% mais dano."},
	"c_reflexo": {"arch": "copista", "tier": 2, "kind": "passive", "stat": "auto_copy", "per": 10, "ranks": 3, "name": "Reflexo Copiado",
		"desc": "Magia que te atinge é copiada sozinha, e você leva 10% menos dano dela por nível."},
	"c_massa": {"arch": "copista", "tier": 3, "kind": "active", "skill": "colar_massa", "ranks": 1, "name": "Colar em Massa",
		"desc": "Cola a magia copiada três vezes em leque (o dobro da mana)."},
	"c_tudo": {"arch": "copista", "tier": 4, "kind": "passive", "stat": "copy_all", "per": 1, "ranks": 1, "name": "Copiar Tudo (Ctrl+A)",
		"desc": "Copiar também copia a força do monstro: +30% de dano por 8 segundos."},
}

## Active skills: mana cost and cooldown (seconds).
const SKILLS := {
	"fireball": {"name": "Bola de Fogo", "cost": 8, "cd": 0.7, "arch": "magia"},
	"golpe_giratorio": {"name": "Golpe Giratório", "cost": 6, "cd": 1.6, "arch": "guerra"},
	"grito_guerra": {"name": "Grito de Guerra", "cost": 10, "cd": 14.0, "arch": "guerra"},
	"flecha": {"name": "Flecha Certeira", "cost": 4, "cd": 0.5, "arch": "arqueria"},
	"chuva_flechas": {"name": "Chuva de Flechas", "cost": 10, "cd": 3.0, "arch": "arqueria"},
	"explosao_arcana": {"name": "Explosão Arcana", "cost": 12, "cd": 3.5, "arch": "magia"},
	"luz_curativa": {"name": "Luz Curativa", "cost": 10, "cd": 6.0, "arch": "sagrado"},
	"julgamento": {"name": "Julgamento", "cost": 12, "cd": 5.0, "arch": "sagrado"},
	"muralha": {"name": "Muralha de Escudo", "cost": 8, "cd": 12.0, "arch": "escudo"},
	"investida": {"name": "Investida", "cost": 8, "cd": 3.0, "arch": "escudo"},
	"maldicao": {"name": "Maldição", "cost": 8, "cd": 6.0, "arch": "bruxaria"},
	"espiritos": {"name": "Espíritos Famintos", "cost": 12, "cd": 10.0, "arch": "bruxaria"},
	"raizes": {"name": "Raízes", "cost": 8, "cd": 7.0, "arch": "espiritual"},
	"tempestade": {"name": "Tempestade", "cost": 14, "cd": 5.0, "arch": "espiritual"},
	"missil_arcano": {"name": "Míssil Arcano", "cost": 3, "cd": 0.45, "arch": "mago"},
	"teleporte": {"name": "Teleporte", "cost": 6, "cd": 3.0, "arch": "mago"},
	"copiar": {"name": "Copiar (Ctrl+C)", "cost": 3, "cd": 1.5, "arch": "copista"},
	"colar": {"name": "Colar (Ctrl+V)", "cost": 0, "cd": 0.8, "arch": "copista"},
	"colar_massa": {"name": "Colar em Massa", "cost": 0, "cd": 4.0, "arch": "copista"},
}
## skills that act on the hero only (Colar em Massa casts these once)
const SELF_SKILLS := ["grito_guerra", "luz_curativa", "muralha", "investida", "espiritos", "teleporte", "copiar", "colar", "colar_massa"]


const ICONS := "res://assets/ui/skills.png"   # built by tools/build_skill_icons.py (24x24, 8 per row)


static func icon_rect(index: int) -> Rect2:
	return Rect2((index % 8) * 24, (index / 8) * 24, 24, 24)


static func node_icon(id: String) -> int:
	return NODES.keys().find(id)


static func emblem_icon(arch: String) -> int:
	return NODES.size() + ORDER.find(arch)


static func skill_icon(sk: String) -> int:
	for id in NODES:
		if NODES[id].get("skill", "") == sk:
			return node_icon(id)
	return 0


static func nodes_of(arch: String) -> Array:
	var out: Array = []
	for id in NODES:
		if NODES[id]["arch"] == arch:
			out.append(id)
	out.sort_custom(func(a, b): return int(NODES[a]["tier"]) < int(NODES[b]["tier"]))
	return out


static func rank(id: String) -> int:
	return int(Game.arch_ranks.get(id, 0))


static func spent_in(arch: String) -> int:
	var n := 0
	for id in nodes_of(arch):
		n += rank(id)
	return n


static func points_total() -> int:
	return maxi(0, Game.level - 1) + Game.arch_bonus_points


static func points_spent() -> int:
	var n := 0
	for id in Game.arch_ranks:
		n += int(Game.arch_ranks[id])
	return n


static func points_free() -> int:
	return points_total() - points_spent()


## "" when the node can take a point, else why not.
static func can_learn(id: String) -> String:
	var n: Dictionary = NODES[id]
	var arch: String = n["arch"]
	if rank(id) >= int(n["ranks"]):
		return "Máximo"
	if points_free() <= 0:
		return "Sem pontos"
	if not arch in Game.archetypes and Game.archetypes.size() >= MAX_ARCHETYPES:
		# the Mago's Grimório / Biblioteca: spells from any archetype beyond the three
		if n["kind"] != "active" or arch == "mago":
			return "Máx. 3 arquétipos"
		if bonus("foreign_all") > 0.0:
			return ""
		if int(n["tier"]) == 1 and foreign_used() < int(bonus("foreign")):
			return ""
		return "Máx. 3 arquétipos (o Grimório do Mago libera)" if bonus("foreign") <= 0.0 else "Grimório cheio"
	if spent_in(arch) < int(TIER_NEED[int(n["tier"]) - 1]):
		return "Precisa de %d pontos em %s" % [TIER_NEED[int(n["tier"]) - 1], DATA[arch]["name"]]
	return ""


## Active skills learned from archetypes outside the chosen three (Grimório).
static func foreign_used() -> int:
	var n := 0
	for id in Game.arch_ranks:
		if not NODES[id]["arch"] in Game.archetypes:
			n += 1
	return n


static func learn(id: String) -> bool:
	if can_learn(id) != "":
		return false
	var n: Dictionary = NODES[id]
	if not n["arch"] in Game.archetypes and Game.archetypes.size() < MAX_ARCHETYPES:
		Game.archetypes.append(n["arch"])
	Game.arch_ranks[id] = rank(id) + 1
	_apply_passive(n, 1)
	if n["kind"] == "active":
		var sk: String = n["skill"]
		Game.learn_skill(sk)
		equip_free_slot(sk)
	Game.stats_changed.emit()
	return true


static func equip_free_slot(sk: String) -> void:
	if sk in Game.skill_slots:
		return
	for i in SLOTS:
		if Game.skill_slots[i] == "":
			Game.skill_slots[i] = sk
			return


## Permanent stats (max life/mana, defence) move with the ranks; the rest are read live (bonus()).
static func _apply_passive(n: Dictionary, sign_: int) -> void:
	if n["kind"] != "passive":
		return
	var v := int(n["per"]) * sign_
	match n["stat"]:
		"max_hp":
			Game.max_hp += v
			Game.hp = clampi(Game.hp + maxi(0, v), 1, Game.max_hp)
		"max_mp":
			Game.max_mp += v
			Game.mp = clampi(Game.mp + maxi(0, v), 0, Game.max_mp)
		"steadfast":
			var hp_bonus := int(round(Game.max_hp * 0.1)) * sign_
			Game.max_hp += hp_bonus
			Game.hp = clampi(Game.hp, 1, Game.max_hp)


## Total of a passive stat over every learned node (per x rank).
static func bonus(stat: String) -> float:
	var t := 0.0
	for id in Game.arch_ranks:
		var n: Dictionary = NODES.get(id, {})
		if not n.is_empty() and n["kind"] == "passive" and n["stat"] == stat:
			t += float(n["per"]) * int(Game.arch_ranks[id])
	return t


## Forget everything (costs gold at the Alchemist): points come back, the fireball orb stays.
static func reset() -> void:
	for id in Game.arch_ranks.keys():
		var n: Dictionary = NODES[id]
		for _r in int(Game.arch_ranks[id]):
			_apply_passive(n, -1)
	Game.arch_ranks = {}
	Game.archetypes = []
	Game.copied = ""
	var keep: Array = []
	for sk in Game.skills:
		if sk in Game.orb_skills:
			keep.append(sk)
	Game.skills = keep
	for i in SLOTS:
		if not Game.skill_slots[i] in keep:
			Game.skill_slots[i] = ""
	Game.stats_changed.emit()


static func reset_cost() -> int:
	return 50 * Game.level


## Class name from the chosen archetypes (up to three).
static func class_name_of(archs: Array) -> String:
	if archs.is_empty():
		return "Aventureiro"
	var sorted: Array = archs.duplicate()
	sorted.sort_custom(func(a, b): return ORDER.find(a) < ORDER.find(b))
	if sorted.size() == 1:
		return DATA[sorted[0]]["title"]
	var pair := "%s+%s" % [sorted[0], sorted[1]]
	var base: String = PAIRS.get(pair, DATA[sorted[0]]["title"])
	if sorted.size() == 2:
		return base
	return "%s %s" % [base, DATA[sorted[2]]["adj"]]
