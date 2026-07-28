extends CharacterBody2D

## One enemy script covers both archetypes. Leave `weapon` empty and it charges
## you; assign one and it shoots. Set these per-instance in the Inspector.
##
## Enemies sleep until you're inside AGGRO_RANGE and in sight, then shout their
## neighbours awake, so a cluster fights as a group instead of trickling in one
## at a time. Give one a `patrol_path` and it walks that route while asleep
## instead of standing still. Shooters advance and plant to fire; chargers just
## come at you.

# ── TUNING ────────────────────────────────────────────────────────────────
const MAX_HEALTH := 3
const CONTACT_DAMAGE := 1

const KNOCKBACK_SPEED := 280.0
const KNOCKBACK_FRICTION := 900.0
const STUN_TIME := 0.25          # Can't act while recovering from a hit.

const SEPARATION := 26.0         # How hard enemies push apart from each other.
const TELEGRAPH_TIME := 0.35     # Warning flash before firing.
const SHOOTER_ADVANCE := 0.6     # Fraction of `speed` while closing on you.

const AGGRO_RANGE := 230.0       # How close you get before a sleeper notices.
const ALERT_RADIUS := 120.0      # How far a waking enemy's shout carries.
const PATROL_SPEED := 0.5        # Fraction of `speed` while walking a patrol.
const PATROL_ARRIVE := 4.0       # How close counts as reaching a patrol point.

const WHISKER_LENGTH := 24.0     # How far ahead an enemy feels for geometry.
const WHISKER_ANGLE := 0.6       # Radians each side whisker sits off centre.
# ──────────────────────────────────────────────────────────────────────────

# Collision bits, per the table in CLAUDE.md. Sight is `wall` alone — eyes and
# bullets both cross waist-high cover, only bodies are stopped by it.
const SIGHT_MASK := 4            # wall
const AVOID_MASK := 4 | 128      # wall | cover

@export var speed := 55.0
@export var weapon: Weapon
## Path2D to walk while asleep. Leave it empty and this one stands guard.
@export var patrol_path: Path2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var damage_area: Area2D = $DamageArea

var health := MAX_HEALTH
var knockback := Vector2.ZERO
var stunned := false
var can_shoot := true
var planting := false            # Committed to a shot; holds still until it lands.
var player: Node2D
var awake := false
var _turn_sign := 1.0            # Which way this one prefers to round a corner.
var _patrol_index := 0
var _patrol_step := 1            # Flips at each end of the path.


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	# Picked once per enemy so a pack rounding the same wall splits around it
	# instead of every one of them choosing the same side.
	_turn_sign = 1.0 if randf() < 0.5 else -1.0
	if weapon:
		sprite.self_modulate = Color(1.5, 1.1, 0.8)  # Shooters read hotter.


func _physics_process(delta: float) -> void:
	knockback = knockback.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * delta)

	if knockback.length() > 5.0:
		velocity = knockback
	elif stunned or player == null:
		velocity = Vector2.ZERO
	elif not awake:
		velocity = _avoid_walls(_patrol_velocity())
		_watch_for_player()
	elif planting:
		# Planted for the telegraph and the shot itself, then free again for
		# the cooldown. That walk-stop-fire-walk beat is the whole rhythm of
		# the archetype; letting them drift while firing flattens it.
		velocity = Vector2.ZERO
	else:
		velocity = _avoid_walls(_desired_velocity()) + _separation_push()
		# Only start a shot we could actually land. Once the telegraph begins
		# it commits, so diving behind a wall during the tell is a real dodge
		# and the bullet dies on the geometry.
		if weapon and can_shoot and _can_see_player():
			_shoot_at_player()

	_update_animation()
	move_and_slide()
	_apply_contact_damage()


func _desired_velocity() -> Vector2:
	var to_player := player.global_position - global_position
	if weapon == null:
		return to_player.normalized() * speed  # Chargers just close in.

	# Shooters close too, only slower. They don't hold a line any more — the
	# spacing comes from the ground they give up while planted and firing.
	return to_player.normalized() * speed * SHOOTER_ADVANCE


## Steer a desired direction around geometry. Three short whiskers: if the one
## straight ahead is blocked, swing toward whichever side is clear. Enough to
## round a corner or slip past a table, and cheap enough to run per frame.
##
## This is steering, not pathfinding — it won't solve a maze or back out of a
## dead end. If rooms ever get that intricate, replace it with a
## NavigationAgent2D rather than stacking more whiskers on.
func _avoid_walls(desired: Vector2) -> Vector2:
	var dir := desired.normalized()
	if dir == Vector2.ZERO or not _blocked(dir):
		return desired

	var left := dir.rotated(-WHISKER_ANGLE)
	var right := dir.rotated(WHISKER_ANGLE)
	var left_open := not _blocked(left)
	var right_open := not _blocked(right)

	if left_open and right_open:
		return (left if _turn_sign < 0.0 else right) * desired.length()
	if left_open:
		return left * desired.length()
	if right_open:
		return right * desired.length()
	# Boxed in on all three. Slide along the wall instead of pressing into it.
	return dir.rotated(_turn_sign * PI * 0.5) * desired.length()


func _blocked(dir: Vector2) -> bool:
	return _ray_hits(global_position + dir * WHISKER_LENGTH, AVOID_MASK)


func _can_see_player() -> bool:
	return not _ray_hits(player.global_position, SIGHT_MASK)


## Excludes our own body, or every ray would hit us at zero distance.
func _ray_hits(to: Vector2, mask: int) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, to, mask, [get_rid()])
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Walk the points of a Path2D you drew in the level. Bounces at the ends
## rather than looping, so a two-point path becomes a back-and-forth and an
## open route retraces itself instead of cutting across to the start — draw a
## closed circuit if you'd rather it go round. Aggro abandons the path for
## good; a woken enemy never returns to its post.
func _patrol_velocity() -> Vector2:
	if patrol_path == null or patrol_path.curve == null or patrol_path.curve.point_count < 2:
		return Vector2.ZERO

	var curve := patrol_path.curve
	var target := patrol_path.to_global(curve.get_point_position(_patrol_index))
	if global_position.distance_to(target) <= PATROL_ARRIVE:
		var next := _patrol_index + _patrol_step
		if next < 0 or next >= curve.point_count:
			_patrol_step = -_patrol_step
			next = _patrol_index + _patrol_step
		_patrol_index = next
		target = patrol_path.to_global(curve.get_point_position(_patrol_index))

	return global_position.direction_to(target) * speed * PATROL_SPEED


## Two gates: close enough, and a clear look. Range keeps a long corridor from
## waking everything on it at once; sight means you can slip past along a wall
## and stops anything triggering through solid rock.
func _watch_for_player() -> void:
	if global_position.distance_to(player.global_position) > AGGRO_RANGE:
		return
	if _can_see_player():
		_wake()


## Waking shouts to nearby sleepers so a cluster activates together. The shout
## carries one hop only: letting the woken shout in turn would ripple across
## the whole level and put every enemy on you at once.
func _wake() -> void:
	if awake:
		return
	awake = true
	for other in get_tree().get_nodes_in_group("enemy"):
		if other != self and global_position.distance_to(other.global_position) <= ALERT_RADIUS:
			other.awake = true


## Without this, every enemy converges on the same point and stacks into one
## square. Pushing apart keeps a group readable as individual threats.
func _separation_push() -> Vector2:
	var push := Vector2.ZERO
	for other in get_tree().get_nodes_in_group("enemy"):
		if other == self:
			continue
		var offset: Vector2 = global_position - other.global_position
		var distance := offset.length()
		if distance < SEPARATION and distance > 0.01:
			push += offset.normalized() * (SEPARATION - distance) * 4.0
	return push


## Face the way we're moving. The dominant axis of velocity picks one of four
## walk animations; a near-still enemy idles. Same 4-direction scheme as the
## player, just driven by velocity instead of input.
func _update_animation() -> void:
	var anim := &"idle"
	if velocity.length() >= 5.0:
		if absf(velocity.x) > absf(velocity.y):
			anim = &"move_right" if velocity.x > 0.0 else &"move_left"
		else:
			anim = &"move_down" if velocity.y > 0.0 else &"move_up"
	if sprite.animation != anim:
		sprite.play(anim)


func _shoot_at_player() -> void:
	can_shoot = false
	planting = true

	# Telegraph: flash before firing so the shot is reactable, not a gotcha.
	var tell := create_tween()
	tell.tween_property(sprite, "modulate", Color(2.2, 1.6, 1.6), TELEGRAPH_TIME * 0.6)
	tell.tween_property(sprite, "modulate", Color.WHITE, TELEGRAPH_TIME * 0.4)

	await get_tree().create_timer(TELEGRAPH_TIME).timeout
	if not is_instance_valid(self) or player == null or stunned:
		planting = false
		can_shoot = true
		return

	var dir := global_position.direction_to(player.global_position)
	Game.fire_weapon(weapon, global_position + dir * 12.0, dir, true)
	planting = false  # Shot's away — start walking again while it cools down.

	await get_tree().create_timer(weapon.cooldown()).timeout
	can_shoot = true


## Enemies hurt on touch. The player's own invulnerability window stops this
## from draining health every frame, so we don't need a cooldown here.
func _apply_contact_damage() -> void:
	for area in damage_area.get_overlapping_areas():
		var target := area.get_parent()
		if target.has_method("take_damage"):
			target.take_damage(CONTACT_DAMAGE, global_position)


func take_hit(damage: int, from_position: Vector2) -> void:
	health -= damage
	knockback = from_position.direction_to(global_position) * KNOCKBACK_SPEED
	_wake()  # Getting shot from out of sight counts as noticing you.

	if health <= 0:
		# Hitstop only on kills. Firing it on every bullet meant an automatic
		# weapon froze the game more than half the time.
		Game.hitstop(0.07)
		_die()
		return

	_flash()
	stunned = true
	await get_tree().create_timer(STUN_TIME).timeout
	stunned = false


func _flash() -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(4, 4, 4), 0.04)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)


func _die() -> void:
	# Stop colliding immediately so the corpse can't still hurt anyone.
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)
	$Hurtbox/CollisionShape2D.set_deferred("disabled", true)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.4, 0.2), 0.18)
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.chain().tween_callback(queue_free)
