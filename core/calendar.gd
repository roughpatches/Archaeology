extends RefCounted
## Island time (D35). There is no running clock: a day has two halves, day and night, and time
## only moves on when the player rests or goes on an expedition (each takes half a day).
## Seasons (D36) turn over every SEASON_DAYS days. Names are placeholders (D10).

const HALVES: Array[String] = ["day", "night"]
const SEASONS: Array[String] = ["Dry season", "the Rains", "Bloom", "the Mists"]
const SEASON_DAYS := 7


## How many halves have passed since the first morning (day 1, day half = 0).
static func half_index(day: int, half: int) -> int:
	return (day - 1) * 2 + half


## The day and half after this one, as [day, half].
static func next(day: int, half: int) -> Array[int]:
	if half == 0:
		return [day, 1]
	return [day + 1, 0]


static func is_night(half: int) -> bool:
	return half == 1


## Season index (into SEASONS) for a day.
static func season(day: int) -> int:
	return ((day - 1) / SEASON_DAYS) % SEASONS.size()


## Which day of its season this is, from 1.
static func day_of_season(day: int) -> int:
	return (day - 1) % SEASON_DAYS + 1


## e.g. "Day 3, night. The Rains, day 3 of 7."
static func describe(day: int, half: int) -> String:
	var s := SEASONS[season(day)]
	return (
		"Day %d, %s. %s, day %d of %d."
		% [day, HALVES[half], s[0].to_upper() + s.substr(1), day_of_season(day), SEASON_DAYS]
	)
