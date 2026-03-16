extends Node2D

var star_radius: float = 45.0
var star_name: String = ""
var _anim_time: float = 0.0

const STAR_NAMES: Array[String] = [
	"Sol Proxima", "Kepler-422", "Vega Prime", "Arcturus B", "Sirius Minor",
	"Deneb IV", "Rigel Alpha", "Altair Sun", "Fomalhaut", "Pollux Star",
	"Castor Yellow", "Aldebaran", "Betelgeuse Jr", "Tau Ceti", "Epsilon Eridani"
]
var _damage_timer: float = 0.0
const WARNING_RANGE := 200.0
const DANGER_RANGE := 110.0
const WARNING_DAMAGE := 5.0   # hp per second
const DANGER_DAMAGE := 18.0   # hp per second
const DAMAGE_INTERVAL := 0.4


func _ready() -> void:
	add_to_group("stars")
	star_radius = randf_range(38.0, 55.0)
	star_name = STAR_NAMES[randi() % STAR_NAMES.size()]
	queue_redraw()


func _process(delta: float) -> void:
	_anim_time += delta
	queue_redraw()

	_damage_timer += delta
	if _damage_timer < DAMAGE_INTERVAL:
		return
	_damage_timer = 0.0

	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var ship := players[0] as Node2D
	if not is_instance_valid(ship):
		return
	var dist := global_position.distance_to(ship.global_position)
	if dist < DANGER_RANGE:
		call_deferred("_apply_star_damage", DANGER_DAMAGE * DAMAGE_INTERVAL, "SOLAR RADIATION — CRITICAL!")
	elif dist < WARNING_RANGE:
		call_deferred("_apply_star_damage", WARNING_DAMAGE * DAMAGE_INTERVAL, "WARNING: Solar heat!")


func _apply_star_damage(amount: float, msg: String) -> void:
	GameState.take_damage(amount)
	var hud := get_tree().get_first_node_in_group("hud")
	if is_instance_valid(hud) and hud.has_method("show_notification"):
		hud.show_notification(msg, 0.5)


func _draw() -> void:
	var t := _anim_time
	# Outer glow layers
	draw_circle(Vector2.ZERO, star_radius * 2.2, Color(1.0, 0.4, 0.0, 0.04))
	draw_circle(Vector2.ZERO, star_radius * 1.7, Color(1.0, 0.55, 0.0, 0.08))
	draw_circle(Vector2.ZERO, star_radius * 1.25, Color(1.0, 0.75, 0.1, 0.18))
	# Corona rays
	for i in range(10):
		var angle := t * 0.15 + i * TAU / 10.0
		var r1 := star_radius * 1.05
		var r2 := star_radius * (1.4 + sin(t * 1.8 + i * 1.3) * 0.15)
		var ray_color := Color(1.0, 0.85, 0.3, 0.35 + sin(t * 2.0 + i) * 0.1)
		draw_line(Vector2.from_angle(angle) * r1, Vector2.from_angle(angle) * r2, ray_color, 2.5)
	# Main body
	draw_circle(Vector2.ZERO, star_radius, Color(1.0, 0.95, 0.5))
	# Surface shimmer
	draw_circle(Vector2.ZERO, star_radius * 0.75, Color(1.0, 1.0, 0.8, 0.6))
	draw_circle(Vector2.ZERO, star_radius * 0.4, Color(1.0, 1.0, 1.0, 0.4))
	# Name label
	var nw: float = star_name.length() * 6.0
	draw_string(ThemeDB.fallback_font, Vector2(-nw * 0.5, star_radius + 14.0),
		star_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.9, 0.5, 0.85))
