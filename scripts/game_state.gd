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

# Last planet the player visited (for respawn)
var last_planet_id: String = ""

signal hull_changed(new_value: float)
signal fuel_changed(new_value: float)
signal credits_changed(new_value: int)
signal resources_changed()
signal player_died()


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


func reset_game() -> void:
	hull = 100.0
	max_hull = 100.0
	fuel = 100.0
	max_fuel = 100.0
	credits = 500
	resources = {"ore": 0, "crystal": 0, "fuel": 0, "scrap": 0}
	inventory = []
	artifacts_collected = []
	planets = {}
	player_speed_bonus = 0.0
	player_damage_bonus = 0.0
	player_mining_speed_bonus = 0.0
	last_planet_id = ""
