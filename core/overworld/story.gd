extends RefCounted
## The slice's one story beat (D46): Professor Philius and the star readers. Three steps, told
## when you talk to him. Placeholder writing.
##
## Stages: 0 not started, 1 he wants anything carved with stars, 2 he wants the lintel stone,
## 3 told.

const DONE := 3
## A thank-you from Philius at the end: "my grant money; I never spend it".
const REWARD := 50

const BEATS := [
	{
		"needs": "",
		"lines":
		[
			"You came back! Splendid. Most don't. Well, I didn't, the first time.",
			"Did you see the carvings by the stair? Stars. All of them stars.",
			"Bring me anything carved with stars. I have a theory. I have several.",
		],
		"note": "Philius wants anything carved with stars.",
	},
	{
		"needs": "Star-chart shard",
		"lines":
		[
			"A star chart! Look, the island's here, and here, and... here again?",
			"They weren't burying kings down there. They were watching the sky.",
			"There's a lintel stone, I'm sure of it. Deep down. The whole sky on it.",
		],
		"note": "Philius thinks a star-carved lintel stone lies deep in the tomb.",
	},
	{
		"needs": "Star-carved lintel stone",
		"lines":
		[
			"Oh. Oh my. That's tonight's sky. And that's the island.",
			"But it's carved in the wrong place. As if the island has moved since.",
			"Take this, my grant money. I never spend it. We have work to do.",
		],
		"note": "The lintel shows the island under tonight's sky, but somewhere else.",
	},
]


## What happens if you talk to Philius now: {} if the story waits, else {stage (the new one),
## lines, note, reward}. expeditions: how many you've been on; have: the find ids in your bag,
## on your shelf and donated.
static func next(stage: int, expeditions: int, have: Array) -> Dictionary:
	if stage >= DONE:
		return {}
	var beat: Dictionary = BEATS[stage]
	if stage == 0 and expeditions < 1:
		return {}
	if beat["needs"] != "" and not have.has(beat["needs"]):
		return {}
	return {
		"stage": stage + 1,
		"lines": beat["lines"],
		"note": beat["note"],
		"reward": REWARD if stage + 1 == DONE else 0,
	}


## A reminder of what he is waiting for, or "" if nothing.
static func reminder(stage: int) -> String:
	match stage:
		1:
			return "Anything with stars on it, remember! Stars!"
		2:
			return "The lintel stone. Deep down. Floor four, perhaps five."
	return ""
