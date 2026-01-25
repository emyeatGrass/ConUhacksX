extends Node2D
var car_scene = preload("res://scenes/car_blue.tscn")

@export var map_regenerator_path: NodePath = ^"../MapRegenerator"

var _map_regen: Node
@onready var _timer: Timer = $Timer

func _ready() -> void:
	_map_regen = get_node_or_null(map_regenerator_path)
	if _map_regen == null:
		# Fallback path for when the scene wiring is... aspirational.
		_map_regen = get_tree().root.get_node_or_null("World/MapRegenerator")

func stop_spawning() -> void:
	if _timer:
		_timer.stop()

func start_spawning() -> void:
	if _timer:
		_timer.start()

func _spawn_offset_y() -> float:
	# This must be chunk-aligned (discrete), not camera-aligned (continuous),
	# or the lanes slowly drift until everything looks "kind of wrong" and nobody knows why.
	if _map_regen != null and _map_regen.has_method("get_current_chunk_offset_global_y"):
		return float(_map_regen.call("get_current_chunk_offset_global_y"))
	return 0.0


func _spawn_car_from_group(spawn_group: String) -> void:
	var markers := get_tree().get_nodes_in_group(spawn_group)
	if markers.is_empty():
		return

	var random_marker = markers.pick_random()
	var car = car_scene.instantiate()

	# Set direction BEFORE parenting so the car's `_ready()` can use it.
	# (Because apparently we like temporal coupling now.)
	if spawn_group == "RightBound":
		car.direction = -1
	else:
		car.direction = 1

	car.global_position = random_marker.global_position + Vector2(0, _spawn_offset_y())
	add_child(car)


func spawn_car() -> void:
	# Legacy/manual entrypoint; keeping it so I can pretend this was planned.
	var spawn_group := "RightBound" if randf() > 0.5 else "LeftBound"
	_spawn_car_from_group(spawn_group)

func _on_timer_timeout() -> void:
	var spawn_group := "RightBound" if randf() > 0.5 else "LeftBound"
	_spawn_car_from_group(spawn_group)
