extends CharacterBody2D

## One enemy script covers both archetypes. Leave `weapon` empty and it charges
## you; assign one and it shoots. Set these per-instance in the Inspector.

# ── TUNING ────────────────────────────────────────────────────────────────
const MAX_HEALTH := 3
const CONTACT_DAMAGE := 1

const KNOCKBACK_SPEED := 280.0
const KNOCKBACK_FRICTION := 900.0
const STUN_TIME := 0.25          # Can't act while recovering from a hit.

const SEPARATION := 26.0         # How hard enemies push apart from each other.
const TELEGRAPH_TIME := 0.35     # Warning flash before firing.
# ──────────────────────────────────────────────────────────────────────────

@export var speed := 55.0
@export var weapon: Weapon
## Shooters hold position at range instead of closing to contact.
@export var preferred_range := 150.0
@export var range_tolerance := 40.0

@onready var body_art: Polygon2D = $Body
@onready var damage_area: Area2D = $DamageArea

var health := MAX_HEALTH
var knockback := Vector2.ZERO
var stunned := false
var can_shoot := true
var player: Node2D


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	if weapon:
		body_art.color = Color(0.85, 0.45, 0.25)  # Shooters read differently.


func _physics_process(delta: float) -> void:
	knockback = knockback.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * delta)

	if knockback.length() > 5.0:
		velocity = knockback
	elif stunned or player == null:
		velocity = Vector2.ZERO
	else:
		velocity = _desired_velocity() + _separation_push()
		if weapon and can_shoot:
			_shoot_at_player()

	move_and_slide()
	_apply_contact_damage()


func _desired_velocity() -> Vector2:
	var to_player := player.global_position - global_position
	var distance := to_player.length()

	if weapon == null:
		return to_player.normalized() * speed  # Chargers just close in.

	# Shooters try to hold a band around preferred_range: back off if too
	# close, advance if too far, strafe when comfortable.
	if distance < preferred_range - range_tolerance:
		return -to_player.normalized() * speed
	if distance > preferred_range + range_tolerance:
		return to_player.normalized() * speed
	return to_player.normalized().orthogonal() * speed * 0.5


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


func _shoot_at_player() -> void:
	can_shoot = false

	# Telegraph: flash before firing so the shot is reactable, not a gotcha.
	var tell := create_tween()
	tell.tween_property(body_art, "modulate", Color(2.2, 1.6, 1.6), TELEGRAPH_TIME * 0.6)
	tell.tween_property(body_art, "modulate", Color.WHITE, TELEGRAPH_TIME * 0.4)

	await get_tree().create_timer(TELEGRAPH_TIME).timeout
	if not is_instance_valid(self) or player == null or stunned:
		can_shoot = true
		return

	var dir := global_position.direction_to(player.global_position)
	Game.fire_weapon(weapon, global_position + dir * 12.0, dir, true)

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
	tween.tween_property(body_art, "modulate", Color(4, 4, 4), 0.04)
	tween.tween_property(body_art, "modulate", Color.WHITE, 0.12)


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
