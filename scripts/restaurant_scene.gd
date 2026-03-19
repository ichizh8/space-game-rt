extends CanvasLayer

# Restaurant GUI — simple 3-step flow for mobile
# Step 1: SELECT ingredients from pantry (tap to add to bench)
# Step 2: Pick method + style, tap COOK
# Step 3: Pick dish from queue, tap guest to serve

const ING_ICONS: Dictionary = {
	"grub_meat": "res://assets/2026-03-18-ingredient-grub-meat.png",
	"grub_fat": "res://assets/2026-03-18-ingredient-grub-meat.png",
	"ray_fillet": "res://assets/2026-03-18-ingredient-ray-fillet.png",
	"ray_membrane": "res://assets/2026-03-18-ingredient-ray-fillet.png",
	"snarler_haunch": "res://assets/2026-03-18-ingredient-snarler-haunch.png",
	"snarler_gland": "res://assets/2026-03-18-ingredient-snarler-haunch.png",
	"drifter_organ": "res://assets/2026-03-18-ingredient-drifter-organ.png",
	"drifter_gel": "res://assets/2026-03-18-ingredient-drifter-gel.png",
	"feeder_flesh": "res://assets/2026-03-18-ingredient-feeder-flesh.png",
	"crystal_extract": "res://assets/2026-03-18-ingredient-crystal-extract.png",
	"feeder_bioluminescence": "res://assets/2026-03-18-ingredient-feeder-flesh.png",
	"leviathan_cut": "res://assets/2026-03-18-ingredient-leviathan-cut.png",
	"leviathan_marrow": "res://assets/2026-03-18-ingredient-leviathan-cut.png",
	"void_crystal_blood": "res://assets/2026-03-18-ingredient-crystal-extract.png",
	"scrap_protein": "res://assets/2026-03-18-ingredient-grub-meat.png",
}

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

enum Step { BENCH, GUESTS }

var _step: int = Step.BENCH
var _bench_ings: Array = []   # list of ingredient IDs added to bench
var _bench_method: int = 0
var _bench_style: int = 0
var _selected_dish: int = -1  # index in prepared_dishes for serving

var _root: Panel
var _content: VBoxContainer
var _credits_lbl: Label
var _msg_lbl: Label
var _msg_timer: float = 0.0

var _tab_bench_btn: Button
var _tab_guests_btn: Button


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.generate_guest_session()
	_build_ui()


func _process(delta: float) -> void:
	if _msg_timer > 0.0:
		_msg_timer -= delta
		if _msg_timer <= 0.0:
			_msg_lbl.text = ""


func _show_msg(text: String, duration: float = 3.0) -> void:
	_msg_lbl.text = text
	_msg_timer = duration


func _build_ui() -> void:
	_root = Panel.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.04, 0.06, 0.12, 0.98)
	_root.add_theme_stylebox_override("panel", bg)
	add_child(_root)

	# Header
	var header := HBoxContainer.new()
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_top = 4; header.offset_left = 6
	header.offset_right = -6; header.offset_bottom = 46
	_root.add_child(header)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(42, 38)
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.pressed.connect(_on_close)
	header.add_child(close_btn)

	var title := Label.new()
	title.text = GameState.restaurant_name
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	header.add_child(title)

	_credits_lbl = Label.new()
	_credits_lbl.text = "%d cr" % GameState.credits
	_credits_lbl.add_theme_font_size_override("font_size", 13)
	_credits_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	header.add_child(_credits_lbl)

	# Tab row
	var tabs := HBoxContainer.new()
	tabs.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tabs.offset_top = 50; tabs.offset_left = 6
	tabs.offset_right = -6; tabs.offset_bottom = 90
	tabs.add_theme_constant_override("separation", 4)
	_root.add_child(tabs)

	_tab_bench_btn = Button.new()
	_tab_bench_btn.text = "🍳 Kitchen"
	_tab_bench_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_bench_btn.custom_minimum_size.y = 38
	_tab_bench_btn.add_theme_font_size_override("font_size", 14)
	_tab_bench_btn.pressed.connect(func(): _switch_step(Step.BENCH))
	tabs.add_child(_tab_bench_btn)

	_tab_guests_btn = Button.new()
	_tab_guests_btn.text = "🪑 Guests"
	_tab_guests_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_guests_btn.custom_minimum_size.y = 38
	_tab_guests_btn.add_theme_font_size_override("font_size", 14)
	_tab_guests_btn.pressed.connect(func(): _switch_step(Step.GUESTS))
	tabs.add_child(_tab_guests_btn)

	# Message label
	_msg_lbl = Label.new()
	_msg_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_msg_lbl.offset_top = 92; _msg_lbl.offset_left = 8
	_msg_lbl.offset_right = -8; _msg_lbl.offset_bottom = 116
	_msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_lbl.add_theme_font_size_override("font_size", 12)
	_msg_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_msg_lbl)

	# Scrollable content area
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 118; scroll.offset_left = 6
	scroll.offset_right = -6; scroll.offset_bottom = -6
	_root.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)

	_switch_step(Step.BENCH)


func _switch_step(step: int) -> void:
	_step = step
	_tab_bench_btn.modulate = Color(1.0, 1.0, 1.0) if step == Step.BENCH else Color(0.6, 0.6, 0.6)
	_tab_guests_btn.modulate = Color(1.0, 1.0, 1.0) if step == Step.GUESTS else Color(0.6, 0.6, 0.6)
	_rebuild_content()


func _rebuild_content() -> void:
	for c in _content.get_children():
		c.queue_free()
	_credits_lbl.text = "%d cr" % GameState.credits
	match _step:
		Step.BENCH: _build_bench()
		Step.GUESTS: _build_guests()


# ─── KITCHEN BENCH ────────────────────────────────────────────────

func _build_bench() -> void:
	# ── Pantry ──
	_section_label(_content, "INGREDIENTS  (tap to add to bench)")

	var pantry_flow := GridContainer.new()
	pantry_flow.columns = 2
	pantry_flow.add_theme_constant_override("h_separation", 4)
	pantry_flow.add_theme_constant_override("v_separation", 4)
	_content.add_child(pantry_flow)

	var max_slots: int = GameState.get_bench_slots()
	var has_any: bool = false
	for ing_id in GameState.restaurant_ingredients:
		var count: int = GameState.restaurant_ingredients[ing_id]
		if count <= 0:
			continue
		has_any = true
		var already: int = _bench_ings.count(ing_id)
		var btn := Button.new()
		var info: Dictionary = GameState.ingredient_tiers.get(ing_id, {})
		var tier: int = int(info.get("tier", 1))
		var name_str: String = str(info.get("name", ing_id.replace("_", " ").capitalize()))
		btn.text = "%s x%d" % [name_str, count - already]
		btn.disabled = (already >= count) or (_bench_ings.size() >= max_slots)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size.y = 40
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_color_override("font_color", TIER_COLORS.get(tier, Color.WHITE))
		var cap_id: String = ing_id
		btn.pressed.connect(func():
			if _bench_ings.size() < max_slots and GameState.restaurant_ingredients.get(cap_id, 0) > _bench_ings.count(cap_id):
				_bench_ings.append(cap_id)
				_rebuild_content())
		pantry_flow.add_child(btn)

	if not has_any:
		var lbl := Label.new()
		lbl.text = "Pantry empty — hunt creatures first"
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		_content.add_child(lbl)

	# ── Bench slots ──
	_section_label(_content, "ON THE BENCH  (tap to remove)")

	if _bench_ings.is_empty():
		var lbl := Label.new()
		lbl.text = "Nothing yet — tap an ingredient above"
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		_content.add_child(lbl)
	else:
		var bench_flow := HBoxContainer.new()
		bench_flow.add_theme_constant_override("separation", 6)
		_content.add_child(bench_flow)
		for i in range(_bench_ings.size()):
			var ing: String = _bench_ings[i]
			var info: Dictionary = GameState.ingredient_tiers.get(ing, {})
			var slot_btn := Button.new()
			slot_btn.text = str(info.get("name", ing)).substr(0, 10) + "\n✕"
			slot_btn.custom_minimum_size = Vector2(70, 50)
			slot_btn.add_theme_font_size_override("font_size", 11)
			var cap_i: int = i
			slot_btn.pressed.connect(func():
				_bench_ings.remove_at(cap_i)
				_rebuild_content())
			bench_flow.add_child(slot_btn)

	# ── Method & Style ──
	_section_label(_content, "COOKING METHOD")
	var methods: Array = GameState.cooking_methods
	var method_flow := HBoxContainer.new()
	method_flow.add_theme_constant_override("separation", 4)
	_content.add_child(method_flow)
	for mi in range(methods.size()):
		var m: Dictionary = methods[mi]
		var mb := Button.new()
		mb.text = str(m.get("name", "?"))
		mb.custom_minimum_size.y = 36
		mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mb.add_theme_font_size_override("font_size", 11)
		if mi == _bench_method:
			mb.modulate = Color(1.0, 0.9, 0.3)
		var cap_mi: int = mi
		mb.pressed.connect(func():
			_bench_method = cap_mi
			_rebuild_content())
		method_flow.add_child(mb)

	_section_label(_content, "SERVING STYLE")
	var styles: Array = GameState.serving_styles
	var style_flow := HBoxContainer.new()
	style_flow.add_theme_constant_override("separation", 4)
	_content.add_child(style_flow)
	for si in range(styles.size()):
		var s: Dictionary = styles[si]
		var sb := Button.new()
		sb.text = str(s.get("name", "?"))
		sb.custom_minimum_size.y = 36
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sb.add_theme_font_size_override("font_size", 11)
		if si == _bench_style:
			sb.modulate = Color(1.0, 0.9, 0.3)
		var cap_si: int = si
		sb.pressed.connect(func():
			_bench_style = cap_si
			_rebuild_content())
		style_flow.add_child(sb)

	# ── Cook button ──
	var sep := HSeparator.new()
	_content.add_child(sep)

	var cook_btn := Button.new()
	cook_btn.text = "COOK" if not _bench_ings.is_empty() else "Add ingredients to cook"
	cook_btn.disabled = _bench_ings.is_empty()
	cook_btn.custom_minimum_size.y = 52
	cook_btn.add_theme_font_size_override("font_size", 18)
	cook_btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
	cook_btn.pressed.connect(_on_cook)
	_content.add_child(cook_btn)

	# ── Kitchen queue ──
	if not GameState.prepared_dishes.is_empty():
		_section_label(_content, "KITCHEN QUEUE — ready to serve")
		for pd in GameState.prepared_dishes:
			var tier: int = int(pd.get("tier", 1))
			var qlbl := Label.new()
			qlbl.text = "• %s  [T%d]" % [str(pd.get("name", "?")), tier]
			qlbl.add_theme_font_size_override("font_size", 13)
			qlbl.add_theme_color_override("font_color", TIER_COLORS.get(tier, Color.WHITE))
			_content.add_child(qlbl)
		var go_btn := Button.new()
		go_btn.text = "→ Go serve guests"
		go_btn.custom_minimum_size.y = 42
		go_btn.add_theme_font_size_override("font_size", 14)
		go_btn.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		go_btn.pressed.connect(func(): _switch_step(Step.GUESTS))
		_content.add_child(go_btn)


func _on_cook() -> void:
	if _bench_ings.is_empty():
		return
	var methods: Array = GameState.cooking_methods
	var styles: Array = GameState.serving_styles
	var method_id: String = str(methods[_bench_method].get("id", "char_grill"))
	var style_id: String = str(styles[_bench_style].get("id", "diner"))

	# Consume ingredients
	for ing in _bench_ings:
		GameState.remove_ingredient(ing, 1)

	# Attempt cook
	var result: Dictionary = GameState.attempt_cook_combo(_bench_ings, method_id, style_id)
	var dish_name: String = str(result.get("name", "Mystery Dish"))
	var tier: int = int(result.get("tier", 1))
	var dish: Dictionary = {
		"name": dish_name, "method": method_id, "style": style_id,
		"tier": tier, "credits_value": 30 + tier * 40,
		"menu_story": str(result.get("menu_story", "")),
		"ingredients": _bench_ings.duplicate(),
	}
	GameState.add_prepared_dish(dish)
	_bench_ings.clear()
	_show_msg("Cooked: %s [T%d] — go serve a guest!" % [dish_name, tier], 4.0)
	_switch_step(Step.GUESTS)


# ─── GUESTS ──────────────────────────────────────────────────────

func _build_guests() -> void:
	# Dish picker at top
	if GameState.prepared_dishes.is_empty():
		var lbl := Label.new()
		lbl.text = "No dishes ready — go to Kitchen first"
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.7, 0.5, 0.3))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(lbl)
		var back_btn := Button.new()
		back_btn.text = "← Go to Kitchen"
		back_btn.custom_minimum_size.y = 44
		back_btn.add_theme_font_size_override("font_size", 14)
		back_btn.pressed.connect(func(): _switch_step(Step.BENCH))
		_content.add_child(back_btn)
	else:
		_section_label(_content, "SELECT DISH TO SERVE")
		var dish_flow := HBoxContainer.new()
		dish_flow.add_theme_constant_override("separation", 4)
		_content.add_child(dish_flow)
		# Show unique dish types with count
		var dish_counts: Dictionary = {}
		var dish_first_idx: Dictionary = {}
		for di in range(GameState.prepared_dishes.size()):
			var dname: String = str(GameState.prepared_dishes[di].get("name", "?"))
			dish_counts[dname] = dish_counts.get(dname, 0) + 1
			if not dish_first_idx.has(dname):
				dish_first_idx[dname] = di
		for dname in dish_counts:
			var di: int = int(dish_first_idx[dname])
			var pd: Dictionary = GameState.prepared_dishes[di]
			var tier: int = int(pd.get("tier", 1))
			var count: int = int(dish_counts[dname])
			var db := Button.new()
			db.text = str(dname) + "\nT%d" % tier + ("  x%d" % count if count > 1 else "")
			db.custom_minimum_size = Vector2(90, 50)
			db.add_theme_font_size_override("font_size", 11)
			if di == _selected_dish:
				db.modulate = Color(1.0, 0.9, 0.3)
			else:
				db.modulate = Color(0.85, 0.85, 0.85)
			var cap_di: int = di
			db.pressed.connect(func():
				_selected_dish = cap_di
				_rebuild_content())
			dish_flow.add_child(db)

	# Guest list
	_section_label(_content, "GUESTS")

	if GameState.pending_guests.is_empty():
		var lbl := Label.new()
		lbl.text = "No guests today — leave and return to the station"
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
	cs.bg_color = Color(0.12, 0.08, 0.06, 0.95) if is_special else Color(0.08, 0.1, 0.18, 0.95)
	cs.set_border_width_all(1)
	cs.border_color = Color(0.9, 0.7, 0.3) if is_special else FACTION_COLORS.get(faction, Color(0.3, 0.3, 0.5))
	cs.content_margin_left = 8; cs.content_margin_right = 8
	cs.content_margin_top = 6; cs.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", cs)
	_content.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Name row
	var name_row := HBoxContainer.new()
	vbox.add_child(name_row)
	var name_lbl := Label.new()
	name_lbl.text = str(guest.get("name", "Guest"))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4) if is_special else Color.WHITE)
	name_row.add_child(name_lbl)

	var faction_lbl := Label.new()
	var faction_badge: String = faction.capitalize()
	faction_lbl.text = "[%s]" % faction_badge
	faction_lbl.add_theme_font_size_override("font_size", 11)
	faction_lbl.add_theme_color_override("font_color", FACTION_COLORS.get(faction, Color(0.6, 0.6, 0.7)))
	name_row.add_child(faction_lbl)

	if not is_special:
		var trait_lbl := Label.new()
		trait_lbl.text = "%s | %s" % [str(guest.get("role", "")), str(guest.get("trait", ""))]
		trait_lbl.add_theme_font_size_override("font_size", 11)
		trait_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
		vbox.add_child(trait_lbl)

	# Dietary hint
	var dp: Dictionary = GameState.faction_dietary.get(faction, {})
	var loves: Array = dp.get("loves", [])
	var hates: Array = dp.get("hates", [])
	var pref_name_map: Dictionary = {
		"char_grill": "char-grill", "slow_boil": "slow boil", "plasma_roast": "plasma roast",
		"cold_press": "raw/cold press", "molecular_decon": "mol. deconstruct",
		"deep_freeze": "deep freeze", "fast_food": "fast food", "diner": "diner plate",
		"high_cuisine": "haute cuisine", "street_cart": "street cart", "the_experiment": "experiment",
	}
	if loves.is_empty() and hates.is_empty():
		var pref_lbl := Label.new()
		pref_lbl.text = "Eats anything"
		pref_lbl.add_theme_font_size_override("font_size", 11)
		pref_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
		vbox.add_child(pref_lbl)
	else:
		var parts: Array = []
		if not loves.is_empty():
			var ns: Array = []
			for k in loves:
				ns.append(str(pref_name_map.get(k, k)))
			parts.append("LOVES: " + ", ".join(ns))
		if not hates.is_empty():
			var ns: Array = []
			for k in hates:
				ns.append(str(pref_name_map.get(k, k)))
			parts.append("HATES: " + ", ".join(ns))
		var pref_lbl := Label.new()
		pref_lbl.text = "  ".join(parts)
		pref_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pref_lbl.add_theme_font_size_override("font_size", 11)
		pref_lbl.add_theme_color_override("font_color", Color(0.6, 0.75, 0.55))
		vbox.add_child(pref_lbl)

	# Special guest intro / choice
	if is_special:
		var intro_lbl := Label.new()
		intro_lbl.text = str(guest.get("intro", ""))
		intro_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		intro_lbl.add_theme_font_size_override("font_size", 12)
		intro_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
		vbox.add_child(intro_lbl)

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

	# Serve buttons (one per unique dish)
	if GameState.prepared_dishes.is_empty():
		var nd_lbl := Label.new()
		nd_lbl.text = "No dishes — cook something first"
		nd_lbl.add_theme_font_size_override("font_size", 12)
		nd_lbl.add_theme_color_override("font_color", Color(0.5, 0.4, 0.4))
		vbox.add_child(nd_lbl)
	else:
		var shown: Dictionary = {}
		for di in range(GameState.prepared_dishes.size()):
			var pd: Dictionary = GameState.prepared_dishes[di]
			var dname: String = str(pd.get("name", "?"))
			if shown.has(dname):
				continue
			shown[dname] = true
			var loved: bool = pd.get("method", "") in loves or pd.get("style", "") in loves
			var hated: bool = pd.get("method", "") in hates or pd.get("style", "") in hates
			var tag: String = " [+]" if loved else (" [-]" if hated else "")
			var col: Color = Color(0.4, 1.0, 0.5) if loved else (Color(1.0, 0.4, 0.4) if hated else Color(0.85, 0.85, 0.85))
			var srv_btn := Button.new()
			srv_btn.text = "Serve: %s%s" % [dname, tag]
			srv_btn.custom_minimum_size.y = 40
			srv_btn.add_theme_font_size_override("font_size", 13)
			# Use modulate for color — font_color override unreliable on all themes
			srv_btn.modulate = col
			var cap_gi: int = idx
			var cap_name: String = dname
			srv_btn.pressed.connect(func(): _serve_guest_named(cap_gi, cap_name))
			vbox.add_child(srv_btn)


func _add_choice_btn(vbox: VBoxContainer, guest_idx: int, choice: String, label: String, col: Color) -> void:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size.y = 38
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", col)
	var cap_idx: int = guest_idx
	var cap_choice: String = choice
	btn.pressed.connect(func(): _resolve_special(cap_idx, cap_choice))
	vbox.add_child(btn)


func _serve_guest_named(guest_idx: int, dish_name: String) -> void:
	# Move named dish to front
	for i in range(GameState.prepared_dishes.size()):
		if str(GameState.prepared_dishes[i].get("name", "")) == dish_name:
			if i != 0:
				var dish = GameState.prepared_dishes[i]
				GameState.prepared_dishes.remove_at(i)
				GameState.prepared_dishes.insert(0, dish)
			break
	var result: Dictionary = GameState.serve_guest(guest_idx, "auto")
	var msg: String = str(result.get("message", "Served."))
	_show_msg(msg, 4.0)
	SaveManager.save_game()
	_rebuild_content()


func _resolve_special(guest_idx: int, choice: String) -> void:
	var result: Dictionary = GameState.serve_guest(guest_idx, choice)
	var msg: String = str(result.get("message", "Done."))
	_show_msg(msg, 5.0)
	SaveManager.save_game()
	_rebuild_content()


func _section_label(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9))
	parent.add_child(lbl)


func _on_close() -> void:
	SaveManager.save_game()
	queue_free()
