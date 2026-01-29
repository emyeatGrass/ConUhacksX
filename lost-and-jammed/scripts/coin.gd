extends Area2D

const GameServices = preload("res://scripts/shared/game_services.gd")

const SPEED = 200.0

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

var owner_player: Node2D = null

func _ready() -> void:
	set_deferred("monitoring", false)
	# Return to pool when the coin leaves the visible screen.
	_screen_notifier.screen_exited.connect(_on_screen_exited)
	body_entered.connect(_on_body_entered)
	# If the notifier has a zero rect (common when edited in text),
	# it will instantly count as "off-screen". Give it a reasonable default.
	if _screen_notifier.rect.size == Vector2.ZERO:
		_screen_notifier.rect = Rect2(-16, -16, 32, 32)


func _physics_process(delta: float) -> void:
	position += Vector2.RIGHT.rotated(rotation) * SPEED * delta
	
	
func reset() -> void:
	show()
	set_deferred("monitoring", true)
	set_physics_process(true)
	_animated_sprite.play()
	owner_player = null


func despawn() -> void:
	hide()
	set_deferred("monitoring", false)
	set_physics_process(false)
	_animated_sprite.stop()
	owner_player = null


func _on_screen_exited() -> void:
	despawn()


func _on_body_entered(body: Node2D) -> void:
	# Coins are pooled: "hidden" == "available", because we are too tired to free/instance.
	# Ignore hitting the shooter to avoid self-bonking (especially important in multiplayer).
	if owner_player != null and body == owner_player:
		return
	if body.has_method("hit_by_coin"):
		body.call("hit_by_coin", owner_player)
	despawn()
