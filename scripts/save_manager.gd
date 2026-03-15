extends Node

const SAVE_PATH := "user://save_game.json"


func save_game() -> void:
	var data := {
		"hull": GameState.hull,
		"max_hull": GameState.max_hull,
		"fuel": GameState.fuel,
		"max_fuel": GameState.max_fuel,
		"credits": GameState.credits,
		"resources": GameState.resources.duplicate(),
		"inventory": GameState.inventory.duplicate(),
		"artifacts_collected": GameState.artifacts_collected.duplicate(),
		"planets": GameState.planets.duplicate(true),
		"player_speed_bonus": GameState.player_speed_bonus,
		"player_damage_bonus": GameState.player_damage_bonus,
		"player_mining_speed_bonus": GameState.player_mining_speed_bonus,
		"weapon_level": GameState.weapon_level,
		"speed_level": GameState.speed_level,
		"shield_level": GameState.shield_level,
		"last_planet_id": GameState.last_planet_id,
	}
	var json_string := JSON.stringify(data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		return false

	var data: Dictionary = json.data
	GameState.hull = float(data.get("hull", 100.0))
	GameState.max_hull = float(data.get("max_hull", 100.0))
	GameState.fuel = float(data.get("fuel", 100.0))
	GameState.max_fuel = float(data.get("max_fuel", 100.0))
	GameState.credits = int(data.get("credits", 500))
	GameState.resources = data.get("resources", {"ore": 0, "crystal": 0, "fuel": 0, "scrap": 0})
	GameState.inventory = data.get("inventory", [])
	GameState.artifacts_collected = data.get("artifacts_collected", [])
	GameState.planets = data.get("planets", {})
	GameState.player_speed_bonus = float(data.get("player_speed_bonus", 0.0))
	GameState.player_damage_bonus = float(data.get("player_damage_bonus", 0.0))
	GameState.player_mining_speed_bonus = float(data.get("player_mining_speed_bonus", 0.0))
	GameState.weapon_level = int(data.get("weapon_level", 0))
	GameState.speed_level = int(data.get("speed_level", 0))
	GameState.shield_level = int(data.get("shield_level", 0))
	GameState.last_planet_id = data.get("last_planet_id", "")
	return true


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
