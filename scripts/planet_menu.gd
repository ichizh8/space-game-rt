extends CanvasLayer

var planet_id: String = ""
var planet_name: String = ""
var quest_id: String = ""

var _panel: Panel
var _tab_container: TabContainer
var _quest_tab: Control
var _services_tab: ScrollContainer
var _buildings_tab: Control
var _storage_tab: Control


func setup(p_id: String, p_name: String, p_quest_id: String) -> void:
	planet_id = p_id
	planet_name = p_name
	quest_id = p_quest_id


func _ready() -> void:
	layer = 20
	_build_ui()
	_collect_building_production()


func _build_ui() -> void:
	# Full screen dark panel
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.05, 0.15, 0.95)
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	# Title
	var title := Label.new()
	title.text = planet_name
	title.add_theme_font_size_override("font_size", 24)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 20
	title.offset_left = 20
	title.offset_right = -60
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(title)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close_btn.offset_left = -50
	close_btn.offset_top = 15
	close_btn.offset_right = -10
	close_btn.offset_bottom = 50
	close_btn.pressed.connect(_on_close)
	_panel.add_child(close_btn)

	# Tab container
	_tab_container = TabContainer.new()
	_tab_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tab_container.offset_top = 60
	_tab_container.offset_left = 10
	_tab_container.offset_right = -10
	_tab_container.offset_bottom = -10
	_panel.add_child(_tab_container)

	# Build tabs
	_build_quest_tab()
	_build_services_tab()
	_build_buildings_tab()
	_build_storage_tab()


func _build_quest_tab() -> void:
	_quest_tab = ScrollContainer.new()
	_quest_tab.name = "Quests"
	_tab_container.add_child(_quest_tab)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quest_tab.add_child(vbox)

	var planet_data := GameState.get_planet_data(planet_id)

	if quest_id in planet_data.get("quests_done", []):
		var done_label := Label.new()
		done_label.text = "You have already completed this quest.\n\nThe locals have no new tasks for you. Perhaps check back another time, traveler."
		done_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		done_label.add_theme_font_size_override("font_size", 16)
		vbox.add_child(done_label)
		return

	var quest := WorldData.get_quest_by_id(quest_id)
	if quest.is_empty():
		var no_quest := Label.new()
		no_quest.text = "No quests available on this planet."
		no_quest.add_theme_font_size_override("font_size", 16)
		vbox.add_child(no_quest)
		return

	# Quest title
	var q_title := Label.new()
	q_title.text = quest.get("title", "Unknown Quest")
	q_title.add_theme_font_size_override("font_size", 20)
	q_title.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(q_title)

	# Quest description
	var q_desc := Label.new()
	q_desc.text = "\n" + quest.get("description", "") + "\n"
	q_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q_desc.add_theme_font_size_override("font_size", 15)
	vbox.add_child(q_desc)

	# Choices
	var choices: Array = quest.get("choices", [])
	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		var btn := Button.new()
		btn.text = choice.get("text", "Choice " + str(i + 1))
		btn.add_theme_font_size_override("font_size", 16)
		btn.custom_minimum_size.y = 44
		btn.pressed.connect(_on_quest_choice.bind(quest_id, choice))
		vbox.add_child(btn)


func _on_quest_choice(q_id: String, choice: Dictionary) -> void:
	# Apply rewards
	var reward: Dictionary = choice.get("reward", {})
	for key in reward:
		if key == "credits":
			GameState.add_credits(int(reward[key]))
		else:
			GameState.add_resource(key, int(reward[key]))

	# Mark quest done
	var planet_data := GameState.get_planet_data(planet_id)
	if not planet_data.has("quests_done"):
		planet_data["quests_done"] = []
	planet_data["quests_done"].append(q_id)

	# Show outcome
	_clear_tab(_quest_tab)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quest_tab.add_child(vbox)

	var outcome_label := Label.new()
	outcome_label.text = choice.get("outcome", "Something happened...")
	outcome_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outcome_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(outcome_label)

	if not reward.is_empty():
		var reward_label := Label.new()
		var reward_text := "\nRewards:\n"
		for key in reward:
			reward_text += "  " + key.capitalize() + ": +" + str(reward[key]) + "\n"
		reward_label.text = reward_text
		reward_label.add_theme_font_size_override("font_size", 14)
		reward_label.add_theme_color_override("font_color", Color.GREEN)
		vbox.add_child(reward_label)

	SaveManager.save_game()


func _build_buildings_tab() -> void:
	_buildings_tab = ScrollContainer.new()
	_buildings_tab.name = "Buildings"
	_tab_container.add_child(_buildings_tab)

	_refresh_buildings()


func _refresh_buildings() -> void:
	_clear_tab(_buildings_tab)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buildings_tab.add_child(vbox)

	var planet_data := GameState.get_planet_data(planet_id)
	var buildings: Dictionary = planet_data.get("buildings", {})

	var building_ids := ["mining_plant", "manufacturing", "storage_depot", "shipyard"]
	for b_id in building_ids:
		var b_data := WorldData.get_building_data(b_id)
		if b_data.is_empty():
			continue

		var current_level: int = buildings.get(b_id, 0)
		var tiers: Array = b_data.get("tiers", [])

		var container := PanelContainer.new()
		var container_style := StyleBoxFlat.new()
		container_style.bg_color = Color(0.1, 0.1, 0.2, 0.8)
		container_style.border_color = Color(0.3, 0.3, 0.5)
		container_style.set_border_width_all(1)
		container_style.content_margin_left = 10
		container_style.content_margin_right = 10
		container_style.content_margin_top = 8
		container_style.content_margin_bottom = 8
		container.add_theme_stylebox_override("panel", container_style)
		vbox.add_child(container)

		var inner_vbox := VBoxContainer.new()
		container.add_child(inner_vbox)

		# Name + level
		var name_label := Label.new()
		name_label.text = b_data.get("name", b_id) + " (Level " + str(current_level) + ")"
		name_label.add_theme_font_size_override("font_size", 17)
		name_label.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
		inner_vbox.add_child(name_label)

		# Description
		var desc_label := Label.new()
		desc_label.text = b_data.get("description", "")
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.add_theme_font_size_override("font_size", 13)
		inner_vbox.add_child(desc_label)

		# Production info (if built)
		if current_level > 0 and current_level <= tiers.size():
			var tier: Dictionary = tiers[current_level - 1]
			var prod: Dictionary = tier.get("production", {})
			if not prod.is_empty():
				var prod_text := "Producing: "
				var parts: Array[String] = []
				var interval: int = tier.get("production_interval", 300)
				for res_key in prod:
					parts.append(str(prod[res_key]) + " " + res_key)
				prod_text += ", ".join(parts) + " per " + str(interval / 60) + " min"
				var prod_label := Label.new()
				prod_label.text = prod_text
				prod_label.add_theme_font_size_override("font_size", 13)
				prod_label.add_theme_color_override("font_color", Color.GREEN)
				inner_vbox.add_child(prod_label)

		# Shipyard special actions
		if b_id == "shipyard" and current_level >= 1:
			var repair_btn := Button.new()
			repair_btn.text = "Repair Hull (20 scrap)"
			repair_btn.add_theme_font_size_override("font_size", 14)
			repair_btn.custom_minimum_size.y = 36
			repair_btn.pressed.connect(_on_repair_pressed)
			inner_vbox.add_child(repair_btn)

			var refuel_btn := Button.new()
			refuel_btn.text = "Refuel +50 fuel  (20 credits)"
			refuel_btn.add_theme_font_size_override("font_size", 14)
			refuel_btn.custom_minimum_size.y = 36
			refuel_btn.pressed.connect(_on_refuel_pressed)
			inner_vbox.add_child(refuel_btn)

		# Build / Upgrade button
		if current_level < tiers.size():
			var next_tier: Dictionary = tiers[current_level]
			var cost: Dictionary = next_tier.get("cost", {})
			var cost_text := ""
			for key in cost:
				cost_text += key.capitalize() + ": " + str(cost[key]) + "  "

			var build_btn := Button.new()
			if current_level == 0:
				build_btn.text = "Build (" + cost_text.strip_edges() + ")"
			else:
				build_btn.text = "Upgrade (" + cost_text.strip_edges() + ")"
			build_btn.add_theme_font_size_override("font_size", 14)
			build_btn.custom_minimum_size.y = 36
			build_btn.disabled = not GameState.has_resources(cost)
			build_btn.pressed.connect(_on_build_pressed.bind(b_id, cost))
			inner_vbox.add_child(build_btn)
		elif current_level >= tiers.size():
			var max_label := Label.new()
			max_label.text = "MAX LEVEL"
			max_label.add_theme_font_size_override("font_size", 14)
			max_label.add_theme_color_override("font_color", Color.GOLD)
			inner_vbox.add_child(max_label)


func _on_build_pressed(building_id: String, cost: Dictionary) -> void:
	if GameState.spend_resources(cost):
		var planet_data := GameState.get_planet_data(planet_id)
		if not planet_data.has("buildings"):
			planet_data["buildings"] = {}
		var current: int = planet_data["buildings"].get(building_id, 0)
		planet_data["buildings"][building_id] = current + 1
		_refresh_buildings()
		SaveManager.save_game()


func _on_repair_pressed() -> void:
	if GameState.remove_resource("scrap", 20):
		GameState.heal(50.0)
		_refresh_buildings()


func _on_refuel_pressed() -> void:
	if GameState.credits >= 20:
		GameState.credits -= 20
		GameState.credits_changed.emit(GameState.credits)
		GameState.add_fuel(50.0)
		_refresh_buildings()



func _build_services_tab() -> void:
	_services_tab = ScrollContainer.new()
	_services_tab.name = "Services"
	_tab_container.add_child(_services_tab)
	_refresh_services()


func _refresh_services() -> void:
	_clear_tab(_services_tab)
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size.x = 320
	_services_tab.add_child(vbox)

	# Repair & Fuel
	var repair_title := Label.new()
	repair_title.text = "REPAIR & FUEL"
	repair_title.add_theme_font_size_override("font_size", 14)
	repair_title.add_theme_color_override("font_color", Color.CYAN)
	vbox.add_child(repair_title)

	var hull_lbl := Label.new()
	hull_lbl.text = "Hull: %.0f / %.0f" % [GameState.hull, GameState.max_hull]
	hull_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(hull_lbl)

	var repair_btn := Button.new()
	repair_btn.text = "Repair +50 HP  (cost: 15 scrap)"
	repair_btn.custom_minimum_size.y = 40
	repair_btn.disabled = not GameState.has_resources({"scrap": 15})
	repair_btn.pressed.connect(_on_service_repair)
	vbox.add_child(repair_btn)

	var fuel_lbl := Label.new()
	fuel_lbl.text = "Fuel: %.0f / %.0f" % [GameState.fuel, GameState.max_fuel]
	fuel_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(fuel_lbl)

	var refuel_btn := Button.new()
	refuel_btn.text = "Refuel +50  (cost: 30 credits)"
	refuel_btn.custom_minimum_size.y = 40
	refuel_btn.disabled = GameState.credits < 30
	refuel_btn.pressed.connect(_on_service_refuel)
	vbox.add_child(refuel_btn)

	# Sell resources
	var sep := HSeparator.new()
	vbox.add_child(sep)
	var sell_title := Label.new()
	sell_title.text = "SELL RESOURCES"
	sell_title.add_theme_font_size_override("font_size", 14)
	sell_title.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(sell_title)

	var prices := {"ore": 4, "crystal": 10, "scrap": 2}
	for res in prices:
		var amt: int = GameState.resources.get(res, 0)
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "%s: %d  (%d cr each)" % [res.capitalize(), amt, prices[res]]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 13)
		row.add_child(lbl)
		var sell_btn := Button.new()
		sell_btn.text = "Sell All"
		sell_btn.custom_minimum_size = Vector2(80, 36)
		sell_btn.disabled = amt == 0
		sell_btn.pressed.connect(_on_sell_resource.bind(res, prices[res]))
		row.add_child(sell_btn)
		vbox.add_child(row)

	# Ship upgrades
	var sep2 := HSeparator.new()
	vbox.add_child(sep2)
	var upgrade_title := Label.new()
	upgrade_title.text = "SHIP UPGRADES"
	upgrade_title.add_theme_font_size_override("font_size", 14)
	upgrade_title.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	vbox.add_child(upgrade_title)

	_add_upgrade_row(vbox, "Weapons",     0, GameState.weapon_level, [80, 200, 500], ["+5 dmg", "+5 dmg", "+10 dmg"])
	_add_upgrade_row(vbox, "Engines",     1, GameState.speed_level,  [60, 150, 400], ["+20 spd", "+20 spd", "+40 spd"])
	_add_upgrade_row(vbox, "Hull Plating",2, GameState.shield_level, [100, 250, 600],["+25 max hp", "+25 max hp", "+50 max hp"])


func _add_upgrade_row(vbox: VBoxContainer, name: String, kind: int, level: int,
		costs: Array, labels: Array) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 40
	vbox.add_child(row)

	var name_lbl := Label.new()
	var level_str := "MAX" if level >= 3 else ("Lv" + str(level))
	name_lbl.text = name + " [" + level_str + "]"
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(name_lbl)

	if level < 3:
		var btn := Button.new()
		btn.text = labels[level] + " (" + str(costs[level]) + " cr)"
		btn.custom_minimum_size = Vector2(140, 36)
		btn.add_theme_font_size_override("font_size", 12)
		btn.disabled = GameState.credits < costs[level]
		btn.pressed.connect(_on_upgrade_pressed.bind(kind))
		row.add_child(btn)
	else:
		var max_lbl := Label.new()
		max_lbl.text = "MAXED"
		max_lbl.add_theme_color_override("font_color", Color.GOLD)
		max_lbl.add_theme_font_size_override("font_size", 13)
		row.add_child(max_lbl)


func _on_upgrade_pressed(kind: int) -> void:
	var costs_w := [80, 200, 500]
	var costs_e := [60, 150, 400]
	var costs_s := [100, 250, 600]
	match kind:
		0: # Weapons
			var lvl := GameState.weapon_level
			if lvl >= 3 or GameState.credits < costs_w[lvl]: return
			GameState.credits -= costs_w[lvl]
			GameState.credits_changed.emit(GameState.credits)
			GameState.player_damage_bonus += [5.0, 5.0, 10.0][lvl]
			GameState.weapon_level += 1
		1: # Engines
			var lvl := GameState.speed_level
			if lvl >= 3 or GameState.credits < costs_e[lvl]: return
			GameState.credits -= costs_e[lvl]
			GameState.credits_changed.emit(GameState.credits)
			GameState.player_speed_bonus += [20.0, 20.0, 40.0][lvl]
			GameState.speed_level += 1
		2: # Hull Plating
			var lvl := GameState.shield_level
			if lvl >= 3 or GameState.credits < costs_s[lvl]: return
			GameState.credits -= costs_s[lvl]
			GameState.credits_changed.emit(GameState.credits)
			var shield_bonus_table: Array[float] = [25.0, 25.0, 50.0]
			var bonus: float = shield_bonus_table[lvl]
			GameState.max_hull += bonus
			GameState.hull = min(GameState.hull + bonus, GameState.max_hull)
			GameState.hull_changed.emit(GameState.hull)
			GameState.shield_level += 1
	SaveManager.save_game()
	_refresh_services()


func _on_service_repair() -> void:
	if GameState.remove_resource("scrap", 15):
		GameState.heal(50.0)
		_refresh_services()


func _on_service_refuel() -> void:
	if GameState.credits >= 30:
		GameState.credits -= 30
		GameState.credits_changed.emit(GameState.credits)
		GameState.add_fuel(50.0)
		_refresh_services()


func _on_sell_resource(res: String, price_each: int) -> void:
	var amt: int = GameState.resources.get(res, 0)
	if amt > 0:
		GameState.resources[res] = 0
		var effective_price := int(round(float(price_each) * (1.0 + GameState.captain_sell_bonus)))
		GameState.add_credits(amt * effective_price)
		GameState.resources_changed.emit()
		_refresh_services()

func _build_storage_tab() -> void:
	_storage_tab = ScrollContainer.new()
	_storage_tab.name = "Storage"
	_tab_container.add_child(_storage_tab)

	_refresh_storage()


func _refresh_storage() -> void:
	_clear_tab(_storage_tab)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_storage_tab.add_child(vbox)

	var planet_data := GameState.get_planet_data(planet_id)
	var storage: Dictionary = planet_data.get("storage", {"ore": 0, "crystal": 0, "scrap": 0})

	var title := Label.new()
	title.text = "Planet Storage"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	vbox.add_child(title)

	var resource_types := ["ore", "crystal", "scrap"]
	for res_type in resource_types:
		var container := HBoxContainer.new()
		container.custom_minimum_size.y = 40
		vbox.add_child(container)

		var label := Label.new()
		label.text = res_type.capitalize() + ": " + str(storage.get(res_type, 0))
		label.add_theme_font_size_override("font_size", 15)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.add_child(label)

		var ship_label := Label.new()
		ship_label.text = "(Ship: " + str(GameState.resources.get(res_type, 0)) + ")"
		ship_label.add_theme_font_size_override("font_size", 13)
		container.add_child(ship_label)

		var deposit_btn := Button.new()
		deposit_btn.text = "Deposit"
		deposit_btn.add_theme_font_size_override("font_size", 13)
		deposit_btn.pressed.connect(_on_deposit.bind(res_type))
		container.add_child(deposit_btn)

		var withdraw_btn := Button.new()
		withdraw_btn.text = "Withdraw"
		withdraw_btn.add_theme_font_size_override("font_size", 13)
		withdraw_btn.pressed.connect(_on_withdraw.bind(res_type))
		container.add_child(withdraw_btn)


func _on_deposit(res_type: String) -> void:
	var amount: int = GameState.resources.get(res_type, 0)
	if amount <= 0:
		return
	GameState.remove_resource(res_type, amount)
	var planet_data := GameState.get_planet_data(planet_id)
	if not planet_data.has("storage"):
		planet_data["storage"] = {"ore": 0, "crystal": 0, "scrap": 0}
	planet_data["storage"][res_type] = planet_data["storage"].get(res_type, 0) + amount
	_refresh_storage()
	SaveManager.save_game()


func _on_withdraw(res_type: String) -> void:
	var planet_data := GameState.get_planet_data(planet_id)
	var storage: Dictionary = planet_data.get("storage", {})
	var amount: int = storage.get(res_type, 0)
	if amount <= 0:
		return
	storage[res_type] = 0
	GameState.add_resource(res_type, amount)
	_refresh_storage()
	SaveManager.save_game()


func _collect_building_production() -> void:
	var planet_data := GameState.get_planet_data(planet_id)
	var buildings: Dictionary = planet_data.get("buildings", {})
	var last_visit: float = planet_data.get("last_visit_time", Time.get_unix_time_from_system())
	var now: float = Time.get_unix_time_from_system()
	var elapsed: float = now - last_visit

	for b_id in buildings:
		var level: int = buildings[b_id]
		if level <= 0:
			continue
		var b_data := WorldData.get_building_data(b_id)
		if b_data.is_empty():
			continue
		var tiers: Array = b_data.get("tiers", [])
		if level > tiers.size():
			continue
		var tier: Dictionary = tiers[level - 1]
		var production: Dictionary = tier.get("production", {})
		var interval: int = tier.get("production_interval", 300)
		if interval <= 0 or production.is_empty():
			continue

		var cycles := int(elapsed / interval)
		if cycles > 0:
			if not planet_data.has("storage"):
				planet_data["storage"] = {"ore": 0, "crystal": 0, "scrap": 0}
			for res_key in production:
				var produced: int = int(production[res_key]) * cycles
				planet_data["storage"][res_key] = planet_data["storage"].get(res_key, 0) + produced

	planet_data["last_visit_time"] = now
	SaveManager.save_game()


func _clear_tab(tab: ScrollContainer) -> void:
	for child in tab.get_children():
		child.queue_free()


func _on_close() -> void:
	SaveManager.save_game()
	queue_free()
