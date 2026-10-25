class_name Rivals
## Rival monsters: names, titles and taunts. The rival list itself lives in Game (saved).
## A rival is born when a monster defeats the hero or escapes a fight badly hurt; it comes back
## later in its home region, stronger, remembering what happened.

const MAX := 3                # rivals alive at the same time
const FLEE_HP := 0.25         # a hurt monster may run away below this share of its life
const FLEE_CHANCE := 0.2      # chance to try, once per monster (rivals: FLEE_CHANCE_RIVAL)
const FLEE_CHANCE_RIVAL := 0.35
const RETURN_DELAY := 75.0    # seconds of play before a new rival can show up
const SEEN_DELAY := 150.0     # seconds before a rival that left the screen can come back
const MAX_LEVEL := 20

const NAMES := {
	"goblin": ["Grak", "Snik", "Zubo", "Murg", "Krix", "Dagg", "Nurk", "Skiv"],
	"orc": ["Thrak", "Gorza", "Brumak", "Ugash", "Kordo", "Mazrog"],
	"wolf": ["Presa Cinzenta", "Uivo-Negro", "Garra Fria", "Sombra", "Fenra"],
	"spider": ["Tessela", "Vexa", "Aracna", "Mortalha", "Seda Rubra"],
	"skeleton": ["Ossário", "Rangedor", "Tíbio", "Caveirão", "Sepulcro"],
	"ghost": ["Lamúria", "Eco", "Véu Pálido", "Suspiro", "Gélida"],
	"slime": ["Gluk", "Blop", "Gosmão", "Plof", "Visco"],
	"mushroom": ["Esporo", "Bolor", "Fungão", "Mofo"],
	"bat": ["Asa-Rubra", "Guincho", "Noturno", "Presinha"],
	"frog": ["Coaxo", "Bufo", "Linguão", "Brejo"],
	"golem": ["Pedregulho", "Basalto", "Granito", "Rochedo"],
	"crystal": ["Prisma", "Quartzo", "Fulgor", "Geodo"],
}

const TAUNTS := {
	"won": ["Voltou para cair de novo?", "Eu já te derrotei uma vez...", "A vila não vai te salvar agora!",
		"Todos sabem quem te venceu!"],
	"scarred": ["Lembra desta cicatriz? Eu lembro de você!", "Hoje eu cobro a conta!",
		"Você não vai me pegar de novo!", "Fiquei mais forte desde aquele dia..."],
	"flee": ["Isso não acabou!", "Eu volto... e mais forte!", "Você vai se arrepender!"],
	"kill": ["Fraco! Lembre-se do meu nome!", "Corra para a vila, herói!", "Esta floresta é minha!"],
	"defeated": ["Impossível...", "Você... venceu...", "Não... de novo não..."],
}


static func family(monster_id: String) -> String:
	match monster_id:
		"goblin_chief":
			return "goblin"
		"slime_fire", "slime_poison":
			return "slime"
		"skeleton_dark", "skeleton_pyro":
			return "skeleton"
		"crystal_elemental":
			return "crystal"
	return monster_id


static func make_name(monster_id: String, taken: Array) -> String:
	var pool: Array = NAMES.get(family(monster_id), NAMES["goblin"]).duplicate()
	pool.shuffle()
	for n in pool:
		if not n in taken:
			return n
	return pool[0]


## Defeating the hero weighs more than scars, and both grow with each encounter.
static func title(r: Dictionary) -> String:
	var wins := int(r.get("wins", 0))
	var scars := int(r.get("scars", 0))
	if wins >= 3:
		return "Pesadelo do Herói"
	if wins == 2:
		return "Flagelo do Herói"
	if wins == 1:
		return "Matador do Herói"
	if scars >= 3:
		return "o Indomável"
	if scars == 2:
		return "o Cicatrizado"
	return "o Marcado"


static func full_name(r: Dictionary) -> String:
	return "%s, %s" % [r["name"], title(r)]


static func taunt(r: Dictionary, event: String) -> String:
	var key := event
	if event == "appear":
		key = "won" if int(r.get("wins", 0)) > 0 else "scarred"
	var lines: Array = TAUNTS[key]
	return lines[randi() % lines.size()]


static func history(r: Dictionary) -> String:
	var parts: Array = []
	var wins := int(r.get("wins", 0))
	var scars := int(r.get("scars", 0))
	if wins > 0:
		parts.append("te derrotou %dx" % wins)
	if scars > 0:
		parts.append("fugiu %dx" % scars)
	return "  -  ".join(parts)
