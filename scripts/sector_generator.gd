extends Node2D

const SPAWN_RADIUS := 800.0
const DESPAWN_DISTANCE := 1500.0
const MIN_ASTEROIDS := 8
const MAX_ASTEROIDS := 12
const MIN_PLANETS := 3
const MAX_PLANETS := 5
const MIN_ENEMIES := 2
const MAX_ENEMIES := 3
const MIN_ARTIFACTS := 1
const MAX_ARTIFACTS := 2
const CHECK_INTERVAL := 1.0

var asteroid_scene: PackedScene
var planet_scene: PackedScene
var enemy_scene: PackedScene
var artifact_scene: PackedScene

var _spawned_objects: Array[Node2D] = []
var _check_timer: float = 0.0
var _planet_index: int = 0
var _used_artifact_positions: Array[Vector2] = []

const PLANET_NAMES: Array[String] = [
	"Nexara", "Vorthen", "Kaelis", "Zyphora", "Meridax",
	"Thalonis", "Orinax", "Pyranth", "Xelvion", "Crynara",
	"Astivon", "Draconis", "Eluvia", "Fenrath", "Gorvax",
	"Helvion", "Iridia", "Jorvask", "Kylonis", "Lumara"
]


func _ready() -> void:
	asteroid_scene = load("res://scenes/asteroid.tscn")
	planet_scene = load("res://scenes/planet.tscn")
	enemy_scene = load("res://scenes/enemy.tscn")
	artifact_scene = load("res://scenes/artifact.tscn")
	_spawn_initial()


func _process(delta: float) -> void:
	_check_timer += delta
	if _check_timer >= CHECK_INTERVAL:
		_check_timer = 0.0
		_manage_objects()


func _spawn_initial() -> void:
	var player := _get_player()
	var center := Vector2.ZERO
	if is_instance_valid(player):
		center = player.global_position

	# Spawn asteroids
	var num_asteroids := randi_range(MIN_ASTEROIDS, MAX_ASTEROIDS)
	for i in range(num_asteroids):
		_spawn_asteroid(center + _random_offset(SPAWN_RADIUS))

	# Spawn planets
	var num_planets := randi_range(MIN_PLANETS, MAX_PLANETS)
	for i in range(num_planets):
		_spawn_planet(center + _random_offset(SPAWN_RADIUS))

	# Spawn enemies
	var num_enemies := randi_range(MIN_ENEMIES, MAX_ENEMIES)
	for i in range(num_enemies):
		_spawn_enemy(center + _random_offset(SPAWN_RADIUS))

	# Spawn artifacts
	var num_artifacts := randi_range(MIN_ARTIFACTS, MAX_ARTIFACTS)
	for i in range(num_artifacts):
		_spawn_artifact(center + _random_offset(SPAWN_RADIUS))


func _manage_objects() -> void:
	var player := _get_player()
	if not is_instance_valid(player):
		return

	var player_pos := player.global_position

	# Despawn far objects
	var to_remove: Array[Node2D] = []
	for obj in _spawned_objects:
		if not is_instance_valid(obj):
			to_remove.append(obj)
			continue
		if obj.global_position.distance_to(player_pos) > DESPAWN_DISTANCE:
			to_remove.append(obj)
			obj.queue_free()

	for obj in to_remove:
		_spawned_objects.erase(obj)

	# Count current objects by type
	var asteroid_count := 0
	var planet_count := 0
	var enemy_count := 0
	var artifact_count := 0
	for obj in _spawned_objects:
		if not is_instance_valid(obj):
			continue
		if obj.is_in_group("asteroids"):
			asteroid_count += 1
		elif obj.is_in_group("planets"):
			planet_count += 1
		elif obj.is_in_group("enemies"):
			enemy_count += 1
		elif obj.is_in_group("artifacts"):
			artifact_count += 1

	# Spawn ahead of player movement
	var move_dir := Vector2.ZERO
	if is_instance_valid(player) and player is CharacterBody2D:
		var cb := player as CharacterBody2D
		if cb.velocity.length() > 10:
			move_dir = cb.velocity.normalized()

	var spawn_center := player_pos + move_dir * SPAWN_RADIUS * 0.5

	if asteroid_count < MIN_ASTEROIDS:
		for i in range(MIN_ASTEROIDS - asteroid_count):
			_spawn_asteroid(spawn_center + _random_offset(SPAWN_RADIUS))

	if planet_count < MIN_PLANETS:
		for i in range(MIN_PLANETS - planet_count):
			_spawn_planet(spawn_center + _random_offset(SPAWN_RADIUS))

	if enemy_count < MIN_ENEMIES:
		for i in range(MIN_ENEMIES - enemy_count):
			_spawn_enemy(spawn_center + _random_offset(SPAWN_RADIUS))

	if artifact_count < MIN_ARTIFACTS:
		_spawn_artifact(spawn_center + _random_offset(SPAWN_RADIUS))


func _spawn_asteroid(pos: Vector2) -> void:
	var asteroid := asteroid_scene.instantiate() as Node2D
	asteroid.global_position = pos
	get_tree().current_scene.add_child(asteroid)
	_spawned_objects.append(asteroid)


func _spawn_planet(pos: Vector2) -> void:
	var planet := planet_scene.instantiate() as Node2D
	planet.global_position = pos
	var p_name: String = PLANET_NAMES[_planet_index % PLANET_NAMES.size()]
	_planet_index += 1
	var p_id := p_name + "_" + str(_planet_index)
	var p_quest := WorldData.get_random_quest_id()
	if planet.has_method("setup"):
		planet.setup(p_name, p_id, p_quest)
	if planet.has_signal("landed"):
		planet.landed.connect(_on_planet_landed)
	get_tree().current_scene.add_child(planet)
	_spawned_objects.append(planet)


func _spawn_enemy(pos: Vector2) -> void:
	var enemy := enemy_scene.instantiate() as Node2D
	enemy.global_position = pos
	if randi() % 2 == 0:
		enemy.enemy_type = 0  # PIRATE
	else:
		enemy.enemy_type = 1  # DRONE
	enemy._ready()  # Re-initialize with correct type
	get_tree().current_scene.add_child(enemy)
	_spawned_objects.append(enemy)


func _spawn_artifact(pos: Vector2) -> void:
	var art_data := WorldData.get_random_artifact()
	if art_data.is_empty():
		return
	var artifact := artifact_scene.instantiate() as Node2D
	artifact.global_position = pos
	if artifact.has_method("setup"):
		artifact.setup(art_data)
	if artifact.has_signal("collected"):
		artifact.collected.connect(_on_artifact_collected)
	get_tree().current_scene.add_child(artifact)
	_spawned_objects.append(artifact)


func _on_planet_landed(p_planet_id: String, p_planet_name: String, p_quest_id: String) -> void:
	# Open planet menu
	var planet_menu_scene := load("res://scenes/planet_menu.tscn")
	var menu: Node = planet_menu_scene.instantiate()
	menu.setup(p_planet_id, p_planet_name, p_quest_id)
	get_tree().current_scene.add_child(menu)


func _on_artifact_collected(data: Dictionary) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if is_instance_valid(hud) and hud.has_method("show_notification"):
		hud.show_notification("Found: " + data.get("name", "Unknown Artifact") + "!")


func _random_offset(radius: float) -> Vector2:
	var angle := randf() * TAU
	var dist := randf_range(radius * 0.3, radius)
	return Vector2(cos(angle), sin(angle)) * dist


func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null
