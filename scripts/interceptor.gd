extends Node2D

enum State { APPROACH, HOVERING, DEAD }

var hp: float = 20.0
var is_dead := false
var speed: float = 240.0
var state: State = State.APPROACH
var _flash_timer: float = 0.0
var _arm_timer: float = 0.0
var _despawn_timer: float = -1.0
var _blink_timer: float = 0.0

const HOVER_RANGE := 90.0
const ARM_TIME := 2.2
const EXPLOSION_RADIUS := 100.0
const EXPLOSION_DAMAGE := 30.0
const XP_REWARD := 8
const CREDIT_REWARD := 10


func _ready() -> void:
	add_to_group("enemies")
	_setup_sprite()
	queue_redraw()


func _setup_sprite() -> void:
	var tex := load("res://assets/2026-03-15-interceptor.png") as Texture2D
	if not is_instance_valid(tex):
		return
	var sprite := Sprite2D.new()
	sprite.texture = tex
	var scale_factor: float = 44.0 / max(tex.get_size().x, tex.get_size().y)
	sprite.scale = Vector2(scale_factor, scale_factor)
	sprite.rotation = 0.0
	add_child(sprite)


func _process(delta: float) -> void:
	if _despawn_timer > 0.0:
		_despawn_timer -= delta
		if _despawn_timer <= 0.0:
			call_deferred("queue_free")
			return

	if is_dead:
		return

	if _flash_timer > 0:
		_flash_timer -= delta
		if _flash_timer <= 0:
			modulate = Color.WHITE
			queue_redraw()

	_blink_timer += delta
	queue_redraw()

	var player := _get_player()
	if not is_instance_valid(player):
		return

	var dist := global_position.distance_to(player.global_position)

	match state:
		State.APPROACH:
			if dist < HOVER_RANGE:
				state = State.HOVERING
				_arm_timer = 0.0
			else:
				var dir := (player.global_position - global_position).normalized()
				position += dir * speed * delta
				rotation = dir.angle() + PI / 2.0

		State.HOVERING:
			# Drift slowly toward player while armed
			var dir := (player.global_position - global_position).normalized()
			position += dir * 30.0 * delta
			_arm_timer += delta
			if _arm_timer >= ARM_TIME:
				call_deferred("_explode")


signal died()

func _explode() -> void:
	is_dead = true
	GameState.record_kill()
	var player := _get_player()
	if is_instance_valid(player):
		if global_position.distance_to(player.global_position) < EXPLOSION_RADIUS:
			GameState.take_damage(EXPLOSION_DAMAGE)
	GameState.add_xp(XP_REWARD)
	var em := get_tree().get_first_node_in_group("effects_manager") as Node2D
	if is_instance_valid(em) and em.has_method("add_explosion"):
		em.add_explosion(global_position, 1.4)
		em.add_float("BOOM!", global_position + Vector2(0, -25), Color.RED)
	call_deferred("_spawn_loot")
	_despawn_timer = 1.0
	queue_redraw()
	died.emit()


func _spawn_loot() -> void:
	var loot_scene := load("res://scenes/loot_drop.tscn") as PackedScene
	if not is_instance_valid(loot_scene):
		GameState.add_credits(CREDIT_REWARD)
		return
	var loot := loot_scene.instantiate() as Node2D
	loot.global_position = global_position
	var res: Dictionary = {}
	if randf() < 0.4:
		res["scrap"] = randi_range(1, 3)
	if loot.has_method("setup"):
		loot.setup(CREDIT_REWARD, res)
	get_parent().add_child(loot)


func take_damage(amount: float) -> void:
	if is_dead:
		return
	hp -= amount
	_flash_timer = 0.1
	modulate = Color(1.5, 0.3, 0.3, 1.0)
	queue_redraw()
	if hp <= 0:
		call_deferred("_explode")


func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null


func _draw() -> void:
	if is_dead:
		return
	# Body: small triangle, darker red
	var col := Color.CRIMSON if state == State.APPROACH else Color.RED
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -9), Vector2(-7, 7), Vector2(7, 7)
	]), col)
	# Armed indicator: blinking ring
	if state == State.HOVERING:
		var blink := sin(_blink_timer * 8.0) > 0.0
		if blink:
			var progress := _arm_timer / ARM_TIME
			draw_arc(Vector2.ZERO, 14.0, 0.0, TAU * progress, 24, Color(1.0, 0.2, 0.2, 0.9), 2.5)
			draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 24, Color(1.0, 0.4, 0.0, 0.3), 1.0)
