extends Node

signal run_finished

@export var ground_layer_path: NodePath = ^"../Layer0"
@export var objects_layer_path: NodePath = ^"../Layer1"
@export var player_path: NodePath

@export var total_chunks: int = 10
@export var generate_buffer_rows: int = 24
@export var end_buffer_rows: int = 2

var _ground: TileMapLayer
var _objects: TileMapLayer
var _player: Node2D

var _base_origin: Vector2i
var _chunk_height_cells: int = 0

var _ground_tiles: Array[Dictionary] = []
var _object_tiles: Array[Dictionary] = []

var _generated_chunks: int = 1 # includes the starting chunk
var _ended := false

var _row_step_global_y: float = 0.0


func _ready() -> void:
	_ground = get_node_or_null(ground_layer_path) as TileMapLayer
	_objects = get_node_or_null(objects_layer_path) as TileMapLayer

	if player_path != NodePath():
		_player = get_node_or_null(player_path) as Node2D
	if _player == null:
		_player = get_tree().get_first_node_in_group("Player") as Node2D

	if _ground == null or _objects == null or _player == null:
		push_warning("MapRegenerator: Missing nodes (ground=%s objects=%s player=%s)" % [_ground, _objects, _player])
		set_process(false)
		return

	var used := _compute_union_used_rect(_ground, _objects)
	if used.size == Vector2i.ZERO:
		push_warning("MapRegenerator: No used cells found to snapshot.")
		set_process(false)
		return

	_base_origin = used.position
	_chunk_height_cells = used.size.y

	_ground_tiles = _snapshot_layer(_ground, used)
	_object_tiles = _snapshot_layer(_objects, used)

	_row_step_global_y = _compute_row_step_global_y()


func get_current_chunk_index() -> int:
	# 0 = starting chunk (the one authored in the scene).
	if _objects == null or _player == null or _chunk_height_cells <= 0:
		return 0

	var player_local := _objects.to_local(_player.global_position)
	var cell: Vector2i = _objects.local_to_map(player_local)

	# Chunk 0 starts at _base_origin.y and extends downward +_chunk_height_cells.
	# As we generate upward, chunk N starts at (_base_origin.y - N*_chunk_height_cells).
	var delta := _base_origin.y - cell.y
	if delta <= 0:
		return 0

	var idx := int(floor(float(delta) / float(_chunk_height_cells)))
	# Clamp to generated range so offset doesn’t jump ahead of generated content.
	return clampi(idx, 0, max(_generated_chunks - 1, 0))


func get_chunk_height_global_y() -> float:
	if _row_step_global_y == 0.0:
		_row_step_global_y = _compute_row_step_global_y()
	return abs(_row_step_global_y) * float(_chunk_height_cells)


func get_current_chunk_offset_global_y() -> float:
	# Negative = upward.
	return -float(get_current_chunk_index()) * get_chunk_height_global_y()


func _compute_row_step_global_y() -> float:
	if _objects == null:
		return 0.0
	# Use map-to-local then convert to global; works even if tile size/scale changes.
	var g0 := _objects.to_global(_objects.map_to_local(Vector2i(0, 0)))
	var g1 := _objects.to_global(_objects.map_to_local(Vector2i(0, 1)))
	return g1.y - g0.y


func _process(_delta: float) -> void:
	if _ended:
		return
	if _player == null or _objects == null:
		return

	# Convert player's global position into the tilemap's map coordinates.
	var player_local := _objects.to_local(_player.global_position)
	var player_cell: Vector2i = _objects.local_to_map(player_local)

	# Highest generated chunk index (0-based).
	var highest_chunk_index := _generated_chunks - 1
	var current_top_y := _base_origin.y - (_chunk_height_cells * highest_chunk_index)

	# Generate the next chunk when approaching the top of the current one.
	if _generated_chunks < total_chunks and player_cell.y <= (current_top_y + generate_buffer_rows):
		_generate_chunk(_generated_chunks) # next chunk index
		_generated_chunks += 1

	# After the last chunk is generated, end once the player goes beyond its top.
	if _generated_chunks >= total_chunks:
		var final_top_y := _base_origin.y - (_chunk_height_cells * (total_chunks - 1))
		if player_cell.y <= (final_top_y - end_buffer_rows):
			_end_run()


func _generate_chunk(chunk_index: int) -> void:
	# chunk_index: 0 is the original (already present), 1.. are copies upward.
	var offset := Vector2i(0, -_chunk_height_cells * chunk_index)

	for t in _ground_tiles:
		var dest: Vector2i = _base_origin + (t.rel as Vector2i) + offset
		_ground.set_cell(dest, int(t.source_id), t.atlas as Vector2i, int(t.alt))

	for t in _object_tiles:
		var dest2: Vector2i = _base_origin + (t.rel as Vector2i) + offset
		_objects.set_cell(dest2, int(t.source_id), t.atlas as Vector2i, int(t.alt))


func _end_run() -> void:
	if _ended:
		return
	_ended = true

	# Freeze player as a placeholder "end".
	if _player != null:
		_player.set_physics_process(false)
		_player.set_process(false)

	_show_end_overlay()
	run_finished.emit()


func _show_end_overlay() -> void:
	var hud := get_node_or_null("/root/World/HUD")
	if hud == null:
		print("END: reached final chunk.")
		return

	var label := Label.new()
	label.name = "EndLabel"
	label.text = "THE END"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_left = 0.0
	label.anchor_top = 0.0
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.offset_left = 0.0
	label.offset_top = 0.0
	label.offset_right = 0.0
	label.offset_bottom = 0.0
	label.add_theme_font_size_override("font_size", 48)

	hud.add_child(label)


func _snapshot_layer(layer: TileMapLayer, rect: Rect2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for cell: Vector2i in layer.get_used_cells():
		if not rect.has_point(cell):
			continue
		var source_id := layer.get_cell_source_id(cell)
		if source_id == -1:
			continue
		out.append({
			"rel": cell - rect.position,
			"source_id": source_id,
			"atlas": layer.get_cell_atlas_coords(cell),
			"alt": layer.get_cell_alternative_tile(cell),
		})
	return out


func _compute_union_used_rect(a: TileMapLayer, b: TileMapLayer) -> Rect2i:
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF

	for cell: Vector2i in a.get_used_cells():
		min_x = min(min_x, float(cell.x))
		min_y = min(min_y, float(cell.y))
		max_x = max(max_x, float(cell.x))
		max_y = max(max_y, float(cell.y))

	for cell: Vector2i in b.get_used_cells():
		min_x = min(min_x, float(cell.x))
		min_y = min(min_y, float(cell.y))
		max_x = max(max_x, float(cell.x))
		max_y = max(max_y, float(cell.y))

	if min_x == INF or min_y == INF:
		return Rect2i(Vector2i.ZERO, Vector2i.ZERO)

	var pos := Vector2i(int(min_x), int(min_y))
	var size := Vector2i(int(max_x - min_x + 1), int(max_y - min_y + 1))
	return Rect2i(pos, size)

