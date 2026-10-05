# Broken Blade — Design Doc

## Pitch
A dark fantasy metroidvania in the spirit of Hollow Knight. The great sword that once
sealed an ancient evil has shattered, and a fragment of that evil clings to each piece.
Recover the pieces, defeat what's bound to them, and reforge the blade.

## Tone
Dark fantasy: a ruined kingdom, oppressive atmosphere, melancholy rather than heroic.

## Story
- **The shattering:** The sword that sealed the ancient evil breaks. The evil is released and
  kills the royal family.
- **The escape:** With his last power, the King throws his last surviving son, **Storm**, off
  the mountain with the **hilt** of the broken blade. The fall goes wrong: Storm wakes at the
  mountain's foot clutching only a jagged **shard** of the blade, its broken end wrapped in
  rags. The hilt is gone.
- **Twenty years later:** Storm returns to a broken kingdom, now split between the parts of the
  great evil. Each part is bound to one piece of the broken blade.

## Protagonist
**Storm**, the last surviving member of the royal family. He starts with only a rag-wrapped
shard of the blade, no hilt: something has clearly gone wrong. The hilt is the first piece
he recovers, pried from the Guardian Centipede, and with it its sword catcher (the wall jump).

## Blade pieces → abilities
Each piece of the blade grants a movement ability and has its own elemental theme. Each piece
is also held by one part of the evil, so each one is likely a boss or region.

| Piece | Ability | Theme |
|---|---|---|
| Shard | Starting weapon: a normal swing with a broken piece of blade, no hilt | — |
| Hilt (first piece) | Wall jump: Storm hooks the hilt's sword catcher into the stone to cling to walls and kick off them. Recovered from the Guardian Centipede in the tutorial | — |
| First piece | Dash | Ice |
| Second piece | Double jump | Fire |
| Final / top piece (the tip) | Shockline: fires a straight line to a grapple point or enemy and pulls you to it (like Silksong's clawline) | Lightning |

**Attack reach:** The hilt is just a normal swing. Every piece recovered makes the blade longer,
so Storm's attack reach grows with each one.

**Order:** The dash (ice) is always first. After that the player chooses: fire (double jump) or
lightning (shockline), in either order. Levels need to be designed so both routes work.

## Art direction (proposed)
- **Style:** pixel art at a 480×270 base resolution, scaled up to full HD.
- **Palette:** cold, desaturated blues and greys for the ruined kingdom, with each blade piece's
  element (ice blue, fire orange, lightning violet or yellow) as the only saturated color, so
  the pieces and their corrupted regions stand out.
- **Placeholder first:** the game uses simple shapes until the controls feel right. Real art
  comes after.

## World: the mountain
The kingdom is built on a great mountain: the castle at the summit, villages on the slopes
around it. The whole game is one climb from the bottom to the top.

**Intro (planned animation):** the kingdom on its mountain → the blade shatters and the evil
pours out → the King's last power throws Storm to the foot of the mountain → Storm, years later,
wakes at the bottom with the hilt on the ground beside him. The opening shot of the whole
mountain doubles as the player's mental map for the rest of the game.

### Map outline (bottom to top)
```
                          [ Throne (final boss) ]
                          [    Castle halls     ]
                          [    Castle gate  *   ]
                                  J+S
        [=================== High pass ===================]
          J                                             S
  [Forge boss]-[Shaft]        [ Hidden shrine ]        [Tower]-[Spire boss]
  [Burning homes *]               J / S                 [Bridges *]
  [ Ashen road ]-------------[ Crossroads * ]------------[ Cliff road ]
                                    |
                               [ Ice climb ]
                                    D
               [Frozen cellar] S [ Village square * ]-[Frost boss]
                                    |          [ Ice caverns ]
  [Landing *]-[Rockfall]-[Ring * / pit]-[Cliff *]-[Gate cavern]

  D dash · J double jump · S shockline = ability-locked door   * rest point
  Hidden shrine and Frozen cellar are optional secret rooms.
```

1. **Foothills (tutorial, forest, open sky).** Landing (Storm wakes with the shard, rest
   point) → Rockfall (run, jump, swing, pogo) → the Ring: a ring of standing stones with the
   hilt glinting in its middle. Stepping in breaks the ground and drops Storm into the pit
   below, where the Guardian Centipede lies pinned by the hilt (fight 1). Beaten, it goes limp;
   Storm pulls the hilt free (the wall jump) and it sinks into the earth, seemingly dead. The
   pit is then the wall-jump tutorial: climbing out (a side tunnel hides a mask shard) →
   the Cliff: a narrow chimney, then a single rock face open to the forest below, with a
   shrine at the top → the Gate cavern: the frozen gate to the village in sight across it,
   until the centipede bursts through the ceiling, risen, and its body coils into the
   arena's walls (fight 2). Its death throes shatter the gate.
2. **Frozen village, taken by the ice evil (dash).** Village square is the lower mountain's hub
   (rest point, maybe the first survivors). Drop through the Ice caverns up into the Frost boss
   arena for the first blade piece. The Ice climb up the mountain needs the dash. A shockline
   anchor visible from the square leads to the Frozen cellar: a promise to come back later.
3. **Crossroads (choose fire or lightning).** Rest point where the path splits west and east.
   The Hidden shrine above it opens with the double jump *or* the shockline, so either route
   unlocks it.
4. **Fire slopes (west face) and Lightning peaks (east face), mirror images.** Road in (dash
   only) → Burning homes / Bridges (rest point) → Forge boss / Spire boss (blade piece) →
   Shaft / Tower, whose only exit is the new ability (double jump up the Shaft, shockline up the
   Tower) onto the High pass. Finish one side, come out on the pass, drop back to the
   Crossroads, do the other.
5. **High pass and castle.** The High pass joins the tops of both faces into one loop. The Castle
   gate climb needs the double jump and the shockline together. Castle halls are the final
   gauntlet; the Throne holds the final boss.

### Built so far
The Foothills and the Frozen village are playable end to end (`tools/build_rooms.py`):
Landing (rest) → Rockfall → Ring (rest; the pit and the first centipede fight: the hilt)
→ Cliff (rest at the top) → Gate cavern (the risen centipede; the frozen gate) → Village
square (rest hub) → Ice caverns (the Frozen cellar hides off it, shockline only) → Frost
arena (Frost Warden, first fight: the ice shard) → Frozen depths (slide tutorial) → Frost
throne (the rematch: a mask shard) → Ice climb (crawlspace exit) → Frozen bridge (gaps
over frozen spikes, slides under fallen ice walls) → Crossroads (rest; a hidden ledge with a
mask shard reached by the double jump or the shockline).

**Fire slopes (west), with their own look and both drake fights:** Ashen road (slide
under a fallen beam) → Burning homes (rest; a secret ledge only the shockline reaches) → Forge
(the Ashen Drake's first fight: the fire piece) → Cinder steps (the
double jump tutorial: platforms five tiles apart over spikes, walls spiked so the wall jump
can't skip it) → Drake's roost (the rematch, open to the sky: a mask shard) → Fire shaft (climbed
with the double jump) → High pass.

**Lightning peaks (east), laid out, art and bosses still to come:** Cliff road (slide under a
rockfall) → Storm bridges (rest; a secret ledge only the double jump reaches) → Spire (the
bound thing's first fight; for now the lightning tip waits on its plinth) → Anchor gorge (the
shockline tutorial: a spiked chasm crossed ring to ring) → Thunderbird's eyrie (the rematch; a
mask shard waits for now) → Storm tower (climbed ring to ring with the shockline, walls
spiked) → High pass.

**High pass:** joins the tops of both faces; the castle gate above it (double jump and
shockline together) is still to come.

`tools/check_reach.py` checks the layouts: that each room can be crossed with the abilities
it needs, and that every ability gate and secret really needs its ability.

Every region has its own painted backdrop and weather: the Foothills forest (light through
the canopy), the Frozen village outdoors (snow falling over the terraced houses, icicles),
and its caverns (frost drifting in the cold, icicles); the Fire slopes' burned village
(embers rising, ash and smoke drifting, embers smouldering on the ground) and the forge
under the rock (embers thicker, heat glowing up from below, molten drips under overhangs).

### Bosses: two fights per region
Every region's boss is fought twice. The first fight, partway through, wins the region's
upgrade (the blade piece). The second half of the region then works as the tutorial for that
new ability, building up to the rematch at the end with the boss at full strength.

### The bosses: each one is held back by a blade piece
Every boss is a part of the evil with a piece of the blade lodged in it. The piece is what
holds it back: while it's there the boss is bound, weakened or trapped. Winning the first
fight means prying the piece loose, which frees the boss at full strength for the rematch.

- **Foothills: the Guardian Centipede.** The forest's old guardian, a giant armored
  centipede, pinned to the forest floor by the hilt's lost sword catcher (the hook that lets
  Storm climb walls). See the fight plan below. (The Gate Warden is its placeholder for now.)
- **Frozen village: the Frost Colossus.** An ice golem frozen into the cavern wall by the ice
  piece. First fight: only its arms reach out of the wall; its slams leave ice lodged in its
  fists as footholds. Pulling the ice piece free breaks it out of the wall. Rematch: whole
  and bigger, it rolls into a ball (slide under it), freezes the floor, and raises ice pillars
  to wall jump between; a glowing core opens after its big slams. (The Frost Warden is its
  placeholder for now.)
- **Fire slopes: the Ashen Drake.** A dragon in a collapsed forge, then in its roost. Breath
  sweeps and wing gusts; its dives are answered with the double jump spin. See the fight
  plan below.
- **Lightning peaks: the Thunderbird.** The first fight is against its bound form, something
  small and wrong with the lightning tip driven through it. Pulling the tip out sets it free
  and it becomes the Thunderbird, a huge storm bird, for the rematch: Storm shocklines onto its
  glowing feathers to reach it.

### Fight plan: the Guardian Centipede (proposed)
**Fight 1: pinned (Great hall).** The sword catcher is driven through its tail into the
ground, so it can only reach a circle around the pin: a tethered boss.
- *Rearing lunge:* it rears up (the telegraph), then bites along the floor and sticks in the
  earth for a moment: the opening to hit its head.
- *Body sweep:* the long body swings across the arena at knee height; jump it.
- *Canopy slam:* it rams a trunk and clods of earth and branches rain down.
- At half health it coils up tight, and its coils become platforms: Storm climbs them to the
  pin and pulls the sword catcher free. That's the wall jump. The centipede tears loose,
  bursts into the wall, and the floor gives way beneath Storm, dropping him into the Catcher
  shaft he now has to climb.

**Fight 2: free (Gate fight).** It tunnels through the walls and floor of the arena.
- *Burrow crossings:* holes crack open in one wall, it bursts out and dives into the other;
  its body arcs across the room and can be used as a bridge.
- *Floor eruptions:* it tunnels under the floor and bursts up where Storm stands; clinging to
  the walls is safe, which is the test of the wall jump.
- *Armored segments:* each body segment is plated; hitting a segment cracks the plate off and
  its glow shows where it's been hurt. Breaking enough segments exposes the head.
- *Phase 2:* at half health it circles the whole arena, walls and ceiling, closing in. Storm
  wall-jumps up the middle to hit the head as it passes overhead. Hatchlings (crawlers) spill
  from the holes.
- Beaten, it crashes through the village gate, opening the way to the Frozen village.

### Fight plan: the Frost Colossus (proposed)
An ice golem the ice evil froze into the cavern wall, with the ice piece driven into its
chest: the piece is what holds it there.

**Fight 1: stuck in the wall (Frost arena).** Only its head, chest and two huge arms are out
of the ice; it can't move, so the fight is about its reach.
- *Fist slam:* it raises an arm; a shadow and falling frost mark where the fist will land.
  The fist slams down and stays wedged in the ice floor for a moment; its arm becomes a ramp
  up to its chest.
- *Floor sweep:* frost gathers along its forearm, then it sweeps the arm across the floor at
  knee height: jump it.
- *Icicle roar:* it roars and icicles fall from the ceiling; their shadows show where. They
  stick in the floor as spikes of ice in the way until its next slam or sweep shatters them.
- *Double slam:* the near fist comes down, then the far one where Storm has moved to; only
  the second stays wedged as a step.
- *Greed:* three hits on its chest in one opening and the crack bursts out a spray of ice
  shards.
- *Second half:* at half health it roars and tears its arm further out of the wall: it reaches
  further and attacks faster.
- *Weak point:* the glowing crack in its chest where the ice piece is lodged, reached by
  running up a wedged arm or wall climbing beside it.
- Beaten, it slumps; Storm pulls the ice piece out of its chest. Its eyes go dark, but the
  ice around it cracks...

**Fight 2: broken out (Frost throne).** The whole colossus, free, after the region has taught
the slide.
- *Roll:* it curls into a ball and rolls across the arena; slide under the gap as it bounces.
- *Frozen floor:* it stamps and the floor turns to slick ice for a while.
- *Pillars:* it raises ice pillars from the floor; wall jump between them to reach its head.
- *Trip:* sliding under its charge trips it; it crashes face down, chest on the floor, for a
  few moments. Charging into the wall instead stuns it to its knees, chest a jump high.
- *Reach:* it crouches and slams a fist down in front of it; the arm stays planted, a stair
  of footholds up to its chest.
- *Core:* after its big slams the armor on its chest cracks open, showing a glowing core.
- Beaten, it shatters into blocks of ice.

### Fight plan: the Ashen Drake
A dragon of charred scales cracked with embers, with the fire piece driven through its wing.

**Fight 1: grounded (Forge).** The piece pins its wing, so it can't fly. It sleeps in the
ashes at the forge's west end until Storm comes in, then stalks him along the floor. In a
fixed order:
- *Lunge:* it crouches with its head drawn back, then lunges forward and snaps. Its head
  stays low afterwards, panting smoke: the opening.
- *Breath:* its throat glows as it rears its head, then a jet of fire sweeps from high on
  the far wall down to the floor just ahead of it. The safe place is close in, under its
  chin.
- *Stomp:* it rears up and slams down; embers rain from the roof, their glow on the floor
  showing where.
- *Tail lash:* if Storm gets behind it, it raises its tail and lashes it down; a wave of fire
  runs out along the floor behind it: jump it.
- Its body hurts to touch, its head doesn't; both can be struck.
- Beaten, it collapses and the fire piece tears out of its wing (the double jump). Then it
  heaves itself up, spreads its wings for the first time and bursts up through the forge's
  roof, free. The hole stays open.

**Fight 2: free (Drake's roost).** A ledge high on the mountain, open to the sky, with rocks
to spin up onto. It drops out of the smoke and fights on the wing. In a fixed order:
- *Dive:* it rears back in the air and roars, then dives at where Storm stood, rakes the floor
  and climbs away. Step aside, then spin into its back as it skims.
- *Air breath:* it hangs high on one side and sweeps a jet along the floor away from itself;
  the floor burns behind it for a moment. The rocks shelter from it.
- *Slam:* it climbs above Storm, its shadow following him, and drops; fire runs out both ways
  along the floor. Then it stays down, panting: the big opening.
- *Gust:* it hangs facing him and beats its wings three times, each beat pushing him away and
  throwing embers.
- Below half health its slams shake embers down too. Beaten, it crashes and burns away to
  ash, leaving a mask shard.

### Enemies
- **Mossback beetle** (Foothills): as big as Storm. Patrols; spotting him ahead, it braces
  and charges, and running into a wall stuns it.
- **Burrow grub** (Foothills): a centipede larva waiting in the earth. The ground rumbles
  when Storm comes near, then it bursts out at him, crawls about, and burrows again: a small
  lesson in the Guardian Centipede's warning signs.
- **Frozen thrall** (Frozen village): a villager the cold turned into a husk. It shambles
  after Storm when he's near and lunges when he's close.
- **Ash bat** (Fire slopes): a bat of charred flesh with embers in its wings. It hangs in the
  air above its roost, drifting after Storm; then it screeches, flaring up, and dives at
  where he stood in a straight line, and swoops back up. A small lesson in the drake's dives.
- **Hatchlings**: the centipede's young, dropped into its second fight.

### Healing: flasks
Storm carries flasks of a shrine's pale flame (3 to start). Drinking one (F or Q, or B on a
controller) roots him in place for a moment and mends 2 masks; a hit before it lands spills
it. Every flask refills when he rests at a shrine or wakes at one after dying. More flasks
could be found later, like mask shards.

### The Foothills are a forest
Storm is thrown off the summit and lands at the very bottom of the mountain, in the dense
forest at its foot. The tutorial rooms are forest: earth and roots underfoot, trunks behind,
a leaf canopy overhead with shafts of light breaking through. The Great hall and Undercroft
are old ruins the forest has swallowed.

### Music
Tracks live in `audio/music/` and are set per room in `scripts/rooms.gd` (`MUSIC`).
- `exploration`: the default for the Foothills and general travel.
- `frozen_land`: the Frozen village region.

### Level design rules
- Every region has one ability-locked door forward, and at least one secret that pays off on
  a later return.
- Rest points before every boss and at every fork.
- Each region's rooms test its own ability: ice rooms are long dash gaps, fire rooms are tall
  climbs, lightning rooms are wide drops with anchor points.
- Fire and lightning regions must be fully completable with only the dash plus their own piece.
- Roughly 25 rooms for the first full slice. New rooms go in `scripts/rooms.gd` using the same
  door-letter links as the existing ones.

## Target platform
The goal is a commercial release on **Steam** someday.

## Open questions
- Are the fire and lightning regions villages too, or wilder terrain (volcano, storm peaks)?
- Do the villages have survivors or NPCs (shops, rest keepers)?
- Does Storm wake right where the tutorial starts, or wander a little first?
- How does the game end? Reforge the blade and reseal the evil, or something darker?
- Engine, art style, and scope of the first playable build.

---

## Original notes (verbatim)
> Broken Blade.
> metroidvania (hollow knight) where a sword that once sealed evil is shattered leaving parts of the evil attached to each piece of the sword
> each piece coordinates to a move the right of the sword is a dash with an ice theme the seconds is a double jump the has a fire effect
> the final and top piece will become a zip line like ability
> the game should have a dark fantasy vibe to it
> the main character Storm is the only surviving member of the royal family
> the plot starts with the sword shattering releasing an ancient evil which eliminates the royal family the king with his last power sends his last son away with the hilt of the broken blade where he rests for 20 years only to reimerge to a now broken kingdom run split by parts of the great evil each attached to one part of the broken blade
