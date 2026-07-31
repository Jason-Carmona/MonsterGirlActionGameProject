extends Camera2D

## Follows the player, shakes on impact, and never shows past the level.
##
## On load the camera fits its scroll limits to the bounding box of the level's
## tilemap, so the view stops at the painted edges instead of drifting into
## empty space. A scene with no tilemap (the old world.tscn arena) keeps the
## previous fixed-center behaviour. Callers add screen-shake trauma via the
## "camera" group; the trauma decays here.

# ── TUNING ────────────────────────────────────────────────────────────────
const FOLLOW_SPEED := 8.0     # How tightly the camera tracks the player. Higher = snappier; 0 = locked 1:1.
const DECAY := 2.0            # Shake trauma lost per second. Higher = snappier.
const MAX_OFFSET := 10.0      # Shake pixels at full trauma.
const MAX_ROTATION := 0.05    # Shake radians at full trauma. Keep this subtle.
# ──────────────────────────────────────────────────────────────────────────

var trauma := 0.0
var _player: Node2D
var _follow := false


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	make_current()
	# Only take over movement when there's a level to bound the camera to;
	# otherwise leave the camera parked where the scene placed it.
	_follow = _fit_limits_to_level() and _player != null
	if _follow:
		global_position = _player.global_position
		position_smoothing_enabled = FOLLOW_SPEED > 0.0
		position_smoothing_speed = FOLLOW_SPEED
		reset_smoothing()


func add_trauma(amount: float) -> void:
	trauma = minf(trauma + amount, 1.0)


func _process(delta: float) -> void:
	if _follow and is_instance_valid(_player):
		global_position = _player.global_position

	# ── Trauma-based screen shake ──
	# Shake is squared before use, so small hits barely register and big ones
	# slam. It rides on `offset`/`rotation`, independent of the follow position.
	if trauma <= 0.0:
		if offset != Vector2.ZERO:
			offset = Vector2.ZERO
			rotation = 0.0
		return

	trauma = maxf(trauma - DECAY * delta, 0.0)
	var amount := trauma * trauma
	offset = Vector2(
		randf_range(-1.0, 1.0) * MAX_OFFSET * amount,
		randf_range(-1.0, 1.0) * MAX_OFFSET * amount,
	)
	rotation = randf_range(-1.0, 1.0) * MAX_ROTATION * amount


## Fit scroll limits to the bounding box of every TileMapLayer in the scene, in
## world pixels. Returns true if at least one non-empty tilemap was found.
func _fit_limits_to_level() -> bool:
	var bounds := Rect2()
	var found := false
	for node in get_tree().current_scene.find_children("*", "TileMapLayer", true, false):
		var layer := node as TileMapLayer
		if layer == null or layer.tile_set == null:
			continue
		var used: Rect2i = layer.get_used_rect()
		if used.size == Vector2i.ZERO:
			continue
		var ts: Vector2i = layer.tile_set.tile_size
		var top_left := layer.to_global(Vector2(used.position * ts))
		var bottom_right := layer.to_global(Vector2((used.position + used.size) * ts))
		var layer_rect := Rect2(top_left, bottom_right - top_left)
		bounds = layer_rect if not found else bounds.merge(layer_rect)
		found = true

	if not found:
		return false

	limit_left = int(bounds.position.x)
	limit_top = int(bounds.position.y)
	limit_right = int(bounds.end.x)
	limit_bottom = int(bounds.end.y)
	return true
