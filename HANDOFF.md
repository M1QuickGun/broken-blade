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
- `press/` and `tools/make_press_images.py` / `make_portfolio_images.py` belong to other
  work; leave them alone.

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
  Colossus twice), the Crossroads, and the laid-out Fire slopes and Lightning peaks (rooms,
  rest points, secrets, tutorials and climbs; their pieces wait on pedestals) up to the High
  pass.
- Systems: saving (autosaves at shrines, pickups, bosses, new rooms), title screen with
  intro, pause menu (volume, fullscreen), colour-coded map, flasks, sound effects, hit
  effects, Silksong-style rings with region skins.
- Debug keys (editor build): 1-4 abilities, 5 beat the current boss, 6-9 warps (Village
  square, Frost arena, Frost throne, Crossroads), 0 reveal the map.

## Open items
- Storm switches sword hands when he turns (all art is right-facing and mirrored). Making
  him stay right-handed needs left-facing versions of every animation (~80 generations);
  offered, not yet decided.
- Fire and lightning regions need their art (backdrops, tilesets, weather, enemies) and
  four boss fights (Ashen Drake; the bound thing / Thunderbird).
- The castle gate above the High pass, and the castle.
- `scripts/boss.gd` (Gate Warden / Frost Warden) is no longer used by any room;
  `tools/playtest.*` uses old room names.
