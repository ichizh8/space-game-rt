extends Node

var SECTOR_NAME: String = "Karath System"
var FACTION: String = "contested"
var PLAYER_SPAWN: Vector2 = Vector2(-2800, 200)

var SUN: Dictionary = {
	"pos": Vector2(200, -300), "radius": 120.0,
	"color_r": 1.0, "color_g": 0.6, "color_b": 0.2,
	"name": "Karath"
}

var PLANETS: Array = [
	{"name": "Cinder",   "planet_id": "s2_cinder",   "pos_x": 800.0,   "pos_y": 600.0,   "radius": 28.0, "color_r": 1.0, "color_g": 0.4, "color_b": 0.15},
	{"name": "Ashfall",  "planet_id": "s2_ashfall",   "pos_x": -1400.0, "pos_y": 900.0,   "radius": 35.0, "color_r": 0.35,"color_g": 0.35,"color_b": 0.38},
	{"name": "Meridian", "planet_id": "s2_meridian",  "pos_x": 1800.0,  "pos_y": -1100.0, "radius": 42.0, "color_r": 0.3, "color_g": 0.7, "color_b": 0.6},
]

var STATIONS: Array = [
	{"name": "Karath Trading Post",       "pos_x": 1200.0,  "pos_y": -500.0, "faction": "neutral"},
	{"name": "Research Station Meridian",  "pos_x": 1900.0,  "pos_y": -900.0, "faction": "coalition"},
]

var ASTEROID_CLUSTERS: Array = [
	{"pos_x": 800.0,   "pos_y": -700.0,  "count": 10, "spread": 240.0, "resources": "ore,ore,crystal",      "pirates": 2},
	{"pos_x": -400.0,  "pos_y": 1100.0,  "count": 8,  "spread": 200.0, "resources": "ore,crystal",           "pirates": 1},
	{"pos_x": 1400.0,  "pos_y": 400.0,   "count": 9,  "spread": 220.0, "resources": "crystal,crystal,ore",   "pirates": 2},
	{"pos_x": -1200.0, "pos_y": 600.0,   "count": 7,  "spread": 190.0, "resources": "ore,scrap",             "pirates": 1},
	{"pos_x": 2500.0,  "pos_y": -800.0,  "count": 12, "spread": 280.0, "resources": "crystal,crystal,scrap", "pirates": 3},
	{"pos_x": -2000.0, "pos_y": 1600.0,  "count": 11, "spread": 260.0, "resources": "crystal,ore,scrap",     "pirates": 2},
]

var BLACK_HOLES: Array = [
	{"pos_x": -2200.0, "pos_y": 1500.0, "name": "Void Rift"},
]

var WARP_GATES: Array = [
	{"name": "Gate Alpha Return", "dest_sector": 1, "pos_x": -3200.0, "pos_y": 200.0,  "fuel_cost": 50},
	{"name": "Gate Bravo",        "dest_sector": 3, "pos_x": 3200.0,  "pos_y": 800.0,  "fuel_cost": 80},
]

var AMBIENT_ENEMIES: Array = [
	{"pos_x": 0.0,     "pos_y": -1500.0, "enemy_type": "pirate", "count": 3},
	{"pos_x": 1200.0,  "pos_y": -200.0,  "enemy_type": "pirate", "count": 3},
	{"pos_x": -1600.0, "pos_y": 1200.0,  "enemy_type": "pirate", "count": 2},
]
