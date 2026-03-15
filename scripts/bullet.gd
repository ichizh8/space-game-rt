extends Node2D

const SPEED := 500.0
const LIFETIME := 2.0
const HIT_RADIUS_ENEMY := 16.0
const HIT_RADIUS_PLAYER := 20.0

var is_player_bullet := true
var damage := 15.0
var _timer := 0.0
var _hit := false


func _process(delta: float) -> void:
	if _hit:
		return
	var forward := Vector2.UP.rotated(rotation)
	position += forward * SPEED * delta
	_timer += delta
	if _timer >= LIFETIME:
		_hit = true
		queue_redraw()
		return
	queue_redraw()
	if is_player_bullet:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy):
				continue
			if enemy.get("is_dead") == true:
				continue
			if global_position.distance_to(enemy.global_position) < HIT_RADIUS_ENEMY:
				if enemy.has_method("take_damage"):
					enemy.take_damage(damage)
				_hit = true
				queue_redraw()
				return
		# Check hazard asteroids
		for haz in get_tree().get_nodes_in_group("hazard_asteroids"):
			if not is_instance_valid(haz):
				continue
			if haz.get("_hit") == true:
				continue
			if global_position.distance_to(haz.global_position) < 16.0:
				if haz.has_method("take_damage"):
					haz.take_damage(damage)
				_hit = true
				queue_redraw()
				return
	else:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var player := players[0]
			if is_instance_valid(player) and global_position.distance_to(player.global_position) < HIT_RADIUS_PLAYER:
				GameState.take_damage(damage)
				_hit = true
				queue_redraw()


func _draw() -> void:
	if _hit:
		return
	if is_player_bullet:
		# Player bullet: cyan core with glow halo
		draw_circle(Vector2.ZERO, 5.5, Color(0.3, 0.9, 1.0, 0.2))  # outer glow
		draw_circle(Vector2.ZERO, 3.5, Color(0.5, 1.0, 1.0, 0.5))  # mid glow
		draw_circle(Vector2.ZERO, 2.0, Color(1.0, 1.0, 1.0, 0.95)) # bright core
	else:
		# Enemy bullet: orange-red with glow
		draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.4, 0.1, 0.15)) # outer glow
		draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.5, 0.1, 0.4))  # mid glow
		draw_circle(Vector2.ZERO, 2.5, Color(1.0, 0.85, 0.5, 1.0)) # core
