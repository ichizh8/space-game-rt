extends Node2D

var _sector_id: int = 1
var _spawned_objects: Array = []
var _respawn_zones: Array = []
# Zone format: {center_x, center_y, enemy_type, max_count, timer, interval, enemies: Array}

var _story_check_timer: float = 0.0
const STORY_CHECK_INTERVAL: float = 0.5
var _pending_initial_spawns: bool = false

# Scene paths
const PLANET_SCENE: String = "res://scenes/planet.tscn"
const STAR_SCENE: String = "res://scenes/star.tscn"
const STATION_SCENE: String = "res://scenes/space_station.tscn"
const ASTEROID_SCENE: String = "res://scenes/asteroid.tscn"
const WARP_GATE_SCENE: String = "res://scenes/warp_gate.tscn"
const ENEMY_SCENE: String = "res://scenes/enemy.tscn"
const BLACK_HOLE_SCENE: String = "res://scenes/black_hole.tscn"
const INTERCEPTOR_SCENE: String = "res://scenes/interceptor.tscn"
const BATTLESHIP_SCENE: String = "res://scenes/battleship.tscn"
const MINER_SCENE: String = "res://scenes/miner_npc.tscn"
const FREIGHTER_SCENE: String = "res://scenes/cargo_freighter.tscn"
const DERELICT_SCENE: String = "res://scenes/derelict.tscn"
const COALITION_SCENE: String = "res://scenes/coalition_patrol.tscn"
const CORSAIR_SCENE: String = "res://scenes/corsair_raider.tscn"
const SCIENCE_SCENE: String = "res://scenes/science_vessel.tscn"
const DRIFTER_SCENE: String = "res://scenes/drifter_shuttle.tscn"


func _ready() -> void:
	add_to_group("sector_loader")
	_sector_id = int(GameState.get("current_sector")) if GameState.get("current_sector") != null else 1
	call_deferred("_load_sector")
	call_deferred("_connect_signals_deferred")


func _process(delta: float) -> void:
	if _pending_initial_spawns:
		_pending_initial_spawns = false
		_do_initial_spawns()
	_tick_respawns(delta)
	_story_check_timer += delta
	if _story_check_timer >= STORY_CHECK_INTERVAL:
		_story_check_timer = 0.0
		_check_story_triggers()
		_discover_nearby_planets()

func _do_initial_spawns() -> void:
	for i in range(_respawn_zones.size()):
		var zone: Dictionary = _respawn_zones[i]
		for _j in range(int(zone.get("max_count", 0))):
			_spawn_zone_enemy(i)


func _get_sector_data() -> Node:
	var path: String = "res://data/sector_" + str(_sector_id) + ".gd"
	var script_res: Script = load(path) as Script
	if script_res == null:
		return null
	var data: Node = script_res.new() as Node
	return data


func _load_sector() -> void:
	var data: Node = _get_sector_data()
	if data == null:
		push_error("SectorLoader: could not load sector " + str(_sector_id))
		return

	var parent: Node = get_parent()

	# Position player ship at spawn point
	var ship: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(ship):
		var spawn: Vector2 = data.get("PLAYER_SPAWN") if data.get("PLAYER_SPAWN") != null else Vector2.ZERO
		if GameState.saved_player_pos != Vector2.ZERO:
			spawn = GameState.saved_player_pos
			GameState.saved_player_pos = Vector2.ZERO  # consume once
		ship.global_position = spawn

	# Place sun
	var sun_data: Dictionary = data.get("SUN") if data.get("SUN") != null else {}
	if not sun_data.is_empty():
		_place_sun(sun_data, parent)

	# Place planets
	var planets: Array = data.get("PLANETS") if data.get("PLANETS") != null else []
	for p in planets:
		_place_planet(p, parent)

	# Place stations
	var stations: Array = data.get("STATIONS") if data.get("STATIONS") != null else []
	for s in stations:
		_place_station(s, parent)

	# Place black holes
	var black_holes: Array = data.get("BLACK_HOLES") if data.get("BLACK_HOLES") != null else []
	for bh in black_holes:
		_place_black_hole(bh, parent)

	# Place asteroid clusters + set up respawn zones
	var clusters: Array = data.get("ASTEROID_CLUSTERS") if data.get("ASTEROID_CLUSTERS") != null else []
	for cluster in clusters:
		_place_asteroid_cluster(cluster, parent)

	# Place warp gates
	var gates: Array = data.get("WARP_GATES") if data.get("WARP_GATES") != null else []
	for g in gates:
		_place_warp_gate(g, parent)

	# Set up ambient enemy zones
	var ambient: Array = data.get("AMBIENT_ENEMIES") if data.get("AMBIENT_ENEMIES") != null else []
	for a in ambient:
		var zone: Dictionary = {
			"center_x": float(a.get("pos_x", 0.0)),
			"center_y": float(a.get("pos_y", 0.0)),
			"enemy_type": str(a.get("enemy_type", "pirate")),
			"max_count": int(a.get("count", 2)),
			"timer": 0.0,
			"interval": 90.0,
			"enemies": []
		}
		_respawn_zones.append(zone)
	_pending_initial_spawns = true

	# Spawn civilian NPCs
	call_deferred("_spawn_civilian_npcs")

	# Free data node (not in tree, safe to free)
	data.free()


func _place_sun(sun_data: Dictionary, parent: Node) -> void:
	var star_scene: PackedScene = load(STAR_SCENE) as PackedScene
	if star_scene == null:
		return
	var star: Node2D = star_scene.instantiate() as Node2D
	if star == null:
		return
	var pos: Vector2 = sun_data.get("pos") if sun_data.get("pos") != null else Vector2.ZERO
	star.global_position = pos
	# add_child first so _ready runs, then override randomized values
	parent.add_child(star)
	var radius: float = float(sun_data.get("radius", 45.0))
	star.set("star_radius", radius)
	var sun_name: String = str(sun_data.get("name", "Star"))
	star.set("star_name", sun_name)
	star.queue_redraw()
	_spawned_objects.append(star)


func _place_planet(p: Dictionary, parent: Node) -> void:
	var planet_scene: PackedScene = load(PLANET_SCENE) as PackedScene
	if planet_scene == null:
		return
	var planet: Node2D = planet_scene.instantiate() as Node2D
	if planet == null:
		return
	planet.global_position = Vector2(float(p.get("pos_x", 0.0)), float(p.get("pos_y", 0.0)))
	# Set planet properties directly (don't call setup — it randomizes radius)
	var p_name: String = str(p.get("name", "Unknown"))
	var p_id: String = str(p.get("planet_id", "unknown"))
	planet.set("planet_name", p_name)
	planet.set("planet_id", p_id)
	planet.set("quest_id", WorldData.get_random_quest_id())
	# Set radius from data
	var radius: float = float(p.get("radius", 30.0))
	planet.set("planet_radius", radius)
	# Set color from RGB data
	var cr: float = float(p.get("color_r", 0.5))
	var cg: float = float(p.get("color_g", 0.5))
	var cb: float = float(p.get("color_b", 0.5))
	var pcolor: Color = Color(cr, cg, cb)
	planet.set("planet_color", pcolor)
	planet.set("_color_h", pcolor.h)
	# Add to tree
	parent.add_child(planet)
	# Connect landed signal for planet menu
	if planet.has_signal("landed"):
		planet.landed.connect(_on_planet_landed)
	_spawned_objects.append(planet)


func _place_station(s: Dictionary, parent: Node) -> void:
	var station_scene: PackedScene = load(STATION_SCENE) as PackedScene
	if station_scene == null:
		return
	var station: Node2D = station_scene.instantiate() as Node2D
	if station == null:
		return
	station.global_position = Vector2(float(s.get("pos_x", 0.0)), float(s.get("pos_y", 0.0)))
	var s_name: String = str(s.get("name", "Station"))
	var s_id: String = str(s.get("station_id", s_name.replace(" ", "_").to_lower()))
	if station.has_method("setup"):
		station.setup(s_id, s_name)
	parent.add_child(station)
	# Connect docked signal for station menu
	if station.has_signal("docked"):
		station.docked.connect(_on_station_docked)
	# Always reveal The Drifting Spoon on the map so player can navigate to it
	if s_id == "drifting_spoon":
		var sp: Vector2 = Vector2(float(s.get("pos_x", 0.0)), float(s.get("pos_y", 0.0)))
		GameState.map_discovered_planets["drifting_spoon"] = {
			"pos_x": sp.x, "pos_y": sp.y,
			"name": "The Drifting Spoon", "color_h": 0.12
		}
	_spawned_objects.append(station)


func _place_black_hole(bh: Dictionary, parent: Node) -> void:
	var bh_scene: PackedScene = load(BLACK_HOLE_SCENE) as PackedScene
	if bh_scene == null:
		return
	var obj: Node2D = bh_scene.instantiate() as Node2D
	if obj == null:
		return
	obj.global_position = Vector2(float(bh.get("pos_x", 0.0)), float(bh.get("pos_y", 0.0)))
	parent.add_child(obj)
	_spawned_objects.append(obj)


func _place_asteroid_cluster(cluster: Dictionary, parent: Node) -> void:
	var asteroid_scene: PackedScene = load(ASTEROID_SCENE) as PackedScene
	if asteroid_scene == null:
		return
	var center: Vector2 = Vector2(float(cluster.get("pos_x", 0.0)), float(cluster.get("pos_y", 0.0)))
	var count: int = int(cluster.get("count", 8))
	var spread: float = float(cluster.get("spread", 200.0))
	var resources_str: String = str(cluster.get("resources", "ore"))
	var resource_list: Array = resources_str.split(",")
	for i in range(count):
		var angle: float = randf() * TAU
		var dist: float = randf() * spread
		var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * dist
		var asteroid: Node2D = asteroid_scene.instantiate() as Node2D
		if asteroid == null:
			continue
		asteroid.global_position = pos
		# Override resource type with our data
		var res_idx: int = randi() % resource_list.size()
		var res_type: String = resource_list[res_idx].strip_edges()
		if asteroid.get("resource_type") != null:
			asteroid.set("resource_type", res_type)
		# Vary size slightly
		var size_scale: float = randf_range(0.7, 1.4)
		asteroid.scale = Vector2(size_scale, size_scale)
		parent.add_child(asteroid)
		_spawned_objects.append(asteroid)
	# Set up respawn zone for pirates
	var pirate_count: int = int(cluster.get("pirates", 0))
	if pirate_count > 0:
		var zone: Dictionary = {
			"center_x": center.x,
			"center_y": center.y,
			"enemy_type": "pirate",
			"max_count": pirate_count,
			"timer": float(randi_range(5, 20)),
			"interval": 90.0,
			"enemies": []
		}
		_respawn_zones.append(zone)
		# Initial spawn
		for i in range(pirate_count):
			call_deferred("_spawn_zone_enemy", _respawn_zones.size() - 1)


func _place_warp_gate(g: Dictionary, parent: Node) -> void:
	var gate_scene: PackedScene = load(WARP_GATE_SCENE) as PackedScene
	if gate_scene == null:
		return
	var gate: Node2D = gate_scene.instantiate() as Node2D
	if gate == null:
		return
	gate.global_position = Vector2(float(g.get("pos_x", 0.0)), float(g.get("pos_y", 0.0)))
	gate.set("gate_name", str(g.get("name", "Gate")))
	gate.set("dest_sector", int(g.get("dest_sector", 1)))
	gate.set("fuel_cost", int(g.get("fuel_cost", 50)))
	parent.add_child(gate)
	_spawned_objects.append(gate)


func _tick_respawns(delta: float) -> void:
	for i in range(_respawn_zones.size()):
		var zone: Dictionary = _respawn_zones[i]
		# Clean up dead enemies from tracking
		var alive: Array = []
		for e in zone.enemies:
			if is_instance_valid(e) and not e.get("is_dead"):
				alive.append(e)
		zone.enemies = alive
		_respawn_zones[i] = zone
		# Check if we need to spawn more
		if alive.size() < int(zone.max_count):
			zone.timer = float(zone.timer) + delta
			_respawn_zones[i] = zone
			if float(zone.timer) >= float(zone.interval):
				zone.timer = 0.0
				_respawn_zones[i] = zone
				call_deferred("_spawn_zone_enemy", i)


func _get_zone_multiplier(pos: Vector2) -> float:
	var dist: float = pos.length()
	if dist >= 4200.0:
		return 2.2
	elif dist >= 2800.0:
		return 1.7
	elif dist >= 1500.0:
		return 1.3
	return 1.0


func _spawn_zone_enemy(zone_idx: int) -> void:
	if zone_idx >= _respawn_zones.size():
		return
	var zone: Dictionary = _respawn_zones[zone_idx]
	var enemy_type: String = str(zone.enemy_type)
	var scene_path: String = ENEMY_SCENE
	match enemy_type:
		"battleship":
			scene_path = "res://scenes/battleship.tscn"
		"void_sentinel":
			scene_path = "res://scenes/void_sentinel.tscn"
		"interceptor":
			scene_path = INTERCEPTOR_SCENE
		"carrier":
			scene_path = "res://scenes/carrier.tscn"
		_:
			scene_path = ENEMY_SCENE
	var enemy_scene: PackedScene = load(scene_path) as PackedScene
	if enemy_scene == null:
		return
	var enemy: Node2D = enemy_scene.instantiate() as Node2D
	if enemy == null:
		return
	# Random position near cluster center
	var cx: float = float(zone.center_x)
	var cy: float = float(zone.center_y)
	var angle: float = randf() * TAU
	var dist: float = randf_range(100.0, 300.0)
	var spawn_pos: Vector2 = Vector2(cx + cos(angle) * dist, cy + sin(angle) * dist)
	enemy.global_position = spawn_pos
	# Set difficulty based on sector + zone
	if enemy.has_method("setup"):
		var sector_mult: float = 1.0 + float(_sector_id - 1) * 0.4
		var zone_mult: float = _get_zone_multiplier(spawn_pos)
		enemy.call("setup", sector_mult * zone_mult)
	get_parent().add_child(enemy)
	zone.enemies.append(enemy)
	_respawn_zones[zone_idx] = zone


# --- Planet / Station menu handlers (from sector_generator) ---

func _on_planet_landed(p_planet_id: String, p_planet_name: String, p_quest_id: String) -> void:
	call_deferred("_open_planet_menu", p_planet_id, p_planet_name, p_quest_id)


func _open_planet_menu(p_planet_id: String, p_planet_name: String, p_quest_id: String) -> void:
	var planet_menu_scene: PackedScene = load("res://scenes/planet_menu.tscn") as PackedScene
	if planet_menu_scene == null:
		return
	var menu: Node = planet_menu_scene.instantiate()
	menu.setup(p_planet_id, p_planet_name, p_quest_id)
	get_parent().add_child(menu)


func _on_station_docked(s_id: String, s_name: String) -> void:
	call_deferred("_open_station_menu", s_id, s_name)


func _open_station_menu(s_id: String, s_name: String) -> void:
	var menu_scene: PackedScene = load("res://scenes/station_menu.tscn") as PackedScene
	if menu_scene == null:
		return
	var menu: Node = menu_scene.instantiate()
	menu.setup(s_id, s_name)
	get_parent().add_child(menu)


# --- Discover nearby planets for map ---

func _discover_nearby_planets() -> void:
	var player: Node2D = _get_player()
	if not is_instance_valid(player):
		return
	var player_pos: Vector2 = player.global_position
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


# --- Story triggers (from sector_generator) ---

func _connect_signals_deferred() -> void:
	if not GameState.player_died.is_connected(_on_player_died_for_end_screen):
		GameState.player_died.connect(_on_player_died_for_end_screen)


func _check_story_triggers() -> void:
	var player: Node2D = _get_player()
	if not is_instance_valid(player):
		return
	var player_pos: Vector2 = player.global_position
	var dist: float = player_pos.length()

	# Old distress signal arc removed — restaurant story replaced it

	# Act 3: spawn command ship cluster when player is near
	if GameState.story_act == 3 and not GameState.get_story_flag("command_ship_spawned"):
		var cx: float = 2500.0
		var cy: float = 800.0
		var v_x = GameState.get_story_flag("command_ship_pos_x")
		if v_x != null:
			cx = float(v_x)
		var v_y = GameState.get_story_flag("command_ship_pos_y")
		if v_y != null:
			cy = float(v_y)
		var cmd_pos: Vector2 = Vector2(cx, cy)
		if player_pos.distance_to(cmd_pos) < 600.0:
			GameState.set_story_flag("command_ship_spawned", true)
			call_deferred("_spawn_command_ship_cluster", cmd_pos)

	# Act 3: check if command ship cluster destroyed
	if GameState.story_act == 3 and GameState.get_story_flag("command_ship_spawned"):
		var total: int = 0
		var killed: int = 0
		var vt = GameState.get_story_flag("cmd_total")
		if vt != null:
			total = int(vt)
		var vk = GameState.get_story_flag("cmd_killed")
		if vk != null:
			killed = int(vk)
		if total > 0 and killed >= total and not GameState.get_story_flag("victory_triggered"):
			GameState.set_story_flag("victory_triggered", true)
			call_deferred("_trigger_victory")


func _spawn_story_planet_deferred(pos: Vector2) -> void:
	var planet_scene: PackedScene = load(PLANET_SCENE) as PackedScene
	if planet_scene == null:
		return
	var planet: Node2D = planet_scene.instantiate() as Node2D
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
	var battleship_scene: PackedScene = load(BATTLESHIP_SCENE) as PackedScene
	var interceptor_scene: PackedScene = load(INTERCEPTOR_SCENE) as PackedScene
	if battleship_scene == null or interceptor_scene == null:
		return
	var total: int = 0
	for i in range(2):
		var bs: Node2D = battleship_scene.instantiate() as Node2D
		bs.global_position = center + Vector2(i * 120 - 60, 0)
		get_parent().add_child(bs)
		_spawned_objects.append(bs)
		if bs.has_signal("died"):
			bs.died.connect(_on_command_ship_enemy_died)
		total += 1
	for i in range(4):
		var ic: Node2D = interceptor_scene.instantiate() as Node2D
		ic.global_position = center + Vector2.from_angle(i * TAU / 4) * 80
		get_parent().add_child(ic)
		_spawned_objects.append(ic)
		if ic.has_signal("died"):
			ic.died.connect(_on_command_ship_enemy_died)
		total += 1
	GameState.set_story_flag("cmd_total", total)
	GameState.set_story_flag("cmd_killed", 0)
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if is_instance_valid(hud) and hud.has_method("show_notification"):
		hud.show_notification("DOMINATOR COMMAND SHIP DETECTED! Destroy all hostiles!")


func _on_command_ship_enemy_died() -> void:
	var killed: int = 0
	var v = GameState.get_story_flag("cmd_killed")
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
	var end_scene: PackedScene = load("res://scenes/end_screen.tscn") as PackedScene
	if end_scene == null:
		return
	var end: Node = end_scene.instantiate()
	if end.has_method("setup"):
		end.setup(victory)
	get_parent().add_child(end)


func _on_player_died_for_end_screen() -> void:
	call_deferred("_open_end_screen", false)


func _get_player() -> Node2D:
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null


func _spawn_civilian_npcs() -> void:
	var parent: Node = get_parent()
	# Miners: 1-2 per sector
	var miner_scene: PackedScene = load(MINER_SCENE) as PackedScene
	if is_instance_valid(miner_scene):
		var miner_count: int = randi_range(1, 2)
		for i in range(miner_count):
			var miner: Node2D = miner_scene.instantiate() as Node2D
			var angle: float = randf() * TAU
			miner.global_position = Vector2.from_angle(angle) * randf_range(300.0, 800.0)
			parent.add_child(miner)
			_spawned_objects.append(miner)

	# Freighter: 1 per sector
	var freighter_scene: PackedScene = load(FREIGHTER_SCENE) as PackedScene
	if is_instance_valid(freighter_scene):
		var freighter: Node2D = freighter_scene.instantiate() as Node2D
		var angle: float = randf() * TAU
		freighter.global_position = Vector2.from_angle(angle) * randf_range(400.0, 1000.0)
		parent.add_child(freighter)
		_spawned_objects.append(freighter)

	# Derelicts: 1-2 per sector, placed 800-2500px from origin
	var derelict_scene: PackedScene = load(DERELICT_SCENE) as PackedScene
	if is_instance_valid(derelict_scene):
		var derelict_count: int = randi_range(1, 2)
		for i in range(derelict_count):
			var derelict: Node2D = derelict_scene.instantiate() as Node2D
			var angle: float = randf() * TAU
			derelict.global_position = Vector2.from_angle(angle) * randf_range(800.0, 2500.0)
			parent.add_child(derelict)
			_spawned_objects.append(derelict)

	# Coalition patrol: 1-2 per sector, near stations
	var coalition_scene: PackedScene = load(COALITION_SCENE) as PackedScene
	if is_instance_valid(coalition_scene):
		var coalition_count: int = randi_range(1, 2)
		for i in range(coalition_count):
			var npc: Node2D = coalition_scene.instantiate() as Node2D
			var angle: float = randf() * TAU
			npc.global_position = Vector2.from_angle(angle) * randf_range(400.0, 800.0)
			parent.add_child(npc)
			_spawned_objects.append(npc)

	# Corsair raider: 1-3 per sector, near asteroid belt
	var corsair_scene: PackedScene = load(CORSAIR_SCENE) as PackedScene
	if is_instance_valid(corsair_scene):
		var corsair_count: int = randi_range(1, 3)
		for i in range(corsair_count):
			var npc: Node2D = corsair_scene.instantiate() as Node2D
			var angle: float = randf() * TAU
			npc.global_position = Vector2.from_angle(angle) * randf_range(800.0, 2000.0)
			parent.add_child(npc)
			_spawned_objects.append(npc)

	# Science vessel: 0-1 per sector
	var science_scene: PackedScene = load(SCIENCE_SCENE) as PackedScene
	if is_instance_valid(science_scene):
		var science_count: int = randi_range(0, 1)
		for i in range(science_count):
			var npc: Node2D = science_scene.instantiate() as Node2D
			var angle: float = randf() * TAU
			npc.global_position = Vector2.from_angle(angle) * randf_range(600.0, 1500.0)
			parent.add_child(npc)
			_spawned_objects.append(npc)

	# Drifter shuttle: 1-2 per sector
	var drifter_scene: PackedScene = load(DRIFTER_SCENE) as PackedScene
	if is_instance_valid(drifter_scene):
		var drifter_count: int = randi_range(1, 2)
		for i in range(drifter_count):
			var npc: Node2D = drifter_scene.instantiate() as Node2D
			var angle: float = randf() * TAU
			npc.global_position = Vector2.from_angle(angle) * randf_range(300.0, 1200.0)
			parent.add_child(npc)
			_spawned_objects.append(npc)
