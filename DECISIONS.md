# Decisions

Structural decisions can be LOCKED. Anything about how something feels stays PROVISIONAL until it
has survived a playtest. Never edit a decision silently: supersede it with a new number.

D1 — Walkable scenes and menus
Status: LOCKED
Decision: Digs, survey grounds and camp are walkable top-down scenes. The world map, museums and
journal are menus.
Why: Keeps the walking where it pays off (finding things) and out of the way elsewhere.

D2 — No skill levels
Status: LOCKED
Decision: No skills or XP. Growth comes from tools, camp upgrades and discoveries.
Why: Andrew's call; major progress should come from discoveries.

D3 — A bad dig never destroys a find
Status: PROVISIONAL (until playtest)
Decision: Mistakes lower a find's condition (chips, partial exposure) but never destroy it.
Why: Keeps a mistake from costing a story unlock, while still mattering.

D4 — Tone
Status: LOCKED
Decision: Wondrous and adventurous, a clear break from The Last Archive's melancholy.

D5 — Wildlife and pets, no combat
Status: LOCKED
Decision: Ambient wildlife in every zone; pets at camp, some unlocked later. No combat.

D6 — Days and seasons
Status: LOCKED (season length and stamina numbers PROVISIONAL)
Decision: Stardew-style days and seasons. A day is 12 real minutes. Some finds and areas depend on
time of day, day or season.

D7 — Several museums
Status: LOCKED
Decision: Several museums with their own wish lists, competing for the same finds.

D8 — Stack
Status: LOCKED
Decision: Phaser 3 + Vite + TypeScript in this new repository, porting engine modules from The Last
Archive by copy. Pinned to Phaser 3.90.0.
Why: Andrew's call. Phaser 4 has been out since April 2026; moving to it is a separate decision.

D9 — Platform
Status: LOCKED
Decision: Desktop browser only.

D10 — Names
Status: LOCKED
Decision: Zone and civilization names stay placeholders for now.

D11 — Fully active
Status: LOCKED
Decision: No idle crew and no offline progress. Overnight results (museum replies, sales,
conservation) replace idle timers.
Why: Andrew's call once days and seasons were in; supersedes the idle/active model in the original
brief.

D12 — Gray-box dig rules
Status: PROVISIONAL (until playtest)
Decision: The first gray-box tests one decision: trowel (1 stamina, risks a chip) versus brush
(3 stamina, safe), with 100 stamina per dig, guided by a site map of three grades and by soil
stains. Details in FEEL_DIG.md.
Why: It is the cheapest version of the dig that has a real choice in it.

D13 — Four dig tools
Status: PROVISIONAL (until playtest). Extends D12.
Decision: The pick (3 stamina) takes a layer off a 3 × 3 patch and chips anything it breaks onto.
The probe (1 stamina) shows a tile's remaining layers and whether something hard is below,
without digging. They join the trowel (1) and the brush (3).
Why: Andrew asked for two more tools after the first playtest. The pick gives bulk work a tool,
and the probe gives information a price, so each tool has its own job.

D14 — Several finds per site, and pieces of large artifacts
Status: PROVISIONAL (until playtest)
Decision: Each site holds three separate finds: two whole ones and one piece of a large artifact
(placeholder: the Lantern Crown, in four pieces, one per site). Pieces are assembled at camp once
all are found.
Why: Andrew's request after the first playtest.

D15 — Lifting a find out
Status: PROVISIONAL (until playtest)
Decision: Exposing a find is not the end. You hold to lift it out (2 stamina), and every three
tiles of soil still packed against it do a point of damage. Clearing round it first means a clean
lift. The find rises out of the trench and its card appears.
Why: Makes uncovering more involved and gives it a final moment of its own (playtest 1).

D16 — Digs run over several days
Status: PROVISIONAL (until playtest)
Decision: The trench stays open between days; sleeping restores stamina. A find left partly
exposed overnight weathers and loses a point of condition, so the plan is to expose only what you
can lift that day.
Why: Andrew wants the full process to take several days per site (playtest 1).

D17 — Scouting, surveying, excavating
Status: PROVISIONAL (until playtest)
Decision: Fieldwork runs scouting (find a site), surveying (map what's in it), then excavating,
over several days. The map grade stops being a choice and comes from how well the site was
surveyed. Specced in FEEL_FIELDWORK.md; the survey is the next gray-box.
Why: Andrew's request after playtest 1.

D18 — Survey gray-box rules
Status: PROVISIONAL (until playtest). Implements the survey half of D17.
Decision: A site opens with a survey. A reading costs 4 of the day's 100 stamina and senses every
square within 2, with noise that is smallest right under it and grows with distance. Readings on a
square combine, so overlapping them makes the map surer. Each square's certainty sets its grade:
rough (marked only on a strong signal, no depth), measured (depth within one) or fine (exact). A
find's grade is the grade most of its squares reached, and sets its context in the dig. D hands
the map to the dig, which starts the next morning. Pressing M in the dig still swaps in a fixed
grade, for comparison.
Why: Makes the map grade something you earn by surveying, and puts a spread-or-focus choice on
every reading.

## Rescope, 12 Nov 2026

Andrew rescoped the game around one island and expeditions. The design is in the Claude Doc
"Island expeditions: rescoped design". D1 to D18 above are kept as history; the ones these
supersede say so here.

D19 — Engine: Godot
Status: LOCKED. Supersedes D8.
Decision: Godot 4.7, pinned to 4.7.2-stable, with GDScript. The Phaser gray-box stays on its
branch (draft PR #1) as a reference; its dig and survey rules are ported by hand when needed.
Why: Andrew's call. GDScript needs no extra runtime and is Godot's best-supported language.

D20 — Setting and loop: one island
Status: LOCKED. Supersedes the six-zone world and the original pitch's scope.
Decision: The player is an archaeologist sent to a mysterious island. A small base camp with one
NPC. Play splits between the overworld (gathering, exploring, expanding camp, preparing) and
procedurally generated expeditions into areas of the island, for rare materials and finds that
explain the world. Stardew-style top-down view.
Why: Andrew's rescope.

D21 — No fighting
Status: LOCKED. Supersedes the "no combat" part of D5 by making it specific; wildlife and pets hold.
Decision: Creatures in expeditions chase, block or guard. The player avoids them or drives them off
with crafted defensive tools (flares, bait, lures). No weapons, no enemy health.
Why: Andrew's choice. Keeps the tone and the scope while giving crawls a threat.

D22 — Supply boat and three outlets
Status: LOCKED. Keeps D7 (several museums).
Decision: A supply boat calls at the island. Finds can be sold to traders (intact pays more,
pieces less), donated to museums, or kept in displays on the island.
Why: Andrew's call; keeps the keep/donate/sell choice on an island.

D23 — Core verb: the expedition
Status: LOCKED. Supersedes the pitch's core verb (the dig).
Decision: The expedition is the core verb. Dig sites are found during expeditions; the dig and
survey rules (D12 to D15, D18) live inside it, scaled to dig spots.
Why: Andrew's call.

D24 — Platform: desktop app
Status: LOCKED. Supersedes D9.
Decision: A desktop application. No browser build planned.

D25 — The NPC
Status: LOCKED (name is a placeholder under D10 unless Andrew says otherwise).
Decision: Professor Philius, already at camp, slightly addled by his long time on the island.

D26 — No clock in expeditions
Status: LOCKED. Amends D6.
Decision: Time does not run inside expeditions; stamina is the limit. Assumed, to confirm: overworld
days still end when the player sleeps.

D27 — Test runner
Status: PROVISIONAL.
Decision: A small in-repo test runner (`tests/run_tests.gd`) run headless, instead of the GUT
add-on, for the setup phase. Revisit if tests need mocks, doubles or parameterised cases.
Why: No add-on to vendor or keep in step with Godot versions; enough for pure `core/` tests.
