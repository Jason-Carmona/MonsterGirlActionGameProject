extends CharacterBody2D

## Twin-stick roguelike player: free movement, mouse aim, i-frame dodge.

# ── TUNING ────────────────────────────────────────────────────────────────
const SPEED := 135.0
const ACCELERATION := 1400.0    # Lower = floatier, higher = snappier.
const FRICTION := 1600.0

## Recoil and knockback live in a separate impulse vector that decays on its
## own schedule. Lower this and shoves last longer and travel further.
const IMPULSE_FRICTION := 750.0
const MAX_IMPULSE := 420.0      # Stops rapid fire from launching you.

const DODGE_SPEED := 340.0
const DODGE_DURATION := 0.20    # Invulnerable for this whole window.
const DODGE_COOLDOWN := 0.30

const MAX_HEALTH := 6
const INVULN_TIME := 0.9        # After taking a hit.
const HIT_KNOCKBACK := 150.0
# ──────────────────────────────────────────────────────────────────────────

signal health_changed(current: int, maximum: int)
signal weapon_changed(weapon: Weapon)
signal died

enum State { MOVE, DODGE }

@export var weapon: Weapon

@onready var aim_pivot: Node2D = $AimPivot
@onready var muzzle: Marker2D = $AimPivot/Muzzle
@onready var flash: Polygon2D = $AimPivot/Flash
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

## Movement and impulse are tracked separately, then summed into `velocity`
## each frame. Keeping them apart is what stops the movement code from
## instantly erasing recoil the frame after a shot.
var move_velocity := Vector2.ZERO
var impulse := Vector2.ZERO

var state := State.MOVE
var aim_direction := Vector2.DOWN
var health := MAX_HEALTH
var invulnerable := false
var dodge_ready := true
var can_shoot := true

var _hit_invuln_until := 0.0


func _ready() -> void:
	flash.visible = false
	health_changed.emit(health, MAX_HEALTH)
	weapon_changed.emit(weapon)


func _physics_process(delta: float) -> void:
	_update_aim()

	match state:
		State.MOVE:
			_process_move(delta)
		State.DODGE:
			# move_velocity was set when the dodge started; just coast.
			pass

	impulse = impulse.move_toward(Vector2.ZERO, IMPULSE_FRICTION * delta)
	velocity = move_velocity + impulse
	move_and_slide()


## Aim is independent of movement — that decoupling is what lets you strafe,
## and strafing is most of what makes bullet dodging interesting.
func _update_aim() -> void:
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length_squared() > 1.0:
		aim_direction = to_mouse.normalized()
	aim_pivot.rotation = aim_direction.angle()


func _process_move(delta: float) -> void:
	if Input.is_action_just_pressed("dodge") and dodge_ready:
		_start_dodge()
		return
	var was_moving := false
	var input_dir := Input.get_vector("walk_left", "walk_right", "walk_up", "walk_down")
	if input_dir != Vector2.ZERO:
		move_velocity = move_velocity.move_toward(input_dir * SPEED, ACCELERATION * delta)
		was_moving = true
	else:
		move_velocity = move_velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	
	_update_animation_4_direction(was_moving, input_dir)
	
	_try_shoot()

func _update_animation_4_direction(is_moving: bool, direction: Vector2)-> void:
	if state == State.DODGE:
		return
	
	var dir_string := _get_direction_string(direction)
	
	sprite.play(dir_string)
	
	_last_direction = dir_string
	
var _last_direction := "idle"
	
func _get_direction_string(direction: Vector2) -> String:
		if abs(direction.x) == abs(direction.y):
			return "idle"
		if abs(direction.x) > abs(direction.y):
			return "move_right" if direction.x > 0 else "move_left"
		else:
			return "move_down" if direction.y > 0 else "move_up"
	
	

# ── SHOOTING ──────────────────────────────────────────────────────────────

func _try_shoot() -> void:
	if weapon == null or not can_shoot:
		return
	var wants_to_fire := (
		Input.is_action_pressed("attack") if weapon.auto_fire
		else Input.is_action_just_pressed("attack")
	)
	if wants_to_fire:
		_fire()


func _fire() -> void:
	Game.fire_weapon(weapon, muzzle.global_position, aim_direction, false)

	# Kick backwards, capped so held automatic fire can't launch you.
	impulse = (impulse - aim_direction * weapon.recoil).limit_length(MAX_IMPULSE)
	Game.shake(weapon.screen_shake)
	_muzzle_flash()

	can_shoot = false
	await get_tree().create_timer(weapon.cooldown()).timeout
	can_shoot = true


func _muzzle_flash() -> void:
	flash.visible = true
	flash.scale = Vector2(randf_range(0.8, 1.3), randf_range(0.7, 1.2))
	await get_tree().create_timer(0.04).timeout
	flash.visible = false


func equip(new_weapon: Weapon) -> void:
	weapon = new_weapon
	can_shoot = true
	weapon_changed.emit(weapon)


# ── DODGE ─────────────────────────────────────────────────────────────────

func _start_dodge() -> void:
	# Dodge the way you're holding, or toward the cursor if standing still.
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dir := input_dir.normalized() if input_dir != Vector2.ZERO else aim_direction

	state = State.DODGE
	dodge_ready = false
	invulnerable = true
	move_velocity = dir * DODGE_SPEED
	impulse = Vector2.ZERO  # A dodge should always go where you aimed it.

	await get_tree().create_timer(DODGE_DURATION).timeout
	_end_dodge()


func _end_dodge() -> void:
	state = State.MOVE
	if not _is_hit_invulnerable():
		invulnerable = false

	await get_tree().create_timer(DODGE_COOLDOWN).timeout
	dodge_ready = true


func _is_hit_invulnerable() -> bool:
	return Time.get_ticks_msec() / 1000.0 < _hit_invuln_until


# ── DAMAGE ────────────────────────────────────────────────────────────────

func take_damage(amount: int, from_position: Vector2) -> void:
	if invulnerable:
		return

	health -= amount
	health_changed.emit(health, MAX_HEALTH)
	impulse = from_position.direction_to(global_position) * HIT_KNOCKBACK
	Game.hitstop(0.12)
	Game.shake(0.5)

	if health <= 0:
		_die()
		return

	invulnerable = true
	_hit_invuln_until = Time.get_ticks_msec() / 1000.0 + INVULN_TIME
	_flash(INVULN_TIME)
	await get_tree().create_timer(INVULN_TIME).timeout
	invulnerable = false


## Blinks the body so the invulnerability window is readable to the player.
func _flash(duration: float) -> void:
	var tween := create_tween()
	tween.set_loops(int(duration / 0.12))


func _die() -> void:
	died.emit()
	get_tree().reload_current_scene()
