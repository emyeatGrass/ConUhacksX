extends Node2D

@export var player_scene: PackedScene = preload("res://scenes/player.tscn")
@export var player_layer_path: NodePath = ^"Layer1"
@export var player1_path: NodePath = ^"Layer1/Player"
@export var player2_spawn_offset: Vector2 = Vector2(32, 0)

func _input(event: InputEvent) -> void:
	# Return to main menu when escape is pressed
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _enter_tree() -> void:
	# Configure players before their `_ready()` runs (so inputs/tags are correct).
	var p1 := get_node_or_null(player1_path)
	if p1 != null:
		p1.set("player_id", 1)
		p1.set("player_label", "P1")

	var session := get_tree().root.get_node_or_null("GameSession")
	if session == null:
		return
	var is_multi: bool = bool(session.call("is_multiplayer"))
	if not is_multi:
		return

	# Spawn P2 as a second instance of the player scene.
	var layer := get_node_or_null(player_layer_path)
	if layer == null or player_scene == null:
		return

	# Avoid double-spawning if the scene is reloaded.
	if layer.get_node_or_null(^"Player2") != null:
		return

	var p2 := player_scene.instantiate()
	p2.name = "Player2"
	# Set identity before entering the tree, so `Player._ready()` uses correct inputs/tag.
	p2.set("player_id", 2)
	p2.set("player_label", "P2")
	layer.add_child(p2)

	# Mirror authored P1 transform for consistency.
	if p1 is Node2D and p2 is Node2D:
		(p2 as Node2D).global_position = (p1 as Node2D).global_position + player2_spawn_offset
		(p2 as Node2D).scale = (p1 as Node2D).scale

