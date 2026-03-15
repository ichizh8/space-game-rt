extends Node2D

@onready var ship: CharacterBody2D = $Ship
@onready var camera: Camera2D = $Camera2D

var _trauma: float = 0.0
var _last_hull: float = 100.0
const SHAKE_MAX := Vector2(8.0, 8.0)
const TRAUMA_DECAY := 1.5


func _ready() -> void:
	GameState.player_died.connect(_on_player_died)
	GameState.hull_changed.connect(_on_hull_changed)
	_last_hull = GameState.hull


func _process(delta: float) -> void:
	if is_instance_valid(ship):
		camera.global_position = ship.global_position
	# Screen shake
	if _trauma > 0:
		var shake := _trauma * _trauma
		camera.offset = Vector2(
			randf_range(-SHAKE_MAX.x, SHAKE_MAX.x) * shake,
			randf_range(-SHAKE_MAX.y, SHAKE_MAX.y) * shake
		)
		_trauma = max(_trauma - delta * TRAUMA_DECAY, 0.0)
	else:
		camera.offset = Vector2.ZERO


func add_trauma(amount: float) -> void:
	_trauma = min(_trauma + amount, 1.0)


func _on_hull_changed(new_hull: float) -> void:
	if new_hull < _last_hull:
		add_trauma(0.45)
	_last_hull = new_hull


func _on_player_died() -> void:
	if is_instance_valid(ship):
		ship.global_position = Vector2.ZERO
	_trauma = 0.7
	SaveManager.save_game()
