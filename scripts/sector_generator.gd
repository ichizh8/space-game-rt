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
const CHECK_INTERVAL := 0.5
const MIN_STARS := 1
const MAX_STARS := 2
const MIN_STATIONS := 1
const MAX_STATIONS := 2
const BLACK_HOLE_CHANCE := 0.4

enum Biome { MIXED, ASTEROID_BELT, DEBRIS_FIELD, DEEP_SPACE, NEBULA }

const BIOME_NAMES: Array[String] = ["Mixed", "Asteroid Belt", "Debris Field", "Deep Space", "Nebula"]

var asteroid_scene: PackedScene
var planet_scene: PackedScene
var enemy_scene: PackedScene
var artifact_scene: PackedScene
var star_scene: PackedScene
var black_hole_scene: PackedScene
var station_scene: PackedScene
var interceptor_scene: PackedScene
var battleship_scene: PackedScene
var turret_scene: PackedScene
var hazard_asteroid_scene: PackedScene
var sniper_scene: PackedScene
var minelayer_scene: PackedScene
var carrier_scene: PackedScene
var void_sentinel_scene: PackedScene

# Wildlife scenes
var void_grub_scene: PackedScene
var skim_ray_scene: PackedScene
var pack_snarler_scene: PackedScene
var membrane_drifter_scene: PackedScene
var crystal_feeder_scene: PackedScene
var void_leviathan_scene: PackedScene

const MIN_WILDLIFE := 2
const MAX_WILDLIFE := 4

var _spawned_objects: Array[Node2D] = []
var _check_timer: float = 0.0
var _planet_index: int = 0
var _used_artifact_positions: Array[Vector2] = []
var _current_biome: Biome = Biome.MIXED
var _biome_change_timer: float = 0.0
const BIOME_CHANGE_INTERVAL := 45.0

var _comet_timer: float = 0.0
var _comet_interval: float = 0.0
var comet_scene: PackedScene

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
	star_scene = load("res://scenes/star.tscn")
	black_hole_scene = load("res://scenes/black_hole.tscn")
	station_scene = load("res://scenes/space_station.tscn")
	interceptor_scene = load("res://scenes/interceptor.tscn")
	battleship_scene = load("res://scenes/battleship.tscn")
	turret_scene = load("res://scenes/turret.tscn")
	hazard_asteroid_scene = load("res://scenes/hazard_asteroid.tscn")
	sniper_scene = load("res://scenes/sniper.tscn")
	minelayer_scene = load("res://scenes/minelayer.tscn")
	carrier_scene = load("res://scenes/carrier.tscn")
	void_sentinel_scene = load("res://scenes/void_sentinel.tscn")
	comet_scene = load("res://scenes/comet.tscn")
	void_grub_scene = load("res://scenes/void_grub.tscn")
	skim_ray_scene = load("res://scenes/skim_ray.tscn")
	pack_snarler_scene = load("res://scenes/pack_snarler.tscn")
	membrane_drifter_scene = load("res://scenes/membrane_drifter.tscn")
	crystal_feeder_scene = load("res://scenes/crystal_feeder.tscn")
	void_leviathan_scene = load("res://scenes/void_leviathan.tscn")
	_comet_interval = randf_range(45.0, 90.0)
	call_deferred("_connect_signals_deferred")
	call_deferred("_spawn_initial")


func _process(delta: float) -> void:
	_check_timer += delta
	if _check_timer >= CHECK_INTERVAL:
		_check_timer = 0.0
		_manage_objects()
		_check_story_triggers()
	_biome_change_timer += delta
	if _biome_change_timer >= BIOME_CHANGE_INTERVAL:
		_biome_change_timer = 0.0
		_pick_biome()
	# Comet spawning
	_comet_timer += delta
	if _comet_timer >= _comet_interval:
		_comet_timer = 0.0
		_comet_interval = randf_range(45.0, 90.0)
		call_deferred("_spawn_comet")


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
	# Spawn home station nearby
	_spawn_planet(center + Vector2(150, -80))
	# Spawn remaining planets farther out
	var num_planets := randi_range(MIN_PLANETS - 1, MAX_PLANETS - 1)
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

	# Spawn stars (away from spawn center)
	var num_stars := randi_range(MIN_STARS, MAX_STARS)
	for i in range(num_stars):
		_spawn_star(center + _random_offset(SPAWN_RADIUS * 0.8))

	# Spawn black hole (rare)
	if randf() < BLACK_HOLE_CHANCE:
		_spawn_black_hole(center + _random_offset(SPAWN_RADIUS))

	# Spawn home station close, additional ones further
	_spawn_station(center + Vector2(-160, 120))
	var num_extra_stations := randi_range(0, MAX_STATIONS - 1)
	for i in range(num_extra_stations):
		_spawn_station(center + _random_offset(SPAWN_RADIUS))

	# Spawn 1-2 hazard belts
	for i in range(randi_range(1, 2)):
		_spawn_hazard_belt(center + _random_offset(SPAWN_RADIUS * 0.6))



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
			pass  # node stays in tree, just not counted

	for obj in to_remove:
		_spawned_objects.erase(obj)

	# Discover nearby planets for the map
	for obj in _spawned_objects:
		if not is_instance_valid(obj):
			continue
		if not obj.is_in_group("planets"):
			continue
		if obj.global_position.distance_to(player_pos) < 350.0:
			var pid: String = str(obj.get("planet_id") if obj.get("planet_id") != null else "")
			var pname: String = str(obj.get("planet_name") if obj.get("planet_name") != null else "")
			var pcol: float = float(obj.get("_color_h") if obj.get("_color_h") != null else 0.3)
			if pid != "":
				GameState.map_discover_planet(pid, obj.global_position, pname, pcol)

	# Count current objects by type
	var asteroid_count := 0
	var planet_count := 0
	var enemy_count := 0
	var artifact_count := 0
	var star_count := 0
	var station_count := 0
	for obj in _spawned_objects:
		if not is_instance_valid(obj):
			continue
		if not obj.visible:
			continue
		if obj.is_in_group("asteroids"):
			asteroid_count += 1
		elif obj.is_in_group("planets"):
			planet_count += 1
		elif obj.is_in_group("enemies"):
			enemy_count += 1
		elif obj.is_in_group("artifacts"):
			artifact_count += 1
		elif obj.is_in_group("stars"):
			star_count += 1
		elif obj.is_in_group("stations"):
			station_count += 1
		elif obj.is_in_group("hazard_asteroids"):
			pass  # tracked by group, not refilled

	# Spawn ahead of player movement
	var move_dir := Vector2.ZERO
	if is_instance_valid(player) and player is CharacterBody2D:
		var cb := player as CharacterBody2D
		if cb.velocity.length() > 10:
			move_dir = cb.velocity.normalized()

	var spawn_center := player_pos + move_dir * SPAWN_RADIUS * 0.5

	if asteroid_count < MIN_ASTEROIDS:
		for i in range(MIN_ASTEROIDS - asteroid_count):
			call_deferred("_spawn_asteroid", _safe_spawn_pos(spawn_center, SPAWN_RADIUS, 200.0))

	if planet_count < MIN_PLANETS:
		for i in range(MIN_PLANETS - planet_count):
			call_deferred("_spawn_planet", _safe_spawn_pos(spawn_center, SPAWN_RADIUS, 400.0))

	if enemy_count < MIN_ENEMIES:
		for i in range(MIN_ENEMIES - enemy_count):
			call_deferred("_spawn_enemy", _safe_spawn_pos(spawn_center, SPAWN_RADIUS, 320.0))

	if artifact_count < MIN_ARTIFACTS:
		call_deferred("_spawn_artifact", _safe_spawn_pos(spawn_center, SPAWN_RADIUS, 250.0))

	if star_count < MIN_STARS:
		for i in range(MIN_STARS - star_count):
			call_deferred("_spawn_star", _safe_spawn_pos(spawn_center, SPAWN_RADIUS * 0.9, 550.0))

	if station_count < MIN_STATIONS:
		call_deferred("_spawn_station", _safe_spawn_pos(spawn_center, SPAWN_RADIUS * 0.5, 350.0))

	# Wildlife spawning
	_spawn_wildlife(player_pos, spawn_center)


func _spawn_asteroid(pos: Vector2) -> void:
	if asteroid_scene == null:
		return
	var asteroid := asteroid_scene.instantiate() as Node2D
	if asteroid == null:
		return
	asteroid.global_position = pos
	get_parent().add_child(asteroid)
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
	get_parent().add_child(planet)
	_spawned_objects.append(planet)


func _get_zone_difficulty() -> float:
	var player := _get_player()
	if not is_instance_valid(player):
		return 1.0
	var dist := player.global_position.length()
	if dist >= 4200.0:
		return 2.2
	elif dist >= 2800.0:
		return 1.7
	elif dist >= 1500.0:
		return 1.3
	return 1.0

func _apply_difficulty(enemy: Node2D, diff: float) -> void:
	if enemy.has_method("setup"):
		enemy.setup(diff)

func _spawn_enemy(pos: Vector2) -> void:
	var diff := _get_zone_difficulty()
	var enemy: Node2D
	var r := randf()
	match _current_biome:
		Biome.ASTEROID_BELT:
			if r < 0.40:
				enemy = enemy_scene.instantiate() as Node2D
				enemy.set("enemy_type", 0)  # pirate
			elif r < 0.65:
				enemy = enemy_scene.instantiate() as Node2D
				enemy.set("enemy_type", 1)  # drone
			elif r < 0.85:
				enemy = carrier_scene.instantiate() as Node2D
			else:
				_spawn_interceptor_pack(pos)
				return
		Biome.DEBRIS_FIELD:
			if r < 0.35:
				_spawn_interceptor_pack(pos)
				return
			elif r < 0.65:
				enemy = minelayer_scene.instantiate() as Node2D
			elif r < 0.80:
				enemy = turret_scene.instantiate() as Node2D
			else:
				enemy = enemy_scene.instantiate() as Node2D
				enemy.set("enemy_type", 0)
		Biome.DEEP_SPACE:
			if r < 0.35:
				enemy = void_sentinel_scene.instantiate() as Node2D
			elif r < 0.65:
				enemy = sniper_scene.instantiate() as Node2D
			elif r < 0.80:
				enemy = battleship_scene.instantiate() as Node2D
			else:
				enemy = enemy_scene.instantiate() as Node2D
				enemy.set("enemy_type", 0)
		Biome.NEBULA:
			if r < 0.45:
				enemy = enemy_scene.instantiate() as Node2D
				enemy.set("enemy_type", 1)  # drone
			elif r < 0.75:
				_spawn_interceptor_pack(pos)
				return
			else:
				enemy = sniper_scene.instantiate() as Node2D
		_:  # MIXED
			if r < 0.28:
				enemy = enemy_scene.instantiate() as Node2D
				enemy.set("enemy_type", 0)
			elif r < 0.50:
				enemy = enemy_scene.instantiate() as Node2D
				enemy.set("enemy_type", 1)
			elif r < 0.65:
				_spawn_interceptor_pack(pos)
				return
			elif r < 0.78:
				enemy = sniper_scene.instantiate() as Node2D
			elif r < 0.88:
				enemy = minelayer_scene.instantiate() as Node2D
			else:
				enemy = carrier_scene.instantiate() as Node2D
	enemy.global_position = pos
	_apply_difficulty(enemy, diff)
	get_parent().add_child(enemy)
	_spawned_objects.append(enemy)


func _spawn_interceptor_pack(center: Vector2) -> void:
	var diff := _get_zone_difficulty()
	var count := randi_range(2, 4)
	for i in range(count):
		var offset := Vector2.from_angle(i * TAU / count) * randf_range(30.0, 60.0)
		var interceptor := interceptor_scene.instantiate() as Node2D
		interceptor.global_position = center + offset
		if interceptor.has_method("setup"):
			interceptor.setup(diff)
		get_parent().add_child(interceptor)
		_spawned_objects.append(interceptor)


func _spawn_hazard_belt(center: Vector2) -> void:
	var count := randi_range(8, 14)
	for i in range(count):
		var offset := Vector2.from_angle(randf() * TAU) * randf_range(40.0, 120.0)
		var haz := hazard_asteroid_scene.instantiate() as Node2D
		haz.global_position = center + offset
		get_parent().add_child(haz)
		_spawned_objects.append(haz)


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
	get_parent().add_child(artifact)
	_spawned_objects.append(artifact)


func _on_planet_landed(p_planet_id: String, p_planet_name: String, p_quest_id: String) -> void:
	# Defer add_child — calling it from inside a signal callback crashes WASM
	call_deferred("_open_planet_menu", p_planet_id, p_planet_name, p_quest_id)


func _open_planet_menu(p_planet_id: String, p_planet_name: String, p_quest_id: String) -> void:
	var planet_menu_scene := load("res://scenes/planet_menu.tscn")
	var menu: Node = planet_menu_scene.instantiate()
	menu.setup(p_planet_id, p_planet_name, p_quest_id)
	get_parent().add_child(menu)


func _on_artifact_collected(data: Dictionary) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if is_instance_valid(hud) and hud.has_method("show_notification"):
		hud.show_notification("Found: " + data.get("name", "Unknown Artifact") + "!")


func _random_offset(radius: float) -> Vector2:
	var angle := randf() * TAU
	var dist := randf_range(radius * 0.5, radius)
	return Vector2(cos(angle), sin(angle)) * dist


func _safe_spawn_pos(center: Vector2, radius: float, min_player_dist: float = 350.0) -> Vector2:
	var player := _get_player()
	var player_pos := player.global_position if is_instance_valid(player) else Vector2.ZERO
	for _i in range(12):  # up to 12 attempts to find a safe spot
		var pos := center + _random_offset(radius)
		if pos.distance_to(player_pos) >= min_player_dist:
			return pos
	# Fallback: spawn directly behind the player's movement direction
	var angle := randf() * TAU
	return player_pos + Vector2(cos(angle), sin(angle)) * (min_player_dist + randf_range(50.0, 150.0))


func _spawn_star(pos: Vector2) -> void:
	var star := star_scene.instantiate() as Node2D
	star.global_position = pos
	get_parent().add_child(star)
	_spawned_objects.append(star)


func _spawn_comet() -> void:
	if comet_scene == null:
		return
	var player := _get_player()
	if not is_instance_valid(player):
		return
	# Spawn at edge of view, random direction
	var angle: float = randf() * TAU
	var spawn_pos: Vector2 = player.global_position + Vector2.from_angle(angle) * 600.0
	var comet: Node2D = comet_scene.instantiate() as Node2D
	comet.global_position = spawn_pos
	get_parent().add_child(comet)


func _spawn_black_hole(pos: Vector2) -> void:
	var bh := black_hole_scene.instantiate() as Node2D
	bh.global_position = pos
	get_parent().add_child(bh)
	_spawned_objects.append(bh)


var _station_index: int = 0
const STATION_NAMES: Array[String] = [
	"Outpost Kepler", "Relay Station Zeta", "Frontier Hub", "Port Orion",
	"Waypoint Nova", "Station Arcturus", "Crossroads Alpha", "Depot Sirius"
]

func _spawn_station(pos: Vector2) -> void:
	var station := station_scene.instantiate() as Node2D
	station.global_position = pos
	var s_name := STATION_NAMES[_station_index % STATION_NAMES.size()]
	_station_index += 1
	var s_id := s_name.replace(" ", "_") + "_" + str(_station_index)
	if station.has_method("setup"):
		station.setup(s_id, s_name)
	if station.has_signal("docked"):
		station.docked.connect(_on_station_docked)
	get_parent().add_child(station)
	_spawned_objects.append(station)


func _on_station_docked(s_id: String, s_name: String) -> void:
	call_deferred("_open_station_menu", s_id, s_name)


func _open_station_menu(s_id: String, s_name: String) -> void:
	var menu_scene := load("res://scenes/station_menu.tscn")
	var menu: Node = menu_scene.instantiate()
	menu.setup(s_id, s_name)
	get_parent().add_child(menu)


func _spawn_wildlife(player_pos: Vector2, spawn_center: Vector2) -> void:
	var wildlife_count := 0
	for obj in _spawned_objects:
		if not is_instance_valid(obj):
			continue
		if obj.is_in_group("wildlife") and not obj.get("is_dead"):
			wildlife_count += 1

	# Inside a hunting zone: higher cap, spawn zone-specific creatures
	var active_zone: String = GameState.active_hunting_zone
	var zone_max: int = MAX_WILDLIFE if active_zone == "" else MAX_WILDLIFE + 3
	var zone_min: int = MIN_WILDLIFE if active_zone == "" else MIN_WILDLIFE + 2
	if wildlife_count >= zone_max:
		return

	var diff := _get_zone_difficulty()
	var to_spawn: int = zone_min - wildlife_count
	if to_spawn <= 0:
		return

	for i in range(to_spawn):
		# Spawn wildlife closer to player (300-500 px), not far ahead like enemies
		var wildlife_spawn_center := player_pos
		if active_zone != "":
			# In a hunting zone: spawn right around player
			var zone_pos := Vector2.ZERO
			for z in GameState.hunting_zones_sector1:
				if z.get("id", "") == active_zone:
					zone_pos = Vector2(float(z.get("pos_x", 0.0)), float(z.get("pos_y", 0.0)))
					break
			# Bias toward zone center so creatures stay in zone
			wildlife_spawn_center = player_pos.lerp(zone_pos, 0.3)
		var pos := _safe_spawn_pos(wildlife_spawn_center, 500.0, 200.0)

		# If inside a named hunting zone, spawn that zone's creature type
		if active_zone != "":
			match active_zone:
				"hunt_void_grubs":
					call_deferred("_spawn_wildlife_single", void_grub_scene, pos, diff)
				"hunt_skim_rays":
					call_deferred("_spawn_wildlife_single", skim_ray_scene, pos, diff)
				"hunt_snarlers":
					call_deferred("_spawn_snarler_pack", pos, diff)
				"hunt_drifters":
					call_deferred("_spawn_wildlife_single", membrane_drifter_scene, pos, diff)
				"hunt_feeders":
					call_deferred("_spawn_wildlife_single", crystal_feeder_scene, pos, diff)
				"hunt_leviathan":
					var has_leviathan2 := false
					for obj2 in _spawned_objects:
						if is_instance_valid(obj2) and obj2.is_in_group("wildlife") and obj2.name.begins_with("VoidLeviathan"):
							has_leviathan2 = true
							break
					if not has_leviathan2:
						call_deferred("_spawn_wildlife_single", void_leviathan_scene, pos, diff)
					else:
						call_deferred("_spawn_wildlife_single", crystal_feeder_scene, pos, diff)
				_:
					call_deferred("_spawn_wildlife_single", void_grub_scene, pos, diff)
			continue

		# Outside hunting zones: biome-based random spawn
		match _current_biome:
			Biome.MIXED:
				var r := randf()
				if r < 0.35:
					call_deferred("_spawn_wildlife_single", void_grub_scene, pos, diff)
				elif r < 0.65:
					call_deferred("_spawn_wildlife_single", skim_ray_scene, pos, diff)
				elif r < 0.85:
					call_deferred("_spawn_snarler_pack", pos, diff)
				else:
					call_deferred("_spawn_wildlife_single", crystal_feeder_scene, pos, diff)
			Biome.ASTEROID_BELT:
				var r := randf()
				if r < 0.45:
					call_deferred("_spawn_wildlife_single", void_grub_scene, pos, diff)
				elif r < 0.75:
					call_deferred("_spawn_wildlife_single", skim_ray_scene, pos, diff)
				else:
					call_deferred("_spawn_wildlife_single", crystal_feeder_scene, pos, diff)
			Biome.DEBRIS_FIELD:
				var r := randf()
				if r < 0.6:
					call_deferred("_spawn_snarler_pack", pos, diff)
				else:
					call_deferred("_spawn_wildlife_single", void_grub_scene, pos, diff)
			Biome.NEBULA:
				call_deferred("_spawn_wildlife_single", membrane_drifter_scene, pos, diff)
			Biome.DEEP_SPACE:
				var has_leviathan := false
				for obj in _spawned_objects:
					if is_instance_valid(obj) and obj.is_in_group("wildlife") and obj.name.begins_with("VoidLeviathan"):
						has_leviathan = true
						break
				if not has_leviathan and randf() < 0.1:
					call_deferred("_spawn_wildlife_single", void_leviathan_scene, pos, diff)
				else:
					call_deferred("_spawn_wildlife_single", crystal_feeder_scene, pos, diff)


func _spawn_wildlife_single(scene: PackedScene, pos: Vector2, diff: float) -> void:
	if scene == null:
		return
	var creature := scene.instantiate() as Node2D
	creature.global_position = pos
	if creature.has_method("setup"):
		creature.setup(diff)
	get_parent().add_child(creature)
	_spawned_objects.append(creature)


func _spawn_snarler_pack(center: Vector2, diff: float) -> void:
	if pack_snarler_scene == null:
		return
	# 1 alpha + 2 normal
	for i in range(3):
		var offset := Vector2.from_angle(i * TAU / 3.0) * randf_range(30.0, 60.0)
		var snarler := pack_snarler_scene.instantiate() as Node2D
		snarler.global_position = center + offset
		if i == 0:
			snarler.set("is_alpha", true)
		if snarler.has_method("setup"):
			snarler.setup(diff)
		get_parent().add_child(snarler)
		_spawned_objects.append(snarler)


func _pick_biome() -> void:
	var player := _get_player()
	if not is_instance_valid(player):
		return
	var dist_from_origin := player.global_position.length()
	# Deep space and nebula only appear far from origin
	var pool: Array[Biome] = [Biome.MIXED, Biome.ASTEROID_BELT, Biome.DEBRIS_FIELD]
	if dist_from_origin > 1200.0:
		pool.append(Biome.DEEP_SPACE)
		pool.append(Biome.NEBULA)
	_current_biome = pool[randi() % pool.size()]
	GameState.map_note_biome(player.global_position, _current_biome)


func _connect_signals_deferred() -> void:
	if not GameState.player_died.is_connected(_on_player_died_for_end_screen):
		GameState.player_died.connect(_on_player_died_for_end_screen)




func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null


func _check_story_triggers() -> void:
	var player := _get_player()
	if not is_instance_valid(player):
		return
	var player_pos := player.global_position
	var dist := player_pos.length()

	# Act 1: player traveled far enough with distress quest active
	if GameState.story_act == 1 and GameState.is_quest_active("story_act1"):
		if dist >= 1500.0 and not GameState.get_story_flag("distress_found"):
			GameState.set_story_flag("distress_found", true)
			call_deferred("_spawn_story_planet_deferred", player_pos + Vector2(300, -150))
			var hud := get_tree().get_first_node_in_group("hud")
			if is_instance_valid(hud) and hud.has_method("show_notification"):
				hud.show_notification("Signal source located! Land on the marked planet.")
			GameState.complete_quest("story_act1")
			_apply_reward({"credits": 100})
			GameState.story_act = 2

	# Act 3: spawn command ship cluster when player is near
	if GameState.story_act == 3 and not GameState.get_story_flag("command_ship_spawned"):
		var cx: float = 2500.0
		var cy: float = 800.0
		var v: Variant = GameState.get_story_flag("command_ship_pos_x")
		if v != null:
			cx = float(v)
		v = GameState.get_story_flag("command_ship_pos_y")
		if v != null:
			cy = float(v)
		var cmd_pos := Vector2(cx, cy)
		if player_pos.distance_to(cmd_pos) < 600.0:
			GameState.set_story_flag("command_ship_spawned", true)
			call_deferred("_spawn_command_ship_cluster", cmd_pos)

	# Act 3: check if command ship cluster destroyed
	if GameState.story_act == 3 and GameState.get_story_flag("command_ship_spawned"):
		var total: int = 0
		var killed: int = 0
		var vt: Variant = GameState.get_story_flag("cmd_total")
		if vt != null:
			total = int(vt)
		var vk: Variant = GameState.get_story_flag("cmd_killed")
		if vk != null:
			killed = int(vk)
		if total > 0 and killed >= total and not GameState.get_story_flag("victory_triggered"):
			GameState.set_story_flag("victory_triggered", true)
			call_deferred("_trigger_victory")


func _spawn_story_planet_deferred(pos: Vector2) -> void:
	var planet := planet_scene.instantiate() as Node2D
	planet.global_position = pos
	if planet.has_method("setup"):
		planet.setup("Signal Source", "story_signal_planet", "story_act2")
	if planet.has_signal("landed"):
		planet.landed.connect(_on_planet_landed)
	get_parent().add_child(planet)
	_spawned_objects.append(planet)
	GameState.map_discovered_planets["story_signal_planet"] = {
		"pos_x": pos.x, "pos_y": pos.y, "name": "Signal Source", "color_h": 0.15
	}


func _spawn_command_ship_cluster(center: Vector2) -> void:
	var total := 0
	# 2 battleships + 4 interceptors
	for i in range(2):
		var bs := battleship_scene.instantiate() as Node2D
		bs.global_position = center + Vector2(i * 120 - 60, 0)
		get_parent().add_child(bs)
		_spawned_objects.append(bs)
		if bs.has_signal("died"):
			bs.died.connect(_on_command_ship_enemy_died)
		total += 1
	for i in range(4):
		var ic := interceptor_scene.instantiate() as Node2D
		ic.global_position = center + Vector2.from_angle(i * TAU / 4) * 80
		get_parent().add_child(ic)
		_spawned_objects.append(ic)
		if ic.has_signal("died"):
			ic.died.connect(_on_command_ship_enemy_died)
		total += 1
	GameState.set_story_flag("cmd_total", total)
	GameState.set_story_flag("cmd_killed", 0)
	var hud := get_tree().get_first_node_in_group("hud")
	if is_instance_valid(hud) and hud.has_method("show_notification"):
		hud.show_notification("DOMINATOR COMMAND SHIP DETECTED! Destroy all hostiles!")


func _on_command_ship_enemy_died() -> void:
	var killed: int = 0
	var v: Variant = GameState.get_story_flag("cmd_killed")
	if v != null:
		killed = int(v)
	GameState.set_story_flag("cmd_killed", killed + 1)


func _trigger_victory() -> void:
	GameState.complete_quest("story_act3")
	_apply_reward({"credits": 1000})
	call_deferred("_open_end_screen", true)


func _apply_reward(reward: Dictionary) -> void:
	for key in reward:
		if key == "credits":
			GameState.add_credits(int(reward[key]))
		elif key == "fuel":
			GameState.add_fuel(float(reward[key]))
		else:
			GameState.add_resource(key, int(reward[key]))


func _open_end_screen(victory: bool) -> void:
	var end_scene := load("res://scenes/end_screen.tscn") as PackedScene
	if end_scene:
		var end: Node = end_scene.instantiate()
		if end.has_method("setup"):
			end.setup(victory)
		get_parent().add_child(end)


func _on_player_died_for_end_screen() -> void:
	call_deferred("_open_end_screen", false)
