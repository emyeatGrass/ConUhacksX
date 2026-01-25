extends CharacterBody2D

const GameServices = preload("res://scripts/shared/game_services.gd")

@onready var _animated_sprite = $AnimatedSprite2D
@onready var coin_pool: Node = GameServices.get_coin_pool(get_tree())
@onready var audio_manager: Node = GameServices.get_audio_manager(get_tree())

signal hp_changed(hp: int, max_hp: int)
signal died
signal downed
signal revived

@export var player_id: int = 1
@export var player_label: String = "P1"

@export var max_hp: int = 100
var hp: int = 100

@export var death_animation_name: StringName = &"death"
var _is_downed: bool = false
var _base_collision_layer: int
var _base_collision_mask: int

@export var damage_flash_color: Color = Color(1.0, 0.2, 0.2, 1.0)
@export var damage_flash_out_s: float = 0.12
var _damage_flash_tween: Tween

const SPEED = 100.0
var last_direction;
var _is_attacking := false
@export var sword_range_px := 64.0
@export var sword_half_width_px := 10.0
@export var sword_origin_forward_px := 12.0
@export var sword_active_start_s := 0.05
@export var sword_active_end_s := 0.45

var _attack_time_s := 0.0
var _attack_dir: Vector2 = Vector2.RIGHT
var _attack_already_hit_by_id: Dictionary = {}

var _crackhead_scene: PackedScene = preload("res://scenes/crackhead.tscn")
var _explosion_scene: PackedScene = preload("res://scenes/explosion.tscn")
@export var knockback_distance_px: float = 64.0
@export var knockback_duration_s: float = 0.15
var _knockback_time_left_s: float = 0.0
var _knockback_velocity: Vector2 = Vector2.ZERO
const direction_to_vector := {
	"right": Vector2.RIGHT,
	"left": Vector2.LEFT,
	"up": Vector2.UP,
	"down": Vector2.DOWN,
}
const direction_to_idle = {
	"right": "idle_side",
	"left": "idle_side",
	"up": "idle_up",
	"down": "idle_down"
}
const direction_to_run = {
	"right": "run_side",
	"left": "run_side",
	"up": "run_up",
	"down": "run_down"
}

@export var revive_duration_s: float = 5.0
@export var revive_distance_px: float = 20.0
@export var revive_hp_fraction: float = 0.5
var _revive_progress_s: float = 0.0
var _revive_bar: ProgressBar = null
var _screen_notifier: VisibleOnScreenNotifier2D = null
var _revive_grace_frames: int = 0  # Grace period after revival to prevent instant screen-exit death

var _move_left_action: StringName
var _move_right_action: StringName
var _move_up_action: StringName
var _move_down_action: StringName
var _attack_action: StringName
var _shoot_action: StringName

func _action_name(base: String) -> StringName:
	var suffix := "p1" if int(player_id) == 1 else "p2"
	return StringName("%s_%s" % [base, suffix])

func _ready() -> void:
	# Resolve input actions for this player.
	_move_left_action = _action_name("move_left")
	_move_right_action = _action_name("move_right")
	_move_up_action = _action_name("move_up")
	_move_down_action = _action_name("move_down")
	_attack_action = _action_name("attack")
	_shoot_action = _action_name("shoot")

	# Multiplayer tuning.
	if _is_multiplayer():
		# Disable player-vs-player collision so revival can overlap cleanly.
		# Player scene uses collision_layer=2, so remove bit 2 from mask.
		collision_mask = int(collision_mask) & ~2
		# Pull revive duration from session (single source of truth) if present.
		var session := get_tree().root.get_node_or_null("GameSession")
		if session != null:
			revive_duration_s = float(session.get("revive_duration_s"))

	# Initialize HP.
	hp = clampi(max_hp, 0, max_hp)
	hp_changed.emit(hp, max_hp)
	_base_collision_layer = int(collision_layer)
	_base_collision_mask = int(collision_mask)

	_ensure_player_tag()
	_ensure_screen_notifier()

	# Ensure we always have a facing direction.
	if last_direction == null:
		last_direction = "right"

	# Used to end non-looping attack animations cleanly.
	if _animated_sprite and not _animated_sprite.animation_finished.is_connected(_on_animated_sprite_animation_finished):
		_animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)

func _process(delta: float) -> void:
	# Decrement the revive grace period (allows camera to catch up before screen-exit checks).
	if _revive_grace_frames > 0:
		_revive_grace_frames -= 1
	
	if _is_downed:
		_ensure_revive_bar()
		_process_revive(delta)
		return

	if Input.is_action_pressed(_move_right_action):
		last_direction = "right";
		_animated_sprite.flip_h = false;
	elif Input.is_action_pressed(_move_left_action):
		last_direction = "left";
		_animated_sprite.flip_h = true;
	elif Input.is_action_pressed(_move_up_action):
		last_direction = "up";
	elif Input.is_action_pressed(_move_down_action):
		last_direction = "down";
		
	if Input.is_action_just_pressed(_attack_action):
		_start_attack()

	if Input.is_action_just_pressed(_shoot_action) and not _is_attacking:
		shoot()

	# While attacking, keep the attack animation (don't overwrite with idle/run).
	if _is_attacking:
		return

	if (last_direction != null):
		var animation = direction_to_idle[last_direction] if velocity == Vector2.ZERO else direction_to_run[last_direction]
		_animated_sprite.play(animation);

func take_damage(amount: int) -> void:
	if _is_downed:
		return
	if amount <= 0:
		return
	var new_hp := clampi(hp - amount, 0, max_hp)
	if new_hp == hp:
		return
	hp = new_hp
	hp_changed.emit(hp, max_hp)
	if audio_manager and audio_manager.has_method("play_player_hurt"):
		audio_manager.call("play_player_hurt")
	if hp <= 0:
		_die()
		return
	_flash_damage()

func heal_hp(amount: int) -> void:
	if amount <= 0:
		return
	if hp >= max_hp:
		return
	var new_hp := clampi(hp + amount, 0, max_hp)
	if new_hp == hp:
		return
	hp = new_hp
	hp_changed.emit(hp, max_hp)

func revive_at(spawn_global_pos: Vector2, hp_override: int = -1) -> void:
	_is_downed = false
	collision_layer = _base_collision_layer
	collision_mask = _base_collision_mask
	global_position = spawn_global_pos
	velocity = Vector2.ZERO
	_knockback_time_left_s = 0.0
	_knockback_velocity = Vector2.ZERO
	_is_attacking = false
	_attack_time_s = 0.0
	_attack_already_hit_by_id.clear()
	_revive_progress_s = 0.0
	_set_revive_ui_visible(false)
	# Grace period to allow camera to reposition before screen-exit checks.
	_revive_grace_frames = 5
	if is_instance_valid(_damage_flash_tween):
		_damage_flash_tween.kill()
	if _animated_sprite:
		_animated_sprite.self_modulate = Color.WHITE
		# Return to a sane idle.
		var dir_key: String = last_direction if last_direction != null else "right"
		_animated_sprite.play(direction_to_idle.get(dir_key, "idle_side"))
	set_process(true)
	set_physics_process(true)
	# Reset HP last so HUD updates reflect the new life.
	if hp_override >= 0:
		hp = clampi(hp_override, 0, max_hp)
	else:
		hp = clampi(max_hp, 0, max_hp)
	hp_changed.emit(hp, max_hp)
	revived.emit()

func _flash_damage() -> void:
	if _animated_sprite == null:
		return

	# Restart flash cleanly if we get hit again mid-flash.
	if is_instance_valid(_damage_flash_tween):
		_damage_flash_tween.kill()

	_animated_sprite.self_modulate = damage_flash_color
	_damage_flash_tween = create_tween()
	_damage_flash_tween.tween_property(_animated_sprite, "self_modulate", Color.WHITE, damage_flash_out_s)

func _die() -> void:
	if _is_downed:
		return
	_is_downed = true

	# Stop player control immediately, but keep `_process` so revive logic can run.
	set_physics_process(false)
	velocity = Vector2.ZERO

	# Prevent further hits/collisions while dead.
	collision_layer = 0
	collision_mask = 0

	# Play death animation if available.
	if _animated_sprite and _animated_sprite.sprite_frames:
		if _animated_sprite.sprite_frames.has_animation(death_animation_name):
			_animated_sprite.play(death_animation_name)
		else:
			push_warning("Player: death animation '%s' not found in SpriteFrames." % [death_animation_name])

	# Singleplayer keeps the legacy "died" signal semantics.
	if not _is_multiplayer():
		set_process(false)
		died.emit()
		return

	# Multiplayer: player is "downed" until revived or both players are downed.
	_ensure_revive_bar()
	_set_revive_ui_visible(false)
	downed.emit()

func apply_knockback(knock_dir: Vector2) -> void:
	var fallback_dir: Vector2 = -direction_to_vector.get(last_direction, Vector2.RIGHT)
	_knockback_time_left_s = knockback_duration_s
	_knockback_velocity = GameServices.compute_knockback_velocity(
		knock_dir,
		velocity,
		fallback_dir,
		knockback_distance_px,
		knockback_duration_s,
		Vector2.RIGHT
	)


func _physics_process(delta: float) -> void:
	if _is_downed:
		return

	if _knockback_time_left_s > 0.0:
		_knockback_time_left_s = max(_knockback_time_left_s - delta, 0.0)
		velocity = _knockback_velocity
		move_and_slide()
		return

	if _is_attacking:
		_attack_time_s += delta
		if _attack_time_s >= sword_active_start_s and _attack_time_s <= sword_active_end_s:
			_do_sword_hit(_attack_dir)
		# Lock movement during attack (simple + readable).
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var direction := Input.get_vector(_move_left_action, _move_right_action, _move_up_action, _move_down_action)
	if direction:
		velocity = direction * SPEED
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)
	move_and_slide()


func shoot() -> void:
	if coin_pool == null:
		push_warning("Player: CoinPool not found (expected at /root/World/CoinPool)")
		return
	var coin = coin_pool.get_coin()
	if coin:
		var aim_dir: Vector2 = direction_to_vector.get(last_direction, Vector2.RIGHT)
		coin.reset()
		# Attribute the coin to this player (for self-hit ignore + correct healing).
		coin.set("owner_player", self)
		# Spawn a bit in front so it doesn't collide with the player instantly.
		coin.global_position = global_position + aim_dir * 12.0
		coin.global_rotation = aim_dir.angle()
		if audio_manager and audio_manager.has_method("play_coin_fling"):
			audio_manager.call("play_coin_fling")


func _start_attack() -> void:
	if _is_attacking:
		return
	_is_attacking = true
	_attack_time_s = 0.0
	_attack_already_hit_by_id.clear()

	var dir_key: String = last_direction if last_direction != null else "right"
	var attack_dir: Vector2 = direction_to_vector.get(dir_key, Vector2.RIGHT)
	_attack_dir = attack_dir

	# Play attack animation based on facing.
	match dir_key:
		"up":
			_animated_sprite.play("attack_up")
		"down":
			_animated_sprite.play("attack_down")
		_:
			_animated_sprite.play("attack_side")
	if audio_manager and audio_manager.has_method("play_sword_attack"):
		audio_manager.call("play_sword_attack")


func _do_sword_hit(attack_dir: Vector2) -> void:
	var dir := attack_dir.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	var ortho := Vector2(-dir.y, dir.x)

	var space := get_world_2d().direct_space_state
	var base_origin: Vector2 = global_position + dir * sword_origin_forward_px
	var origins := [
		base_origin,
		base_origin + ortho * sword_half_width_px,
		base_origin - ortho * sword_half_width_px,
	]

	var best: Dictionary = {}
	var best_dist_sq := INF

	for o in origins:
		var params := PhysicsRayQueryParameters2D.create(o, o + dir * sword_range_px)
		params.exclude = [self]
		# Query all layers, then filter by car layer on the hit collider.
		# This avoids issues if cars change layers later.
		params.collision_mask = -1
		params.collide_with_areas = true
		params.collide_with_bodies = true

		var hit := space.intersect_ray(params)
		if hit.is_empty():
			continue

		var d2 = o.distance_squared_to(hit.position)
		if d2 < best_dist_sq:
			best_dist_sq = d2
			best = hit

	if best.is_empty():
		return

	var collider = best.get("collider")
	if collider == null:
		return

	# Treat anything on the car layer bit as a "car" target.
	if collider is CollisionObject2D and (int((collider as CollisionObject2D).collision_layer) & 4) != 0:
		var id := (collider as Node).get_instance_id()
		if _attack_already_hit_by_id.has(id):
			return
		_attack_already_hit_by_id[id] = true

		# Prefer the ray hit point. If it isn't present for any reason, fall back to the
		# collider's position (car center) rather than a player-derived value.
		var hit_pos_v: Variant = best.get("position")
		if not (hit_pos_v is Vector2):
			hit_pos_v = best.get(&"position")
		var hit_pos: Vector2
		if hit_pos_v is Vector2:
			hit_pos = hit_pos_v
		elif collider is Node2D:
			hit_pos = (collider as Node2D).global_position
		else:
			hit_pos = global_position + dir * sword_range_px

		var parent = collider.get_parent()

		# Spawn an explosion VFX at the hit position.
		if parent != null and _explosion_scene != null:
			var explosion_pos: Vector2 = hit_pos
			# Cars have their visible sprite offset from the root, so prefer the visual position.
			if collider is Node:
				var car_sprite := (collider as Node).get_node_or_null(^"Sprite2D")
				if car_sprite is Node2D:
					explosion_pos = (car_sprite as Node2D).global_position

			var explosion := _explosion_scene.instantiate()
			(parent as Node).add_child(explosion)
			(explosion as Node2D).global_position = explosion_pos

		(collider as Node).queue_free()

		if parent != null and _crackhead_scene != null:
			var crackhead := _crackhead_scene.instantiate()
			# Give the player time to react before the crackhead starts moving.
			(crackhead as Node).set("spawn_pause_s", 2.0)
			(parent as Node).add_child(crackhead)
			(crackhead as Node2D).global_position = hit_pos


func _on_animated_sprite_animation_finished() -> void:
	var anim = _animated_sprite.animation
	if anim == "attack_down" or anim == "attack_side" or anim == "attack_up":
		_is_attacking = false
		_attack_time_s = 0.0
		_attack_already_hit_by_id.clear()

func _is_multiplayer() -> bool:
	var session := get_tree().root.get_node_or_null("GameSession")
	return session != null and bool(session.call("is_multiplayer"))

func _process_revive(delta: float) -> void:
	if not _is_multiplayer():
		return
	var any_reviving := false
	for n in get_tree().get_nodes_in_group(&"Player"):
		if n == self:
			continue
		if not (n is Node2D):
			continue
		var other := n as Node2D
		if other.has_method("is_downed") and bool(other.call("is_downed")):
			continue

		if other.global_position.distance_to(global_position) <= revive_distance_px:
			any_reviving = true
			break

	if any_reviving:
		_revive_progress_s += delta
	else:
		_revive_progress_s = 0.0

	_update_revive_ui(any_reviving)

	if _revive_progress_s >= maxf(revive_duration_s, 0.0):
		var revived_hp := int(round(float(max_hp) * clampf(revive_hp_fraction, 0.0, 1.0)))
		revive_at(global_position, revived_hp)

func is_downed() -> bool:
	return _is_downed

func _ensure_player_tag() -> void:
	if not _is_multiplayer():
		return
	if get_node_or_null(^"PlayerTag") != null:
		return

	var label := Label.new()
	label.name = "PlayerTag"
	label.text = player_label
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(-12, -42)
	label.size = Vector2(24, 16)
	label.add_theme_font_size_override("font_size", 12)
	add_child(label)

func _ensure_screen_notifier() -> void:
	if _screen_notifier != null:
		return
	var n := get_node_or_null(^"ScreenNotifier")
	if n is VisibleOnScreenNotifier2D:
		_screen_notifier = n
	else:
		_screen_notifier = VisibleOnScreenNotifier2D.new()
		_screen_notifier.name = "ScreenNotifier"
		# Small rect around the player so it counts as "on screen" while visible.
		_screen_notifier.rect = Rect2(-8, -8, 16, 16)
		add_child(_screen_notifier)

	if not _screen_notifier.screen_exited.is_connected(_on_screen_exited):
		_screen_notifier.screen_exited.connect(_on_screen_exited)

func _on_screen_exited() -> void:
	# If the player leaves the camera view, they are considered dead/downed.
	if _is_downed:
		return
	
	# Grace period after revival to allow camera to reposition.
	if _revive_grace_frames > 0:
		return

	if _is_multiplayer():
		var cam := get_viewport().get_camera_2d()
		if cam != null:
			# Move the downed body to the middle of the screen.
			global_position = cam.get_screen_center_position()

	_die()

func _ensure_revive_bar() -> void:
	if _revive_bar != null:
		return
	if not _is_multiplayer():
		return

	var bar := ProgressBar.new()
	bar.name = "ReviveBar"
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = maxf(revive_duration_s, 0.001)
	bar.value = 0.0
	bar.position = Vector2(-24, -26)
	bar.size = Vector2(48, 8)
	bar.visible = false
	# Keep it readable without custom theme resources.
	bar.modulate = Color(0.9, 0.95, 1.0, 1.0)
	add_child(bar)
	_revive_bar = bar

func _update_revive_ui(is_reviving: bool) -> void:
	if _revive_bar == null:
		return
	_revive_bar.max_value = maxf(revive_duration_s, 0.001)
	_revive_bar.value = clampf(_revive_progress_s, 0.0, _revive_bar.max_value)
	_set_revive_ui_visible(true)
	# Only show fill while actively reviving; otherwise show empty bar faintly.
	_revive_bar.modulate.a = 1.0 if is_reviving else 0.4

func _set_revive_ui_visible(enabled: bool) -> void:
	if _revive_bar != null:
		_revive_bar.visible = enabled
