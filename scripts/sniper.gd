extends Node2D

var hp: float = 25.0
var max_hp: float = 25.0
var is_dead := false
var speed: float = 60.0
var difficulty_mult: float = 1.0

signal died()

const SHOOT_RANGE := 700.0
const RETREAT_RANGE := 300.0
const CHARGE_TIME := 2.2
const BULLET_SPEED := 900.0
const BULLET_DAMAGE := 28.0
const XP_REWARD := 20
const CREDIT_REWARD := 30

enum State { REPOSITION, CHARGE, FIRE, RETREAT }
var state: State = State.REPOSITION

var _charge_timer: float = 0.0
var _reposition_timer: float = 0.0
var _reposition_target: Vector2 = Vector2.ZERO
var _flash_timer: float = 0.0
var _despawn_timer: float = -1.0
var _has_sprite: bool = false
var _sprite_tex: Texture2D = null
var _sprite_size: float = 40.0
var _charge_dir: Vector2 = Vector2.ZERO
var bullet_scene: PackedScene

func _ready() -> void:
	add_to_group("enemies")
	bullet_scene = load("res://scenes/bullet.tscn")
	_pick_reposition_target()
	queue_redraw()
	call_deferred("_setup_sprite")

func setup(diff_mult: float) -> void:
	difficulty_mult = diff_mult
	hp = 25.0 * difficulty_mult
	max_hp = hp

func _pick_reposition_target() -> void:
	var player := _get_player()
	if not is_instance_valid(player):
		return
	var angle := randf() * TAU
	var dist := randf_range(500.0, 680.0)
	_reposition_target = player.global_position + Vector2(cos(angle), sin(angle)) * dist
	_reposition_timer = 4.0


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

	match state:
		State.REPOSITION:
			var to_target := (_reposition_target - global_position)
			if to_target.length() > 20.0:
				position += to_target.normalized() * speed * delta
			_reposition_timer -= delta
			if _reposition_timer <= 0 or to_target.length() < 20.0:
				if dist <= SHOOT_RANGE:
					state = State.CHARGE
					_charge_timer = 0.0
					_charge_dir = dir_to_player
				else:
					_pick_reposition_target()

		State.CHARGE:
			_charge_timer += delta
			_charge_dir = dir_to_player
			# Drift slowly away while charging
			position -= dir_to_player * (speed * 0.3) * delta
			rotation = _charge_dir.angle() + PI / 2.0
			queue_redraw()
			if _charge_timer >= CHARGE_TIME:
				state = State.FIRE

		State.FIRE:
			call_deferred("_fire_shot")
			state = State.REPOSITION
			_pick_reposition_target()

		State.RETREAT:
			position -= dir_to_player * speed * 1.8 * delta
			if dist > RETREAT_RANGE + 100.0:
				state = State.REPOSITION
				_pick_reposition_target()

	if dist < RETREAT_RANGE:
		state = State.RETREAT

func _fire_shot() -> void:
	if is_dead or not is_instance_valid(bullet_scene):
		return
	var bullet := bullet_scene.instantiate() as Node2D
	bullet.global_position = global_position
	bullet.rotation = _charge_dir.angle() - PI / 2.0
	bullet.set("is_player_bullet", false)
	bullet.set("damage", BULLET_DAMAGE * difficulty_mult)
	var parent := get_parent()
	if is_instance_valid(parent):
		parent.add_child(bullet)
	# Override bullet speed via velocity
	if bullet.has_method("set") and bullet.get("_hit") != null:
		pass  # bullet uses its own SPEED const; that's fine

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
		em.add_explosion(global_position, 1.0)
	call_deferred("_spawn_loot")
	_despawn_timer = 1.4
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
		loot.setup(cr, {})
	var parent := get_parent()
	if is_instance_valid(parent):
		parent.add_child(loot)

func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null

func _setup_sprite() -> void:
	var tex := load("res://assets/2026-03-16-sniper-ship.png") as Texture2D
	if not is_instance_valid(tex):
		return
	_sprite_tex = tex
	_sprite_size = 48.0
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
			draw_rect(Rect2(-bw*0.5, by, bw, 3.0), Color(0.2,0.2,0.2,0.8))
			var fc := Color(0.2,0.9,0.2) if pct>0.5 else (Color(0.9,0.7,0.1) if pct>0.25 else Color(0.9,0.1,0.1))
			draw_rect(Rect2(-bw*0.5, by, bw*pct, 3.0), fc)
		return
	if is_dead:
		return
	# Fallback polygon: long thin ship
	var points := PackedVector2Array([
		Vector2(0, -20), Vector2(4, -12), Vector2(3, 14),
		Vector2(0, 18), Vector2(-3, 14), Vector2(-4, -12)
	])
	var col := Color(0.1, 0.6, 0.2) if not is_dead else Color(0.3, 0.3, 0.3, 0.4)
	draw_colored_polygon(points, col)
	# Charge indicator
	if state == State.CHARGE:
		var t := _charge_timer / CHARGE_TIME
		draw_circle(Vector2(0, -22), 4.0 * t, Color(1.0, 0.2, 0.2, t))
