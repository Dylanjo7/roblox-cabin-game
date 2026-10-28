--!strict
-- Every line of story text in Hollow Pines: the intro, the beats that play as the Hollow Man
-- closes in on the clock, and the endings. Rewrite freely; nothing else depends on the wording.

local Story = {}

Story.Title = "HOLLOW PINES"

-- The drive up (client/Trip), about 30 seconds. `at` is seconds from the start; each line stays up
-- until the next one, or for `hold` seconds when that isn't 0. Speakers: the old driver who brought you, and his
-- radio.
Story.Trip = {
	{ at = 5.6, speaker = "Driver", line = "Don't get many folks wanting to go up to Hollow Pines. Not after dark.", hold = 0 },
	{ at = 9.2, speaker = "Driver", line = "Ranger says the road's shut past the lake. I'll take you as far as the cabin path, no further.", hold = 0 },
	{ at = 12.6, speaker = "Radio", line = "...unit four... anyone on this channel... do not stop for anyone on the—", hold = 2.2 },
	{ at = 16.4, speaker = "Driver", line = "...You see that? Somebody standing out there in the trees.", hold = 3.4 },
	{ at = 21.4, speaker = "Driver", line = "No, no, no. Come on, girl. Not here.", hold = 0 },
	{ at = 24.4, speaker = "Driver", line = "Engine's gone. Cabin's just up the path. Go on. I'll radio for help.", hold = 3.2 },
}

-- Short lines while you walk up from the truck (after the drive up, Story.ArrivalAfterTrip).
Story.Arrival = {
	"Route 9. Past the last gas station, the radio turned to static and the pines closed over the road.",
	"The truck died a mile short of the lake. There's a cabin up the path. Its door is open.",
	"Somebody left the porch light on.",
}
Story.ArrivalAfterTrip = {
	"The driver's door hangs open. The radio hisses. He's gone.",
	"Somebody left the porch light on.",
}

-- The intro cutscene once you're inside and the door slams behind you (client/Scenes): one line
-- per shot, in this order: the door, the fire and the table, him out in the trees, the clock.
Story.Intro = {
	"Behind you, the front door slams. It won't open again. Every window shows the same black trees.",
	"A fire is already lit. On the Parlor table: a round board, a deck of cards, and one candle. Carved into the rim: PLAY UNTIL THREE.",
	"The locals have a name for what lives out there. They call him the Hollow Man. He keeps time by your candle, and he's coming to put it out.",
	"Build the house. Find the way out. Don't let him catch the light.",
}

-- Short lines when the Hollow Man moves on the clock.
Story.Beats = {
	enters = "Nine o'clock. Something steps out of the pines.",
	moves = "Something moves closer in the dark...",
	midnight = "Midnight. His steps grow longer.",
	caught = "He's at the door. Move the Candle, or it goes out.",
	pushedBack = "For a moment, the footsteps retreat.",
}

-- Notes left around the cabin by the four friends on the ranger station's "missing" poster
-- (Mara, Theo, Jun and Cal), found in rooms as they're built, always in this order (server/Notes).
-- Read in order they tell what happened to them, and who's been driving the truck since.
Story.Notes = {
	{ by = "Mara", text = "October 3rd. The truck died at the end of the path, just like the man at the gas station said it would. The cabin's warm. Somebody lit the fire for us." },
	{ by = "Theo", text = "There's a game set out on the table. Cards, a candle, a carved board. Cal says it's somebody's idea of a joke. The front door won't open, so we're playing." },
	{ by = "Jun", text = "The rooms aren't there until you play them. I put down a hallway and heard it build itself behind the wall. Like bones setting." },
	{ by = "Mara", text = "He doesn't come in while the candle burns. He waits at the edge of the light and counts. Keep the cards moving. Don't let the clock stand still for him." },
	{ by = "Theo", text = "The mirror in the sitting room is wrong. The chair by the fire isn't in it. Neither am I." },
	{ by = "Jun", text = "Scratches in three rooms. I added them up twice. Odd or even, the book says it matters. Everything in this house is counting." },
	{ by = "Cal", text = "Jun walked through the wrong door at three. He was smiling. The pines just folded around him." },
	{ by = "Mara", text = "Theo didn't come up from the basement this time. The door opened. He didn't." },
	{ by = "Cal", text = "The real way out isn't the same room twice. That's the trick of it. Believe the clues, not the room you want." },
	{ by = "Cal", text = "I got out. The truck started on the first try. I drive this road every night now. He says if I bring him enough of you, he'll let the others go. I'm sorry." },
}

-- Endings, keyed by the result's ending id.
Story.Endings = {
	caught = {
		title = "THE CANDLE GOES OUT",
		lines = {
			"The flame gutters. A cold hand closes around it.",
			"By morning the cabin is quiet, and the table is set for new players.",
		},
	},
	escaped = {
		title = "OUT OF THE PINES",
		lines = {
			"The door gives. Cold air, real air, and the long grey road.",
			"Behind you the cabin's windows go dark, one by one.",
			"The truck starts on the first try. Nobody looks back.",
		},
	},
	lost = {
		title = "THE DOORS CLOSE",
		lines = {
			"Three o'clock came and went. Nobody found the way out.",
			"By morning the cabin is quiet, and the table is set for new players.",
		},
	},
	never_built = {
		title = "NO WAY OUT",
		lines = {
			"Every door you opened led back inside.",
			"The way out was never built. It's still in the deck, waiting.",
		},
	},
}

return Story
