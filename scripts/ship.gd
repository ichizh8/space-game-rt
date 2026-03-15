extends CharacterBody2D

const BASE_SPEED := 200.0
const FUEL_DRAIN_RATE := 0.5  # per second while moving

var is_firing := false
var can_shoot := true
var bullet_scene: PackedScene

@onready var gun_point: Marker2D = $GunPoint
@onready var shoot_timer: Timer = $ShootTimer


func _ready() -> void:
	bullet_scene = load("res://scenes/bullet.tscn")
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)


func _physics_process(delta: float) -> void:
	var direction := Vector2.ZERO
	var hud_node := get_tree().get_first_node_in_group("hud")
	if hud_node and hud_node.has_method("get_joystick_direction"):
		direction = hud_node.get_joystick_direction()

	if direction.length() > 0.1 and GameState.fuel > 0:
		var speed := BASE_SPEED + GameState.player_speed_bonus
		velocity = direction.normalized() * speed
		rotation = direction.angle() + PI / 2.0
		GameState.use_fuel(FUEL_DRAIN_RATE * delta)
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	if is_firing and can_shoot and GameState.fuel > 0:
		_shoot()


func _shoot() -> void:
	can_shoot = false
	shoot_timer.start()
	var bullet := bullet_scene.instantiate() as Node2D
	bullet.global_position = gun_point.global_position
	bullet.rotation = rotation
	bullet.is_player_bullet = true
	bullet.damage = 15.0 + GameState.player_damage_bonus
	get_tree().current_scene.add_child(bullet)


func _on_shoot_timer_timeout() -> void:
	can_shoot = true


func set_firing(value: bool) -> void:
	is_firing = value


func _draw() -> void:
	# Draw a simple cyan triangle as placeholder ship
	var points := PackedVector2Array([
		Vector2(0, -15),
		Vector2(-10, 15),
		Vector2(10, 15)
	])
	draw_colored_polygon(points, Color.CYAN)
	# Engine glow
	draw_circle(Vector2(0, 12), 4, Color(1.0, 0.5, 0.0, 0.6))
