extends CharacterBody2D

@export var chase_speed := 50.0
@export var flee_speed := 80.0
@export var knockback_distance_px: float = 96.0
@export var knockback_duration_s: float = 0.15
@export var spawn_pause_s: float = 0.0: set = _set_spawn_pause_s

@onready var player: Node2D = get_tree().get_first_node_in_group("Player") as Node2D
@onready var _screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
@onready var audio_manager: Node = get_node_or_null("/root/World/AudioManager")

var _fleeing := false
var _spawn_pause_left_s: float = 0.0
var _knockback_time_left_s: float = 0.0
var _knockback_velocity: Vector2 = Vector2.ZERO
var _friendly := false

func _ready() -> void:
	# Only despawn after being hit (while fleeing).
	_screen_notifier.screen_exited.connect(_on_screen_exited)
	_spawn_pause_left_s = maxf(spawn_pause_s, 0.0)


func _set_spawn_pause_s(value: float) -> void:
	spawn_pause_s = maxf(value, 0.0)
	# If this is set after spawning/ready, still apply it immediately.
	_spawn_pause_left_s = maxf(spawn_pause_s, _spawn_pause_left_s)

func apply_knockback(knock_dir: Vector2) -> void:
	var dir := knock_dir.normalized()
	if dir == Vector2.ZERO:
		dir = -velocity.normalized()
	if dir == Vector2.ZERO:
		dir = (global_position - player.global_position).normalized() if player != null else Vector2.LEFT

	_knockback_time_left_s = knockback_duration_s
	_knockback_velocity = dir * (knockback_distance_px / max(knockback_duration_s, 0.001))


func _physics_process(delta: float) -> void:
	if player == null:
		return

	if _knockback_time_left_s > 0.0:
		_knockback_time_left_s = max(_knockback_time_left_s - delta, 0.0)
		velocity = _knockback_velocity
		move_and_slide()
		return

	if _spawn_pause_left_s > 0.0:
		_spawn_pause_left_s = maxf(_spawn_pause_left_s - delta, 0.0)
		velocity = Vector2.ZERO
		move_and_slide()
		# Grace period: touching the player does nothing.
		return

	var direction: Vector2
	if _fleeing:
		# Move away from the player.
		direction = player.global_position.direction_to(global_position)
		velocity = direction * flee_speed
	else:
		# Default behavior: chase player until hit.
		direction = global_position.direction_to(player.global_position)
		velocity = direction * chase_speed

	move_and_slide()
	_check_player_touch()


func _check_player_touch() -> void:
	# During the grace period, ignore contact entirely.
	if _spawn_pause_left_s > 0.0:
		return
	# If a crackhead received a coin, it becomes friendly.
	if _friendly:
		return

	var count := get_slide_collision_count()
	if count <= 0:
		return

	for i in range(count):
		var c := get_slide_collision(i)
		if c == null:
			continue
		var collider := c.get_collider()
		if collider == null:
			continue

		var collider_node := collider as Node
		if collider_node == null:
			continue

		if collider_node.is_in_group("Player"):
			if collider_node.has_method("take_damage"):
				collider_node.call("take_damage", 10)
			queue_free()
			return


func hit_by_coin() -> void:
	# Getting hit by a coin ends the grace period (if any) and makes the crackhead friendly.
	_spawn_pause_left_s = 0.0
	_friendly = true
	_fleeing = true
	if audio_manager and audio_manager.has_method("play_enemy_hit"):
		audio_manager.call("play_enemy_hit")


func _on_screen_exited() -> void:
	if _fleeing:
		queue_free()
