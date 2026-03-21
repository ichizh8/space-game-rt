extends Control

# Draws restaurant art (backgrounds, station indicators, NPC) via _draw()
# Used by restaurant_room.gd — no Sprite2D nodes (WASM safe)

var kitchen_bg: Texture2D = null
var dining_bg: Texture2D = null
# No longer used — kept for reference compatibility
var cook_npc_tex: Texture2D = null

var show_kitchen: bool = true
var npc_pos: Vector2 = Vector2(200, 200)
var npc_scale: float = 1.0
var art_top: float = 88.0
var art_height: float = 240.0

# Station glow during cooking (-1 = none)
var glow_station: int = -1
var glow_alpha: float = 0.0

# Active station highlight (-1 = none)
var active_station: int = -1

# Station rects (relative to this control) — positioned over the bg art
const STATION_RECTS: Array = [
	[50, 140, 120, 120],   # grill (top-left quadrant)
	[230, 100, 120, 120],  # cold press (top-right quadrant)
	[50, 220, 120, 120],   # fermentation pod (bottom-left quadrant)
	[170, 180, 120, 120],  # prep bench (bottom-right quadrant)
]

const STATION_NAMES: Array = ["Grill", "Cold Press", "Ferment Pod", "Prep Bench"]

# Table rects for dining room
const TABLE_RECTS: Array = [
	[30, 40, 330, 70],
	[30, 120, 330, 70],
	[30, 200, 330, 70],
]


func _draw() -> void:
	# Art strip area
	var art_rect: Rect2 = Rect2(0.0, art_top, size.x, art_height)

	# Fill art strip with solid dark bg — no checkerboard
	draw_rect(art_rect, Color(0.031, 0.051, 0.102))

	var bg: Texture2D = kitchen_bg if show_kitchen else dining_bg
	if bg != null:
		# Scale bg to fill art strip width, maintain aspect, clip to strip
		var tex_size: Vector2 = bg.get_size()
		var scale_f: float = size.x / tex_size.x
		var draw_h: float = tex_size.y * scale_f
		var y_off: float = art_top + (art_height - draw_h) * 0.5
		draw_texture_rect(bg, Rect2(Vector2(0.0, y_off), Vector2(size.x, draw_h)), false)

	if show_kitchen:
		# Draw station tap target indicators (no sprite overlays)
		for i in range(STATION_RECTS.size()):
			var r: Array = STATION_RECTS[i]
			var rect: Rect2 = Rect2(float(r[0]), art_top + float(r[1]), float(r[2]), float(r[3]))

			var is_cooking: bool = (i == glow_station and glow_alpha > 0.0)
			var is_active: bool = (i == active_station)

			# Background fill
			var fill_color: Color
			var border_color: Color
			if is_cooking:
				fill_color = Color(1.0, 0.6, 0.1, 0.4)
				border_color = Color(1.0, 0.6, 0.1, 0.7 + 0.3 * glow_alpha)
			elif is_active:
				fill_color = Color(1.0, 0.6, 0.2, 0.25)
				border_color = Color(0.3, 0.7, 1.0, 0.9)
			else:
				fill_color = Color(0.2, 0.6, 1.0, 0.25)
				border_color = Color(0.2, 0.6, 1.0, 0.7)

			# Rounded rect fill (draw as regular rect — _draw has no rounded rect)
			draw_rect(rect, fill_color)
			# Border — 2px outline
			draw_rect(rect, border_color, false, 2.0)

			# Station name label below hitbox
			var label_pos: Vector2 = Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y + 10.0)
			var label_text: String = STATION_NAMES[i]
			draw_string(ThemeDB.fallback_font, label_pos - Vector2(label_text.length() * 3.0, 0.0), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.85, 1.0, 0.9))

		# Cook NPC — simple drawn character (no texture)
		draw_set_transform(npc_pos, 0.0, Vector2(npc_scale, npc_scale))
		var body_color: Color = Color(0.9, 0.9, 1.0)
		var visor_color: Color = Color(0.2, 0.5, 1.0)
		# Body rectangle (10x16)
		draw_rect(Rect2(Vector2(-5.0, -2.0), Vector2(10.0, 16.0)), body_color)
		# Head circle (radius 10)
		draw_circle(Vector2(0.0, -12.0), 10.0, body_color)
		# Blue visor stripe
		draw_rect(Rect2(Vector2(-7.0, -14.0), Vector2(14.0, 4.0)), visor_color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		# Dining room — draw table slot indicators for empty tables
		for i in range(TABLE_RECTS.size()):
			var r: Array = TABLE_RECTS[i]
			draw_rect(
				Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])),
				Color(0.15, 0.2, 0.35, 0.3), false, 1.0
			)
