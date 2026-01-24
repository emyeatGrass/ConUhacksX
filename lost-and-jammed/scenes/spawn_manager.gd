extends Node2D
var car_scene = preload("res://scenes/car_blue.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func spawn_car():
	var spawn_points = get_tree().get_nodes_in_group("RightBound")
	var random_marker = spawn_points.pick_random()
	
	var car = car_scene.instantiate()
	car.global_position = random_marker.global_position
	
	if random_marker.is_in_group("RightBound"):
		car.direction = -1 # Move Left
	else:
		car.direction = 1  # Move Right
		
	add_child(car)


func _on_timer_timeout() -> void:
	# 1. Decide direction first (50/50 chance)
	var spawn_group = "RightBound" if randf() > 0.5 else "LeftBound"
	
	# 2. Get all markers in that specific group
	var markers = get_tree().get_nodes_in_group(spawn_group)
	var random_marker = markers.pick_random()
	
	# 3. Create the car
	var car = car_scene.instantiate()
	add_child(car)
	
	# 4. Position it and set direction
	car.global_position = random_marker.global_position
	
	if spawn_group == "RightBound":
		car.direction = -1 # Move left
		car.rotation_degrees = 0 # Face left
	else:
		car.direction = 1  # Move right
		car.rotation_degrees = 180 # Flip the car sprite to face right
