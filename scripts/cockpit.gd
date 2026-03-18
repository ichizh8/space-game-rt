extends CanvasLayer

var _tab_container: TabContainer
var _captain_tab: ScrollContainer
var _bridge_tab: ScrollContainer
var _quests_tab: ScrollContainer
var _crafting_tab: ScrollContainer
var _map_tab: ScrollContainer
var _inventory_tab: ScrollContainer
var initial_tab: int = -1


class MapControl extends Control:
	const MAP_SCALE := 0.036
	const FOG_RADIUS := 18.0
	const PLANET_RADIUS := 5.0
	const GRID_WORLD := 1000.0

	var _player_pos: Vector2 = Vector2.ZERO
	var _player_rot: float = 0.0
	var _poll_timer: float = 0.0
	var zoom: float = 1.0
	var _clear_btn: Button = null
	var _zoom_label: Label = null
	var _time: float = 0.0

	func _process(delta: float) -> void:
		_poll_timer += delta
		_time += delta
		if _poll_timer >= 0.25:
			_poll_timer = 0.0
			var players := get_tree().get_nodes_in_group("player")
			if players.size() > 0 and is_instance_valid(players[0]):
				_player_pos = (players[0] as Node2D).global_position
				_player_rot = (players[0] as Node2D).rotation
			queue_redraw()

	func zoom_in() -> void:
		zoom = minf(zoom + 0.25, 4.0)
		if is_instance_valid(_zoom_label):
			_zoom_label.text = "%.1fx" % zoom
		queue_redraw()

	func zoom_out() -> void:
		zoom = maxf(zoom - 0.25, 0.5)
		if is_instance_valid(_zoom_label):
			_zoom_label.text = "%.1fx" % zoom
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_set_waypoint_from_tap(mb.position)
				accept_event()
		elif event is InputEventScreenTouch:
			var st := event as InputEventScreenTouch
			if st.pressed:
				_set_waypoint_from_tap(st.position)
				accept_event()

	func _set_waypoint_from_tap(local_pos: Vector2) -> void:
		var center := size / 2.0
		var effective_scale: float = MAP_SCALE * zoom
		var world_pos: Vector2 = _player_pos + (local_pos - center) / effective_scale
		GameState.map_waypoint = world_pos
		if is_instance_valid(_clear_btn):
			_clear_btn.visible = true
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var center := size / 2.0
		var effective_scale: float = MAP_SCALE * zoom

		# Background
		draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.04, 0.08))

		# Grid
		var grid_px := GRID_WORLD * effective_scale
		var ox := fmod(_player_pos.x * effective_scale, grid_px)
		var oy := fmod(_player_pos.y * effective_scale, grid_px)
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

		# Draw stars from scene
		for star in get_tree().get_nodes_in_group("stars"):
			if not is_instance_valid(star):
				continue
			var world_pos: Vector2 = (star as Node2D).global_position
			var mp: Vector2 = center + (world_pos - _player_pos) * effective_scale
			if mp.x < -30.0 or mp.x > w + 30.0 or mp.y < -30.0 or mp.y > h + 30.0:
				continue
			var sr: float = max(5.0, float(star.get("star_radius") if star.get("star_radius") != null else 8.0) * effective_scale * 0.4)
			draw_circle(mp, sr * 1.8, Color(1.0, 0.55, 0.0, 0.12))
			draw_circle(mp, sr, Color(1.0, 0.92, 0.4, 0.95))
			draw_circle(mp, sr * 0.55, Color(1.0, 1.0, 0.9, 0.7))
			var sname2: String = str(star.get("star_name") if star.get("star_name") != null else "")
			if sname2 != "":
				draw_string(ThemeDB.fallback_font, mp + Vector2(sr + 4.0, 4.0), sname2,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.88, 0.5, 0.85))

		# Draw all planets from scene
		for planet in get_tree().get_nodes_in_group("planets"):
			if not is_instance_valid(planet):
				continue
			var world_pos: Vector2 = (planet as Node2D).global_position
			var mp: Vector2 = center + (world_pos - _player_pos) * effective_scale
			if mp.x < -20.0 or mp.x > w + 20.0 or mp.y < -20.0 or mp.y > h + 20.0:
				continue
			var pcol: Color = Color(0.4, 0.7, 1.0)
			if planet.get("planet_color") != null:
				pcol = planet.get("planet_color") as Color
			draw_circle(mp, PLANET_RADIUS, pcol)
			draw_arc(mp, PLANET_RADIUS + 2.5, 0.0, TAU, 16, Color(pcol.r, pcol.g, pcol.b, 0.4), 1.0)
			var pname: String = ""
			if planet.get("planet_name") != null:
				pname = str(planet.get("planet_name"))
			if pname != "":
				draw_string(ThemeDB.fallback_font, mp + Vector2(8, 4), pname,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.85, 0.9, 0.9))

		# Draw all stations from scene
		for station in get_tree().get_nodes_in_group("stations"):
			if not is_instance_valid(station):
				continue
			var world_pos: Vector2 = (station as Node2D).global_position
			var mp: Vector2 = center + (world_pos - _player_pos) * effective_scale
			if mp.x < -20.0 or mp.x > w + 20.0 or mp.y < -20.0 or mp.y > h + 20.0:
				continue
			draw_rect(Rect2(mp - Vector2(4, 4), Vector2(8, 8)), Color(0.9, 0.8, 0.3))
			var sname: String = ""
			if station.get("station_name") != null:
				sname = str(station.get("station_name"))
			if sname != "":
				draw_string(ThemeDB.fallback_font, mp + Vector2(8, 4), sname,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.9, 0.85, 0.5, 0.9))

		# Draw warp gates
		for gate in get_tree().get_nodes_in_group("warp_gates"):
			if not is_instance_valid(gate):
				continue
			var world_pos: Vector2 = (gate as Node2D).global_position
			var mp: Vector2 = center + (world_pos - _player_pos) * effective_scale
			if mp.x < -20.0 or mp.x > w + 20.0 or mp.y < -20.0 or mp.y > h + 20.0:
				continue
			draw_arc(mp, 6.0, 0.0, TAU, 8, Color(0.4, 0.9, 1.0, 0.9), 2.0)
			var gname: String = ""
			if gate.get("gate_name") != null:
				gname = str(gate.get("gate_name"))
			if gname != "":
				draw_string(ThemeDB.fallback_font, mp + Vector2(8, 4), gname,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.4, 0.9, 1.0, 0.8))

		# Quest markers — turn-in locations
		for q in GameState.active_quests:
			var source_id: String = q.get("source_id", "")
			if source_id == "":
				continue
			var target_pos := Vector2(1e9, 1e9)
			for planet in get_tree().get_nodes_in_group("planets"):
				if not is_instance_valid(planet):
					continue
				if str(planet.get("planet_id")) == source_id:
					target_pos = (planet as Node2D).global_position
					break
			if target_pos.x > 1e8:
				for station in get_tree().get_nodes_in_group("stations"):
					if not is_instance_valid(station):
						continue
					if str(station.get("station_id")) == source_id:
						target_pos = (station as Node2D).global_position
						break
			if target_pos.x > 1e8:
				continue
			var qmp: Vector2 = center + (target_pos - _player_pos) * effective_scale
			if qmp.x < 0.0 or qmp.x > w or qmp.y < 0.0 or qmp.y > h:
				continue
			var is_tracked: bool = (GameState.tracked_quest_id == q.get("id", ""))
			var qcol: Color = Color(1.0, 0.9, 0.0, 0.95) if not is_tracked else Color(0.3, 1.0, 0.4, 1.0)
			draw_circle(qmp + Vector2(0.0, -10.0), 5.0, qcol)
			draw_string(ThemeDB.fallback_font, qmp + Vector2(-3.0, -6.0), "!",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.05, 0.05, 0.05))

		# Story act 2 target — signal planet
		if GameState.story_act == 2 or (GameState.story_act >= 2 and GameState.is_quest_active("story_act2")):
			for planet in get_tree().get_nodes_in_group("planets"):
				if not is_instance_valid(planet):
					continue
				if str(planet.get("planet_id")) == "story_signal_planet":
					var sp: Vector2 = (planet as Node2D).global_position
					var smp: Vector2 = center + (sp - _player_pos) * effective_scale
					if smp.x >= 0.0 and smp.x <= w and smp.y >= 0.0 and smp.y <= h:
						draw_circle(smp + Vector2(0.0, -10.0), 5.0, Color(1.0, 0.5, 0.0, 0.9))
						draw_string(ThemeDB.fallback_font, smp + Vector2(-3.0, -6.0), "!",
							HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.05, 0.05, 0.05))
					break

		# Story act 3 target — command ship
		if GameState.is_quest_active("story_act3"):
			var px = GameState.get_story_flag("command_ship_pos_x")
			var py_val = GameState.get_story_flag("command_ship_pos_y")
			if px != null and py_val != null:
				var cmd_pos := Vector2(float(px), float(py_val))
				var cmp: Vector2 = center + (cmd_pos - _player_pos) * effective_scale
				if cmp.x >= 0.0 and cmp.x <= w and cmp.y >= 0.0 and cmp.y <= h:
					draw_circle(cmp, 6.0, Color(1.0, 0.2, 0.2, 0.9))
					draw_string(ThemeDB.fallback_font, cmp + Vector2(8.0, 4.0), "CMD",
						HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.3, 0.3, 0.9))

		# Discovered zone map markers (purchased or proximity-found hunting zones)
		for zone_id in GameState.map_discovered_planets:
			var entry: Dictionary = GameState.map_discovered_planets[zone_id]
			# Only draw zones from hunting_zones_sector1 (they have color_h and no planet_color)
			# Skip stations/planets already drawn as scene nodes above
			var is_zone: bool = false
			for z in GameState.hunting_zones_sector1:
				if z.get("id", "") == zone_id:
					is_zone = true
					break
			if not is_zone:
				continue
			var zx: float = float(entry.get("pos_x", 0.0))
			var zy: float = float(entry.get("pos_y", 0.0))
			var zname: String = str(entry.get("name", ""))
			var zh: float = float(entry.get("color_h", 0.3))
			var world_pos2 := Vector2(zx, zy)
			var mp2: Vector2 = center + (world_pos2 - _player_pos) * effective_scale
			if mp2.x < -30.0 or mp2.x > w + 30.0 or mp2.y < -30.0 or mp2.y > h + 30.0:
				continue
			var zcol: Color = Color.from_hsv(zh, 0.7, 0.9, 0.9)
			# Diamond marker for hunting zones
			var d: float = 6.0
			draw_colored_polygon(PackedVector2Array([
				mp2 + Vector2(0, -d), mp2 + Vector2(d, 0),
				mp2 + Vector2(0, d),  mp2 + Vector2(-d, 0)
			]), zcol)
			draw_polyline(PackedVector2Array([
				mp2 + Vector2(0, -d), mp2 + Vector2(d, 0),
				mp2 + Vector2(0, d),  mp2 + Vector2(-d, 0),
				mp2 + Vector2(0, -d)
			]), Color(1.0, 1.0, 1.0, 0.4), 1.0)
			if zname != "":
				draw_string(ThemeDB.fallback_font, mp2 + Vector2(9, 4), zname,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(zcol.r, zcol.g, zcol.b, 0.95))

		# Nearby enemies (red dots, within 2000 world units)
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy):
				continue
			var epos: Vector2 = (enemy as Node2D).global_position
			if epos.distance_to(_player_pos) > 2000.0:
				continue
			var emp: Vector2 = center + (epos - _player_pos) * effective_scale
			if emp.x < 0.0 or emp.x > w or emp.y < 0.0 or emp.y > h:
				continue
			draw_circle(emp, 2.5, Color(1.0, 0.3, 0.3, 0.8))

		# Loot drops (small yellow dots)
		for loot in get_tree().get_nodes_in_group("loot_drops"):
			if not is_instance_valid(loot):
				continue
			var lpos: Vector2 = (loot as Node2D).global_position
			var lmp: Vector2 = center + (lpos - _player_pos) * effective_scale
			if lmp.x < 0.0 or lmp.x > w or lmp.y < 0.0 or lmp.y > h:
				continue
			draw_circle(lmp, 2.0, Color(1.0, 0.85, 0.2, 0.7))

		# Waypoint marker (pulsing orange X)
		if GameState.map_waypoint.x < 1e8:
			var wmp: Vector2 = center + (GameState.map_waypoint - _player_pos) * effective_scale
			if wmp.x >= -10.0 and wmp.x <= w + 10.0 and wmp.y >= -10.0 and wmp.y <= h + 10.0:
				var pulse: float = 0.6 + 0.4 * sin(_time * 3.0)
				var wcol := Color(1.0, 0.6, 0.1, pulse)
				var xs: float = 5.0
				draw_line(wmp + Vector2(-xs, -xs), wmp + Vector2(xs, xs), wcol, 2.0)
				draw_line(wmp + Vector2(xs, -xs), wmp + Vector2(-xs, xs), wcol, 2.0)

		# Player arrow (facing direction)
		var forward: Vector2 = Vector2.UP.rotated(_player_rot)
		var arrow_sz: float = 6.0
		var arrow_tip: Vector2 = center + forward * arrow_sz
		var arrow_left: Vector2 = center + forward.rotated(2.4) * (arrow_sz * 0.7)
		var arrow_right: Vector2 = center + forward.rotated(-2.4) * (arrow_sz * 0.7)
		draw_colored_polygon(PackedVector2Array([arrow_tip, arrow_left, arrow_right]), Color.CYAN)
		draw_arc(center, 7.0, 0.0, TAU, 16, Color(0.0, 1.0, 1.0, 0.4), 1.5)

		# Border
		draw_rect(Rect2(0, 0, w, h), Color(0.15, 0.35, 0.55), false, 1.5)

		# Coords
		var zoom_text: String = " (%.1fx)" % zoom if zoom != 1.0 else ""
		draw_string(ThemeDB.fallback_font, Vector2(6, h - 6),
			"%.0f, %.0f%s" % [_player_pos.x, _player_pos.y, zoom_text],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.4, 0.6, 0.8, 0.8))


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	GameState.xp_gained.connect(_on_xp_changed)
	GameState.perk_unlocked.connect(_on_perk_unlocked)
	get_tree().paused = true
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if is_instance_valid(hud) and hud.has_method("reset_fire"):
		hud.reset_fire()


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

	var menu_btn := Button.new()
	menu_btn.text = "MENU"
	menu_btn.add_theme_font_size_override("font_size", 12)
	menu_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	menu_btn.offset_left = 8
	menu_btn.offset_top = 12
	menu_btn.offset_right = 70
	menu_btn.offset_bottom = 50
	menu_btn.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	menu_btn.pressed.connect(_on_main_menu)
	panel.add_child(menu_btn)

	_tab_container = TabContainer.new()
	_tab_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tab_container.offset_top = 58
	_tab_container.offset_left = 8
	_tab_container.offset_right = -8
	_tab_container.offset_bottom = -8
	panel.add_child(_tab_container)

	_build_bridge_tab()
	_build_captain_tab()
	_build_quests_tab()
	_build_crafting_tab()
	_build_inventory_tab()
	_build_map_tab()

	if initial_tab >= 0 and initial_tab < _tab_container.get_tab_count():
		_tab_container.current_tab = initial_tab


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
	_add_stat_row(vbox, "Weapons", "T%d/T20" % GameState.weapon_level if GameState.weapon_level > 0 else "T0")
	_add_stat_row(vbox, "Engines", "T%d/T20" % GameState.speed_level if GameState.speed_level > 0 else "T0")
	_add_stat_row(vbox, "Hull Plating", "T%d/T20" % GameState.shield_level if GameState.shield_level > 0 else "T0")

	# Faction standing
	vbox.add_child(HSeparator.new())
	var sec4 := _make_section_label("FACTION STANDING")
	vbox.add_child(sec4)
	var faction_data := [
		["Coalition", GameState.faction_rep.get("coalition", 50), Color(0.3, 0.7, 1.0)],
		["Pirates", GameState.faction_rep.get("pirates", 0), Color(0.9, 0.3, 0.3)],
	]
	for fd in faction_data:
		var f_row := HBoxContainer.new()
		f_row.custom_minimum_size.y = 24
		vbox.add_child(f_row)
		var f_name := Label.new()
		f_name.text = str(fd[0])
		f_name.custom_minimum_size.x = 80
		f_name.add_theme_font_size_override("font_size", 13)
		f_row.add_child(f_name)
		var f_bar := ProgressBar.new()
		f_bar.max_value = 100
		f_bar.value = int(fd[1])
		f_bar.custom_minimum_size = Vector2(140, 16)
		f_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bar_style := StyleBoxFlat.new()
		bar_style.bg_color = fd[2]
		f_bar.add_theme_stylebox_override("fill", bar_style)
		f_row.add_child(f_bar)
		var f_val := Label.new()
		f_val.text = str(int(fd[1]))
		f_val.add_theme_font_size_override("font_size", 12)
		f_val.custom_minimum_size.x = 30
		f_row.add_child(f_val)

	# Note about roguelite
	vbox.add_child(HSeparator.new())
	var note := Label.new()
	note.text = "Ship upgrades & resources are lost on death.\nCaptain XP and perks are permanent."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vbox.add_child(note)

	# DEV: quick credits button
	vbox.add_child(HSeparator.new())
	var dev_lbl := Label.new()
	dev_lbl.text = "DEV"
	dev_lbl.add_theme_font_size_override("font_size", 10)
	dev_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	vbox.add_child(dev_lbl)
	var dev_btn := Button.new()
	dev_btn.text = "+10 000 credits"
	dev_btn.custom_minimum_size.y = 36
	dev_btn.add_theme_font_size_override("font_size", 12)
	dev_btn.pressed.connect(func():
		GameState.credits += 10000
		GameState.credits_changed.emit(GameState.credits)
		call_deferred("_refresh_bridge"))
	vbox.add_child(dev_btn)


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


func _build_quests_tab() -> void:
	_quests_tab = ScrollContainer.new()
	_quests_tab.name = "Quests"
	_tab_container.add_child(_quests_tab)
	_refresh_quests()


func _refresh_quests() -> void:
	for c in _quests_tab.get_children():
		c.queue_free()
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size.x = 330
	vbox.add_theme_constant_override("separation", 6)
	_quests_tab.add_child(vbox)

	# Section 1: Active Quests
	var sec1 := _make_section_label("ACTIVE QUESTS")
	vbox.add_child(sec1)

	if GameState.active_quests.is_empty():
		var none := Label.new()
		none.text = "No active quests. Accept quests at planets and stations."
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.add_theme_font_size_override("font_size", 13)
		none.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		vbox.add_child(none)
	else:
		for q in GameState.active_quests:
			var card := PanelContainer.new()
			var cstyle := StyleBoxFlat.new()
			cstyle.bg_color = Color(0.08, 0.1, 0.18, 0.9)
			cstyle.set_border_width_all(1)
			cstyle.border_color = Color(0.5, 0.5, 0.2)
			cstyle.content_margin_left = 8
			cstyle.content_margin_right = 8
			cstyle.content_margin_top = 6
			cstyle.content_margin_bottom = 6
			card.add_theme_stylebox_override("panel", cstyle)
			vbox.add_child(card)

			var row := HBoxContainer.new()
			card.add_child(row)

			var info := VBoxContainer.new()
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(info)

			var title_lbl := Label.new()
			title_lbl.text = q.get("title", "Quest")
			title_lbl.add_theme_font_size_override("font_size", 14)
			title_lbl.add_theme_color_override("font_color", Color.YELLOW)
			info.add_child(title_lbl)

			var desc_lbl := Label.new()
			desc_lbl.text = q.get("description", "")
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc_lbl.add_theme_font_size_override("font_size", 11)
			desc_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
			info.add_child(desc_lbl)

			var prog_lbl := Label.new()
			var qtype: String = q.get("type", "")
			match qtype:
				"destroy":
					prog_lbl.text = "%d / %d enemies killed" % [q.get("progress", 0), q.get("required", 0)]
				"gather":
					var res_name: String = q.get("resource", "")
					prog_lbl.text = "%d / %d %s" % [GameState.resources.get(res_name, 0), q.get("required", 0), res_name]
				"story":
					var qid: String = q.get("id", "")
					if qid == "story_act1":
						prog_lbl.text = "Travel 1500 units from origin"
					elif qid == "story_act3":
						var killed: int = 0
						var total: int = 0
						var v = GameState.get_story_flag("cmd_killed")
						if v != null:
							killed = int(v)
						v = GameState.get_story_flag("cmd_total")
						if v != null:
							total = int(v)
						if total > 0:
							prog_lbl.text = "%d / %d hostiles destroyed" % [killed, total]
						else:
							prog_lbl.text = "Navigate to the marked location"
					else:
						prog_lbl.text = "In progress..."
				_:
					prog_lbl.text = ""
			prog_lbl.add_theme_font_size_override("font_size", 12)
			prog_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
			info.add_child(prog_lbl)

			var qid_bind: String = q.get("id", "")
			var is_tracked: bool = GameState.tracked_quest_id == qid_bind
			if is_tracked:
				cstyle.border_color = Color(0.3, 1.0, 0.4)
				card.add_theme_stylebox_override("panel", cstyle)

			var track_btn := Button.new()
			track_btn.text = "NAV" if not is_tracked else "NAV"
			track_btn.custom_minimum_size = Vector2(42, 36)
			track_btn.add_theme_font_size_override("font_size", 11)
			var track_style := StyleBoxFlat.new()
			track_style.bg_color = Color(0.1, 0.4, 0.15) if not is_tracked else Color(0.15, 0.6, 0.2)
			track_style.corner_radius_top_left = 3
			track_style.corner_radius_top_right = 3
			track_style.corner_radius_bottom_left = 3
			track_style.corner_radius_bottom_right = 3
			track_btn.add_theme_stylebox_override("normal", track_style)
			track_btn.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5) if not is_tracked else Color.WHITE)
			track_btn.pressed.connect(func():
				if GameState.tracked_quest_id == qid_bind:
					GameState.tracked_quest_id = ""
				else:
					GameState.tracked_quest_id = qid_bind
				_refresh_quests())
			row.add_child(track_btn)

			var abandon_btn := Button.new()
			abandon_btn.text = "X"
			abandon_btn.custom_minimum_size = Vector2(36, 36)
			abandon_btn.add_theme_font_size_override("font_size", 14)
			abandon_btn.pressed.connect(func():
				if GameState.tracked_quest_id == qid_bind:
					GameState.tracked_quest_id = ""
				GameState.abandon_quest(qid_bind)
				_refresh_quests())
			row.add_child(abandon_btn)

	# Section 2: Storyline
	vbox.add_child(HSeparator.new())
	var sec2 := _make_section_label("STORYLINE")
	vbox.add_child(sec2)

	var acts := [
		["Act 1: Investigate distress signal", "story_act1", 1],
		["Act 2: Locate command ship", "story_act2", 2],
		["Act 3: Destroy command ship", "story_act3", 3],
	]
	for act_info in acts:
		var act_row := HBoxContainer.new()
		act_row.custom_minimum_size.y = 32
		vbox.add_child(act_row)
		var dot := Label.new()
		var act_label := Label.new()
		act_label.text = str(act_info[0])
		act_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		act_label.add_theme_font_size_override("font_size", 13)
		var act_id: String = str(act_info[1])
		var act_num: int = int(act_info[2])
		var is_active_act: bool = false
		if GameState.is_quest_completed(act_id):
			dot.text = "  "
			dot.add_theme_color_override("font_color", Color.GREEN)
			act_label.add_theme_color_override("font_color", Color.GREEN)
		elif GameState.story_act == act_num and GameState.is_quest_active(act_id):
			dot.text = "  "
			dot.add_theme_color_override("font_color", Color.YELLOW)
			act_label.add_theme_color_override("font_color", Color.YELLOW)
			is_active_act = true
		else:
			dot.text = "  "
			dot.add_theme_color_override("font_color", Color(0.3, 0.3, 0.4))
			act_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.4))
		dot.add_theme_font_size_override("font_size", 13)
		act_row.add_child(dot)
		act_row.add_child(act_label)
		# NAV button for active story acts
		if is_active_act:
			var is_tracked: bool = GameState.tracked_quest_id == act_id
			var nav_btn := Button.new()
			nav_btn.text = "NAV"
			nav_btn.custom_minimum_size = Vector2(42, 28)
			nav_btn.add_theme_font_size_override("font_size", 11)
			var nav_style := StyleBoxFlat.new()
			nav_style.bg_color = Color(0.35, 0.2, 0.0) if not is_tracked else Color(0.55, 0.35, 0.0)
			nav_style.corner_radius_top_left = 3
			nav_style.corner_radius_top_right = 3
			nav_style.corner_radius_bottom_left = 3
			nav_style.corner_radius_bottom_right = 3
			nav_btn.add_theme_stylebox_override("normal", nav_style)
			nav_btn.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2) if not is_tracked else Color.WHITE)
			var act_id_bind: String = act_id
			nav_btn.pressed.connect(func():
				if GameState.tracked_quest_id == act_id_bind:
					GameState.tracked_quest_id = ""
				else:
					GameState.tracked_quest_id = act_id_bind
				_refresh_quests())
			act_row.add_child(nav_btn)


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


func _build_inventory_tab() -> void:
	_inventory_tab = ScrollContainer.new()
	_inventory_tab.name = "Inventory"
	_tab_container.add_child(_inventory_tab)
	_refresh_inventory()


func _refresh_inventory() -> void:
	for c in _inventory_tab.get_children():
		c.queue_free()
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size.x = 330
	vbox.add_theme_constant_override("separation", 8)
	_inventory_tab.add_child(vbox)

	var header := _make_section_label("COLLECTED ARTIFACTS  (%d)" % GameState.artifacts_collected.size())
	vbox.add_child(header)

	if GameState.artifacts_collected.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "No artifacts found yet.\nExplore the sector to discover them."
		none_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none_lbl.add_theme_font_size_override("font_size", 13)
		none_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		vbox.add_child(none_lbl)
	else:
		for art_id in GameState.artifacts_collected:
			var data := WorldData.get_artifact_by_id(art_id)
			if data.is_empty():
				continue
			var card := PanelContainer.new()
			var cstyle := StyleBoxFlat.new()
			cstyle.bg_color = Color(0.08, 0.1, 0.16, 0.9)
			cstyle.set_border_width_all(1)
			cstyle.border_color = Color(0.6, 0.5, 0.1, 0.6)
			cstyle.content_margin_left = 10
			cstyle.content_margin_right = 10
			cstyle.content_margin_top = 8
			cstyle.content_margin_bottom = 8
			card.add_theme_stylebox_override("panel", cstyle)
			vbox.add_child(card)

			var inner := VBoxContainer.new()
			card.add_child(inner)

			var name_lbl := Label.new()
			name_lbl.text = "★  " + data.get("name", art_id)
			name_lbl.add_theme_font_size_override("font_size", 14)
			name_lbl.add_theme_color_override("font_color", Color.GOLD)
			inner.add_child(name_lbl)

			var desc_lbl := Label.new()
			desc_lbl.text = data.get("description", "")
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc_lbl.add_theme_font_size_override("font_size", 12)
			desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
			inner.add_child(desc_lbl)

			var bonus: Dictionary = data.get("bonus", {})
			if not bonus.is_empty():
				var bonus_parts: Array[String] = []
				for key in bonus:
					bonus_parts.append(key.replace("player_", "").replace("_bonus", "").capitalize() + " +" + str(bonus[key]))
				var bonus_lbl := Label.new()
				bonus_lbl.text = "  ".join(bonus_parts)
				bonus_lbl.add_theme_font_size_override("font_size", 11)
				bonus_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
				inner.add_child(bonus_lbl)


func _build_map_tab() -> void:
	_map_tab = ScrollContainer.new()
	_map_tab.name = "Map"
	_tab_container.add_child(_map_tab)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	_map_tab.add_child(vbox)

	# Sector info label
	var sector_lbl := Label.new()
	var sector_names: Array[String] = ["", "Helion System", "Karath System", "Skull System", "The Void"]
	var sec_idx: int = clampi(GameState.current_sector, 1, 4)
	sector_lbl.text = "Sector %d: %s" % [sec_idx, sector_names[sec_idx]]
	sector_lbl.add_theme_font_size_override("font_size", 13)
	sector_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	vbox.add_child(sector_lbl)

	# Biome indicator
	var biome_lbl := Label.new()
	var sg := get_tree().get_first_node_in_group("sector_generator") if get_tree() != null else null
	var biome_text: String = "MIXED"
	var biome_color: Color = Color(0.6, 0.6, 0.7)
	if is_instance_valid(sg) and sg.get("_current_biome") != null:
		var biome_id: int = int(sg.get("_current_biome"))
		var biome_names: Array[String] = ["MIXED", "ASTEROID BELT", "DEBRIS FIELD", "DEEP SPACE", "NEBULA"]
		var biome_colors: Array[Color] = [Color(0.6, 0.6, 0.7), Color(1.0, 0.7, 0.3), Color(0.5, 0.5, 0.55), Color(0.2, 0.3, 0.7), Color(0.7, 0.4, 0.9)]
		if biome_id >= 0 and biome_id < biome_names.size():
			biome_text = biome_names[biome_id]
			biome_color = biome_colors[biome_id]
	biome_lbl.text = "Biome: " + biome_text
	biome_lbl.add_theme_font_size_override("font_size", 11)
	biome_lbl.add_theme_color_override("font_color", biome_color)
	vbox.add_child(biome_lbl)

	# Zoom controls
	var zoom_row := HBoxContainer.new()
	zoom_row.add_theme_constant_override("separation", 8)
	vbox.add_child(zoom_row)

	var zoom_out_btn := Button.new()
	zoom_out_btn.text = "-"
	zoom_out_btn.custom_minimum_size = Vector2(36, 28)
	zoom_out_btn.add_theme_font_size_override("font_size", 16)
	zoom_row.add_child(zoom_out_btn)

	var zoom_label := Label.new()
	zoom_label.text = "1.0x"
	zoom_label.add_theme_font_size_override("font_size", 12)
	zoom_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	zoom_label.custom_minimum_size.x = 36
	zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zoom_row.add_child(zoom_label)

	var zoom_in_btn := Button.new()
	zoom_in_btn.text = "+"
	zoom_in_btn.custom_minimum_size = Vector2(36, 28)
	zoom_in_btn.add_theme_font_size_override("font_size", 16)
	zoom_row.add_child(zoom_in_btn)

	var zoom_spacer := Control.new()
	zoom_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zoom_row.add_child(zoom_spacer)

	# Map control
	var map_ctrl := MapControl.new()
	map_ctrl.custom_minimum_size = Vector2(0, 400)
	map_ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	map_ctrl._zoom_label = zoom_label
	vbox.add_child(map_ctrl)

	# Connect zoom buttons
	zoom_out_btn.pressed.connect(map_ctrl.zoom_out)
	zoom_in_btn.pressed.connect(map_ctrl.zoom_in)

	# Clear waypoint button
	var clear_wp_btn := Button.new()
	clear_wp_btn.text = "Clear Waypoint"
	clear_wp_btn.custom_minimum_size = Vector2(0, 30)
	clear_wp_btn.add_theme_font_size_override("font_size", 12)
	clear_wp_btn.visible = GameState.map_waypoint.x < 1e8
	var cwp_style := StyleBoxFlat.new()
	cwp_style.bg_color = Color(0.3, 0.18, 0.05, 0.9)
	cwp_style.corner_radius_top_left = 3
	cwp_style.corner_radius_top_right = 3
	cwp_style.corner_radius_bottom_left = 3
	cwp_style.corner_radius_bottom_right = 3
	clear_wp_btn.add_theme_stylebox_override("normal", cwp_style)
	clear_wp_btn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	clear_wp_btn.pressed.connect(func():
		GameState.map_waypoint = Vector2(1e9, 1e9)
		clear_wp_btn.visible = false
		map_ctrl.queue_redraw())
	vbox.add_child(clear_wp_btn)
	map_ctrl._clear_btn = clear_wp_btn

	# Legend panel
	var legend_panel := PanelContainer.new()
	var leg_style := StyleBoxFlat.new()
	leg_style.bg_color = Color(0.04, 0.06, 0.12, 0.9)
	leg_style.content_margin_left = 8
	leg_style.content_margin_right = 8
	leg_style.content_margin_top = 6
	leg_style.content_margin_bottom = 6
	legend_panel.add_theme_stylebox_override("panel", leg_style)
	vbox.add_child(legend_panel)

	var legend := Label.new()
	legend.text = "LEGEND\nCyan arrow = You   Blue dots = Planets   Yellow squares = Stations\nGold circle = Star (⚠ radiation damage nearby!)   Cyan rings = Warp Gates\nYellow ! = Quests   Colored diamonds = Zones\nRed dots = Enemies (nearby)   Yellow dots = Loot   Orange X = Waypoint"
	legend.add_theme_font_size_override("font_size", 10)
	legend.add_theme_color_override("font_color", Color(0.45, 0.55, 0.65))
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend_panel.add_child(legend)


func _on_craft(kind: String, cost: Dictionary, value: float) -> void:
	if not GameState.spend_resources(cost):
		return
	match kind:
		"repair":  GameState.heal(value)
		"fuel":    GameState.add_fuel(value)
		"credits": GameState.add_credits(int(value))
	_refresh_crafting()


func _on_perk_buy(perk_id: String) -> void:
	if GameState.unlock_perk(perk_id):
		_refresh_captain()


func _on_xp_changed(_total: int) -> void:
	# Defer to avoid WASM unsafe queue_free/add_child from signal callback
	if is_instance_valid(_captain_tab) and _tab_container.current_tab == 1:
		call_deferred("_refresh_captain")


func _on_perk_unlocked(_perk_id: String) -> void:
	pass  # handled in _on_perk_buy already


func _on_close() -> void:
	SaveManager.save_game()
	call_deferred("_do_close")

func _do_close() -> void:
	get_tree().paused = false
	queue_free()

func _on_main_menu() -> void:
	SaveManager.save_game()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


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
