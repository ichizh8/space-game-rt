extends Node2D

var planet_id: String = ""
var planet_name: String = "Unknown"
var quest_id: String = ""
var planet_color: Color = Color.GREEN
var _color_h: float = 0.3
var planet_radius: float = 30.0

const GRAVITY_RANGE := 250.0   # px from edge of planet
const GRAVITY_STRENGTH := 800.0

signal landed(p_planet_id: String, p_planet_name: String, p_quest_id: String)


var _has_sprite: bool = false
var _sprite_tex: Texture2D = null

func _ready() -> void:
	add_to_group("planets")
	call_deferred("_setup_sprite")
	queue_redraw()

func _setup_sprite() -> void:
	var tex_path: String
	if _color_h < 0.08 or _color_h > 0.95:
		tex_path = "res://assets/2026-03-16-planet-lava.png"
	elif _color_h < 0.18:
		tex_path = "res://assets/2026-03-16-planet-rocky.png"
	elif _color_h < 0.5:
		tex_path = "res://assets/2026-03-16-planet-gas.png"
	elif _color_h < 0.65:
		tex_path = "res://assets/2026-03-16-planet-ocean.png"
	else:
		tex_path = "res://assets/2026-03-16-planet-ice.png"
	var tex := load(tex_path) as Texture2D
	if not is_instance_valid(tex):
		return
	_sprite_tex = tex
	_has_sprite = true
	queue_redraw()


func _process(delta: float) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var ship := players[0] as Node2D
	if not is_instance_valid(ship):
		return
	var to_planet: Vector2 = global_position - ship.global_position
	var dist: float = to_planet.length()
	var gravity_edge: float = planet_radius + GRAVITY_RANGE
	if dist < gravity_edge and dist > planet_radius and ship.has_method("apply_gravity"):
		var force: float = GRAVITY_STRENGTH / max(dist * dist, 100.0)
		var pull: Vector2 = to_planet.normalized() * force * delta
		ship.apply_gravity(pull)


func setup(p_name: String, p_id: String, p_quest_id: String) -> void:
	planet_name = p_name
	planet_id = p_id
	quest_id = p_quest_id
	# Generate a color based on name hash
	var hash_val := planet_name.hash()
	_color_h = fmod(abs(float(hash_val)) / 1000.0, 1.0)
	planet_color = Color.from_hsv(_color_h, 0.5, 0.8)
	planet_radius = randf_range(25.0, 40.0)
	queue_redraw()


func land() -> void:
	GameState.last_planet_id = planet_id
	landed.emit(planet_id, planet_name, quest_id)


func _draw() -> void:
	if _has_sprite and is_instance_valid(_sprite_tex):
		var sz: float = planet_radius * 2.2
		draw_texture_rect(_sprite_tex, Rect2(-sz * 0.5, -sz * 0.5, sz, sz), false)
		var name_width: float = planet_name.length() * 6.0
		draw_string(ThemeDB.fallback_font, Vector2(-name_width * 0.5, planet_radius + 14.0),
			planet_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.95, 1.0, 0.9))
		return
	# Procedural fallback
	draw_circle(Vector2.ZERO, planet_radius, planet_color)
	# Atmosphere ring
	draw_arc(Vector2.ZERO, planet_radius + 4, 0, TAU, 32, planet_color.lightened(0.3), 2.0)
	# Surface detail (horizontal line)
	draw_line(
		Vector2(-planet_radius * 0.7, planet_radius * 0.2),
		Vector2(planet_radius * 0.7, planet_radius * 0.2),
		planet_color.darkened(0.3), 2.0
	)
	draw_line(
		Vector2(-planet_radius * 0.5, -planet_radius * 0.3),
		Vector2(planet_radius * 0.5, -planet_radius * 0.3),
		planet_color.darkened(0.2), 1.5
	)
	# Name label
	var name_width: float = planet_name.length() * 6.0
	draw_string(ThemeDB.fallback_font, Vector2(-name_width * 0.5, planet_radius + 14.0),
		planet_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.95, 1.0, 0.9))
