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
  `%APPDATA%/Godot/app_userdata/Broken Blade/save.json` only if a test wrote one: it is
  Storm's playtest save, so back it up before any test that would overwrite it).
- `press/` (press and portfolio images) and `tools/make_press_images.py` /
  `make_portfolio_images.py` come from other chats working on the same repo: commit them
  along with everything else.

## Tools
- `tools/build_rooms.py`: every room layout and door link; regenerates `LINKS`, `MAP` and
  `LAYOUTS` in `scripts/rooms.gd`. Checks two-way links and keeps enemies away from doors.
  `EXTRA` places each region's second creature ("Y": toad, frost hound, cinder husk,
  conductor, hollow archer) and flier ("V": frost bat, carrion crow) on the nearest open
  floor to the spot given; room.gd picks which by region.
  `SHRINES` puts a rest shrine by the door into every boss; `AFTER_SHRINES` an "S" in each
  boss room, a shrine that kindles (and becomes the wake point) the moment the boss falls.
- Floors: each region's tileset plus a second one per region (`art/world/<name>_tileset.png`,
  room.gd `FLOOR_SHEETS`, rooms.gd `FLOORS`), made with PixelLab's sidescroller tileset tool
  (32px, 4x4 corner layout as STONE_TILES; download the metadata's spritesheet_url) and
  toned toward the region's colours.
- `tools/check_reach.py`: reachability check (jump, double jump, wall climb, shockline,
  slide limits) for the fire and lightning regions' gates and secrets.
- `tools/make_sfx.py`: synthesizes every sound effect into `audio/sfx/`.
- `tools/capture.tscn` (+ `capture.gd`): portfolio screenshots. Runs the game windowed with an
  invulnerable stand-in Storm through chosen rooms and boss fights (muted), saving bursts of
  frames to `press/raw/` (git-ignored); it puts the save back as it found it. Storm asked for
  this for the portfolio, so running it is fine. `tools/make_portfolio_shots.py` then turns
  the picked frames into captioned 1920x1080 images in `press/portfolio/screenshots/`.
- PixelLab (MCP) for art: about 320 generations left this cycle (resets 2026-10-29).
  Bases for animating Storm are in `art/concepts/bases/` and are fetched from the raw
  GitHub URL, so push a base before animating from it.

## State
- Playable: Foothills (forest; the Guardian Centipede twice), Frozen village (the Frost
  Colossus twice), the Crossroads, the Fire slopes (their own art and weather, ash bats, the
  Ashen Drake twice: grounded in the Forge, flying in the Drake's roost), and the Lightning
  peaks (their own art and weather, spark wisps, the Stormcaller twice: bound in the Spire,
  freed in the eyrie) up to the High pass, and the castle above it (the Hollow King, then
  the ending).
- Systems: saving (autosaves at shrines, pickups, bosses, new rooms), title screen with
  intro, pause menu (volume, fullscreen), colour-coded map, flasks, sound effects, hit
  effects, Silksong-style rings with region skins.
- Debug keys (editor build): 1-4 abilities, 5 beat the current boss (the Hollow King takes
  it twice, once per phase), 6-9, -, =, [, ], \ and ' warps (Village square, Frost arena,
  Frost throne, Crossroads, Forge, Drake's roost, Spire, eyrie, castle gate, throne
  approach), 0 reveal the map.

## Open items
- Storm switches sword hands when he turns (all art is right-facing and mirrored). Making
  him stay right-handed needs left-facing versions of every animation (~80 generations);
  offered, not yet decided.
- The fire region has no music of its own yet (it plays `exploration`).
- Frost Colossus reworked after feedback (fight 1 too easy, fight 2's chest out of reach);
  Storm likes fight 2 now.
- The lightning boss is the Stormcaller (Storm chose it over a Thunderbird, too like the
  drake): the king's court sorcerer, taken by the evil. Needs a playtest.
- The mountain was rebuilt to 45 rooms (3+ new per region) with each face switching back so
  the fire and lightning roads meet at the Crossroads (bottom) and the High pass (top). The
  Crossroads area (Storm's pick): the Refuge below (survivors' camp under the crossroads,
  talking NPCs in `Rooms.NPCS`, "N" in layouts) and the Last Stand above (the summit
  battlefield, hollow knights). Shops are a possible next step (needs a currency).
- Props are drawn flat, straight-on (Storm disliked three-quarter views); keep new ones so.
- The burned houses were removed from the fire rooms (Storm didn't like them, flat or not);
  the fire village has no scenery props for now.
- The drake is cut from one drawing (`art/bosses/drake_full.png`, and `drake_bare_full.png`
  with its folded wings painted out) into parts on the same 256x144 canvas; recut from them
  if a part needs changing. Its spread wing is `drake_wing.png`.
- The castle has no music of its own (it plays `exploration`), and only the throne for
  props. The castle opens with the double jump and shockline; it doesn't check the two
  second fights were won.
- The Dark Storm side boss (a dark copy of Storm) goes on a hidden path between the two
  crossroads (off the lift shaft); its reward isn't decided yet.
- `scripts/boss.gd` (Gate Warden / Frost Warden) is no longer used by any room;
  `tools/playtest.*` uses old room names.
