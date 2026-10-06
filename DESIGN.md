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
| Final / top piece (the tip) | Shockline: fires a straight line to a grapple point or enemy and pulls you to it (like Silksong's clawline); a pull cut short (jumped out of, timed out, snagged) leaves Storm at running speed, never flung | Lightning |

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
The mountain is laid out in `tools/build_rooms.py` (45 rooms). The Foothills climb to the
Frozen village, which climbs to the Crossroads at the bottom middle of the mountain. From
there each face switches back on itself: a lower road out to its boss, a tall climb at its
far end, and an upper road back toward the middle, then a last climb onto the High pass,
which runs along the summit above the Crossroads and joins the two faces' tops.

**Foothills:** Landing (rest) → Thicket (logs and branches, no enemies yet) → Rockfall →
Sunken glade (grubs in a dip) → Ring (rest; the pit and the first centipede fight: the hilt)
→ Cliff (rest at the top) → Fern gully (drop in, wall jump out) → Gate cavern (the risen
centipede; the frozen gate).

**Frozen village:** Frozen street (the gate, frozen villagers) → Village square (rest hub) →
Icefall hall (ledges up over spikes) → Ice caverns (the Frozen cellar hides off it,
shockline only) → Frost arena (the Frost Colossus: the ice piece) → Glacier run → Frozen
depths (slide tutorial) → Frost throne (the rematch) → Ice climb → Frozen bridge →
Crossroads (rest; a hidden ledge with a mask shard for the double jump or the shockline).

**Fire slopes (west face):** lower road west: Ashen road → Smoke hollow → Burning homes (rest;
a secret ledge for the shockline) → Slag works → Forge (the Ashen Drake: the fire piece); the
Cinder steps climb (the double jump tutorial) turns it back; upper road east: Bellows hall →
Ember span → Cinder ridge → Drake's roost (the rematch) → Fire shaft (double jump) → High
pass.

**Lightning peaks (east face):** lower road east: Cliff road → Lookout → Storm bridges (rest; a
secret ledge for the double jump) → Rod field → Spire (the Stormcaller, bound: the lightning
tip) → Anchor gorge (the shockline tutorial); the Chain ravine climb (ring to ring) turns it
back; upper road west: Gale ledges → Aqueduct → the eyrie (the Stormcaller freed) → Storm
tower (shockline) → the summit.

**The Crossroads area** is where the two faces meet, below and above:
- *The Refuge (below):* the Crossroads (rest) and, through a gap in its road, the survivors'
  camp in a sheltered hollow underneath: Sister Maud the healer, Old Bram the king's smith
  (who forged the blade), and Wren the mapmaker; the Old barracks east (Hale, who ran from
  the gate; a mask shard on a high shelf, wall jump) and the Storehouse west (a mask shard
  behind the crates, slide). Road stone and snow, firelight and embers from the campfires.
  The survivors only talk for now; shops would need a currency.
- *The old lift shaft:* from the High pass a gap drops straight down the old lift shaft to
  the Crossroads: a way back to the refuge once Storm has reached the summit (it can't be
  climbed from below).
- *The Last Stand (above):* High pass → Windward pass → Summit ledge, the battlefield under
  the castle gate where the royal army fell: torn banners, wrecked siege engines, graves and
  heaped armor, mist rolling over it, far-off flashes of fire and lightning. Hollow knights
  walk it. The castle gate above the High pass (double jump and shockline together) is
  still to come.
- From the summit, the way down into each face's last climb is sealed by that face's evil
  (a wall of fire over the Fire shaft, lightning across the Storm tower) until Storm holds
  its piece, so neither face can be entered from the top and its first boss skipped.

`tools/check_reach.py` checks the layouts: that each room can be crossed with the abilities
it needs, and that every ability gate and secret really needs its ability.

Every region has its own painted backdrop and weather: the Foothills forest (light through
the canopy), the Frozen village outdoors (snow falling over the terraced houses, icicles),
and its caverns (frost drifting in the cold, icicles); the Fire slopes' burned village
(embers rising, ash and smoke drifting, embers smouldering on the ground) and the forge
under the rock (embers thicker, heat glowing up from below, molten drips under overhangs);
the Lightning peaks under the storm (rain slanting in the wind, lightning flashes with thunder
after) and inside the spire and the tower (static drifting, water dripping, arcs jumping
across the rock). Scenery props are drawn flat, straight-on, to sit in the 2D world.

### Bosses: two fights per region
Every region's boss is fought twice. The first fight, partway through, wins the region's
upgrade (the blade piece). The second half of the region then works as the tutorial for that
new ability, building up to the rematch at the end with the boss at full strength.

### The bosses: each one is held back by a blade piece
The piece is part of the boss's own art (the ice piece in the colossus's chest crack, the
fire piece driven through the drake's folded wing, the lightning tip jutting from the
Stormcaller's back). Each first fight ends with the piece tearing free and floating up into
the middle of the arena, where Storm takes it, as the hilt does after the centipede. Pickups
show the piece itself, cut from the sword's art (art/blade/piece_*.png).

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
- **Lightning peaks: the Stormcaller.** The king's court sorcerer, who first sealed the evil
  into the blade, taken by it. See the fight plan below.

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
  the second stays wedged, its arm a stair of footholds up to the chest. Planted fists can be
  struck too.
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
- *Reach:* it drops to one knee and slams a fist down in front of it; the arm stays planted,
  a stair of icy footholds up to its chest (within a jump anyway).
- While it's down (stunned, tripped, or planted on its arm), a blow anywhere on its upper body
  finds the crack.
- *Core:* after its big slams the armor on its chest cracks open, showing a glowing core.
- Beaten, it drops to its knees as cracks spread from the hole in its chest, light pouring
  out of them and chunks breaking away; then it comes apart a part at a time: its legs burst
  and its body drops to the ground, then its arms, then its body.

### Fight plan: the Ashen Drake
A dragon of charred scales cracked with embers, with the fire piece driven through its wing.

**Fight 1: grounded (Forge).** The piece pins its wing, so it can't fly. It sleeps in the
ashes at the forge's west end until Storm comes in, then stalks him along the floor. In a
fixed order:
- *Lunge:* it crouches with its head drawn back, then lunges forward and snaps. Its head
  stays low afterwards, panting smoke: the opening.
- *Breath:* it crouches with its head low and level and its throat glows, then a jet of fire
  roars straight out at chest height to the far wall. Slide under it, and under the drake
  itself (a slide always passes under its belly safely) to come out behind it.
- *Stomp:* it rears up and slams down; embers rain from the roof, their glow on the floor
  showing where.
- *Rampage:* it paws the ground snorting smoke, then charges the length of the forge: slide
  under its belly. If it runs into the wall it staggers with its head low: the opening.
- Everything it does in the forge takes two masks. Its jaw drops open (only as far as its
  head allows) as it lunges and breathes, the inside of its mouth lit by the fire: the tell.
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
- Below half health its slams shake embers down too. Below 40% it heats up: it bursts into
  flame, its scales glowing ember-orange, its wings burning, and it flies and fights faster,
  adding meteors: it hangs over the roost spitting fireballs that arc down around Storm and
  leave the floor burning.
- Beaten, it makes one last attack: white-hot, wings ablaze, it climbs high over the roost
  while a ring of fire on the floor follows Storm, locks on, and dives at the ring, blowing
  itself apart. Be out of the ring. It's left as ash, with a mask shard in it.

### Fight plan: the Stormcaller
**Fight 1: bound (Spire).** A small hunched figure in rags, the lightning tip through its
back, a crackling chain from it to the plinth: it can't go further than the chain reaches
(the walls and their ledges are out of reach). It blinks from spot to spot (a crackle on the
floor first) and casts, in a fixed order:
- *Floor arcs:* lightning runs both ways along the floor: jump.
- *Orbs:* two balls of static drift after Storm; strike them to pop them.
- *Roof bolts:* back on the plinth it calls four bolts down from the roof, one after
  another wherever Storm stands (each flickers first), then kneels spent: the big opening.
- *Chain lash:* the chain glows and it swings over the plinth from one side to the other,
  sweeping everything within reach: get out to the walls.
- Touching it hurts, except while it kneels spent. Beaten, the tip tears out of it; it rises,
  swells into its true form and bursts up through the spire's roof.

**Fight 2: freed (the eyrie).** A peak open to the storm with lightning rods standing high
around it. A towering sorcerer whose robes dissolve into storm cloud, blinking between the
rods; the shockline reaches it there. Touching it doesn't hurt; its spells do:
- *Bolts:* bolt after bolt strikes where Storm stands, each flickering a moment first: keep
  moving.
- *Beam:* it locks on to Storm's height and fires across the whole arena.
- *Bolt rain:* rows of bolts across the whole arena, every other column, then the others
  (three rows below 40%).
- *Copies:* two fainter copies at other rods (one blow pops one); all three send an orb.
- Below 40% it erupts with light and fights on in a crackling aura, faster, adding the
  storm surge: a wall of lightning gathers at one side and sweeps the floor end to end; get
  up on a ring. (The eyrie has no rocks: the rings are the way up to it and out of the surge.) Beaten, the storm turns on it:
  bolt after bolt strikes it, faster and faster, as it sinks slowly to the ground, until a
  last great one blasts it apart, leaving a mask shard.

### Enemies
- **Mossback beetle** (Foothills): as big as Storm. Patrols; spotting him ahead, it braces
  and charges, and running into a wall stuns it.
- **Burrow grub** (Foothills): a centipede larva waiting in the earth. The ground rumbles
  when Storm comes near, then it bursts out at him, crawls about, and burrows again: a small
  lesson in the Guardian Centipede's warning signs.
- **Frozen thrall** (Frozen village): a villager the cold turned into a husk. It shambles
  after Storm when he's near and lunges when he's close.
- **Spark wisp** (Lightning peaks): a knot of static around a stone core with one eye. It
  hangs in the air drifting after Storm, then charges, a thin line showing its aim (it stops
  tracking just before it fires), and zaps a beam along it to the rock. The shockline can
  catch it like a ring.
- **Hollow knight** (the Last Stand): the empty armor of the royal army, scorched and
  storm-struck. It advances behind its shield (blows from the front glance off), raises its
  sword and brings it down hard close in, and is slow to recover: hit it then, from behind,
  or from above.
- **Ash bat** (Fire slopes): a bat of charred flesh with embers in its wings. It hangs in the
  air above its roost, drifting after Storm; then it screeches, flaring up, and dives at
  where he stood in a straight line, and swoops back up. A small lesson in the drake's dives.
- **Moss toad** (Foothills): a toad with ferns growing from its back. It sits, then hops at
  Storm in arcs.
- **Frost hound** (Frozen village): a wolf grown through with ice crystals. It runs Storm
  down, crouches, and leaps at him.
- **Frost bat** (Frozen village): the ash bat's frostbitten kin, pale blue with ice glowing
  where the embers were; it hunts the same way. Reused enemies always wear their region's
  colours.
- **Cinder husk** (Fire slopes): a burnt villager, still smouldering. It shambles after him;
  close in its embers flare faster and faster and it bursts in fire: kill it first or get
  clear.
- **Conductor** (Lightning peaks): an iron walker with a lightning rod on its back. Close in
  it charges up crackling and sends shockwaves both ways along the floor: jump them.
- **Hollow archer** (the Last Stand): an archer of the royal army, empty like the knights. It
  backs away, draws, and looses arrows at Storm (the blade cuts them down).
- **Carrion crow** (the Last Stand): a crow off the battlefield; it hunts like the bats.
- **Hatchlings**: the centipede's young, dropped into its second fight.

### Death
When his last mask breaks, time slows; cracks of light run across his blade and it comes
apart in his hand, then bursts, shards of steel and of each piece he'd won back flying; Storm crumples where he stands (falling if he's
in the air), sinking to his knees and collapsing face down. Then the screen fades and he wakes at the last shrine.

### Rings
Shocklined to a ring, Storm hangs from it by his blade. Jumping off is always a full jump
(the double jump, once he has it, is still there after it), and letting go, a jump still
works for a moment.

### Healing: flasks
Rest shrines stand by the way into every boss fight, and a shrine kindles in the arena the
moment a boss falls (Storm wakes there from then on).

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
- Should the survivors at the refuge become shops (a currency to collect)?
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

### Ground
Every region has two kinds of ground (rooms.gd's FLOORS picks which rooms use the second):
forest earth, and roots and boulders on the rockier slopes; cave rock under the forest;
the village's frosted brick, and natural glacier ice outside it; the fire slopes' charred
brick, and cooled basalt with magma seams on the upper road; the lightning peaks' slate,
and old fitted masonry for the Spire, the Storm tower and the aqueduct; road stone at the
Crossroads, timber floors in the Refuge, frozen battlefield earth on the summit. Rooms
narrower than the screen sit in the middle of it, solid rock drawn on to its edges.
