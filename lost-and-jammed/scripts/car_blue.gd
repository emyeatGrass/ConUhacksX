extends CharacterBody2D

@export var base_speed = 400.0
var current_speed = 0.0
var direction = -1 
var should_flip = false;
@export var hit_cooldown_s: float = 0.2

@onready var sprite = $Sprite2D
@onready var ray = $RayCast2D
var _recent_hit_time_left_by_id: Dictionary = {}

func _ready():
	current_speed = base_speed
	if direction == 1:
		sprite.flip_h = true
	ray.set_collision_mask_value(2, false) 

func _physics_process(delta: float) -> void:
	# Decay per-body hit cooldowns.
	for id in _recent_hit_time_left_by_id.keys():
		_recent_hit_time_left_by_id[id] = float(_recent_hit_time_left_by_id[id]) - delta
		if float(_recent_hit_time_left_by_id[id]) <= 0.0:
			_recent_hit_time_left_by_id.erase(id)

	if ray.is_colliding():
		var collider = ray.get_collider()
		# Ensure we don't brake for the player accidentally
		if collider is CharacterBody2D and collider != self and not collider.is_in_group("Player"):
			current_speed = lerp(current_speed, collider.velocity.length(), 0.1)
	else:
		current_speed = lerp(current_speed, base_speed, 0.05)
		
	velocity.x = current_speed * direction
	velocity.y = 0 
	move_and_slide()

# Deletes car when it leaves the screen
func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free()

# Detects when the player is "squashed" or hit
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body == null:
		return

	# Knockback anything that supports it (player + crackheads).
	if not body.has_method("apply_knockback"):
		return

	var id := body.get_instance_id()
	if _recent_hit_time_left_by_id.has(id):
		return
	_recent_hit_time_left_by_id[id] = hit_cooldown_s

	# Compute knockback from hit position + car travel direction.
	# - `hit_dir`: where the body is relative to the car (car -> body)
	# - `car_dir`: direction the car is moving
	var hit_dir: Vector2 = (body.global_position - global_position).normalized()

	var car_dir: Vector2 = velocity.normalized()
	if car_dir == Vector2.ZERO:
		car_dir = Vector2.RIGHT * float(direction)

	# If the body is in front of the car, bias knockback forward.
	var forwardness: float = maxf(hit_dir.dot(car_dir), 0.0)
	var knock_dir: Vector2 = (hit_dir + car_dir * forwardness).normalized()
	if knock_dir == Vector2.ZERO:
		knock_dir = hit_dir if hit_dir != Vector2.ZERO else car_dir

	body.call("apply_knockback", knock_dir)

	if body.is_in_group("Player") and body.has_method("take_damage"):
		body.call("take_damage", 20)
