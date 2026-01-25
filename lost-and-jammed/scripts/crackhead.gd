extends CharacterBody2D

@export var chase_speed := 50.0
@export var flee_speed := 80.0
@export var knockback_distance_px: float = 96.0
@export var knockback_duration_s: float = 0.15

@onready var player: Node2D = get_node_or_null("/root/World/Player")
@onready var _screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
@onready var audio_manager: Node = get_node_or_null("/root/World/AudioManager")

var _fleeing := false
var _knockback_time_left_s: float = 0.0
var _knockback_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Only despawn after being hit (while fleeing).
	_screen_notifier.screen_exited.connect(_on_screen_exited)

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


func hit_by_coin() -> void:
	_fleeing = true
	if audio_manager and audio_manager.has_method("play_enemy_hit"):
		audio_manager.call("play_enemy_hit")


func _on_screen_exited() -> void:
	if _fleeing:
		queue_free()
