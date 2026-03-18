extends Node

# Ship stats
var hull: float = 300.0
var _dying: bool = false
var max_hull: float = 300.0
var fuel: float = 500.0
var max_fuel: float = 500.0
var credits: int = 9999

# Resources
var resources: Dictionary = {"ore": 50, "crystal": 20, "scrap": 50}

# Inventory (item IDs)
var inventory: Array = []

# Collected artifact IDs
var artifacts_collected: Array = []

# Planet data: planet_id -> {buildings: {}, storage: {}, quests_done: [], last_visit_time: 0}
var planets: Dictionary = {}

# Player bonuses from artifacts
var player_speed_bonus: float = 120.0
var player_damage_bonus: float = 0.0
var player_mining_speed_bonus: float = 0.0

# Captain progression (persistent — never reset on death)
var captain_xp: int = 0
var captain_perk_points_earned: int = 0   # total earned = captain_xp // 100
var captain_perks: Array[String] = []      # list of unlocked perk IDs
# Captain stat bonuses (from perks, persistent)
var captain_hull_bonus: float = 0.0
var captain_damage_bonus: float = 0.0
var captain_mining_bonus: float = 0.0     # multiplier on top: yield * (1 + captain_mining_bonus)
var captain_fuel_efficiency: float = 0.0  # reduces fuel drain: drain * (1 - captain_fuel_efficiency)
var captain_sell_bonus: float = 0.0       # sell price multiplier: price * (1 + captain_sell_bonus)

# Map state
var map_visited_trail: Array[Vector2] = []   # session-only
var map_discovered_planets: Dictionary = {}   # persistent: planet_id -> {pos_x, pos_y, name, color_h}
var map_waypoint: Vector2 = Vector2(1e9, 1e9)  # set via cockpit map tap; sentinel = no waypoint

# Faction reputation (0–100)
var faction_rep: Dictionary = {
	"coalition": 50, "corsairs": 20, "miners": 40,
	"scientists": 30, "drifters": 60, "independents": 50
}

# Quest system
var active_quests: Array = []
var completed_quests: Array = []
var tracked_quest_id: String = ""

# Session stats
var session_kills: int = 0
var session_artifacts: int = 0

# Storyline
var story_act: int = 1
var story_flags: Dictionary = {}

# Ship upgrade levels (0-10 each)
var weapon_level: int = 0
var speed_level: int = 0
var shield_level: int = 0

# Last planet the player visited (for respawn)
var last_planet_id: String = ""
# Saved spawn position restored from save file (consumed on use)
var saved_player_pos: Vector2 = Vector2.ZERO

# Sector system
var current_sector: int = 1

# Restaurant system
var restaurant_rep: int = 0
var restaurant_ingredients: Dictionary = {}
var restaurant_name: String = "The Drifting Spoon"
var restaurant_owned: bool = false    # unlocked by intro quest, persistent
var restaurant_unlocked_dishes: Array = ["dish_mystery_patty"]

# Ingredient tier system
var ingredient_tiers: Dictionary = {
	"grub_meat":      {"tier": 1, "name": "Grub Meat",                    "creature": "void_grub"},
	"grub_fat":       {"tier": 1, "name": "Grub Fat",                     "creature": "void_grub"},
	"ray_fillet":     {"tier": 1, "name": "Skim Ray Fillet",              "creature": "skim_ray"},
	"ray_membrane":   {"tier": 1, "name": "Ray Membrane",                 "creature": "skim_ray"},
	"snarler_haunch": {"tier": 1, "name": "Snarler Haunch",               "creature": "pack_snarler"},
	"scrap_protein":  {"tier": 1, "name": "Scrap Protein",                "creature": "any"},
	"drifter_organ":  {"tier": 2, "name": "Drifter Organ",                "creature": "membrane_drifter"},
	"drifter_gel":    {"tier": 2, "name": "Drifter Bioluminescent Gel",   "creature": "membrane_drifter"},
	"feeder_flesh":   {"tier": 2, "name": "Crystal Feeder Flesh",         "creature": "crystal_feeder"},
	"crystal_extract":{"tier": 2, "name": "Crystal Extract",              "creature": "crystal_feeder"},
	"snarler_gland":  {"tier": 2, "name": "Snarler Venom Gland",         "creature": "pack_snarler"},
	"leviathan_cut":  {"tier": 3, "name": "Leviathan Medallion Cut",      "creature": "void_leviathan"},
	"leviathan_marrow":{"tier": 3, "name": "Leviathan Marrow",            "creature": "void_leviathan"},
	"void_crystal_blood":{"tier": 3, "name": "Void-Crystallized Blood",   "creature": "void_leviathan"},
	"feeder_bioluminescence":{"tier": 3, "name": "Bioluminescent Secretion","creature": "crystal_feeder"},
}
var zone_depth: int = 1  # 1=shallow, 2=mid, 3=deep
var active_hunting_zone: String = ""  # id of zone player is currently inside, "" = none

# Zone maps purchased at stations (persistent)
var purchased_zone_maps: Array = []
var starter_maps_claimed: bool = false

# Hunting zone definitions for sector 1
var hunting_zones_sector1: Array = [
	{"id": "hunt_void_grubs",  "label": "Void Grub Nesting Area",            "pos_x": 600.0,   "pos_y": 1400.0,  "color_h": 0.25, "radius": 400.0},
	{"id": "hunt_skim_rays",   "label": "Skim Ray Feeding Zone",              "pos_x": -400.0,  "pos_y": 1800.0,  "color_h": 0.55, "radius": 400.0},
	{"id": "hunt_snarlers",    "label": "Pack Snarler Debris Field",          "pos_x": 1600.0,  "pos_y": 600.0,   "color_h": 0.08, "radius": 350.0},
	{"id": "hunt_drifters",    "label": "Nebula — Membrane Drifter Territory","pos_x": -1800.0, "pos_y": 2200.0,  "color_h": 0.65, "radius": 500.0},
	{"id": "hunt_feeders",     "label": "Crystal Feeder Cluster",             "pos_x": -1200.0, "pos_y": -800.0,  "color_h": 0.45, "radius": 400.0},
	{"id": "hunt_leviathan",   "label": "Deep Space — Leviathan Waters",      "pos_x": 3000.0,  "pos_y": 1500.0,  "color_h": 0.78, "radius": 600.0},
]

# Cooking / experiment system
var cooking_methods: Array = [
	{"id": "char_grill",       "name": "Char-Grill",               "desc": "Fast, smoky. Miners approve."},
	{"id": "slow_boil",        "name": "Slow Boil",                "desc": "Safe. Unremarkable."},
	{"id": "plasma_roast",     "name": "Plasma Roast",             "desc": "Repurposed weapon tech. Caramelizes void components."},
	{"id": "cold_press",       "name": "Cold Press",               "desc": "Raw preparation. Corsairs respect the commitment."},
	{"id": "molecular_decon",  "name": "Molecular Deconstruction", "desc": "Technically a weapon. Produces foam and a very small plate."},
	{"id": "deep_freeze",      "name": "Deep Freeze Flash",        "desc": "Locks in bioluminescence. Dish glows. Safety unclear."},
]
var serving_styles: Array = [
	{"id": "fast_food",     "name": "Fast Food Tray",    "desc": "Volume play. Miners and Corsair grunts approve."},
	{"id": "diner",         "name": "Diner Plate",        "desc": "Default. Works for everyone. Peaks nowhere."},
	{"id": "high_cuisine",  "name": "High Cuisine",       "desc": "Small portions, large plates. Critics pay triple."},
	{"id": "street_cart",   "name": "Street Cart Style",  "desc": "Corsairs feel at home. Scientists ask about the wrapper."},
	{"id": "the_experiment","name": "The Experiment",     "desc": "Served with a card: we don't know what this is."},
]
var discovered_recipes: Dictionary = {}

# Faction dietary profiles
var faction_dietary: Dictionary = {
	"coalition":   {"loves": ["slow_boil", "diner"],              "hates": ["the_experiment", "cold_press"]},
	"corsairs":    {"loves": ["cold_press", "char_grill", "street_cart"], "hates": ["molecular_decon", "high_cuisine"]},
	"miners":      {"loves": ["char_grill", "fast_food"],         "hates": ["molecular_decon", "high_cuisine"]},
	"scientists":  {"loves": ["molecular_decon", "cold_press"],   "hates": ["char_grill"]},
	"drifters":    {"loves": [],                                   "hates": []},
	"independents":{"loves": [],                                   "hates": []},
}

# Guest log
var guest_log: Array = []           # past sessions, max 20
var special_guests_seen: Array = [] # IDs of specials who visited
var pending_guests: Array = []      # generated on departure, resolved on dock

# Prepared dishes (cooked, waiting to be served)
var prepared_dishes: Array = []
# Each entry: {"name": String, "method": String, "style": String, "credits_value": int, "rep_value": int, "tier": int, "menu_story": String}

# Cooksta
var cooksta_rating: int = 0
var cooksta_posts: Array = []  # max 10

signal hull_changed(new_value: float)
signal fuel_changed(new_value: float)
signal credits_changed(new_value: int)
signal resources_changed()
signal player_died()
signal xp_gained(new_total: int)
signal perk_unlocked(perk_id: String)
signal restaurant_rep_changed(new_value: int)
signal restaurant_ingredients_changed()
signal ingredient_dropped(ing_name: String)
signal guests_generated()
signal prepared_dishes_changed()


func add_resource(type: String, amount: int) -> void:
	if type == "fuel":
		add_fuel(float(amount) * 10.0)  # 1 fuel canister = +10 ship fuel
		return
	if resources.has(type):
		resources[type] += amount
		resources_changed.emit()


func remove_resource(type: String, amount: int) -> bool:
	if resources.has(type) and resources[type] >= amount:
		resources[type] -= amount
		resources_changed.emit()
		return true
	return false


func has_resources(cost: Dictionary) -> bool:
	for key in cost:
		if key == "credits":
			if credits < cost[key]:
				return false
		elif not resources.has(key) or resources[key] < cost[key]:
			return false
	return true


func spend_resources(cost: Dictionary) -> bool:
	if not has_resources(cost):
		return false
	for key in cost:
		if key == "credits":
			credits -= int(cost[key])
			credits_changed.emit()
		else:
			resources[key] -= int(cost[key])
	resources_changed.emit()
	return true


func take_damage(amount: float) -> void:
	if _dying:
		return
	if has_perk("last_stand") and hull / max_hull < 0.2:
		amount *= 0.7
	hull -= amount
	hull = max(hull, 0.0)
	hull_changed.emit(hull)
	if hull <= 0.0 and not _dying:
		_dying = true
		call_deferred("on_player_death")


func heal(amount: float) -> void:
	hull = min(hull + amount, max_hull)
	hull_changed.emit(hull)


func use_fuel(amount: float) -> void:
	fuel -= amount
	fuel = max(fuel, 0.0)
	fuel_changed.emit(fuel)


func add_fuel(amount: float) -> void:
	fuel = min(fuel + amount, max_fuel)
	fuel_changed.emit(fuel)


func add_credits(amount: int) -> void:
	credits += amount
	credits_changed.emit(credits)


func collect_artifact(artifact_data: Dictionary) -> void:
	if artifact_data["id"] in artifacts_collected:
		return
	artifacts_collected.append(artifact_data["id"])
	var bonus: Dictionary = artifact_data.get("bonus", {})
	for key in bonus:
		if key == "player_speed_bonus":
			player_speed_bonus += float(bonus[key])
		elif key == "player_damage_bonus":
			player_damage_bonus += float(bonus[key])
		elif key == "player_mining_speed_bonus":
			player_mining_speed_bonus += float(bonus[key])


func get_planet_data(planet_id: String) -> Dictionary:
	if not planets.has(planet_id):
		planets[planet_id] = {
			"buildings": {},
			"storage": {"ore": 0, "crystal": 0, "scrap": 0},
			"quests_done": [],
			"last_visit_time": Time.get_unix_time_from_system()
		}
	return planets[planet_id]


func on_player_death() -> void:
	_dying = false
	# Award captain XP before reset
	var death_xp: int = session_kills * 5 + session_artifacts * 20
	if death_xp > 0:
		add_xp(death_xp)
	hull = max_hull
	fuel = max_fuel
	# Credit penalty: lose 25%
	credits = int(credits * 0.75)
	credits_changed.emit(credits)
	# Lose some resources on death
	for key in resources:
		resources[key] = int(resources[key] * 0.5)
	resources_changed.emit()
	hull_changed.emit(hull)
	fuel_changed.emit(fuel)
	# Lose ingredients on death
	restaurant_ingredients = {}
	restaurant_ingredients_changed.emit()
	# Respawn at nearest station
	var respawn: Vector2 = _find_nearest_station_pos()
	if respawn != Vector2.ZERO:
		saved_player_pos = respawn
	player_died.emit()


func _find_nearest_station_pos() -> Vector2:
	var sector_script = load("res://data/sector_%d.gd" % current_sector)
	if sector_script == null:
		return Vector2.ZERO
	var sector_node := Node.new()
	sector_node.set_script(sector_script)
	var stations: Array = sector_node.get("STATIONS")
	sector_node.free()
	if stations == null or stations.is_empty():
		return Vector2.ZERO
	var origin: Vector2 = saved_player_pos if saved_player_pos != Vector2.ZERO else Vector2.ZERO
	var best_pos: Vector2 = Vector2.ZERO
	var best_dist: float = INF
	for s in stations:
		var sp := Vector2(float(s.get("pos_x", 0)), float(s.get("pos_y", 0)))
		var d: float = origin.distance_squared_to(sp)
		if d < best_dist:
			best_dist = d
			best_pos = sp
	return best_pos


func reset_run() -> void:
	# Reset run-specific state but keep captain progression
	hull = max_hull
	fuel = max_fuel
	# credits intentionally NOT reset here — death penalty already applied in on_player_death()
	# New game resets credits via reset_game() instead
	resources = {"ore": 0, "crystal": 0, "scrap": 0}
	inventory = []
	artifacts_collected = []
	planets = {}
	weapon_level = 0
	speed_level = 0
	shield_level = 0
	player_speed_bonus = 0.0
	player_damage_bonus = 0.0
	player_mining_speed_bonus = 0.0
	last_planet_id = ""
	map_visited_trail = []
	session_kills = 0
	session_artifacts = 0
	current_sector = 1
	story_act = 1
	story_flags = {}
	active_quests = []
	faction_rep = {"coalition": 50, "corsairs": 20, "miners": 40, "scientists": 30, "drifters": 60, "independents": 50}
	_dying = false
	hull_changed.emit(hull)
	fuel_changed.emit(fuel)
	credits_changed.emit(credits)
	resources_changed.emit()


func add_xp(amount: int) -> void:
	captain_xp += amount
	var new_earned := captain_xp / 100
	if new_earned > captain_perk_points_earned:
		captain_perk_points_earned = new_earned
	xp_gained.emit(captain_xp)


func get_available_perk_points() -> int:
	return captain_perk_points_earned - captain_perks.size()


func has_perk(perk_id: String) -> bool:
	return perk_id in captain_perks


func unlock_perk(perk_id: String) -> bool:
	if has_perk(perk_id):
		return false
	if get_available_perk_points() <= 0:
		return false
	captain_perks.append(perk_id)
	_apply_perk(perk_id)
	perk_unlocked.emit(perk_id)
	return true


func _apply_perk(perk_id: String) -> void:
	match perk_id:
		"iron_will":      captain_hull_bonus += 20.0; max_hull += 20.0; hull = min(hull + 20.0, max_hull); hull_changed.emit(hull)
		"steady_aim":     captain_damage_bonus += 8.0
		"last_stand":     pass  # checked at damage time, no stat change
		"efficient_miner": captain_mining_bonus += 0.5
		"fuel_saver":     captain_fuel_efficiency += 0.25
		"salvager":       pass  # checked in enemy die, no stat change
		"keen_eye":       pass  # checked in hud proximity, no stat change
		"negotiator":     captain_sell_bonus += 0.25
		"lucky_find":     pass  # checked in artifact spawn, no stat change


func reapply_all_perks() -> void:
	# Called on load to restore perk stat effects
	captain_hull_bonus = 0.0
	captain_damage_bonus = 0.0
	captain_mining_bonus = 0.0
	captain_fuel_efficiency = 0.0
	captain_sell_bonus = 0.0
	for perk_id in captain_perks:
		_apply_perk(perk_id)
	max_hull = 100.0 + captain_hull_bonus
	hull = min(hull, max_hull)


func map_record_position(player_pos: Vector2) -> void:
	const SPACING := 80.0
	const MAX_POINTS := 600
	if map_visited_trail.is_empty() or player_pos.distance_to(map_visited_trail[-1]) > SPACING:
		map_visited_trail.append(player_pos)
		if map_visited_trail.size() > MAX_POINTS:
			map_visited_trail.remove_at(0)


func map_discover_planet(planet_id: String, pos: Vector2, p_name: String, color_h: float) -> void:
	if not map_discovered_planets.has(planet_id):
		map_discovered_planets[planet_id] = {
			"pos_x": pos.x, "pos_y": pos.y,
			"name": p_name, "color_h": color_h
		}


func reveal_zone_map(zone_key: String) -> void:
	if zone_key in purchased_zone_maps:
		return
	purchased_zone_maps.append(zone_key)
	for zone in hunting_zones_sector1:
		if zone.get("id", "") == zone_key:
			var zpos_x: float = float(zone.get("pos_x", 0.0))
			var zpos_y: float = float(zone.get("pos_y", 0.0))
			var zlabel: String = str(zone.get("label", ""))
			var zcolor: float = float(zone.get("color_h", 0.3))
			if not map_discovered_planets.has(zone_key):
				map_discovered_planets[zone_key] = {
					"pos_x": zpos_x, "pos_y": zpos_y,
					"name": zlabel, "color_h": zcolor
				}
			return


func map_note_biome(_pos: Vector2, _biome_id: int) -> void:
	pass  # future: visualize biomes on cockpit map


func add_faction_rep(faction: String, amount: int) -> void:
	if faction_rep.has(faction):
		faction_rep[faction] = clamp(faction_rep[faction] + amount, 0, 100)


func accept_quest(quest_data: Dictionary, source_id: String = "") -> bool:
	if active_quests.size() >= 3:
		return false
	for q in active_quests:
		if q["id"] == quest_data["id"]:
			return false
	var q_copy: Dictionary = quest_data.duplicate(true)
	if source_id != "":
		q_copy["source_id"] = source_id
	active_quests.append(q_copy)
	apply_quest_map_markers(quest_data)
	return true


func update_quest_progress(quest_type: String, amount: int = 1) -> void:
	for q in active_quests:
		if q.get("type") == quest_type:
			q["progress"] = q.get("progress", 0) + amount
	# Auto-complete destroy quests that hit their target
	var to_complete: Array = []
	for q in active_quests:
		if q.get("type") == quest_type and q.get("type") == "destroy":
			if q.get("progress", 0) >= q.get("required", 999):
				to_complete.append(q["id"])
	for qid in to_complete:
		var reward: Dictionary = complete_quest(qid)
		for key in reward:
			if key == "credits":
				add_credits(int(reward[key]))
			elif key == "fuel":
				add_fuel(float(reward[key]))
			elif key == "faction_coalition":
				add_faction_rep("coalition", int(reward[key]))
			elif key == "faction_pirates":
				add_faction_rep("pirates", int(reward[key]))
			else:
				add_resource(key, int(reward[key]))


func complete_quest(quest_id: String) -> Dictionary:
	for i in range(active_quests.size()):
		if active_quests[i]["id"] == quest_id:
			var q = active_quests[i]
			active_quests.remove_at(i)
			if quest_id not in completed_quests:
				completed_quests.append(quest_id)
			# Look up full quest data for bonus rewards
			var full_quest: Dictionary = {}
			if is_instance_valid(WorldData):
				full_quest = WorldData.get_quest_by_id(quest_id)
			if not full_quest.is_empty():
				apply_quest_map_markers(full_quest)
				apply_quest_gives_recipe(full_quest)
			return q.get("reward", {})
	return {}


func abandon_quest(quest_id: String) -> void:
	for i in range(active_quests.size()):
		if active_quests[i]["id"] == quest_id:
			active_quests.remove_at(i)
			return


func get_quest_progress(quest_id: String) -> Dictionary:
	for q in active_quests:
		if q["id"] == quest_id:
			return q
	return {}


func is_quest_active(quest_id: String) -> bool:
	return not get_quest_progress(quest_id).is_empty()


func is_quest_completed(quest_id: String) -> bool:
	return quest_id in completed_quests


func record_kill() -> void:
	session_kills += 1
	add_faction_rep("coalition", 1)
	update_quest_progress("destroy")


func record_artifact() -> void:
	session_artifacts += 1


func get_session_score() -> int:
	return credits + session_kills * 15 + session_artifacts * 150


func set_story_flag(flag: String, value = true) -> void:
	story_flags[flag] = value


func get_story_flag(flag: String):
	return story_flags.get(flag, null)


func travel_to_sector(sector_id: int) -> void:
	current_sector = sector_id
	SaveManager.save_game()
	get_tree().reload_current_scene()


func reset_game() -> void:
	max_hull = 300.0 + captain_hull_bonus
	hull = max_hull
	max_fuel = 500.0
	fuel = max_fuel
	credits = 9999
	resources = {"ore": 0, "crystal": 0, "scrap": 0}
	inventory = []
	artifacts_collected = []
	planets = {}
	# do NOT touch: captain_xp, captain_perk_points_earned, captain_perks, captain_* bonuses
	weapon_level = 0
	speed_level = 0
	shield_level = 0
	player_speed_bonus = 0.0
	player_damage_bonus = 0.0
	player_mining_speed_bonus = 0.0
	last_planet_id = ""
	saved_player_pos = Vector2.ZERO
	map_visited_trail = []
	# do NOT reset map_discovered_planets
	session_kills = 0
	session_artifacts = 0
	current_sector = 1
	story_act = 1
	story_flags = {}
	active_quests = []
	faction_rep = {"coalition": 50, "corsairs": 20, "miners": 40, "scientists": 30, "drifters": 60, "independents": 50}
	# completed_quests is NOT reset (persistent history)
	# do NOT reset restaurant_rep or restaurant_ingredients (persistent like captain XP)


func add_ingredient(id: String, amount: int) -> void:
	restaurant_ingredients[id] = restaurant_ingredients.get(id, 0) + amount
	restaurant_ingredients_changed.emit()


func remove_ingredient(id: String, amount: int) -> bool:
	if restaurant_ingredients.get(id, 0) < amount:
		return false
	restaurant_ingredients[id] -= amount
	if restaurant_ingredients[id] <= 0:
		restaurant_ingredients.erase(id)
	restaurant_ingredients_changed.emit()
	return true


func has_ingredient(id: String, amount: int) -> bool:
	return restaurant_ingredients.get(id, 0) >= amount


func add_restaurant_rep(amount: int) -> void:
	restaurant_rep = clampi(restaurant_rep + amount, 0, 100)
	restaurant_rep_changed.emit(restaurant_rep)


func add_prepared_dish(dish: Dictionary) -> void:
	prepared_dishes.append(dish)
	prepared_dishes_changed.emit()


func remove_prepared_dish(index: int) -> Dictionary:
	if index < 0 or index >= prepared_dishes.size():
		return {}
	var dish: Dictionary = prepared_dishes[index]
	prepared_dishes.remove_at(index)
	prepared_dishes_changed.emit()
	return dish


func get_best_dish_for_faction(faction: String) -> int:
	if prepared_dishes.is_empty():
		return -1
	var best_idx: int = 0
	var best_score: float = -999.0
	var profile: Dictionary = faction_dietary.get(faction, {})
	var loves: Array = profile.get("loves", [])
	var hates: Array = profile.get("hates", [])
	for i in range(prepared_dishes.size()):
		var dish: Dictionary = prepared_dishes[i]
		var score: float = float(dish.get("tier", 1))
		if dish.get("method", "") in loves or dish.get("style", "") in loves:
			score += 2.0
		if dish.get("method", "") in hates or dish.get("style", "") in hates:
			score -= 3.0
		if score > best_score:
			best_score = score
			best_idx = i
	return best_idx


func get_restaurant_tier() -> String:
	if restaurant_rep < 20:
		return "Shithole Fastfood"
	elif restaurant_rep < 40:
		return "Decent Joint"
	elif restaurant_rep < 60:
		return "Hidden Gem"
	elif restaurant_rep < 80:
		return "Renowned"
	else:
		return "Galaxy Famous"


# ── Ingredient Drop System ──────────────────────────────────────

func get_ingredient_drop_chance(tier: int) -> float:
	match tier:
		1: return 1.0
		2: return 0.3 + (zone_depth - 1) * 0.25
		3: return 0.05 + (zone_depth - 1) * 0.1
	return 0.0


func drop_ingredients(creature_type: String) -> void:
	var drops: Dictionary = {
		"void_grub":        [["grub_meat", 1, 1.0], ["grub_fat", 1, 0.4]],
		"skim_ray":         [["ray_fillet", 1, 1.0], ["ray_membrane", 2, 0.35]],
		"pack_snarler":     [["snarler_haunch", 1, 1.0], ["snarler_gland", 2, 0.3]],
		"membrane_drifter": [["drifter_organ", 2, 0.7], ["drifter_gel", 2, 0.4]],
		"crystal_feeder":   [["feeder_flesh", 2, 0.8], ["crystal_extract", 2, 0.5], ["feeder_bioluminescence", 3, 0.15]],
		"void_leviathan":   [["leviathan_cut", 3, 0.9], ["leviathan_marrow", 3, 0.5], ["void_crystal_blood", 3, 0.3]],
	}
	var creature_drops = drops.get(creature_type, [])
	for drop in creature_drops:
		var ing_id: String = drop[0]
		var ing_tier: int = drop[1]
		var base_chance: float = drop[2]
		var roll_chance: float = base_chance * get_ingredient_drop_chance(ing_tier)
		if randf() <= roll_chance:
			add_ingredient(ing_id, 1)
			var info: Dictionary = ingredient_tiers.get(ing_id, {})
			ingredient_dropped.emit(info.get("name", ing_id))


# ── Quest Map Markers & Recipe Rewards ───────────────────────────

func apply_quest_map_markers(quest: Dictionary) -> void:
	var markers: Array = quest.get("map_markers", [])
	for marker in markers:
		var mid: String = str(marker.get("id", ""))
		var mpos_x: float = float(marker.get("pos_x", 0.0))
		var mpos_y: float = float(marker.get("pos_y", 0.0))
		var mname: String = str(marker.get("label", ""))
		var mcolor: float = float(marker.get("color_h", 0.3))
		if mid != "" and not map_discovered_planets.has(mid):
			map_discovered_planets[mid] = {"pos_x": mpos_x, "pos_y": mpos_y, "name": mname, "color_h": mcolor}


func apply_quest_gives_recipe(quest: Dictionary) -> void:
	var recipe: Dictionary = quest.get("gives_recipe", {})
	if recipe.is_empty():
		return
	var rname: String = str(recipe.get("name", ""))
	var recipe_key: String = "quest_recipe:" + rname
	if not discovered_recipes.has(recipe_key):
		var full_recipe: Dictionary = recipe.duplicate()
		full_recipe["key"] = recipe_key
		if not full_recipe.has("ingredients"):
			full_recipe["ingredients"] = []
		discovered_recipes[recipe_key] = full_recipe


# ── Faction Satisfaction ─────────────────────────────────────────

func get_satisfaction_modifier(faction: String, method: String, style: String) -> float:
	var profile: Dictionary = faction_dietary.get(faction, {})
	var loves: Array = profile.get("loves", [])
	var hates: Array = profile.get("hates", [])
	var mod: float = 1.0
	if method in loves or style in loves:
		mod += 0.5
	if method in hates or style in hates:
		mod -= 0.5
	return clampf(mod, 0.2, 2.0)


# ── Experiment Bench ─────────────────────────────────────────────

func get_bench_slots() -> int:
	if restaurant_rep >= 80:
		return 6
	elif restaurant_rep >= 40:
		return 5
	return 3


func resolve_experiment(ingredients: Array, method: String, style: String) -> Dictionary:
	var sorted_ings: Array = ingredients.duplicate()
	sorted_ings.sort()
	var recipe_key: String = "|".join(sorted_ings) + ":" + method + ":" + style
	if discovered_recipes.has(recipe_key):
		var recipe: Dictionary = discovered_recipes[recipe_key]
		for ing in ingredients:
			remove_ingredient(ing, 1)
		var known_dish: Dictionary = {
			"name": str(recipe.get("name", "Unknown Dish")),
			"method": str(recipe.get("method", method)),
			"style": str(recipe.get("style", style)),
			"credits_value": int(recipe.get("credits", 50)),
			"rep_value": int(recipe.get("rep", 1)),
			"tier": 1,
			"menu_story": str(recipe.get("menu_story", "")),
		}
		for ing in ingredients:
			var t: int = ingredient_tiers.get(ing, {}).get("tier", 1)
			if t > known_dish["tier"]:
				known_dish["tier"] = t
		add_prepared_dish(known_dish)
		return {"result": "known", "recipe": recipe, "dish_added": true}
	var max_tier: int = 1
	for ing in ingredients:
		var t: int = ingredient_tiers.get(ing, {}).get("tier", 1)
		if t > max_tier:
			max_tier = t
	var success_chance: float = 0.5 + (max_tier - 1) * 0.15
	if method == "plasma_roast" and max_tier >= 3:
		success_chance += 0.2
	if method == "molecular_decon" and max_tier >= 2:
		success_chance += 0.25
	if style == "the_experiment":
		success_chance = 1.0
	var roll: float = randf()
	if roll > success_chance:
		for i in range(int(ceil(float(ingredients.size()) / 2.0))):
			remove_ingredient(ingredients[i], 1)
		return {"result": "fail", "message": "Inedible. The smoke detector is now a smoke suggester."}
	var credits_val: int = 30 + max_tier * 40
	if style == "high_cuisine":
		credits_val += 100
	var rep_val: int = max_tier
	var dish_name: String = _generate_dish_name(ingredients, method, style)
	var story: String = _build_menu_story(method, style, "First cooked at The Drifting Spoon.")
	var recipe: Dictionary = {
		"key": recipe_key,
		"name": dish_name,
		"ingredients": ingredients.duplicate(),
		"method": method,
		"style": style,
		"credits": credits_val,
		"rep": rep_val,
		"menu_story": story,
	}
	discovered_recipes[recipe_key] = recipe
	for ing in ingredients:
		remove_ingredient(ing, 1)
	var new_dish: Dictionary = {
		"name": dish_name,
		"method": method,
		"style": style,
		"credits_value": credits_val,
		"rep_value": rep_val,
		"tier": max_tier,
		"menu_story": story,
	}
	add_prepared_dish(new_dish)
	if style == "the_experiment" and roll < 0.2:
		return {"result": "catastrophe", "recipe": recipe, "dish_added": true, "message": "Someone is ill. Data logged. Worth it."}
	return {"result": "discovered", "recipe": recipe, "dish_added": true}


func _generate_dish_name(ingredients: Array, method: String, style: String) -> String:
	var primary: String = ingredients[0] if ingredients.size() > 0 else "mystery"
	var ing_info: Dictionary = ingredient_tiers.get(primary, {})
	var ing_name: String = ing_info.get("name", primary.replace("_", " ").capitalize())
	var method_words: Dictionary = {
		"char_grill": "Charred", "slow_boil": "Braised", "plasma_roast": "Plasma-Seared",
		"cold_press": "Raw-Pressed", "molecular_decon": "Deconstructed", "deep_freeze": "Luminescent"
	}
	var style_words: Dictionary = {
		"fast_food": "", "diner": "", "high_cuisine": " en Vide",
		"street_cart": " Wrap", "the_experiment": " (Unknown)"
	}
	var prefix: String = method_words.get(method, "Cooked")
	var suffix: String = style_words.get(style, "")
	if ingredients.size() > 1:
		var second_info: Dictionary = ingredient_tiers.get(ingredients[1], {})
		var second_name: String = second_info.get("name", "").split(" ")[0]
		if not second_name.is_empty():
			return "%s %s with %s%s" % [prefix, ing_name, second_name, suffix]
	return "%s %s%s" % [prefix, ing_name, suffix]


func _build_menu_story(method: String, style: String, context: String) -> String:
	var method_name: String = method.replace("_", " ").capitalize()
	var style_name: String = style.replace("_", " ").capitalize()
	for m in cooking_methods:
		if m["id"] == method:
			method_name = m["name"]
	for s in serving_styles:
		if s["id"] == style:
			style_name = s["name"]
	return "%s. %s presentation. %s" % [method_name, style_name, context]


# ── Guest System ─────────────────────────────────────────────────

func generate_guest_session() -> void:
	if not pending_guests.is_empty():
		return  # already waiting
	var guests: Array = []
	var count: int = randi_range(2, 5)
	var eligible_specials: Array = _get_eligible_special_guests()
	if not eligible_specials.is_empty() and randf() < 0.35:
		guests.append(eligible_specials[randi() % eligible_specials.size()])
	while guests.size() < count:
		guests.append(_generate_procedural_guest())
	pending_guests = guests
	guests_generated.emit()


func _get_eligible_special_guests() -> Array:
	var specials: Array = []
	if faction_rep.get("corsairs", 0) >= 40 and "velka_orin" not in special_guests_seen:
		specials.append({
			"id": "velka_orin", "special": true, "name": "Velka Orin",
			"faction": "corsairs", "role": "Food Critic",
			"intro": "She doesn't sit — she surveys. Then sits.",
			"wants": "leviathan_cut", "choice_id": "velka_first_visit"
		})
	if faction_rep.get("coalition", 0) >= 60 and "commissioner_drath" not in special_guests_seen:
		specials.append({
			"id": "commissioner_drath", "special": true, "name": "Commissioner Drath",
			"faction": "coalition", "role": "Trade Inspector",
			"intro": "He has a clipboard. He is using it.",
			"wants": "", "choice_id": "drath_first_visit"
		})
	return specials


func _generate_procedural_guest() -> Dictionary:
	var archetypes: Array = ["Hungry Spacer", "Supply Runner", "Off-Duty Soldier", "Debt Runner", "Tourist", "Passing Through"]
	var traits: Array = ["suspicious", "generous", "chatty", "paranoid", "snobbish", "adventurous"]
	var faction: String = _weighted_faction_pick()
	var archetype: String = archetypes[randi() % archetypes.size()]
	var trait_val: String = traits[randi() % traits.size()]
	var first_names: Array = ["Korr", "Vex", "Mira", "Taln", "Desh", "Yura", "Brenn", "Solek", "Ash", "Calix", "Driva", "Finn"]
	var last_names: Array = ["of Sector 4", "the Wanderer", "ex-Coalition", "no-name", "Drifter", "Outpost-born", "void-touched"]
	var name_str: String = first_names[randi() % first_names.size()] + " " + last_names[randi() % last_names.size()]
	return {
		"id": "proc_" + str(randi()),
		"special": false,
		"name": name_str,
		"faction": faction,
		"role": archetype,
		"trait": trait_val,
	}


func _weighted_faction_pick() -> String:
	var factions: Array = ["coalition", "corsairs", "miners", "scientists", "drifters", "independents"]

	# Determine what the player can actually make
	var has_t2: bool = false
	var has_t3: bool = false
	for ing_id in restaurant_ingredients.keys():
		if restaurant_ingredients[ing_id] > 0:
			var tier: int = int(ingredient_tiers.get(ing_id, {}).get("tier", 1))
			if tier >= 2:
				has_t2 = true
			if tier >= 3:
				has_t3 = true
	# Also count any prepared dishes
	for pd in prepared_dishes:
		var ptier: int = int(pd.get("tier", 1))
		if ptier >= 2:
			has_t2 = true
		if ptier >= 3:
			has_t3 = true

	var weights: Array = []
	for f in factions:
		var base_weight: int = max(10, faction_rep.get(f, 30))
		# Scientists love molecular deconstruction + rare ingredients — penalise until T2 unlocked
		if f == "scientists":
			if not has_t2:
				base_weight = 2   # nearly excluded early game
			elif not has_t3:
				base_weight = base_weight / 2
		# Corsairs love cold press + raw — fine early, but some high-end prefs need T2+
		# No penalty, cold press works on any ingredient
		weights.append(base_weight)

	var total: int = 0
	for w in weights:
		total += w
	var roll: int = randi() % total
	var cumulative: int = 0
	for i in range(factions.size()):
		cumulative += weights[i]
		if roll < cumulative:
			return factions[i]
	return "drifters"


func log_guest_session(guests: Array, outcomes: Array) -> void:
	var entry: Dictionary = {
		"session": guest_log.size() + 1,
		"guests": guests.duplicate(true),
		"outcomes": outcomes.duplicate(true),
	}
	guest_log.append(entry)
	if guest_log.size() > 20:
		guest_log.pop_front()
	pending_guests = []
	if cooksta_posts.size() > 10:
		cooksta_posts = cooksta_posts.slice(-10)


func resolve_guest(guest: Dictionary, choice: String) -> Dictionary:
	var faction: String = guest.get("faction", "drifters")
	var is_special: bool = guest.get("special", false)
	var result: Dictionary = {"credits": 0, "faction_deltas": {}, "message": ""}

	if is_special:
		var choice_id: String = guest.get("choice_id", "")
		if choice_id == "velka_first_visit":
			if not "velka_orin" in special_guests_seen:
				special_guests_seen.append("velka_orin")
			if choice == "serve_leviathan":
				# Try to find a tier 3 prepared dish first
				var t3_idx: int = -1
				for i in range(prepared_dishes.size()):
					if prepared_dishes[i].get("tier", 0) >= 3:
						t3_idx = i
						break
				if t3_idx >= 0:
					var _served_dish: Dictionary = remove_prepared_dish(t3_idx)
				elif has_ingredient("leviathan_cut", 1):
					remove_ingredient("leviathan_cut", 1)
				result["credits"] = 500
				result["faction_deltas"] = {"corsairs": 5}
				result["message"] = "Velka Orin eats in silence. Then: 'Adequate.' From her, that's a rave review."
				cooksta_rating = clampi(cooksta_rating + 3, 0, 100)
				cooksta_posts.append("Velka Orin writes: 'The Drifting Spoon. Go. Leviathan cut. Don't ask questions.'")
			elif choice == "overcharge":
				# Consume tier 3 dish or raw ingredient
				var t3o_idx: int = -1
				for i in range(prepared_dishes.size()):
					if prepared_dishes[i].get("tier", 0) >= 3:
						t3o_idx = i
						break
				if t3o_idx >= 0:
					var _dish: Dictionary = remove_prepared_dish(t3o_idx)
				elif has_ingredient("leviathan_cut", 1):
					remove_ingredient("leviathan_cut", 1)
				if randf() < 0.4:
					result["credits"] = 1500
					result["faction_deltas"] = {"corsairs": 2}
					result["message"] = "She pays without blinking. 'You know what it's worth.' Corsair rep."
				else:
					result["credits"] = 0
					result["faction_deltas"] = {"corsairs": -3}
					result["message"] = "She leaves the credits on the table and walks out. Slower than she arrived."
			elif choice == "honest":
				result["faction_deltas"] = {"corsairs": 2}
				result["message"] = "She nods. 'I'll be back.' She means it."
				cooksta_rating = clampi(cooksta_rating + 1, 0, 100)
			elif choice == "bluff":
				if randf() < 0.45:
					result["credits"] = 200
					result["faction_deltas"] = {"corsairs": 3}
					result["message"] = "She buys it. Or pretends to. Either way, she leaves satisfied."
				else:
					result["faction_deltas"] = {"corsairs": -5}
					result["message"] = "She sets down her fork. 'This is Drifter organ.' A statement, not a question. She leaves."
					cooksta_rating = clampi(cooksta_rating - 3, 0, 100)
			elif choice == "defer":
				result["faction_deltas"] = {"corsairs": 1}
				result["message"] = "She accepts the drink. Bookmarks the place."
		elif choice_id == "drath_first_visit":
			if not "commissioner_drath" in special_guests_seen:
				special_guests_seen.append("commissioner_drath")
			if choice == "cooperate":
				result["faction_deltas"] = {"coalition": 3}
				result["message"] = "He makes notes. 'Unusual menu.' He pays and leaves. The notes are probably fine."
			elif choice == "bribe_food":
				add_credits(-100)
				result["faction_deltas"] = {"coalition": 5}
				result["message"] = "He accepts. 'On official business, I can't accept gifts.' He eats it anyway."
			elif choice == "probe":
				result["faction_deltas"] = {"coalition": 1}
				result["message"] = "He's vague. Something about 'ingredient provenance standards.' Watch for Coalition patrols."
				set_story_flag("drath_warned", true)
	else:
		# Procedural guest — requires a prepared dish
		if prepared_dishes.is_empty():
			result["credits"] = 0
			result["faction_deltas"] = {faction: -1}
			result["message"] = "%s (%s) — nothing to serve. They leave hungry." % [guest.get("name", "Guest"), faction.capitalize()]
			add_restaurant_rep(-1)
			add_credits(0)
			for f in result["faction_deltas"]:
				add_faction_rep(f, result["faction_deltas"][f])
			return result
		# Pick best dish for this faction
		var dish_idx: int = get_best_dish_for_faction(faction)
		var dish: Dictionary = remove_prepared_dish(dish_idx)
		var base_credits: int = dish.get("credits_value", 60)
		var base_rep: int = dish.get("rep_value", 1)
		var satisfaction: float = get_satisfaction_modifier(faction, dish.get("method", ""), dish.get("style", ""))
		# Trait modifiers
		var trait_val: String = guest.get("trait", "")
		if trait_val == "generous":
			satisfaction += 0.3
		elif trait_val == "suspicious" or trait_val == "paranoid":
			satisfaction -= 0.2
		elif trait_val == "snobbish":
			if restaurant_rep < 40:
				satisfaction -= 0.4
		var earned: int = int(base_credits * satisfaction)
		var rep_delta: int = base_rep if satisfaction >= 1.0 else (0 if satisfaction >= 0.6 else -1)
		result["credits"] = earned
		result["faction_deltas"] = {faction: rep_delta}
		result["dish_served"] = dish.get("name", "Unknown Dish")
		if satisfaction >= 1.3:
			result["message"] = "%s (%s) — loved the %s. +%d cr" % [guest.get("name", "Guest"), faction.capitalize(), dish.get("name", "dish"), earned]
		elif satisfaction >= 0.8:
			result["message"] = "%s (%s) — satisfied with %s. +%d cr" % [guest.get("name", "Guest"), faction.capitalize(), dish.get("name", "dish"), earned]
		else:
			result["message"] = "%s (%s) — did not enjoy the %s. +%d cr" % [guest.get("name", "Guest"), faction.capitalize(), dish.get("name", "dish"), earned]
		add_restaurant_rep(rep_delta)
		# Corsair retaliation check
		if faction == "corsairs" and satisfaction < 0.5 and faction_rep.get("corsairs", 0) < 30:
			set_story_flag("corsair_retaliation_pending", true)

	add_credits(result["credits"])
	for f in result["faction_deltas"]:
		add_faction_rep(f, result["faction_deltas"][f])
	return result
