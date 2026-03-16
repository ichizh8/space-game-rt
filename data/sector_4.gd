extends Node

var SECTOR_NAME: String = "The Void"
var FACTION: String = "void"
var PLAYER_SPAWN: Vector2 = Vector2(-2200, 0)

var SUN: Dictionary = {}  # no sun

var PLANETS: Array = [
	{"name": "Nullspace", "planet_id": "s4_nullspace", "pos_x": 600.0, "pos_y": -800.0, "radius": 50.0, "color_r": 0.3, "color_g": 0.1, "color_b": 0.4},
]

var STATIONS: Array = [
	{"name": "Abandoned Outpost", "pos_x": -800.0, "pos_y": 300.0, "faction": "neutral"},
]

var ASTEROID_CLUSTERS: Array = [
	{"pos_x": -300.0,  "pos_y": -1500.0, "count": 8,  "spread": 200.0, "resources": "scrap,scrap,crystal", "pirates": 2},
	{"pos_x": 1200.0,  "pos_y": 600.0,   "count": 6,  "spread": 180.0, "resources": "crystal,scrap",       "pirates": 3},
	{"pos_x": 1800.0,  "pos_y": -400.0,  "count": 5,  "spread": 160.0, "resources": "crystal,crystal",     "pirates": 2},
]

var WARP_GATES: Array = [
	{"name": "Gate Charlie Return", "dest_sector": 3, "pos_x": -2500.0, "pos_y": 0.0, "fuel_cost": 0},
]

var AMBIENT_ENEMIES: Array = [
	{"pos_x": 500.0,  "pos_y": -400.0,  "enemy_type": "void_sentinel", "count": 2},
	{"pos_x": 1200.0, "pos_y": -600.0,  "enemy_type": "battleship",    "count": 2},
	{"pos_x": 1800.0, "pos_y": 200.0,   "enemy_type": "void_sentinel", "count": 3},
	{"pos_x": 2000.0, "pos_y": 800.0,   "enemy_type": "battleship",    "count": 2},
]
