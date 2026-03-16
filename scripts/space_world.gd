extends Node2D

@onready var ship: CharacterBody2D = $Ship
@onready var camera: Camera2D = $Camera2D

var _trauma: float = 0.0
var _last_hull: float = 100.0
const SHAKE_MAX := Vector2(8.0, 8.0)
const TRAUMA_DECAY := 1.5

# Raid system
var _raid_timer: float = 0.0
var _raid_first: bool = true
var _raid_enemies: Array = []
var _raid_active: bool = false
var _raid_warning_timer: float = -1.0
const RAID_INTERVAL := 90.0
const RAID_FIRST_DELAY := 120.0
const RAID_WARNING_DURATION := 3.0


func _ready() -> void:
	# Add parallax starfield as background
	var sf_scene := load("res://scenes/starfield.tscn") as PackedScene
	if is_instance_valid(sf_scene):
		var sf := sf_scene.instantiate()
		add_child(sf)
		move_child(sf, 0)  # ensure it's behind everything
	camera.add_to_group("camera")
	GameState.player_died.connect(_on_player_died)
	GameState.hull_changed.connect(_on_hull_changed)
	_last_hull = GameState.hull
	call_deferred("_show_tutorial")


func _show_tutorial() -> void:
	var tut_scene: PackedScene = load("res://scenes/tutorial_overlay.tscn") as PackedScene
	if is_instance_valid(tut_scene):
		var tut: Node = tut_scene.instantiate()
		add_child(tut)


func _process(delta: float) -> void:
	if is_instance_valid(ship):
		camera.global_position = ship.global_position
		GameState.map_record_position(ship.global_position)
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

	# Raid system
	if _raid_warning_timer > 0:
		_raid_warning_timer -= delta
		if _raid_warning_timer <= 0:
			call_deferred("_spawn_raid")
	elif not _raid_active:
		var threshold: float = RAID_FIRST_DELAY if _raid_first else RAID_INTERVAL
		_raid_timer += delta
		if _raid_timer >= threshold:
			_raid_timer = 0.0
			_raid_first = false
			_start_raid_warning()
	else:
		# Check if raid is over
		_check_raid_complete()


func add_trauma(amount: float) -> void:
	_trauma = min(_trauma + amount, 1.0)


func _on_hull_changed(new_hull: float) -> void:
	if new_hull < _last_hull:
		add_trauma(0.45)
	_last_hull = new_hull


func _start_raid_warning() -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if is_instance_valid(hud) and hud.has_method("show_notification"):
		hud.show_notification("INCOMING RAID", RAID_WARNING_DURATION)
	_raid_warning_timer = RAID_WARNING_DURATION


func _spawn_raid() -> void:
	if not is_instance_valid(ship):
		return
	_raid_active = true
	_raid_enemies.clear()
	var count: int = randi_range(3, 5)
	var player_pos: Vector2 = ship.global_position
	var dist_from_origin: float = player_pos.length()

	# Determine zone for enemy types
	var zone: int = 1
	if dist_from_origin >= 4200.0:
		zone = 4
	elif dist_from_origin >= 2800.0:
		zone = 3
	elif dist_from_origin >= 1500.0:
		zone = 2

	for i in range(count):
		var angle: float = randf() * TAU
		var spawn_dist: float = randf_range(500.0, 700.0)
		var spawn_pos: Vector2 = player_pos + Vector2.from_angle(angle) * spawn_dist
		var scene_path: String = _get_raid_enemy_scene(zone)
		call_deferred("_spawn_raid_enemy", spawn_pos, scene_path)


func _get_raid_enemy_scene(zone: int) -> String:
	var r: float = randf()
	match zone:
		2:
			if r < 0.6:
				return "res://scenes/enemy.tscn"
			return "res://scenes/enemy.tscn"  # drone variant handled below
		3:
			if r < 0.4:
				return "res://scenes/enemy.tscn"
			elif r < 0.7:
				return "res://scenes/interceptor.tscn"
			return "res://scenes/enemy.tscn"
		4:
			if r < 0.3:
				return "res://scenes/battleship.tscn"
			elif r < 0.6:
				return "res://scenes/interceptor.tscn"
			return "res://scenes/enemy.tscn"
	return "res://scenes/enemy.tscn"


func _spawn_raid_enemy(pos: Vector2, scene_path: String) -> void:
	var scene: PackedScene = load(scene_path) as PackedScene
	if scene == null:
		return
	var enemy: Node2D = scene.instantiate() as Node2D
	if enemy == null:
		return
	enemy.global_position = pos
	# Apply zone difficulty
	var zone_mult: float = 1.0
	if pos.length() >= 4200.0:
		zone_mult = 2.2
	elif pos.length() >= 2800.0:
		zone_mult = 1.7
	elif pos.length() >= 1500.0:
		zone_mult = 1.3
	if enemy.has_method("setup"):
		enemy.setup(zone_mult)
	if enemy.has_signal("died"):
		enemy.died.connect(_on_raid_enemy_died)
	add_child(enemy)
	_raid_enemies.append(enemy)


func _on_raid_enemy_died() -> void:
	pass  # checked in _check_raid_complete


func _check_raid_complete() -> void:
	var alive: int = 0
	for e in _raid_enemies:
		if is_instance_valid(e) and not e.get("is_dead"):
			alive += 1
	if alive <= 0 and _raid_active:
		_raid_active = false
		_raid_enemies.clear()
		var hud: Node = get_tree().get_first_node_in_group("hud")
		if is_instance_valid(hud) and hud.has_method("show_notification"):
			hud.show_notification("RAID REPELLED!", 3.0)
		GameState.add_credits(150)
		# 80% artifact drop
		if randf() < 0.8:
			GameState.record_artifact()
			var em := get_tree().get_first_node_in_group("effects_manager") as Node2D
			if is_instance_valid(em) and em.has_method("add_float") and is_instance_valid(ship):
				em.add_float("+ARTIFACT", ship.global_position + Vector2(0, -30), Color.GOLD)


func _on_player_died() -> void:
	if is_instance_valid(ship):
		ship.global_position = Vector2.ZERO
	_trauma = 0.7
	_raid_active = false
	_raid_enemies.clear()
	SaveManager.save_game()
