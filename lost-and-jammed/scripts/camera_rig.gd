extends Node2D

const GameServices = preload("res://scripts/shared/game_services.gd")

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
		_player = GameServices.get_player(get_tree())
		if _player == null:
			return

	# Multiplayer: follow the midpoint of alive players.
	var sum_y := 0.0
	var count := 0
	for n in get_tree().get_nodes_in_group(&"Player"):
		if not (n is Node2D):
			continue
		var pnode := n as Node2D
		if pnode.has_method("is_downed") and bool(pnode.call("is_downed")):
			continue
		sum_y += pnode.global_position.y
		count += 1

	var p := _player.global_position
	if count > 0:
		p.y = sum_y / float(count)
	var new_pos := global_position
	new_pos.x = _fixed_x
	if follow_y:
		new_pos.y = p.y
	global_position = new_pos

