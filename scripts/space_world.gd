extends Node2D

@onready var ship: CharacterBody2D = $Ship
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	GameState.player_died.connect(_on_player_died)


func _process(_delta: float) -> void:
	if is_instance_valid(ship):
		camera.global_position = ship.global_position


func _on_player_died() -> void:
	# Respawn at origin (or last planet position)
	if is_instance_valid(ship):
		ship.global_position = Vector2.ZERO
	SaveManager.save_game()
