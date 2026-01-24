extends CharacterBody2D

@export var speed = 300.0
var direction = Vector2.LEFT

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float):
	velocity.x = -speed
	move_and_slide()


func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free() # Replace with function body.
