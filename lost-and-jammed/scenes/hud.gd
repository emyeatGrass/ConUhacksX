extends CanvasLayer

@export var heart_full: Texture2D
@export var heart_empty: Texture2D

@onready var hearts_box: HBoxContainer = $Hearts

func set_hearts(current: int, max_hearts: int) -> void:
	# Assumes you have exactly max_hearts children (3 in your case)
	for i in range(hearts_box.get_child_count()):
		var heart := hearts_box.get_child(i) as TextureRect
		heart.texture = heart_full if i < current else heart_empty
