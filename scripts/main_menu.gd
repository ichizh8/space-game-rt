extends Control


func _ready() -> void:
	# Remove static nodes from .tscn; we build everything in code
	for child in get_children():
		if child.name != "Background":
			child.queue_free()
	call_deferred("_build_ui")


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 14)
	scroll.add_child(outer)

	# Title
	var title := Label.new()
	title.text = "SPACE EXPLORER"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(title)

	var sub := Label.new()
	sub.text = "Navigate. Mine. Conquer."
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.4, 0.6, 0.8))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(sub)

	outer.add_child(HSeparator.new())

	# Slot cards
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		outer.add_child(_make_slot_card(slot, outer))


func _make_slot_card(slot: int, outer: VBoxContainer) -> PanelContainer:
	var card := PanelContainer.new()
	var cstyle := StyleBoxFlat.new()
	cstyle.bg_color = Color(0.04, 0.08, 0.16, 0.92)
	cstyle.border_color = Color(0.2, 0.35, 0.55)
	cstyle.set_border_width_all(1)
	cstyle.corner_radius_top_left = 6
	cstyle.corner_radius_top_right = 6
	cstyle.corner_radius_bottom_left = 6
	cstyle.corner_radius_bottom_right = 6
	cstyle.content_margin_left = 14
	cstyle.content_margin_right = 14
	cstyle.content_margin_top = 12
	cstyle.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", cstyle)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 7)
	card.add_child(vbox)

	# Slot header label
	var slot_lbl := Label.new()
	slot_lbl.text = "SLOT %d" % slot
	slot_lbl.add_theme_font_size_override("font_size", 11)
	slot_lbl.add_theme_color_override("font_color", Color(0.35, 0.55, 0.75))
	vbox.add_child(slot_lbl)

	var summary := SaveManager.get_slot_summary(slot)

	if summary.is_empty():
		_fill_empty_slot(vbox, slot)
	else:
		_fill_occupied_slot(vbox, slot, summary, card, outer)

	return card


func _fill_empty_slot(vbox: VBoxContainer, slot: int) -> void:
	var empty_lbl := Label.new()
	empty_lbl.text = "— Empty —"
	empty_lbl.add_theme_font_size_override("font_size", 14)
	empty_lbl.add_theme_color_override("font_color", Color(0.38, 0.38, 0.48))
	empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(empty_lbl)

	var new_btn := Button.new()
	new_btn.text = "NEW GAME"
	new_btn.custom_minimum_size.y = 44
	new_btn.add_theme_font_size_override("font_size", 15)
	var nbstyle := StyleBoxFlat.new()
	nbstyle.bg_color = Color(0.05, 0.18, 0.35, 0.92)
	nbstyle.corner_radius_top_left = 4
	nbstyle.corner_radius_top_right = 4
	nbstyle.corner_radius_bottom_left = 4
	nbstyle.corner_radius_bottom_right = 4
	new_btn.add_theme_stylebox_override("normal", nbstyle)
	new_btn.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0))
	new_btn.pressed.connect(_on_new_game.bind(slot))
	vbox.add_child(new_btn)


func _fill_occupied_slot(vbox: VBoxContainer, slot: int, summary: Dictionary,
		card: PanelContainer, outer: VBoxContainer) -> void:
	var sector_name: String = summary.get("sector_name", "Unknown")
	var credits: int = summary.get("credits", 0)
	var hull: float = summary.get("hull", 100.0)
	var max_hull: float = summary.get("max_hull", 100.0)
	var hull_pct: int = int(round(hull / max(max_hull, 1.0) * 100.0))
	var ts: float = summary.get("timestamp", 0.0)
	var act: int = summary.get("story_act", 1)

	var info_lbl := Label.new()
	info_lbl.text = "%s  —  Act %d" % [sector_name, act]
	info_lbl.add_theme_font_size_override("font_size", 15)
	info_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
	vbox.add_child(info_lbl)

	var stat_row := HBoxContainer.new()
	stat_row.add_theme_constant_override("separation", 12)
	vbox.add_child(stat_row)

	var hull_col: Color = Color(0.4, 1.0, 0.5) if hull_pct > 50 else (Color(1.0, 0.8, 0.2) if hull_pct > 25 else Color(1.0, 0.35, 0.35))
	var hull_lbl := Label.new()
	hull_lbl.text = "Hull %d%%" % hull_pct
	hull_lbl.add_theme_font_size_override("font_size", 12)
	hull_lbl.add_theme_color_override("font_color", hull_col)
	stat_row.add_child(hull_lbl)

	var cr_lbl := Label.new()
	cr_lbl.text = "%d cr" % credits
	cr_lbl.add_theme_font_size_override("font_size", 12)
	cr_lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.3))
	stat_row.add_child(cr_lbl)

	if ts > 0.0:
		var dt: Dictionary = Time.get_datetime_dict_from_unix_time(int(ts))
		var ts_lbl := Label.new()
		ts_lbl.text = "%02d/%02d %02d:%02d" % [dt.month, dt.day, dt.hour, dt.minute]
		ts_lbl.add_theme_font_size_override("font_size", 11)
		ts_lbl.add_theme_color_override("font_color", Color(0.42, 0.42, 0.52))
		ts_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ts_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stat_row.add_child(ts_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	var cont_btn := Button.new()
	cont_btn.text = "CONTINUE"
	cont_btn.custom_minimum_size = Vector2(0, 44)
	cont_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cont_btn.add_theme_font_size_override("font_size", 15)
	var cstyle := StyleBoxFlat.new()
	cstyle.bg_color = Color(0.04, 0.22, 0.08, 0.92)
	cstyle.corner_radius_top_left = 4
	cstyle.corner_radius_top_right = 4
	cstyle.corner_radius_bottom_left = 4
	cstyle.corner_radius_bottom_right = 4
	cont_btn.add_theme_stylebox_override("normal", cstyle)
	cont_btn.add_theme_color_override("font_color", Color(0.35, 1.0, 0.5))
	cont_btn.pressed.connect(_on_continue.bind(slot))
	btn_row.add_child(cont_btn)

	var erase_btn := Button.new()
	erase_btn.text = "ERASE"
	erase_btn.custom_minimum_size = Vector2(76, 44)
	erase_btn.add_theme_font_size_override("font_size", 13)
	var estyle := StyleBoxFlat.new()
	estyle.bg_color = Color(0.22, 0.04, 0.04, 0.92)
	estyle.corner_radius_top_left = 4
	estyle.corner_radius_top_right = 4
	estyle.corner_radius_bottom_left = 4
	estyle.corner_radius_bottom_right = 4
	erase_btn.add_theme_stylebox_override("normal", estyle)
	erase_btn.add_theme_color_override("font_color", Color(1.0, 0.38, 0.38))
	erase_btn.pressed.connect(_on_erase_confirm.bind(slot, vbox))
	btn_row.add_child(erase_btn)


func _on_erase_confirm(slot: int, vbox: VBoxContainer) -> void:
	for c in vbox.get_children():
		c.queue_free()

	var slot_lbl := Label.new()
	slot_lbl.text = "SLOT %d" % slot
	slot_lbl.add_theme_font_size_override("font_size", 11)
	slot_lbl.add_theme_color_override("font_color", Color(0.35, 0.55, 0.75))
	vbox.add_child(slot_lbl)

	var confirm_lbl := Label.new()
	confirm_lbl.text = "Erase this save?"
	confirm_lbl.add_theme_font_size_override("font_size", 14)
	confirm_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
	confirm_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(confirm_lbl)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vbox.add_child(row)

	var yes_btn := Button.new()
	yes_btn.text = "ERASE"
	yes_btn.custom_minimum_size = Vector2(0, 42)
	yes_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes_btn.add_theme_font_size_override("font_size", 14)
	yes_btn.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	yes_btn.pressed.connect(func():
		SaveManager.delete_save(slot)
		_rebuild_ui())
	row.add_child(yes_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "CANCEL"
	cancel_btn.custom_minimum_size = Vector2(0, 42)
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.add_theme_font_size_override("font_size", 14)
	cancel_btn.pressed.connect(_rebuild_ui)
	row.add_child(cancel_btn)


func _rebuild_ui() -> void:
	for c in get_children():
		if c.name != "Background":
			c.queue_free()
	call_deferred("_build_ui")


func _on_new_game(slot: int) -> void:
	SaveManager.active_slot = slot
	GameState.reset_game()
	SaveManager.delete_save(slot)
	get_tree().change_scene_to_file("res://scenes/space_world.tscn")


func _on_continue(slot: int) -> void:
	if SaveManager.load_game(slot):
		get_tree().change_scene_to_file("res://scenes/space_world.tscn")
