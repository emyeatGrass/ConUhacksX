extends Node2D

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var audio_manager: Node = get_node_or_null("/root/World/AudioManager")

func _ready() -> void:
	if _animated_sprite == null:
		return

	# In case frames/animations aren't assigned yet, avoid errors.
	if _animated_sprite.sprite_frames == null:
		return
	if _animated_sprite.sprite_frames.get_animation_names().is_empty():
		return

	if not _animated_sprite.animation_finished.is_connected(_on_animation_finished):
		_animated_sprite.animation_finished.connect(_on_animation_finished)

	# Ensure the animation can actually finish even if it was authored as looping.
	var anim_name: StringName = _animated_sprite.animation
	if anim_name == StringName():
		anim_name = &"default"
	if _animated_sprite.sprite_frames.has_animation(anim_name):
		_animated_sprite.sprite_frames.set_animation_loop(anim_name, false)

	# Plays the currently selected/default animation (set in the editor).
	_animated_sprite.play()
	
	if audio_manager and audio_manager.has_method("play_explosion"):
		audio_manager.call("play_explosion")


func _on_animation_finished() -> void:
	queue_free()
