extends Node

var SECTOR_NAME: String = "Skull System"
var FACTION: String = "pirates"
var PLAYER_SPAWN: Vector2 = Vector2(-3000, 200)

var SUN: Dictionary = {
	"pos": Vector2(-400, 400), "radius": 110.0,
	"color_r": 1.0, "color_g": 0.25, "color_b": 0.1,
	"name": "Ashkara"
}

var PLANETS: Array = [
	{"name": "Ashkara I",  "planet_id": "s3_ash1",  "pos_x": 600.0,   "pos_y": -800.0,  "radius": 30.0, "color_r": 0.7, "color_g": 0.2, "color_b": 0.15},
	{"name": "Ashkara II", "planet_id": "s3_ash2",  "pos_x": -1200.0, "pos_y": 1100.0,   "radius": 38.0, "color_r": 0.55,"color_g": 0.35,"color_b": 0.2},
	{"name": "Ravenmoor",  "planet_id": "s3_raven", "pos_x": 2200.0,  "pos_y": 500.0,    "radius": 45.0, "color_r": 0.6, "color_g": 0.6, "color_b": 0.65},
]

var STATIONS: Array = [
	{"name": "Skullport",          "pos_x": -1800.0, "pos_y": -600.0, "faction": "pirates"},
	{"name": "Black Market Depot", "pos_x": 1400.0,  "pos_y": 900.0,  "faction": "pirates"},
]

var ASTEROID_CLUSTERS: Array = [
	{"pos_x": 1200.0,  "pos_y": -1200.0, "count": 14, "spread": 300.0, "resources": "scrap,scrap,ore,crystal", "pirates": 3},
	{"pos_x": 2200.0,  "pos_y": 1400.0,  "count": 12, "spread": 280.0, "resources": "crystal,crystal,scrap",   "pirates": 4},
	{"pos_x": -800.0,  "pos_y": 2000.0,  "count": 10, "spread": 250.0, "resources": "ore,scrap",               "pirates": 3},
	{"pos_x": 3000.0,  "pos_y": -400.0,  "count": 11, "spread": 260.0, "resources": "crystal,ore",             "pirates": 4},
	{"pos_x": 800.0,   "pos_y": 2800.0,  "count": 9,  "spread": 230.0, "resources": "scrap,crystal",           "pirates": 3},
]

var WARP_GATES: Array = [
	{"name": "Gate Bravo Return", "dest_sector": 2, "pos_x": -3200.0, "pos_y": 0.0,    "fuel_cost": 80},
	{"name": "Gate Charlie",      "dest_sector": 4, "pos_x": 3200.0,  "pos_y": -500.0, "fuel_cost": 120},
]

var AMBIENT_ENEMIES: Array = [
	{"pos_x": 800.0,   "pos_y": -600.0,  "enemy_type": "pirate",     "count": 4},
	{"pos_x": -500.0,  "pos_y": -800.0,  "enemy_type": "pirate",     "count": 3},
	{"pos_x": 1600.0,  "pos_y": 800.0,   "enemy_type": "battleship", "count": 1},
	{"pos_x": -1400.0, "pos_y": 1600.0,  "enemy_type": "pirate",     "count": 3},
]
