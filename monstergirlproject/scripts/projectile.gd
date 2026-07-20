extends Area2D

## One bullet. Spawned by whoever is shooting; despawns on hit, wall, or range.
##
## The same scene serves player and enemy fire — only the collision layers
## differ, which is what stops enemies shooting each other.

const BASE_RADIUS := 3.0  # The radius the art is authored at, for scaling.

var direction := Vector2.RIGHT
var speed := 380.0
var damage := 1
var knockback := 90.0
var max_range := 420.0
var color := Color.WHITE
var radius := BASE_RADIUS

var _travelled := 0.0


## Call this immediately after instantiate(), before adding to the tree.
func configure(weapon: Weapon, dir: Vector2, hostile: bool) -> void:
	direction = dir.normalized()
	speed = weapon.projectile_speed
	damage = weapon.damage
	knockback = weapon.knockback
	max_range = weapon.projectile_range
	color = weapon.projectile_color
	radius = weapon.projectile_radius
	rotation = direction.angle()

	if hostile:
		collision_layer = 64      # enemy_bullet
		collision_mask = 16 | 4   # player_hurtbox | wall
	else:
		collision_layer = 32      # player_bullet
		collision_mask = 2 | 4    # enemy_hurtbox | wall


func _ready() -> void:
	$Art.color = color
	# Scaling the whole node scales the collision shape with the art, which
	# saves giving every bullet its own unique shape resource.
	scale = Vector2.ONE * (radius / BASE_RADIUS)


func _physics_process(delta: float) -> void:
	var step := speed * delta
	position += direction * step
	_travelled += step
	if _travelled >= max_range:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	# Hurtboxes are children; the thing that owns the health is the parent.
	var target := area.get_parent()
	if target.has_method("take_hit"):
		target.take_hit(damage, global_position)
	elif target.has_method("take_damage"):
		target.take_damage(damage, global_position)
	queue_free()


func _on_body_entered(_body: Node2D) -> void:
	queue_free()  # Hit a wall.
