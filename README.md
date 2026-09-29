# Broken Blade

A dark fantasy metroidvania made with Godot 4. See [DESIGN.md](DESIGN.md) for the story and plans.

## Running it
1. Open Godot 4.7 (`Godot_v4.7.1-stable_win64.exe`).
2. In the Project Manager, choose **Import**, select this folder's `project.godot`, and open it.
3. Press **F5** to play.

## Controls
| Action | Keyboard & mouse | Controller |
|---|---|---|
| Move | A / D or ← / → | Left stick / D-pad |
| Look up / down (aim slashes) | W / S or ↑ / ↓ | Left stick / D-pad |
| Jump (hold for higher) | Space, Z or K | A |
| Attack | Left click | X |
| Dash (ice piece) | Shift, L or C | RB |
| Shockline (lightning piece) | Right click | Y |
| Debug: unlock dash / shockline | F1 / F2 | — |

Hold up while attacking to slash upward. Hold down while in the air to slash downward, and
land a down-slash on an enemy or spikes to bounce off them (pogo).

**Dash:** a quick burst in the direction you're moving, once on the ground and once per jump.
**Shockline:** fires straight ahead like a harpoon and drags you to whatever it hits, or to
the end of the line if it hits nothing. Enemies get struck. On a grapple ring you hang for as
long as you hold right click: let go to drop, or jump to leap off. Jump mid-pull to cancel.

## Project layout
- `scripts/game.gd`: global state (blade pieces, max health) and input bindings.
- `scripts/main.gd`: player, camera, HUD, and room transitions.
- `scripts/player.gd`: Storm's movement, combat and damage.
- `scripts/rooms.gd`: room layouts as text maps, and which doors connect.
- `scripts/room.gd`: turns a text map into collision, spikes, doors and enemies.
- `scripts/crawler.gd`: the first enemy.
- `scripts/shard.gd`, `scripts/anchor.gd`: blade piece pickups and shockline grapple points.
- `tools/playtest.tscn`: automated smoke test that plays a route and saves screenshots.
