extends Control

# Draws restaurant art (backgrounds, stations, NPC) via _draw()
# Used by restaurant_room.gd — no Sprite2D nodes (WASM safe)

var kitchen_bg: Texture2D = null
var dining_bg: Texture2D = null
var stations_tex: Texture2D = null
var cook_npc_tex: Texture2D = null

var show_kitchen: bool = true
var npc_pos: Vector2 = Vector2(195, 160)
var npc_scale: float = 1.0

# Station glow during cooking (-1 = none)
var glow_station: int = -1
var glow_alpha: float = 0.0

# Station rects (relative to this control) — positioned over the bg art
const STATION_RECTS: Array = [
	[30, 60, 105, 80],    # grill (left)
	[145, 60, 105, 80],   # cold press (center)
	[260, 60, 105, 80],   # prep bench (right)
]

# Table rects for dining room
const TABLE_RECTS: Array = [
	[30, 40, 330, 70],
	[30, 120, 330, 70],
	[30, 200, 330, 70],
]


func _draw() -> void:
	var bg: Texture2D = kitchen_bg if show_kitchen else dining_bg
	if bg != null:
		draw_texture_rect(bg, Rect2(Vector2.ZERO, size), false)

	if show_kitchen:
		if stations_tex != null:
			draw_texture_rect(stations_tex, Rect2(Vector2.ZERO, size), false)

		# Station glow effect
		if glow_station >= 0 and glow_station < STATION_RECTS.size() and glow_alpha > 0.0:
			var r: Array = STATION_RECTS[glow_station]
			draw_rect(
				Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])),
				Color(0.3, 0.85, 1.0, glow_alpha * 0.4)
			)

		# Cook NPC
		if cook_npc_tex != null:
			var npc_sz := Vector2(56, 72)
			draw_set_transform(npc_pos, 0.0, Vector2(npc_scale, npc_scale))
			draw_texture_rect(cook_npc_tex, Rect2(-npc_sz * 0.5, npc_sz), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		# Dining room — draw table slot indicators for empty tables
		for i in range(TABLE_RECTS.size()):
			var r: Array = TABLE_RECTS[i]
			draw_rect(
				Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])),
				Color(0.15, 0.2, 0.35, 0.3), false, 1.0
			)
