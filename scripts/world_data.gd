extends Node

var resources_data: Dictionary = {}
var artifacts_data: Array = []
var quests_data: Array = []
var buildings_data: Dictionary = {}


func _ready() -> void:
	_load_json_data()


func _load_json_data() -> void:
	resources_data = _load_json("res://data/resources.json") as Dictionary
	artifacts_data = _load_json("res://data/artifacts.json") as Array
	quests_data = _load_json("res://data/quests.json") as Array
	buildings_data = _load_json("res://data/buildings.json") as Dictionary


func _load_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open: " + path)
		return {}
	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		push_error("JSON parse error in " + path + ": " + json.get_error_message())
		return {}
	return json.data


func get_quest_by_id(quest_id: String) -> Dictionary:
	for quest in quests_data:
		if quest["id"] == quest_id:
			return quest
	return {}


func get_artifact_by_id(artifact_id: String) -> Dictionary:
	for artifact in artifacts_data:
		if artifact["id"] == artifact_id:
			return artifact
	return {}


func get_random_quest_id() -> String:
	if quests_data.is_empty():
		return ""
	return quests_data[randi() % quests_data.size()]["id"]


func get_random_artifact() -> Dictionary:
	if artifacts_data.is_empty():
		return {}
	# Filter out already collected artifacts
	var available: Array = []
	for artifact in artifacts_data:
		if artifact["id"] not in GameState.artifacts_collected:
			available.append(artifact)
	if available.is_empty():
		return {}
	return available[randi() % available.size()]


func get_board_quests_for(source_type: String) -> Array:
	var result: Array = []
	for quest in quests_data:
		var qtype: String = quest.get("type", "")
		if qtype == "story":
			continue
		if qtype == "":
			continue  # skip classic text quests (no type field)
		var qsource: String = quest.get("source_type", "any")
		if qsource == source_type or qsource == "any" or source_type == "any":
			if not GameState.is_quest_completed(quest["id"]):
				result.append(quest)
	result.shuffle()
	return result


func get_building_data(building_id: String) -> Dictionary:
	if buildings_data.has(building_id):
		return buildings_data[building_id]
	return {}
