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
	vbox.custom_minimum_size = Vector2(300, 400)
	vbox.offset_left = -150
	vbox.offset_top = -200
	vbox.offset_right = 150
	vbox.offset_bottom = 200
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "RUN COMPLETE" if _victory else "SHIP DESTROYED"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color.GOLD if _victory else Color.RED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var score_items := [
		["Credits", str(GameState.credits) + " cr", Color.WHITE],
		["Enemies Killed", str(GameState.session_kills) + " x 15 = " + str(GameState.session_kills * 15), Color(0.8, 0.4, 0.4)],
		["Artifacts Found", str(GameState.session_artifacts) + " x 150 = " + str(GameState.session_artifacts * 150), Color.GOLD],
	]
	for item in score_items:
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = str(item[0])
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 14)
		row.add_child(lbl)
		var val := Label.new()
		val.text = str(item[1])
		val.add_theme_font_size_override("font_size", 14)
		val.add_theme_color_override("font_color", item[2])
		row.add_child(val)
		vbox.add_child(row)

	vbox.add_child(HSeparator.new())

	var total_lbl := Label.new()
	total_lbl.text = "TOTAL SCORE: " + str(GameState.get_session_score())
	total_lbl.add_theme_font_size_override("font_size", 22)
	total_lbl.add_theme_color_override("font_color", Color.GOLD)
	total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(total_lbl)

	vbox.add_child(HSeparator.new())

	var coalition_lbl := Label.new()
	coalition_lbl.text = "Coalition standing: " + str(GameState.faction_rep.get("coalition", 50))
	coalition_lbl.add_theme_font_size_override("font_size", 13)
	coalition_lbl.add_theme_color_override("font_color", Color.CYAN)
	vbox.add_child(coalition_lbl)

	var new_run_btn := Button.new()
	new_run_btn.text = "New Run"
	new_run_btn.custom_minimum_size.y = 52
	new_run_btn.add_theme_font_size_override("font_size", 20)
	new_run_btn.pressed.connect(_on_new_run)
	vbox.add_child(new_run_btn)


func _on_new_run() -> void:
	GameState.reset_game()
	SaveManager.delete_save()
	call_deferred("_reload_scene")


func _reload_scene() -> void:
	queue_free()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
