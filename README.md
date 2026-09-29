# Broken Blade

A dark fantasy metroidvania made with Godot 4. See [DESIGN.md](DESIGN.md) for the story and plans.

## Running it
1. Open Godot 4.7 (`Godot_v4.7.1-stable_win64.exe`).
2. In the Project Manager, choose **Import**, select this folder's `project.godot`, and open it.
3. Press **F5** to play.

## Controls
| Action | Keyboard | Controller |
|---|---|---|
| Move | A / D or ← / → | Left stick / D-pad |
| Look up / down (aim slashes) | W / S or ↑ / ↓ | Left stick / D-pad |
| Jump (hold for higher) | Space, Z or K | A |
| Attack | J or X | X |
| Debug: add a blade piece | F1 | — |

Hold up while attacking to slash upward. Hold down while in the air to slash downward, and
land a down-slash on an enemy or spikes to bounce off them (pogo).

## Project layout
- `scripts/game.gd`: global state (blade pieces, max health) and input bindings.
- `scripts/main.gd`: player, camera, HUD, and room transitions.
- `scripts/player.gd`: Storm's movement, combat and damage.
- `scripts/rooms.gd`: room layouts as text maps, and which doors connect.
- `scripts/room.gd`: turns a text map into collision, spikes, doors and enemies.
- `scripts/crawler.gd`, `scripts/shard.gd`: first enemy and the test blade shard.
- `tools/playtest.tscn`: automated smoke test that plays a route and saves screenshots.
