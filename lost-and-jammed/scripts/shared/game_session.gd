extends Node

# Global game session state (autoload).
# Keeps game mode + lightweight settings, so gameplay code stays modular and testable.

enum GameMode {
	SINGLEPLAYER,
	MULTIPLAYER,
}

@export var revive_duration_s: float = 5.0

var mode: GameMode = GameMode.SINGLEPLAYER

func set_singleplayer() -> void:
	mode = GameMode.SINGLEPLAYER

func set_multiplayer() -> void:
	mode = GameMode.MULTIPLAYER

func is_multiplayer() -> bool:
	return mode == GameMode.MULTIPLAYER
