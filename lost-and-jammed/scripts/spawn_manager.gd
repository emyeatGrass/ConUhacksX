extends Node2D
var car_scene = preload("res://scenes/car_blue.tscn")

@export var map_regenerator_path: NodePath = ^"../MapRegenerator"

var _map_regen: Node

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_map_regen = get_node_or_null(map_regenerator_path)
	if _map_regen == null:
		# Fallback: try to find by name in the active scene.
		_map_regen = get_tree().root.get_node_or_null("World/MapRegenerator")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _spawn_offset_y() -> float:
	# IMPORTANT: This must be chunk-aligned (discrete), not camera-aligned (continuous),
	# otherwise lanes drift relative to the repeated map chunks.
	if _map_regen != null and _map_regen.has_method("get_current_chunk_offset_global_y"):
		return float(_map_regen.call("get_current_chunk_offset_global_y"))
	return 0.0


func spawn_car():
	var spawn_group = "RightBound" if randf() > 0.5 else "LeftBound"
	var markers = get_tree().get_nodes_in_group(spawn_group)
	if markers.is_empty(): return
	
	var random_marker = markers.pick_random()
	
	# Check if marker has a car
	
	
	var car = car_scene.instantiate()
	car.global_position = random_marker.global_position + Vector2(0, _spawn_offset_y())
	
	if random_marker.is_in_group("RightBound"):
		car.direction = -1 # Move Left
	else:
		car.direction = 1 # Move Right
		
	add_child(car)

func _on_timer_timeout() -> void:
	# 1. Decide direction (50/50 chance)
	var spawn_group = "RightBound" if randf() > 0.5 else "LeftBound"
	
	# 2. Get all markers in that specific group
	var markers = get_tree().get_nodes_in_group(spawn_group)
	var random_marker = markers.pick_random()
	
	# 3. Create the car
	var car = car_scene.instantiate()
	
	# 4. Position it and set direction
	car.global_position = random_marker.global_position + Vector2(0, _spawn_offset_y())
	
	if spawn_group == "RightBound":
		car.direction = -1 # Move left
		car.should_flip = false
	else:
		car.direction = 1 # Move right
		car.should_flip = true
	
	add_child(car)
	# (Don't reassign position after parenting; we already used global_position.)
