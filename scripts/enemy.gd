extends CharacterBody2D

enum State { PATROL, CHASE, ATTACK }
enum EnemyType { PIRATE, DRONE }

@export var enemy_type: EnemyType = EnemyType.PIRATE

var hp: float = 30.0
var is_dead := false
var damage: float = 10.0
var speed: float = 180.0
var state: State = State.PATROL
var patrol_direction: Vector2 = Vector2.RIGHT
var patrol_timer: float = 0.0
var shoot_timer: float = 0.0
var shoot_cooldown: float = 1.0
var bullet_scene: PackedScene

const CHASE_RANGE := 300.0
const ATTACK_RANGE := 150.0


func _ready() -> void:
	add_to_group("enemies")
	bullet_scene = load("res://scenes/bullet.tscn")
	match enemy_type:
		EnemyType.PIRATE:
			speed = 180.0
			hp = 30.0
			damage = 10.0
			shoot_cooldown = 1.2
		EnemyType.DRONE:
			speed = 100.0
			hp = 60.0
			damage = 15.0
			shoot_cooldown = 0.8
	patrol_direction = Vector2.from_angle(randf() * TAU)
	queue_redraw()


func _physics_process(delta: float) -> void:
	var player := _get_player()
	if not is_instance_valid(player):
		_do_patrol(delta)
		return

	var dist := global_position.distance_to(player.global_position)

	if dist <= ATTACK_RANGE:
		state = State.ATTACK
	elif dist <= CHASE_RANGE:
		state = State.CHASE
	else:
		state = State.PATROL

	match state:
		State.PATROL:
			_do_patrol(delta)
		State.CHASE:
			_do_chase(player, delta)
		State.ATTACK:
			_do_attack(player, delta)

	move_and_slide()


func _do_patrol(delta: float) -> void:
	patrol_timer += delta
	if patrol_timer > 3.0:
		patrol_timer = 0.0
		patrol_direction = Vector2.from_angle(randf() * TAU)
	velocity = patrol_direction * speed * 0.5
	rotation = velocity.angle() + PI / 2.0


func _do_chase(player: Node2D, _delta: float) -> void:
	var dir := (player.global_position - global_position).normalized()
	velocity = dir * speed
	rotation = dir.angle() + PI / 2.0


func _do_attack(player: Node2D, delta: float) -> void:
	var dir := (player.global_position - global_position).normalized()
	velocity = dir * speed * 0.3
	rotation = dir.angle() + PI / 2.0

	shoot_timer += delta
	if shoot_timer >= shoot_cooldown:
		shoot_timer = 0.0
		_shoot()


func _shoot() -> void:
	if not is_instance_valid(bullet_scene):
		return
	var bullet := bullet_scene.instantiate() as Area2D
	bullet.global_position = global_position + Vector2.UP.rotated(rotation) * -20.0
	bullet.rotation = rotation
	bullet.is_player_bullet = false
	bullet.damage = damage
	get_tree().current_scene.add_child(bullet)


func take_damage(amount: float) -> void:
	if is_dead:
		return
	hp -= amount
	if hp <= 0:
		_die()


func _die() -> void:
	is_dead = true
	set_physics_process(false)
	set_process(false)
	var drop_types := ["ore", "crystal", "scrap", "fuel"]
	var drop_type: String = drop_types[randi() % drop_types.size()]
	var drop_amount: int = randi_range(5, 10)
	GameState.add_resource(drop_type, drop_amount)
	call_deferred("queue_free")


func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null


func _draw() -> void:
	match enemy_type:
		EnemyType.PIRATE:
			# Red diamond shape
			var points := PackedVector2Array([
				Vector2(0, -12),
				Vector2(-10, 0),
				Vector2(0, 12),
				Vector2(10, 0)
			])
			draw_colored_polygon(points, Color.RED)
		EnemyType.DRONE:
			# Orange hexagon
			var points := PackedVector2Array()
			for i in range(6):
				var angle := i * TAU / 6.0 - PI / 2.0
				points.append(Vector2(cos(angle), sin(angle)) * 14)
			draw_colored_polygon(points, Color.ORANGE)
