extends CharacterBody2D

@export var base_speed = 400.0
var current_speed = 0.0
var direction = -1 
var should_flip = false;

@onready var sprite = $Sprite2D
@onready var ray = $RayCast2D

func _ready():
	current_speed = base_speed
	if direction == 1:
		sprite.flip_h = true
	ray.set_collision_mask_value(2, false) 

func _physics_process(delta: float) -> void:
	if ray.is_colliding():
		var collider = ray.get_collider()
		# Ensure we don't brake for the player accidentally
		if collider is CharacterBody2D and collider != self and not collider.is_in_group("Player"):
			current_speed = lerp(current_speed, collider.velocity.length(), 0.1)
	else:
		current_speed = lerp(current_speed, base_speed, 0.05)
		
	velocity.x = current_speed * direction
	velocity.y = 0 
	move_and_slide()

# Deletes car when it leaves the screen
func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free()

# Detects when the player is "squashed" or hit
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		print("Player was hit!")
		# You can add: body.take_damage() or get_tree().reload_current_scene()
