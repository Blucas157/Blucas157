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
		"name": "Morcego Vampiro", "path": NEW + "bat.png", "grid": 32, "feet": 24,
		"hp": 10, "atk": 5, "speed": 66.0, "xp": 6, "gold": [1, 3], "reach": 16.0, "aggro": 120.0,
		"hit_frame": 3, "cooldown": 1.2, "behavior": "fly", "attack": "melee", "lunge": 110.0, "radius": 4.0,
		"fps_move": 12.0,
	},
	"ghost": {
		"name": "Fantasma", "path": NEW + "ghost.png", "grid": 32, "feet": 24,
		"hp": 22, "atk": 8, "speed": 38.0, "xp": 12, "gold": [2, 6], "reach": 18.0, "aggro": 110.0,
		"hit_frame": 3, "cooldown": 1.6, "behavior": "ghost", "attack": "melee", "lunge": 60.0, "radius": 5.0,
		"alpha": 0.88,
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
	"skeleton_pyro": {
		"base": "skeleton", "name": "Esqueleto Piromante", "tint": Color(1.0, 0.66, 0.5), "hp": 34, "atk": 7, "xp": 22,
		"gold": [4, 10], "speed": 36.0, "reach": 105.0, "aggro": 140.0, "cooldown": 2.4, "attack": "ranged",
		"keep_away": 56.0, "flame": true, "teaches": "fireball",
	},
	"guardiao_pagma": {
		"base": "skeleton", "name": "Guardião de Pagma", "tint": Color(1.25, 1.05, 0.6), "hp": 150, "atk": 13, "xp": 120,
		"gold": [60, 90], "speed": 46.0, "scale": 1.35, "miniboss": true, "faction": "mortos", "aggro": 150.0,
	},
	"goblin": {
		"name": "Goblin", "path": NEW + "goblin.png", "grid": 32, "feet": 24,
		"hp": 22, "atk": 7, "speed": 54.0, "xp": 11, "gold": [3, 7], "reach": 20.0, "aggro": 120.0,
		"hit_frame": 3, "cooldown": 1.3, "behavior": "walk", "attack": "melee", "lunge": 70.0, "radius": 6.0,
	},
	"goblin_chief": {
		"base": "goblin", "name": "Goblin Chefe", "hue": 0.72, "hp": 70, "atk": 13, "xp": 40,
		"gold": [12, 25], "speed": 50.0, "reach": 26.0, "knock_resist": 0.5,
	},
	"golem": {
		"name": "Golem de Pedra", "path": NEW + "golem.png", "grid": 64, "feet": 56,
		"hp": 75, "atk": 15, "speed": 24.0, "xp": 35, "gold": [8, 16], "reach": 26.0, "aggro": 100.0,
		"hit_frame": 3, "cooldown": 2.4, "behavior": "tank", "attack": "aoe", "aoe": 34.0, "radius": 9.0,
		"knock_resist": 0.85, "fps_attack": 8.0, "miniboss": true,
	},
	# --- PixelLab monsters (frame counts in MonsterFrames.gd, written by tools/pixellab_import.py)
	"orc": {
		"name": "Orc Guerreiro", "path": NEW + "orc.png", "grid": 48, "feet": 40,
		"hp": 40, "atk": 11, "speed": 46.0, "xp": 22, "gold": [4, 9], "reach": 22.0, "aggro": 120.0,
		"hit_frame": 3, "cooldown": 1.5, "behavior": "walk", "attack": "melee", "radius": 7.0, "knock_resist": 0.3,
	},
	"wolf": {
		"name": "Lobo Sombrio", "path": NEW + "wolf.png", "grid": 48, "feet": 40,
		"hp": 24, "atk": 8, "speed": 76.0, "xp": 14, "gold": [2, 5], "reach": 18.0, "aggro": 140.0,
		"hit_frame": 3, "cooldown": 1.2, "behavior": "walk", "attack": "melee", "lunge": 140.0, "radius": 6.0,
		"fps_move": 12.0,
	},
	"spider": {
		"name": "Aranha Espinhosa", "path": NEW + "spider.png", "grid": 32, "feet": 24,
		"hp": 26, "atk": 10, "speed": 60.0, "xp": 15, "gold": [2, 6], "reach": 20.0, "aggro": 120.0,
		"hit_frame": 3, "cooldown": 1.3, "behavior": "walk", "attack": "melee", "lunge": 110.0, "radius": 6.0,
		"fps_move": 12.0,
	},
	"frog": {
		"name": "Sapo do Pântano", "path": NEW + "frog.png", "grid": 48, "feet": 40,
		"hp": 18, "atk": 6, "speed": 40.0, "xp": 9, "gold": [1, 4], "reach": 26.0, "aggro": 90.0,
		"hit_frame": 3, "cooldown": 1.6, "behavior": "hop", "attack": "melee", "radius": 6.0,
	},
	"crystal_elemental": {
		"name": "Golem de Cristal", "path": NEW + "crystal_elemental.png", "grid": 64, "feet": 56,
		"hp": 65, "atk": 14, "speed": 30.0, "xp": 32, "gold": [6, 14], "reach": 24.0, "aggro": 100.0,
		"hit_frame": 3, "cooldown": 2.0, "behavior": "tank", "attack": "aoe", "aoe": 32.0, "radius": 9.0,
		"knock_resist": 0.75, "fps_attack": 9.0, "miniboss": true,
	},
	"treant": {
		"name": "Ent Ancião", "path": NEW + "treant.png", "grid": 80, "feet": 72,
		"hp": 520, "atk": 18, "speed": 30.0, "xp": 400, "gold": [120, 160], "reach": 32.0, "aggro": 170.0,
		"hit_frame": 3, "cooldown": 2.2, "behavior": "boss", "attack": "aoe", "aoe": 46.0, "radius": 14.0,
		"knock_resist": 1.0, "boss": true, "fps_attack": 8.0,
	},
}

## Spawn tables per region: [id, weight, min_level]
const SPAWNS := {
	"prado": [["slime", 6, 1], ["mushroom", 3, 1], ["bat", 1, 2], ["slime_poison", 1, 3], ["frog", 1, 2]],
	"floresta": [["goblin", 4, 1], ["wolf", 3, 1], ["orc", 2, 4], ["mushroom", 2, 1], ["bat", 1, 1], ["goblin_chief", 1, 6]],
	"ruinas": [["skeleton", 5, 1], ["spider", 3, 1], ["ghost", 2, 1], ["bat", 1, 1], ["skeleton_dark", 2, 7], ["skeleton_pyro", 2, 2]],
	"pedreira": [["golem", 1, 1], ["crystal_elemental", 1, 3], ["spider", 2, 1], ["bat", 2, 1], ["slime_fire", 2, 5]],
	"pantano": [["frog", 5, 1], ["slime_poison", 3, 1], ["mushroom", 2, 1], ["ghost", 1, 1], ["slime_fire", 1, 6]],
	"coracao": [["orc", 3, 1], ["goblin", 2, 1], ["wolf", 2, 1], ["goblin_chief", 1, 1]],
}


static func get_def(id: String) -> Dictionary:
	var d: Dictionary = DATA[id]
	if d.has("base"):
		var merged: Dictionary = DATA[d["base"]].duplicate(true)
		merged.merge(d, true)
		d = merged
	if not d.has("frames"):
		d = d.duplicate(true)
		d["frames"] = MonsterFrames.FRAMES[d.get("base", id)]
	return d
