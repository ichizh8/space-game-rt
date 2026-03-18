extends CanvasLayer

# Visual restaurant GUI with drag-and-drop cooking and serving

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

const GUEST_PORTRAITS: Dictionary = {
	"velka_orin": "res://assets/2026-03-18-guest-velka-orin.png",
	"commissioner_drath": "res://assets/2026-03-18-guest-drath.png",
}

const TIER_COLORS: Dictionary = {
	1: Color(0.7, 0.7, 0.7),
	2: Color(0.3, 0.9, 0.4),
	3: Color(1.0, 0.7, 0.2),
}

const FACTION_COLORS: Dictionary = {
	"coalition": Color(0.4, 0.7, 1.0),
	"corsairs": Color(1.0, 0.4, 0.3),
	"miners": Color(0.8, 0.7, 0.3),
	"scientists": Color(0.6, 0.4, 1.0),
	"drifters": Color(0.5, 0.8, 0.5),
	"independents": Color(0.7, 0.7, 0.7),
}

var _root_panel: Panel
var _bench_slots: Array = []  # ingredient IDs in bench slots
var _bench_method: String = "char_grill"
var _bench_style: String = "diner"
var _method_idx: int = 0
var _style_idx: int = 0

# Panels that need refresh
var _pantry_vbox: VBoxContainer
var _bench_vbox: VBoxContainer
var _queue_hbox: HBoxContainer
var _dining_vbox: VBoxContainer
var _result_label: Label
var _credits_label: Label

var _pending_close: bool = false


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.generate_guest_session()
	var max_slots: int = GameState.get_bench_slots()
	_bench_slots.resize(max_slots)
	for i in range(max_slots):
		_bench_slots[i] = ""
	_build_ui()


func _process(_delta: float) -> void:
	if _pending_close:
		_pending_close = false
		queue_free()


func _build_ui() -> void:
	_root_panel = Panel.new()
	_root_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.03, 0.05, 0.1, 0.97)
	_root_panel.add_theme_stylebox_override("panel", bg_style)
	add_child(_root_panel)

	# ── Header bar ──
	var header := HBoxContainer.new()
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_top = 6
	header.offset_left = 8
	header.offset_right = -8
	header.offset_bottom = 40
	_root_panel.add_child(header)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(40, 34)
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.pressed.connect(_on_close)
	header.add_child(close_btn)

	var title_lbl := Label.new()
	title_lbl.text = "  " + GameState.restaurant_name + "  "
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title_lbl)

	_credits_label = Label.new()
	_credits_label.text = "%d cr" % GameState.credits
	_credits_label.add_theme_font_size_override("font_size", 14)
	_credits_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	header.add_child(_credits_label)

	# ── Main scroll area ──
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 42
	scroll.offset_left = 4
	scroll.offset_right = -4
	scroll.offset_bottom = -4
	_root_panel.add_child(scroll)

	var main_vbox := VBoxContainer.new()
	main_vbox.custom_minimum_size.x = 340
	main_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(main_vbox)

	# Result label (hidden initially)
	_result_label = Label.new()
	_result_label.text = ""
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_label.add_theme_font_size_override("font_size", 13)
	_result_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	main_vbox.add_child(_result_label)

	# ── Section: Pantry + Bench side by side ──
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 6)
	main_vbox.add_child(top_row)

	# Pantry panel
	var pantry_panel := _make_section_panel(Color(0.06, 0.08, 0.14))
	pantry_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pantry_panel.custom_minimum_size = Vector2(150, 0)
	top_row.add_child(pantry_panel)
	var pantry_inner := VBoxContainer.new()
	pantry_inner.add_theme_constant_override("separation", 4)
	pantry_panel.add_child(pantry_inner)
	var pantry_title := Label.new()
	pantry_title.text = "PANTRY"
	pantry_title.add_theme_font_size_override("font_size", 13)
	pantry_title.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	pantry_inner.add_child(pantry_title)
	_pantry_vbox = VBoxContainer.new()
	_pantry_vbox.add_theme_constant_override("separation", 2)
	pantry_inner.add_child(_pantry_vbox)

	# Bench panel
	var bench_panel := _make_section_panel(Color(0.08, 0.06, 0.14))
	bench_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bench_panel.custom_minimum_size = Vector2(170, 0)
	top_row.add_child(bench_panel)
	var bench_inner := VBoxContainer.new()
	bench_inner.add_theme_constant_override("separation", 4)
	bench_panel.add_child(bench_inner)
	var bench_title := Label.new()
	bench_title.text = "KITCHEN BENCH"
	bench_title.add_theme_font_size_override("font_size", 13)
	bench_title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	bench_inner.add_child(bench_title)
	_bench_vbox = VBoxContainer.new()
	_bench_vbox.add_theme_constant_override("separation", 3)
	bench_inner.add_child(_bench_vbox)

	# ── Section: Kitchen Queue ──
	var queue_section := _make_section_panel(Color(0.06, 0.07, 0.12))
	main_vbox.add_child(queue_section)
	var queue_inner := VBoxContainer.new()
	queue_inner.add_theme_constant_override("separation", 4)
	queue_section.add_child(queue_inner)
	var queue_title := Label.new()
	queue_title.text = "KITCHEN QUEUE"
	queue_title.add_theme_font_size_override("font_size", 13)
	queue_title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	queue_inner.add_child(queue_title)
	_queue_hbox = HBoxContainer.new()
	_queue_hbox.add_theme_constant_override("separation", 6)
	queue_inner.add_child(_queue_hbox)

	# ── Section: Dining Floor ──
	var dining_section := _make_section_panel(Color(0.05, 0.08, 0.06))
	main_vbox.add_child(dining_section)
	var dining_inner := VBoxContainer.new()
	dining_inner.add_theme_constant_override("separation", 4)
	dining_section.add_child(dining_inner)
	var dining_title := Label.new()
	dining_title.text = "DINING FLOOR"
	dining_title.add_theme_font_size_override("font_size", 13)
	dining_title.add_theme_color_override("font_color", Color(0.4, 0.9, 0.6))
	dining_inner.add_child(dining_title)
	_dining_vbox = VBoxContainer.new()
	_dining_vbox.add_theme_constant_override("separation", 6)
	dining_inner.add_child(_dining_vbox)

	_refresh_all()


func _make_section_panel(bg_color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_border_width_all(1)
	style.border_color = Color(0.2, 0.25, 0.4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _refresh_all() -> void:
	_refresh_pantry()
	_refresh_bench()
	_refresh_queue()
	_refresh_dining()
	_credits_label.text = "%d cr" % GameState.credits


# ── PANTRY ──────────────────────────────────────────────────────────

func _refresh_pantry() -> void:
	for c in _pantry_vbox.get_children():
		c.queue_free()
	if GameState.restaurant_ingredients.is_empty():
		var lbl := Label.new()
		lbl.text = "Empty — hunt creatures"
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		_pantry_vbox.add_child(lbl)
		return
	for ing_id in GameState.restaurant_ingredients:
		var count: int = GameState.restaurant_ingredients[ing_id]
		if count <= 0:
			continue
		var item := _IngredientDragSource.new()
		item.setup(ing_id, count, self)
		_pantry_vbox.add_child(item)


# ── BENCH ───────────────────────────────────────────────────────────

func _refresh_bench() -> void:
	for c in _bench_vbox.get_children():
		c.queue_free()

	# Slots
	var slots_label := Label.new()
	slots_label.text = "Drop ingredients:"
	slots_label.add_theme_font_size_override("font_size", 11)
	slots_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_bench_vbox.add_child(slots_label)

	var slots_flow := HBoxContainer.new()
	slots_flow.add_theme_constant_override("separation", 4)
	_bench_vbox.add_child(slots_flow)

	for i in range(_bench_slots.size()):
		var slot := _BenchSlotControl.new()
		slot.setup(i, _bench_slots[i], self)
		slots_flow.add_child(slot)

	# Method picker
	var method_row := HBoxContainer.new()
	method_row.add_theme_constant_override("separation", 4)
	_bench_vbox.add_child(method_row)
	var m_lbl := Label.new()
	m_lbl.text = "Method:"
	m_lbl.add_theme_font_size_override("font_size", 11)
	m_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	method_row.add_child(m_lbl)
	var m_btn := Button.new()
	var m_info: Dictionary = GameState.cooking_methods[_method_idx]
	m_btn.text = str(m_info["name"])
	m_btn.custom_minimum_size = Vector2(0, 30)
	m_btn.add_theme_font_size_override("font_size", 11)
	m_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_btn.pressed.connect(func():
		_method_idx = (_method_idx + 1) % GameState.cooking_methods.size()
		_bench_method = GameState.cooking_methods[_method_idx]["id"]
		_refresh_bench())
	method_row.add_child(m_btn)

	# Style picker
	var style_row := HBoxContainer.new()
	style_row.add_theme_constant_override("separation", 4)
	_bench_vbox.add_child(style_row)
	var s_lbl := Label.new()
	s_lbl.text = "Style:"
	s_lbl.add_theme_font_size_override("font_size", 11)
	s_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	style_row.add_child(s_lbl)
	var s_btn := Button.new()
	var s_info: Dictionary = GameState.serving_styles[_style_idx]
	s_btn.text = str(s_info["name"])
	s_btn.custom_minimum_size = Vector2(0, 30)
	s_btn.add_theme_font_size_override("font_size", 11)
	s_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s_btn.pressed.connect(func():
		_style_idx = (_style_idx + 1) % GameState.serving_styles.size()
		_bench_style = GameState.serving_styles[_style_idx]["id"]
		_refresh_bench())
	style_row.add_child(s_btn)

	# Cook button
	var has_ings: bool = false
	for s in _bench_slots:
		if s != "":
			has_ings = true
			break
	var cook_btn := Button.new()
	cook_btn.text = "COOK"
	cook_btn.custom_minimum_size = Vector2(0, 38)
	cook_btn.add_theme_font_size_override("font_size", 14)
	cook_btn.disabled = not has_ings
	cook_btn.pressed.connect(_on_cook_pressed)
	_bench_vbox.add_child(cook_btn)


# ── KITCHEN QUEUE ───────────────────────────────────────────────────

func _refresh_queue() -> void:
	for c in _queue_hbox.get_children():
		c.queue_free()
	if GameState.prepared_dishes.is_empty():
		var lbl := Label.new()
		lbl.text = "No dishes — cook something first"
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		_queue_hbox.add_child(lbl)
		return
	for i in range(GameState.prepared_dishes.size()):
		var dish: Dictionary = GameState.prepared_dishes[i]
		var card := _DishDragSource.new()
		card.setup(i, dish, self)
		_queue_hbox.add_child(card)


# ── DINING FLOOR ────────────────────────────────────────────────────

func _refresh_dining() -> void:
	for c in _dining_vbox.get_children():
		c.queue_free()
	if GameState.pending_guests.is_empty():
		var lbl := Label.new()
		lbl.text = "No guests. Depart and return."
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		_dining_vbox.add_child(lbl)
		return
	for gi in range(GameState.pending_guests.size()):
		var guest: Dictionary = GameState.pending_guests[gi]
		var card := _GuestCard.new()
		card.setup(gi, guest, self)
		_dining_vbox.add_child(card)


# ── ACTIONS ─────────────────────────────────────────────────────────

func on_ingredient_dropped_on_bench(slot_idx: int, ing_id: String) -> void:
	if slot_idx < 0 or slot_idx >= _bench_slots.size():
		return
	_bench_slots[slot_idx] = ing_id
	_refresh_bench()


func on_bench_slot_cleared(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= _bench_slots.size():
		return
	_bench_slots[slot_idx] = ""
	_refresh_bench()


func _on_cook_pressed() -> void:
	var ings: Array = []
	for s in _bench_slots:
		if s != "":
			ings.append(s)
	if ings.is_empty():
		return
	var result: Dictionary = GameState.resolve_experiment(ings, _bench_method, _bench_style)
	# Clear bench slots
	for i in range(_bench_slots.size()):
		_bench_slots[i] = ""
	# Show result
	var outcome: String = str(result.get("result", "fail"))
	if outcome == "discovered":
		_result_label.text = "NEW RECIPE: " + str(result.get("recipe", {}).get("name", ""))
		_result_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	elif outcome == "known":
		_result_label.text = "Cooked: " + str(result.get("recipe", {}).get("name", ""))
		_result_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	elif outcome == "catastrophe":
		_result_label.text = str(result.get("message", "Catastrophe!"))
		_result_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		_result_label.text = str(result.get("message", "Experiment failed."))
		_result_label.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
	call_deferred("_refresh_all")


func on_dish_served_to_guest(guest_idx: int, dish_idx: int) -> void:
	if guest_idx >= GameState.pending_guests.size():
		return
	var guest: Dictionary = GameState.pending_guests[guest_idx]
	if guest.get("_resolved", false):
		return
	var is_special: bool = guest.get("special", false)
	if is_special:
		# Special guests need their choice buttons, can't drag-serve
		return
	# Move the specific dish to front so resolve_guest picks it
	if dish_idx >= 0 and dish_idx < GameState.prepared_dishes.size() and dish_idx != 0:
		var dish = GameState.prepared_dishes[dish_idx]
		GameState.prepared_dishes.remove_at(dish_idx)
		GameState.prepared_dishes.insert(0, dish)
	var result: Dictionary = GameState.resolve_guest(guest, "auto")
	guest["_resolved"] = true
	guest["_result_message"] = result.get("message", "Served.")
	_result_label.text = str(result.get("message", "Served."))
	var earned: int = int(result.get("credits", 0))
	if earned > 0:
		_result_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	else:
		_result_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.3))
	# Check if tutorial quest should complete
	if GameState.is_quest_active("quest_first_day_open"):
		var q: Dictionary = WorldData.get_quest_by_id("quest_first_day_open")
		if not q.is_empty():
			_complete_quest_safe(q)
	# Check all done
	_check_session_complete()
	call_deferred("_refresh_all")


func on_special_guest_choice(guest_idx: int, choice: String) -> void:
	if guest_idx >= GameState.pending_guests.size():
		return
	var guest: Dictionary = GameState.pending_guests[guest_idx]
	if guest.get("_resolved", false):
		return
	var result: Dictionary = GameState.resolve_guest(guest, choice)
	guest["_resolved"] = true
	guest["_result_message"] = result.get("message", "Served.")
	_result_label.text = str(result.get("message", ""))
	_result_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	_check_session_complete()
	call_deferred("_refresh_all")


func _check_session_complete() -> void:
	var all_done: bool = true
	var outcomes: Array = []
	for g in GameState.pending_guests:
		if not g.get("_resolved", false):
			all_done = false
		else:
			outcomes.append(g.get("_result_message", ""))
	if all_done:
		GameState.log_guest_session(GameState.pending_guests, outcomes)


func _complete_quest_safe(q: Dictionary) -> void:
	var qid: String = str(q.get("id", ""))
	if qid.is_empty():
		return
	var req_ing: String = q.get("required_ingredient", "")
	var req_amt: int = int(q.get("required_amount", 0))
	if not req_ing.is_empty() and req_amt > 0:
		GameState.remove_ingredient(req_ing, req_amt)
	var reward: Dictionary = q.get("reward", {})
	for key in reward:
		if key == "credits":
			GameState.add_credits(int(reward[key]))
		else:
			GameState.add_resource(key, int(reward[key]))
	var rep_reward: int = int(q.get("rep_reward", 0))
	if rep_reward > 0:
		GameState.add_restaurant_rep(rep_reward)
	var unlock_dish: String = q.get("unlock_dish", "")
	if not unlock_dish.is_empty() and unlock_dish not in GameState.restaurant_unlocked_dishes:
		GameState.restaurant_unlocked_dishes.append(unlock_dish)
	GameState.complete_quest(qid)


func _on_close() -> void:
	SaveManager.save_game()
	_pending_close = true


# ═══════════════════════════════════════════════════════════════════
# INNER CLASSES — Drag & Drop Controls
# ═══════════════════════════════════════════════════════════════════

# ── Draggable Ingredient (Pantry) ──────────────────────────────────

class _IngredientDragSource extends HBoxContainer:
	var _ing_id: String = ""
	var _count: int = 0
	var _scene_ref = null  # restaurant_scene ref

	func setup(ing_id: String, count: int, scene_ref) -> void:
		_ing_id = ing_id
		_count = count
		_scene_ref = scene_ref
		custom_minimum_size = Vector2(0, 28)
		add_theme_constant_override("separation", 4)

		var icon_path: String = ING_ICONS.get(ing_id, "")
		if not icon_path.is_empty():
			var tex = load(icon_path)
			if tex is Texture2D:
				var trect := TextureRect.new()
				trect.texture = tex
				trect.custom_minimum_size = Vector2(22, 22)
				trect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				add_child(trect)

		var info: Dictionary = GameState.ingredient_tiers.get(ing_id, {})
		var tier: int = int(info.get("tier", 1))
		var lbl := Label.new()
		lbl.text = "%s x%d" % [str(info.get("name", ing_id)).substr(0, 12), count]
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", TIER_COLORS.get(tier, Color.WHITE))
		add_child(lbl)

	func _get_drag_data(_at_position: Vector2):
		var preview := Label.new()
		var info: Dictionary = GameState.ingredient_tiers.get(_ing_id, {})
		preview.text = str(info.get("name", _ing_id))
		preview.add_theme_font_size_override("font_size", 12)
		preview.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		set_drag_preview(preview)
		return {"type": "ingredient", "id": _ing_id}


# ── Bench Slot (Drop Target for Ingredients) ──────────────────────

class _BenchSlotControl extends PanelContainer:
	var _slot_idx: int = 0
	var _ing_id: String = ""
	var _scene_ref = null

	func setup(idx: int, ing_id: String, scene_ref) -> void:
		_slot_idx = idx
		_ing_id = ing_id
		_scene_ref = scene_ref
		custom_minimum_size = Vector2(42, 42)

		var style := StyleBoxFlat.new()
		if ing_id.is_empty():
			style.bg_color = Color(0.12, 0.12, 0.2, 0.8)
			style.set_border_width_all(1)
			style.border_color = Color(0.3, 0.3, 0.5)
		else:
			style.bg_color = Color(0.15, 0.18, 0.1, 0.9)
			style.set_border_width_all(1)
			style.border_color = Color(0.5, 0.7, 0.3)
		style.set_corner_radius_all(4)
		add_theme_stylebox_override("panel", style)

		if not ing_id.is_empty():
			var icon_path: String = ING_ICONS.get(ing_id, "")
			if not icon_path.is_empty():
				var tex = load(icon_path)
				if tex is Texture2D:
					var trect := TextureRect.new()
					trect.texture = tex
					trect.custom_minimum_size = Vector2(32, 32)
					trect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					add_child(trect)
			else:
				var lbl := Label.new()
				var info: Dictionary = GameState.ingredient_tiers.get(ing_id, {})
				lbl.text = str(info.get("name", "?")).substr(0, 4)
				lbl.add_theme_font_size_override("font_size", 10)
				add_child(lbl)

	func _can_drop_data(_at_position: Vector2, data) -> bool:
		if data is Dictionary and data.get("type", "") == "ingredient":
			return true
		return false

	func _drop_data(_at_position: Vector2, data) -> void:
		if data is Dictionary and data.get("type", "") == "ingredient":
			if _scene_ref != null:
				_scene_ref.call_deferred("on_ingredient_dropped_on_bench", _slot_idx, str(data["id"]))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and not _ing_id.is_empty():
			if _scene_ref != null:
				_scene_ref.call_deferred("on_bench_slot_cleared", _slot_idx)


# ── Draggable Dish Card (Kitchen Queue) ───────────────────────────

class _DishDragSource extends PanelContainer:
	var _dish_idx: int = 0
	var _dish: Dictionary = {}
	var _scene_ref = null

	func setup(idx: int, dish: Dictionary, scene_ref) -> void:
		_dish_idx = idx
		_dish = dish
		_scene_ref = scene_ref
		custom_minimum_size = Vector2(100, 50)

		var style := StyleBoxFlat.new()
		var tier: int = int(dish.get("tier", 1))
		style.bg_color = Color(0.1, 0.08, 0.04, 0.9)
		style.set_border_width_all(1)
		style.border_color = TIER_COLORS.get(tier, Color.WHITE) * 0.7
		style.set_corner_radius_all(4)
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		add_theme_stylebox_override("panel", style)

		var inner := VBoxContainer.new()
		add_child(inner)

		var name_lbl := Label.new()
		name_lbl.text = str(dish.get("name", "?"))
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", TIER_COLORS.get(tier, Color.WHITE))
		inner.add_child(name_lbl)

		var cr_lbl := Label.new()
		cr_lbl.text = "%d cr" % int(dish.get("credits_value", 0))
		cr_lbl.add_theme_font_size_override("font_size", 10)
		cr_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
		inner.add_child(cr_lbl)

	func _get_drag_data(_at_position: Vector2):
		var preview := Label.new()
		preview.text = str(_dish.get("name", "Dish"))
		preview.add_theme_font_size_override("font_size", 12)
		preview.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		set_drag_preview(preview)
		return {"type": "dish", "index": _dish_idx}


# ── Guest Card with Plate Drop Zone ───────────────────────────────

class _GuestCard extends PanelContainer:
	var _guest_idx: int = 0
	var _guest: Dictionary = {}
	var _scene_ref = null

	func setup(idx: int, guest: Dictionary, scene_ref) -> void:
		_guest_idx = idx
		_guest = guest
		_scene_ref = scene_ref

		var is_special: bool = guest.get("special", false)
		var is_resolved: bool = guest.get("_resolved", false)

		var style := StyleBoxFlat.new()
		if is_resolved:
			style.bg_color = Color(0.04, 0.06, 0.04, 0.8)
			style.border_color = Color(0.3, 0.5, 0.3)
		elif is_special:
			style.bg_color = Color(0.12, 0.06, 0.06, 0.9)
			style.border_color = Color(0.9, 0.7, 0.3)
		else:
			style.bg_color = Color(0.08, 0.1, 0.18, 0.9)
			style.border_color = Color(0.3, 0.3, 0.5)
		style.set_border_width_all(1)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		add_theme_stylebox_override("panel", style)

		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 3)
		add_child(inner)

		# Portrait + name row
		var top_row := HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 8)
		inner.add_child(top_row)

		if is_special:
			var guest_id: String = str(guest.get("id", ""))
			var portrait_path: String = GUEST_PORTRAITS.get(guest_id, "")
			if not portrait_path.is_empty():
				var tex = load(portrait_path)
				if tex is Texture2D:
					var trect := TextureRect.new()
					trect.texture = tex
					trect.custom_minimum_size = Vector2(48, 48)
					trect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					top_row.add_child(trect)

		var name_col := VBoxContainer.new()
		name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(name_col)

		var name_lbl := Label.new()
		name_lbl.text = str(guest.get("name", "Unknown"))
		name_lbl.add_theme_font_size_override("font_size", 13)
		var name_color: Color = Color(1.0, 0.85, 0.4) if is_special else Color.WHITE
		name_lbl.add_theme_color_override("font_color", name_color)
		name_col.add_child(name_lbl)

		# Faction badge
		var faction: String = str(guest.get("faction", "drifters"))
		var faction_lbl := Label.new()
		var faction_display: String = faction.capitalize()
		if not is_special:
			faction_display += " | " + str(guest.get("role", ""))
			var trait_val: String = str(guest.get("trait", ""))
			if not trait_val.is_empty():
				faction_display += " | " + trait_val
		else:
			faction_display += " | " + str(guest.get("role", ""))
		faction_lbl.text = faction_display
		faction_lbl.add_theme_font_size_override("font_size", 10)
		faction_lbl.add_theme_color_override("font_color", FACTION_COLORS.get(faction, Color.WHITE))
		name_col.add_child(faction_lbl)

		# Dietary preferences
		var dp: Dictionary = GameState.faction_dietary.get(faction, {})
		var loves: Array = dp.get("loves", [])
		var hates: Array = dp.get("hates", [])
		if not loves.is_empty() or not hates.is_empty():
			var pref_parts: Array = []
			if not loves.is_empty():
				var love_names: Array = []
				for k in loves:
					love_names.append(str(k).replace("_", " "))
				pref_parts.append("Wants: " + ", ".join(love_names))
			if not hates.is_empty():
				var hate_names: Array = []
				for k in hates:
					hate_names.append(str(k).replace("_", " "))
				pref_parts.append("Dislikes: " + ", ".join(hate_names))
			var pref_lbl := Label.new()
			pref_lbl.text = " · ".join(pref_parts)
			pref_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			pref_lbl.add_theme_font_size_override("font_size", 10)
			pref_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
			inner.add_child(pref_lbl)
		else:
			var eats_lbl := Label.new()
			eats_lbl.text = "Eats anything"
			eats_lbl.add_theme_font_size_override("font_size", 10)
			eats_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
			inner.add_child(eats_lbl)

		if is_resolved:
			var result_lbl := Label.new()
			result_lbl.text = str(guest.get("_result_message", "Served."))
			result_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			result_lbl.add_theme_font_size_override("font_size", 11)
			result_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
			inner.add_child(result_lbl)
		elif is_special:
			# Intro text
			var intro_lbl := Label.new()
			intro_lbl.text = str(guest.get("intro", ""))
			intro_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			intro_lbl.add_theme_font_size_override("font_size", 11)
			intro_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
			inner.add_child(intro_lbl)
			# Choice buttons
			_build_special_choices(inner, guest, idx, scene_ref)
		else:
			# Drop zone for dishes
			var drop_zone := _PlateDropZone.new()
			drop_zone.setup(idx, scene_ref)
			inner.add_child(drop_zone)

	func _build_special_choices(inner: VBoxContainer, guest: Dictionary, idx: int, scene_ref) -> void:
		var choice_id: String = str(guest.get("choice_id", ""))
		if choice_id == "velka_first_visit":
			var has_t3_dish: bool = false
			for pd in GameState.prepared_dishes:
				if pd.get("tier", 0) >= 3:
					has_t3_dish = true
					break
			var has_lev: bool = has_t3_dish or GameState.has_ingredient("leviathan_cut", 1)
			if has_lev:
				_add_choice_btn(inner, idx, scene_ref, "serve_leviathan", "Serve Leviathan Cut")
				_add_choice_btn(inner, idx, scene_ref, "overcharge", "Overcharge (risky)")
			else:
				_add_choice_btn(inner, idx, scene_ref, "honest", "Tell her you don't have it")
				_add_choice_btn(inner, idx, scene_ref, "bluff", "Bluff with something else")
				_add_choice_btn(inner, idx, scene_ref, "defer", "Offer a drink instead")
		elif choice_id == "drath_first_visit":
			_add_choice_btn(inner, idx, scene_ref, "cooperate", "Cooperate with inspection")
			_add_choice_btn(inner, idx, scene_ref, "bribe_food", "Bribe with food (-100 cr)")
			_add_choice_btn(inner, idx, scene_ref, "probe", "Ask what he's really looking for")

	func _add_choice_btn(inner: VBoxContainer, idx: int, scene_ref, choice: String, label: String) -> void:
		var btn := Button.new()
		btn.text = label
		btn.custom_minimum_size.y = 32
		btn.add_theme_font_size_override("font_size", 11)
		var cap_idx: int = idx
		var cap_choice: String = choice
		btn.pressed.connect(func():
			if scene_ref != null:
				scene_ref.call_deferred("on_special_guest_choice", cap_idx, cap_choice))
		inner.add_child(btn)


# ── Plate Drop Zone (on guest cards) ──────────────────────────────

class _PlateDropZone extends PanelContainer:
	var _guest_idx: int = 0
	var _scene_ref = null

	func setup(idx: int, scene_ref) -> void:
		_guest_idx = idx
		_scene_ref = scene_ref
		custom_minimum_size = Vector2(0, 36)

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.12, 0.08, 0.6)
		style.set_border_width_all(1)
		style.border_color = Color(0.3, 0.5, 0.3, 0.5)
		style.set_corner_radius_all(4)
		style.content_margin_left = 8
		style.content_margin_top = 4
		add_theme_stylebox_override("panel", style)

		var lbl := Label.new()
		lbl.text = "[ Drop dish here ]"
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.4, 0.6, 0.4))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(lbl)

	func _can_drop_data(_at_position: Vector2, data) -> bool:
		if data is Dictionary and data.get("type", "") == "dish":
			return true
		return false

	func _drop_data(_at_position: Vector2, data) -> void:
		if data is Dictionary and data.get("type", "") == "dish":
			if _scene_ref != null:
				_scene_ref.call_deferred("on_dish_served_to_guest", _guest_idx, int(data["index"]))
