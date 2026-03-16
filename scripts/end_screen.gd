extends CanvasLayer

var _victory: bool = true


func setup(victory: bool) -> void:
	_victory = victory


func _ready() -> void:
	layer = 25
	_build_ui()


func _build_ui() -> void:
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.04, 0.08, 0.97)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(300, 420)
	vbox.offset_left = -150
	vbox.offset_top = -210
	vbox.offset_right = 150
	vbox.offset_bottom = 210
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	if _victory:
		title.text = "RUN COMPLETE"
		title.add_theme_color_override("font_color", Color.GOLD)
	else:
		title.text = "SHIP DESTROYED"
		title.add_theme_color_override("font_color", Color.RED)
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Subtitle for victory
	if _victory:
		var sub := Label.new()
		sub.text = "Helion Sector Liberated!"
		sub.add_theme_font_size_override("font_size", 14)
		sub.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(sub)

	vbox.add_child(HSeparator.new())

	# Stats
	var xp_earned: int = GameState.session_kills * 5 + GameState.session_artifacts * 20
	var stats: Array = [
		["Enemies Destroyed", str(GameState.session_kills)],
		["Credits Earned", str(GameState.credits) + " cr"],
		["Artifacts Collected", str(GameState.session_artifacts)],
		["Captain XP Gained", "+" + str(xp_earned)],
		["Total Captain XP", str(GameState.captain_xp)],
	]
	for item in stats:
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = str(item[0])
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
		row.add_child(lbl)
		var val := Label.new()
		val.text = str(item[1])
		val.add_theme_font_size_override("font_size", 13)
		val.add_theme_color_override("font_color", Color.WHITE)
		row.add_child(val)
		vbox.add_child(row)

	vbox.add_child(HSeparator.new())

	# Score
	var total_lbl := Label.new()
	total_lbl.text = "SCORE: " + str(GameState.get_session_score())
	total_lbl.add_theme_font_size_override("font_size", 20)
	total_lbl.add_theme_color_override("font_color", Color.GOLD)
	total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(total_lbl)

	vbox.add_child(HSeparator.new())

	# TRY AGAIN button
	var try_btn := Button.new()
	try_btn.text = "TRY AGAIN"
	try_btn.custom_minimum_size.y = 48
	try_btn.add_theme_font_size_override("font_size", 18)
	var try_style := StyleBoxFlat.new()
	try_style.bg_color = Color(0.1, 0.4, 0.15, 0.9)
	try_style.corner_radius_top_left = 6
	try_style.corner_radius_top_right = 6
	try_style.corner_radius_bottom_left = 6
	try_style.corner_radius_bottom_right = 6
	try_btn.add_theme_stylebox_override("normal", try_style)
	try_btn.pressed.connect(_on_try_again)
	vbox.add_child(try_btn)

	# MAIN MENU button
	var menu_btn := Button.new()
	menu_btn.text = "MAIN MENU"
	menu_btn.custom_minimum_size.y = 44
	menu_btn.add_theme_font_size_override("font_size", 16)
	menu_btn.pressed.connect(_on_main_menu)
	vbox.add_child(menu_btn)


func _on_try_again() -> void:
	GameState.reset_run()
	SaveManager.delete_save()
	call_deferred("_change_to_game")


func _on_main_menu() -> void:
	GameState.reset_run()
	SaveManager.delete_save()
	call_deferred("_change_to_menu")


func _change_to_game() -> void:
	queue_free()
	get_tree().change_scene_to_file("res://scenes/space_world.tscn")


func _change_to_menu() -> void:
	queue_free()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
