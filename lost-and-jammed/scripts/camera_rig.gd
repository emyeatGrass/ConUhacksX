extends Node2D

@export var player_path: NodePath
@export var follow_y: bool = true

var _player: Node2D
var _fixed_x: float

func _ready() -> void:
	_fixed_x = global_position.x
	if player_path != NodePath():
		_player = get_node_or_null(player_path) as Node2D

func _process(_delta: float) -> void:
	if _player == null:
		# Lazy lookup (scene may instantiate player later).
		_player = get_tree().get_first_node_in_group("Player") as Node2D
		if _player == null:
			return

	var p := _player.global_position
	var new_pos := global_position
	new_pos.x = _fixed_x
	if follow_y:
		new_pos.y = p.y
	global_position = new_pos

