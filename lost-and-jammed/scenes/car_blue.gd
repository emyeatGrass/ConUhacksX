extends CharacterBody2D

@export var base_speed = 200.0
var current_speed = 0.0
var direction = -1 # (left)

@onready var ray = $RayCast2D

# Called when the node enters the scene tree for the first time.
func _ready():
	ray.target_position.x = 100 * direction
	current_speed = base_speed

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float):
	if ray.is_colliding():
		var collider = ray.get_collider()
		# If we hit another car, match its speed
		if collider is CharacterBody2D:
			current_speed = lerp(current_speed, collider.velocity.length(), 0.1)
	else:
		# No car in front? Accelerate back to base speed
		current_speed = lerp(current_speed, base_speed, 0.05)

	velocity.x = current_speed * direction
	move_and_slide()

func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free() # Replace with function body.
