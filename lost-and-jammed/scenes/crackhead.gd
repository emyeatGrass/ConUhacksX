extends CharacterBody2D
@onready var player = get_node("/root/World/Player")

func _physics_process(delta):
	var direction = global_position.direction_to(player.global_position)
	velocity = direction * 50
	move_and_slide()
	
	if is_on_floor(): 
		pass

	if get_slide_collision_count() > 0:
		var col = get_slide_collision(0)
		if col.get_collider() == player:
			player.take_damage(1)
