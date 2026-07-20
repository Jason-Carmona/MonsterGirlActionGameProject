# video-game

A twin-stick roguelike in Godot 4.7. Pablo owns design; Claude owns code; audio
is handled by collaborators outside this repo.

## The pitch

Enter the Gungeon: roguelike runs, procedurally arranged rooms, guns found
mid-run. Mouse aim, 360°.

Target: a complete experience of 1–2 hours, combat-forward.

## History worth knowing

This started as a melee ALTTP/Hades-style game. **It pivoted to ranged** because
melee weapon variety is expensive — each new melee weapon needs its own
animation, hitbox, and retuning against every enemy, where a new gun is just
numbers. That pivot is what made "find a new weapon every room" affordable, so
the ranged decision and the Gungeon loot model are linked. Don't unpick one
without reconsidering the other.

The melee code (a rotating `HitboxPivot` carrying a swept sword hitbox) has been
removed. If it's ever wanted back, the approach was: one `Area2D` parented to a
pivot node, rotated to `facing.angle()`, tweened through an arc.

## Design decisions already made

- **Roguelike runs, not an authored world.** Randomised loot only pays off if
  you replay.
- **The dodge is load-bearing.** It's the defining mechanic in this genre.
  Invulnerable for its whole duration.
- **Enemy bullets are the challenge, not your gun.** Your weapon is the fun;
  difficulty comes from reading and dodging patterns. Content work is bullet
  patterns, not weapon count.
- **Enemy bullets are slow and large; player bullets are fast and small.** Fast
  tiny enemy bullets are unfair — they can't be reacted to. See the radius and
  speed gap between `enemy_pistol.tres` and `pistol.tres`.
- **Enemy shots telegraph.** A flash precedes every enemy shot so it's
  reactable rather than a gotcha.

## Conventions

- **Tuning constants go at the top of each script under a `TUNING` banner.**
  Game feel is Pablo's domain; values must be findable without reading logic.
  Never bury a magic number in a function body.
- **Weapons are data, not code.** A new gun is a `.tres` in `resources/`, never
  a new script. Players and enemies use the same `Weapon` resource and the same
  `Game.fire_weapon()` call.
- **Damage is duck-typed.** Bullets call `take_hit(damage, from_position)` or
  `take_damage(amount, from_position)` on whatever they overlap. Anything
  implementing those becomes damageable for free. No class hierarchy for this.
- **Hitboxes are `Area2D`; bodies are `CharacterBody2D`.** A hurtbox is a child
  `Area2D` so the thing that gets hit is separate from the thing that collides.
- Toggle `monitoring` and `disabled` with `set_deferred` — physics state can't
  change mid-step.
- One `enemy.gd` covers both archetypes: no `weapon` means it charges, a
  `weapon` means it holds range and shoots. Configure per-instance in the
  Inspector, don't fork the script.

## Collision layers

| Bit | Value | Name | Used by |
| --- | --- | --- | --- |
| 1 | 1 | player | Player body |
| 2 | 2 | enemy_hurtbox | What player bullets look for |
| 3 | 4 | wall | Static geometry; stops all bullets |
| 4 | 8 | enemy_body | Enemy physics |
| 5 | 16 | player_hurtbox | What enemy bullets look for |
| 6 | 32 | player_bullet | |
| 7 | 64 | enemy_bullet | |

## Layout

```
project.godot         Settings, input map, `Game` autoload
resources/*.tres      Weapon definitions — add new guns here, no code
scenes/world.tscn     Main scene — arena, player, enemies, HUD
scenes/player.tscn
scenes/enemy.tscn     Charger by default; assign a weapon for a shooter
scenes/projectile.tscn
scripts/game.gd       Autoload. hitstop(), fire_weapon().
scripts/weapon.gd     Weapon resource definition
scripts/player.gd     Movement, aim, shooting, dodge, damage
scripts/enemy.gd      Chase / hold-range AI, telegraphed shooting
scripts/projectile.gd
scripts/hud.gd
```

## Roadmap

1. ~~Combat feel: knockback, hitstop, i-frames, dodge~~ — done, confirmed running
2. ~~Weapons as data; ranged pivot~~ — done, untested
3. Weapon pickups — walk over a dropped gun to swap
4. Room clearing: doors lock until enemies are dead, then a reward spawns
5. Room generation and run structure
6. Real art to replace the `Polygon2D` placeholders

## Working notes

- Claude cannot run Godot in this environment. Pablo runs it and reports back.
  Never claim a change is verified.
- Editing `project.godot` externally while the editor is open requires a
  project reload before autoloads and input actions register.
