extends Node2D

var hp: float = 45.0
var max_hp: float = 45.0
var is_dead := false
var _rot_target: float = 0.0
var _shoot_timer: float = 0.0
var _flash_timer: float = 0.0
var _despawn_timer: float = -1.0

const DETECT_RANGE := 260.0
const SHOOT_COOLDOWN := 0.7
const BULLET_DAMAGE := 12.0
const XP_REWARD := 20
const CREDIT_REWARD := 25

var bullet_scene: PackedScene


func _ready() -> void:
	add_to_group("enemies")
	bullet_scene = load("res://scenes/bullet.tscn")
	_setup_sprite()
	queue_redraw()


func _setup_sprite() -> void:
	var tex := load("res://assets/2026-03-15-turret.png") as Texture2D
	if not is_instance_valid(tex):
		return
	var sprite := Sprite2D.new()
	sprite.texture = tex
	var scale_factor: float = 56.0 / max(tex.get_size().x, tex.get_size().y)
	sprite.scale = Vector2(scale_factor, scale_factor)
	# Turret rotates with the node so no flip needed
	add_child(sprite)


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
	if not is_instance_valid(player):
		return

	var dist := global_position.distance_to(player.global_position)
	if dist > DETECT_RANGE:
		queue_redraw()
		return

	var dir := (player.global_position - global_position).normalized()
	_rot_target = dir.angle() + PI / 2.0
	rotation = lerp_angle(rotation, _rot_target, delta * 4.0)
	queue_redraw()

	_shoot_timer += delta
	if _shoot_timer >= SHOOT_COOLDOWN:
		_shoot_timer = 0.0
		call_deferred("_fire")


func take_damage(amount: float) -> void:
	if is_dead:
		return
	hp -= amount
	_flash_timer = 0.12
	modulate = Color(1.5, 0.3, 0.3, 1.0)
	queue_redraw()
	if hp <= 0:
			call_deferred("_die")


func _fire() -> void:
	if is_dead:
		return
	var bullet := bullet_scene.instantiate() as Node2D
	var forward := Vector2.UP.rotated(rotation)
	bullet.global_position = global_position + forward * -20.0
	bullet.rotation = rotation
	bullet.set("is_player_bullet", false)
	bullet.set("damage", BULLET_DAMAGE)
	get_parent().add_child(bullet)


signal died()

func _die() -> void:
	is_dead = true
	GameState.record_kill()
	GameState.add_xp(XP_REWARD)
	var em := get_tree().get_first_node_in_group("effects_manager") as Node2D
	if is_instance_valid(em) and em.has_method("add_explosion"):
		em.add_explosion(global_position, 0.9)
	call_deferred("_spawn_loot")
	_despawn_timer = 1.2
	queue_redraw()
	died.emit()


func _spawn_loot() -> void:
	var loot_scene := load("res://scenes/loot_drop.tscn") as PackedScene
	if not is_instance_valid(loot_scene):
		GameState.add_credits(CREDIT_REWARD)
		return
	var loot := loot_scene.instantiate() as Node2D
	loot.global_position = global_position
	var res: Dictionary = {"scrap": randi_range(4, 8)}
	if loot.has_method("setup"):
		loot.setup(CREDIT_REWARD, res)
	get_parent().add_child(loot)


func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null


func _draw() -> void:
	if is_dead:
		return
	# Base platform
	draw_circle(Vector2.ZERO, 14.0, Color(0.3, 0.35, 0.3))
	draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 24, Color(0.5, 0.55, 0.5), 2.0)
	# Rotating gun barrel (drawn in local rotated space)
	draw_rect(Rect2(-4, -18, 8, 18), Color(0.55, 0.55, 0.4))
	draw_rect(Rect2(-2, -22, 4, 8), Color(0.4, 0.4, 0.3))
	# HP bar
	if hp < max_hp:
		var bw := 28.0
		var bh := 4.0
		var by := -26.0
		var pct := hp / max_hp
		draw_rect(Rect2(-bw / 2.0, by, bw, bh), Color(0.2, 0.2, 0.2, 0.8))
		var fc := Color(0.2, 0.9, 0.2) if pct > 0.5 else (Color(0.9, 0.7, 0.1) if pct > 0.25 else Color(0.9, 0.1, 0.1))
		draw_rect(Rect2(-bw / 2.0, by, bw * pct, bh), fc)
