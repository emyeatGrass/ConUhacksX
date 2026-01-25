extends CharacterBody2D

@export var chase_speed := 50.0
@export var flee_speed := 80.0

@onready var player: Node2D = get_node_or_null("/root/World/Player")
@onready var _screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

var _fleeing := false

func _ready() -> void:
	# Only despawn after being hit (while fleeing).
	_screen_notifier.screen_exited.connect(_on_screen_exited)

func _physics_process(_delta: float) -> void:
	if player == null:
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


func _on_screen_exited() -> void:
	if _fleeing:
		queue_free()
