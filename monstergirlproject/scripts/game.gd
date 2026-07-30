extends Node

## Autoloaded as `Game` — global helpers available from any script.
const PROJECTILE := preload("res://scenes/projectile.tscn")


## Freezes the whole game briefly. Called on every hit; it's the single biggest
## reason an impact reads as "solid" rather than "a number went down".
func hitstop(duration: float) -> void:
	if Engine.time_scale < 1.0:
		return  # Already frozen — don't stack and unfreeze early.
	Engine.time_scale = 0.0
	# The trailing `true` makes this timer ignore time_scale, otherwise it
	# would never tick while we're frozen.
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


## Kicks the camera. `amount` is 0–1; the camera squares it, so 0.2 is a nudge
## and 0.6 is a slam. Silently does nothing if the scene has no camera.
func shake(amount: float) -> void:
	if amount <= 0.0:
		return
	var camera := get_tree().get_first_node_in_group("camera")
	if camera:
		camera.add_trauma(amount)


## Spawns one weapon's worth of bullets. Players and enemies share this, so
## spread and pellet-fanning behave identically on both sides.
func fire_weapon(w: Weapon, from: Vector2, dir: Vector2, hostile: bool) -> void:
	if w == null:
		return

	var base_angle := dir.angle()
	var spread := deg_to_rad(w.spread_degrees)

	for i in w.projectile_count:
		var offset := 0.0
		if w.projectile_count > 1:
			# Fan pellets evenly across the cone, plus a little jitter so
			# repeated shots don't look identical.
			offset = spread * (float(i) / float(w.projectile_count - 1) - 0.5)
			offset += randf_range(-spread, spread) * 0.08
		else:
			offset = randf_range(-spread, spread) * 0.5

		var bullet := PROJECTILE.instantiate()
		bullet.configure(w, Vector2.from_angle(base_angle + offset), hostile)
		bullet.global_position = from
		get_tree().current_scene.add_child(bullet)
