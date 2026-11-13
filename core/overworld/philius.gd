extends RefCounted
## What Professor Philius says (D25: slightly addled by his long years on the island). Lines
## depend on the season and the half of the day. Placeholder writing for the gray-box.

const LINES := {
	"any":
	[
		"Ah, you again! Or is it the first time? The island does that to a calendar.",
		"Rope, my dear. Always rope. Getting into the tomb is easy; it's the leaving.",
		"I named that crab Horace. Or it named me. One of the two.",
	],
	"night":
	[
		"Glowcaps come up after dark, in the damp places. Mind your feet.",
		"The tomb is busier at night. Things wake that ought not to.",
		"Can't sleep either? I count the stars. They keep changing the total.",
	],
	"Dry season":
	[
		"Resin weeps from the trees in this heat. Or was that me?",
		"Nothing fruits in the dry. Even the monkeys are sulking.",
	],
	"the Rains":
	[
		"The rains swell the streams below. The tomb will be wet going.",
		"Vines grow thick in the rains. Good for rope, if you've the patience.",
	],
	"Bloom":
	[
		"Bloom! Fruit everywhere. Pack a ration or two, you'll thank me.",
		"The flowers on the old steps open only now. Somebody planted them. Long ago.",
	],
	"the Mists":
	[
		"Mist season. Glowcaps grow fat on it. So do my doubts.",
		"I heard singing from the tomb last mist. Probably the wind. Probably.",
	],
}


## The line for the nth time you speak to him this half.
static func line(season_name: String, night: bool, n: int) -> String:
	var pool: Array = []
	pool.append_array(LINES[season_name])
	if night:
		pool.append_array(LINES["night"])
	pool.append_array(LINES["any"])
	return pool[n % pool.size()]
