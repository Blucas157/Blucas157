class_name MonsterDB
## Monster definitions. Pack monsters (slime, skeleton) + the new ones drawn for this game.
##
## behaviour: "hop" (moves in jumps), "walk", "fly" (erratic flight), "ghost" (passes through walls),
##            "tank" (slow, area slam), "boss"
## attack:    "melee" (hit in front), "aoe" (hits around itself, radius = aoe)

const NEW := "res://assets/monsters/"

const DATA := {
	"slime": {
		"name": "Slime", "path": Sheets.MW + "characters/slime.png", "grid": 32, "feet": 24,
		"frames": {"idle": 4, "move": 6, "attack": 7, "damaged": 3, "death": 5},
		"hp": 12, "atk": 4, "speed": 40.0, "xp": 5, "gold": [1, 3], "reach": 16.0, "aggro": 90.0,
		"hit_frame": 3, "cooldown": 1.4, "behavior": "hop", "attack": "melee", "lunge": 70.0, "radius": 5.0,
	},
	"slime_fire": {
		"base": "slime", "name": "Slime de Fogo", "hue": 0.47, "hp": 22, "atk": 7, "xp": 11, "gold": [2, 5], "speed": 48.0,
	},
	"slime_poison": {
		"base": "slime", "name": "Slime Venenoso", "hue": 0.27, "hp": 18, "atk": 6, "xp": 9, "gold": [2, 4],
	},
	"mushroom": {
		"name": "Cogumelo", "path": NEW + "mushroom.png", "grid": 32, "feet": 24,
		"frames": {"idle": 4, "move": 6, "attack": 6, "damaged": 3, "death": 5},
		"hp": 16, "atk": 5, "speed": 34.0, "xp": 7, "gold": [1, 4], "reach": 18.0, "aggro": 80.0,
		"hit_frame": 3, "cooldown": 1.8, "behavior": "hop", "attack": "aoe", "aoe": 24.0, "radius": 5.0,
	},
	"bat": {
		"name": "Morcego", "path": NEW + "bat.png", "grid": 32, "feet": 24,
		"frames": {"idle": 4, "move": 6, "attack": 6, "damaged": 3, "death": 5},
		"hp": 10, "atk": 5, "speed": 66.0, "xp": 6, "gold": [1, 3], "reach": 16.0, "aggro": 120.0,
		"hit_frame": 3, "cooldown": 1.2, "behavior": "fly", "attack": "melee", "lunge": 110.0, "radius": 4.0,
		"fps_move": 14.0,
	},
	"ghost": {
		"name": "Fantasma", "path": NEW + "ghost.png", "grid": 32, "feet": 24,
		"frames": {"idle": 4, "move": 6, "attack": 6, "damaged": 3, "death": 5},
		"hp": 22, "atk": 8, "speed": 38.0, "xp": 12, "gold": [2, 6], "reach": 18.0, "aggro": 110.0,
		"hit_frame": 3, "cooldown": 1.6, "behavior": "ghost", "attack": "melee", "lunge": 60.0, "radius": 5.0,
		"alpha": 0.85,
	},
	"skeleton": {
		"name": "Esqueleto", "path": Sheets.MW + "characters/skeleton.png", "grid": 48, "feet": 40,
		"frames": {"idle": 6, "move": 6, "attack": 6, "damaged": 3, "death": 5},
		"hp": 26, "atk": 8, "speed": 42.0, "xp": 13, "gold": [2, 6], "reach": 22.0, "aggro": 110.0,
		"hit_frame": 3, "cooldown": 1.5, "behavior": "walk", "attack": "melee", "radius": 6.0,
	},
	"skeleton_dark": {
		"base": "skeleton", "name": "Esqueleto Sombrio", "tint": Color(0.62, 0.6, 0.85), "hp": 45, "atk": 12, "xp": 24,
		"gold": [4, 9], "speed": 48.0,
	},
	"goblin": {
		"name": "Goblin", "path": NEW + "goblin.png", "grid": 48, "feet": 40,
		"frames": {"idle": 6, "move": 6, "attack": 6, "damaged": 3, "death": 5},
		"hp": 22, "atk": 7, "speed": 54.0, "xp": 11, "gold": [3, 7], "reach": 22.0, "aggro": 120.0,
		"hit_frame": 3, "cooldown": 1.3, "behavior": "walk", "attack": "melee", "radius": 6.0,
	},
	"goblin_chief": {
		"base": "goblin", "name": "Goblin Chefe", "hue": 0.72, "hp": 70, "atk": 13, "xp": 40,
		"gold": [12, 25], "speed": 50.0, "reach": 26.0, "knock_resist": 0.5,
	},
	"golem": {
		"name": "Golem de Pedra", "path": NEW + "golem.png", "grid": 48, "feet": 40,
		"frames": {"idle": 4, "move": 6, "attack": 7, "damaged": 3, "death": 6},
		"hp": 75, "atk": 15, "speed": 24.0, "xp": 35, "gold": [8, 16], "reach": 24.0, "aggro": 100.0,
		"hit_frame": 4, "cooldown": 2.4, "behavior": "tank", "attack": "aoe", "aoe": 34.0, "radius": 9.0,
		"knock_resist": 0.85, "fps_attack": 8.0,
	},
	"treant": {
		"name": "Ent Ancião", "path": NEW + "treant.png", "grid": 64, "feet": 56,
		"frames": {"idle": 4, "move": 6, "attack": 7, "damaged": 3, "death": 6},
		"hp": 520, "atk": 18, "speed": 30.0, "xp": 400, "gold": [120, 160], "reach": 30.0, "aggro": 170.0,
		"hit_frame": 3, "cooldown": 2.2, "behavior": "boss", "attack": "aoe", "aoe": 44.0, "radius": 12.0,
		"knock_resist": 1.0, "boss": true, "fps_attack": 8.0,
	},
}

## Spawn tables per region: [id, weight, min_level]
const SPAWNS := {
	"prado": [["slime", 6, 1], ["mushroom", 3, 1], ["bat", 1, 2], ["slime_poison", 1, 3]],
	"floresta": [["goblin", 5, 1], ["mushroom", 2, 1], ["bat", 2, 1], ["goblin_chief", 1, 6], ["slime_poison", 1, 1]],
	"ruinas": [["skeleton", 6, 1], ["ghost", 2, 1], ["bat", 1, 1], ["skeleton_dark", 2, 7]],
	"pedreira": [["golem", 2, 1], ["bat", 3, 1], ["skeleton", 2, 1], ["slime_fire", 2, 5]],
	"pantano": [["slime_poison", 4, 1], ["mushroom", 3, 1], ["ghost", 1, 1], ["slime_fire", 1, 6]],
	"coracao": [["goblin", 3, 1], ["mushroom", 2, 1], ["goblin_chief", 1, 1]],
}


static func get_def(id: String) -> Dictionary:
	var d: Dictionary = DATA[id]
	if d.has("base"):
		var merged: Dictionary = DATA[d["base"]].duplicate(true)
		merged.merge(d, true)
		return merged
	return d
