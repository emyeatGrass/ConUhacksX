extends CanvasLayer

const GameServices = preload("res://scripts/shared/game_services.gd")

@onready var _p1_bar: ProgressBar = $MarginContainer/PlayersHBox/P1/HealthBar
@onready var _p1_value_label: Label = $MarginContainer/PlayersHBox/P1/ValueLabel
@onready var _p2_container: Control = $MarginContainer/PlayersHBox/P2
@onready var _p2_bar: ProgressBar = $MarginContainer/PlayersHBox/P2/HealthBar
@onready var _p2_value_label: Label = $MarginContainer/PlayersHBox/P2/ValueLabel
@onready var _death_overlay: ColorRect = $DeathOverlay

var _players: Array[Node2D] = []


func _ready() -> void:
	# Multiplayer UI is enabled only when the session says so.
	var session := get_tree().root.get_node_or_null("GameSession")
	var is_multi := false
	if session != null:
		is_multi = bool(session.call("is_multiplayer"))
	if _p2_container:
		_p2_container.visible = is_multi

	_players.clear()
	for n in get_tree().get_nodes_in_group(&"Player"):
		if n is Node2D:
			_players.append(n as Node2D)
	# Stable ordering: by player_id if present, else by name.
	_players.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		var ida := int(a.get("player_id")) if a.get("player_id") != null else 0
		var idb := int(b.get("player_id")) if b.get("player_id") != null else 0
		if ida != idb:
			return ida < idb
		return a.name < b.name
	)

	if _players.is_empty():
		push_warning("HUD: No players found (expected nodes in group 'Player').")
		return

	for p in _players:
		var pid := int(p.get("player_id")) if p.get("player_id") != null else 1
		if p.has_signal("hp_changed"):
			# Bind via closure so we can update the correct bar.
			p.hp_changed.connect(func(hp: int, max_hp: int) -> void:
				_set_hp(pid, hp, max_hp)
			)
		# Initialize from current player state if available.
		var hp_val: int = int(p.get("hp"))
		var max_hp_val: int = int(p.get("max_hp"))
		_set_hp(pid, hp_val, max_hp_val)


func _set_hp(player_id: int, hp: int, max_hp: int) -> void:
	if int(player_id) == 2 and _p2_container and _p2_container.visible:
		_p2_bar.max_value = max_hp
		_p2_bar.value = hp
		_p2_value_label.text = "%d/%d" % [hp, max_hp]
	else:
		_p1_bar.max_value = max_hp
		_p1_bar.value = hp
		_p1_value_label.text = "%d/%d" % [hp, max_hp]

func show_death_overlay(enabled: bool) -> void:
	if _death_overlay == null:
		return
	_death_overlay.visible = enabled

