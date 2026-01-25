extends CharacterBody2D

@export var base_speed = 400.0
var current_speed = 0.0
var direction = -1 # (left)
var should_flip = false

@onready var sprite = $Sprite2D
@onready var ray = $RayCast2D

# Called when the node enters the scene tree for the first time.
func _ready():
	current_speed = base_speed
	sprite.flip_h = should_flip
	ray.target_position.x = abs(ray.target_position.x) * direction

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float):
	if ray.is_colliding():
		var collider = ray.get_collider()
		# If we hit another car, match its speed
		if collider is CharacterBody2D and collider != self:
			current_speed = lerp(current_speed, collider.velocity.length(), 0.1)
	else:
		# No car in front? Accelerate back to base speed
		current_speed = lerp(current_speed, base_speed, 0.05)

	velocity.x = current_speed * direction
	move_and_slide()

func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free() # Replace with function body.


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		print("Player was hit!")
		# body.die() or get_tree().reload_current_scene()
