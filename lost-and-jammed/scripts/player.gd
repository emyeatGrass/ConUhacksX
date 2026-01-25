extends CharacterBody2D

@onready var _animated_sprite = $AnimatedSprite2D
@onready var coin_pool = $"../CoinPool"
@onready var audio_manager: Node = get_node_or_null("../AudioManager")

const SPEED = 100.0
var last_direction;
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
		
	if Input.is_action_just_pressed("shoot"):
		shoot()

	if (last_direction != null):
		var animation = direction_to_idle[last_direction] if velocity == Vector2.ZERO else direction_to_run[last_direction]
		_animated_sprite.play(animation);

func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction:
		velocity = direction * SPEED
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)
	move_and_slide()
	
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# If we are hit by a car (check by Group or Class)
		if collider and collider.has_method("_on_visible_on_screen_notifier_2d_screen_exited"): # Or use groups: if collider.is_in_group("Car")
			# Create a push vector based on the car's direction
			var push_force = collider.velocity
			# Option 1: Direct shove (Simulates getting hit hard)
			velocity += push_force * 2.0 * _delta
			# Option 2: Position adjustment (Ensures you don't get stuck inside the car)
			# This is useful if the car is very fast
			if push_force.x != 0:
				global_position.x += push_force.x * _delta


func shoot() -> void:
	var coin = coin_pool.get_coin()
	if coin:
		var aim_dir: Vector2 = direction_to_vector.get(last_direction, Vector2.RIGHT)
		coin.reset()
		# Spawn a bit in front so it doesn't collide with the player instantly.
		coin.global_position = global_position + aim_dir * 12.0
		coin.global_rotation = aim_dir.angle()
		if audio_manager and audio_manager.has_method("play_coin_fling"):
			audio_manager.call("play_coin_fling")
