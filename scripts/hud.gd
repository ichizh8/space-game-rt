extends CanvasLayer

var _joystick: Control
var _fire_button: Control
var _fire_pressed := false
var _fire_debounce: float = 0.0


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


func _ready() -> void:
	add_to_group("hud")
	layer = 10
	_build_ui()
	_connect_signals()
	_update_all()


func _build_ui() -> void:
	# Top bar container
	var top_bar := VBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 80
	top_bar.offset_left = 94   # clear COCKPIT button on left
	top_bar.offset_right = -10
	top_bar.offset_top = 6
	add_child(top_bar)

	# Hull bar
	var hull_container := HBoxContainer.new()
	top_bar.add_child(hull_container)
	var hull_label := Label.new()
	hull_label.text = "Hull"
	hull_label.add_theme_font_size_override("font_size", 14)
	hull_label.custom_minimum_size.x = 50
	hull_container.add_child(hull_label)
	_hull_bar = ProgressBar.new()
	_hull_bar.max_value = GameState.max_hull
	_hull_bar.value = GameState.hull
	_hull_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hull_bar.custom_minimum_size.y = 18
	var hull_style := StyleBoxFlat.new()
	hull_style.bg_color = Color(0.8, 0.1, 0.1)
	_hull_bar.add_theme_stylebox_override("fill", hull_style)
	hull_container.add_child(_hull_bar)

	# Fuel bar
	var fuel_container := HBoxContainer.new()
	top_bar.add_child(fuel_container)
	var fuel_label := Label.new()
	fuel_label.text = "Fuel"
	fuel_label.add_theme_font_size_override("font_size", 14)
	fuel_label.custom_minimum_size.x = 50
	fuel_container.add_child(fuel_label)
	_fuel_bar = ProgressBar.new()
	_fuel_bar.max_value = GameState.max_fuel
	_fuel_bar.value = GameState.fuel
	_fuel_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fuel_bar.custom_minimum_size.y = 18
	var fuel_style := StyleBoxFlat.new()
	fuel_style.bg_color = Color(0.1, 0.3, 0.9)
	_fuel_bar.add_theme_stylebox_override("fill", fuel_style)
	fuel_container.add_child(_fuel_bar)

	# Credits label
	_credits_label = Label.new()
	_credits_label.text = "Credits: " + str(GameState.credits)
	_credits_label.add_theme_font_size_override("font_size", 14)
	top_bar.add_child(_credits_label)

	# Resource display (top-right)
	_resource_label = Label.new()
	_resource_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_resource_label.offset_left = -140
	_resource_label.offset_top = 10
	_resource_label.offset_right = -10
	_resource_label.add_theme_font_size_override("font_size", 12)
	_resource_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_resource_label)

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


func _connect_signals() -> void:
	GameState.hull_changed.connect(_on_hull_changed)
	GameState.fuel_changed.connect(_on_fuel_changed)
	GameState.credits_changed.connect(_on_credits_changed)
	GameState.resources_changed.connect(_on_resources_changed)


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


func get_joystick_direction() -> Vector2:
	if is_instance_valid(_joystick) and _joystick.has_method("get_direction"):
		return _joystick.get_direction()
	return Vector2.ZERO





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
		_credits_label.text = "Credits: " + str(value)


func _on_resources_changed() -> void:
	if is_instance_valid(_resource_label):
		_resource_label.text = "Ore: %d\nCrystal: %d\nScrap: %d" % [
			GameState.resources.get("ore", 0),
			GameState.resources.get("crystal", 0),
			GameState.resources.get("scrap", 0)
		]


func _draw_fire_button() -> void:
	pass  # Drawn by fire_button.gd

func _on_cockpit_pressed() -> void:
	var cockpit_scene: PackedScene = load("res://scenes/cockpit.tscn")
	var cockpit: Node = cockpit_scene.instantiate()
	# Use call_deferred for WASM safety
	call_deferred("_add_cockpit", cockpit)


func _add_cockpit(cockpit: Node) -> void:
	get_tree().current_scene.add_child(cockpit)



