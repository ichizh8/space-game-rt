extends CanvasLayer

var _tab_container: TabContainer
var _captain_tab: ScrollContainer
var _bridge_tab: ScrollContainer
var _crafting_tab: ScrollContainer
var _map_tab: ScrollContainer


class MapControl extends Control:
	const MAP_SCALE := 0.09
	const FOG_RADIUS := 18.0
	const PLANET_RADIUS := 5.0
	const GRID_WORLD := 500.0

	var _player_pos: Vector2 = Vector2.ZERO
	var _poll_timer: float = 0.0

	func _process(delta: float) -> void:
		_poll_timer += delta
		if _poll_timer >= 0.25:
			_poll_timer = 0.0
			var players := get_tree().get_nodes_in_group("player")
			if players.size() > 0 and is_instance_valid(players[0]):
				_player_pos = (players[0] as Node2D).global_position
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var center := size / 2.0

		# Background
		draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.04, 0.08))

		# Grid
		var grid_px := GRID_WORLD * MAP_SCALE
		var ox := fmod(_player_pos.x * MAP_SCALE, grid_px)
		var oy := fmod(_player_pos.y * MAP_SCALE, grid_px)
		var gc := Color(0.06, 0.11, 0.17)
		var gx := center.x - ox
		while gx < w:
			draw_line(Vector2(gx, 0), Vector2(gx, h), gc, 1.0)
			gx += grid_px
		gx = center.x - ox - grid_px
		while gx >= 0:
			draw_line(Vector2(gx, 0), Vector2(gx, h), gc, 1.0)
			gx -= grid_px
		var gy := center.y - oy
		while gy < h:
			draw_line(Vector2(0, gy), Vector2(w, gy), gc, 1.0)
			gy += grid_px
		gy = center.y - oy - grid_px
		while gy >= 0:
			draw_line(Vector2(0, gy), Vector2(w, gy), gc, 1.0)
			gy -= grid_px

		# Fog of war — revealed trail circles
		var fog_col := Color(0.08, 0.14, 0.22)
		for trail_pos in GameState.map_visited_trail:
			var mp := center + (trail_pos - _player_pos) * MAP_SCALE
			if mp.x > -FOG_RADIUS and mp.x < w + FOG_RADIUS and mp.y > -FOG_RADIUS and mp.y < h + FOG_RADIUS:
				draw_circle(mp, FOG_RADIUS, fog_col)

		# Origin marker
		var origin_mp := center + (Vector2.ZERO - _player_pos) * MAP_SCALE
		if origin_mp.x > -20 and origin_mp.x < w + 20 and origin_mp.y > -20 and origin_mp.y < h + 20:
			draw_circle(origin_mp, 4.0, Color(0.3, 0.8, 1.0, 0.7))
			draw_arc(origin_mp, 8.0, 0.0, TAU, 16, Color(0.3, 0.8, 1.0, 0.35), 1.5)
			draw_string(ThemeDB.fallback_font, origin_mp + Vector2(10, 4), "ORIGIN",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.3, 0.8, 1.0, 0.8))

		# Discovered planets
		for planet_id in GameState.map_discovered_planets:
			var entry: Dictionary = GameState.map_discovered_planets[planet_id]
			var world_pos := Vector2(float(entry.get("pos_x", 0)), float(entry.get("pos_y", 0)))
			var mp := center + (world_pos - _player_pos) * MAP_SCALE
			if mp.x < -20 or mp.x > w + 20 or mp.y < -20 or mp.y > h + 20:
				continue
			var ch := float(entry.get("color_h", 0.3))
			var pcol := Color.from_hsv(ch, 0.7, 0.9)
			draw_circle(mp, PLANET_RADIUS, pcol)
			draw_arc(mp, PLANET_RADIUS + 2.5, 0.0, TAU, 16, Color(pcol.r, pcol.g, pcol.b, 0.4), 1.0)
			var pname := str(entry.get("name", "?"))
			draw_string(ThemeDB.fallback_font, mp + Vector2(9, 4), pname,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.85, 0.9, 0.9))

		# Player dot
		draw_circle(center, 4.0, Color.CYAN)
		draw_arc(center, 7.0, 0.0, TAU, 16, Color(0.0, 1.0, 1.0, 0.4), 1.5)

		# Border
		draw_rect(Rect2(0, 0, w, h), Color(0.15, 0.35, 0.55), false, 1.5)

		# Coords
		draw_string(ThemeDB.fallback_font, Vector2(6, h - 6),
			"%.0f, %.0f" % [_player_pos.x, _player_pos.y],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.4, 0.6, 0.8, 0.8))


func _ready() -> void:
	layer = 15
	_build_ui()
	GameState.xp_gained.connect(_on_xp_changed)
	GameState.perk_unlocked.connect(_on_perk_unlocked)


func _build_ui() -> void:
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.07, 0.12, 0.97)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var title := Label.new()
	title.text = "COCKPIT"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 18
	title.offset_left = 20
	title.offset_right = -60
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close_btn.offset_left = -50
	close_btn.offset_top = 12
	close_btn.offset_right = -8
	close_btn.offset_bottom = 50
	close_btn.pressed.connect(_on_close)
	panel.add_child(close_btn)

	_tab_container = TabContainer.new()
	_tab_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tab_container.offset_top = 58
	_tab_container.offset_left = 8
	_tab_container.offset_right = -8
	_tab_container.offset_bottom = -8
	panel.add_child(_tab_container)

	_build_bridge_tab()
	_build_captain_tab()
	_build_crafting_tab()
	_build_map_tab()


func _build_bridge_tab() -> void:
	_bridge_tab = ScrollContainer.new()
	_bridge_tab.name = "Bridge"
	_tab_container.add_child(_bridge_tab)
	_refresh_bridge()


func _refresh_bridge() -> void:
	for c in _bridge_tab.get_children():
		c.queue_free()
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size.x = 330
	vbox.add_theme_constant_override("separation", 8)
	_bridge_tab.add_child(vbox)

	# Ship status
	var sec1 := _make_section_label("SHIP STATUS")
	vbox.add_child(sec1)
	_add_stat_row(vbox, "Hull", "%.0f / %.0f" % [GameState.hull, GameState.max_hull])
	_add_stat_row(vbox, "Fuel", "%.0f / %.0f" % [GameState.fuel, GameState.max_fuel])
	_add_stat_row(vbox, "Credits", str(GameState.credits) + " cr")

	# Resources
	vbox.add_child(HSeparator.new())
	var sec2 := _make_section_label("CARGO HOLD")
	vbox.add_child(sec2)
	for res in ["ore", "crystal", "fuel", "scrap"]:
		_add_stat_row(vbox, res.capitalize(), str(GameState.resources.get(res, 0)))

	# Ship upgrades
	vbox.add_child(HSeparator.new())
	var sec3 := _make_section_label("SHIP UPGRADES")
	vbox.add_child(sec3)
	_add_stat_row(vbox, "Weapons", "Lv %d" % GameState.weapon_level)
	_add_stat_row(vbox, "Engines", "Lv %d" % GameState.speed_level)
	_add_stat_row(vbox, "Hull Plating", "Lv %d" % GameState.shield_level)

	# Note about roguelite
	vbox.add_child(HSeparator.new())
	var note := Label.new()
	note.text = "Ship upgrades & resources are lost on death.\nCaptain XP and perks are permanent."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vbox.add_child(note)


func _build_captain_tab() -> void:
	_captain_tab = ScrollContainer.new()
	_captain_tab.name = "Captain"
	_tab_container.add_child(_captain_tab)
	_refresh_captain()


func _refresh_captain() -> void:
	for c in _captain_tab.get_children():
		c.queue_free()
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size.x = 330
	vbox.add_theme_constant_override("separation", 6)
	_captain_tab.add_child(vbox)

	# XP bar
	var xp_section := _make_section_label("CAPTAIN EXPERIENCE")
	vbox.add_child(xp_section)

	var xp_in_level := GameState.captain_xp % 100
	var xp_bar := ProgressBar.new()
	xp_bar.max_value = 100
	xp_bar.value = xp_in_level
	xp_bar.custom_minimum_size.y = 20
	var xp_style := StyleBoxFlat.new()
	xp_style.bg_color = Color(0.2, 0.6, 1.0)
	xp_bar.add_theme_stylebox_override("fill", xp_style)
	vbox.add_child(xp_bar)

	var xp_lbl := Label.new()
	xp_lbl.text = "Total XP: %d  |  Points available: %d" % [GameState.captain_xp, GameState.get_available_perk_points()]
	xp_lbl.add_theme_font_size_override("font_size", 13)
	xp_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	vbox.add_child(xp_lbl)

	vbox.add_child(HSeparator.new())

	# Perk branches
	_add_perk_branch(vbox, "COMBAT", [
		{"id": "iron_will",  "name": "Iron Will",   "desc": "+20 max hull permanently"},
		{"id": "steady_aim", "name": "Steady Aim",  "desc": "+8 weapon damage"},
		{"id": "last_stand", "name": "Last Stand",  "desc": "+30% damage when hull < 20%"},
	])
	vbox.add_child(HSeparator.new())
	_add_perk_branch(vbox, "PROSPECTOR", [
		{"id": "efficient_miner", "name": "Efficient Miner", "desc": "+50% mining yield"},
		{"id": "fuel_saver",      "name": "Fuel Saver",      "desc": "-25% fuel consumption"},
		{"id": "salvager",        "name": "Salvager",         "desc": "Enemy kills also drop scrap"},
	])
	vbox.add_child(HSeparator.new())
	_add_perk_branch(vbox, "EXPLORER", [
		{"id": "keen_eye",   "name": "Keen Eye",   "desc": "Artifact & planet detect range +50%"},
		{"id": "negotiator", "name": "Negotiator", "desc": "+25% sell prices"},
		{"id": "lucky_find", "name": "Lucky Find", "desc": "Artifact drops are always rare tier"},
	])


func _add_perk_branch(vbox: VBoxContainer, branch_name: String, perks: Array) -> void:
	var branch_lbl := Label.new()
	branch_lbl.text = branch_name
	branch_lbl.add_theme_font_size_override("font_size", 13)
	branch_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	vbox.add_child(branch_lbl)

	for perk in perks:
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 44
		vbox.add_child(row)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		var name_lbl := Label.new()
		name_lbl.text = perk["name"]
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", Color.WHITE if not GameState.has_perk(perk["id"]) else Color.GREEN)
		info.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = perk["desc"]
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(desc_lbl)

		if GameState.has_perk(perk["id"]):
			var done_lbl := Label.new()
			done_lbl.text = "UNLOCKED"
			done_lbl.add_theme_font_size_override("font_size", 12)
			done_lbl.add_theme_color_override("font_color", Color.GREEN)
			row.add_child(done_lbl)
		else:
			var btn := Button.new()
			btn.text = "1 pt"
			btn.custom_minimum_size = Vector2(60, 36)
			btn.add_theme_font_size_override("font_size", 12)
			btn.disabled = GameState.get_available_perk_points() <= 0
			btn.pressed.connect(_on_perk_buy.bind(perk["id"]))
			row.add_child(btn)


func _build_crafting_tab() -> void:
	_crafting_tab = ScrollContainer.new()
	_crafting_tab.name = "Crafting"
	_tab_container.add_child(_crafting_tab)
	_refresh_crafting()


func _refresh_crafting() -> void:
	for c in _crafting_tab.get_children():
		c.queue_free()
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size.x = 330
	vbox.add_theme_constant_override("separation", 6)
	_crafting_tab.add_child(vbox)

	var sec := _make_section_label("FIELD CRAFTING")
	vbox.add_child(sec)

	var note := Label.new()
	note.text = "Craft anywhere. Use resources to survive without a planet."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vbox.add_child(note)

	vbox.add_child(HSeparator.new())

	# Recipes: {name, desc, cost: {}, effect: callable, effect_label}
	var recipes := [
		{
			"name": "Emergency Repair",
			"desc": "Patch hull with scrap and ore. Restores 40 hull.",
			"cost": {"ore": 8, "scrap": 6},
			"kind": "repair",
			"value": 40.0
		},
		{
			"name": "Fuel Synthesis",
			"desc": "Refine crystal into fuel. Restores 40 fuel.",
			"cost": {"crystal": 5, "ore": 4},
			"kind": "fuel",
			"value": 40.0
		},
		{
			"name": "Energy Core",
			"desc": "Sell-ready component. Converts to 120 credits.",
			"cost": {"crystal": 12, "ore": 6},
			"kind": "credits",
			"value": 120.0
		},
		{
			"name": "Nano Repair Kit",
			"desc": "Full field repair. Restores 80 hull.",
			"cost": {"ore": 18, "crystal": 8, "scrap": 10},
			"kind": "repair",
			"value": 80.0
		},
		{
			"name": "Fuel Cell",
			"desc": "High-yield fuel conversion. Restores 80 fuel.",
			"cost": {"crystal": 12, "ore": 8},
			"kind": "fuel",
			"value": 80.0
		},
	]

	for recipe in recipes:
		var can_craft := GameState.has_resources(recipe["cost"])
		var container := PanelContainer.new()
		var cstyle := StyleBoxFlat.new()
		cstyle.bg_color = Color(0.08, 0.12, 0.18, 0.9) if can_craft else Color(0.06, 0.06, 0.08, 0.7)
		cstyle.set_border_width_all(1)
		cstyle.border_color = Color(0.2, 0.4, 0.6) if can_craft else Color(0.15, 0.15, 0.2)
		cstyle.content_margin_left = 8
		cstyle.content_margin_right = 8
		cstyle.content_margin_top = 6
		cstyle.content_margin_bottom = 6
		container.add_theme_stylebox_override("panel", cstyle)
		vbox.add_child(container)

		var inner := HBoxContainer.new()
		container.add_child(inner)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner.add_child(info)

		var r_name := Label.new()
		r_name.text = recipe["name"]
		r_name.add_theme_font_size_override("font_size", 14)
		r_name.add_theme_color_override("font_color", Color.WHITE if can_craft else Color(0.5, 0.5, 0.5))
		info.add_child(r_name)

		var r_desc := Label.new()
		r_desc.text = recipe["desc"]
		r_desc.add_theme_font_size_override("font_size", 11)
		r_desc.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
		r_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(r_desc)

		var cost_parts: Array[String] = []
		for key in recipe["cost"]:
			var have: int = GameState.resources.get(key, 0)
			var need: int = recipe["cost"][key]
			cost_parts.append("%s: %d/%d" % [key.capitalize(), have, need])
		var cost_lbl := Label.new()
		cost_lbl.text = "  ".join(cost_parts)
		cost_lbl.add_theme_font_size_override("font_size", 11)
		cost_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4) if can_craft else Color(0.7, 0.3, 0.3))
		info.add_child(cost_lbl)

		var craft_btn := Button.new()
		craft_btn.text = "CRAFT"
		craft_btn.custom_minimum_size = Vector2(70, 50)
		craft_btn.add_theme_font_size_override("font_size", 13)
		craft_btn.disabled = not can_craft
		craft_btn.pressed.connect(_on_craft.bind(recipe["kind"], recipe["cost"], recipe["value"]))
		inner.add_child(craft_btn)


func _build_map_tab() -> void:
	_map_tab = ScrollContainer.new()
	_map_tab.name = "Map"
	_tab_container.add_child(_map_tab)

	var vbox := VBoxContainer.new()
	_map_tab.add_child(vbox)

	var legend := Label.new()
	legend.text = "Cyan = you   Colored dots = planets   Blue = origin   Dark = unexplored"
	legend.add_theme_font_size_override("font_size", 10)
	legend.add_theme_color_override("font_color", Color(0.45, 0.55, 0.65))
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(legend)

	var map_ctrl := MapControl.new()
	map_ctrl.custom_minimum_size = Vector2(320, 370)
	vbox.add_child(map_ctrl)


func _on_craft(kind: String, cost: Dictionary, value: float) -> void:
	if not GameState.spend_resources(cost):
		return
	match kind:
		"repair":  GameState.heal(value)
		"fuel":    GameState.add_fuel(value)
		"credits": GameState.add_credits(int(value))
	SaveManager.save_game()
	_refresh_crafting()


func _on_perk_buy(perk_id: String) -> void:
	if GameState.unlock_perk(perk_id):
		SaveManager.save_game()
		_refresh_captain()


func _on_xp_changed(_total: int) -> void:
	# Refresh captain tab only if it is visible
	if is_instance_valid(_captain_tab) and _tab_container.current_tab == 1:
		_refresh_captain()


func _on_perk_unlocked(_perk_id: String) -> void:
	pass  # handled in _on_perk_buy already


func _on_close() -> void:
	call_deferred("queue_free")


func _make_section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	return lbl


func _add_stat_row(vbox: VBoxContainer, label: String, value: String) -> void:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(lbl)
	var val := Label.new()
	val.text = value
	val.add_theme_font_size_override("font_size", 13)
	val.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	row.add_child(val)
	vbox.add_child(row)
