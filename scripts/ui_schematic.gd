extends Control

# ─── Restaurant UI Schematic Draft ───────────────────────────────────────────
# Attach to a full-screen Control node and run.
# Tap/click anywhere to cycle through 4 views.
# ─────────────────────────────────────────────────────────────────────────────

enum View { KITCHEN_MAIN, KITCHEN_SHEET, KITCHEN_PICKER, DINING_MAIN }
var current_view := View.KITCHEN_MAIN

const W := 390.0
const H := 844.0

# ── Colors ────────────────────────────────────────────────────────────────────
const C_BG         := Color(0.02, 0.04, 0.09)
const C_PANEL      := Color(0.03, 0.05, 0.10)
const C_CARD       := Color(0.04, 0.08, 0.13)
const C_BORDER     := Color(0.10, 0.19, 0.33)
const C_BORDER_ACT := Color(0.27, 0.53, 1.00)
const C_GREEN      := Color(0.20, 0.73, 0.33)
const C_YELLOW     := Color(1.00, 0.85, 0.40)
const C_BLUE       := Color(0.40, 0.60, 1.00)
const C_TEXT       := Color(1.00, 1.00, 1.00)
const C_DIM        := Color(0.53, 0.60, 0.73)
const C_LABEL      := Color(0.27, 0.33, 0.47)
const C_ART_FILL   := Color(0.06, 0.10, 0.18)
const C_ART_GRID   := Color(0.08, 0.13, 0.22)
const C_STATION    := Color(1.00, 0.60, 0.20, 0.25)
const C_STATION_BD := Color(1.00, 0.60, 0.20, 0.80)
const C_T1         := Color(0.53, 0.53, 0.53)
const C_T2         := Color(0.27, 0.73, 0.40)
const C_T3         := Color(1.00, 0.53, 0.20)

var _font: Font

func _ready() -> void:
	_font = ThemeDB.fallback_font
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		current_view = (current_view + 1) % 4
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), C_BG)

	match current_view:
		View.KITCHEN_MAIN:
			_draw_art_bg(false)
			_draw_stations()
			_draw_topbar("The Drifting Spoon")
			_draw_bottom_strip("🍽  3 dishes ready", "Dining Room →")
			_draw_view_label("1 / 4   Kitchen — main view   (tap to continue)")

		View.KITCHEN_SHEET:
			_draw_art_bg(true)
			_draw_stations()
			_draw_topbar("The Drifting Spoon")
			_draw_bottom_strip("🍽  3 dishes ready", "Dining Room →")
			_draw_cooking_sheet()
			_draw_view_label("2 / 4   Kitchen + Cooking Sheet")

		View.KITCHEN_PICKER:
			_draw_art_bg(true)
			_draw_stations()
			_draw_topbar("The Drifting Spoon")
			_draw_cooking_sheet()
			_draw_ingredient_picker()
			_draw_view_label("3 / 4   Kitchen + Sheet + Ingredient Picker")

		View.DINING_MAIN:
			_draw_art_bg(false)
			_draw_topbar("Dining Room")
			_draw_guest_cards()
			_draw_bottom_strip("🍽  3 dishes ready", "← Kitchen")
			_draw_view_label("4 / 4   Dining Room")

# ─── VIEW LABEL ───────────────────────────────────────────────────────────────

func _draw_view_label(text: String) -> void:
	draw_rect(Rect2(0, 0, W, 22), Color(0, 0, 0, 0.75))
	_text(8, 15, text, 11, C_YELLOW)

# ─── ART BACKGROUND (grid pattern = placeholder for real art) ─────────────────

func _draw_art_bg(dimmed: bool) -> void:
	var fill := C_ART_FILL if not dimmed else Color(C_ART_FILL.r * 0.5, C_ART_FILL.g * 0.5, C_ART_FILL.b * 0.5)
	var grid := C_ART_GRID if not dimmed else Color(C_ART_GRID.r * 0.5, C_ART_GRID.g * 0.5, C_ART_GRID.b * 0.5)
	draw_rect(Rect2(0, 0, W, H), fill)
	var step := 40
	for x in range(0, int(W), step):
		draw_line(Vector2(x, 0), Vector2(x, H), grid, 0.5)
	for y in range(0, int(H), step):
		draw_line(Vector2(0, y), Vector2(W, y), grid, 0.5)
	if not dimmed:
		_text_center(W / 2, H / 2 - 14, "KITCHEN ART bg", 13, C_DIM)
		_text_center(W / 2, H / 2 + 8, "440 × 956 px", 11, C_LABEL)

# ─── STATION TAP ZONES ────────────────────────────────────────────────────────

func _draw_stations() -> void:
	_station(Rect2(20,  200, 130, 120), "GRILL")
	_station(Rect2(240, 180, 130, 120), "COLD PRESS")
	_station(Rect2(120, 340, 150, 120), "PREP BENCH")
	_station(Rect2(20,  420, 100, 100), "FERMENT POD")

func _station(r: Rect2, label: String) -> void:
	draw_rect(r, C_STATION)
	draw_rect(r, C_STATION_BD, false, 1.5)
	_text_center(r.position.x + r.size.x / 2, r.position.y + r.size.y / 2 + 5, label, 11, Color(1, 0.7, 0.3))

# ─── TOP BAR ──────────────────────────────────────────────────────────────────

func _draw_topbar(title: String) -> void:
	draw_rect(Rect2(0, 0, W, 88), Color(C_PANEL.r, C_PANEL.g, C_PANEL.b, 0.92))
	draw_line(Vector2(0, 88), Vector2(W, 88), C_BORDER, 1)
	_outline_btn(Rect2(16, 44, 44, 44), "←")
	_text_center(W / 2, 68, title, 15, C_YELLOW)
	_text(310, 68, "420 cr", 13, C_GREEN)

# ─── BOTTOM STRIP ─────────────────────────────────────────────────────────────

func _draw_bottom_strip(left_label: String, right_label: String) -> void:
	draw_rect(Rect2(0, 754, W, 90), Color(C_PANEL.r, C_PANEL.g, C_PANEL.b, 0.93))
	draw_line(Vector2(0, 754), Vector2(W, 754), C_BORDER, 1)
	_outline_btn(Rect2(16,  765, 180, 48), left_label)
	_outline_btn(Rect2(214, 765, 160, 48), right_label)

# ─── COOKING SHEET ────────────────────────────────────────────────────────────

func _draw_cooking_sheet() -> void:
	# Panel
	draw_rect(Rect2(0, 380, W, 464), Color(C_PANEL.r, C_PANEL.g, C_PANEL.b, 0.97))
	draw_line(Vector2(0, 380), Vector2(W, 380), C_BORDER_ACT, 1.5)

	# Station header
	_text(16, 418, "Grill — Char-Heat cooking", 17, C_YELLOW)
	_outline_btn(Rect2(350, 388, 30, 30), "✕")

	# Bench slots
	var slot_y := 450.0
	for i in 3:
		var sx = 16.0 + i * (114.0 + 8.0)
		if i == 0:
			draw_rect(Rect2(sx, slot_y, 114, 64), Color(0.05, 0.13, 0.13))
			draw_rect(Rect2(sx, slot_y, 114, 64), C_GREEN, false, 1)
			_text(sx + 8, slot_y + 22, "Snarler Haunch", 11, C_TEXT)
			_text(sx + 8, slot_y + 40, "T3  ×1", 10, C_T3)
			draw_circle(Vector2(sx + 106, slot_y + 8), 5, C_T3)
		else:
			draw_rect(Rect2(sx, slot_y, 114, 64), C_CARD)
			draw_rect(Rect2(sx, slot_y, 114, 64), C_BORDER, false, 1)
			_text_center(sx + 57, slot_y + 38, "+", 22, C_LABEL)

	# Add Ingredients button
	draw_rect(Rect2(16, 526, 358, 48), C_CARD)
	draw_rect(Rect2(16, 526, 358, 48), C_BORDER_ACT, false, 1)
	_text_center(W / 2, 555, "+ Add Ingredients", 14, C_BLUE)

	# Method pills
	_text(16, 588, "METHOD", 10, C_LABEL)
	var methods := ["Grill", "Plasma Roast", "Slow Boil", "Cold Press"]
	var px := 16.0
	for j in methods.size():
		var pw := methods[j].length() * 8.0 + 22
		var active := j == 0
		draw_rect(Rect2(px, 598, pw, 32), Color(0.10, 0.23, 0.43) if active else C_CARD)
		draw_rect(Rect2(px, 598, pw, 32), C_BORDER_ACT if active else C_BORDER, false, 1)
		_text(px + 10, 619, methods[j], 12, C_TEXT if active else C_DIM)
		px += pw + 8
		if px > W - 40: break

	# Style pills
	_text(16, 646, "STYLE", 10, C_LABEL)
	var styles := ["Diner", "Haute Cuisine", "Street Cart", "Fast Food"]
	px = 16.0
	for j in styles.size():
		var pw := styles[j].length() * 8.0 + 22
		var active := j == 1
		draw_rect(Rect2(px, 656, pw, 32), Color(0.10, 0.23, 0.43) if active else C_CARD)
		draw_rect(Rect2(px, 656, pw, 32), C_BORDER_ACT if active else C_BORDER, false, 1)
		_text(px + 10, 677, styles[j], 12, C_TEXT if active else C_DIM)
		px += pw + 8
		if px > W - 40: break

	# Cook button (active state)
	draw_rect(Rect2(16, 700, 358, 52), Color(0.10, 0.33, 0.13))
	draw_rect(Rect2(16, 700, 358, 52), C_GREEN, false, 1.5)
	_text_center(W / 2, 732, "COOK", 20, C_TEXT)

# ─── INGREDIENT PICKER ────────────────────────────────────────────────────────

func _draw_ingredient_picker() -> void:
	draw_rect(Rect2(0, 274, W, 570), Color(0.02, 0.04, 0.09, 0.99))
	draw_line(Vector2(0, 274), Vector2(W, 274), Color(0.20, 0.33, 0.60), 1.5)

	# Header
	_text(16, 308, "Add Ingredients", 16, C_TEXT)
	draw_rect(Rect2(310, 286, 64, 36), Color(0.10, 0.29, 0.50))
	_text_center(342, 309, "Done", 14, C_TEXT)

	# Saved recipes bar
	draw_rect(Rect2(16, 334, 358, 38), C_CARD)
	draw_rect(Rect2(16, 334, 358, 38), C_BORDER, false, 1)
	_text(28, 358, "⚡ Saved Recipes (3)   ▶", 13, Color(0.40, 0.53, 0.73))

	# Pantry ingredient cards (2-col grid)
	var items := [
		["Grub Meat",       "×4", C_T1, true],
		["Ray Fillet",      "×2", C_T2, true],
		["Snarler Haunch",  "×1", C_T3, true],
		["Drifter Organ",   "×3", C_T2, true],
		["Drifter Gel",     "×2", C_T1, true],
		["Feeder Flesh",    "×1", C_T2, true],
		["Crystal Extract", "×0", C_T3, false],
		["Leviathan Cut",   "×0", C_T3, false],
	]

	for i in items.size():
		var col := i % 2
		var row := i / 2
		var cx := 8.0 + col * (183.0 + 8.0)
		var cy := 386.0 + row * (64.0 + 6.0)

		var avail: bool = items[i][3]
		var bg    = C_CARD if avail else Color(0.03, 0.05, 0.08)
		var bord  = C_BORDER if avail else Color(0.07, 0.10, 0.18)
		var tc    = C_TEXT if avail else C_LABEL

		draw_rect(Rect2(cx, cy, 183, 62), bg)
		draw_rect(Rect2(cx, cy, 183, 62), bord, false, 1)
		draw_circle(Vector2(cx + 14, cy + 14), 5, items[i][2])
		_text(cx + 26, cy + 22, items[i][0], 12, tc)
		_text(cx + 26, cy + 42, items[i][1], 11, Color(0.47, 0.53, 0.60))

		if cy + 70 > H: break

# ─── DINING ROOM ──────────────────────────────────────────────────────────────

func _draw_guest_cards() -> void:
	var guests := [
		{"name": "Velka Orin",        "faction": "CORSAIRS",  "wants": "Grilled Haunch",   "match": "good"},
		{"name": "Commissioner Drath", "faction": "COALITION", "wants": "any dish",          "match": "neutral"},
		{"name": "Drifter Trader",     "faction": "DRIFTERS",  "wants": "Cold-Pressed Fillet","match": "bad"},
	]

	for i in guests.size():
		var gy := 100.0 + i * (150.0 + 8.0)
		var g := guests[i]

		draw_rect(Rect2(16, gy, W - 32, 142), C_CARD)
		draw_rect(Rect2(16, gy, W - 32, 142), C_BORDER, false, 1)

		# Portrait placeholder
		draw_rect(Rect2(24, gy + 10, 64, 82), Color(0.08, 0.12, 0.22))
		draw_rect(Rect2(24, gy + 10, 64, 82), C_BORDER, false, 1)
		_text_center(56, gy + 56, "PORTRAIT", 9, C_LABEL)

		# Name / faction
		_text(100, gy + 30, g["name"],    15, C_TEXT)
		_text(100, gy + 50, g["faction"], 11, C_DIM)

		# Wants line
		_text(100, gy + 72, "Wants: " + g["wants"], 11, C_LABEL)

		# Loves / Hates
		_text(28, gy + 112, "♥ Spicy   ✗ Cold", 10, C_DIM)

		# Serve button
		var btn_bg: Color
		var btn_bd: Color
		match g["match"]:
			"good":    btn_bg = Color(0.10, 0.40, 0.15); btn_bd = C_GREEN
			"bad":     btn_bg = Color(0.40, 0.08, 0.08); btn_bd = Color(0.80, 0.20, 0.20)
			_:         btn_bg = Color(0.15, 0.15, 0.22); btn_bd = C_BORDER
		draw_rect(Rect2(W - 102, gy + 88, 86, 40), btn_bg)
		draw_rect(Rect2(W - 102, gy + 88, 86, 40), btn_bd, false, 1)
		_text_center(W - 59, gy + 113, "SERVE", 13, C_TEXT)

		if gy + 150 > 754: break  # don't overlap bottom strip

# ─── HELPERS ──────────────────────────────────────────────────────────────────

func _outline_btn(r: Rect2, label: String) -> void:
	draw_rect(r, C_CARD)
	draw_rect(r, C_BORDER, false, 1)
	_text_center(r.position.x + r.size.x / 2, r.position.y + r.size.y / 2 + 6, label, 12, C_DIM)

func _text(x: float, y: float, s: String, size: int, color: Color) -> void:
	draw_string(_font, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _text_center(cx: float, y: float, s: String, size: int, color: Color) -> void:
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(_font, Vector2(cx - w / 2, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
