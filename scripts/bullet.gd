extends Area2D

const SPEED := 400.0
const LIFETIME := 2.0

var is_player_bullet := true
var damage := 15.0
var _timer := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	var forward := Vector2.UP.rotated(rotation)
	position += forward * SPEED * delta
	_timer += delta
	if _timer >= LIFETIME:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if is_player_bullet and body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		call_deferred("queue_free")
	elif not is_player_bullet and body.is_in_group("player"):
		GameState.take_damage(damage)
		call_deferred("queue_free")


func _on_area_entered(area: Area2D) -> void:
	if is_player_bullet and area.is_in_group("enemies"):
		if area.has_method("take_damage"):
			area.take_damage(damage)
		call_deferred("queue_free")
	elif not is_player_bullet and area.is_in_group("player"):
		GameState.take_damage(damage)
		call_deferred("queue_free")


func _draw() -> void:
	if is_player_bullet:
		draw_circle(Vector2.ZERO, 3, Color.YELLOW)
	else:
		draw_circle(Vector2.ZERO, 3, Color.RED)
