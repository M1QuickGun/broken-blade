# Handoff: where Broken Blade stands

Notes for picking the project up in a new chat. The design itself is in `DESIGN.md`; the
controls are in `README.md`.

## Working with Storm (the developer)
- He playtests; don't run the game to play it yourself. "start it up" means launch the game
  for him:
  `"/c/Users/miche/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --path .`
  (in the background).
- Commit and push after every chunk of work (`main`, GitHub `M1QuickGun/broken-blade`).
- Checks that are fine to run: `--headless --path . --import`, then
  `--headless --path . --quit-after 3` (compile check), and throwaway headless scenes that
  build rooms or run boss fights with a stand-in player (delete them afterwards, and delete
  `%APPDATA%/Godot/app_userdata/Broken Blade/save.json` if a test wrote one).
- `press/` (press and portfolio images) and `tools/make_press_images.py` /
  `make_portfolio_images.py` come from other chats working on the same repo: commit them
  along with everything else.

## Tools
- `tools/build_rooms.py`: every room layout and door link; regenerates `LINKS`, `MAP` and
  `LAYOUTS` in `scripts/rooms.gd`. Checks two-way links and keeps enemies away from doors.
- `tools/check_reach.py`: reachability check (jump, double jump, wall climb, shockline,
  slide limits) for the fire and lightning regions' gates and secrets.
- `tools/make_sfx.py`: synthesizes every sound effect into `audio/sfx/`.
- PixelLab (MCP) for art: about 1,140 generations left this cycle (resets 2026-10-29).
  Bases for animating Storm are in `art/concepts/bases/` and are fetched from the raw
  GitHub URL, so push a base before animating from it.

## State
- Playable: Foothills (forest; the Guardian Centipede twice), Frozen village (the Frost
  Colossus twice), the Crossroads, the Fire slopes (their own art and weather, ash bats, the
  Ashen Drake twice: grounded in the Forge, flying in the Drake's roost), and the laid-out Lightning peaks (rooms, rest points, secrets, tutorials and
  climbs; their piece waits on a plinth) up to the High pass.
- Systems: saving (autosaves at shrines, pickups, bosses, new rooms), title screen with
  intro, pause menu (volume, fullscreen), colour-coded map, flasks, sound effects, hit
  effects, Silksong-style rings with region skins.
- Debug keys (editor build): 1-4 abilities, 5 beat the current boss, 6-9, - and = warps
  (Village square, Frost arena, Frost throne, Crossroads, Forge, Drake's roost), 0 reveal the map.

## Open items
- Storm switches sword hands when he turns (all art is right-facing and mirrored). Making
  him stay right-handed needs left-facing versions of every animation (~80 generations);
  offered, not yet decided.
- The fire region has no music of its own yet (it plays `exploration`).
- Frost Colossus feedback (not acted on yet): fight 1 is too easy; fight 2's chest is out of
  reach without the double jump. Ideas were offered (topple it by sliding under its charge,
  kneel lower when stunned, a harder second half for fight 1).
- Lightning peaks need their art (backdrop, tileset, weather, enemy: the Spark wisp) and both
  fights (the bound thing / Thunderbird).
- The drake is cut from one drawing (`art/bosses/drake_full.png`, and `drake_bare_full.png`
  with its folded wings painted out) into parts on the same 256x144 canvas; recut from them
  if a part needs changing. Its spread wing is `drake_wing.png`.
- The castle gate above the High pass, and the castle.
- `scripts/boss.gd` (Gate Warden / Frost Warden) is no longer used by any room;
  `tools/playtest.*` uses old room names.
