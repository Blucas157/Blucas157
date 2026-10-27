class_name ItemDB
## Collectible items, resource nodes, monster drops and the village recipes.
## Icons live in assets/items/items.png (16x16 cells, 8 per row, PixelLab art).

const ICONS := "res://assets/items/items.png"
const NODES := "res://assets/items/nodes.png"
const ICON_COLS := 8

const ITEMS := {
	"cobre": {"name": "Minério de Cobre", "icon": 0, "price": 3},
	"ferro": {"name": "Minério de Ferro", "icon": 1, "price": 6},
	"ouro": {"name": "Pepita de Ouro", "icon": 2, "price": 15},
	"prata": {"name": "Minério de Prata", "icon": 3, "price": 10},
	"cristal": {"name": "Cristal Azul", "icon": 4, "price": 14},
	"ametista": {"name": "Ametista", "icon": 5, "price": 18},
	"carvao": {"name": "Carvão", "icon": 8, "price": 2},
	"esmeralda": {"name": "Esmeralda", "icon": 6, "price": 40},
	"rubi": {"name": "Rubi", "icon": 7, "price": 50},
	"erva": {"name": "Erva Medicinal", "icon": 12, "price": 2},
	"cogumelo_azul": {"name": "Cogumelo Azul", "icon": 13, "price": 5},
	"frutinhas": {"name": "Frutinhas", "icon": 14, "price": 2},
	"flor_lunar": {"name": "Flor Lunar", "icon": 15, "price": 8},
	"hortela": {"name": "Hortelã", "icon": 16, "price": 2},
	"maca": {"name": "Maçã", "icon": 17, "price": 3},
	"gosma": {"name": "Gosma de Slime", "icon": 18, "price": 2},
	"esporos": {"name": "Esporos", "icon": 19, "price": 3},
	"asa_morcego": {"name": "Asa de Morcego", "icon": 20, "price": 4},
	"ectoplasma": {"name": "Ectoplasma", "icon": 21, "price": 7},
	"osso": {"name": "Osso", "icon": 22, "price": 3},
	"dente_goblin": {"name": "Dente de Goblin", "icon": 23, "price": 5},
	"nucleo_golem": {"name": "Núcleo de Golem", "icon": 24, "price": 20},
	"pele_lobo": {"name": "Pele de Lobo", "icon": 25, "price": 8},
	"presa_orc": {"name": "Presa de Orc", "icon": 26, "price": 9},
	"seda_aranha": {"name": "Seda de Aranha", "icon": 27, "price": 6},
	"perna_sapo": {"name": "Perna de Sapo", "icon": 28, "price": 4},
	"cerne_ent": {"name": "Cerne do Ent", "icon": 29, "price": 80},
	"pena": {"name": "Pena", "icon": 36, "price": 2},
	"couro": {"name": "Retalho de Couro", "icon": 37, "price": 3},
}

## Resource nodes in the world: frame in nodes.png (32x32), depleted frame, yield, hits, tool tier.
const RESOURCES := {
	"veio_cobre": {"frame": 0, "empty": 7, "item": "cobre", "amount": [1, 3], "hits": 3, "tier": 0, "regrow": 150.0, "ore": true},
	"veio_ferro": {"frame": 1, "empty": 7, "item": "ferro", "amount": [1, 2], "hits": 4, "tier": 1, "regrow": 180.0, "ore": true},
	"veio_ouro": {"frame": 2, "empty": 7, "item": "ouro", "amount": [1, 2], "hits": 5, "tier": 2, "regrow": 240.0, "ore": true},
	"veio_prata": {"frame": 6, "empty": 7, "item": "prata", "amount": [1, 2], "hits": 5, "tier": 1, "regrow": 200.0, "ore": true},
	"veio_cristal": {"frame": 3, "empty": 7, "item": "cristal", "amount": [1, 2], "hits": 5, "tier": 2, "regrow": 240.0, "ore": true},
	"veio_ametista": {"frame": 4, "empty": 7, "item": "ametista", "amount": [1, 2], "hits": 6, "tier": 2, "regrow": 260.0, "ore": true},
	"veio_rubi": {"frame": 16, "empty": 7, "item": "rubi", "amount": [1, 1], "hits": 7, "tier": 2, "regrow": 400.0, "ore": true},
	"veio_carvao": {"frame": 5, "empty": 7, "item": "carvao", "amount": [1, 3], "hits": 3, "tier": 0, "regrow": 150.0, "ore": true},
	"moita_erva": {"frame": 8, "empty": 14, "item": "erva", "amount": [1, 3], "hits": 1, "tier": 0, "regrow": 90.0},
	"moita_frutinhas": {"frame": 9, "empty": 15, "item": "frutinhas", "amount": [2, 4], "hits": 1, "tier": 0, "regrow": 90.0},
	"cogumelos_azuis": {"frame": 10, "empty": -1, "item": "cogumelo_azul", "amount": [1, 2], "hits": 1, "tier": 0, "regrow": 120.0},
	"flores_lunares": {"frame": 11, "empty": -1, "item": "flor_lunar", "amount": [1, 2], "hits": 1, "tier": 0, "regrow": 150.0},
	"hortela": {"frame": 12, "empty": -1, "item": "hortela", "amount": [1, 3], "hits": 1, "tier": 0, "regrow": 90.0},
	"macieira": {"frame": 13, "empty": 15, "item": "maca", "amount": [1, 3], "hits": 1, "tier": 0, "regrow": 120.0},
}

## Ore veins and fruit trees are solid; plants (flowers, herbs, mushrooms, bushes) are not,
## so a monster spawned among them can always be reached.
static func resource_solid(type: String) -> bool:
	var d: Dictionary = RESOURCES.get(type, {})
	return d.get("ore", false) or type == "macieira"


## Where resources grow: region -> [[type, weight]], plus density per cell.
const RESOURCE_SPAWNS := {
	"prado": [0.006, [["moita_erva", 4], ["moita_frutinhas", 3], ["hortela", 2], ["veio_cobre", 2], ["macieira", 1]]],
	"floresta": [0.007, [["moita_erva", 3], ["moita_frutinhas", 2], ["macieira", 2], ["cogumelos_azuis", 2], ["veio_cobre", 1], ["veio_carvao", 1]]],
	"ruinas": [0.006, [["veio_ferro", 3], ["veio_prata", 2], ["veio_ametista", 1], ["moita_erva", 1], ["veio_rubi", 1]]],
	"pedreira": [0.012, [["veio_cobre", 3], ["veio_ferro", 3], ["veio_carvao", 3], ["veio_prata", 2], ["veio_ouro", 1], ["veio_cristal", 2], ["veio_rubi", 1]]],
	"pantano": [0.008, [["cogumelos_azuis", 3], ["flores_lunares", 2], ["hortela", 2], ["veio_carvao", 1], ["moita_erva", 1]]],
	"coracao": [0.004, [["flores_lunares", 2], ["cogumelos_azuis", 1]]],
}

## Monster drops: id -> [[item, chance]]
const DROPS := {
	"slime": [["gosma", 0.6]], "slime_fire": [["gosma", 0.7], ["carvao", 0.3]], "slime_poison": [["gosma", 0.7]],
	"mushroom": [["esporos", 0.6], ["cogumelo_azul", 0.1]], "bat": [["asa_morcego", 0.5]],
	"ghost": [["ectoplasma", 0.6]], "skeleton": [["osso", 0.7]], "skeleton_pyro": [["osso", 0.7], ["rubi", 0.08]], "skeleton_dark": [["osso", 0.8], ["prata", 0.2]],
	"goblin": [["dente_goblin", 0.5], ["couro", 0.3]], "goblin_chief": [["dente_goblin", 1.0], ["couro", 0.6], ["ouro", 0.3]],
	"golem": [["nucleo_golem", 0.4], ["ferro", 0.5], ["rubi", 0.03]], "treant": [["cerne_ent", 1.0], ["esmeralda", 1.0]],
	"orc": [["presa_orc", 0.5], ["couro", 0.4]], "wolf": [["pele_lobo", 0.55], ["pena", 0.0]],
	"spider": [["seda_aranha", 0.6]], "frog": [["perna_sapo", 0.5]],
	"crystal_elemental": [["cristal", 0.7], ["ametista", 0.15], ["esmeralda", 0.05], ["rubi", 0.04]],
}

## Village crafting. kind: tool, sword, armor, potion, stat
const RECIPES := {
	"ferreiro": [
		{"id": "picareta_cobre", "icon": 30, "name": "Picareta de Cobre", "desc": "Minera ferro e prata", "cost": {"cobre": 5}, "gold": 20, "kind": "tool", "value": 1},
		{"id": "picareta_ferro", "icon": 31, "name": "Picareta de Ferro", "desc": "Minera ouro, cristal e ametista", "cost": {"ferro": 5, "carvao": 3}, "gold": 60, "kind": "tool", "value": 2},
		{"id": "picareta_ouro", "icon": 32, "name": "Picareta de Ouro", "desc": "Minera com metade dos golpes", "cost": {"ouro": 4, "ferro": 3}, "gold": 150, "kind": "tool", "value": 3},
		{"id": "espada_ferro", "icon": 10, "name": "Espada de Ferro", "desc": "+3 de ataque", "cost": {"ferro": 6, "carvao": 3, "dente_goblin": 2}, "gold": 80, "kind": "sword", "value": 1},
		{"id": "espada_prata", "icon": 3, "name": "Espada de Prata", "desc": "+3 de ataque", "cost": {"prata": 5, "osso": 4, "presa_orc": 2}, "gold": 140, "kind": "sword", "value": 2},
		{"id": "espada_cristal", "icon": 4, "name": "Espada de Cristal", "desc": "+6 de ataque", "cost": {"cristal": 5, "ametista": 2, "nucleo_golem": 1}, "gold": 250, "kind": "sword", "value": 3},
		{"id": "armadura_couro", "icon": 37, "name": "Armadura de Couro", "desc": "+2 de defesa", "cost": {"couro": 4, "pele_lobo": 3, "seda_aranha": 2}, "gold": 60, "kind": "armor", "value": 1},
		{"id": "armadura_ferro", "icon": 10, "name": "Armadura de Ferro", "desc": "Defesa +5 (substitui a de couro)", "cost": {"ferro": 8, "prata": 2, "pele_lobo": 2}, "gold": 160, "kind": "armor", "value": 2},
	],
	"alquimista": [
		{"id": "pocao", "icon": 35, "name": "Poção de Vida", "desc": "Cura metade da vida", "cost": {"erva": 2, "gosma": 1}, "gold": 5, "kind": "potion", "value": 1},
		{"id": "pocao_frutas", "icon": 34, "name": "Suco Curativo", "desc": "2 poções de vida", "cost": {"frutinhas": 4, "hortela": 2, "maca": 1}, "gold": 10, "kind": "potion", "value": 2},
		{"id": "tonico_forca", "icon": 19, "name": "Tônico de Força", "desc": "+1 de ataque permanente", "cost": {"cogumelo_azul": 3, "asa_morcego": 2, "esporos": 2}, "gold": 40, "kind": "stat", "value": "atk"},
		{"id": "elixir_vida", "icon": 15, "name": "Elixir de Vida", "desc": "+5 de vida máxima permanente", "cost": {"flor_lunar": 3, "perna_sapo": 2, "ectoplasma": 1}, "gold": 60, "kind": "stat", "value": "hp"},
		{"id": "pocao_pele_pedra", "icon": 24, "name": "Poção Pele de Pedra", "desc": "+1 de defesa permanente", "cost": {"cristal": 2, "nucleo_golem": 1, "erva": 3}, "gold": 80, "kind": "stat", "value": "def"},
	],
}

const TOOL_NAMES := ["Mãos", "Picareta de Cobre", "Picareta de Ferro", "Picareta de Ouro"]
const SWORD_UPGRADES := {1: 1, 2: 1, 3: 2}   # recipe value -> sword tiers added
const ARMOR_DEF := {1: 2, 2: 5}


static func item_name(id: String) -> String:
	return ITEMS[id]["name"] if ITEMS.has(id) else id


static func icon_rect(id: String) -> Rect2:
	return icon_index_rect(ITEMS[id]["icon"])


static func icon_index_rect(i: int) -> Rect2:
	return Rect2((i % ICON_COLS) * 16, (i / ICON_COLS) * 16, 16, 16)


static func node_rect(frame: int) -> Rect2:
	return Rect2((frame % 8) * 32, (frame / 8) * 32, 32, 32)
