extends CanvasLayer

# RestaurantRoom — full-screen restaurant UI with bottom sheet panels
# Art fills entire 390x844 viewport, UI slides up as sheets
# 4 views: KITCHEN_IDLE, KITCHEN_SHEET, KITCHEN_PICKER, DINING

const FACTION_COLORS: Dictionary = {
	"coalition": Color(0.4, 0.7, 1.0),
	"corsairs": Color(1.0, 0.4, 0.3),
	"miners": Color(0.9, 0.7, 0.2),
	"scientists": Color(0.5, 0.9, 0.9),
	"drifters": Color(0.6, 0.9, 0.6),
	"independents": Color(0.7, 0.7, 0.7),
}

const TIER_COLORS: Dictionary = {
	1: Color(0.53, 0.53, 0.53),
	2: Color(0.27, 0.73, 0.40),
	3: Color(1.00, 0.53, 0.20),
}

const STATION_NAMES: Array = ["Grill", "Cold Press", "Prep Bench", "Ferment Pod"]
const STATION_DESCS: Array = ["Char-Heat cooking", "Cryo extraction", "Prep & combine", "Slow ferment"]

# Station tap zones — same as canvas
const STATION_RECTS: Array = [
	[20, 200, 130, 120],
	[240, 180, 130, 120],
	[120, 340, 150, 120],
	[20, 420, 100, 100],
]

# Layout constants (390x844 viewport)
const TOP_BAR_H: int = 88
const SHEET_Y_HALF: int = 380    # cooking sheet (464px tall)
const SHEET_Y_FULL: int = 274    # ingredient picker (570px tall)
const BOTTOM_STRIP_H: int = 90
const BOTTOM_STRIP_Y: int = 754  # 844 - 90
const MSG_H: int = 36

# Colors
const COL_BG_DARK: Color = Color(0.02, 0.04, 0.09)
const COL_PANEL: Color = Color(0.03, 0.05, 0.10, 0.97)
const COL_CARD: Color = Color(0.04, 0.08, 0.13)
const COL_BORDER: Color = Color(0.10, 0.19, 0.33)
const COL_BORDER_ACTIVE: Color = Color(0.27, 0.53, 1.00)
const COL_BORDER_GREEN: Color = Color(0.20, 0.73, 0.33)
const COL_ACCENT_YELLOW: Color = Color(1.00, 0.85, 0.40)
const COL_ACCENT_BLUE: Color = Color(0.40, 0.60, 1.00)
const COL_ACCENT_GREEN: Color = Color(0.20, 0.73, 0.33)

# Views
enum View { KITCHEN_IDLE, KITCHEN_SHEET, KITCHEN_PICKER, DINING }

# Preference display names
const PREF_MAP: Dictionary = {
	"char_grill": "char-grill", "slow_boil": "slow boil", "plasma_roast": "plasma roast",
	"cold_press": "raw/cold press", "molecular_decon": "mol. decon",
	"deep_freeze": "deep freeze", "fast_food": "fast food", "diner": "diner plate",
	"high_cuisine": "haute cuisine", "street_cart": "street cart", "the_experiment": "experiment",
}

# ── State ──
var _view: int = View.KITCHEN_IDLE
var _active_station: int = -1
var _bench_ings: Array = []
var _bench_method: int = 0
var _bench_style: int = 0

# Cooking animation
var _cooking: bool = false
var _cook_timer: float = 0.0
var _cook_station_idx: int = -1

# NPC
var _npc_home: Vector2 = Vector2(200, 360)
var _npc_tween: Tween = null

# Message
var _msg_timer: float = 0.0

# Idle pulse
var _idle_time: float = 0.0

# Result auto-reset timer
var _result_timer: float = 0.0

# Deferred rebuild flag (WASM safe)
var _needs_rebuild: bool = false

# Drag-and-drop state
var _drag_ing: String = ""
var _drag_preview: Control = null
var _drag_active: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_pending: bool = false

# ── Textures ──
var _kitchen_bg_tex: Texture2D = null
var _dining_bg_tex: Texture2D = null
var _cook_npc_tex: Texture2D = null
var _canvas_script: GDScript = null

# ── Key nodes ──
var _root: Panel
var _canvas: Control
var _credits_lbl: Label
var _msg_lbl: Label
var _top_bar: HBoxContainer
var _bottom_strip: PanelContainer
var _sheet_panel: PanelContainer
var _sheet_scroll: ScrollContainer
var _sheet_content: VBoxContainer
var _station_layer: Control
var _station_btns: Array = []


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS

	_kitchen_bg_tex = load("res://assets/restaurant-kitchen-bg.png")
	_dining_bg_tex = load("res://assets/restaurant-dining-bg.png")
	_cook_npc_tex = load("res://assets/restaurant-cook-npc.png")
	_canvas_script = load("res://scripts/restaurant_canvas.gd")

	GameState.generate_guest_session()
	_build_ui()


func _process(delta: float) -> void:
	# Deferred rebuilds (WASM safe)
	if _needs_rebuild:
		_needs_rebuild = false
		_rebuild()

	# Message timer
	if _msg_timer > 0.0:
		_msg_timer -= delta
		if _msg_timer <= 0.0 and is_instance_valid(_msg_lbl):
			_msg_lbl.text = ""

	# Result auto-reset timer
	if _result_timer > 0.0:
		_result_timer -= delta
		if _result_timer <= 0.0:
			_active_station = -1
			_view = View.KITCHEN_IDLE
			if is_instance_valid(_canvas):
				_canvas.active_station = -1
				_canvas.show_hint = true
				_canvas.queue_redraw()
			_needs_rebuild = true

	# Cooking timer
	if _cooking:
		_cook_timer -= delta
		if _cook_timer <= 0.0:
			_cooking = false
			_finish_cook()
		elif is_instance_valid(_canvas):
			_canvas.glow_alpha = 0.5 + 0.5 * sin(_cook_timer * 6.0)
			_canvas.queue_redraw()

	# NPC idle pulse
	if not _cooking and _view != View.DINING and is_instance_valid(_canvas):
		_idle_time += delta
		_canvas.npc_scale = 1.0 + 0.02 * sin(_idle_time * PI)
		_canvas.queue_redraw()


# ═══════════════════════════════════════════════════════════════════
# BUILD UI — one-time setup of persistent nodes
# ═══════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	_root = Panel.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := StyleBoxFlat.new()
	bg.bg_color = COL_BG_DARK
	_root.add_theme_stylebox_override("panel", bg)
	add_child(_root)

	_build_canvas()
	_build_top_bar()
	_build_msg_bar()
	_build_bottom_strip()
	_build_sheet_panel()
	_set_view(View.KITCHEN_IDLE)


func _build_canvas() -> void:
	_canvas = Control.new()
	if _canvas_script != null:
		_canvas.set_script(_canvas_script)
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.kitchen_bg = _kitchen_bg_tex
	_canvas.dining_bg = _dining_bg_tex
	_canvas.cook_npc_tex = _cook_npc_tex
	_canvas.npc_pos = _npc_home
	_canvas.show_kitchen = true
	_canvas.show_hint = true
	_root.add_child(_canvas)

	# Dedicated passthrough layer for station buttons — fixed pixel coords work correctly here
	_station_layer = Control.new()
	_station_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_station_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_station_layer)


func _build_top_bar() -> void:
	# Dark bg drawn by canvas; this is just the widget container
	_top_bar = HBoxContainer.new()
	_top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top_bar.offset_top = 40  # safe area offset
	_top_bar.offset_left = 10
	_top_bar.offset_right = -10
	_top_bar.offset_bottom = TOP_BAR_H
	_root.add_child(_top_bar)

	var back_btn := Button.new()
	back_btn.text = "←"
	back_btn.custom_minimum_size = Vector2(44, 40)
	back_btn.add_theme_font_size_override("font_size", 22)
	back_btn.add_theme_color_override("font_color", Color.WHITE)
	_style_btn_flat(back_btn)
	back_btn.pressed.connect(_on_back)
	_top_bar.add_child(back_btn)

	var title := Label.new()
	title.text = GameState.restaurant_name
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", COL_ACCENT_YELLOW)
	_top_bar.add_child(title)

	_credits_lbl = Label.new()
	_credits_lbl.text = "%d cr" % GameState.credits
	_credits_lbl.add_theme_font_size_override("font_size", 13)
	_credits_lbl.add_theme_color_override("font_color", COL_ACCENT_GREEN)
	_top_bar.add_child(_credits_lbl)


func _build_msg_bar() -> void:
	_msg_lbl = Label.new()
	_msg_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_msg_lbl.offset_top = TOP_BAR_H
	_msg_lbl.offset_left = 12
	_msg_lbl.offset_right = -12
	_msg_lbl.offset_bottom = TOP_BAR_H + MSG_H
	_msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_lbl.add_theme_font_size_override("font_size", 12)
	_msg_lbl.add_theme_color_override("font_color", COL_ACCENT_YELLOW)
	_msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg_lbl.z_index = 10
	_root.add_child(_msg_lbl)


func _build_bottom_strip() -> void:
	_bottom_strip = PanelContainer.new()
	_bottom_strip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_bottom_strip.offset_top = BOTTOM_STRIP_Y
	_bottom_strip.offset_bottom = 844
	_bottom_strip.offset_left = 0
	_bottom_strip.offset_right = 0
	_bottom_strip.z_index = 20
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.04, 0.09, 0.95)
	style.border_color = COL_BORDER
	style.set_border_width_all(0)
	style.border_width_top = 1
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 20
	_bottom_strip.add_theme_stylebox_override("panel", style)
	_root.add_child(_bottom_strip)


func _build_sheet_panel() -> void:
	_sheet_panel = PanelContainer.new()
	_sheet_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_sheet_panel.offset_left = 0
	_sheet_panel.offset_right = 0
	_sheet_panel.z_index = 15
	var style := StyleBoxFlat.new()
	style.bg_color = COL_PANEL
	style.set_corner_radius_all(0)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_sheet_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_sheet_panel)

	_sheet_scroll = ScrollContainer.new()
	_sheet_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sheet_panel.add_child(_sheet_scroll)

	_sheet_content = VBoxContainer.new()
	_sheet_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet_content.add_theme_constant_override("separation", 6)
	_sheet_scroll.add_child(_sheet_content)


# ═══════════════════════════════════════════════════════════════════
# VIEW SWITCHING
# ═══════════════════════════════════════════════════════════════════

func _set_view(view: int) -> void:
	_view = view
	_rebuild()


func _rebuild() -> void:
	# Clear sheet content
	for c in _sheet_content.get_children():
		_sheet_content.remove_child(c)
		c.queue_free()

	# Clear bottom strip content
	for c in _bottom_strip.get_children():
		_bottom_strip.remove_child(c)
		c.queue_free()

	# Clear station buttons
	for btn in _station_btns:
		if is_instance_valid(btn):
			_station_layer.remove_child(btn)
			btn.queue_free()
	_station_btns.clear()

	# Update credits
	if is_instance_valid(_credits_lbl):
		_credits_lbl.text = "%d cr" % GameState.credits

	# Update canvas
	var is_kitchen: bool = (_view != View.DINING)
	if is_instance_valid(_canvas):
		_canvas.show_kitchen = is_kitchen
		_canvas.sheet_open = (_view == View.KITCHEN_SHEET or _view == View.KITCHEN_PICKER)
		_canvas.active_station = _active_station if is_kitchen else -1
		_canvas.show_hint = (_view == View.KITCHEN_IDLE and _active_station < 0)
		_canvas.queue_redraw()

	# Station layer only active in idle view
	if is_instance_valid(_station_layer):
		_station_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE if _view != View.KITCHEN_IDLE else Control.MOUSE_FILTER_IGNORE

	match _view:
		View.KITCHEN_IDLE:
			_build_kitchen_idle()
		View.KITCHEN_SHEET:
			_build_kitchen_sheet()
		View.KITCHEN_PICKER:
			_build_kitchen_picker()
		View.DINING:
			_build_dining_view()


# ═══════════════════════════════════════════════════════════════════
# VIEW: KITCHEN IDLE — art visible, station zones active
# ═══════════════════════════════════════════════════════════════════

func _build_kitchen_idle() -> void:
	_sheet_panel.visible = false

	# Station tap zones (invisible buttons over art)
	_build_station_buttons()

	# Bottom strip: dishes ready + dining room button
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	_bottom_strip.add_child(hbox)

	var dish_count: int = GameState.prepared_dishes.size()
	var dishes_btn := Button.new()
	dishes_btn.text = "🍽 %d dishes ready" % dish_count if dish_count > 0 else "🍽 No dishes"
	dishes_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dishes_btn.custom_minimum_size.y = 48
	dishes_btn.add_theme_font_size_override("font_size", 14)
	dishes_btn.add_theme_color_override("font_color", COL_ACCENT_YELLOW if dish_count > 0 else Color(0.5, 0.5, 0.6))
	dishes_btn.disabled = (dish_count == 0)
	_style_btn_card(dishes_btn, COL_CARD)
	dishes_btn.pressed.connect(func(): _set_view(View.DINING))
	hbox.add_child(dishes_btn)

	var dining_btn := Button.new()
	dining_btn.text = "Dining Room →"
	dining_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dining_btn.custom_minimum_size.y = 48
	dining_btn.add_theme_font_size_override("font_size", 14)
	dining_btn.add_theme_color_override("font_color", COL_ACCENT_BLUE)
	_style_btn_card(dining_btn, COL_CARD)
	dining_btn.pressed.connect(func(): _set_view(View.DINING))
	hbox.add_child(dining_btn)

	_bottom_strip.visible = true


func _build_station_buttons() -> void:
	for i in range(STATION_RECTS.size()):
		var r: Array = STATION_RECTS[i]
		var btn := Button.new()
		btn.text = ""
		btn.position = Vector2(float(r[0]), float(r[1]))
		btn.size = Vector2(float(r[2]), float(r[3]))
		var empty_style := StyleBoxEmpty.new()
		btn.add_theme_stylebox_override("normal", empty_style)
		btn.add_theme_stylebox_override("hover", empty_style)
		btn.add_theme_stylebox_override("pressed", empty_style)
		btn.add_theme_stylebox_override("focus", empty_style)
		var cap_i: int = i
		btn.pressed.connect(func(): _on_station_tap(cap_i))
		_station_layer.add_child(btn)
		_station_btns.append(btn)


# ═══════════════════════════════════════════════════════════════════
# VIEW: KITCHEN SHEET — cooking panel slides up from y=380
# ═══════════════════════════════════════════════════════════════════

func _build_kitchen_sheet() -> void:
	_sheet_panel.visible = true
	_sheet_panel.offset_top = SHEET_Y_HALF
	_sheet_panel.offset_bottom = BOTTOM_STRIP_Y

	# Tap-above-sheet dismiss zone
	var dismiss_btn := Button.new()
	dismiss_btn.text = ""
	dismiss_btn.position = Vector2(0, TOP_BAR_H)
	dismiss_btn.size = Vector2(390, SHEET_Y_HALF - TOP_BAR_H)
	var empty := StyleBoxEmpty.new()
	dismiss_btn.add_theme_stylebox_override("normal", empty)
	dismiss_btn.add_theme_stylebox_override("hover", empty)
	dismiss_btn.add_theme_stylebox_override("pressed", empty)
	dismiss_btn.add_theme_stylebox_override("focus", empty)
	dismiss_btn.pressed.connect(func():
		_active_station = -1
		_bench_ings.clear()
		_bench_method = 0
		_bench_style = 0
		_set_view(View.KITCHEN_IDLE))
	_root.add_child(dismiss_btn)
	_station_btns.append(dismiss_btn)  # cleaned up on next rebuild

	# Header: station name + close button
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	_sheet_content.add_child(header)

	var station_lbl := Label.new()
	station_lbl.text = STATION_NAMES[_active_station] if _active_station >= 0 else "Station"
	station_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	station_lbl.add_theme_font_size_override("font_size", 16)
	station_lbl.add_theme_color_override("font_color", COL_ACCENT_YELLOW)
	header.add_child(station_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(40, 36)
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	_style_btn_flat(close_btn)
	close_btn.pressed.connect(func():
		_active_station = -1
		_bench_ings.clear()
		_bench_method = 0
		_bench_style = 0
		_set_view(View.KITCHEN_IDLE))
	header.add_child(close_btn)

	# Saved recipes (compact, above bench)
	if not GameState.discovered_recipes.is_empty():
		_section_label("SAVED RECIPES")
		for rkey in GameState.discovered_recipes:
			var recipe: Dictionary = GameState.discovered_recipes[rkey]
			_build_recipe_shortcut(recipe)

	# Bench slots (3 horizontal)
	_section_label("BENCH")
	var bench_row := HBoxContainer.new()
	bench_row.add_theme_constant_override("separation", 6)
	_sheet_content.add_child(bench_row)
	var max_slots: int = GameState.get_bench_slots()
	var slot_w: float = 114.0
	for i in range(max_slots):
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(slot_w, 44)
		var slot_style := StyleBoxFlat.new()
		slot_style.set_corner_radius_all(8)
		slot_style.content_margin_left = 6
		slot_style.content_margin_right = 6
		slot_style.content_margin_top = 4
		slot_style.content_margin_bottom = 4
		if i < _bench_ings.size():
			var ing: String = _bench_ings[i]
			var binfo: Dictionary = GameState.ingredient_tiers.get(ing, {})
			var display_name: String = str(binfo.get("name", ing))
			if display_name.length() > 12:
				display_name = display_name.substr(0, 12)
			slot.text = display_name
			slot.add_theme_font_size_override("font_size", 11)
			slot.add_theme_color_override("font_color", Color.WHITE)
			slot_style.bg_color = Color(0.06, 0.12, 0.20)
			slot_style.set_border_width_all(1)
			slot_style.border_color = COL_BORDER_GREEN
			var cap_i: int = i
			slot.pressed.connect(func():
				_bench_ings.remove_at(cap_i)
				_needs_rebuild = true)
		else:
			slot.text = "+"
			slot.add_theme_font_size_override("font_size", 18)
			slot.add_theme_color_override("font_color", Color(0.4, 0.4, 0.6))
			slot_style.bg_color = Color(0.04, 0.06, 0.10)
			slot_style.set_border_width_all(1)
			slot_style.border_color = COL_BORDER
			slot.disabled = true
		slot.add_theme_stylebox_override("normal", slot_style)
		var dis_style: StyleBoxFlat = slot_style.duplicate()
		dis_style.bg_color = Color(0.03, 0.05, 0.09, 0.5)
		slot.add_theme_stylebox_override("disabled", dis_style)
		bench_row.add_child(slot)

	# Add Ingredients button
	var add_btn := Button.new()
	add_btn.text = "＋ Add Ingredients"
	add_btn.custom_minimum_size.y = 42
	add_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_btn.add_theme_font_size_override("font_size", 14)
	add_btn.add_theme_color_override("font_color", COL_ACCENT_BLUE)
	_style_btn_card(add_btn, COL_CARD)
	add_btn.pressed.connect(func(): _set_view(View.KITCHEN_PICKER))
	_sheet_content.add_child(add_btn)

	# METHOD pills
	_section_label("METHOD")
	var methods: Array = GameState.cooking_methods
	var mscroll := ScrollContainer.new()
	mscroll.custom_minimum_size.y = 40
	mscroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sheet_content.add_child(mscroll)
	var mflow := HBoxContainer.new()
	mflow.add_theme_constant_override("separation", 6)
	mscroll.add_child(mflow)
	for mi in range(methods.size()):
		var m: Dictionary = methods[mi]
		var mb := _make_pill_btn(str(m.get("name", "?")), mi == _bench_method)
		var cap_mi: int = mi
		mb.pressed.connect(func():
			_bench_method = cap_mi
			_needs_rebuild = true)
		mflow.add_child(mb)

	# STYLE pills
	_section_label("STYLE")
	var styles: Array = GameState.serving_styles
	var sscroll := ScrollContainer.new()
	sscroll.custom_minimum_size.y = 40
	sscroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sheet_content.add_child(sscroll)
	var sflow := HBoxContainer.new()
	sflow.add_theme_constant_override("separation", 6)
	sscroll.add_child(sflow)
	for si in range(styles.size()):
		var s: Dictionary = styles[si]
		var sb := _make_pill_btn(str(s.get("name", "?")), si == _bench_style)
		var cap_si: int = si
		sb.pressed.connect(func():
			_bench_style = cap_si
			_needs_rebuild = true)
		sflow.add_child(sb)

	# COOK button
	var can_cook: bool = not _bench_ings.is_empty() and not _cooking
	var cook_btn := Button.new()
	cook_btn.text = "COOK" if can_cook else "Add ingredients first"
	cook_btn.disabled = not can_cook
	cook_btn.custom_minimum_size.y = 56
	cook_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cook_btn.add_theme_font_size_override("font_size", 18)
	cook_btn.add_theme_color_override("font_color", Color.WHITE)
	var cook_style := StyleBoxFlat.new()
	cook_style.set_corner_radius_all(12)
	cook_style.content_margin_top = 8
	cook_style.content_margin_bottom = 8
	if can_cook:
		cook_style.bg_color = Color(0.1, 0.45, 0.15)
		cook_style.set_border_width_all(1)
		cook_style.border_color = COL_BORDER_GREEN
	else:
		cook_style.bg_color = Color(0.10, 0.10, 0.15)
	cook_btn.add_theme_stylebox_override("normal", cook_style)
	cook_btn.add_theme_stylebox_override("disabled", cook_style)
	var cook_hover: StyleBoxFlat = cook_style.duplicate()
	cook_hover.bg_color = cook_style.bg_color.lightened(0.08)
	cook_btn.add_theme_stylebox_override("hover", cook_hover)
	cook_btn.pressed.connect(_on_cook)
	_sheet_content.add_child(cook_btn)

	# Bottom strip — same as idle
	_build_kitchen_bottom_strip()


func _build_recipe_shortcut(recipe: Dictionary) -> void:
	var rname: String = str(recipe.get("name", "?"))
	var r_ings: Array = recipe.get("ingredients", [])
	var r_method: String = str(recipe.get("method", ""))
	var r_style: String = str(recipe.get("style", ""))

	# Determine tier
	var r_tier: int = 1
	for ri in r_ings:
		var rt: int = int(GameState.ingredient_tiers.get(ri, {}).get("tier", 1))
		if rt > r_tier:
			r_tier = rt

	# Check availability
	var can_make: bool = true
	var missing: Array = []
	var temp_counts: Dictionary = {}
	for ri in r_ings:
		temp_counts[ri] = int(temp_counts.get(ri, 0)) + 1
	for ri in temp_counts:
		var have: int = int(GameState.restaurant_ingredients.get(ri, 0))
		if have < int(temp_counts[ri]):
			can_make = false
			var iname: String = str(GameState.ingredient_tiers.get(ri, {}).get("name", ri))
			missing.append(iname)

	var rbtn := Button.new()
	rbtn.text = "%s (T%d)" % [rname, r_tier]
	rbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rbtn.custom_minimum_size.y = 38
	rbtn.add_theme_font_size_override("font_size", 12)
	rbtn.add_theme_color_override("font_color", COL_ACCENT_YELLOW if can_make else Color(0.5, 0.5, 0.6))
	var rstyle := StyleBoxFlat.new()
	rstyle.bg_color = Color(0.05, 0.07, 0.12)
	rstyle.set_corner_radius_all(8)
	rstyle.set_border_width_all(1)
	rstyle.border_color = Color(0.8, 0.6, 0.2, 0.7) if can_make else Color(0.2, 0.2, 0.3, 0.4)
	rstyle.content_margin_left = 10
	rstyle.content_margin_right = 10
	rstyle.content_margin_top = 3
	rstyle.content_margin_bottom = 3
	rbtn.add_theme_stylebox_override("normal", rstyle)
	var rhover: StyleBoxFlat = rstyle.duplicate()
	rhover.bg_color = Color(0.08, 0.12, 0.18)
	rbtn.add_theme_stylebox_override("hover", rhover)

	var cap_ings: Array = r_ings.duplicate()
	var cap_method: String = r_method
	var cap_style: String = r_style
	var cap_can: bool = can_make
	var cap_missing: Array = missing.duplicate()
	rbtn.pressed.connect(func():
		if not cap_can:
			_show_msg("Need: " + ", ".join(cap_missing), 3.0)
			return
		_bench_ings = cap_ings.duplicate()
		for mi in range(GameState.cooking_methods.size()):
			if str(GameState.cooking_methods[mi].get("id", "")) == cap_method:
				_bench_method = mi
				break
		for si in range(GameState.serving_styles.size()):
			if str(GameState.serving_styles[si].get("id", "")) == cap_style:
				_bench_style = si
				break
		_needs_rebuild = true)
	_sheet_content.add_child(rbtn)


# ═══════════════════════════════════════════════════════════════════
# VIEW: KITCHEN PICKER — ingredient picker slides up from y=274
# ═══════════════════════════════════════════════════════════════════

func _build_kitchen_picker() -> void:
	_sheet_panel.visible = true
	_sheet_panel.offset_top = SHEET_Y_FULL
	_sheet_panel.offset_bottom = BOTTOM_STRIP_Y

	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	_sheet_content.add_child(header)

	var title := Label.new()
	title.text = "Add Ingredients"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color.WHITE)
	header.add_child(title)

	var done_btn := Button.new()
	done_btn.text = "Done"
	done_btn.custom_minimum_size = Vector2(70, 36)
	done_btn.add_theme_font_size_override("font_size", 14)
	done_btn.add_theme_color_override("font_color", COL_ACCENT_BLUE)
	_style_btn_flat(done_btn)
	done_btn.pressed.connect(func(): _set_view(View.KITCHEN_SHEET))
	header.add_child(done_btn)

	# Saved recipes collapsible row
	if not GameState.discovered_recipes.is_empty():
		var recipe_count: int = GameState.discovered_recipes.size()
		var recipe_row := Button.new()
		recipe_row.text = "⚡ %d recipes ▶" % recipe_count
		recipe_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		recipe_row.custom_minimum_size.y = 34
		recipe_row.add_theme_font_size_override("font_size", 12)
		recipe_row.add_theme_color_override("font_color", COL_ACCENT_YELLOW)
		_style_btn_card(recipe_row, Color(0.06, 0.08, 0.12))
		recipe_row.pressed.connect(func(): _set_view(View.KITCHEN_SHEET))
		_sheet_content.add_child(recipe_row)

	# 2-column pantry grid
	var pantry := GridContainer.new()
	pantry.columns = 2
	pantry.add_theme_constant_override("h_separation", 6)
	pantry.add_theme_constant_override("v_separation", 6)
	_sheet_content.add_child(pantry)

	var max_slots: int = GameState.get_bench_slots()
	var has_any: bool = false
	for ing_id in GameState.restaurant_ingredients:
		var count: int = int(GameState.restaurant_ingredients[ing_id])
		if count <= 0:
			continue
		has_any = true
		var already: int = _bench_ings.count(ing_id)
		var info: Dictionary = GameState.ingredient_tiers.get(ing_id, {})
		var tier: int = int(info.get("tier", 1))
		var name_str: String = str(info.get("name", ing_id.replace("_", " ").capitalize()))
		var on_bench: bool = already > 0
		var is_full: bool = (_bench_ings.size() >= max_slots)
		var is_depleted: bool = (already >= count)

		var btn := Button.new()
		btn.text = "%s  ×%d" % [name_str, count - already]
		btn.disabled = is_depleted or is_full
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(183, 62)
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_color_override("font_color", Color.WHITE)

		var card_style := StyleBoxFlat.new()
		card_style.bg_color = COL_CARD
		card_style.set_corner_radius_all(8)
		card_style.set_border_width_all(1)
		card_style.border_color = COL_BORDER_GREEN if on_bench else COL_BORDER
		card_style.content_margin_left = 10
		card_style.content_margin_right = 8
		card_style.content_margin_top = 6
		card_style.content_margin_bottom = 6
		btn.add_theme_stylebox_override("normal", card_style)
		var hover_s: StyleBoxFlat = card_style.duplicate()
		hover_s.bg_color = Color(0.08, 0.14, 0.22)
		btn.add_theme_stylebox_override("hover", hover_s)
		var pressed_s: StyleBoxFlat = card_style.duplicate()
		pressed_s.bg_color = Color(0.10, 0.18, 0.28)
		btn.add_theme_stylebox_override("pressed", pressed_s)
		var disabled_s: StyleBoxFlat = card_style.duplicate()
		disabled_s.bg_color = Color(0.03, 0.05, 0.09, 0.7)
		disabled_s.border_color = Color(0.08, 0.12, 0.18)
		btn.add_theme_stylebox_override("disabled", disabled_s)

		var cap_id: String = ing_id
		btn.pressed.connect(func():
			if _bench_ings.size() < max_slots and int(GameState.restaurant_ingredients.get(cap_id, 0)) > _bench_ings.count(cap_id):
				_bench_ings.append(cap_id)
				_needs_rebuild = true)

		# Drag support
		var cap_drag_id: String = ing_id
		btn.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				if not btn.disabled:
					_drag_pending = true
					_drag_ing = cap_drag_id
					_drag_start_pos = ev.global_position
			elif ev is InputEventMouseMotion and _drag_pending and _drag_ing == cap_drag_id:
				if ev.global_position.distance_to(_drag_start_pos) > 15.0:
					_drag_pending = false
					_start_drag(cap_drag_id, ev.global_position)
			elif ev is InputEventMouseButton and not ev.pressed:
				_drag_pending = false
			elif ev is InputEventScreenTouch and ev.pressed:
				if not btn.disabled:
					_drag_pending = true
					_drag_ing = cap_drag_id
					_drag_start_pos = ev.position
			elif ev is InputEventScreenDrag and _drag_pending and _drag_ing == cap_drag_id:
				if ev.position.distance_to(_drag_start_pos) > 15.0:
					_drag_pending = false
					_start_drag(cap_drag_id, ev.position)
			elif ev is InputEventScreenTouch and not ev.pressed:
				_drag_pending = false)
		pantry.add_child(btn)

	if not has_any:
		var lbl := Label.new()
		lbl.text = "Pantry empty — hunt creatures first"
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		_sheet_content.add_child(lbl)

	# Bottom strip
	_build_kitchen_bottom_strip()


func _build_kitchen_bottom_strip() -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	_bottom_strip.add_child(hbox)

	var dish_count: int = GameState.prepared_dishes.size()
	var dishes_btn := Button.new()
	dishes_btn.text = "🍽 %d dishes ready" % dish_count if dish_count > 0 else "🍽 No dishes"
	dishes_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dishes_btn.custom_minimum_size.y = 48
	dishes_btn.add_theme_font_size_override("font_size", 14)
	dishes_btn.add_theme_color_override("font_color", COL_ACCENT_YELLOW if dish_count > 0 else Color(0.5, 0.5, 0.6))
	dishes_btn.disabled = (dish_count == 0)
	_style_btn_card(dishes_btn, COL_CARD)
	dishes_btn.pressed.connect(func(): _set_view(View.DINING))
	hbox.add_child(dishes_btn)

	var dining_btn := Button.new()
	dining_btn.text = "Dining Room →"
	dining_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dining_btn.custom_minimum_size.y = 48
	dining_btn.add_theme_font_size_override("font_size", 14)
	dining_btn.add_theme_color_override("font_color", COL_ACCENT_BLUE)
	_style_btn_card(dining_btn, COL_CARD)
	dining_btn.pressed.connect(func(): _set_view(View.DINING))
	hbox.add_child(dining_btn)

	_bottom_strip.visible = true


# ═══════════════════════════════════════════════════════════════════
# VIEW: DINING — guest cards in scrollable area
# ═══════════════════════════════════════════════════════════════════

func _build_dining_view() -> void:
	# Use sheet panel as full-height scroll area for guests
	_sheet_panel.visible = true
	_sheet_panel.offset_top = TOP_BAR_H
	_sheet_panel.offset_bottom = BOTTOM_STRIP_Y

	if GameState.pending_guests.is_empty():
		var lbl := Label.new()
		lbl.text = "No guests today — leave and return"
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		_sheet_content.add_child(lbl)
	else:
		for gi in range(GameState.pending_guests.size()):
			var guest: Dictionary = GameState.pending_guests[gi]
			_build_guest_card(gi, guest)

	# Bottom strip: Kitchen button
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	_bottom_strip.add_child(hbox)

	var kitchen_btn := Button.new()
	kitchen_btn.text = "← Kitchen"
	kitchen_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kitchen_btn.custom_minimum_size.y = 48
	kitchen_btn.add_theme_font_size_override("font_size", 14)
	kitchen_btn.add_theme_color_override("font_color", COL_ACCENT_BLUE)
	_style_btn_card(kitchen_btn, COL_CARD)
	kitchen_btn.pressed.connect(func():
		_active_station = -1
		_bench_ings.clear()
		_set_view(View.KITCHEN_IDLE))
	hbox.add_child(kitchen_btn)

	_bottom_strip.visible = true


func _build_guest_card(idx: int, guest: Dictionary) -> void:
	var is_special: bool = guest.get("special", false)
	var resolved: bool = guest.get("_resolved", false)
	var faction: String = str(guest.get("faction", "independents"))

	var card := PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.10, 0.07, 0.05, 0.95) if is_special else COL_CARD
	cs.set_border_width_all(1)
	cs.border_color = COL_ACCENT_YELLOW if is_special else FACTION_COLORS.get(faction, COL_BORDER)
	cs.set_corner_radius_all(10)
	cs.content_margin_left = 10
	cs.content_margin_right = 10
	cs.content_margin_top = 8
	cs.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", cs)
	_sheet_content.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Name + faction badge
	var name_row := HBoxContainer.new()
	vbox.add_child(name_row)
	var name_lbl := Label.new()
	name_lbl.text = str(guest.get("name", "Guest"))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", COL_ACCENT_YELLOW if is_special else Color.WHITE)
	name_row.add_child(name_lbl)

	var faction_lbl := Label.new()
	faction_lbl.text = "[%s]" % faction.capitalize()
	faction_lbl.add_theme_font_size_override("font_size", 11)
	faction_lbl.add_theme_color_override("font_color", FACTION_COLORS.get(faction, Color(0.6, 0.6, 0.7)))
	name_row.add_child(faction_lbl)

	# Role/trait
	if not is_special:
		var trait_lbl := Label.new()
		trait_lbl.text = "%s | %s" % [str(guest.get("role", "")), str(guest.get("trait", ""))]
		trait_lbl.add_theme_font_size_override("font_size", 11)
		trait_lbl.add_theme_color_override("font_color", Color(0.50, 0.50, 0.60))
		vbox.add_child(trait_lbl)

	# LOVES / HATES
	var dp: Dictionary = GameState.faction_dietary.get(faction, {})
	var loves: Array = dp.get("loves", [])
	var hates: Array = dp.get("hates", [])
	if loves.is_empty() and hates.is_empty():
		var p := Label.new()
		p.text = "Eats anything"
		p.add_theme_font_size_override("font_size", 11)
		p.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
		vbox.add_child(p)
	else:
		if not loves.is_empty():
			var ns: Array = []
			for k in loves:
				ns.append(str(PREF_MAP.get(k, k)))
			var lbl := Label.new()
			lbl.text = "LOVES: " + ", ".join(ns)
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.add_theme_font_size_override("font_size", 11)
			lbl.add_theme_color_override("font_color", COL_ACCENT_GREEN)
			vbox.add_child(lbl)
		if not hates.is_empty():
			var ns: Array = []
			for k in hates:
				ns.append(str(PREF_MAP.get(k, k)))
			var lbl := Label.new()
			lbl.text = "HATES: " + ", ".join(ns)
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.add_theme_font_size_override("font_size", 11)
			lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
			vbox.add_child(lbl)

	# Special intro text
	if is_special:
		var intro := Label.new()
		intro.text = str(guest.get("intro", ""))
		intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		intro.add_theme_font_size_override("font_size", 12)
		intro.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
		vbox.add_child(intro)

	# Already resolved — show result
	if resolved:
		var res_lbl := Label.new()
		res_lbl.text = str(guest.get("_result_message", "Served."))
		res_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		res_lbl.add_theme_font_size_override("font_size", 12)
		res_lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
		vbox.add_child(res_lbl)
		card.modulate = Color(0.6, 0.6, 0.6)
		return

	# Special choice buttons
	if is_special:
		var choice_id: String = str(guest.get("choice_id", ""))
		if choice_id == "velka_first_visit":
			var has_t3: bool = false
			for pd in GameState.prepared_dishes:
				if int(pd.get("tier", 0)) >= 3:
					has_t3 = true
					break
			if has_t3:
				_add_choice_btn(vbox, idx, "serve_leviathan", "Serve Leviathan Cut", Color(1.0, 0.7, 0.2))
				_add_choice_btn(vbox, idx, "overcharge", "Overcharge (risky)", Color(0.9, 0.3, 0.3))
			else:
				_add_choice_btn(vbox, idx, "honest", "Tell her you don't have it", Color(0.6, 0.8, 0.6))
				_add_choice_btn(vbox, idx, "bluff", "Bluff with something else", Color(0.9, 0.7, 0.3))
				_add_choice_btn(vbox, idx, "defer", "Offer a drink, ask her back", Color(0.5, 0.6, 0.9))
		elif choice_id == "drath_first_visit":
			_add_choice_btn(vbox, idx, "cooperate", "Cooperate with inspection", Color(0.4, 0.7, 1.0))
			_add_choice_btn(vbox, idx, "bribe_food", "Bribe with food (-100 cr)", Color(0.9, 0.7, 0.3))
			_add_choice_btn(vbox, idx, "probe", "Ask what he's really after", Color(0.6, 0.6, 0.9))
		return

	# Serve buttons for procedural guests (per unique dish)
	if GameState.prepared_dishes.is_empty():
		var nd := Label.new()
		nd.text = "No dishes — cook something first"
		nd.add_theme_font_size_override("font_size", 12)
		nd.add_theme_color_override("font_color", Color(0.5, 0.4, 0.4))
		vbox.add_child(nd)
	else:
		var shown: Dictionary = {}
		for di in range(GameState.prepared_dishes.size()):
			var pd: Dictionary = GameState.prepared_dishes[di]
			var dname: String = str(pd.get("name", "?"))
			if shown.has(dname):
				continue
			shown[dname] = true
			var loved: bool = str(pd.get("method", "")) in loves or str(pd.get("style", "")) in loves
			var hated: bool = str(pd.get("method", "")) in hates or str(pd.get("style", "")) in hates
			var tag: String = " [+]" if loved else (" [-]" if hated else "")
			var col: Color = COL_ACCENT_GREEN if loved else (Color(1.0, 0.4, 0.4) if hated else Color(0.85, 0.85, 0.85))
			var srv := Button.new()
			srv.text = "Serve: %s%s" % [dname, tag]
			srv.custom_minimum_size.y = 40
			srv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			srv.add_theme_font_size_override("font_size", 13)
			srv.add_theme_color_override("font_color", col)
			_style_btn_card(srv, COL_CARD)
			var cap_gi: int = idx
			var cap_name: String = dname
			srv.pressed.connect(func(): _serve_guest_named(cap_gi, cap_name))
			vbox.add_child(srv)


# ═══════════════════════════════════════════════════════════════════
# DRAG AND DROP
# ═══════════════════════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	if _view != View.KITCHEN_PICKER:
		return

	if _drag_active and _drag_preview != null and is_instance_valid(_drag_preview):
		if event is InputEventMouseMotion:
			_drag_preview.position = event.position - Vector2(40.0, 20.0)
		elif event is InputEventScreenDrag:
			_drag_preview.position = event.position - Vector2(40.0, 20.0)
		if event is InputEventMouseButton and not event.pressed:
			_finish_drag(event.position)
		elif event is InputEventScreenTouch and not event.pressed:
			_finish_drag(event.position)


func _start_drag(ing_id: String, start_pos: Vector2) -> void:
	if _drag_active:
		return
	_drag_active = true
	_drag_ing = ing_id

	var info: Dictionary = GameState.ingredient_tiers.get(ing_id, {})
	var name_str: String = str(info.get("name", ing_id.replace("_", " ").capitalize()))

	_drag_preview = Label.new()
	_drag_preview.text = name_str
	_drag_preview.add_theme_font_size_override("font_size", 14)
	_drag_preview.add_theme_color_override("font_color", COL_ACCENT_YELLOW)
	_drag_preview.position = start_pos - Vector2(40.0, 20.0)
	_drag_preview.z_index = 100
	_root.add_child(_drag_preview)


func _finish_drag(pos: Vector2) -> void:
	_drag_active = false
	if _drag_preview != null and is_instance_valid(_drag_preview):
		_drag_preview.call_deferred("queue_free")
		_drag_preview = null

	if _drag_ing.is_empty():
		return

	var max_slots: int = GameState.get_bench_slots()
	if _bench_ings.size() < max_slots:
		var count: int = int(GameState.restaurant_ingredients.get(_drag_ing, 0))
		var already: int = _bench_ings.count(_drag_ing)
		if already < count:
			_bench_ings.append(_drag_ing)
			_needs_rebuild = true

	_drag_ing = ""


# ═══════════════════════════════════════════════════════════════════
# ACTIONS
# ═══════════════════════════════════════════════════════════════════

func _on_station_tap(idx: int) -> void:
	_active_station = idx
	if is_instance_valid(_canvas):
		_canvas.active_station = idx
		_canvas.show_hint = false
		_canvas.queue_redraw()
	_view = View.KITCHEN_SHEET
	_needs_rebuild = true


func _on_cook() -> void:
	if _bench_ings.is_empty() or _cooking:
		return

	var methods: Array = GameState.cooking_methods
	var styles: Array = GameState.serving_styles
	var method_id: String = str(methods[_bench_method].get("id", "char_grill"))
	var style_id: String = str(styles[_bench_style].get("id", "diner"))

	_cooking = true
	_cook_timer = 1.5
	_cook_station_idx = _active_station if _active_station >= 0 else 2

	_move_npc_to_station(_cook_station_idx)

	if is_instance_valid(_canvas):
		_canvas.glow_station = _cook_station_idx
		_canvas.glow_alpha = 0.5
		_canvas.queue_redraw()

	set_meta("_cook_ings", _bench_ings.duplicate())
	set_meta("_cook_method", method_id)
	set_meta("_cook_style", style_id)

	_show_msg("Cooking...", 2.0)


func _finish_cook() -> void:
	var ings: Array = get_meta("_cook_ings", [])
	var method_id: String = str(get_meta("_cook_method", "char_grill"))
	var style_id: String = str(get_meta("_cook_style", "diner"))

	var result: Dictionary = GameState.resolve_experiment(ings, method_id, style_id)

	_bench_ings.clear()

	if is_instance_valid(_canvas):
		_canvas.glow_station = -1
		_canvas.glow_alpha = 0.0
		_canvas.queue_redraw()

	_move_npc_home()

	var result_type: String = str(result.get("result", "fail"))
	if result_type == "fail":
		_show_msg(str(result.get("message", "Failed.")), 4.0)
	elif result_type == "catastrophe":
		_show_msg(str(result.get("message", "Something went wrong.")), 5.0)
	else:
		var recipe: Dictionary = result.get("recipe", {})
		var dish_name: String = str(recipe.get("name", "Mystery Dish"))
		if result_type == "known":
			_show_msg("%s — added to queue!" % dish_name, 3.0)
		else:
			_show_msg("New: %s — added to queue!" % dish_name, 3.0)

	SaveManager.save_game()
	_result_timer = 2.0
	_needs_rebuild = true


func _serve_guest_named(guest_idx: int, dish_name: String) -> void:
	if guest_idx < 0 or guest_idx >= GameState.pending_guests.size():
		return
	# Move named dish to front of queue
	for i in range(GameState.prepared_dishes.size()):
		if str(GameState.prepared_dishes[i].get("name", "")) == dish_name:
			if i != 0:
				var dish: Dictionary = GameState.prepared_dishes[i]
				GameState.prepared_dishes.remove_at(i)
				GameState.prepared_dishes.insert(0, dish)
			break
	var guest: Dictionary = GameState.pending_guests[guest_idx]
	var result: Dictionary = GameState.resolve_guest(guest, "auto")
	var msg: String = str(result.get("message", "Served."))
	guest["_resolved"] = true
	guest["_result_message"] = msg
	_show_msg(msg, 4.0)
	SaveManager.save_game()
	_needs_rebuild = true


func _resolve_special(guest_idx: int, choice: String) -> void:
	if guest_idx < 0 or guest_idx >= GameState.pending_guests.size():
		return
	var guest: Dictionary = GameState.pending_guests[guest_idx]
	var result: Dictionary = GameState.resolve_guest(guest, choice)
	var msg: String = str(result.get("message", "Done."))
	guest["_resolved"] = true
	guest["_result_message"] = msg
	_show_msg(msg, 5.0)
	SaveManager.save_game()
	_needs_rebuild = true


func _add_choice_btn(parent: VBoxContainer, guest_idx: int, choice: String, label: String, col: Color) -> void:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size.y = 38
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", col)
	_style_btn_card(btn, COL_CARD)
	var cap_idx: int = guest_idx
	var cap_choice: String = choice
	btn.pressed.connect(func(): _resolve_special(cap_idx, cap_choice))
	parent.add_child(btn)


# ═══════════════════════════════════════════════════════════════════
# NPC MOVEMENT
# ═══════════════════════════════════════════════════════════════════

func _move_npc_to_station(station_idx: int) -> void:
	if not is_instance_valid(_canvas):
		return
	# Targets matching station rect centers
	var targets: Array = [Vector2(85, 260), Vector2(305, 240), Vector2(195, 400), Vector2(70, 470)]
	if station_idx < 0 or station_idx >= targets.size():
		return
	if _npc_tween != null and _npc_tween.is_valid():
		_npc_tween.kill()
	_npc_tween = create_tween()
	_npc_tween.tween_property(_canvas, "npc_pos", targets[station_idx], 0.4)
	_npc_tween.tween_callback(func(): _canvas.queue_redraw())


func _move_npc_home() -> void:
	if not is_instance_valid(_canvas):
		return
	if _npc_tween != null and _npc_tween.is_valid():
		_npc_tween.kill()
	_npc_tween = create_tween()
	_npc_tween.tween_property(_canvas, "npc_pos", _npc_home, 0.4)
	_npc_tween.tween_callback(func(): _canvas.queue_redraw())


# ═══════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════

func _section_label(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", COL_ACCENT_BLUE)
	_sheet_content.add_child(lbl)


func _show_msg(text: String, duration: float = 3.0) -> void:
	if is_instance_valid(_msg_lbl):
		_msg_lbl.text = text
	_msg_timer = duration


func _make_pill_btn(text: String, selected: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size.y = 36
	btn.add_theme_font_size_override("font_size", 12)
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(18)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.set_border_width_all(1)
	if selected:
		style.bg_color = Color(0.15, 0.35, 0.70)
		style.border_color = COL_BORDER_ACTIVE
		btn.add_theme_color_override("font_color", Color.WHITE)
	else:
		style.bg_color = Color(0.05, 0.08, 0.14)
		style.border_color = COL_BORDER
		btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8))
	btn.add_theme_stylebox_override("normal", style)
	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.08)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = style.duplicate()
	pressed.bg_color = style.bg_color.lightened(0.12)
	btn.add_theme_stylebox_override("pressed", pressed)
	return btn


func _style_btn_flat(btn: Button) -> void:
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("focus", empty)


func _style_btn_card(btn: Button, bg_col: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_col
	style.set_corner_radius_all(10)
	style.set_border_width_all(1)
	style.border_color = COL_BORDER
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", style)
	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = bg_col.lightened(0.06)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = style.duplicate()
	pressed.bg_color = bg_col.lightened(0.1)
	btn.add_theme_stylebox_override("pressed", pressed)
	var disabled: StyleBoxFlat = style.duplicate()
	disabled.bg_color = bg_col.darkened(0.3)
	disabled.border_color = COL_BORDER.darkened(0.3)
	btn.add_theme_stylebox_override("disabled", disabled)


func _on_back() -> void:
	SaveManager.save_game()
	call_deferred("_do_close")


func _do_close() -> void:
	queue_free()
