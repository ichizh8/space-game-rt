extends Control

# Draws restaurant art (backgrounds, station zones, NPC, overlays) via _draw()
# Full-screen layout: art fills entire 390x844 canvas
# Used by restaurant_room.gd — no Sprite2D nodes (WASM safe)

var kitchen_bg: Texture2D = null
var dining_bg: Texture2D = null
var cook_npc_tex: Texture2D = null

var show_kitchen: bool = true
var npc_pos: Vector2 = Vector2(200, 300)
var npc_scale: float = 1.0

# Station glow during cooking (-1 = none)
var glow_station: int = -1
var glow_alpha: float = 0.0

# Active station highlight (-1 = none)
var active_station: int = -1

# Show hint overlay when no station selected
var show_hint: bool = true

# Whether a bottom sheet is open (draws dim overlay)
var sheet_open: bool = false

# Station tap zones — absolute positions on 390x844 canvas
const STATION_RECTS: Array = [
	[20, 200, 130, 120],   # Grill — left
	[240, 180, 130, 120],  # Cold Press — right
	[120, 340, 150, 120],  # Prep Bench — center
	[20, 420, 100, 100],   # Ferment Pod — lower left
]

const STATION_NAMES: Array = ["Grill", "Cold Press", "Prep Bench", "Ferment Pod"]

const TOP_BAR_H: float = 88.0


func _draw() -> void:
	var vp_size: Vector2 = size

	# 1. Full-screen art background
	var bg: Texture2D = kitchen_bg if show_kitchen else dining_bg
	if bg != null:
		var tex_size: Vector2 = bg.get_size()
		var scale_x: float = vp_size.x / tex_size.x
		var scale_y: float = vp_size.y / tex_size.y
		var sc: float = maxf(scale_x, scale_y)
		var draw_w: float = tex_size.x * sc
		var draw_h: float = tex_size.y * sc
		var x_off: float = (vp_size.x - draw_w) * 0.5
		var y_off: float = (vp_size.y - draw_h) * 0.5
		draw_texture_rect(bg, Rect2(Vector2(x_off, y_off), Vector2(draw_w, draw_h)), false)
	else:
		# Dark grid placeholder
		draw_rect(Rect2(Vector2.ZERO, vp_size), Color(0.02, 0.04, 0.09))
		var grid_col: Color = Color(0.06, 0.10, 0.16)
		var step: float = 40.0
		var x: float = 0.0
		while x < vp_size.x:
			draw_line(Vector2(x, 0), Vector2(x, vp_size.y), grid_col, 1.0)
			x += step
		var y: float = 0.0
		while y < vp_size.y:
			draw_line(Vector2(0, y), Vector2(vp_size.x, y), grid_col, 1.0)
			y += step

	# 2. Station tap zones (kitchen mode only)
	if show_kitchen:
		for i in range(STATION_RECTS.size()):
			var r: Array = STATION_RECTS[i]
			var rect: Rect2 = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))

			var is_cooking: bool = (i == glow_station and glow_alpha > 0.0)
			var is_active: bool = (i == active_station)

			if is_cooking:
				# Pulsing orange glow
				draw_rect(rect, Color(1.0, 0.5, 0.0, 0.3 + 0.2 * glow_alpha))
				draw_rect(rect, Color(1.0, 0.6, 0.0, 0.8 + 0.2 * glow_alpha), false, 2.5)
			elif is_active:
				# Orange border + subtle fill
				draw_rect(rect, Color(1.0, 0.6, 0.1, 0.15))
				draw_rect(rect, Color(1.0, 0.7, 0.2, 0.9), false, 2.0)

			# Station name label for active station
			if is_active:
				var label_text: String = STATION_NAMES[i]
				var font_sz: int = 12
				var label_col: Color = Color(1.0, 0.9, 0.4, 1.0)
				var label_w: float = label_text.length() * 7.0
				var label_x: float = rect.position.x + (rect.size.x - label_w) * 0.5
				var label_y: float = rect.position.y + rect.size.y + 16.0
				draw_string(ThemeDB.fallback_font, Vector2(label_x, label_y), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz, label_col)

		# Hint text when no station selected
		if show_hint and active_station < 0 and not sheet_open:
			var hint_text: String = "Tap a station to begin"
			var hint_w: float = hint_text.length() * 8.5
			var hint_x: float = (vp_size.x - hint_w) * 0.5
			var hint_y: float = 320.0
			var bg_rect: Rect2 = Rect2(hint_x - 14.0, hint_y - 20.0, hint_w + 28.0, 32.0)
			draw_rect(bg_rect, Color(0.0, 0.0, 0.0, 0.55))
			draw_string(ThemeDB.fallback_font, Vector2(hint_x, hint_y), hint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 1.0, 1.0, 0.9))

		# Cook NPC
		if cook_npc_tex != null:
			var npc_sz: Vector2 = Vector2(72.0, 72.0) * npc_scale
			var npc_rect: Rect2 = Rect2(npc_pos - npc_sz * 0.5, npc_sz)
			draw_texture_rect(cook_npc_tex, npc_rect, false)
			if glow_station >= 0 and glow_alpha > 0.0:
				draw_circle(npc_pos + Vector2(38.0, 0.0), 5.0, Color(1.0, 0.5, 0.1, 0.8))

	# 3. Top bar overlay — dark panel with 90% opacity
	draw_rect(Rect2(0, 0, vp_size.x, TOP_BAR_H), Color(0.02, 0.04, 0.09, 0.90))

	# 4. Dim overlay when sheet is open (below top bar)
	if sheet_open:
		draw_rect(Rect2(0, TOP_BAR_H, vp_size.x, vp_size.y - TOP_BAR_H), Color(0.0, 0.0, 0.0, 0.45))
