extends CanvasLayer

const GameServices = preload("res://scripts/shared/game_services.gd")

@onready var _bar: ProgressBar = $MarginContainer/HBoxContainer/HealthBar
@onready var _value_label: Label = $MarginContainer/HBoxContainer/ValueLabel
@onready var _death_overlay: ColorRect = $DeathOverlay

var _player: Node


func _ready() -> void:
	_player = GameServices.get_player(get_tree())
	if _player == null:
		push_warning("HUD: Player not found (expected node in group 'Player').")
		return

	var cb := Callable(self, "_on_hp_changed")
	if _player.has_signal("hp_changed") and not _player.is_connected("hp_changed", cb):
		_player.connect("hp_changed", cb)

	# Initialize from current player state if available.
	var hp_val: int = int(_player.get("hp"))
	var max_hp_val: int = int(_player.get("max_hp"))
	_on_hp_changed(hp_val, max_hp_val)


func _on_hp_changed(hp: int, max_hp: int) -> void:
	_bar.max_value = max_hp
	_bar.value = hp
	_value_label.text = "%d/%d" % [hp, max_hp]

func show_death_overlay(enabled: bool) -> void:
	if _death_overlay == null:
		return
	_death_overlay.visible = enabled

