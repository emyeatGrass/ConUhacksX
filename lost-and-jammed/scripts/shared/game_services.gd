extends Object

# Lightweight shared helpers to reduce duplicated lookup/utility code.
# Not an autoload: scripts can `preload()` and call these static funcs.


static func get_player(tree: SceneTree) -> Node2D:
	return tree.get_first_node_in_group(&"Player") as Node2D


static func get_audio_manager(tree: SceneTree) -> Node:
	var n := tree.get_first_node_in_group(&"AudioManager")
	if n != null:
		return n
	# Back-compat with older absolute-path lookups.
	return tree.root.get_node_or_null("World/AudioManager")


static func get_coin_pool(tree: SceneTree) -> Node:
	var n := tree.get_first_node_in_group(&"CoinPool")
	if n != null:
		return n
	# Back-compat with older absolute-path lookups.
	return tree.root.get_node_or_null("World/CoinPool")


static func get_hud(tree: SceneTree) -> Node:
	var n := tree.get_first_node_in_group(&"HUD")
	if n != null:
		return n
	# Back-compat with older absolute-path lookups.
	return tree.root.get_node_or_null("World/HUD")


static func compute_knockback_velocity(
	knock_dir: Vector2,
	current_velocity: Vector2,
	fallback_dir: Vector2,
	distance_px: float,
	duration_s: float,
	default_dir: Vector2 = Vector2.LEFT
) -> Vector2:
	var dir := knock_dir.normalized()
	if dir == Vector2.ZERO:
		dir = -current_velocity.normalized()
	if dir == Vector2.ZERO:
		dir = fallback_dir.normalized()
	if dir == Vector2.ZERO:
		dir = default_dir

	return dir * (distance_px / max(duration_s, 0.001))

