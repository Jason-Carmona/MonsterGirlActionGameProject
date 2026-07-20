extends Resource
class_name Weapon

## Data-only definition of a gun. Players and enemies both use these.
##
## To make a new weapon you do NOT need code: right-click in the FileSystem
## dock → New Resource → Weapon, fill in the fields, save it to resources/.

@export var display_name := "Pistol"

@export_group("Fire")
@export var damage := 1
@export var shots_per_second := 5.0
@export var auto_fire := true            ## Hold to shoot, vs. click per shot.

@export_group("Projectile")
@export var projectile_count := 1        ## Above 1 gives you a shotgun.
@export var spread_degrees := 3.0        ## Total cone width.
@export var projectile_speed := 380.0
@export var projectile_range := 420.0    ## Distance before it despawns.
@export var projectile_radius := 3.0
@export var projectile_color := Color(1.0, 0.9, 0.4)

@export_group("Feel")
@export var knockback := 90.0            ## Shove applied to whatever it hits.
@export var recoil := 70.0               ## Shove applied to the shooter.
@export var screen_shake := 0.18         ## 0–1. Usually reads stronger than recoil.


func cooldown() -> float:
	return 1.0 / maxf(shots_per_second, 0.01)
