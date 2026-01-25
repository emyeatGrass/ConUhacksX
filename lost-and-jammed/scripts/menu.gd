extends Control

@onready var _single_btn: Button = %SingleplayerButton
@onready var _multi_btn: Button = %MultiplayerButton

func _ready() -> void:
	if _single_btn:
		_single_btn.grab_focus()
		_single_btn.pressed.connect(_on_single_pressed)
	if _multi_btn:
		_multi_btn.pressed.connect(_on_multi_pressed)

func _on_single_pressed() -> void:
	var session := get_tree().root.get_node_or_null("GameSession")
	if session != null:
		session.call("set_singleplayer")
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_multi_pressed() -> void:
	var session := get_tree().root.get_node_or_null("GameSession")
	if session != null:
		session.call("set_multiplayer")
	get_tree().change_scene_to_file("res://scenes/main.tscn")

