extends Node2D

var hp: float = 90.0
var max_hp: float = 90.0
var is_dead := false
var speed: float = 50.0
var difficulty_mult: float = 1.0

signal died()

const PREFERRED_RANGE := 380.0
const SHOOT_INTERVAL := 2.8
const BULLET_DAMAGE := 20.0
const XP_REWARD := 35
const CREDIT_REWARD := 50

var _shoot_timer: float = 1.5
var _flash_timer: float = 0.0
var _despawn_timer: float = -1.0
var _has_sprite: bool = false
var bullet_scene: PackedScene

func _ready() -> void:
	add_to_group("enemies")
	bullet_scene = load("res://scenes/bullet.tscn")
	queue_redraw()
	call_deferred("_setup_sprite")

func setup(diff_mult: float) -> void:
	difficulty_mult = diff_mult
	hp = 90.0 * difficulty_mult
	max_hp = hp


func _process(delta: float) -> void:
	if is_dead:
		if _despawn_timer > 0:
			_despawn_timer -= delta
			if _despawn_timer <= 0:
				call_deferred("queue_free")
		return

	if _flash_timer > 0:
		_flash_timer -= delta
		if _flash_timer <= 0:
			modulate = Color.WHITE

	var player := _get_player()
	if not is_instance_valid(player):
		return

	var dist := global_position.distance_to(player.global_position)
	var dir_to_player := (player.global_position - global_position).normalized()

	# Maintain preferred range — move toward or away
	if dist < PREFERRED_RANGE - 40.0:
		position -= dir_to_player * speed * delta
	elif dist > PREFERRED_RANGE + 40.0:
		position += dir_to_player * speed * delta
	else:
		# Slow strafe
		var perp := Vector2(-dir_to_player.y, dir_to_player.x)
		position += perp * speed * 0.5 * delta

	# Always face player
	rotation = dir_to_player.angle() + PI / 2.0

	_shoot_timer -= delta
	if _shoot_timer <= 0 and dist < PREFERRED_RANGE + 100.0:
		_shoot_timer = SHOOT_INTERVAL
		call_deferred("_fire")


func _fire() -> void:
	if is_dead or not is_instance_valid(bullet_scene):
		return
	var player := _get_player()
	if not is_instance_valid(player):
		return
	# Fire 2 heavy shots with slight spread
	for spread in [-0.08, 0.08]:
		var dir := (player.global_position - global_position).normalized()
		var angle: float = dir.angle() + float(spread)
		var bullet := bullet_scene.instantiate() as Node2D
		bullet.global_position = global_position
		bullet.rotation = angle - PI / 2.0
		bullet.set("is_player_bullet", false)
		bullet.set("damage", BULLET_DAMAGE * difficulty_mult)
		var parent := get_parent()
		if is_instance_valid(parent):
			parent.add_child(bullet)

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
	if is_dead:
		return
	is_dead = true
	GameState.record_kill()
	GameState.add_xp(XP_REWARD)
	var em := get_tree().get_first_node_in_group("effects_manager") as Node2D
	if is_instance_valid(em) and em.has_method("add_explosion"):
		em.add_explosion(global_position, 2.2)
	call_deferred("_spawn_loot")
	_despawn_timer = 2.0
	queue_redraw()
	died.emit()

func _spawn_loot() -> void:
	var loot_scene := load("res://scenes/loot_drop.tscn") as PackedScene
	if not is_instance_valid(loot_scene):
		GameState.add_credits(CREDIT_REWARD)
		return
	var loot := loot_scene.instantiate() as Node2D
	loot.global_position = global_position
	var cr := int(float(CREDIT_REWARD) * difficulty_mult)
	if loot.has_method("setup"):
		loot.setup(cr, {"crystal": randi_range(3, 6)})
	var parent := get_parent()
	if is_instance_valid(parent):
		parent.add_child(loot)
	GameState.add_ingredient("void_flesh", randi_range(1, 2))

func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null

func _setup_sprite() -> void:
	var tex := load("res://assets/2026-03-16-void-sentinel-ship.png") as Texture2D
	if not is_instance_valid(tex):
		return
	var sprite := Sprite2D.new()
	sprite.texture = tex
	var scale_factor: float = 56.0 / max(tex.get_size().x, tex.get_size().y)
	sprite.scale = Vector2(scale_factor, scale_factor)
	sprite.rotation = PI
	add_child(sprite)
	_has_sprite = true

func _draw() -> void:
	if _has_sprite:
		return
	if is_dead:
		return
	# Fallback: large diamond-ish hull
	var hull_ratio := hp / max_hp
	var points := PackedVector2Array([
		Vector2(0, -20), Vector2(16, -8), Vector2(18, 0),
		Vector2(16, 8), Vector2(0, 20), Vector2(-16, 8),
		Vector2(-18, 0), Vector2(-16, -8)
	])
	var col := Color(0.15, 0.1, 0.5 * hull_ratio + 0.1)
	draw_colored_polygon(points, col)
	# Cannon glow
	draw_circle(Vector2(14, -6), 4.0, Color(0.0, 0.8, 1.0, 0.9))
	draw_circle(Vector2(-14, -6), 4.0, Color(0.0, 0.8, 1.0, 0.9))
	# HP bar
	var bar_w := 36.0 * hull_ratio
	draw_rect(Rect2(-18, -26, 36, 3), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(-18, -26, bar_w, 3), Color(0.1, 0.5, 1.0))
