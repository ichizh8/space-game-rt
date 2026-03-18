extends CanvasLayer

var station_id: String = ""
var station_name: String = ""
var _panel: Panel
var _tab_container: TabContainer
var _quests_tab: ScrollContainer
var _restaurant_tab: ScrollContainer


func setup(s_id: String, s_name: String) -> void:
	station_id = s_id
	station_name = s_name


func is_restaurant_station() -> bool:
	return station_id == "drifting_spoon"


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	if is_restaurant_station() and not GameState.restaurant_owned:
		GameState.restaurant_owned = true
		GameState.complete_quest("quest_inherit_restaurant")
	_build_ui()
	get_tree().paused = true
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if is_instance_valid(hud) and hud.has_method("reset_fire"):
		hud.reset_fire()


func _build_ui() -> void:
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.07, 0.14, 0.96)
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	var title := Label.new()
	title.text = station_name
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 18
	title.offset_left = 20
	title.offset_right = -60
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close_btn.offset_left = -50
	close_btn.offset_top = 12
	close_btn.offset_right = -8
	close_btn.offset_bottom = 50
	close_btn.pressed.connect(_on_close)
	_panel.add_child(close_btn)

	_tab_container = TabContainer.new()
	_tab_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tab_container.offset_top = 58
	_tab_container.offset_left = 8
	_tab_container.offset_right = -8
	_tab_container.offset_bottom = -8
	_panel.add_child(_tab_container)

	_build_services_tab()
	_build_quests_tab()
	if is_restaurant_station():
		_build_restaurant_tab()
		_build_bench_tab()
		_build_guests_tab()


func _build_services_tab() -> void:
	var services_tab := ScrollContainer.new()
	services_tab.name = "Services"
	_tab_container.add_child(services_tab)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size.x = 330
	vbox.add_theme_constant_override("separation", 10)
	services_tab.add_child(vbox)
	_fill_services(vbox)


func _fill_services(vbox: VBoxContainer) -> void:
	var r_title := Label.new()
	r_title.text = "REPAIR & REFUEL"
	r_title.add_theme_font_size_override("font_size", 14)
	r_title.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	vbox.add_child(r_title)

	var hull_lbl := Label.new()
	hull_lbl.text = "Hull: %.0f / %.0f" % [GameState.hull, GameState.max_hull]
	hull_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(hull_lbl)

	var repair_btn := Button.new()
	repair_btn.text = "Repair +50 HP  (15 scrap)"
	repair_btn.custom_minimum_size.y = 44
	repair_btn.disabled = not GameState.has_resources({"scrap": 15})
	repair_btn.pressed.connect(func():
		if GameState.remove_resource("scrap", 15):
			GameState.heal(50.0)
			_on_close())
	vbox.add_child(repair_btn)

	var full_repair_btn := Button.new()
	full_repair_btn.text = "Full Repair  (40 scrap)"
	full_repair_btn.custom_minimum_size.y = 44
	full_repair_btn.disabled = not GameState.has_resources({"scrap": 40})
	full_repair_btn.pressed.connect(func():
		if GameState.remove_resource("scrap", 40):
			GameState.heal(GameState.max_hull)
			_on_close())
	vbox.add_child(full_repair_btn)

	var fuel_lbl := Label.new()
	fuel_lbl.text = "Fuel: %.0f / %.0f" % [GameState.fuel, GameState.max_fuel]
	fuel_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(fuel_lbl)

	var refuel_btn := Button.new()
	refuel_btn.text = "Refuel +50  (25 credits)"
	refuel_btn.custom_minimum_size.y = 44
	refuel_btn.disabled = GameState.credits < 25
	refuel_btn.pressed.connect(func():
		if GameState.credits >= 25:
			GameState.credits -= 25
			GameState.credits_changed.emit(GameState.credits)
			GameState.add_fuel(50.0)
			_on_close())
	vbox.add_child(refuel_btn)

	vbox.add_child(HSeparator.new())

	var s_title := Label.new()
	s_title.text = "SELL RESOURCES"
	s_title.add_theme_font_size_override("font_size", 14)
	s_title.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(s_title)

	var prices := {"ore": 4, "crystal": 10, "scrap": 2}
	for res in prices:
		var amt: int = GameState.resources.get(res, 0)
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "%s: %d  (%d cr ea)" % [res.capitalize(), amt, prices[res]]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 13)
		row.add_child(lbl)
		var sell_btn := Button.new()
		sell_btn.text = "Sell All"
		sell_btn.custom_minimum_size = Vector2(84, 38)
		sell_btn.disabled = amt == 0
		var effective := int(round(float(prices[res]) * (1.0 + GameState.captain_sell_bonus)))
		sell_btn.pressed.connect(func():
			var a: int = GameState.resources.get(res, 0)
			if a > 0:
				GameState.resources[res] = 0
				GameState.add_credits(a * effective)
				GameState.resources_changed.emit()
				_on_close())
		row.add_child(sell_btn)
		vbox.add_child(row)


func _build_quests_tab() -> void:
	_quests_tab = ScrollContainer.new()
	_quests_tab.name = "Quests"
	_tab_container.add_child(_quests_tab)
	_refresh_quests_tab()


func _refresh_quests_tab() -> void:
	for c in _quests_tab.get_children():
		c.queue_free()

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size.x = 330
	vbox.add_theme_constant_override("separation", 8)
	_quests_tab.add_child(vbox)

	var station_data := GameState.get_planet_data(station_id)

	# Active world quests (Dad's Place + any other source_type:world quests)
	var has_world_quest := false
	for q in GameState.active_quests:
		if q.get("source_type", "") == "world":
			has_world_quest = true
			var qpanel := PanelContainer.new()
			var qstyle := StyleBoxFlat.new()
			qstyle.bg_color = Color(0.08, 0.12, 0.08, 0.95)
			qstyle.border_color = Color(0.3, 0.9, 0.4)
			qstyle.set_border_width_all(2)
			qstyle.content_margin_left = 10
			qstyle.content_margin_right = 10
			qstyle.content_margin_top = 8
			qstyle.content_margin_bottom = 8
			qpanel.add_theme_stylebox_override("panel", qstyle)
			vbox.add_child(qpanel)
			var qinner := VBoxContainer.new()
			qpanel.add_child(qinner)
			var qtag := Label.new()
			qtag.text = "MAIN QUEST"
			qtag.add_theme_font_size_override("font_size", 11)
			qtag.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
			qinner.add_child(qtag)
			var qtitle := Label.new()
			qtitle.text = q.get("title", "")
			qtitle.add_theme_font_size_override("font_size", 16)
			qtitle.add_theme_color_override("font_color", Color.WHITE)
			qinner.add_child(qtitle)
			var qdesc := Label.new()
			qdesc.text = q.get("description", "")
			qdesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			qdesc.add_theme_font_size_override("font_size", 13)
			qdesc.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
			qinner.add_child(qdesc)
	if has_world_quest:
		vbox.add_child(HSeparator.new())

	# Board quests
	var board_title := Label.new()
	board_title.text = "STATION QUEST BOARD"
	board_title.add_theme_font_size_override("font_size", 14)
	board_title.add_theme_color_override("font_color", Color.CYAN)
	vbox.add_child(board_title)

	if not station_data.has("available_quests"):
		var board_quests := WorldData.get_board_quests_for("station")
		var count := mini(board_quests.size(), randi_range(2, 3))
		var ids: Array = []
		for i in range(count):
			ids.append(board_quests[i]["id"])
		station_data["available_quests"] = ids

	var quest_ids: Array = station_data.get("available_quests", [])
	if quest_ids.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "No quests available."
		none_lbl.add_theme_font_size_override("font_size", 13)
		none_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		vbox.add_child(none_lbl)
	else:
		for qid in quest_ids:
			var q := WorldData.get_quest_by_id(qid)
			if q.is_empty():
				continue
			_add_station_quest_row(vbox, q, qid)


func _add_station_quest_row(vbox: VBoxContainer, q: Dictionary, qid: String) -> void:
	var container := PanelContainer.new()
	var cstyle := StyleBoxFlat.new()
	cstyle.bg_color = Color(0.08, 0.1, 0.18, 0.9)
	cstyle.set_border_width_all(1)
	cstyle.content_margin_left = 8
	cstyle.content_margin_right = 8
	cstyle.content_margin_top = 6
	cstyle.content_margin_bottom = 6

	if GameState.is_quest_completed(qid):
		cstyle.border_color = Color(0.3, 0.3, 0.3)
		container.add_theme_stylebox_override("panel", cstyle)
		vbox.add_child(container)
		var lbl := Label.new()
		lbl.text = q.get("title", qid) + " — Completed"
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		container.add_child(lbl)
		return

	if GameState.is_quest_active(qid):
		cstyle.border_color = Color(0.7, 0.7, 0.2)
		container.add_theme_stylebox_override("panel", cstyle)
		vbox.add_child(container)
		var inner := VBoxContainer.new()
		container.add_child(inner)
		var title_lbl := Label.new()
		title_lbl.text = q.get("title", qid)
		title_lbl.add_theme_font_size_override("font_size", 14)
		title_lbl.add_theme_color_override("font_color", Color.YELLOW)
		inner.add_child(title_lbl)
		var progress_q := GameState.get_quest_progress(qid)
		var prog_lbl := Label.new()
		if q.get("type") == "destroy":
			prog_lbl.text = "%d / %d killed" % [progress_q.get("progress", 0), q.get("required", 0)]
		elif q.get("type") == "gather":
			var res_name: String = q.get("resource", "")
			prog_lbl.text = "%d / %d %s" % [GameState.resources.get(res_name, 0), q.get("required", 0), res_name]
		prog_lbl.add_theme_font_size_override("font_size", 12)
		prog_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		inner.add_child(prog_lbl)
		var abandon_btn := Button.new()
		abandon_btn.text = "Abandon"
		abandon_btn.custom_minimum_size.y = 30
		abandon_btn.add_theme_font_size_override("font_size", 12)
		abandon_btn.pressed.connect(func():
			GameState.abandon_quest(qid)
			_refresh_quests_tab())
		inner.add_child(abandon_btn)
		return

	# Available quest
	cstyle.border_color = Color(0.3, 0.3, 0.5)
	container.add_theme_stylebox_override("panel", cstyle)
	vbox.add_child(container)
	var inner := VBoxContainer.new()
	container.add_child(inner)
	var title_lbl := Label.new()
	title_lbl.text = q.get("title", qid)
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	inner.add_child(title_lbl)
	var desc_lbl := Label.new()
	desc_lbl.text = q.get("description", "")
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	inner.add_child(desc_lbl)
	var reward: Dictionary = q.get("reward", {})
	if not reward.is_empty():
		var parts: Array[String] = []
		for key in reward:
			parts.append(key.capitalize() + ": " + str(reward[key]))
		var rew_lbl := Label.new()
		rew_lbl.text = "Reward: " + ", ".join(parts)
		rew_lbl.add_theme_font_size_override("font_size", 11)
		rew_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
		inner.add_child(rew_lbl)
	var accept_btn := Button.new()
	accept_btn.text = "Accept"
	accept_btn.custom_minimum_size.y = 34
	accept_btn.add_theme_font_size_override("font_size", 13)
	accept_btn.pressed.connect(func():
		GameState.accept_quest(q, station_id)
		_refresh_quests_tab())
	inner.add_child(accept_btn)


func _build_restaurant_tab() -> void:
	_restaurant_tab = ScrollContainer.new()
	_restaurant_tab.name = "Restaurant"
	_tab_container.add_child(_restaurant_tab)
	_refresh_restaurant_tab()


func _refresh_restaurant_tab() -> void:
	for c in _restaurant_tab.get_children():
		c.queue_free()

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size.x = 330
	vbox.add_theme_constant_override("separation", 8)
	_restaurant_tab.add_child(vbox)

	# First visit scene — show inheritance moment
	if not GameState.get_story_flag("spoon_intro_seen"):
		GameState.set_story_flag("spoon_intro_seen", true)
		var intro_lbl := Label.new()
		intro_lbl.text = "The Drifting Spoon"
		intro_lbl.add_theme_font_size_override("font_size", 22)
		intro_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		intro_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(intro_lbl)
		var scene_lbl := Label.new()
		scene_lbl.text = "\nThe airlock hisses open. The smell hits you first.\n\nSomething fried. Something burnt. Something that might have been meat, once.\n\nYour father's handwriting is on a sticky note above the fryer:\n\"Don't turn off the compressor. It knows.\"\n\nThe license on the wall has three violations circled in red. One of them just says 'atmosphere.'\n\nThis is yours now."
		scene_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		scene_lbl.add_theme_font_size_override("font_size", 14)
		scene_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
		vbox.add_child(scene_lbl)
		var sep := HSeparator.new()
		vbox.add_child(sep)

	# Header
	var name_lbl := Label.new()
	name_lbl.text = GameState.restaurant_name
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	vbox.add_child(name_lbl)

	var tier_lbl := Label.new()
	tier_lbl.text = GameState.get_restaurant_tier() + "  —  Reputation: %d / 100" % GameState.restaurant_rep
	tier_lbl.add_theme_font_size_override("font_size", 13)
	tier_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(tier_lbl)

	# Cooksta section
	if GameState.cooksta_rating > 0 or not GameState.cooksta_posts.is_empty():
		vbox.add_child(HSeparator.new())
		var cooksta_title := Label.new()
		cooksta_title.text = "COOKSTA"
		cooksta_title.add_theme_font_size_override("font_size", 14)
		cooksta_title.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
		vbox.add_child(cooksta_title)
		var rating_lbl := Label.new()
		rating_lbl.text = "Rating: %dpts" % GameState.cooksta_rating
		rating_lbl.add_theme_font_size_override("font_size", 13)
		rating_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.4))
		vbox.add_child(rating_lbl)
		var post_count: int = mini(GameState.cooksta_posts.size(), 3)
		for pi in range(GameState.cooksta_posts.size() - post_count, GameState.cooksta_posts.size()):
			var post_lbl := Label.new()
			post_lbl.text = str(GameState.cooksta_posts[pi])
			post_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			post_lbl.add_theme_font_size_override("font_size", 11)
			post_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
			vbox.add_child(post_lbl)

	vbox.add_child(HSeparator.new())

	# Ingredient storage
	var ing_title := Label.new()
	ing_title.text = "INGREDIENT STORAGE"
	ing_title.add_theme_font_size_override("font_size", 14)
	ing_title.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	vbox.add_child(ing_title)

	if GameState.restaurant_ingredients.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No ingredients. Hunt creatures to collect."
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		vbox.add_child(empty_lbl)
	else:
		for ing_id in GameState.restaurant_ingredients:
			var count: int = GameState.restaurant_ingredients[ing_id]
			var lbl := Label.new()
			lbl.text = "%s: %d" % [ing_id.replace("_", " ").capitalize(), count]
			lbl.add_theme_font_size_override("font_size", 13)
			vbox.add_child(lbl)

	vbox.add_child(HSeparator.new())

	# Restaurant quests section
	_build_restaurant_quests(vbox)

	vbox.add_child(HSeparator.new())

	# Menu Book — discovered recipes
	if not GameState.discovered_recipes.is_empty():
		var book_title := Label.new()
		book_title.text = "MENU BOOK"
		book_title.add_theme_font_size_override("font_size", 14)
		book_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		vbox.add_child(book_title)
		for rkey in GameState.discovered_recipes:
			var recipe: Dictionary = GameState.discovered_recipes[rkey]
			_build_discovered_recipe_row(vbox, recipe)
		vbox.add_child(HSeparator.new())

	# Menu section
	var menu_title := Label.new()
	menu_title.text = "MENU"
	menu_title.add_theme_font_size_override("font_size", 14)
	menu_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	vbox.add_child(menu_title)

	var rep: int = GameState.restaurant_rep
	var dishes: Array[Dictionary] = []
	# Base dishes (rep-gated)
	dishes.append({"id": "dish_mystery_patty", "name": "Mystery Meat Patty", "desc": "Dad's recipe. Nobody knows what's in it. Nobody asks.", "cost_id": "scrap_protein", "cost_amt": 2, "credits": 25, "rep": 0, "req_rep": 0})
	dishes.append({"id": "dish_scrap_bowl", "name": "Scrap Protein Bowl", "desc": "Hearty and questionable.", "cost_id": "scrap_protein", "cost_amt": 3, "credits": 40, "rep": 1, "req_rep": 20})
	dishes.append({"id": "dish_void_steak", "name": "Void Steak", "desc": "Seared void creature meat.", "cost_id": "void_flesh", "cost_amt": 1, "credits": 120, "rep": 3, "req_rep": 20})
	dishes.append({"id": "dish_carrier_roast", "name": "Carrier Roast", "desc": "Slow-roasted carrier organ.", "cost_id": "carrier_organ", "cost_amt": 1, "credits": 150, "rep": 4, "req_rep": 40})
	dishes.append({"id": "dish_sentinel_tartare", "name": "Sentinel Tartare", "desc": "Raw sentinel core, thinly sliced.", "cost_id": "sentinel_core", "cost_amt": 1, "credits": 400, "rep": 10, "req_rep": 60})
	# Quest-unlocked dishes
	dishes.append({"id": "dish_grub_fritters", "name": "Grub Fritters", "desc": "Old Marta's suggestion. Embarrassing but people keep ordering it.", "cost_id": "grub_meat", "cost_amt": 2, "credits": 45, "rep": 1, "req_rep": 0})
	dishes.append({"id": "dish_drifter_soup", "name": "Drifter Soup", "desc": "Gelatinous. Weird. Somehow works. Hunter's recipe.", "cost_id": "drifter_organ", "cost_amt": 1, "credits": 130, "rep": 4, "req_rep": 0})
	dishes.append({"id": "dish_feeder_tartare", "name": "Feeder Tartare", "desc": "Raw, luminescent, pretentious. Critics approve.", "cost_id": "feeder_flesh", "cost_amt": 1, "credits": 280, "rep": 8, "req_rep": 0})
	# Additional rep-gated wildlife dishes
	dishes.append({"id": "dish_ray_sashimi", "name": "Raw Ray Sashimi", "desc": "Technically just raw fish. The presentation saves it.", "cost_id": "ray_fillet", "cost_amt": 1, "credits": 60, "rep": 2, "req_rep": 10})
	dishes.append({"id": "dish_snarler_stew", "name": "Snarler Stew", "desc": "Slow cooked. Regulars start coming back for it.", "cost_id": "snarler_haunch", "cost_amt": 1, "credits": 100, "rep": 3, "req_rep": 20})
	dishes.append({"id": "dish_leviathan_cut", "name": "Leviathan Medallion", "desc": "One medallion per Leviathan. Guests book weeks in advance.", "cost_id": "leviathan_cut", "cost_amt": 1, "credits": 500, "rep": 15, "req_rep": 65})

	for dish in dishes:
		var dish_id: String = str(dish["id"])
		var dish_req_rep: int = int(dish["req_rep"])
		# Show if: unlocked via quest OR meets rep threshold
		var is_unlocked: bool = dish_id in GameState.restaurant_unlocked_dishes
		var meets_rep: bool = rep >= dish_req_rep
		if not is_unlocked and not meets_rep:
			continue
		_build_dish_row(vbox, dish)


func _build_dish_row(vbox: VBoxContainer, dish: Dictionary) -> void:
	var container := PanelContainer.new()
	var cstyle := StyleBoxFlat.new()
	cstyle.bg_color = Color(0.08, 0.1, 0.18, 0.9)
	cstyle.set_border_width_all(1)
	cstyle.border_color = Color(0.3, 0.3, 0.5)
	cstyle.content_margin_left = 8
	cstyle.content_margin_right = 8
	cstyle.content_margin_top = 6
	cstyle.content_margin_bottom = 6
	container.add_theme_stylebox_override("panel", cstyle)
	vbox.add_child(container)

	var inner := VBoxContainer.new()
	container.add_child(inner)

	var d_name := Label.new()
	d_name.text = str(dish["name"])
	d_name.add_theme_font_size_override("font_size", 14)
	d_name.add_theme_color_override("font_color", Color.WHITE)
	inner.add_child(d_name)

	var d_desc := Label.new()
	d_desc.text = str(dish["desc"])
	d_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d_desc.add_theme_font_size_override("font_size", 11)
	d_desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	inner.add_child(d_desc)

	var cost_id: String = str(dish["cost_id"])
	var cost_amt: int = int(dish["cost_amt"])
	var earn_cr: int = int(dish["credits"])
	var earn_rep: int = int(dish["rep"])

	var info_lbl := Label.new()
	info_lbl.text = "Cost: %s x%d  |  Earn: %d cr" % [cost_id.replace("_", " ").capitalize(), cost_amt, earn_cr]
	if earn_rep > 0:
		info_lbl.text += ", +%d rep" % earn_rep
	info_lbl.add_theme_font_size_override("font_size", 12)
	info_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	inner.add_child(info_lbl)

	var cook_btn := Button.new()
	cook_btn.text = "Cook & Serve"
	cook_btn.custom_minimum_size.y = 38
	cook_btn.add_theme_font_size_override("font_size", 13)
	cook_btn.disabled = not GameState.has_ingredient(cost_id, cost_amt)
	cook_btn.pressed.connect(_on_cook.bind(cost_id, cost_amt, earn_cr, earn_rep))
	inner.add_child(cook_btn)


func _build_restaurant_quests(vbox: VBoxContainer) -> void:
	var quest_title := Label.new()
	quest_title.text = "QUESTS"
	quest_title.add_theme_font_size_override("font_size", 14)
	quest_title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	vbox.add_child(quest_title)

	var restaurant_quests: Array = _get_restaurant_quests()
	var shown_any := false

	for q in restaurant_quests:
		var qid: String = q["id"]

		# Completed quests
		if GameState.is_quest_completed(qid):
			_build_rquest_completed(vbox, q)
			shown_any = true
			continue

		# Active quests — check auto-complete
		if GameState.is_quest_active(qid):
			var req_ing: String = q.get("required_ingredient", "")
			var req_amt: int = int(q.get("required_amount", 0))
			if GameState.has_ingredient(req_ing, req_amt):
				# Auto-complete
				_complete_restaurant_quest(q)
				_build_rquest_completed(vbox, q)
			else:
				_build_rquest_active(vbox, q)
			shown_any = true
			continue

		# Available quests — check unlock condition
		if _check_quest_unlock(q):
			_build_rquest_available(vbox, q)
			shown_any = true

	if not shown_any:
		var none_lbl := Label.new()
		none_lbl.text = "No quests available yet."
		none_lbl.add_theme_font_size_override("font_size", 12)
		none_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		vbox.add_child(none_lbl)


func _get_restaurant_quests() -> Array:
	var result: Array = []
	for q in WorldData.quests_data:
		if q.get("source_type", "") == "restaurant":
			result.append(q)
	return result


func _check_quest_unlock(q: Dictionary) -> bool:
	var cond: String = q.get("unlock_condition", "")
	if cond.is_empty():
		return true
	# Parse "restaurant_rep >= N"
	if cond.begins_with("restaurant_rep >= "):
		var threshold: int = int(cond.split(">= ")[1])
		return GameState.restaurant_rep >= threshold
	return true


func _complete_restaurant_quest(q: Dictionary) -> void:
	var qid: String = q["id"]
	var req_ing: String = q.get("required_ingredient", "")
	var req_amt: int = int(q.get("required_amount", 0))
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
	# Remove from active + mark completed
	GameState.complete_quest(qid)


func _build_rquest_completed(vbox: VBoxContainer, q: Dictionary) -> void:
	var container := PanelContainer.new()
	var cstyle := StyleBoxFlat.new()
	cstyle.bg_color = Color(0.06, 0.08, 0.12, 0.9)
	cstyle.set_border_width_all(1)
	cstyle.border_color = Color(0.3, 0.5, 0.3)
	cstyle.content_margin_left = 8
	cstyle.content_margin_right = 8
	cstyle.content_margin_top = 4
	cstyle.content_margin_bottom = 4
	container.add_theme_stylebox_override("panel", cstyle)
	vbox.add_child(container)
	var lbl := Label.new()
	lbl.text = str(q.get("title", "")) + " — Complete"
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.4, 0.7, 0.4))
	container.add_child(lbl)


func _build_rquest_active(vbox: VBoxContainer, q: Dictionary) -> void:
	var container := PanelContainer.new()
	var cstyle := StyleBoxFlat.new()
	cstyle.bg_color = Color(0.1, 0.09, 0.04, 0.9)
	cstyle.set_border_width_all(1)
	cstyle.border_color = Color(0.8, 0.7, 0.2)
	cstyle.content_margin_left = 8
	cstyle.content_margin_right = 8
	cstyle.content_margin_top = 6
	cstyle.content_margin_bottom = 6
	container.add_theme_stylebox_override("panel", cstyle)
	vbox.add_child(container)

	var inner := VBoxContainer.new()
	container.add_child(inner)

	var title_lbl := Label.new()
	title_lbl.text = str(q.get("title", ""))
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color.YELLOW)
	inner.add_child(title_lbl)

	var npc_lbl := Label.new()
	npc_lbl.text = "From: " + str(q.get("npc", ""))
	npc_lbl.add_theme_font_size_override("font_size", 11)
	npc_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	inner.add_child(npc_lbl)

	var req_ing: String = q.get("required_ingredient", "")
	var req_amt: int = int(q.get("required_amount", 0))
	var have: int = GameState.restaurant_ingredients.get(req_ing, 0)
	var prog_lbl := Label.new()
	prog_lbl.text = "%s: %d / %d" % [req_ing.replace("_", " ").capitalize(), have, req_amt]
	prog_lbl.add_theme_font_size_override("font_size", 13)
	prog_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6) if have < req_amt else Color(0.4, 1.0, 0.4))
	inner.add_child(prog_lbl)


func _build_rquest_available(vbox: VBoxContainer, q: Dictionary) -> void:
	var qid: String = q["id"]
	var container := PanelContainer.new()
	var cstyle := StyleBoxFlat.new()
	cstyle.bg_color = Color(0.08, 0.1, 0.18, 0.9)
	cstyle.set_border_width_all(1)
	cstyle.border_color = Color(0.3, 0.3, 0.5)
	cstyle.content_margin_left = 8
	cstyle.content_margin_right = 8
	cstyle.content_margin_top = 6
	cstyle.content_margin_bottom = 6
	container.add_theme_stylebox_override("panel", cstyle)
	vbox.add_child(container)

	var inner := VBoxContainer.new()
	container.add_child(inner)

	var title_lbl := Label.new()
	title_lbl.text = str(q.get("title", ""))
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	inner.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = str(q.get("description", ""))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	inner.add_child(desc_lbl)

	var reward: Dictionary = q.get("reward", {})
	if not reward.is_empty():
		var parts: Array[String] = []
		for key in reward:
			parts.append(key.capitalize() + ": " + str(reward[key]))
		var rep_r: int = int(q.get("rep_reward", 0))
		if rep_r > 0:
			parts.append("+%d rep" % rep_r)
		var rew_lbl := Label.new()
		rew_lbl.text = "Reward: " + ", ".join(parts)
		rew_lbl.add_theme_font_size_override("font_size", 11)
		rew_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
		inner.add_child(rew_lbl)

	var accept_btn := Button.new()
	accept_btn.text = "Accept"
	accept_btn.custom_minimum_size.y = 36
	accept_btn.add_theme_font_size_override("font_size", 13)
	accept_btn.pressed.connect(func():
		GameState.accept_quest(q, "restaurant")
		_refresh_restaurant_tab())
	inner.add_child(accept_btn)


func _build_discovered_recipe_row(vbox: VBoxContainer, recipe: Dictionary) -> void:
	var container := PanelContainer.new()
	var cstyle := StyleBoxFlat.new()
	cstyle.bg_color = Color(0.1, 0.08, 0.04, 0.9)
	cstyle.set_border_width_all(1)
	cstyle.border_color = Color(0.6, 0.5, 0.2)
	cstyle.content_margin_left = 8
	cstyle.content_margin_right = 8
	cstyle.content_margin_top = 6
	cstyle.content_margin_bottom = 6
	container.add_theme_stylebox_override("panel", cstyle)
	vbox.add_child(container)
	var inner := VBoxContainer.new()
	container.add_child(inner)
	var d_name := Label.new()
	d_name.text = str(recipe.get("name", "Unknown Dish"))
	d_name.add_theme_font_size_override("font_size", 14)
	d_name.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	inner.add_child(d_name)
	var story_lbl := Label.new()
	story_lbl.text = str(recipe.get("menu_story", ""))
	story_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_lbl.add_theme_font_size_override("font_size", 11)
	story_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	inner.add_child(story_lbl)
	var ings: Array = recipe.get("ingredients", [])
	var ing_names: Array = []
	for ing_id in ings:
		var info: Dictionary = GameState.ingredient_tiers.get(ing_id, {})
		ing_names.append(info.get("name", str(ing_id).replace("_", " ").capitalize()))
	var ing_lbl := Label.new()
	ing_lbl.text = "Ingredients: " + ", ".join(ing_names)
	ing_lbl.add_theme_font_size_override("font_size", 11)
	ing_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.6))
	inner.add_child(ing_lbl)
	var method_name: String = str(recipe.get("method", "")).replace("_", " ").capitalize()
	var style_name: String = str(recipe.get("style", "")).replace("_", " ").capitalize()
	var ms_lbl := Label.new()
	ms_lbl.text = "Method: %s | Style: %s" % [method_name, style_name]
	ms_lbl.add_theme_font_size_override("font_size", 11)
	ms_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	inner.add_child(ms_lbl)
	var cr_lbl := Label.new()
	cr_lbl.text = "%d credits" % int(recipe.get("credits", 0))
	cr_lbl.add_theme_font_size_override("font_size", 12)
	cr_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	inner.add_child(cr_lbl)
	# Check if can cook
	var can_cook: bool = true
	for ing_id in ings:
		if not GameState.has_ingredient(ing_id, 1):
			can_cook = false
			break
	var cook_btn := Button.new()
	cook_btn.text = "Cook"
	cook_btn.custom_minimum_size.y = 36
	cook_btn.add_theme_font_size_override("font_size", 13)
	cook_btn.disabled = not can_cook
	var recipe_ref: Dictionary = recipe
	cook_btn.pressed.connect(func():
		var r_ings: Array = recipe_ref.get("ingredients", [])
		for rid in r_ings:
			GameState.remove_ingredient(rid, 1)
		GameState.add_credits(int(recipe_ref.get("credits", 0)))
		GameState.add_restaurant_rep(int(recipe_ref.get("rep", 0)))
		_refresh_restaurant_tab())
	inner.add_child(cook_btn)


# ── Bench Tab ────────────────────────────────────────────────────

var _bench_tab: ScrollContainer
var _bench_selected_ings: Array = []
var _bench_method: String = "char_grill"
var _bench_style: String = "diner"


func _build_bench_tab() -> void:
	_bench_tab = ScrollContainer.new()
	_bench_tab.name = "Bench"
	_tab_container.add_child(_bench_tab)
	_refresh_bench_tab()


func _refresh_bench_tab() -> void:
	for c in _bench_tab.get_children():
		c.queue_free()
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size.x = 330
	vbox.add_theme_constant_override("separation", 8)
	_bench_tab.add_child(vbox)

	var title := Label.new()
	title.text = "EXPERIMENT BENCH"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	vbox.add_child(title)

	# Ingredient slots
	var slot_title := Label.new()
	slot_title.text = "Ingredients (tap to select, tap filled to clear)"
	slot_title.add_theme_font_size_override("font_size", 12)
	slot_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vbox.add_child(slot_title)

	var max_slots: int = GameState.get_bench_slots()
	# Ensure selected array is right size
	while _bench_selected_ings.size() > max_slots:
		_bench_selected_ings.pop_back()

	for i in range(max_slots):
		var slot_btn := Button.new()
		if i < _bench_selected_ings.size() and _bench_selected_ings[i] != "":
			var info: Dictionary = GameState.ingredient_tiers.get(_bench_selected_ings[i], {})
			slot_btn.text = "Slot %d: %s" % [i + 1, info.get("name", _bench_selected_ings[i])]
		else:
			slot_btn.text = "Slot %d: Empty" % [i + 1]
		slot_btn.custom_minimum_size.y = 36
		slot_btn.add_theme_font_size_override("font_size", 13)
		var slot_idx: int = i
		slot_btn.pressed.connect(func(): _on_bench_slot_pressed(slot_idx))
		vbox.add_child(slot_btn)

	vbox.add_child(HSeparator.new())

	# Cooking method picker
	var method_title := Label.new()
	method_title.text = "COOKING METHOD"
	method_title.add_theme_font_size_override("font_size", 13)
	method_title.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	vbox.add_child(method_title)
	for m in GameState.cooking_methods:
		var m_btn := Button.new()
		var m_id: String = m["id"]
		m_btn.text = str(m["name"])
		if m_id == _bench_method:
			m_btn.text = "> " + m_btn.text + " <"
		m_btn.custom_minimum_size.y = 34
		m_btn.add_theme_font_size_override("font_size", 12)
		m_btn.pressed.connect(func():
			_bench_method = m_id
			_refresh_bench_tab())
		vbox.add_child(m_btn)
		var m_desc := Label.new()
		m_desc.text = str(m["desc"])
		m_desc.add_theme_font_size_override("font_size", 10)
		m_desc.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		vbox.add_child(m_desc)

	vbox.add_child(HSeparator.new())

	# Serving style picker
	var style_title := Label.new()
	style_title.text = "SERVING STYLE"
	style_title.add_theme_font_size_override("font_size", 13)
	style_title.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	vbox.add_child(style_title)
	for s in GameState.serving_styles:
		var s_btn := Button.new()
		var s_id: String = s["id"]
		s_btn.text = str(s["name"])
		if s_id == _bench_style:
			s_btn.text = "> " + s_btn.text + " <"
		s_btn.custom_minimum_size.y = 34
		s_btn.add_theme_font_size_override("font_size", 12)
		s_btn.pressed.connect(func():
			_bench_style = s_id
			_refresh_bench_tab())
		vbox.add_child(s_btn)
		var s_desc := Label.new()
		s_desc.text = str(s["desc"])
		s_desc.add_theme_font_size_override("font_size", 10)
		s_desc.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		vbox.add_child(s_desc)

	vbox.add_child(HSeparator.new())

	# Experiment button
	var has_ings: bool = false
	for ing in _bench_selected_ings:
		if ing != "":
			has_ings = true
			break
	var exp_btn := Button.new()
	exp_btn.text = "Experiment!"
	exp_btn.custom_minimum_size.y = 48
	exp_btn.add_theme_font_size_override("font_size", 16)
	exp_btn.disabled = not has_ings
	exp_btn.pressed.connect(_on_experiment_pressed)
	vbox.add_child(exp_btn)


func _on_bench_slot_pressed(slot_idx: int) -> void:
	# If slot is filled, clear it
	if slot_idx < _bench_selected_ings.size() and _bench_selected_ings[slot_idx] != "":
		_bench_selected_ings[slot_idx] = ""
		_refresh_bench_tab()
		return
	# Show ingredient picker
	_show_ingredient_picker(slot_idx)


func _show_ingredient_picker(slot_idx: int) -> void:
	# Replace bench tab content with ingredient list
	for c in _bench_tab.get_children():
		c.queue_free()
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size.x = 330
	vbox.add_theme_constant_override("separation", 6)
	_bench_tab.add_child(vbox)

	var title := Label.new()
	title.text = "SELECT INGREDIENT"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	vbox.add_child(title)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size.y = 34
	cancel_btn.pressed.connect(func(): _refresh_bench_tab())
	vbox.add_child(cancel_btn)

	for ing_id in GameState.restaurant_ingredients:
		var count: int = GameState.restaurant_ingredients[ing_id]
		if count <= 0:
			continue
		var info: Dictionary = GameState.ingredient_tiers.get(ing_id, {})
		var btn := Button.new()
		btn.text = "%s (x%d)" % [info.get("name", ing_id.replace("_", " ").capitalize()), count]
		btn.custom_minimum_size.y = 36
		btn.add_theme_font_size_override("font_size", 13)
		var captured_id: String = ing_id
		btn.pressed.connect(func():
			while _bench_selected_ings.size() <= slot_idx:
				_bench_selected_ings.append("")
			_bench_selected_ings[slot_idx] = captured_id
			_refresh_bench_tab())
		vbox.add_child(btn)

	if GameState.restaurant_ingredients.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No ingredients available."
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		vbox.add_child(empty_lbl)


func _on_experiment_pressed() -> void:
	var ings: Array = []
	for ing in _bench_selected_ings:
		if ing != "":
			ings.append(ing)
	if ings.is_empty():
		return
	var result: Dictionary = GameState.resolve_experiment(ings, _bench_method, _bench_style)
	_bench_selected_ings = []
	_show_experiment_result(result)


func _show_experiment_result(result: Dictionary) -> void:
	for c in _bench_tab.get_children():
		c.queue_free()
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size.x = 330
	vbox.add_theme_constant_override("separation", 8)
	_bench_tab.add_child(vbox)

	var outcome: String = str(result.get("result", "fail"))
	var title := Label.new()
	if outcome == "discovered":
		title.text = "NEW RECIPE DISCOVERED!"
		title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	elif outcome == "known":
		title.text = "KNOWN RECIPE"
		title.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	elif outcome == "catastrophe":
		title.text = "CATASTROPHE"
		title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		title.text = "EXPERIMENT FAILED"
		title.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	if result.has("recipe"):
		var recipe: Dictionary = result["recipe"]
		var name_lbl := Label.new()
		name_lbl.text = str(recipe.get("name", ""))
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_lbl)
		var cr_lbl := Label.new()
		cr_lbl.text = "+%d credits, +%d rep" % [int(recipe.get("credits", 0)), int(recipe.get("rep", 0))]
		cr_lbl.add_theme_font_size_override("font_size", 14)
		cr_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
		cr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(cr_lbl)

	if result.has("message"):
		var msg_lbl := Label.new()
		msg_lbl.text = str(result["message"])
		msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		msg_lbl.add_theme_font_size_override("font_size", 13)
		msg_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
		vbox.add_child(msg_lbl)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size.y = 40
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.pressed.connect(func(): _refresh_bench_tab())
	vbox.add_child(close_btn)


# ── Guests Tab ───────────────────────────────────────────────────

var _guests_tab: ScrollContainer


func _build_guests_tab() -> void:
	_guests_tab = ScrollContainer.new()
	_guests_tab.name = "Guests"
	_tab_container.add_child(_guests_tab)
	GameState.generate_guest_session()
	_refresh_guests_tab()


func _refresh_guests_tab() -> void:
	for c in _guests_tab.get_children():
		c.queue_free()
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size.x = 330
	vbox.add_theme_constant_override("separation", 8)
	_guests_tab.add_child(vbox)

	var title := Label.new()
	title.text = "EXPECTED THIS SESSION"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	vbox.add_child(title)

	if GameState.pending_guests.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No guests expected. Depart and return to generate guests."
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		vbox.add_child(empty_lbl)
	else:
		for gi in range(GameState.pending_guests.size()):
			var guest: Dictionary = GameState.pending_guests[gi]
			_build_guest_card(vbox, guest, gi)

	vbox.add_child(HSeparator.new())

	# Past sessions
	var past_title := Label.new()
	past_title.text = "PAST SESSIONS"
	past_title.add_theme_font_size_override("font_size", 14)
	past_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(past_title)

	var show_count: int = mini(GameState.guest_log.size(), 5)
	if show_count == 0:
		var no_past := Label.new()
		no_past.text = "No past sessions."
		no_past.add_theme_font_size_override("font_size", 12)
		no_past.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		vbox.add_child(no_past)
	else:
		for pi in range(GameState.guest_log.size() - 1, GameState.guest_log.size() - show_count - 1, -1):
			if pi < 0:
				break
			var entry: Dictionary = GameState.guest_log[pi]
			var names: Array = []
			var guests_arr: Array = entry.get("guests", [])
			for g in guests_arr:
				names.append(str(g.get("name", "?")))
			var entry_lbl := Label.new()
			entry_lbl.text = "Session %d: %s" % [int(entry.get("session", 0)), ", ".join(names)]
			entry_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			entry_lbl.add_theme_font_size_override("font_size", 11)
			entry_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
			vbox.add_child(entry_lbl)


func _build_guest_card(vbox: VBoxContainer, guest: Dictionary, idx: int) -> void:
	var container := PanelContainer.new()
	var cstyle := StyleBoxFlat.new()
	var is_special: bool = guest.get("special", false)
	cstyle.bg_color = Color(0.1, 0.06, 0.06, 0.9) if is_special else Color(0.08, 0.1, 0.18, 0.9)
	cstyle.set_border_width_all(1)
	cstyle.border_color = Color(0.9, 0.7, 0.3) if is_special else Color(0.3, 0.3, 0.5)
	cstyle.content_margin_left = 8
	cstyle.content_margin_right = 8
	cstyle.content_margin_top = 6
	cstyle.content_margin_bottom = 6
	container.add_theme_stylebox_override("panel", cstyle)
	vbox.add_child(container)
	var inner := VBoxContainer.new()
	container.add_child(inner)

	var name_lbl := Label.new()
	name_lbl.text = str(guest.get("name", "Unknown"))
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4) if is_special else Color.WHITE)
	inner.add_child(name_lbl)

	var info_lbl := Label.new()
	var trait_str: String = str(guest.get("trait", ""))
	info_lbl.text = "%s | %s%s" % [str(guest.get("faction", "")).capitalize(), str(guest.get("role", "")), " | " + trait_str if not trait_str.is_empty() else ""]
	info_lbl.add_theme_font_size_override("font_size", 11)
	info_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	inner.add_child(info_lbl)

	if is_special:
		var intro_lbl := Label.new()
		intro_lbl.text = str(guest.get("intro", ""))
		intro_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		intro_lbl.add_theme_font_size_override("font_size", 12)
		intro_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
		inner.add_child(intro_lbl)

		# Show choice buttons based on choice_id
		var choice_id: String = str(guest.get("choice_id", ""))
		if guest.get("_resolved", false):
			var result_lbl := Label.new()
			result_lbl.text = str(guest.get("_result_message", ""))
			result_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			result_lbl.add_theme_font_size_override("font_size", 12)
			result_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
			inner.add_child(result_lbl)
		elif choice_id == "velka_first_visit":
			var has_lev: bool = GameState.has_ingredient("leviathan_cut", 1)
			if has_lev:
				_add_choice_btn(inner, guest, idx, "serve_leviathan", "Serve Leviathan Cut")
				_add_choice_btn(inner, guest, idx, "overcharge", "Overcharge (risky)")
			else:
				_add_choice_btn(inner, guest, idx, "honest", "Tell her you don't have it")
				_add_choice_btn(inner, guest, idx, "bluff", "Bluff with something else")
				_add_choice_btn(inner, guest, idx, "defer", "Offer a drink instead")
		elif choice_id == "drath_first_visit":
			_add_choice_btn(inner, guest, idx, "cooperate", "Cooperate with inspection")
			_add_choice_btn(inner, guest, idx, "bribe_food", "Bribe with food (-100 cr)")
			_add_choice_btn(inner, guest, idx, "probe", "Ask what he's really looking for")
	else:
		if guest.get("_resolved", false):
			var result_lbl := Label.new()
			result_lbl.text = str(guest.get("_result_message", ""))
			result_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			result_lbl.add_theme_font_size_override("font_size", 12)
			result_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
			inner.add_child(result_lbl)
		else:
			var serve_btn := Button.new()
			var has_food: bool = not GameState.restaurant_ingredients.is_empty()
			serve_btn.text = "Serve" if has_food else "Serve (no ingredients)"
			serve_btn.disabled = not has_food
			serve_btn.custom_minimum_size.y = 34
			serve_btn.add_theme_font_size_override("font_size", 13)
			var guest_idx: int = idx
			serve_btn.pressed.connect(func(): _on_serve_guest(guest_idx, "auto"))
			inner.add_child(serve_btn)


func _add_choice_btn(inner: VBoxContainer, guest: Dictionary, idx: int, choice: String, label: String) -> void:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size.y = 34
	btn.add_theme_font_size_override("font_size", 12)
	var guest_idx: int = idx
	var choice_str: String = choice
	btn.pressed.connect(func(): _on_serve_guest(guest_idx, choice_str))
	inner.add_child(btn)


func _on_serve_guest(guest_idx: int, choice: String) -> void:
	if guest_idx >= GameState.pending_guests.size():
		return
	var guest: Dictionary = GameState.pending_guests[guest_idx]
	if guest.get("_resolved", false):
		return
	var result: Dictionary = GameState.resolve_guest(guest, choice)
	guest["_resolved"] = true
	guest["_result_message"] = result.get("message", "Served.")
	# Check if all guests resolved
	var all_done: bool = true
	var outcomes: Array = []
	for g in GameState.pending_guests:
		if not g.get("_resolved", false):
			all_done = false
		else:
			outcomes.append(g.get("_result_message", ""))
	if all_done:
		GameState.log_guest_session(GameState.pending_guests, outcomes)
	_refresh_guests_tab()


func _on_cook(cost_id: String, cost_amt: int, earn_cr: int, earn_rep: int) -> void:
	if GameState.remove_ingredient(cost_id, cost_amt):
		GameState.add_credits(earn_cr)
		if earn_rep > 0:
			GameState.add_restaurant_rep(earn_rep)
		_refresh_restaurant_tab()


func _on_close() -> void:
	SaveManager.save_game()
	call_deferred("_do_close")

func _do_close() -> void:
	get_tree().paused = false
	queue_free()
