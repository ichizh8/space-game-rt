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
		"captain_xp": GameState.captain_xp,
		"captain_perk_points_earned": GameState.captain_perk_points_earned,
		"captain_perks": GameState.captain_perks.duplicate(),
		"map_discovered_planets": GameState.map_discovered_planets.duplicate(true),
		"faction_rep": GameState.faction_rep.duplicate(),
		"active_quests": GameState.active_quests.duplicate(true),
		"completed_quests": GameState.completed_quests.duplicate(),
		"session_kills": GameState.session_kills,
		"session_artifacts": GameState.session_artifacts,
		"story_act": GameState.story_act,
		"story_flags": GameState.story_flags.duplicate(),
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
	GameState.captain_xp = int(data.get("captain_xp", 0))
	GameState.captain_perk_points_earned = int(data.get("captain_perk_points_earned", 0))
	var loaded_perks = data.get("captain_perks", [])
	GameState.captain_perks = []
	for p in loaded_perks:
		GameState.captain_perks.append(str(p))
	GameState.reapply_all_perks()
	GameState.faction_rep = data.get("faction_rep", {"coalition": 50, "pirates": 0})
	GameState.active_quests = data.get("active_quests", [])
	GameState.completed_quests = data.get("completed_quests", [])
	GameState.session_kills = int(data.get("session_kills", 0))
	GameState.session_artifacts = int(data.get("session_artifacts", 0))
	GameState.story_act = int(data.get("story_act", 1))
	GameState.story_flags = data.get("story_flags", {})
	var loaded_map: Dictionary = data.get("map_discovered_planets", {})
	GameState.map_discovered_planets = {}
	for pid in loaded_map:
		var entry: Dictionary = loaded_map[pid]
		GameState.map_discovered_planets[str(pid)] = {
			"pos_x": float(entry.get("pos_x", 0)),
			"pos_y": float(entry.get("pos_y", 0)),
			"name": str(entry.get("name", "")),
			"color_h": float(entry.get("color_h", 0.3))
		}
	return true


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
