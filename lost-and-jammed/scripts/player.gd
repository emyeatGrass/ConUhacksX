extends CharacterBody2D

@onready var _animated_sprite = $AnimatedSprite2D

const SPEED = 100.0
var last_direction;
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

func _process(delta: float) -> void:
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

	if (last_direction != null):
		var animation = direction_to_idle[last_direction] if velocity == Vector2.ZERO else direction_to_run[last_direction]
		_animated_sprite.play(animation);

func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction:
		velocity = direction * SPEED
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)

	move_and_slide()
