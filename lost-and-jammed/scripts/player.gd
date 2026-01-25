extends CharacterBody2D

@onready var _animated_sprite = $AnimatedSprite2D
@onready var coin_pool: Node = get_node_or_null("/root/World/CoinPool")
@onready var audio_manager: Node = get_node_or_null("/root/World/AudioManager")

signal hp_changed(hp: int, max_hp: int)

@export var max_hp: int = 100
var hp: int = 100

const SPEED = 100.0
var last_direction;
var _is_attacking := false
@export var sword_range_px := 64.0
@export var sword_half_width_px := 10.0
@export var sword_origin_forward_px := 12.0
@export var sword_active_start_s := 0.05
@export var sword_active_end_s := 0.45

var _attack_time_s := 0.0
var _attack_dir: Vector2 = Vector2.RIGHT
var _attack_already_hit_by_id: Dictionary = {}

var _crackhead_scene: PackedScene = preload("res://scenes/crackhead.tscn")
var _explosion_scene: PackedScene = preload("res://scenes/Explosion.tscn")
@export var knockback_distance_px: float = 64.0
@export var knockback_duration_s: float = 0.15
var _knockback_time_left_s: float = 0.0
var _knockback_velocity: Vector2 = Vector2.ZERO
const direction_to_vector := {
	"right": Vector2.RIGHT,
	"left": Vector2.LEFT,
	"up": Vector2.UP,
	"down": Vector2.DOWN,
}
const direction_to_idle = {
	"right": "idle_side",
	"left": "idle_side",
	"up": "idle_up",
	"down": "idle_down"
}
const direction_to_run = {
	"right": "run_side",
	"left": "run_side",
	"up": "run_up",
	"down": "run_down"
}

func _ready() -> void:
	# Initialize HP.
	hp = clampi(max_hp, 0, max_hp)
	hp_changed.emit(hp, max_hp)

	# Ensure we always have a facing direction.
	if last_direction == null:
		last_direction = "right"

	# Used to end non-looping attack animations cleanly.
	if _animated_sprite and not _animated_sprite.animation_finished.is_connected(_on_animated_sprite_animation_finished):
		_animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)

func _process(_delta: float) -> void:
	if Input.is_action_pressed("move_right"):
		last_direction = "right";
		_animated_sprite.flip_h = false;
	elif Input.is_action_pressed("move_left"):
		last_direction = "left";
		_animated_sprite.flip_h = true;
	elif Input.is_action_pressed("move_up"):
		last_direction = "up";
	elif Input.is_action_pressed("move_down"):
		last_direction = "down";
		
	if Input.is_action_just_pressed("attack"):
		_start_attack()

	if Input.is_action_just_pressed("shoot") and not _is_attacking:
		shoot()

	# While attacking, keep the attack animation (don't overwrite with idle/run).
	if _is_attacking:
		return

	if (last_direction != null):
		var animation = direction_to_idle[last_direction] if velocity == Vector2.ZERO else direction_to_run[last_direction]
		_animated_sprite.play(animation);

func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	var new_hp := clampi(hp - amount, 0, max_hp)
	if new_hp == hp:
		return
	hp = new_hp
	hp_changed.emit(hp, max_hp)

func heal_hp(amount: int) -> void:
	if amount >= max_hp:
		return
	var new_hp := clampi(hp + amount, 0, max_hp)
	if new_hp == hp:
		return
	hp = new_hp
	hp_changed.emit(hp, max_hp)

func apply_knockback(knock_dir: Vector2) -> void:
	var dir := knock_dir.normalized()
	if dir == Vector2.ZERO:
		dir = - velocity.normalized()
	if dir == Vector2.ZERO:
		dir = - direction_to_vector.get(last_direction, Vector2.RIGHT)

	_knockback_time_left_s = knockback_duration_s
	_knockback_velocity = dir * (knockback_distance_px / max(knockback_duration_s, 0.001))


func _physics_process(delta: float) -> void:
	if _knockback_time_left_s > 0.0:
		_knockback_time_left_s = max(_knockback_time_left_s - delta, 0.0)
		velocity = _knockback_velocity
		move_and_slide()
		return

	if _is_attacking:
		_attack_time_s += delta
		if _attack_time_s >= sword_active_start_s and _attack_time_s <= sword_active_end_s:
			_do_sword_hit(_attack_dir)
		# Lock movement during attack (simple + readable).
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction:
		velocity = direction * SPEED
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)
	move_and_slide()


func shoot() -> void:
	if coin_pool == null:
		push_warning("Player: CoinPool not found (expected at /root/World/CoinPool)")
		return
	var coin = coin_pool.get_coin()
	if coin:
		var aim_dir: Vector2 = direction_to_vector.get(last_direction, Vector2.RIGHT)
		coin.reset()
		# Spawn a bit in front so it doesn't collide with the player instantly.
		coin.global_position = global_position + aim_dir * 12.0
		coin.global_rotation = aim_dir.angle()
		if audio_manager and audio_manager.has_method("play_coin_fling"):
			audio_manager.call("play_coin_fling")


func _start_attack() -> void:
	if _is_attacking:
		return
	_is_attacking = true
	_attack_time_s = 0.0
	_attack_already_hit_by_id.clear()

	var dir_key: String = last_direction if last_direction != null else "right"
	var attack_dir: Vector2 = direction_to_vector.get(dir_key, Vector2.RIGHT)
	_attack_dir = attack_dir

	# Play attack animation based on facing.
	match dir_key:
		"up":
			_animated_sprite.play("attack_up")
		"down":
			_animated_sprite.play("attack_down")
		_:
			_animated_sprite.play("attack_side")
	if audio_manager and audio_manager.has_method("play_sword_attack"):
		audio_manager.call("play_sword_attack")


func _do_sword_hit(attack_dir: Vector2) -> void:
	var dir := attack_dir.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	var ortho := Vector2(-dir.y, dir.x)

	var space := get_world_2d().direct_space_state
	var base_origin: Vector2 = global_position + dir * sword_origin_forward_px
	var origins := [
		base_origin,
		base_origin + ortho * sword_half_width_px,
		base_origin - ortho * sword_half_width_px,
	]

	var best: Dictionary = {}
	var best_dist_sq := INF

	for o in origins:
		var params := PhysicsRayQueryParameters2D.create(o, o + dir * sword_range_px)
		params.exclude = [self]
		# Query all layers, then filter by car layer on the hit collider.
		# This avoids issues if cars change layers later.
		params.collision_mask = -1
		params.collide_with_areas = true
		params.collide_with_bodies = true

		var hit := space.intersect_ray(params)
		if hit.is_empty():
			continue

		var d2 = o.distance_squared_to(hit.position)
		if d2 < best_dist_sq:
			best_dist_sq = d2
			best = hit

	if best.is_empty():
		return

	var collider = best.get("collider")
	if collider == null:
		return

	# Treat anything on the car layer bit as a "car" target.
	if collider is CollisionObject2D and (int((collider as CollisionObject2D).collision_layer) & 4) != 0:
		var id := (collider as Node).get_instance_id()
		if _attack_already_hit_by_id.has(id):
			return
		_attack_already_hit_by_id[id] = true

		# Prefer the ray hit point. If it isn't present for any reason, fall back to the
		# collider's position (car center) rather than a player-derived value.
		var hit_pos_v: Variant = best.get("position")
		if not (hit_pos_v is Vector2):
			hit_pos_v = best.get(&"position")
		var hit_pos: Vector2
		if hit_pos_v is Vector2:
			hit_pos = hit_pos_v
		elif collider is Node2D:
			hit_pos = (collider as Node2D).global_position
		else:
			hit_pos = global_position + dir * sword_range_px

		var parent = collider.get_parent()

		# Spawn an explosion VFX at the hit position.
		if parent != null and _explosion_scene != null:
			var explosion_pos: Vector2 = hit_pos
			# Cars have their visible sprite offset from the root, so prefer the visual position.
			if collider is Node:
				var car_sprite := (collider as Node).get_node_or_null(^"Sprite2D")
				if car_sprite is Node2D:
					explosion_pos = (car_sprite as Node2D).global_position

			var explosion := _explosion_scene.instantiate()
			(parent as Node).add_child(explosion)
			(explosion as Node2D).global_position = explosion_pos

		(collider as Node).queue_free()

		if parent != null and _crackhead_scene != null:
			var crackhead := _crackhead_scene.instantiate()
			# Give the player time to react before the crackhead starts moving.
			(crackhead as Node).set("spawn_pause_s", 2.0)
			(parent as Node).add_child(crackhead)
			(crackhead as Node2D).global_position = hit_pos


func _on_animated_sprite_animation_finished() -> void:
	var anim = _animated_sprite.animation
	if anim == "attack_down" or anim == "attack_side" or anim == "attack_up":
		_is_attacking = false
		_attack_time_s = 0.0
		_attack_already_hit_by_id.clear()
