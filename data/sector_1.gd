extends Node

var SECTOR_NAME: String = "Helion System"
var FACTION: String = "coalition"
var PLAYER_SPAWN: Vector2 = Vector2(-1200, -200)

var SUN: Dictionary = {
	"pos": Vector2(0, 0), "radius": 140.0,
	"color_r": 1.0, "color_g": 0.92, "color_b": 0.3,
	"name": "Helion"
}

var PLANETS: Array = [
	{"name": "Ember",      "planet_id": "s1_ember",     "pos_x": 300.0,   "pos_y": 520.0,   "radius": 22.0, "color_r": 0.8, "color_g": 0.4, "color_b": 0.2},
	{"name": "Vega Prime", "planet_id": "s1_vega",      "pos_x": -1221.0, "pos_y": -444.0,  "radius": 48.0, "color_r": 0.3, "color_g": 0.6, "color_b": 1.0},
	{"name": "Dusthaven",  "planet_id": "s1_dusthaven", "pos_x": 1686.0,  "pos_y": -1414.0, "radius": 55.0, "color_r": 0.7, "color_g": 0.6, "color_b": 0.3},
	{"name": "Glacius",    "planet_id": "s1_glacius",   "pos_x": -2298.0, "pos_y": 1928.0,  "radius": 32.0, "color_r": 0.7, "color_g": 0.85,"color_b": 1.0},
]

var STATIONS: Array = [
	{"name": "Coalition Hub",        "station_id": "s1_coalition_hub",   "pos_x": -1350.0, "pos_y": -300.0, "faction": "coalition"},
	{"name": "Mining Outpost Alpha", "station_id": "s1_mining_outpost",  "pos_x": 1700.0,  "pos_y": -750.0, "faction": "neutral"},
	{"name": "Observation Post",     "station_id": "s1_observation",     "pos_x": 2600.0,  "pos_y": 800.0,  "faction": "coalition"},
	{"name": "The Drifting Spoon",   "station_id": "drifting_spoon",     "pos_x": -800.0,  "pos_y": 600.0,  "faction": "neutral", "is_restaurant": true},
]

var ASTEROID_CLUSTERS: Array = [
	{"pos_x": 1559.0,  "pos_y": -900.0,  "count": 11, "spread": 250.0, "resources": "ore,ore,ore,crystal",    "pirates": 1},
	{"pos_x": 1739.0,  "pos_y": 633.0,   "count": 8,  "spread": 200.0, "resources": "ore,crystal,crystal",    "pirates": 1},
	{"pos_x": 453.0,   "pos_y": 1690.0,  "count": 10, "spread": 230.0, "resources": "ore,ore,scrap",          "pirates": 1},
	{"pos_x": -1157.0, "pos_y": 1379.0,  "count": 9,  "spread": 220.0, "resources": "crystal,crystal,ore",    "pirates": 1},
	{"pos_x": -1559.0, "pos_y": -900.0,  "count": 12, "spread": 260.0, "resources": "ore,scrap,scrap",        "pirates": 0},
	{"pos_x": 0.0,     "pos_y": -1750.0, "count": 9,  "spread": 210.0, "resources": "ore,ore,crystal",        "pirates": 0},
]

var WARP_GATES: Array = [
	{"name": "Gate Alpha", "dest_sector": 2, "pos_x": 3500.0, "pos_y": 0.0, "fuel_cost": 50},
]

var AMBIENT_ENEMIES: Array = [
	{"pos_x": -500.0, "pos_y": 1200.0, "enemy_type": "pirate", "count": 1},
	{"pos_x": 900.0,  "pos_y": -300.0, "enemy_type": "pirate", "count": 1},
]
