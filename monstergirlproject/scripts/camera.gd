extends Camera2D

## Trauma-based screen shake. Callers add trauma; the camera decays it.
##
## Shake is squared before use, so small hits barely register and big ones
## slam. Linear shake reads as constant jitter, which is worse than none.

# ── TUNING ────────────────────────────────────────────────────────────────
const DECAY := 2.0            # Trauma lost per second. Higher = snappier.
const MAX_OFFSET := 10.0      # Pixels at full trauma.
const MAX_ROTATION := 0.05    # Radians at full trauma. Keep this subtle.
# ──────────────────────────────────────────────────────────────────────────

var trauma := 0.0


func add_trauma(amount: float) -> void:
	trauma = minf(trauma + amount, 1.0)


func _process(delta: float) -> void:
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
