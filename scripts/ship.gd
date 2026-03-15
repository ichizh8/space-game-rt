extends CharacterBody2D

const BASE_SPEED := 200.0
const FUEL_DRAIN_RATE := 0.5  # per second while moving

var is_firing := false
var can_shoot := true
var bullet_scene: PackedScene
var _gravity_accum: Vector2 = Vector2.ZERO
var _trail_points: Array[Vector2] = []
var _trail_timer: float = 0.0

@onready var gun_point: Marker2D = $GunPoint
@onready var shoot_timer: Timer = $ShootTimer


func _ready() -> void:
	bullet_scene = load("res://scenes/bullet.tscn")
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	_setup_sprite()


func _physics_process(delta: float) -> void:
	var direction := Vector2.ZERO
	var hud_node := get_tree().get_first_node_in_group("hud")
	if hud_node and hud_node.has_method("get_joystick_direction"):
		direction = hud_node.get_joystick_direction()

	if direction.length() > 0.1 and GameState.fuel > 0:
		var speed := BASE_SPEED + GameState.player_speed_bonus
		velocity = direction.normalized() * speed
		rotation = direction.angle() + PI / 2.0
		var drain := FUEL_DRAIN_RATE * (1.0 - GameState.captain_fuel_efficiency)
		GameState.use_fuel(drain * delta)
	else:
		velocity = Vector2.ZERO

	velocity += _gravity_accum
	_gravity_accum = Vector2.ZERO
	move_and_slide()

	_trail_timer += delta
	if _trail_timer > 0.04 and velocity.length() > 10.0:
		_trail_timer = 0.0
		_trail_points.push_front(global_position)
		if _trail_points.size() > 12:
			_trail_points.resize(12)
		queue_redraw()
	elif velocity.length() < 10.0 and not _trail_points.is_empty():
		_trail_points.clear()
		queue_redraw()

	if is_firing and can_shoot and GameState.fuel > 0:
		_shoot()


func _shoot() -> void:
	can_shoot = false
	shoot_timer.start()
	var bullet := bullet_scene.instantiate() as Node2D
	bullet.global_position = gun_point.global_position
	bullet.rotation = rotation
	bullet.is_player_bullet = true
	bullet.damage = 15.0 + GameState.player_damage_bonus + GameState.captain_damage_bonus
	get_tree().current_scene.add_child(bullet)


func _on_shoot_timer_timeout() -> void:
	can_shoot = true


func apply_gravity(force: Vector2) -> void:
	_gravity_accum += force


func set_firing(value: bool) -> void:
	is_firing = value


func _setup_sprite() -> void:
	var sprite := Sprite2D.new()
	sprite.name = "ShipSprite"
	var tex := load("res://assets/2026-03-15-ship-sprite.png") as Texture2D
	if is_instance_valid(tex):
		sprite.texture = tex
		# Scale to fit: sprite is ~1024px, we want ~36px game size
		var target_size := 36.0
		var tex_size := tex.get_size()
		var scale_factor: float = target_size / max(tex_size.x, tex_size.y)
		sprite.scale = Vector2(scale_factor, scale_factor)
	else:
		# Fallback: keep procedural draw if texture fails
		return
	add_child(sprite)


func _draw() -> void:
	# Engine exhaust trail
	for i in range(_trail_points.size()):
		var world_pt: Vector2 = _trail_points[i]
		var local_pt: Vector2 = to_local(world_pt)
		var t: float = 1.0 - float(i) / float(_trail_points.size())
		var radius: float = 3.5 * t
		var alpha: float = 0.6 * t
		draw_circle(local_pt, radius, Color(0.3, 0.7, 1.0, alpha))
