extends Node

const GameServices = preload("res://scripts/shared/game_services.gd")

@export var respawn_delay_s: float = 2.0
@export var spawn_manager_path: NodePath = ^"../SpawnManager"
@export var map_regenerator_path: NodePath = ^"../MapRegenerator"
@export var objects_layer_path: NodePath = ^"../Layer1"

var _player: Node
var _hud: Node
var _coin_pool: Node
var _spawn_manager: Node
var _map_regen: Node
var _objects_layer: Node

var _spawn_pos: Vector2 = Vector2.ZERO
var _is_respawning: bool = false


func _ready() -> void:
	_player = GameServices.get_player(get_tree())
	_hud = GameServices.get_hud(get_tree())
	_coin_pool = GameServices.get_coin_pool(get_tree())
	_spawn_manager = get_node_or_null(spawn_manager_path)
	_map_regen = get_node_or_null(map_regenerator_path)
	_objects_layer = get_node_or_null(objects_layer_path)

	if _player is Node2D:
		_spawn_pos = (_player as Node2D).global_position

	if _player != null and _player.has_signal("died"):
		var cb := Callable(self, "_on_player_died")
		if not _player.is_connected("died", cb):
			_player.connect("died", cb)


func _on_player_died() -> void:
	if _is_respawning:
		return
	_is_respawning = true

	# Stop spawns immediately.
	if _spawn_manager != null and _spawn_manager.has_method("stop_spawning"):
		_spawn_manager.call("stop_spawning")

	# Clear dynamic entities.
	_clear_spawned_entities()

	# Despawn pooled projectiles.
	if _coin_pool != null and _coin_pool.has_method("despawn_all"):
		_coin_pool.call("despawn_all")

	# Show gray overlay.
	if _hud != null and _hud.has_method("show_death_overlay"):
		_hud.call("show_death_overlay", true)

	await get_tree().create_timer(maxf(respawn_delay_s, 0.0)).timeout

	# Reset map back to the authored start.
	if _map_regen != null and _map_regen.has_method("reset_run"):
		_map_regen.call("reset_run")

	# Respawn the player.
	if _player != null and _player.has_method("revive_at"):
		_player.call("revive_at", _spawn_pos)
	elif _player is Node2D:
		(_player as Node2D).global_position = _spawn_pos
		_player.set_process(true)
		_player.set_physics_process(true)

	# Hide gray overlay and resume spawns.
	if _hud != null and _hud.has_method("show_death_overlay"):
		_hud.call("show_death_overlay", false)
	if _spawn_manager != null and _spawn_manager.has_method("start_spawning"):
		_spawn_manager.call("start_spawning")

	_is_respawning = false


func _clear_spawned_entities() -> void:
	# 1) Clear cars spawned under SpawnManager (but keep Timer + lane markers).
	if _spawn_manager != null:
		for c in _spawn_manager.get_children():
			if c is Timer:
				continue
			if c is Node and ((c as Node).is_in_group("LeftBound") or (c as Node).is_in_group("RightBound")):
				continue
			(c as Node).queue_free()

	# 2) Clear any other dynamic entities parented under the objects layer (crackheads, explosions, etc.).
	# Keep the player node.
	if _objects_layer != null:
		for c in _objects_layer.get_children():
			if c == _player:
				continue
			(c as Node).queue_free()

