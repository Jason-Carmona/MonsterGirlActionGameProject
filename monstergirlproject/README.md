# video-game — twin-stick roguelike

Enter the Gungeon-style combat prototype in Godot 4. Move with the keyboard,
aim with the mouse, dodge through bullets. All art is placeholder polygons, no
image files needed.

## Running it

1. Open Godot, click **Import**, and select this folder's `project.godot`.
2. Press **F5** (or the play button, top right).

## Controls

| Action | Keys |
| --- | --- |
| Move | WASD or arrow keys |
| Aim | Mouse |
| Shoot | Left click (or Space) |
| Dodge (invulnerable) | Shift or K |

## What's in here

```
project.godot          Settings, input map, `Game` autoload
resources/*.tres       Weapon definitions
scenes/world.tscn      Main scene: arena, player, enemies, HUD
scenes/player.tscn
scenes/enemy.tscn      Charger by default; give it a weapon to make a shooter
scenes/projectile.tscn
scripts/game.gd        hitstop() and fire_weapon(), globally available
scripts/weapon.gd      The Weapon resource definition
scripts/player.gd      Movement, aim, shooting, dodge, damage
scripts/enemy.gd       AI, telegraphed shooting, knockback
scripts/projectile.gd
scripts/hud.gd
```

## Making a new gun (no code)

Right-click in the FileSystem dock → **New Resource** → search `Weapon` → save
it into `resources/`. Fill in the fields in the Inspector, then drag it onto a
Player or Enemy node's **Weapon** slot.

`projectile_count` above 1 gives you a shotgun. `spread_degrees` is the total
cone width. `auto_fire` off means one shot per click.

## How the pieces fit

**One weapon system for everyone.** Players and enemies both hold a `Weapon`
resource and both call `Game.fire_weapon()`. Only the collision layers differ,
which is what stops enemies shooting each other.

**Aim is decoupled from movement.** `AimPivot` rotates toward the cursor while
the body moves independently. That separation is what lets you strafe, and
strafing is most of what makes bullet dodging interesting.

**Damage is duck-typed.** A bullet calls `take_hit()` or `take_damage()` on
whatever it overlaps. Anything implementing those methods becomes damageable —
barrels, doors, bosses — with no changes to the bullet.

## Tuning

Every number that affects game feel sits at the top of `player.gd` and
`enemy.gd` under a `TUNING` banner, or in the `.tres` weapon files. Change one,
press F5, feel the difference.
