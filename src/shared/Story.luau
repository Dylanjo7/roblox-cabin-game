--!strict
-- Every line of story text in Hollow Pines: the intro, the beats that play as the Hollow Man
-- closes in on the clock, and the endings. Rewrite freely; nothing else depends on the wording.

local Story = {}

Story.Title = "HOLLOW PINES"

-- Short lines while you walk up from the truck.
Story.Arrival = {
	"Route 9. Past the last gas station, the radio turned to static and the pines closed over the road.",
	"The truck died a mile short of the lake. There's a cabin up the path. Its door is open.",
	"Somebody left the porch light on.",
}

-- Shown one line at a time once you're inside and the door slams behind you.
Story.Intro = {
	"A fire is already lit. On the Parlor table: a round board, a deck of cards, and one candle. Carved into the rim: PLAY UNTIL THREE.",
	"Behind you, the front door slams. It won't open again. Every window shows the same black trees.",
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
