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

	# Story quest at top
	if GameState.story_act == 1 and not GameState.is_quest_completed("story_act1") and not GameState.is_quest_active("story_act1") and not GameState.get_story_flag("distress_given"):
		var story_panel := PanelContainer.new()
		var sp_style := StyleBoxFlat.new()
		sp_style.bg_color = Color(0.12, 0.1, 0.05, 0.95)
		sp_style.border_color = Color(0.8, 0.7, 0.2)
		sp_style.set_border_width_all(2)
		sp_style.content_margin_left = 10
		sp_style.content_margin_right = 10
		sp_style.content_margin_top = 8
		sp_style.content_margin_bottom = 8
		story_panel.add_theme_stylebox_override("panel", sp_style)
		vbox.add_child(story_panel)
		var sp_inner := VBoxContainer.new()
		story_panel.add_child(sp_inner)
		var sp_title := Label.new()
		sp_title.text = "PRIORITY: Distress Signal"
		sp_title.add_theme_font_size_override("font_size", 16)
		sp_title.add_theme_color_override("font_color", Color.YELLOW)
		sp_inner.add_child(sp_title)
		var sq := WorldData.get_quest_by_id("story_act1")
		var sp_desc := Label.new()
		sp_desc.text = sq.get("description", "An encrypted distress signal from deep space...")
		sp_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sp_desc.add_theme_font_size_override("font_size", 13)
		sp_desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.7))
		sp_inner.add_child(sp_desc)
		var accept_btn := Button.new()
		accept_btn.text = "Accept Mission"
		accept_btn.custom_minimum_size.y = 40
		accept_btn.add_theme_font_size_override("font_size", 14)
		accept_btn.pressed.connect(func():
			GameState.set_story_flag("distress_given", true)
			var sq2 := WorldData.get_quest_by_id("story_act1")
			GameState.accept_quest(sq2, station_id)
			_refresh_quests_tab())
		sp_inner.add_child(accept_btn)
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

	# Menu section
	var menu_title := Label.new()
	menu_title.text = "MENU"
	menu_title.add_theme_font_size_override("font_size", 14)
	menu_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	vbox.add_child(menu_title)

	var rep: int = GameState.restaurant_rep
	var dishes: Array[Dictionary] = []
	dishes.append({"name": "Mystery Meat Patty", "desc": "Dad's recipe. Nobody knows what's in it. Nobody asks.", "cost_id": "scrap_protein", "cost_amt": 2, "credits": 25, "rep": 0, "req_rep": 0})
	dishes.append({"name": "Scrap Protein Bowl", "desc": "Hearty and questionable.", "cost_id": "scrap_protein", "cost_amt": 3, "credits": 40, "rep": 1, "req_rep": 20})
	dishes.append({"name": "Void Steak", "desc": "Seared void creature meat.", "cost_id": "void_flesh", "cost_amt": 1, "credits": 120, "rep": 3, "req_rep": 20})
	dishes.append({"name": "Carrier Roast", "desc": "Slow-roasted carrier organ.", "cost_id": "carrier_organ", "cost_amt": 1, "credits": 150, "rep": 4, "req_rep": 40})
	dishes.append({"name": "Sentinel Tartare", "desc": "Raw sentinel core, thinly sliced.", "cost_id": "sentinel_core", "cost_amt": 1, "credits": 400, "rep": 10, "req_rep": 60})

	for dish in dishes:
		if rep < int(dish["req_rep"]):
			continue
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
