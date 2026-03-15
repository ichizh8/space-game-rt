extends Node

# Ship stats
var hull: float = 100.0
var max_hull: float = 100.0
var fuel: float = 100.0
var max_fuel: float = 100.0
var credits: int = 500

# Resources
var resources: Dictionary = {"ore": 0, "crystal": 0, "fuel": 0, "scrap": 0}

# Inventory (item IDs)
var inventory: Array = []

# Collected artifact IDs
var artifacts_collected: Array = []

# Planet data: planet_id -> {buildings: {}, storage: {}, quests_done: [], last_visit_time: 0}
var planets: Dictionary = {}

# Player bonuses from artifacts
var player_speed_bonus: float = 0.0
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

# Ship upgrade levels (0-3 each)
var weapon_level: int = 0
var speed_level: int = 0
var shield_level: int = 0

# Last planet the player visited (for respawn)
var last_planet_id: String = ""

signal hull_changed(new_value: float)
signal fuel_changed(new_value: float)
signal credits_changed(new_value: int)
signal resources_changed()
signal player_died()
signal xp_gained(new_total: int)
signal perk_unlocked(perk_id: String)


func add_resource(type: String, amount: int) -> void:
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
	if has_perk("last_stand") and hull / max_hull < 0.2:
		amount *= 0.7
	hull -= amount
	hull = max(hull, 0.0)
	hull_changed.emit(hull)
	if hull <= 0.0:
		on_player_death()


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
			"storage": {"ore": 0, "crystal": 0, "fuel": 0, "scrap": 0},
			"quests_done": [],
			"last_visit_time": Time.get_unix_time_from_system()
		}
	return planets[planet_id]


func on_player_death() -> void:
	hull = max_hull
	fuel = max_fuel
	# Lose some resources on death
	for key in resources:
		resources[key] = int(resources[key] * 0.5)
	resources_changed.emit()
	hull_changed.emit(hull)
	fuel_changed.emit(fuel)
	player_died.emit()


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


func reset_game() -> void:
	max_hull = 100.0 + captain_hull_bonus
	hull = max_hull
	max_fuel = 100.0
	fuel = max_fuel
	credits = 500
	resources = {"ore": 0, "crystal": 0, "fuel": 0, "scrap": 0}
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
