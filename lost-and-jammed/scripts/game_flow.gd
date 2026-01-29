extends Node

const GameServices = preload("res://scripts/shared/game_services.gd")

@export var respawn_delay_s: float = 2.0
@export var spawn_manager_path: NodePath = ^"../SpawnManager"
@export var map_regenerator_path: NodePath = ^"../MapRegenerator"
@export var objects_layer_path: NodePath = ^"../Layer1"

var _players: Array[Node2D] = []
var _hud: Node
var _coin_pool: Node
var _audio_manager: Node
var _spawn_manager: Node
var _map_regen: Node
var _objects_layer: Node

var _spawn_positions_by_id: Dictionary = {}
var _is_respawning: bool = false
var _respawn_requested_frame: int = -1  # Frame when respawn was last requested


func _ready() -> void:
	_hud = GameServices.get_hud(get_tree())
	_coin_pool = GameServices.get_coin_pool(get_tree())
	_audio_manager = GameServices.get_audio_manager(get_tree())
	_spawn_manager = get_node_or_null(spawn_manager_path)
	_map_regen = get_node_or_null(map_regenerator_path)
	_objects_layer = get_node_or_null(objects_layer_path)

	_players = _get_players_sorted()
	for p in _players:
		var pid := int(p.get("player_id")) if p.get("player_id") != null else 1
		_spawn_positions_by_id[pid] = p.global_position

	var is_multi := _is_multiplayer()
	for p in _players:
		if is_multi and p.has_signal("downed"):
			p.downed.connect(func() -> void:
				_on_any_player_downed()
			)
		elif (not is_multi) and p.has_signal("died"):
			p.died.connect(func() -> void:
				_on_any_player_died_singleplayer()
			)


func _on_any_player_died_singleplayer() -> void:
	# Legacy behavior: immediate respawn on death.
	# Use deferred call to consolidate multiple death events in the same frame.
	_request_respawn_deferred()

func _on_any_player_downed() -> void:
	# Multiplayer behavior: only respawn the run when *all* players are downed.
	if _is_respawning:
		return
	if not _all_players_downed():
		return
	# Use deferred call to consolidate multiple death events in the same frame.
	_request_respawn_deferred()

func _request_respawn_deferred() -> void:
	# Prevent multiple respawn requests in the same frame.
	var current_frame := Engine.get_process_frames()
	if _respawn_requested_frame == current_frame:
		return
	_respawn_requested_frame = current_frame
	# Defer the actual respawn so all death signals in this frame are processed first.
	call_deferred("_on_respawn_sequence")

func _on_respawn_sequence() -> void:
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
	if _audio_manager != null and _audio_manager.has_method("play_game_over"):
		_audio_manager.call("play_game_over")
	if _hud != null and _hud.has_method("show_death_overlay"):
		_hud.call("show_death_overlay", true)

	await get_tree().create_timer(maxf(respawn_delay_s, 0.0)).timeout

	# Reset map back to the authored start.
	if _map_regen != null and _map_regen.has_method("reset_run"):
		_map_regen.call("reset_run")

	# Respawn all players.
	_players = _get_players_sorted()
	for p in _players:
		var pid := int(p.get("player_id")) if p.get("player_id") != null else 1
		var spawn_pos: Vector2 = _spawn_positions_by_id.get(pid, p.global_position)
		if p.has_method("revive_at"):
			p.call("revive_at", spawn_pos)
		else:
			p.global_position = spawn_pos
			p.set_process(true)
			p.set_physics_process(true)

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
	# Keep player nodes.
	if _objects_layer != null:
		for c in _objects_layer.get_children():
			if c is Node and (c as Node).is_in_group("Player"):
				continue
			(c as Node).queue_free()

func _get_players_sorted() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for n in get_tree().get_nodes_in_group(&"Player"):
		if n is Node2D:
			out.append(n as Node2D)
	out.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		var ida := int(a.get("player_id")) if a.get("player_id") != null else 0
		var idb := int(b.get("player_id")) if b.get("player_id") != null else 0
		if ida != idb:
			return ida < idb
		return a.name < b.name
	)
	return out

func _all_players_downed() -> bool:
	_players = _get_players_sorted()
	if _players.is_empty():
		return true
	for p in _players:
		if p.has_method("is_downed") and bool(p.call("is_downed")):
			continue
		return false
	return true

func _is_multiplayer() -> bool:
	var session := get_tree().root.get_node_or_null("GameSession")
	return session != null and bool(session.call("is_multiplayer"))

