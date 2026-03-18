extends Node2D

enum State { GRAZE, FLEE }

var hp: float = 20.0
var max_hp: float = 20.0
var is_dead: bool = false
var speed: float = 40.0
var state: State = State.GRAZE
var difficulty_mult: float = 1.0

var velocity: Vector2 = Vector2.ZERO
var _wander_dir: Vector2 = Vector2.RIGHT
var _wander_timer: float = 0.0
var _flash_timer: float = 0.0
var _despawn_timer: float = -1.0
var _has_sprite: bool = false
var _sprite_tex: Texture2D = null
var _sprite_size: float = 40.0

const FLEE_RANGE := 150.0
const COLOR := Color(0.6, 0.8, 0.3)

signal died()


func setup(diff_mult: float) -> void:
	difficulty_mult = diff_mult


func _ready() -> void:
	add_to_group("wildlife")
	add_to_group("enemies")
	hp *= difficulty_mult
	max_hp = hp
	_wander_dir = Vector2.from_angle(randf() * TAU)
	_setup_sprite()
	queue_redraw()


func _process(delta: float) -> void:
	if _despawn_timer > 0.0:
		_despawn_timer -= delta
		if _despawn_timer <= 0.0:
			call_deferred("queue_free")
			return

	if is_dead:
		return

	if _flash_timer > 0:
		_flash_timer -= delta
		if _flash_timer <= 0:
			modulate = Color.WHITE
			queue_redraw()

	var player := _get_player()
	var dist := INF
	if is_instance_valid(player):
		dist = global_position.distance_to(player.global_position)

	match state:
		State.GRAZE:
			if dist < FLEE_RANGE:
				state = State.FLEE
		State.FLEE:
			if dist > FLEE_RANGE * 2.5:
				state = State.GRAZE

	match state:
		State.GRAZE:
			_wander_timer += delta
			if _wander_timer > randf_range(2.0, 4.0):
				_wander_timer = 0.0
				_wander_dir = Vector2.from_angle(randf() * TAU)
			velocity = _wander_dir * speed * 0.5
		State.FLEE:
			if is_instance_valid(player):
				var away := (global_position - player.global_position).normalized()
				velocity = away * speed * 2.0

	if velocity.length() > 0.1:
		rotation = velocity.angle() + PI / 2.0
	position += velocity * delta


func take_damage(amount: float) -> void:
	if is_dead:
		return
	hp -= amount
	_flash_timer = 0.12
	modulate = Color(1.5, 0.3, 0.3, 1.0)
	queue_redraw()
	if hp <= 0:
		call_deferred("_die")


func _die() -> void:
	is_dead = true
	GameState.record_kill()
	GameState.add_xp(5)
	GameState.drop_ingredients("void_grub")
	var em := get_tree().get_first_node_in_group("effects_manager") as Node2D
	if is_instance_valid(em) and em.has_method("add_explosion"):
		em.add_explosion(global_position, 0.6)
	call_deferred("_spawn_ingredient_loot")
	_despawn_timer = 1.4
	queue_redraw()
	died.emit()


func _spawn_ingredient_loot() -> void:
	GameState.add_ingredient("grub_meat", randi_range(2, 3))
	var em := get_tree().get_first_node_in_group("effects_manager") as Node2D
	if is_instance_valid(em) and em.has_method("add_float"):
		em.add_float("+Grub Meat", global_position + Vector2(0, -20), Color(0.6, 0.8, 0.3))


func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null


func _setup_sprite() -> void:
	var tex := load("res://assets/2026-03-18-wildlife-void-grub.png") as Texture2D
	if not is_instance_valid(tex):
		return
	_sprite_tex = tex
	_sprite_size = 28.0
	_has_sprite = true
	queue_redraw()

func _draw() -> void:
	if _has_sprite and is_instance_valid(_sprite_tex):
		if is_dead:
			return
		var sz: float = _sprite_size
		draw_texture_rect(_sprite_tex, Rect2(-sz * 0.5, -sz * 0.5, sz, sz), false)
		if hp < max_hp:
			var bw: float = sz
			var by: float = -sz * 0.5 - 5.0
			var pct: float = hp / max_hp
			# Counter-rotate so HP bar stays screen-aligned
			draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
			draw_rect(Rect2(-bw*0.5, by, bw, 3.0), Color(0.2,0.2,0.2,0.8))
			var fc := Color(0.2,0.9,0.2) if pct>0.5 else (Color(0.9,0.7,0.1) if pct>0.25 else Color(0.9,0.1,0.1))
			draw_rect(Rect2(-bw*0.5, by, bw*pct, 3.0), fc)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if is_dead:
		return
	# Fat oval
	var pts := PackedVector2Array()
	for i in range(16):
		var a: float = i * TAU / 16.0
		pts.append(Vector2(cos(a) * 10.0, sin(a) * 6.0))
	draw_colored_polygon(pts, COLOR)
	# HP bar
	if hp < max_hp:
		var bw := 24.0
		var bh := 3.0
		var by := -14.0
		var pct := hp / max_hp
		draw_rect(Rect2(-bw / 2.0, by, bw, bh), Color(0.2, 0.2, 0.2, 0.8))
		var fc := Color(0.2, 0.9, 0.2) if pct > 0.5 else (Color(0.9, 0.7, 0.1) if pct > 0.25 else Color(0.9, 0.1, 0.1))
		draw_rect(Rect2(-bw / 2.0, by, bw * pct, bh), fc)
