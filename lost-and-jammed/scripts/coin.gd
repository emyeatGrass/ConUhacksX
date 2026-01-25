extends Area2D

const SPEED = 800.0

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_deferred("monitoring", false)
	# Return to pool when the coin leaves the visible screen.
	_screen_notifier.screen_exited.connect(_on_screen_exited)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	position += Vector2.RIGHT.rotated(rotation) * SPEED * delta
	
	
func reset() -> void:
	show()
	set_deferred("monitoring", true)
	set_physics_process(true)
	_animated_sprite.play()


func despawn() -> void:
	hide()
	set_deferred("monitoring", false)
	set_physics_process(false)
	_animated_sprite.stop()


func _on_screen_exited() -> void:
	despawn()
