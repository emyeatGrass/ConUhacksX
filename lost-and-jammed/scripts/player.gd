extends CharacterBody2D



const SPEED = 300.0

func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction:
		velocity = direction * SPEED
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)
	move_and_slide()
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# If we are hit by a car (check by Group or Class)
		if collider.has_method("_on_visible_on_screen_notifier_2d_screen_exited"): # Or use groups: if collider.is_in_group("Car")
			# Create a push vector based on the car's direction
			var push_force = collider.velocity
			# Option 1: Direct shove (Simulates getting hit hard)
			velocity += push_force * 2 * delta
			# Option 2: Position adjustment (Ensures you don't get stuck inside the car)
			# This is useful if the car is very fast
			if push_force.x != 0:
				global_position.x += push_force.x * delta
