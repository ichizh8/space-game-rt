extends CanvasLayer

var _joystick: Control
var _fire_button: Control
var _fire_pressed := false
var _fire_debounce: float = 0.0
var _throttle_slider: Control


# Action popup
var _action_button: Button
var _action_target: Node2D = null
var _action_type: String = ""

# Labels
var _hull_bar: ProgressBar
var _fuel_bar: ProgressBar
var _credits_label: Label
var _resource_label: Label
var _notification_label: Label
var _notification_timer: float = 0.0
var _last_action_type: String = ""
var _last_action_target: Node2D = null
var _zone_label: Label
var _zone_check_timer: float = 0.0
var _current_zone: int = 1


func _ready() -> void:
	add_to_group("hud")
	layer = 10
	_build_ui()
	_connect_signals()
	_update_all()


class MinimapControl extends Control:
	const SIZE_PX := 88.0
	const HALF := SIZE_PX / 2.0
	const SCALE := HALF / 1500.0  # 1500 world units fills half the map

	var _player_pos: Vector2 = Vector2.ZERO
	var _poll_timer: float = 0.0

	func _process(delta: float) -> void:
		_poll_timer += delta
		if _poll_timer >= 0.15:
			_poll_timer = 0.0
			var p := get_tree().get_first_node_in_group("player")
			if is_instance_valid(p):
				_player_pos = (p as Node2D).global_position
			queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				accept_event()
				if get_parent().has_method("_open_cockpit_to_map"):
					get_parent()._open_cockpit_to_map()
		elif event is InputEventScreenTouch:
			var st := event as InputEventScreenTouch
			if st.pressed:
				accept_event()
				if get_parent().has_method("_open_cockpit_to_map"):
					get_parent()._open_cockpit_to_map()

	func _draw() -> void:
		var c := Vector2(HALF, HALF)
		draw_rect(Rect2(0.0, 0.0, SIZE_PX, SIZE_PX), Color(0.02, 0.04, 0.08, 0.78))
		# Planets
		for planet in get_tree().get_nodes_in_group("planets"):
			if not is_instance_valid(planet):
				continue
			var mp: Vector2 = c + ((planet as Node2D).global_position - _player_pos) * SCALE
			if mp.x < 2.0 or mp.x > SIZE_PX - 2.0 or mp.y < 2.0 or mp.y > SIZE_PX - 2.0:
				continue
			var pcol := Color(0.4, 0.7, 1.0)
			if planet.get("planet_color") != null:
				pcol = planet.get("planet_color") as Color
			draw_circle(mp, 3.0, pcol)
		# Stations
		for station in get_tree().get_nodes_in_group("stations"):
			if not is_instance_valid(station):
				continue
			var mp: Vector2 = c + ((station as Node2D).global_position - _player_pos) * SCALE
			if mp.x < 2.0 or mp.x > SIZE_PX - 2.0 or mp.y < 2.0 or mp.y > SIZE_PX - 2.0:
				continue
			draw_rect(Rect2(mp - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), Color(0.9, 0.8, 0.3))
		# Warp gates
		for gate in get_tree().get_nodes_in_group("warp_gates"):
			if not is_instance_valid(gate):
				continue
			var mp: Vector2 = c + ((gate as Node2D).global_position - _player_pos) * SCALE
			if mp.x < 2.0 or mp.x > SIZE_PX - 2.0 or mp.y < 2.0 or mp.y > SIZE_PX - 2.0:
				continue
			draw_arc(mp, 3.5, 0.0, TAU, 6, Color(0.4, 0.9, 1.0, 0.9), 1.5)
		# Quest turn-in markers
		for q in GameState.active_quests:
			var source_id: String = q.get("source_id", "")
			if source_id == "":
				continue
			var target_pos := Vector2(1e9, 1e9)
			for planet in get_tree().get_nodes_in_group("planets"):
				if is_instance_valid(planet) and str(planet.get("planet_id")) == source_id:
					target_pos = (planet as Node2D).global_position
					break
			if target_pos.x > 1e8:
				for station in get_tree().get_nodes_in_group("stations"):
					if is_instance_valid(station) and str(station.get("station_id")) == source_id:
						target_pos = (station as Node2D).global_position
						break
			if target_pos.x > 1e8:
				continue
			var mp: Vector2 = c + (target_pos - _player_pos) * SCALE
			# If off-map, clamp to edge with arrow direction
			if mp.x < 2.0 or mp.x > SIZE_PX - 2.0 or mp.y < 2.0 or mp.y > SIZE_PX - 2.0:
				var dir: Vector2 = (mp - c).normalized()
				mp = c + dir * (HALF - 4.0)
			draw_string(ThemeDB.fallback_font, mp - Vector2(3.0, 0.0), "!",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.9, 0.0, 1.0))
		# Player dot
		draw_circle(c, 3.0, Color.CYAN)
		draw_arc(c, 5.5, 0.0, TAU, 12, Color(0.0, 1.0, 1.0, 0.35), 1.0)
		# Zone overlay (bottom-left of minimap)
		var dist_z: float = _player_pos.length()
		var zone: int = 1
		if dist_z >= 4200.0: zone = 4
		elif dist_z >= 2800.0: zone = 3
		elif dist_z >= 1500.0: zone = 2
		var zcol: Color
		match zone:
			1: zcol = Color(0.3, 1.0, 0.4, 0.85)
			2: zcol = Color(1.0, 0.9, 0.2, 0.85)
			3: zcol = Color(1.0, 0.55, 0.1, 0.85)
			_: zcol = Color(1.0, 0.2, 0.2, 0.85)
		draw_string(ThemeDB.fallback_font, Vector2(3.0, SIZE_PX - 4.0), "Z" + str(zone),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, zcol)
		# "MAP" tap hint
		draw_string(ThemeDB.fallback_font, Vector2(SIZE_PX - 30.0, 12.0), "MAP",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.4, 0.7, 0.9, 0.5))
		# Border
		draw_rect(Rect2(0.0, 0.0, SIZE_PX, SIZE_PX), Color(0.15, 0.35, 0.55, 0.85), false, 1.5)


class CompassControl extends Control:
	const ORBIT_RADIUS := 82.0   # px from ship screen center
	const HIDE_DISTANCE := 220.0  # world units — hide when closer than this
	const ARROW_HALF := 12.0

	var _poll_timer: float = 0.0
	var _show: bool = false
	var _direction: Vector2 = Vector2.UP
	var _quest_title: String = ""
	var _distance: float = 0.0
	var _is_story: bool = false
	var _wp_show: bool = false
	var _wp_direction: Vector2 = Vector2.UP
	var _wp_distance: float = 0.0

	func _process(delta: float) -> void:
		_poll_timer += delta
		if _poll_timer >= 0.2:
			_poll_timer = 0.0
			_update()
			queue_redraw()

	func _update() -> void:
		# Waypoint arrow
		_wp_show = false
		if GameState.map_waypoint.x < 1e8:
			var wp_player := get_tree().get_first_node_in_group("player")
			if is_instance_valid(wp_player):
				var wp_pp: Vector2 = (wp_player as Node2D).global_position
				var wp_d: float = wp_pp.distance_to(GameState.map_waypoint)
				if wp_d > 100.0:
					_wp_direction = (GameState.map_waypoint - wp_pp).normalized()
					_wp_distance = wp_d
					_wp_show = true
		var tracked_id := GameState.tracked_quest_id
		if tracked_id == "":
			_show = false
			return
		# Look in active_quests first
		var tracked_quest: Dictionary = {}
		for q in GameState.active_quests:
			if q.get("id") == tracked_id:
				tracked_quest = q
				break
		# Story quests may not be in active_quests under the same structure —
		# synthesize a minimal dict so we can still resolve their target
		if tracked_quest.is_empty():
			if tracked_id in ["story_act1", "story_act2", "story_act3"]:
				tracked_quest = {"id": tracked_id, "title": "Main Quest", "type": "story"}
			else:
				GameState.tracked_quest_id = ""
				_show = false
				return
		_quest_title = tracked_quest.get("title", "Quest")
		var player_node := get_tree().get_first_node_in_group("player")
		if not is_instance_valid(player_node):
			_show = false
			return
		var player_pos: Vector2 = (player_node as Node2D).global_position
		var target_pos := Vector2(1e9, 1e9)
		var source_id: String = tracked_quest.get("source_id", "")
		if source_id != "" and source_id != "world":
			for planet in get_tree().get_nodes_in_group("planets"):
				if is_instance_valid(planet) and str(planet.get("planet_id")) == source_id:
					target_pos = (planet as Node2D).global_position
					break
			if target_pos.x > 1e8:
				for station in get_tree().get_nodes_in_group("stations"):
					if is_instance_valid(station) and str(station.get("station_id")) == source_id:
						target_pos = (station as Node2D).global_position
						break
			# Fallback: check map_discovered_planets (e.g. Drifting Spoon not yet in range)
			if target_pos.x > 1e8 and GameState.map_discovered_planets.has(source_id):
				var entry: Dictionary = GameState.map_discovered_planets[source_id]
				target_pos = Vector2(float(entry.get("pos_x", 1e9)), float(entry.get("pos_y", 1e9)))
		elif tracked_id == "story_act3":
			var px = GameState.get_story_flag("command_ship_pos_x")
			var py_val = GameState.get_story_flag("command_ship_pos_y")
			if px != null and py_val != null:
				target_pos = Vector2(float(px), float(py_val))
		elif tracked_id == "story_act2":
			for planet in get_tree().get_nodes_in_group("planets"):
				if is_instance_valid(planet) and str(planet.get("planet_id")) == "story_signal_planet":
					target_pos = (planet as Node2D).global_position
					break
		if target_pos.x > 1e8:
			_show = false
			return
		_distance = player_pos.distance_to(target_pos)
		if _distance < HIDE_DISTANCE:
			_show = false
			return
		_direction = (target_pos - player_pos).normalized()
		_is_story = tracked_quest.get("type", "") == "story"
		_show = true

	func _draw() -> void:
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		var screen_center: Vector2 = vp_size / 2.0
		if _show:
			# Arrow orbits around ship screen center
			var arrow_center: Vector2 = screen_center + _direction * ORBIT_RADIUS
			var tip: Vector2 = arrow_center + _direction * ARROW_HALF
			var perp: Vector2 = _direction.rotated(PI / 2.0)
			var bl: Vector2 = arrow_center - _direction * (ARROW_HALF * 0.4) + perp * (ARROW_HALF * 0.55)
			var br: Vector2 = arrow_center - _direction * (ARROW_HALF * 0.4) - perp * (ARROW_HALF * 0.55)
			var acol: Color = Color(0.35, 1.0, 0.55, 0.92) if not _is_story else Color(1.0, 0.72, 0.2, 0.92)
			draw_polygon([tip, bl, br],
				[acol, Color(acol.r * 0.45, acol.g * 0.45, acol.b * 0.45, 0.8),
				 Color(acol.r * 0.45, acol.g * 0.45, acol.b * 0.45, 0.8)])
			# Text just beyond the tip
			var text_base: Vector2 = tip + _direction * 5.0
			var title_short := _quest_title if _quest_title.length() <= 13 else _quest_title.left(12) + "…"
			draw_string(ThemeDB.fallback_font, text_base,
				title_short, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(1.0, 0.9, 0.0, 0.9))
			var dist_text: String = ("%.1fk" % (_distance / 1000.0)) if _distance >= 1000.0 else ("%.0f" % _distance)
			draw_string(ThemeDB.fallback_font, text_base + _direction * 13.0,
				dist_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(0.6, 0.8, 0.65, 0.82))
		# Waypoint compass arrow (orange)
		if _wp_show:
			var wac: Vector2 = screen_center + _wp_direction * ORBIT_RADIUS
			var wtip: Vector2 = wac + _wp_direction * ARROW_HALF
			var wperp: Vector2 = _wp_direction.rotated(PI / 2.0)
			var wbl: Vector2 = wac - _wp_direction * (ARROW_HALF * 0.4) + wperp * (ARROW_HALF * 0.55)
			var wbr: Vector2 = wac - _wp_direction * (ARROW_HALF * 0.4) - wperp * (ARROW_HALF * 0.55)
			var wcol := Color(1.0, 0.6, 0.1, 0.9)
			draw_polygon([wtip, wbl, wbr],
				[wcol, Color(wcol.r * 0.45, wcol.g * 0.45, wcol.b * 0.45, 0.8),
				 Color(wcol.r * 0.45, wcol.g * 0.45, wcol.b * 0.45, 0.8)])
			var wtext: Vector2 = wtip + _wp_direction * 5.0
			draw_string(ThemeDB.fallback_font, wtext,
				"WPT", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(1.0, 0.6, 0.1, 0.9))
			var wdist_text: String = ("%.1fk" % (_wp_distance / 1000.0)) if _wp_distance >= 1000.0 else ("%.0f" % _wp_distance)
			draw_string(ThemeDB.fallback_font, wtext + _wp_direction * 13.0,
				wdist_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(0.8, 0.5, 0.2, 0.82))


func _build_ui() -> void:
	# Bottom-left stats panel (hull, fuel, credits, resources)
	var stats_bg := PanelContainer.new()
	stats_bg.anchor_left = 0.0
	stats_bg.anchor_right = 0.0
	stats_bg.anchor_top = 1.0
	stats_bg.anchor_bottom = 1.0
	stats_bg.offset_left = 6.0
	stats_bg.offset_right = 120.0
	stats_bg.offset_top = -100.0
	stats_bg.offset_bottom = -6.0
	var stats_style := StyleBoxFlat.new()
	stats_style.bg_color = Color(0.02, 0.04, 0.10, 0.78)
	stats_style.corner_radius_top_left = 4
	stats_style.corner_radius_top_right = 4
	stats_style.corner_radius_bottom_left = 4
	stats_style.corner_radius_bottom_right = 4
	stats_style.content_margin_left = 5
	stats_style.content_margin_right = 5
	stats_style.content_margin_top = 4
	stats_style.content_margin_bottom = 4
	stats_bg.add_theme_stylebox_override("panel", stats_style)
	add_child(stats_bg)

	var stats_vbox := VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 3)
	stats_bg.add_child(stats_vbox)

	# Hull bar row
	var hull_row := HBoxContainer.new()
	hull_row.add_theme_constant_override("separation", 3)
	stats_vbox.add_child(hull_row)
	var hull_lbl := Label.new()
	hull_lbl.text = "HP"
	hull_lbl.add_theme_font_size_override("font_size", 11)
	hull_lbl.custom_minimum_size.x = 18
	hull_lbl.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	hull_row.add_child(hull_lbl)
	_hull_bar = ProgressBar.new()
	_hull_bar.max_value = GameState.max_hull
	_hull_bar.value = GameState.hull
	_hull_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hull_bar.custom_minimum_size.y = 12
	_hull_bar.show_percentage = false
	var hull_style := StyleBoxFlat.new()
	hull_style.bg_color = Color(0.8, 0.1, 0.1)
	_hull_bar.add_theme_stylebox_override("fill", hull_style)
	hull_row.add_child(_hull_bar)

	# Fuel bar row
	var fuel_row := HBoxContainer.new()
	fuel_row.add_theme_constant_override("separation", 3)
	stats_vbox.add_child(fuel_row)
	var fuel_lbl := Label.new()
	fuel_lbl.text = "FU"
	fuel_lbl.add_theme_font_size_override("font_size", 11)
	fuel_lbl.custom_minimum_size.x = 18
	fuel_lbl.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
	fuel_row.add_child(fuel_lbl)
	_fuel_bar = ProgressBar.new()
	_fuel_bar.max_value = GameState.max_fuel
	_fuel_bar.value = GameState.fuel
	_fuel_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fuel_bar.custom_minimum_size.y = 12
	_fuel_bar.show_percentage = false
	var fuel_style := StyleBoxFlat.new()
	fuel_style.bg_color = Color(0.1, 0.3, 0.9)
	_fuel_bar.add_theme_stylebox_override("fill", fuel_style)
	fuel_row.add_child(_fuel_bar)

	# Credits
	_credits_label = Label.new()
	_credits_label.add_theme_font_size_override("font_size", 11)
	_credits_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.3))
	_credits_label.text = str(GameState.credits) + " cr"
	stats_vbox.add_child(_credits_label)

	# Resources compact
	_resource_label = Label.new()
	_resource_label.add_theme_font_size_override("font_size", 11)
	_resource_label.add_theme_color_override("font_color", Color(0.65, 0.75, 0.65))
	stats_vbox.add_child(_resource_label)

	# Virtual joystick (center-bottom)
	_joystick = Control.new()
	_joystick.set_script(load("res://scripts/virtual_joystick.gd"))
	_joystick.anchor_left = 0.5
	_joystick.anchor_right = 0.5
	_joystick.anchor_top = 1.0
	_joystick.anchor_bottom = 1.0
	_joystick.offset_left = -75
	_joystick.offset_right = 75
	_joystick.offset_top = -210
	_joystick.offset_bottom = -60
	add_child(_joystick)

	# Fire button (bottom-right) — styled Button
	var fire_btn := Control.new()
	fire_btn.set_script(load("res://scripts/fire_button.gd"))
	fire_btn.anchor_left = 1.0
	fire_btn.anchor_right = 1.0
	fire_btn.anchor_top = 1.0
	fire_btn.anchor_bottom = 1.0
	fire_btn.offset_left = -110
	fire_btn.offset_right = -20
	fire_btn.offset_top = -110
	fire_btn.offset_bottom = -20
	fire_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fire_button = fire_btn
	add_child(_fire_button)

	# Throttle slider removed — joystick Y axis controls thrust

	# Cockpit button (top-left)
	var cockpit_btn := Button.new()
	cockpit_btn.text = "COCKPIT"
	cockpit_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	cockpit_btn.offset_left = 6
	cockpit_btn.offset_top = 6
	cockpit_btn.offset_right = 88
	cockpit_btn.offset_bottom = 34
	cockpit_btn.add_theme_font_size_override("font_size", 12)
	var cockpit_style := StyleBoxFlat.new()
	cockpit_style.bg_color = Color(0.05, 0.15, 0.35, 0.88)
	cockpit_style.corner_radius_top_left = 4
	cockpit_style.corner_radius_top_right = 4
	cockpit_style.corner_radius_bottom_left = 4
	cockpit_style.corner_radius_bottom_right = 4
	cockpit_btn.add_theme_stylebox_override("normal", cockpit_style)
	cockpit_btn.add_theme_stylebox_override("pressed", cockpit_style)
	cockpit_btn.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	cockpit_btn.pressed.connect(_on_cockpit_pressed)
	add_child(cockpit_btn)

	# Save button (top-left, next to cockpit)
	var save_btn := Button.new()
	save_btn.text = "SAVE"
	save_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	save_btn.offset_left = 94
	save_btn.offset_top = 6
	save_btn.offset_right = 152
	save_btn.offset_bottom = 34
	save_btn.add_theme_font_size_override("font_size", 12)
	var save_style := StyleBoxFlat.new()
	save_style.bg_color = Color(0.05, 0.28, 0.12, 0.88)
	save_style.corner_radius_top_left = 4
	save_style.corner_radius_top_right = 4
	save_style.corner_radius_bottom_left = 4
	save_style.corner_radius_bottom_right = 4
	save_btn.add_theme_stylebox_override("normal", save_style)
	save_btn.add_theme_stylebox_override("pressed", save_style)
	save_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	save_btn.pressed.connect(_on_save_pressed.bind(save_btn))
	add_child(save_btn)

	# Action button (center of screen, above controls)
	_action_button = Button.new()
	_action_button.set_anchors_preset(Control.PRESET_CENTER)
	_action_button.offset_left = -80
	_action_button.offset_right = 80
	_action_button.offset_top = 60
	_action_button.offset_bottom = 110
	_action_button.add_theme_font_size_override("font_size", 18)
	_action_button.modulate.a = 0.0
	_action_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_button.pressed.connect(_on_action_pressed)
	add_child(_action_button)

	# Notification label (center)
	_notification_label = Label.new()
	_notification_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_notification_label.offset_top = 100
	_notification_label.offset_left = -150
	_notification_label.offset_right = 150
	_notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notification_label.add_theme_font_size_override("font_size", 16)
	_notification_label.add_theme_color_override("font_color", Color.YELLOW)
	_notification_label.visible = false
	add_child(_notification_label)

	# Minimap (top-right)
	var minimap := MinimapControl.new()
	minimap.custom_minimum_size = Vector2(88.0, 88.0)
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.anchor_top = 0.0
	minimap.anchor_bottom = 0.0
	minimap.offset_left = -96.0
	minimap.offset_right = -8.0
	minimap.offset_top = 8.0
	minimap.offset_bottom = 96.0
	minimap.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(minimap)

	# Quest compass — fullscreen overlay, draws arrow orbiting ship center
	var compass := CompassControl.new()
	compass.set_anchors_preset(Control.PRESET_FULL_RECT)
	compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(compass)

	# Zone label is now drawn inside the MinimapControl overlay
	_zone_label = null


func _connect_signals() -> void:
	GameState.hull_changed.connect(_on_hull_changed)
	GameState.fuel_changed.connect(_on_fuel_changed)
	GameState.credits_changed.connect(_on_credits_changed)
	GameState.resources_changed.connect(_on_resources_changed)
	GameState.ingredient_dropped.connect(_on_ingredient_dropped)


func _input(event: InputEvent) -> void:
	var vp_size := get_viewport().get_visible_rect().size
	var tap_pos := Vector2(-1, -1)
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		tap_pos = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			tap_pos = mb.position
	if tap_pos.x >= 0 and _fire_debounce <= 0.0:
		# Fire zone: bottom-right 120x120 px
		if tap_pos.x > vp_size.x - 120 and tap_pos.y > vp_size.y - 120:
			_fire_pressed = not _fire_pressed
			_fire_debounce = 0.3
			if is_instance_valid(_fire_button) and _fire_button.has_method("set_active"):
				_fire_button.set_active(_fire_pressed)
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _fire_debounce > 0.0:
		_fire_debounce -= delta
	_check_nearby_objects()

	if _notification_timer > 0:
		_notification_timer -= delta
		if _notification_timer <= 0:
			call_deferred("_hide_notification")

	# Continuously update fire state on ship
	var ship := get_tree().get_first_node_in_group("player")
	if is_instance_valid(ship) and ship.has_method("set_firing"):
		ship.set_firing(_fire_pressed)

	# Zone label update (every 2s)
	_zone_check_timer += delta
	if _zone_check_timer >= 2.0:
		_zone_check_timer = 0.0
		_update_zone_label()


func get_joystick_direction() -> Vector2:
	if is_instance_valid(_joystick) and _joystick.has_method("get_direction"):
		return _joystick.get_direction()
	return Vector2.ZERO


func get_throttle() -> float:
	if is_instance_valid(_throttle_slider) and _throttle_slider.has_method("get_throttle"):
		return _throttle_slider.get_throttle()
	return 0.0





func _check_nearby_objects() -> void:
	var ship := get_tree().get_first_node_in_group("player")
	if not is_instance_valid(ship):
		call_deferred("_hide_action")
		return

	var ship_pos: Vector2 = ship.global_position
	var closest_dist := 999999.0
	var closest_node: Node2D = null
	var closest_type := ""

	# Check asteroids
	for asteroid in get_tree().get_nodes_in_group("asteroids"):
		if not is_instance_valid(asteroid):
			continue
		if asteroid.get("is_being_mined") == true:
			continue
		var dist: float = ship_pos.distance_to(asteroid.global_position)
		if dist < 80.0 and dist < closest_dist:
			closest_dist = dist
			closest_node = asteroid
			closest_type = "Mine"

	# Check planets
	for planet in get_tree().get_nodes_in_group("planets"):
		if not is_instance_valid(planet):
			continue
		var dist: float = ship_pos.distance_to(planet.global_position)
		var planet_range := 120.0 if GameState.has_perk("keen_eye") else 80.0
		if dist < planet_range and dist < closest_dist:
			closest_dist = dist
			closest_node = planet
			closest_type = "Land"

	# Check stations
	for station in get_tree().get_nodes_in_group("stations"):
		if not is_instance_valid(station):
			continue
		var dist: float = ship_pos.distance_to(station.global_position)
		if dist < 80.0 and dist < closest_dist:
			closest_dist = dist
			closest_node = station
			closest_type = "Dock"

	# Check warp gates
	for gate in get_tree().get_nodes_in_group("warp_gates"):
		if not is_instance_valid(gate):
			continue
		var dist: float = ship_pos.distance_to(gate.global_position)
		if dist < 100.0 and dist < closest_dist:
			closest_dist = dist
			closest_node = gate
			closest_type = "Warp"

	# Check derelicts
	for derelict in get_tree().get_nodes_in_group("derelicts"):
		if not is_instance_valid(derelict):
			continue
		if derelict.has_method("can_scavenge") and not derelict.can_scavenge():
			continue
		var dist: float = ship_pos.distance_to(derelict.global_position)
		if dist < 80.0 and dist < closest_dist:
			closest_dist = dist
			closest_node = derelict
			closest_type = "Scavenge"

	if is_instance_valid(closest_node):
		if closest_type != _last_action_type or closest_node != _last_action_target:
			_last_action_type = closest_type
			_last_action_target = closest_node
			call_deferred("_show_action", closest_type, closest_node)
	else:
		if _last_action_type != "" or is_instance_valid(_last_action_target):
			_last_action_type = ""
			_last_action_target = null
			call_deferred("_hide_action")


func _hide_notification() -> void:
	_notification_label.visible = false

func _show_action(action_type: String, target: Node2D) -> void:
	_action_type = action_type
	_action_target = target
	_action_button.text = action_type
	_action_button.modulate.a = 1.0
	_action_button.mouse_filter = Control.MOUSE_FILTER_STOP


func _hide_action() -> void:
	_action_button.modulate.a = 0.0
	_action_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_target = null
	_action_type = ""


func _on_action_pressed() -> void:
	if not is_instance_valid(_action_target):
		return
	# Reset joystick to prevent stuck touch state
	if is_instance_valid(_joystick) and _joystick.has_method("_reset"):
		_joystick._reset()
	match _action_type:
		"Mine":
			if _action_target.has_method("mine"):
				_action_target.mine()
				call_deferred("_hide_action")
		"Land":
			if _action_target.has_method("land"):
				_action_target.land()
				call_deferred("_hide_action")
		"Dock":
			if _action_target.has_method("dock"):
				_action_target.dock()
				call_deferred("_hide_action")
		"Warp":
			if _action_target.has_method("activate"):
				_action_target.activate()
				call_deferred("_hide_action")
		"Scavenge":
			if _action_target.has_method("scavenge"):
				_action_target.scavenge()
				call_deferred("_hide_action")


func show_notification(text: String, duration: float = 3.0) -> void:
	_notification_label.text = text
	_notification_label.visible = true
	_notification_timer = duration


func _update_all() -> void:
	_on_hull_changed(GameState.hull)
	_on_fuel_changed(GameState.fuel)
	_on_credits_changed(GameState.credits)
	_on_resources_changed()


func _on_hull_changed(value: float) -> void:
	if is_instance_valid(_hull_bar):
		_hull_bar.value = value
	if value <= 0 and _fire_pressed:
		_fire_pressed = false
		if is_instance_valid(_fire_button) and _fire_button.has_method("set_active"):
			_fire_button.set_active(false)


func _on_fuel_changed(value: float) -> void:
	if is_instance_valid(_fuel_bar):
		_fuel_bar.value = value


func _on_credits_changed(value: int) -> void:
	if is_instance_valid(_credits_label):
		_credits_label.text = str(value) + " cr"


func _on_resources_changed() -> void:
	if is_instance_valid(_resource_label):
		_resource_label.text = "O:%d C:%d S:%d" % [
			GameState.resources.get("ore", 0),
			GameState.resources.get("crystal", 0),
			GameState.resources.get("scrap", 0)
		]


func _update_zone_label() -> void:
	pass  # Zone is now shown inside MinimapControl overlay


func reset_fire() -> void:
	_fire_pressed = false
	_fire_debounce = 0.0
	if is_instance_valid(_fire_button) and _fire_button.has_method("set_active"):
		_fire_button.set_active(false)
	if is_instance_valid(_joystick) and _joystick.has_method("_reset"):
		_joystick._reset()


func _draw_fire_button() -> void:
	pass  # Drawn by fire_button.gd

func _on_ingredient_dropped(ing_name: String) -> void:
	var drop_lbl := Label.new()
	drop_lbl.text = "+ " + ing_name
	drop_lbl.add_theme_font_size_override("font_size", 14)
	drop_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	drop_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	drop_lbl.offset_top = 60
	drop_lbl.offset_left = -100
	drop_lbl.offset_right = 100
	drop_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(drop_lbl)
	var tw := create_tween()
	tw.tween_property(drop_lbl, "offset_top", 30.0, 2.0)
	tw.parallel().tween_property(drop_lbl, "modulate:a", 0.0, 2.0)
	tw.tween_callback(drop_lbl.queue_free)


func _on_save_pressed(btn: Button) -> void:
	SaveManager.save_game()
	btn.text = "SAVED ✓"
	btn.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3))
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(btn):
		btn.text = "SAVE"
		btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))


func _on_cockpit_pressed() -> void:
	var cockpit_scene: PackedScene = load("res://scenes/cockpit.tscn")
	var cockpit: Node = cockpit_scene.instantiate()
	# Use call_deferred for WASM safety
	call_deferred("_add_cockpit", cockpit)


func _open_cockpit_to_map() -> void:
	var cockpit_scene: PackedScene = load("res://scenes/cockpit.tscn")
	var cockpit: Node = cockpit_scene.instantiate()
	cockpit.initial_tab = 5  # Map tab index
	call_deferred("_add_cockpit", cockpit)


func _add_cockpit(cockpit: Node) -> void:
	get_tree().current_scene.add_child(cockpit)



