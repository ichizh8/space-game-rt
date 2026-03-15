extends Control

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var new_game_btn: Button = $VBoxContainer/NewGameButton
@onready var continue_btn: Button = $VBoxContainer/ContinueButton


func _ready() -> void:
	new_game_btn.pressed.connect(_on_new_game)
	continue_btn.pressed.connect(_on_continue)
	# Check if save exists
	continue_btn.visible = FileAccess.file_exists("user://save_game.json")


func _on_new_game() -> void:
	GameState.reset_game()
	SaveManager.delete_save()
	get_tree().change_scene_to_file("res://scenes/space_world.tscn")


func _on_continue() -> void:
	if SaveManager.load_game():
		get_tree().change_scene_to_file("res://scenes/space_world.tscn")
