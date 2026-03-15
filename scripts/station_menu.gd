extends CanvasLayer

var station_id: String = ""
var station_name: String = ""
var _panel: Panel


func setup(s_id: String, s_name: String) -> void:
	station_id = s_id
	station_name = s_name


func _ready() -> void:
	layer = 20
	_build_ui()


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

	var sub := Label.new()
	sub.text = "SPACE STATION — DOCKING SERVICES"
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", Color(0.4, 0.5, 0.6))
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 46
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(sub)

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

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 68
	scroll.offset_left = 10
	scroll.offset_right = -10
	scroll.offset_bottom = -10
	_panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size.x = 330
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)
	_fill_services(vbox)


func _fill_services(vbox: VBoxContainer) -> void:
	# Repair
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
			SaveManager.save_game()
			_on_close())
	vbox.add_child(repair_btn)

	var full_repair_btn := Button.new()
	full_repair_btn.text = "Full Repair  (40 scrap)"
	full_repair_btn.custom_minimum_size.y = 44
	full_repair_btn.disabled = not GameState.has_resources({"scrap": 40})
	full_repair_btn.pressed.connect(func():
		if GameState.remove_resource("scrap", 40):
			GameState.heal(GameState.max_hull)
			SaveManager.save_game()
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
			SaveManager.save_game()
			_on_close())
	vbox.add_child(refuel_btn)

	vbox.add_child(HSeparator.new())

	# Sell resources
	var s_title := Label.new()
	s_title.text = "SELL RESOURCES"
	s_title.add_theme_font_size_override("font_size", 14)
	s_title.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(s_title)

	var prices := {"ore": 4, "crystal": 10, "scrap": 2, "fuel": 6}
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
				SaveManager.save_game()
				_on_close())
		row.add_child(sell_btn)
		vbox.add_child(row)


func _on_close() -> void:
	call_deferred("queue_free")
