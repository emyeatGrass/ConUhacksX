extends Area2D

const SPEED = 200.0

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_deferred("monitoring", false)
	# Return to pool when the coin leaves the visible screen.
	_screen_notifier.screen_exited.connect(_on_screen_exited)
	body_entered.connect(_on_body_entered)
	# If the notifier has a zero rect (common when edited in text),
	# it will instantly count as "off-screen". Give it a reasonable default.
	if _screen_notifier.rect.size == Vector2.ZERO:
		_screen_notifier.rect = Rect2(-16, -16, 32, 32)


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


func _on_body_entered(body: Node2D) -> void:
	# Notify enemies/NPCs and return this coin to the pool.
	# (The pool treats "hidden" coins as available.)
	# Ignore hitting the player immediately on spawn.
	var player := get_node_or_null("/root/World/Player")
	if body == player:
		return
	if body.has_method("hit_by_coin"):
		body.call("hit_by_coin")
	despawn()
