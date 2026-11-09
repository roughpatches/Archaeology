# Feel spec: scouting and surveying

Andrew wants a full process: scouting to identify a new dig site, surveying to work out where in
it finds are, then excavating to get them out, over several days. This is the proposal for the two
new steps. Each gets a gray-box and a playtest before anything else is built on it; the survey
comes first, because it feeds the dig directly.

A site, end to end, should take about 4 to 6 in-game days: 1 to 2 scouting, 1 surveying, 2 to 3
excavating.

## Scouting: finding a site

The player walks a region (a top-down map, roughly 40 × 30 tiles) looking for signs that people
lived or something died here.

- **Read:** surface signs show when you walk near them: sherds by a river bend, an odd mound,
  bone chips at a burrow, crop marks that only show in dry weather or low evening light. Terrain
  hints too: high ground near water is where towns grew. Each sign you inspect becomes a pin in
  the field notebook.
- **Decide:** where to walk with a day's stamina (walking and inspecting both cost it), and when
  enough pins cluster to stake a claim rather than keep looking. Staking spends the claim, so a
  weak site is a real cost.
- **Feedback:** pins that agree draw together into "promising ground" on the notebook map; staking
  a claim marks the trench outline on the ground.

Some signs only show at certain times or seasons (D6), so scouting the same ground again later can
turn up a site you walked past.

## Surveying: mapping what's buried (gray-box built, D18)

On the claimed site, the player takes readings across the trench area.

- **Read:** each reading senses every square within 2, with noise that is smallest right under
  it and grows with distance. Squares go from dark (unread) toward warm (something there) or cool
  (probably nothing), and grow stronger in colour as the survey gets surer. White dots mark where
  readings were taken. The blue boxes are the map the dig will get, with depth guesses where the
  survey is sure enough.
- **Decide:** where to take readings with the day's stamina (4 each, 25 a day). Spread them to
  find all three finds roughly, or concentrate them to map one exactly, or spend another day.
- **Feedback:** a ping spreads from each reading and the squares it sensed settle into their new
  colour; outlines tighten and depth guesses appear and firm up.

**The map grade stops being a choice.** A square's certainty sets its grade: rough (marked only on
a strong signal, no depth), measured (depth within one) or fine (exact). A find's grade is the
grade most of its squares reached, and sets its context when it's lifted.

### What the numbers say so far

Simple surveyors (`tests/surveybot.ts`) over 200 sites, then the dig bot on the map they made:

| Survey                             | Survey days | Finds mapped fine / measured / rough | False squares on the map | Finds lifted | Of those, pristine | Dig days |
| ---------------------------------- | ----------- | ------------------------------------ | ------------------------ | ------------ | ------------------ | -------- |
| Grid, every 3rd square             | 1           | 0% / 1% / 99%                        | 11                       | 17%          | 33%                | 1.6      |
| Grid, then focus on likely squares | 1           | 0% / 72% / 28%                       | 9                        | 36%          | 57%                | 2.0      |
| Grid, every 2nd square             | 2           | 10% / 89% / 2%                       | 11                       | 65%          | 75%                | 2.6      |
| Grid, then focus                   | 2           | 96% / 4% / 0%                        | 3                        | 83%          | 94%                | 2.3      |

Two days of well-placed readings map a site finely, which fits the 4 to 6 day target for a whole
site. The dig bot never explores off the map, so a person should lift far more than it does from
rougher maps.

### Questions the playtest should answer

1. Does choosing where to read feel like a decision, or like filling in a grid?
2. Can you read the colours: what's likely, and how sure the survey is?
3. Does a better survey make the dig that follows feel noticeably easier?
4. Is two days of survey per site the right length?

## Gray-box plan

1. **Survey gray-box (built):** the same 14 × 10 site with three hidden finds, a day of survey stamina,
   readings with noise, and the map building up live. Then hand the resulting map to the dig.
2. **Scouting gray-box:** a region of coloured squares, signs, a notebook of pins, and staking a
   claim that opens a survey.
3. **Chain them:** scout, survey and dig one site across several days, then playtest the whole
   process.
