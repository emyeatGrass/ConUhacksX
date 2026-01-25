extends Node

# Runtime adapter to replace deprecated multi-layer TileMap with TileMapLayer nodes,
# so we can y-sort tiles against characters (player/crackheads) properly.

@export var source_tilemap_path: NodePath = ^"../TileMap"
@export var y_sort_origin_px: int = 16

func _ready() -> void:
	var legacy := get_node_or_null(source_tilemap_path) as TileMap
	if legacy == null:
		push_warning("TileMapLayersAdapter: legacy TileMap not found at %s" % [source_tilemap_path])
		return

	var world := legacy.get_parent()
	if world == null:
		return

	# Build layers.
	var ground := TileMapLayer.new()
	ground.name = "GroundLayer"
	ground.tile_set = legacy.tile_set
	ground.position = legacy.position
	ground.scale = legacy.scale
	ground.visible = legacy.visible
	world.add_child(ground)

	var objects := TileMapLayer.new()
	objects.name = "ObjectsLayer"
	objects.tile_set = legacy.tile_set
	objects.position = legacy.position
	objects.scale = legacy.scale
	objects.visible = legacy.visible
	objects.y_sort_enabled = true
	objects.y_sort_origin = y_sort_origin_px
	world.add_child(objects)

	_copy_layer_cells(legacy, 0, ground)
	_copy_layer_cells(legacy, 1, objects)

	# Move y-sorted characters under objects layer (player + any crackheads).
	for child in world.get_children():
		if child == legacy or child == ground or child == objects:
			continue
		if child is Node2D and (child.is_in_group("Player") or child.name.begins_with("Crackhead")):
			(child as Node).reparent(objects)

	# Remove legacy tilemap so it doesn't render/collide twice.
	legacy.queue_free()


func _copy_layer_cells(legacy: TileMap, layer_index: int, target: TileMapLayer) -> void:
	# Godot 4 TileMap API: get_used_cells(layer) returns Array[Vector2i].
	for coords: Vector2i in legacy.get_used_cells(layer_index):
		var source_id := legacy.get_cell_source_id(layer_index, coords)
		if source_id == -1:
			continue
		var atlas_coords := legacy.get_cell_atlas_coords(layer_index, coords)
		var alt := legacy.get_cell_alternative_tile(layer_index, coords)
		target.set_cell(coords, source_id, atlas_coords, alt)
