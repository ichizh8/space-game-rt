extends CanvasLayer

# RestaurantRoom — full-screen isometric restaurant scene
# Replaces old restaurant_scene.gd CanvasLayer overlay
# Kitchen side: 3 cooking stations, ingredient bench, cook NPC
# Dining side: guest tables with serve interaction

const FACTION_COLORS: Dictionary = {
	"coalition": Color(0.4, 0.7, 1.0),
	"corsairs": Color(1.0, 0.4, 0.3),
	"miners": Color(0.9, 0.7, 0.2),
	"scientists": Color(0.5, 0.9, 0.9),
	"drifters": Color(0.6, 0.9, 0.6),
	"independents": Color(0.7, 0.7, 0.7),
}

const TIER_COLORS: Dictionary = {
	1: Color(0.8, 0.8, 0.8),
	2: Color(0.3, 0.9, 0.4),
	3: Color(1.0, 0.7, 0.2),
}

const STATION_NAMES: Array = ["Grill", "Cold Press", "Prep Bench", "Ferment Pod"]
const STATION_DESCS: Array = ["Char-Heat cooking", "Cryo extraction", "Prep & combine", "Slow ferment"]

enum Room { KITCHEN, DINING }

# ── State ──
var _current_room: int = Room.KITCHEN
var _bench_ings: Array = []
var _bench_method: int = 0
var _bench_style: int = 0
var _selected_dish: int = -1
var _active_station: int = -1
var _step: int = 0  # 0=select station, 1=ingredients, 2=cook

# Cooking animation
var _cooking: bool = false
var _cook_timer: float = 0.0
var _cook_station_idx: int = -1

# NPC
var _npc_home: Vector2 = Vector2(200, 248)  # ART_TOP(88) + 160
var _npc_tween: Tween = null

# Message
var _msg_timer: float = 0.0

# Idle pulse
var _idle_time: float = 0.0

# Guest pulse for empty tables
var _pulse_time: float = 0.0

# Result auto-reset timer
var _result_timer: float = 0.0

# Deferred rebuild flag (WASM safe — never add_child/queue_free from signal callbacks)
var _needs_rebuild: bool = false
var _needs_table_rebuild: bool = false

# ── Textures ──
var _kitchen_bg_tex: Texture2D = null
var _dining_bg_tex: Texture2D = null
var _cook_npc_tex: Texture2D = null

# ── Canvas script ──
var _canvas_script: GDScript = null

# ── Key nodes ──
var _root: Panel
var _canvas: Control  # restaurant_canvas.gd instance
var _credits_lbl: Label
var _msg_lbl: Label
var _scroll: ScrollContainer
var _content: VBoxContainer
var _kitchen_pill: Button
var _dining_pill: Button
var _station_btns: Array = []
var _step_bar_container: HBoxContainer
var _step_labels: Array = []

# Layout constants (390x844 viewport)
const TOP_BAR_H: int = 48
const PILL_H: int = 40
const ART_H: int = 240
const MSG_H: int = 36
const STEP_BAR_H: int = 36
const ART_TOP: int = 88  # TOP_BAR_H + PILL_H
const STEP_BAR_TOP: int = 328  # ART_TOP + ART_H
const SCROLL_TOP: int = 364  # STEP_BAR_TOP + STEP_BAR_H
const MSG_TOP: int = 808


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Load textures — safe in _ready
	_kitchen_bg_tex = load("res://assets/restaurant-kitchen-bg.png")
	_dining_bg_tex = load("res://assets/restaurant-dining-bg.png")
	_cook_npc_tex = load("res://assets/restaurant-cook-npc.png")
	_canvas_script = load("res://scripts/restaurant_canvas.gd")

	GameState.generate_guest_session()
	_build_ui()


func _process(delta: float) -> void:
	# Deferred rebuilds (WASM safe)
	if _needs_table_rebuild:
		_needs_table_rebuild = false
		if _current_room == Room.KITCHEN:
			_build_station_buttons()
		else:
			_build_table_buttons()
	if _needs_rebuild:
		_needs_rebuild = false
		_rebuild_content()

	# Message timer
	if _msg_timer > 0.0:
		_msg_timer -= delta
		if _msg_timer <= 0.0 and is_instance_valid(_msg_lbl):
			_msg_lbl.text = ""

	# Result auto-reset timer
	if _result_timer > 0.0:
		_result_timer -= delta
		if _result_timer <= 0.0:
			_step = 0
			_active_station = -1
			if is_instance_valid(_canvas):
				_canvas.active_station = -1
				_canvas.show_hint = true
				_canvas.queue_redraw()
			_needs_rebuild = true
			_needs_table_rebuild = true

	# Cooking timer
	if _cooking:
		_cook_timer -= delta
		if _cook_timer <= 0.0:
			_cooking = false
			_finish_cook()
		elif is_instance_valid(_canvas):
			# Pulse glow
			_canvas.glow_alpha = 0.5 + 0.5 * sin(_cook_timer * 6.0)
			_canvas.queue_redraw()

	# NPC idle pulse (scale 0.98–1.02, 2s loop)
	if not _cooking and _current_room == Room.KITCHEN and is_instance_valid(_canvas):
		_idle_time += delta
		_canvas.npc_scale = 1.0 + 0.02 * sin(_idle_time * PI)
		_canvas.queue_redraw()

	# Empty table pulse
	if _current_room == Room.DINING:
		_pulse_time += delta


func _build_ui() -> void:
	_root = Panel.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.05, 0.1, 0.98)
	_root.add_theme_stylebox_override("panel", bg)
	add_child(_root)

	_build_top_bar()
	_build_room_pills()
	_build_art_canvas()
	_build_step_bar()
	_build_scroll_area()
	_build_msg_bar()
	_switch_room(Room.KITCHEN)


# ── TOP BAR ──────────────────────────────────────────────────────

func _build_top_bar() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_top = 4
	bar.offset_left = 6
	bar.offset_right = -6
	bar.offset_bottom = TOP_BAR_H
	_root.add_child(bar)

	var back_btn := Button.new()
	back_btn.text = "<"
	back_btn.custom_minimum_size = Vector2(44, 40)
	back_btn.add_theme_font_size_override("font_size", 20)
	back_btn.pressed.connect(_on_back)
	bar.add_child(back_btn)

	var title := Label.new()
	title.text = GameState.restaurant_name
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	bar.add_child(title)

	_credits_lbl = Label.new()
	_credits_lbl.text = "%d cr" % GameState.credits
	_credits_lbl.add_theme_font_size_override("font_size", 13)
	_credits_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	bar.add_child(_credits_lbl)


# ── ROOM PILLS ───────────────────────────────────────────────────

func _build_room_pills() -> void:
	var pills := HBoxContainer.new()
	pills.set_anchors_preset(Control.PRESET_TOP_WIDE)
	pills.offset_top = TOP_BAR_H
	pills.offset_left = 40
	pills.offset_right = -40
	pills.offset_bottom = TOP_BAR_H + PILL_H
	pills.add_theme_constant_override("separation", 8)
	_root.add_child(pills)

	_kitchen_pill = _make_pill("Kitchen", pills)
	_kitchen_pill.pressed.connect(func(): call_deferred("_switch_room", Room.KITCHEN))

	_dining_pill = _make_pill("Dining Room", pills)
	_dining_pill.pressed.connect(func(): call_deferred("_switch_room", Room.DINING))


func _make_pill(text: String, parent: HBoxContainer) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size.y = 34
	btn.add_theme_font_size_override("font_size", 14)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.18, 0.28)
	style.set_corner_radius_all(16)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color(0.18, 0.26, 0.4)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate()
	pressed.bg_color = Color(0.2, 0.35, 0.55)
	btn.add_theme_stylebox_override("pressed", pressed)
	parent.add_child(btn)
	return btn


# ── ART CANVAS ───────────────────────────────────────────────────

func _build_art_canvas() -> void:
	_canvas = Control.new()
	if _canvas_script != null:
		_canvas.set_script(_canvas_script)
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.offset_top = 0
	_canvas.offset_left = 0
	_canvas.offset_right = 0
	_canvas.offset_bottom = 0
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Set texture refs
	_canvas.kitchen_bg = _kitchen_bg_tex
	_canvas.dining_bg = _dining_bg_tex
	_canvas.cook_npc_tex = _cook_npc_tex
	_canvas.art_top = float(ART_TOP)
	_canvas.art_height = float(ART_H)
	_canvas.npc_pos = Vector2(200.0, float(ART_TOP) + 160.0)
	_canvas.active_station = _active_station
	_canvas.show_hint = true

	_root.add_child(_canvas)


func _build_station_buttons() -> void:
	# Remove old station buttons
	for btn in _station_btns:
		if is_instance_valid(btn):
			btn.queue_free()
	_station_btns.clear()

	if _current_room != Room.KITCHEN:
		return

	var rects: Array = [[10, 20, 100, 90], [250, 30, 120, 100], [120, 60, 130, 100], [10, 130, 80, 70]]
	for i in range(rects.size()):
		var r: Array = rects[i]
		var btn := Button.new()
		btn.text = ""
		btn.position = Vector2(float(r[0]), ART_TOP + float(r[1]))
		btn.size = Vector2(float(r[2]), float(r[3]))
		# Invisible tap target — canvas _draw() handles all visuals
		var empty_style := StyleBoxEmpty.new()
		btn.add_theme_stylebox_override("normal", empty_style)
		btn.add_theme_stylebox_override("hover", empty_style)
		btn.add_theme_stylebox_override("pressed", empty_style)
		btn.add_theme_stylebox_override("focus", empty_style)
		var cap_i: int = i
		btn.pressed.connect(func(): _on_station_tap(cap_i))
		_root.add_child(btn)
		_station_btns.append(btn)


func _build_table_buttons() -> void:
	for btn in _station_btns:
		if is_instance_valid(btn):
			btn.queue_free()
	_station_btns.clear()

	if _current_room != Room.DINING:
		return

	var rects: Array = [[30, 40, 330, 70], [30, 120, 330, 70], [30, 200, 330, 70]]
	var guests: Array = GameState.pending_guests
	for i in range(rects.size()):
		var r: Array = rects[i]
		var btn := Button.new()
		if i < guests.size():
			var g: Dictionary = guests[i]
			var gname: String = str(g.get("name", "Guest"))
			var faction: String = str(g.get("faction", "independents"))
			var resolved: bool = g.get("_resolved", false)
			btn.text = gname + " [" + faction.capitalize() + "]" + (" (served)" if resolved else "")
			btn.add_theme_color_override("font_color", FACTION_COLORS.get(faction, Color(0.7, 0.7, 0.7)))
			btn.disabled = resolved
		else:
			btn.text = "Awaiting guests..."
			btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
			btn.disabled = true
		btn.position = Vector2(float(r[0]), ART_TOP + float(r[1]))
		btn.size = Vector2(float(r[2]), float(r[3]))
		btn.add_theme_font_size_override("font_size", 12)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.12, 0.22, 0.6)
		style.set_border_width_all(1)
		style.border_color = Color(0.25, 0.35, 0.55, 0.5)
		style.set_corner_radius_all(8)
		btn.add_theme_stylebox_override("normal", style)
		var cap_i: int = i
		btn.pressed.connect(func(): _on_table_tap(cap_i))
		_root.add_child(btn)
		_station_btns.append(btn)


# ── STEP BAR ─────────────────────────────────────────────────────

func _build_step_bar() -> void:
	_step_bar_container = HBoxContainer.new()
	_step_bar_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_step_bar_container.offset_top = STEP_BAR_TOP
	_step_bar_container.offset_left = 10
	_step_bar_container.offset_right = -10
	_step_bar_container.offset_bottom = STEP_BAR_TOP + STEP_BAR_H
	_step_bar_container.add_theme_constant_override("separation", 4)
	_root.add_child(_step_bar_container)

	_step_labels.clear()
	var step_texts: Array = ["1 Station", "2 Ingredients", "3 Cook"]
	for i in range(step_texts.size()):
		var lbl := Label.new()
		lbl.text = step_texts[i]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.custom_minimum_size.y = STEP_BAR_H
		_step_bar_container.add_child(lbl)
		_step_labels.append(lbl)

	_update_step_bar()


func _update_step_bar() -> void:
	if _step_labels.size() < 3:
		return
	var step_texts: Array = ["1 Station", "2 Ingredients", "3 Cook"]
	for i in range(3):
		var lbl: Label = _step_labels[i]
		if i < _step:
			# Completed
			lbl.text = "✓ " + step_texts[i].substr(2)
			lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4, 0.9))
		elif i == _step:
			# Current
			lbl.text = step_texts[i]
			lbl.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0, 1.0))
		else:
			# Future
			lbl.text = step_texts[i]
			lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45, 0.6))

	# Show/hide step bar based on room
	_step_bar_container.visible = (_current_room == Room.KITCHEN)


# ── SCROLL AREA (interaction panel) ──────────────────────────────

func _build_scroll_area() -> void:
	# Dark panel behind scroll with top border to separate from art
	var scroll_bg := PanelContainer.new()
	scroll_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll_bg.offset_top = SCROLL_TOP
	scroll_bg.offset_left = 0
	scroll_bg.offset_right = 0
	scroll_bg.offset_bottom = -MSG_H
	var sbg_style := StyleBoxFlat.new()
	sbg_style.bg_color = Color(0.031, 0.051, 0.102, 1.0)
	sbg_style.border_color = Color(0.2, 0.5, 0.9, 0.5)
	sbg_style.set_border_width_all(0)
	sbg_style.border_width_top = 2
	sbg_style.content_margin_left = 6
	sbg_style.content_margin_right = 6
	sbg_style.content_margin_top = 6
	sbg_style.content_margin_bottom = 0
	scroll_bg.add_theme_stylebox_override("panel", sbg_style)
	_root.add_child(scroll_bg)

	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll_bg.add_child(_scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 6)
	_scroll.add_child(_content)


# ── MESSAGE BAR ──────────────────────────────────────────────────

func _build_msg_bar() -> void:
	_msg_lbl = Label.new()
	_msg_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_msg_lbl.offset_top = -MSG_H
	_msg_lbl.offset_left = 8
	_msg_lbl.offset_right = -8
	_msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_lbl.add_theme_font_size_override("font_size", 12)
	_msg_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_msg_lbl)


# ── ROOM SWITCHING ───────────────────────────────────────────────

func _switch_room(room: int) -> void:
	_current_room = room
	_active_station = -1
	_selected_dish = -1
	_step = 0

	# Update pills
	var active_style := StyleBoxFlat.new()
	active_style.bg_color = Color(0.2, 0.35, 0.55)
	active_style.set_corner_radius_all(16)
	active_style.content_margin_left = 12
	active_style.content_margin_right = 12
	active_style.content_margin_top = 4
	active_style.content_margin_bottom = 4
	var inactive_style := StyleBoxFlat.new()
	inactive_style.bg_color = Color(0.08, 0.12, 0.2)
	inactive_style.set_corner_radius_all(16)
	inactive_style.content_margin_left = 12
	inactive_style.content_margin_right = 12
	inactive_style.content_margin_top = 4
	inactive_style.content_margin_bottom = 4

	if room == Room.KITCHEN:
		_kitchen_pill.add_theme_stylebox_override("normal", active_style)
		_dining_pill.add_theme_stylebox_override("normal", inactive_style)
	else:
		_kitchen_pill.add_theme_stylebox_override("normal", inactive_style)
		_dining_pill.add_theme_stylebox_override("normal", active_style)

	# Update canvas
	if is_instance_valid(_canvas):
		_canvas.show_kitchen = (room == Room.KITCHEN)
		_canvas.glow_station = -1
		_canvas.glow_alpha = 0.0
		_canvas.active_station = _active_station
		_canvas.show_hint = (room == Room.KITCHEN)
		_canvas.queue_redraw()

	# Update step bar
	_update_step_bar()

	# Rebuild interactive elements
	if room == Room.KITCHEN:
		_build_station_buttons()
	else:
		_build_table_buttons()
	_rebuild_content()


func _rebuild_content() -> void:
	# Remove all children synchronously — safe here since _rebuild_content
	# is only called from _process() (never from a signal callback directly)
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	if is_instance_valid(_credits_lbl):
		_credits_lbl.text = "%d cr" % GameState.credits
	_update_step_bar()
	match _current_room:
		Room.KITCHEN:
			_build_kitchen_panel()
		Room.DINING:
			_build_dining_panel()


# ── KITCHEN PANEL (step-based) ──────────────────────────────────

func _build_kitchen_panel() -> void:
	match _step:
		0:
			_build_kitchen_step0()
		1:
			_build_kitchen_step1()
		2:
			_build_kitchen_step2()


func _build_kitchen_step0() -> void:
	# Step 0: station selection — minimal bottom panel
	# Kitchen queue (always visible)
	_build_kitchen_queue()


func _build_kitchen_step1() -> void:
	# Step 1: ingredients — station name + pantry + bench

	# Station header + back button
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 6)
	_content.add_child(header_row)

	var back_btn := Button.new()
	back_btn.text = "< Back"
	back_btn.custom_minimum_size = Vector2(70, 32)
	back_btn.add_theme_font_size_override("font_size", 12)
	back_btn.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	back_btn.pressed.connect(func(): _go_to_step(0))
	header_row.add_child(back_btn)

	var station_lbl := Label.new()
	var desc: String = STATION_DESCS[_active_station] if _active_station >= 0 and _active_station < STATION_DESCS.size() else ""
	station_lbl.text = "%s — %s" % [STATION_NAMES[_active_station] if _active_station >= 0 else "?", desc]
	station_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	station_lbl.add_theme_font_size_override("font_size", 14)
	station_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	header_row.add_child(station_lbl)

	# Hint
	var hint := Label.new()
	hint.text = "Add up to %d ingredients" % GameState.get_bench_slots()
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	_content.add_child(hint)

	# Pantry
	_section_label("Pantry", true)

	var pantry := GridContainer.new()
	pantry.columns = 2
	pantry.add_theme_constant_override("h_separation", 6)
	pantry.add_theme_constant_override("v_separation", 6)
	_content.add_child(pantry)

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

		var btn := Button.new()
		btn.text = "  %s x%d" % [name_str, count - already]
		btn.disabled = (already >= count) or (_bench_ings.size() >= max_slots)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size.y = 44
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_color_override("font_color", Color.WHITE)
		# Styled card
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.08, 0.12, 0.2, 1.0)
		card_style.set_corner_radius_all(8)
		card_style.set_border_width_all(1)
		if on_bench:
			card_style.border_color = Color(0.3, 0.8, 0.4, 1.0)
		else:
			card_style.border_color = Color(0.2, 0.4, 0.8, 0.5)
		card_style.content_margin_left = 10
		card_style.content_margin_right = 8
		card_style.content_margin_top = 4
		card_style.content_margin_bottom = 4
		btn.add_theme_stylebox_override("normal", card_style)
		var hover_style: StyleBoxFlat = card_style.duplicate()
		hover_style.bg_color = Color(0.12, 0.18, 0.28, 1.0)
		btn.add_theme_stylebox_override("hover", hover_style)
		var pressed_style: StyleBoxFlat = card_style.duplicate()
		pressed_style.bg_color = Color(0.15, 0.22, 0.35, 1.0)
		btn.add_theme_stylebox_override("pressed", pressed_style)
		var disabled_style: StyleBoxFlat = card_style.duplicate()
		disabled_style.bg_color = Color(0.06, 0.08, 0.14, 0.7)
		disabled_style.border_color = Color(0.15, 0.2, 0.3, 0.3)
		btn.add_theme_stylebox_override("disabled", disabled_style)
		var cap_id: String = ing_id
		btn.pressed.connect(func():
			if _bench_ings.size() < max_slots and int(GameState.restaurant_ingredients.get(cap_id, 0)) > _bench_ings.count(cap_id):
				_bench_ings.append(cap_id)
				# Auto-advance to step 2 when first ingredient added
				if _bench_ings.size() >= 1 and _step < 2:
					_step = 2
				_needs_rebuild = true)
		pantry.add_child(btn)

	if not has_any:
		var lbl := Label.new()
		lbl.text = "Pantry empty — hunt creatures first"
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		_content.add_child(lbl)

	# Bench slots
	_section_label("Bench", true)
	var bench_row := HBoxContainer.new()
	bench_row.add_theme_constant_override("separation", 6)
	_content.add_child(bench_row)
	var slot_w: float = (390.0 - 32.0) / 3.0
	for i in range(max_slots):
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(slot_w, 40)
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
			slot_style.bg_color = Color(0.08, 0.14, 0.22, 1.0)
			slot_style.set_border_width_all(1)
			slot_style.border_color = Color(0.3, 0.8, 0.4, 0.8)
			var cap_i: int = i
			slot.pressed.connect(func():
				_bench_ings.remove_at(cap_i)
				# If bench becomes empty, go back to step 1
				if _bench_ings.is_empty() and _step == 2:
					_step = 1
				_needs_rebuild = true)
		else:
			slot.text = "+"
			slot.add_theme_font_size_override("font_size", 16)
			slot.add_theme_color_override("font_color", Color(0.4, 0.4, 0.6))
			slot_style.bg_color = Color(0.05, 0.07, 0.12, 0.6)
			slot_style.set_border_width_all(1)
			slot_style.border_color = Color(0.3, 0.3, 0.5, 0.5)
			slot.disabled = true
		slot.add_theme_stylebox_override("normal", slot_style)
		var slot_disabled: StyleBoxFlat = slot_style.duplicate()
		slot_disabled.bg_color = Color(0.05, 0.07, 0.12, 0.4)
		slot.add_theme_stylebox_override("disabled", slot_disabled)
		bench_row.add_child(slot)


func _build_kitchen_step2() -> void:
	# Step 2: method + style + cook

	# Back button
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 6)
	_content.add_child(header_row)

	var back_btn := Button.new()
	back_btn.text = "< Back"
	back_btn.custom_minimum_size = Vector2(70, 32)
	back_btn.add_theme_font_size_override("font_size", 12)
	back_btn.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	back_btn.pressed.connect(func(): _go_to_step(1))
	header_row.add_child(back_btn)

	var station_lbl := Label.new()
	station_lbl.text = STATION_NAMES[_active_station] if _active_station >= 0 else "?"
	station_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	station_lbl.add_theme_font_size_override("font_size", 14)
	station_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	header_row.add_child(station_lbl)

	# Bench chips — horizontal small chips
	var bench_label := Label.new()
	bench_label.text = "On the bench:"
	bench_label.add_theme_font_size_override("font_size", 11)
	bench_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	_content.add_child(bench_label)

	var chip_row := HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 4)
	_content.add_child(chip_row)
	for i in range(_bench_ings.size()):
		var ing: String = _bench_ings[i]
		var binfo: Dictionary = GameState.ingredient_tiers.get(ing, {})
		var display_name: String = str(binfo.get("name", ing))
		if display_name.length() > 14:
			display_name = display_name.substr(0, 14)
		var chip := Button.new()
		chip.text = display_name
		chip.custom_minimum_size.y = 28
		chip.add_theme_font_size_override("font_size", 11)
		chip.add_theme_color_override("font_color", Color.WHITE)
		var chip_style := StyleBoxFlat.new()
		chip_style.bg_color = Color(0.1, 0.2, 0.3, 0.9)
		chip_style.set_corner_radius_all(14)
		chip_style.set_border_width_all(1)
		chip_style.border_color = Color(0.3, 0.8, 0.4, 0.7)
		chip_style.content_margin_left = 10
		chip_style.content_margin_right = 10
		chip_style.content_margin_top = 2
		chip_style.content_margin_bottom = 2
		chip.add_theme_stylebox_override("normal", chip_style)
		var cap_i: int = i
		chip.pressed.connect(func():
			_bench_ings.remove_at(cap_i)
			if _bench_ings.is_empty():
				_step = 1
			_needs_rebuild = true)
		chip_row.add_child(chip)

	# Method
	_section_label("Method", true)
	var methods: Array = GameState.cooking_methods
	var mscroll := ScrollContainer.new()
	mscroll.custom_minimum_size.y = 40
	mscroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(mscroll)
	var mflow := HBoxContainer.new()
	mflow.add_theme_constant_override("separation", 6)
	mscroll.add_child(mflow)
	for mi in range(methods.size()):
		var m: Dictionary = methods[mi]
		var mb := Button.new()
		mb.text = str(m.get("name", "?"))
		mb.custom_minimum_size.y = 36
		mb.add_theme_font_size_override("font_size", 12)
		var pill_style := StyleBoxFlat.new()
		pill_style.set_corner_radius_all(18)
		pill_style.content_margin_left = 14
		pill_style.content_margin_right = 14
		pill_style.content_margin_top = 4
		pill_style.content_margin_bottom = 4
		pill_style.set_border_width_all(1)
		if mi == _bench_method:
			pill_style.bg_color = Color(0.15, 0.35, 0.7, 1.0)
			pill_style.border_color = Color(0.3, 0.6, 1.0, 1.0)
			mb.add_theme_color_override("font_color", Color.WHITE)
		else:
			pill_style.bg_color = Color(0.06, 0.1, 0.18, 1.0)
			pill_style.border_color = Color(0.2, 0.3, 0.5, 0.6)
			mb.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
		mb.add_theme_stylebox_override("normal", pill_style)
		var hover_p: StyleBoxFlat = pill_style.duplicate()
		hover_p.bg_color = pill_style.bg_color.lightened(0.1)
		mb.add_theme_stylebox_override("hover", hover_p)
		var pressed_p: StyleBoxFlat = pill_style.duplicate()
		pressed_p.bg_color = pill_style.bg_color.lightened(0.15)
		mb.add_theme_stylebox_override("pressed", pressed_p)
		var cap_mi: int = mi
		mb.pressed.connect(func():
			_bench_method = cap_mi
			_needs_rebuild = true)
		mflow.add_child(mb)

	# Style
	_section_label("Style", true)
	var styles: Array = GameState.serving_styles
	var sscroll := ScrollContainer.new()
	sscroll.custom_minimum_size.y = 40
	sscroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(sscroll)
	var sflow := HBoxContainer.new()
	sflow.add_theme_constant_override("separation", 6)
	sscroll.add_child(sflow)
	for si in range(styles.size()):
		var s: Dictionary = styles[si]
		var sb := Button.new()
		sb.text = str(s.get("name", "?"))
		sb.custom_minimum_size.y = 36
		sb.add_theme_font_size_override("font_size", 12)
		var spill := StyleBoxFlat.new()
		spill.set_corner_radius_all(18)
		spill.content_margin_left = 14
		spill.content_margin_right = 14
		spill.content_margin_top = 4
		spill.content_margin_bottom = 4
		spill.set_border_width_all(1)
		if si == _bench_style:
			spill.bg_color = Color(0.15, 0.35, 0.7, 1.0)
			spill.border_color = Color(0.3, 0.6, 1.0, 1.0)
			sb.add_theme_color_override("font_color", Color.WHITE)
		else:
			spill.bg_color = Color(0.06, 0.1, 0.18, 1.0)
			spill.border_color = Color(0.2, 0.3, 0.5, 0.6)
			sb.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
		sb.add_theme_stylebox_override("normal", spill)
		var shover: StyleBoxFlat = spill.duplicate()
		shover.bg_color = spill.bg_color.lightened(0.1)
		sb.add_theme_stylebox_override("hover", shover)
		var spressed: StyleBoxFlat = spill.duplicate()
		spressed.bg_color = spill.bg_color.lightened(0.15)
		sb.add_theme_stylebox_override("pressed", spressed)
		var cap_si: int = si
		sb.pressed.connect(func():
			_bench_style = cap_si
			_needs_rebuild = true)
		sflow.add_child(sb)

	# Cook button — full width, green, 56px, font 18
	var cook_btn := Button.new()
	var can_cook: bool = not _bench_ings.is_empty() and not _cooking
	cook_btn.text = "COOK" if can_cook else "Add ingredients first"
	cook_btn.disabled = not can_cook
	cook_btn.custom_minimum_size.y = 56
	cook_btn.add_theme_font_size_override("font_size", 18)
	cook_btn.add_theme_color_override("font_color", Color.WHITE)
	var cook_style := StyleBoxFlat.new()
	cook_style.set_corner_radius_all(12)
	if can_cook:
		cook_style.bg_color = Color(0.1, 0.45, 0.15, 1.0)
		cook_style.set_border_width_all(1)
		cook_style.border_color = Color(0.2, 0.7, 0.3, 0.6)
	else:
		cook_style.bg_color = Color(0.15, 0.15, 0.2, 1.0)
		cook_style.set_border_width_all(0)
	cook_style.content_margin_top = 8
	cook_style.content_margin_bottom = 8
	cook_btn.add_theme_stylebox_override("normal", cook_style)
	cook_btn.add_theme_stylebox_override("disabled", cook_style)
	var cook_hover: StyleBoxFlat = cook_style.duplicate()
	cook_hover.bg_color = cook_style.bg_color.lightened(0.08)
	cook_btn.add_theme_stylebox_override("hover", cook_hover)
	cook_btn.pressed.connect(_on_cook)
	_content.add_child(cook_btn)

	# Kitchen queue
	_build_kitchen_queue()


func _build_kitchen_queue() -> void:
	if not GameState.prepared_dishes.is_empty():
		_section_label("READY TO SERVE (%d dishes)" % GameState.prepared_dishes.size())
		for pd in GameState.prepared_dishes:
			var tier: int = int(pd.get("tier", 1))
			var qlbl := Label.new()
			qlbl.text = "  %s  [T%d]" % [str(pd.get("name", "?")), tier]
			qlbl.add_theme_font_size_override("font_size", 12)
			qlbl.add_theme_color_override("font_color", TIER_COLORS.get(tier, Color.WHITE))
			_content.add_child(qlbl)
		var go_btn := Button.new()
		go_btn.text = "-> Go serve guests"
		go_btn.custom_minimum_size.y = 40
		go_btn.add_theme_font_size_override("font_size", 14)
		go_btn.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		go_btn.pressed.connect(func(): call_deferred("_switch_room", Room.DINING))
		_content.add_child(go_btn)


func _go_to_step(step: int) -> void:
	if step == 0:
		_active_station = -1
		_bench_ings.clear()
		if is_instance_valid(_canvas):
			_canvas.active_station = -1
			_canvas.show_hint = true
			_canvas.queue_redraw()
	_step = step
	_needs_rebuild = true


# ── DINING PANEL ─────────────────────────────────────────────────

func _build_dining_panel() -> void:
	# Dish picker
	if GameState.prepared_dishes.is_empty():
		var lbl := Label.new()
		lbl.text = "No dishes ready — go to Kitchen first"
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.7, 0.5, 0.3))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(lbl)
		var back_btn := Button.new()
		back_btn.text = "<- Go to Kitchen"
		back_btn.custom_minimum_size.y = 42
		back_btn.add_theme_font_size_override("font_size", 14)
		back_btn.pressed.connect(func(): call_deferred("_switch_room", Room.KITCHEN))
		_content.add_child(back_btn)
	else:
		_section_label("SELECT DISH TO SERVE")
		var dish_flow := HBoxContainer.new()
		dish_flow.add_theme_constant_override("separation", 4)
		_content.add_child(dish_flow)
		var dish_counts: Dictionary = {}
		var dish_first_idx: Dictionary = {}
		for di in range(GameState.prepared_dishes.size()):
			var dname: String = str(GameState.prepared_dishes[di].get("name", "?"))
			dish_counts[dname] = int(dish_counts.get(dname, 0)) + 1
			if not dish_first_idx.has(dname):
				dish_first_idx[dname] = di
		for dname in dish_counts:
			var di: int = int(dish_first_idx[dname])
			var pd: Dictionary = GameState.prepared_dishes[di]
			var tier: int = int(pd.get("tier", 1))
			var count: int = int(dish_counts[dname])
			var db := Button.new()
			db.text = str(dname) + "\nT%d" % tier + ("  x%d" % count if count > 1 else "")
			db.custom_minimum_size = Vector2(88, 48)
			db.add_theme_font_size_override("font_size", 11)
			if di == _selected_dish:
				db.modulate = Color(1.0, 0.9, 0.3)
			else:
				db.modulate = Color(0.85, 0.85, 0.85)
			var cap_di: int = di
			db.pressed.connect(func():
				_selected_dish = cap_di
				_needs_rebuild = true)
			dish_flow.add_child(db)

	# Guest cards
	_section_label("GUESTS")
	if GameState.pending_guests.is_empty():
		var lbl := Label.new()
		lbl.text = "No guests today — leave and return"
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		_content.add_child(lbl)
		return

	for gi in range(GameState.pending_guests.size()):
		var guest: Dictionary = GameState.pending_guests[gi]
		_build_guest_card(gi, guest)


func _build_guest_card(idx: int, guest: Dictionary) -> void:
	var is_special: bool = guest.get("special", false)
	var resolved: bool = guest.get("_resolved", false)
	var faction: String = str(guest.get("faction", "independents"))

	var card := PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.12, 0.08, 0.06, 0.95) if is_special else Color(0.06, 0.08, 0.15, 0.95)
	cs.set_border_width_all(1)
	cs.border_color = Color(0.9, 0.7, 0.3) if is_special else FACTION_COLORS.get(faction, Color(0.3, 0.3, 0.5))
	cs.set_corner_radius_all(8)
	cs.content_margin_left = 8
	cs.content_margin_right = 8
	cs.content_margin_top = 6
	cs.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", cs)
	_content.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	card.add_child(vbox)

	# Name + faction
	var name_row := HBoxContainer.new()
	vbox.add_child(name_row)
	var name_lbl := Label.new()
	name_lbl.text = str(guest.get("name", "Guest"))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4) if is_special else Color.WHITE)
	name_row.add_child(name_lbl)

	var faction_lbl := Label.new()
	faction_lbl.text = "[%s]" % faction.capitalize()
	faction_lbl.add_theme_font_size_override("font_size", 11)
	faction_lbl.add_theme_color_override("font_color", FACTION_COLORS.get(faction, Color(0.6, 0.6, 0.7)))
	name_row.add_child(faction_lbl)

	# Role/trait for procedural
	if not is_special:
		var trait_lbl := Label.new()
		trait_lbl.text = "%s | %s" % [str(guest.get("role", "")), str(guest.get("trait", ""))]
		trait_lbl.add_theme_font_size_override("font_size", 11)
		trait_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
		vbox.add_child(trait_lbl)

	# Dietary hints
	var dp: Dictionary = GameState.faction_dietary.get(faction, {})
	var loves: Array = dp.get("loves", [])
	var hates: Array = dp.get("hates", [])
	var pref_map: Dictionary = {
		"char_grill": "char-grill", "slow_boil": "slow boil", "plasma_roast": "plasma roast",
		"cold_press": "raw/cold press", "molecular_decon": "mol. decon",
		"deep_freeze": "deep freeze", "fast_food": "fast food", "diner": "diner plate",
		"high_cuisine": "haute cuisine", "street_cart": "street cart", "the_experiment": "experiment",
	}
	if loves.is_empty() and hates.is_empty():
		var p := Label.new()
		p.text = "Eats anything"
		p.add_theme_font_size_override("font_size", 11)
		p.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
		vbox.add_child(p)
	else:
		var parts: Array = []
		if not loves.is_empty():
			var ns: Array = []
			for k in loves:
				ns.append(str(pref_map.get(k, k)))
			parts.append("LOVES: " + ", ".join(ns))
		if not hates.is_empty():
			var ns: Array = []
			for k in hates:
				ns.append(str(pref_map.get(k, k)))
			parts.append("HATES: " + ", ".join(ns))
		var p := Label.new()
		p.text = "  ".join(parts)
		p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		p.add_theme_font_size_override("font_size", 11)
		p.add_theme_color_override("font_color", Color(0.6, 0.75, 0.55))
		vbox.add_child(p)

	# Special intro
	if is_special:
		var intro := Label.new()
		intro.text = str(guest.get("intro", ""))
		intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		intro.add_theme_font_size_override("font_size", 12)
		intro.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
		vbox.add_child(intro)

	# Already resolved
	if resolved:
		var res_lbl := Label.new()
		res_lbl.text = str(guest.get("_result_message", "Served."))
		res_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		res_lbl.add_theme_font_size_override("font_size", 12)
		res_lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
		vbox.add_child(res_lbl)
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

	# Serve buttons for procedural guests
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
			var col: Color = Color(0.4, 1.0, 0.5) if loved else (Color(1.0, 0.4, 0.4) if hated else Color(0.85, 0.85, 0.85))
			var srv := Button.new()
			srv.text = "Serve: %s%s" % [dname, tag]
			srv.custom_minimum_size.y = 38
			srv.add_theme_font_size_override("font_size", 12)
			srv.modulate = col
			var cap_gi: int = idx
			var cap_name: String = dname
			srv.pressed.connect(func(): _serve_guest_named(cap_gi, cap_name))
			vbox.add_child(srv)


# ── ACTIONS ──────────────────────────────────────────────────────

func _on_station_tap(idx: int) -> void:
	_active_station = idx
	_step = 1
	if is_instance_valid(_canvas):
		_canvas.active_station = idx
		_canvas.show_hint = false
		_canvas.queue_redraw()
	_needs_table_rebuild = true
	_needs_rebuild = true


func _on_table_tap(idx: int) -> void:
	if idx >= GameState.pending_guests.size():
		return
	var guest: Dictionary = GameState.pending_guests[idx]
	if guest.get("_resolved", false):
		return
	_needs_rebuild = true


func _on_cook() -> void:
	if _bench_ings.is_empty() or _cooking:
		return

	var methods: Array = GameState.cooking_methods
	var styles: Array = GameState.serving_styles
	var method_id: String = str(methods[_bench_method].get("id", "char_grill"))
	var style_id: String = str(styles[_bench_style].get("id", "diner"))

	# Start cooking animation
	_cooking = true
	_cook_timer = 1.5
	_cook_station_idx = _active_station if _active_station >= 0 else 2  # default to prep bench (index 2)

	# Move NPC to station
	_move_npc_to_station(_cook_station_idx)

	# Set glow on canvas
	if is_instance_valid(_canvas):
		_canvas.glow_station = _cook_station_idx
		_canvas.glow_alpha = 0.5
		_canvas.queue_redraw()

	# Store cook params for when animation finishes
	set_meta("_cook_ings", _bench_ings.duplicate())
	set_meta("_cook_method", method_id)
	set_meta("_cook_style", style_id)

	_show_msg("Cooking...", 2.0)


func _finish_cook() -> void:
	var ings: Array = get_meta("_cook_ings", [])
	var method_id: String = str(get_meta("_cook_method", "char_grill"))
	var style_id: String = str(get_meta("_cook_style", "diner"))

	# Call GameState — resolve_experiment handles ingredient consumption + dish creation
	var result: Dictionary = GameState.resolve_experiment(ings, method_id, style_id)

	# Clear bench
	_bench_ings.clear()

	# Stop glow
	if is_instance_valid(_canvas):
		_canvas.glow_station = -1
		_canvas.glow_alpha = 0.0
		_canvas.queue_redraw()

	# Move NPC back
	_move_npc_home()

	# Show result
	var result_type: String = str(result.get("result", "fail"))
	if result_type == "fail":
		var fail_msg: String = str(result.get("message", "Failed."))
		_show_msg(fail_msg, 4.0)
	elif result_type == "catastrophe":
		var cat_msg: String = str(result.get("message", "Something went wrong."))
		_show_msg(cat_msg, 5.0)
	else:
		var recipe: Dictionary = result.get("recipe", {})
		var dish_name: String = str(recipe.get("name", "Mystery Dish"))
		if result_type == "known":
			_show_msg("%s — added to queue!" % dish_name, 3.0)
		else:
			_show_msg("New: %s — added to queue!" % dish_name, 3.0)

	SaveManager.save_game()

	# Auto-reset to step 0 after 2 seconds
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
	_needs_table_rebuild = true
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
	_needs_table_rebuild = true
	_needs_rebuild = true


func _add_choice_btn(parent: VBoxContainer, guest_idx: int, choice: String, label: String, col: Color) -> void:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size.y = 36
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", col)
	var cap_idx: int = guest_idx
	var cap_choice: String = choice
	btn.pressed.connect(func(): _resolve_special(cap_idx, cap_choice))
	parent.add_child(btn)


# ── NPC MOVEMENT ─────────────────────────────────────────────────

func _move_npc_to_station(station_idx: int) -> void:
	if not is_instance_valid(_canvas):
		return
	# Updated targets matching new station rect positions
	var targets: Array = [Vector2(60, 200), Vector2(310, 180), Vector2(185, 240), Vector2(50, 280)]
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


# ── HELPERS ──────────────────────────────────────────────────────

func _section_label(text: String, is_header: bool = false) -> void:
	var lbl := Label.new()
	if is_header:
		lbl.text = text.to_upper()
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.4, 0.6, 0.9, 0.8))
	else:
		lbl.text = text
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9))
	_content.add_child(lbl)


func _show_msg(text: String, duration: float = 3.0) -> void:
	if is_instance_valid(_msg_lbl):
		_msg_lbl.text = text
	_msg_timer = duration


func _on_back() -> void:
	SaveManager.save_game()
	call_deferred("_do_close")


func _do_close() -> void:
	queue_free()
