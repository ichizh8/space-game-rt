extends Node

var active_slot: int = 1  # defaults to slot 1; overridden when player picks a slot

const SLOT_COUNT := 3
const SECTOR_NAMES: Dictionary = {
	1: "Helion System",
	2: "Karath System",
	3: "Skull System",
	4: "The Void"
}


func _get_slot_path(slot: int) -> String:
	return "user://save_slot_%d.json" % slot


# ── Web (localStorage) helpers ──────────────────────────────────

func _web_save(slot: int, json_string: String) -> void:
	# Chunk the JSON into small pieces to avoid JS eval string length issues
	var key: String = "save_slot_%d" % slot
	JavaScriptBridge.eval("window.__gs_buf = ''; window.__gs_key = '%s';" % key, true)
	var chunk_size: int = 500
	var i: int = 0
	while i < json_string.length():
		var chunk: String = json_string.substr(i, chunk_size)
		chunk = chunk.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n").replace("\r", "\\r")
		JavaScriptBridge.eval("window.__gs_buf += '%s';" % chunk, true)
		i += chunk_size
	JavaScriptBridge.eval("try { localStorage.setItem(window.__gs_key, window.__gs_buf); } catch(e) { console.error('Save error:', e); }", true)


func _web_load(slot: int) -> String:
	var result = JavaScriptBridge.eval("localStorage.getItem('save_slot_%d') || '';" % slot, true)
	if result == null or str(result).is_empty():
		return ""
	return str(result)


func _web_has_save(slot: int) -> bool:
	var result = JavaScriptBridge.eval("localStorage.getItem('save_slot_%d') !== null;" % slot, true)
	if result == null:
		return false
	return bool(result)


# ── Public API ──────────────────────────────────────────────────

func has_save(slot: int) -> bool:
	if OS.get_name() == "Web":
		return _web_has_save(slot)
	return FileAccess.file_exists(_get_slot_path(slot))


func get_slot_summary(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var json_text: String = ""
	if OS.get_name() == "Web":
		json_text = _web_load(slot)
	else:
		var file := FileAccess.open(_get_slot_path(slot), FileAccess.READ)
		if not file:
			return {}
		json_text = file.get_as_text()
		file.close()
	if json_text.is_empty():
		return {}
	var json := JSON.new()
	var err: int = json.parse(json_text)
	if err != OK:
		return {}
	var data: Dictionary = json.data
	return {
		"credits": int(data.get("credits", 0)),
		"hull": float(data.get("hull", 100.0)),
		"max_hull": float(data.get("max_hull", 100.0)),
		"sector": int(data.get("current_sector", 1)),
		"sector_name": str(SECTOR_NAMES.get(int(data.get("current_sector", 1)), "Unknown")),
		"timestamp": float(data.get("timestamp", 0.0)),
		"story_act": int(data.get("story_act", 1)),
	}


func save_game() -> void:
	var px: float = 0.0
	var py: float = 0.0
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(player):
		px = player.global_position.x
		py = player.global_position.y

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
		"current_sector": GameState.current_sector,
		"restaurant_rep": GameState.restaurant_rep,
		"restaurant_owned": GameState.restaurant_owned,
		"restaurant_ingredients": GameState.restaurant_ingredients.duplicate(),
		"restaurant_unlocked_dishes": GameState.restaurant_unlocked_dishes.duplicate(),
		"player_pos_x": px,
		"player_pos_y": py,
		"timestamp": Time.get_unix_time_from_system(),
	}
	var json_string := JSON.stringify(data, "\t")
	if OS.get_name() == "Web":
		_web_save(active_slot, json_string)
	else:
		var file := FileAccess.open(_get_slot_path(active_slot), FileAccess.WRITE)
		if file:
			file.store_string(json_string)
			file.close()


func load_game(slot: int) -> bool:
	if not has_save(slot):
		return false
	var json_text: String = ""
	if OS.get_name() == "Web":
		json_text = _web_load(slot)
	else:
		var file := FileAccess.open(_get_slot_path(slot), FileAccess.READ)
		if not file:
			return false
		json_text = file.get_as_text()
		file.close()
	if json_text.is_empty():
		return false
	var json := JSON.new()
	var error: int = json.parse(json_text)
	if error != OK:
		return false

	active_slot = slot
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
	GameState.current_sector = int(data.get("current_sector", 1))
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
	GameState.restaurant_rep = int(data.get("restaurant_rep", 0))
	GameState.restaurant_owned = bool(data.get("restaurant_owned", false))
	GameState.restaurant_ingredients = data.get("restaurant_ingredients", {})
	var loaded_dishes = data.get("restaurant_unlocked_dishes", ["dish_mystery_patty"])
	GameState.restaurant_unlocked_dishes = []
	for d in loaded_dishes:
		GameState.restaurant_unlocked_dishes.append(str(d))
	# Restore spawn position
	var ppx: float = float(data.get("player_pos_x", 0.0))
	var ppy: float = float(data.get("player_pos_y", 0.0))
	if ppx != 0.0 or ppy != 0.0:
		GameState.saved_player_pos = Vector2(ppx, ppy)
	return true


func delete_save(slot: int) -> void:
	if OS.get_name() == "Web":
		if _web_has_save(slot):
			JavaScriptBridge.eval("localStorage.removeItem('save_slot_%d');" % slot, true)
	else:
		if has_save(slot):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_get_slot_path(slot)))
	if active_slot == slot:
		active_slot = 0
