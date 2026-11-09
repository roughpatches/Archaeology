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
