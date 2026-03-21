extends Control

# Draws restaurant art (backgrounds, stations, NPC) via _draw()
# Used by restaurant_room.gd — no Sprite2D nodes (WASM safe)

var kitchen_bg: Texture2D = null
var dining_bg: Texture2D = null
var stations_tex: Texture2D = null
var cook_npc_tex: Texture2D = null

var show_kitchen: bool = true
var npc_pos: Vector2 = Vector2(200, 200)
var npc_scale: float = 1.0

# Station glow during cooking (-1 = none)
var glow_station: int = -1
var glow_alpha: float = 0.0

# Station rects (relative to this control) — positioned over the bg art
const STATION_RECTS: Array = [
	[50, 140, 120, 120],   # grill (top-left quadrant)
	[230, 100, 120, 120],  # cold press (top-right quadrant)
	[50, 220, 120, 120],   # fermentation pod (bottom-left quadrant)
	[170, 180, 120, 120],  # prep bench (bottom-right quadrant)
]

# Table rects for dining room
const TABLE_RECTS: Array = [
	[30, 40, 330, 70],
	[30, 120, 330, 70],
	[30, 200, 330, 70],
]


func _draw() -> void:
	# Solid dark fill — prevents checkerboard transparency
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.031, 0.051, 0.102))

	var bg: Texture2D = kitchen_bg if show_kitchen else dining_bg
	if bg != null:
		# Scale bg to fill width, maintain aspect, center vertically
		var tex_size: Vector2 = bg.get_size()
		var scale_f: float = size.x / tex_size.x
		var draw_h: float = tex_size.y * scale_f
		var y_off: float = (size.y - draw_h) * 0.5
		draw_texture_rect(bg, Rect2(Vector2(0.0, y_off), Vector2(size.x, draw_h)), false)

	if show_kitchen:
		if stations_tex != null:
			# stations_tex is a 2x2 sprite sheet — draw each quadrant separately
			var tex_w: float = stations_tex.get_width() * 0.5
			var tex_h: float = stations_tex.get_height() * 0.5
			var quad_size: Vector2 = Vector2(120.0, 120.0)
			# Top-left quadrant → Grill
			draw_texture_rect_region(stations_tex, Rect2(Vector2(50.0, 140.0), quad_size), Rect2(0.0, 0.0, tex_w, tex_h))
			# Top-right quadrant → Cold Press
			draw_texture_rect_region(stations_tex, Rect2(Vector2(230.0, 100.0), quad_size), Rect2(tex_w, 0.0, tex_w, tex_h))
			# Bottom-left quadrant → Fermentation Pod
			draw_texture_rect_region(stations_tex, Rect2(Vector2(50.0, 220.0), quad_size), Rect2(0.0, tex_h, tex_w, tex_h))
			# Bottom-right quadrant → Prep Bench
			draw_texture_rect_region(stations_tex, Rect2(Vector2(170.0, 180.0), quad_size), Rect2(tex_w, tex_h, tex_w, tex_h))

		# Station glow effect
		if glow_station >= 0 and glow_station < STATION_RECTS.size() and glow_alpha > 0.0:
			var r: Array = STATION_RECTS[glow_station]
			draw_rect(
				Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])),
				Color(0.3, 0.85, 1.0, glow_alpha * 0.4)
			)

		# Cook NPC
		if cook_npc_tex != null:
			var npc_sz := Vector2(80, 80)
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
