extends Area2D

var artifact_data: Dictionary = {}
var _pulse_timer: float = 0.0

signal collected(data: Dictionary)


func _ready() -> void:
	add_to_group("artifacts")
	body_entered.connect(_on_body_entered)
	queue_redraw()


func setup(data: Dictionary) -> void:
	artifact_data = data
	queue_redraw()


func _physics_process(delta: float) -> void:
	_pulse_timer += delta
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameState.collect_artifact(artifact_data)
		collected.emit(artifact_data)
		queue_free()


func _draw() -> void:
	# Pulsing glow effect
	var pulse := (sin(_pulse_timer * 3.0) + 1.0) * 0.5
	var glow_radius := 12.0 + pulse * 4.0
	var glow_color := Color(1.0, 0.8, 0.2, 0.2 + pulse * 0.2)
	draw_circle(Vector2.ZERO, glow_radius, glow_color)
	# Inner diamond
	var points := PackedVector2Array([
		Vector2(0, -8),
		Vector2(-6, 0),
		Vector2(0, 8),
		Vector2(6, 0)
	])
	draw_colored_polygon(points, Color(1.0, 0.85, 0.0))
	# Sparkle
	draw_circle(Vector2(0, -4), 2, Color.WHITE)
