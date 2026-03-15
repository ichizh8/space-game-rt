extends Node2D

# Float text: {text, pos, color, life, max_life, vel}
var _floats: Array = []
# Explosion ring: {pos, life, max_life, size}
var _explosions: Array = []
# Spark particle: {pos, vel, life, max_life, color}
var _sparks: Array = []

const FLOAT_LIFE := 1.2
const EXPLOSION_LIFE := 0.5
const SPARK_LIFE := 0.7

func _ready() -> void:
	add_to_group("effects_manager")

func add_float(text: String, pos: Vector2, color: Color = Color.WHITE) -> void:
	_floats.append({
		"text": text, "pos": pos, "color": color,
		"life": FLOAT_LIFE, "max_life": FLOAT_LIFE,
		"vel": Vector2(randf_range(-15, 15), -55.0)
	})

func add_explosion(pos: Vector2, size: float = 1.0) -> void:
	_explosions.append({"pos": pos, "life": EXPLOSION_LIFE, "max_life": EXPLOSION_LIFE, "size": size})
	for i in range(int(10 * size)):
		var angle := randf() * TAU
		var speed := randf_range(70, 180) * size
		_sparks.append({
			"pos": pos,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"life": SPARK_LIFE * randf_range(0.4, 1.0),
			"max_life": SPARK_LIFE,
			"color": Color(1.0, randf_range(0.3, 0.8), 0.0, 1.0)
		})

func _process(delta: float) -> void:
	var dirty := false
	# Update floats (rebuild array without expired)
	var nf: Array = []
	for f in _floats:
		f["life"] -= delta
		f["pos"] += f["vel"] * delta
		if f["life"] > 0:
			nf.append(f)
		dirty = true
	_floats = nf
	# Update explosions
	var ne: Array = []
	for e in _explosions:
		e["life"] -= delta
		if e["life"] > 0:
			ne.append(e)
		dirty = true
	_explosions = ne
	# Update sparks
	var ns: Array = []
	for s in _sparks:
		s["life"] -= delta
		s["pos"] += s["vel"] * delta
		s["vel"] *= (1.0 - delta * 3.5)
		if s["life"] > 0:
			ns.append(s)
		dirty = true
	_sparks = ns
	if dirty:
		queue_redraw()

func _draw() -> void:
	for e in _explosions:
		var t := 1.0 - (e["life"] / e["max_life"])
		var radius := e["size"] * 35.0 * t
		var alpha := e["life"] / e["max_life"]
		draw_circle(e["pos"], radius, Color(1.0, 0.5, 0.0, alpha * 0.6))
		draw_circle(e["pos"], radius * 0.5, Color(1.0, 1.0, 0.6, alpha * 0.85))
	for s in _sparks:
		var alpha := s["life"] / s["max_life"]
		var c: Color = s["color"]
		c.a = alpha
		draw_circle(s["pos"], 2.5, c)
	for f in _floats:
		var alpha := f["life"] / f["max_life"]
		var c: Color = f["color"]
		c.a = alpha
		draw_string(ThemeDB.fallback_font, f["pos"], f["text"],
			HORIZONTAL_ALIGNMENT_CENTER, -1, 14, c)
