extends Node2D

var speed: float = 0.0
var hp: float = 35.0
var max_hp: float = 35.0
var is_dead := false
var _target_pos: Vector2 = Vector2.ZERO
var _flash_timer: float = 0.0
var _despawn_timer: float = -1.0
var _has_sprite: bool = false


func _ready() -> void:
	add_to_group("npc_ships")
	add_to_group("npc_drifters")
	speed = randf_range(60.0, 80.0)
	_pick_wander_target()
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

	# Wander toward target
	var dir: Vector2 = (_target_pos - global_position).normalized()
	position += dir * speed * delta
	rotation = dir.angle() + PI / 2.0

	if global_position.distance_to(_target_pos) < 50.0:
		_pick_wander_target()

	queue_redraw()


func _pick_wander_target() -> void:
	_target_pos = global_position + Vector2.from_angle(randf() * TAU) * randf_range(300.0, 800.0)


func take_damage(amount: float) -> void:
	if is_dead:
		return
	hp -= amount
	_flash_timer = 0.1
	modulate = Color(1.5, 0.3, 0.3, 1.0)
	queue_redraw()
	if hp <= 0:
		call_deferred("_die")


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	var em := get_tree().get_first_node_in_group("effects_manager") as Node2D
	if is_instance_valid(em) and em.has_method("add_explosion"):
		em.add_explosion(global_position, 0.8)
		em.add_float("DRIFTERS REP -4", global_position + Vector2(0, -20), Color.ORANGE)
	GameState.add_faction_rep("drifters", -4)
	call_deferred("_spawn_loot")
	_despawn_timer = 1.5


func _spawn_loot() -> void:
	var loot_scene: PackedScene = load("res://scenes/loot_drop.tscn") as PackedScene
	if not is_instance_valid(loot_scene):
		return
	var res: Dictionary = {"scrap": randi_range(2, 5)}
	var loot: Node2D = loot_scene.instantiate() as Node2D
	loot.global_position = global_position
	if loot.has_method("setup"):
		loot.setup(randi_range(10, 25), res)
	get_parent().add_child(loot)


func _setup_sprite() -> void:
	var tex := load("res://assets/2026-03-18-faction-drifter-shuttle.png") as Texture2D
	if not is_instance_valid(tex):
		return
	var sprite := Sprite2D.new()
	sprite.texture = tex
	var scale_factor: float = 40.0 / max(tex.get_size().x, tex.get_size().y)
	sprite.scale = Vector2(scale_factor, scale_factor)
	sprite.rotation = PI
	add_child(sprite)
	_has_sprite = true

func _draw() -> void:
	if _has_sprite:
		return
	if is_dead:
		return
	# Yellow/tan irregular shape
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2, -9), Vector2(-6, -3), Vector2(-5, 8), Vector2(5, 8), Vector2(6, -3), Vector2(2, -9)
	]), Color(0.8, 0.7, 0.4, 0.9))
	# Label
	draw_string(ThemeDB.fallback_font, Vector2(-16, -13), "DRIFTER",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.8, 0.7, 0.4, 0.6))
	# HP bar when damaged
	if hp < max_hp:
		var bw := 30.0
		var pct: float = hp / max_hp
		draw_rect(Rect2(-bw / 2.0, -22, bw, 3), Color(0.2, 0.2, 0.2, 0.7))
		draw_rect(Rect2(-bw / 2.0, -22, bw * pct, 3), Color(0.2, 0.9, 0.2))
