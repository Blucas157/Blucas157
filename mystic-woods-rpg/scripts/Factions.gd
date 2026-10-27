class_name Factions
## Living world: monster factions (and, later, NPC groups such as bandits) that learn from the
## hero, evolve, build camps, take territory and go to war with each other. The state lives in
## Game.factions (saved); this file holds the rules. Design and references: docs/IA_VIVA.md.
##
## A new monster joins a faction by being listed in "members" below or by a "faction" key in its
## MonsterDB entry; from then on it learns, evolves and fights like the others with no extra code.

const DATA := {
	"goblins": {"name": "Clã Goblin", "home": "floresta", "start": 60.0, "ambition": 1.3,
		"members": ["goblin", "goblin_chief"], "elite": "goblin_chief", "color": Color("6fb151"), "props": "camp"},
	"orcs": {"name": "Horda Orc", "home": "coracao", "start": 55.0, "ambition": 1.1,
		"members": ["orc"], "elite": "orc", "color": Color("bc6924"), "props": "camp"},
	"mortos": {"name": "Legião dos Mortos", "home": "ruinas", "start": 70.0, "ambition": 0.9,
		"members": ["skeleton", "skeleton_dark", "skeleton_pyro", "ghost"], "elite": "skeleton_dark", "color": Color("8f9ab0"), "props": "grave"},
	"aranhas": {"name": "Ninho das Aranhas", "home": "pedreira", "start": 45.0, "ambition": 1.0,
		"members": ["spider"], "elite": "spider", "color": Color("9e2e46"), "props": "nest"},
	"feras": {"name": "Matilha Selvagem", "home": "floresta", "start": 30.0, "ambition": 0.7,
		"members": ["wolf", "bat"], "elite": "wolf", "color": Color("677598"), "props": "den"},
	"gosmas": {"name": "Brejo Vivo", "home": "pantano", "start": 60.0, "ambition": 0.6,
		"members": ["slime", "slime_poison", "slime_fire", "mushroom", "frog"], "elite": "slime_fire", "color": Color("4d8ab3"), "props": "den"},
	"golens": {"name": "Guardiões de Pedra", "home": "pedreira", "start": 35.0, "ambition": 0.0,
		"members": ["golem", "crystal_elemental"], "elite": "crystal_elemental", "color": Color("b6bec8"), "props": "grave"},
	# humans: ready for when the bandit art arrives (no members yet, so they stay dormant)
	"bandidos": {"name": "Bando de Saqueadores", "home": "prado", "start": 25.0, "ambition": 1.2,
		"members": [], "elite": "", "color": Color("d18075"), "props": "camp"},
}

## Which regions touch which (the village is never taken; raids only reach its gates).
const ADJ := {
	"prado": ["floresta", "ruinas", "pedreira", "pantano"],
	"floresta": ["prado", "coracao", "ruinas", "pantano"],
	"coracao": ["floresta"],
	"ruinas": ["prado", "floresta", "pedreira"],
	"pedreira": ["prado", "ruinas", "pantano"],
	"pantano": ["prado", "floresta", "pedreira"],
}

const START_WARS := [["goblins", "orcs"], ["aranhas", "feras"]]

const TIERS := ["Selvagens", "Organizados", "Táticos", "Veteranos", "Elite", "Lendários"]
const TIER_ADJ := ["", "", "Tático", "Veterano", "de Elite", "Lendário"]
const TIER_XP := [0.0, 40.0, 100.0, 200.0, 350.0, 600.0]
const MAX_CAMPS := 4

## Adaptations: "from" = the hero tactic they answer (counter needed), or "tier" = unlocked by evolving.
const ADAPT := {
	"chamado": {"name": "Grito de guerra", "tier": 1,
		"desc": "Quando um apanha, os outros do grupo por perto correm para ajudar."},
	"cerco": {"name": "Táticas de cerco", "tier": 2,
		"desc": "Atacam em grupo, cada um por um lado, para cercar o alvo."},
	"recuo": {"name": "Recuo tático", "tier": 3,
		"desc": "Feridos recuam, se reagrupam e voltam ao combate."},
	"escudos": {"name": "Escudos improvisados", "from": "melee", "need": 12,
		"desc": "Aprenderam com a sua espada: -20% de dano corpo a corpo e às vezes bloqueiam."},
	"dispersar": {"name": "Formação dispersa", "from": "magic", "need": 6,
		"desc": "Aprenderam com a Bola de Fogo: -25% de dano mágico e não andam amontoados."},
	"finta": {"name": "Fintas", "from": "dodge", "need": 10,
		"desc": "Aprenderam com a sua esquiva: esperam ela acabar antes de atacar."},
}


static func init_state() -> Dictionary:
	var all := {}
	for fid in DATA:
		var d: Dictionary = DATA[fid]
		all[fid] = {"power": 30.0, "tier": 0, "xp": 0.0, "regions": {d["home"]: float(d["start"])}, "camps": [],
			"learn": {"melee": 0, "magic": 0, "dodge": 0}, "adapt": [], "grudge": 0.0, "wars": [], "kills": 0, "losses": 0}
	for w in START_WARS:
		all[w[0]]["wars"].append(w[1])
		all[w[1]]["wars"].append(w[0])
	return all


static func active(fid: String) -> bool:
	return not (DATA[fid]["members"] as Array).is_empty()


## Faction of a monster: its MonsterDB "faction" key, else the members lists above.
static func of(monster_id: String) -> String:
	if MonsterDB.DATA.has(monster_id):
		var f: String = MonsterDB.DATA[monster_id].get("faction", "")
		if f != "":
			return f
	for fid in DATA:
		if monster_id in DATA[fid]["members"]:
			return fid
	return ""


static func st(fid: String) -> Dictionary:
	if fid == "" or not Game.factions.has(fid):
		return {}
	return Game.factions[fid]


static func has_adapt(fid: String, a: String) -> bool:
	var s := st(fid)
	return not s.is_empty() and a in s["adapt"]


static func at_war(a: String, b: String) -> bool:
	if a == "" or b == "" or a == b:
		return false
	var s := st(a)
	return not s.is_empty() and b in s["wars"]


static func tier(fid: String) -> int:
	var s := st(fid)
	return 0 if s.is_empty() else int(s["tier"])


## Stat multipliers of an evolved faction: [hp, atk, speed].
static func stat_mult(fid: String) -> Array:
	var t := tier(fid)
	return [1.0 + 0.12 * t, 1.0 + 0.08 * t, 1.0 + 0.04 * t]


static func control(fid: String, region: String) -> float:
	var s := st(fid)
	return 0.0 if s.is_empty() else float(s["regions"].get(region, 0.0))


## The faction that holds a region (highest control), or "".
static func ruler(region: String) -> String:
	var best := ""
	var bc := 0.0
	for fid in Game.factions:
		var c := control(fid, region)
		if c > bc:
			bc = c
			best = fid
	return best


## Spawn weight multiplier: a faction's monsters show up more where it rules.
static func spawn_mult(monster_id: String, region: String) -> float:
	var fid := of(monster_id)
	if fid == "":
		return 1.0
	return 0.35 + control(fid, region) / 40.0


static func chronicle(text: String) -> void:
	Game.chronicle.append("Dia %d: %s" % [Game.day_count + 1, text])
	while Game.chronicle.size() > 40:
		Game.chronicle.pop_front()


# ---------------------------------------------------------------- learning & evolution
## The hero beat one of them with `kind` (melee / magic) or dodged one of their blows (dodge).
## Returns the id of a newly learned adaptation, or "".
static func learn(fid: String, kind: String) -> String:
	var s := st(fid)
	if s.is_empty() or not s["learn"].has(kind):
		return ""
	s["learn"][kind] = int(s["learn"][kind]) + 1
	for a in ADAPT:
		var d: Dictionary = ADAPT[a]
		if d.get("from", "") == kind and not a in s["adapt"] and int(s["learn"][kind]) >= int(d["need"]) * (1 + s["adapt"].size() / 3):
			s["adapt"].append(a)
			chronicle("%s aprendeu: %s." % [DATA[fid]["name"], d["name"]])
			return a
	return ""


## Experience from fights (against the hero or other factions) and from time. Returns true on a new tier.
static func gain_xp(fid: String, amount: float) -> bool:
	var s := st(fid)
	if s.is_empty():
		return false
	s["xp"] = float(s["xp"]) + amount
	var evolved := false
	while int(s["tier"]) + 1 < TIER_XP.size() and float(s["xp"]) >= TIER_XP[int(s["tier"]) + 1]:
		var t := int(s["tier"]) + 1
		s["tier"] = t
		s["power"] = float(s["power"]) + 15.0
		for a in ADAPT:
			if int(ADAPT[a].get("tier", 99)) <= t and not a in s["adapt"]:
				s["adapt"].append(a)
		chronicle("%s evoluiu: agora são %s!" % [DATA[fid]["name"], TIERS[t]])
		evolved = true
	return evolved


static func declare_war(a: String, b: String) -> void:
	if a == b or at_war(a, b):
		return
	st(a)["wars"].append(b)
	st(b)["wars"].append(a)
	chronicle("Guerra declarada: %s contra %s!" % [DATA[a]["name"], DATA[b]["name"]])


# ---------------------------------------------------------------- the world turning
## One step of the off-screen simulation. pick_cell(region) -> Vector2i finds room for a camp far
## from the hero (Vector2i(-1, -1) when there is none). Returns events for the HUD:
## {text, color, kind ("camp" | "war" | "tier" | "expand" | "raid"), fid, ...}.
static func tick(rng: RandomNumberGenerator, night: bool, pick_cell: Callable) -> Array:
	var events: Array = []
	for fid in Game.factions:
		if not active(fid):
			continue
		var s: Dictionary = Game.factions[fid]
		var amb := float(DATA[fid]["ambition"])
		# growth: camps and land feed the population
		var camp_lv := 0
		for c in s["camps"]:
			camp_lv += int(c["level"])
		var land := 0.0
		for r in s["regions"]:
			land += float(s["regions"][r])
		s["power"] = minf(float(s["power"]) + 0.6 + 0.5 * camp_lv + land / 120.0, 60.0 + land + 30.0 * camp_lv)
		if gain_xp(fid, 0.4 + 0.2 * camp_lv):
			events.append({"text": "%s evoluíram: %s!" % [DATA[fid]["name"], TIERS[int(s["tier"])]], "color": Color(1.0, 0.75, 0.4), "kind": "tier", "fid": fid})
		# camps grow
		for c in s["camps"]:
			if int(c["level"]) < 3 and float(s["power"]) > 40.0 * int(c["level"]) and rng.randf() < 0.08:
				c["level"] = int(c["level"]) + 1
				c["hp"] = 60 * int(c["level"])
				chronicle("O acampamento de %s em %s cresceu (nível %d)." % [DATA[fid]["name"], WorldGen.REGION_NAMES[c["region"]], c["level"]])
		if amb <= 0.0:
			continue
		# a camp in its strongest region once it holds it firmly
		if s["camps"].size() < MAX_CAMPS and float(s["power"]) > 35.0:
			for r in s["regions"]:
				if float(s["regions"][r]) >= 50.0 and not _has_camp(s, r) and rng.randf() < 0.25 * amb:
					var cell: Vector2i = pick_cell.call(r)
					if cell.x >= 0:
						var camp := {"id": "%s_%d" % [fid, Game.camp_seq], "region": r, "cell": [cell.x, cell.y], "level": 1, "hp": 60}
						Game.camp_seq += 1
						s["camps"].append(camp)
						s["power"] = float(s["power"]) - 15.0
						chronicle("%s ergueu um acampamento em %s." % [DATA[fid]["name"], WorldGen.REGION_NAMES[r]])
						events.append({"text": "%s ergueu um acampamento em %s!" % [DATA[fid]["name"], WorldGen.REGION_NAMES[r]],
							"color": Color(1.0, 0.85, 0.5), "kind": "camp", "fid": fid, "camp": camp})
					break
		# expansion: send a war party into a neighbouring region (more often at night)
		var need: float = 45.0 + 10.0 * s["regions"].size()
		if float(s["power"]) < need or rng.randf() > (0.35 if night else 0.15) * amb:
			continue
		var target := _pick_target(fid, rng)
		if target == "":
			continue
		var holder := ruler(target)
		var hc := control(holder, target) if holder != fid else 0.0
		s["power"] = float(s["power"]) - 20.0
		if holder == "" or holder == fid or hc < 20.0:
			_add_control(fid, target, 20.0)
			events.append({"text": "%s avança sobre %s." % [DATA[fid]["name"], WorldGen.REGION_NAMES[target]],
				"color": Color(1.0, 0.8, 0.6), "kind": "expand", "fid": fid, "region": target})
			continue
		# contested land: war
		if not at_war(fid, holder):
			declare_war(fid, holder)
		var mine := float(s["power"]) * (1.0 + 0.25 * int(s["tier"])) * rng.randf_range(0.7, 1.3)
		var hs := st(holder)
		var theirs := (float(hs["power"]) + hc) * (1.0 + 0.25 * int(hs["tier"])) * rng.randf_range(0.7, 1.3)
		var win := mine > theirs
		var w: String = fid if win else holder
		var l: String = holder if win else fid
		st(w)["power"] = maxf(0.0, float(st(w)["power"]) - 8.0)
		st(l)["power"] = maxf(0.0, float(st(l)["power"]) - 18.0)
		gain_xp(w, 12.0)
		gain_xp(l, 5.0)   # they also learn from losing
		if win:
			_add_control(fid, target, 25.0)
			_add_control(holder, target, -30.0)
		else:
			_add_control(holder, target, 10.0)
		var text := "Batalha em %s: %s venceu %s!" % [WorldGen.REGION_NAMES[target], DATA[w]["name"], DATA[l]["name"]]
		chronicle(text)
		events.append({"text": text, "color": Color(1.0, 0.55, 0.45), "kind": "war", "fid": w, "loser": l, "region": target})
	return events


static func _has_camp(s: Dictionary, region: String) -> bool:
	for c in s["camps"]:
		if c["region"] == region:
			return true
	return false


static func _add_control(fid: String, region: String, amount: float) -> void:
	var s := st(fid)
	var v := clampf(float(s["regions"].get(region, 0.0)) + amount, 0.0, 100.0)
	if v <= 0.0:
		s["regions"].erase(region)
		# losing the land loses the camps on it
		var keep: Array = []
		for c in s["camps"]:
			if c["region"] != region:
				keep.append(c)
		s["camps"] = keep
	else:
		s["regions"][region] = v


static func _pick_target(fid: String, rng: RandomNumberGenerator) -> String:
	var s := st(fid)
	var options: Array = []
	for r in s["regions"]:
		for n in ADJ.get(r, []):
			if float(s["regions"].get(n, 0.0)) < 80.0 and not n in options:
				options.append(n)
	if options.is_empty():
		return ""
	return options[rng.randi() % options.size()]


## The hero burned down one of their camps.
static func camp_destroyed(fid: String, camp_id: String) -> Dictionary:
	var s := st(fid)
	for c in s["camps"]:
		if c["id"] == camp_id:
			s["camps"].erase(c)
			s["power"] = float(s["power"]) * 0.65
			s["grudge"] = float(s["grudge"]) + 30.0
			_add_control(fid, c["region"], -30.0)
			chronicle("O herói destruiu o acampamento de %s em %s." % [DATA[fid]["name"], WorldGen.REGION_NAMES[c["region"]]])
			return c
	return {}


static func find_camp(camp_id: String) -> Array:
	for fid in Game.factions:
		for c in Game.factions[fid]["camps"]:
			if c["id"] == camp_id:
				return [fid, c]
	return []


## Night raid on the village gates by the faction that hates the hero most (and is strong enough).
static func raid_candidate(rng: RandomNumberGenerator) -> String:
	var best := ""
	var bg := 25.0
	for fid in Game.factions:
		var s: Dictionary = Game.factions[fid]
		if active(fid) and float(s["grudge"]) > bg and float(s["power"]) > 40.0:
			bg = float(s["grudge"])
			best = fid
	if best != "" and rng.randf() < 0.5:
		return best
	return ""
