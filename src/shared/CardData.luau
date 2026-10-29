--!strict
-- Every card definition, as data. Gameplay code looks cards up here by id; no per-card logic.
-- Copies per deck live in Config.CardCopies, clock steps in Config.ProgressSteps.

local Config = require(script.Parent.Config)
local RoomShapes = require(script.Parent.RoomShapes)

type Dir = RoomShapes.Dir

export type CardType = "Room" | "Progress" | "Clue" | "Exit" | "Event"

export type CardDef = {
	id: string,
	name: string,
	type: CardType,
	inDeck: boolean, -- false for setup-only rooms (Parlor, Crawlspace)
	doors: { Dir }?, -- Room: doorways at rotation 0
	buildable: boolean?, -- Room: false means nothing can be built off it (Crawlspace)
	effect: string?, -- Progress: side-effect id handled by CardEffects (Step 4)
	color: Color3?, -- Room: floor colour
	wall: Color3?, -- Room: wallpaper colour
	size: Vector2?, -- Room: inside width (X) and depth (Z) at rotation 0; default fills the tile
	exit: boolean?, -- Room: one of the 8 exit rooms (sealed outside door until 3:00 AM)
	red: boolean?, -- a red card: only goes into the deck when something unlocks it
	text: string,
}

-- The rooms you build, one card each. Door shapes at rotation 0: straight N+S, corner N+E,
-- three-way N+E+W, four-way all sides, single N. (Same shape mix as RULES.md's 21 basic rooms.)
local STRAIGHT: { Dir } = { "N", "S" }
local CORNER: { Dir } = { "N", "E" }
local THREE: { Dir } = { "N", "E", "W" }
local FOUR: { Dir } = { "N", "E", "S", "W" }
local SINGLE: { Dir } = { "N" }

local function room(id: string, name: string, doors: { Dir }, text: string, floor: Color3, wall: Color3, size: Vector2?): CardDef
	return { id = id, name = name, type = "Room", inDeck = true, doors = doors, text = text, color = floor, wall = wall, size = size }
end

local OAK = Color3.fromRGB(104, 74, 50)
local DARK = Color3.fromRGB(70, 50, 36)
local PINE = Color3.fromRGB(130, 98, 66)
local TILE = Color3.fromRGB(150, 146, 136)

local ROOMS: { CardDef } = {
	-- Straight through
	room("front_hall", "Front Hall", STRAIGHT, "Coats on hooks that nobody hung. Boots by the wall, still wet.", OAK, Color3.fromRGB(92, 70, 58), Vector2.new(14, 40)),
	room("back_hall", "Back Hall", STRAIGHT, "A narrow hall that feels longer walking back.", DARK, Color3.fromRGB(74, 66, 60), Vector2.new(12, 40)),
	room("gallery", "Gallery", STRAIGHT, "Portraits line the walls. None of them are smiling.", OAK, Color3.fromRGB(86, 40, 40), Vector2.new(16, 40)),
	room("pantry", "Pantry", STRAIGHT, "Shelves of jars, labels in a hand you don't recognise.", PINE, Color3.fromRGB(110, 96, 70), Vector2.new(14, 40)),
	room("stair_hall", "Stair Hall", STRAIGHT, "Stairs climb to a floor this cabin doesn't have.", DARK, Color3.fromRGB(60, 64, 70), Vector2.new(16, 40)),
	room("sun_porch", "Sun Porch", STRAIGHT, "Wicker chairs and dead plants. The glass shows only night.", PINE, Color3.fromRGB(100, 110, 96)),
	-- Corners
	room("kitchen", "Kitchen", CORNER, "The stove is warm. Something was cooked here tonight.", TILE, Color3.fromRGB(120, 112, 84)),
	room("dining_room", "Dining Room", CORNER, "Places set for one more than you.", OAK, Color3.fromRGB(70, 46, 50)),
	room("living_room", "Living Room", CORNER, "The sofa still holds the shape of someone sitting.", OAK, Color3.fromRGB(78, 74, 56)),
	room("laundry_room", "Laundry Room", CORNER, "Damp sheets on the line. Some of them move.", TILE, Color3.fromRGB(90, 100, 104)),
	room("sewing_room", "Sewing Room", CORNER, "A dress form stands by the window, facing in.", PINE, Color3.fromRGB(104, 72, 84)),
	room("library", "Library", CORNER, "Every book is about the woods.", DARK, Color3.fromRGB(56, 62, 50)),
	-- Three doors
	room("den", "Den", THREE, "Antlers over the mantel. Too many points.", DARK, Color3.fromRGB(84, 58, 42)),
	room("sitting_room", "Sitting Room", THREE, "Two chairs turned toward a wall.", OAK, Color3.fromRGB(70, 74, 88)),
	room("music_room", "Music Room", THREE, "The piano is open. One key is warm.", OAK, Color3.fromRGB(60, 44, 66)),
	room("game_room", "Game Room", THREE, "A game left mid-hand. Your name is on the score card.", DARK, Color3.fromRGB(46, 70, 54)),
	-- Four doors
	room("grand_hall", "Grand Hall", FOUR, "Bigger than the cabin should hold.", OAK, Color3.fromRGB(96, 80, 60)),
	room("foyer", "Foyer", FOUR, "Every door here looks like the way out.", PINE, Color3.fromRGB(88, 64, 54)),
	-- One door
	room("bathroom", "Bathroom", SINGLE, "A clawfoot tub, a cracked mirror, and a pull-cord in the ceiling.", TILE, Color3.fromRGB(96, 116, 110), Vector2.new(22, 22)),
	room("bedroom", "Bedroom", SINGLE, "The bed is made. The pillow is dented.", PINE, Color3.fromRGB(84, 96, 112)),
	room("linen_closet", "Linen Closet", SINGLE, "Three deep cupboards. Room to hide, if you hold your breath.", OAK, Color3.fromRGB(98, 86, 70), Vector2.new(20, 20)),
}

-- The 8 exit rooms (RULES.md), one card each. Their clue combinations are in ClueData.Exits.
local function exitRoom(id: string, name: string, doors: { Dir }, text: string, floor: Color3, wall: Color3, size: Vector2?): CardDef
	local def = room(id, name, doors, text, floor, wall, size)
	def.exit = true
	return def
end

local EXITS: { CardDef } = {
	exitRoom("boathouse", "Boathouse", SINGLE, "Exit room. A rowboat on blocks, and a door to the lake, boarded shut.", DARK, Color3.fromRGB(58, 70, 76)),
	exitRoom("root_cellar", "Root Cellar", SINGLE, "Exit room. Cold earth and jars. A storm door, chained from this side.", Color3.fromRGB(70, 58, 44), Color3.fromRGB(84, 72, 58), Vector2.new(24, 24)),
	exitRoom("greenhouse", "Greenhouse", STRAIGHT, "Exit room. Everything in it is dead. The garden door is nailed shut.", TILE, Color3.fromRGB(76, 92, 70)),
	exitRoom("study", "Study", CORNER, "Exit room. A letter on the desk, addressed to you. The door out is boarded.", OAK, Color3.fromRGB(70, 52, 40)),
	exitRoom("chapel", "Chapel", STRAIGHT, "Exit room. Pews facing the wrong way. A side door, barred.", PINE, Color3.fromRGB(96, 90, 80)),
	exitRoom("workshop", "Workshop", CORNER, "Exit room. Tools hung in neat outlines, one missing. The yard door is nailed.", DARK, Color3.fromRGB(80, 70, 56)),
	exitRoom("nursery", "Nursery", THREE, "Exit room. The mobile over the cot is still turning. Its outside door is boarded.", PINE, Color3.fromRGB(110, 92, 96)),
	exitRoom("mudroom", "Mudroom", THREE, "Exit room. Boots lined up by a back door that has been nailed shut.", OAK, Color3.fromRGB(86, 80, 66), Vector2.new(30, 30)),
}

local CARDS: { CardDef } = {
	-- Setup rooms (not shuffled in)
	{
		id = "parlor",
		name = "Parlor",
		type = "Room",
		inDeck = false,
		doors = { "N", "E", "S", "W" },
		color = Color3.fromRGB(96, 62, 46),
		text = "The starting room. A door on every side.",
	},
	{
		id = "crawlspace",
		name = "Crawlspace",
		type = "Room",
		inDeck = false,
		doors = { "N" },
		buildable = false,
		color = Color3.fromRGB(40, 38, 34),
		text = "Attached to the Parlor at setup. Nothing can be built from it.",
	},


	-- Progress (enabled in the deck in Step 4)
	{ id = "steady_hands", name = "Steady Hands", type = "Progress", inDeck = true, effect = "none", text = "No side effect." },
	{
		id = "second_wind",
		name = "Second Wind",
		type = "Progress",
		inDeck = true,
		effect = "all_draw",
		text = "Every player draws 1 card.",
	},
	{
		id = "hold_the_line",
		name = "Hold the Line",
		type = "Progress",
		inDeck = true,
		effect = "push_hollow_man",
		text = "Push the Hollow Man back 30 min.",
	},
	{
		id = "peek",
		name = "Peek",
		type = "Progress",
		inDeck = true,
		effect = "peek",
		text = "Look at the next 3 cards and put them back in any order.",
	},
	{ id = "long_night", name = "Long Night", type = "Progress", inDeck = true, effect = "none", text = "No side effect." },
	{
		id = "cold_draft",
		name = "Cold Draft",
		type = "Progress",
		inDeck = true,
		effect = "altar_wipe",
		text = "Altar Wipe: every Clue card on the Altar is gone.",
	},
	{
		id = "shaking_floor",
		name = "Shaking Floor",
		type = "Progress",
		inDeck = true,
		effect = "all_discard_random",
		text = "Every player discards 1 random card.",
	},
	{
		id = "swap",
		name = "Swap",
		type = "Progress",
		inDeck = true,
		effect = "swap_hands",
		text = "Trade your whole hand with another player's.",
	},

	-- Events: start the moment they're drawn (never go to a hand). Timers in Config.EventSeconds.
	{
		id = "fuse_box",
		name = "Fuse Box",
		type = "Event",
		inDeck = true,
		text = "The power dies. Find the fuse in a random built room and carry it back to the Parlor.",
	},
	{
		id = "the_knock",
		name = "The Knock",
		type = "Event",
		inDeck = true,
		text = "Something knocks at the front door. Every player must be hidden in a wardrobe or under a bed (or the Parlor table) when it opens.",
	},
	{
		id = "candlelight",
		name = "Candlelight",
		type = "Event",
		inDeck = true,
		text = "Light candles in 3 marked rooms before the last one burns out.",
	},
	{
		id = "he_walks",
		name = "He Walks",
		type = "Event",
		inDeck = true,
		text = "The Hollow Man enters the cabin in person and hunts. Stay out of his sight until he leaves.",
	},
	{
		id = "rising_water",
		name = "Rising Water",
		type = "Event",
		inDeck = true,
		text = "Water floods out from the Crawlspace. Get to the room farthest from it on the map.",
	},
	{
		id = "lockdown",
		name = "Lockdown",
		type = "Event",
		inDeck = true,
		text = "All doors slam shut. Find the key in your room to open your way back to the table.",
	},
	{
		id = "dont_look",
		name = "Don't Look Away",
		type = "Event",
		inDeck = true,
		text = "Something pale climbs out of the mirrors. It only moves when nobody is looking at it, and the lights keep failing. Cover the marked mirrors to send it back.",
	},
	{
		id = "hush",
		name = "Hush",
		type = "Event",
		inDeck = true,
		text = "A gramophone starts playing somewhere in the cabin. Move while the music plays; when it stops, freeze. Find it and lift the needle.",
	},

	-- Clues: played onto the Altar. If the top card is a true clue, its sign appears in the cabin.
	{
		id = "music_box",
		name = "Music Box",
		type = "Clue",
		inDeck = true,
		text = "A faint lullaby starts playing somewhere. Follow the sound to a small open music box.",
	},
	{
		id = "wet_footprints",
		name = "Wet Footprints",
		type = "Clue",
		inDeck = true,
		text = "Bare, wet footprints track across a floor and stop in the middle of a room.",
	},
	{
		id = "rocking_chair",
		name = "Rocking Chair",
		type = "Clue",
		inDeck = true,
		text = "An empty rocking chair rocks by itself in one room, creaking. Follow the sound.",
	},
	{
		id = "frost",
		name = "Frost",
		type = "Clue",
		inDeck = true,
		text = "One room's windows ice over and your breath fogs inside it.",
	},
	{
		id = "tally_marks",
		name = "Tally Marks",
		type = "Clue",
		inDeck = true,
		text = "Scratch marks appear in 3 rooms. An odd total means Odd Tally, an even total Even Tally.",
	},
	{
		id = "the_doll",
		name = "The Doll",
		type = "Clue",
		inDeck = true,
		text = "A cloth doll sits facing the wall. If it's a decoy, its smile turns to a frown once the third true clue is revealed.",
	},

	-- Red card: shuffled into the deck once the Bathroom is built (TurnController).
	{
		id = "attic",
		name = "The Attic",
		type = "Event",
		inDeck = false,
		red = true,
		text = "The hatch in the Bathroom ceiling drops open. 60 seconds to search the attic. Nobody can be eliminated. The ledger up there names one true clue.",
	},

	-- Not in the deck: the final escape at 3:00 AM runs as an event (EventRunner).
	{
		id = "final_escape",
		name = "The Final Escape",
		type = "Event",
		inDeck = false,
		text = "3:00 AM. Every built exit room's outside door unseals. Only one leads out, the rest are traps. The Hollow Man is in the Parlor.",
	},
}

local CardData = {}

CardData.DEFAULT_ROOM_COLOR = Color3.fromRGB(120, 104, 84)

for _, def in ROOMS do
	table.insert(CARDS, def)
end
for _, def in EXITS do
	table.insert(CARDS, def)
end

CardData.byId = {} :: { [string]: CardDef }
for _, def in CARDS do
	CardData.byId[def.id] = def
end

-- Half the inside size of a room (x, z) in world terms at this rotation. Rooms smaller than the
-- tile sit in its middle, with short passages out to their doorways.
function CardData.roomHalf(id: string, rotation: number): (number, number)
	local size = CardData.byId[id] and CardData.byId[id].size or Vector2.new(Config.TileSize, Config.TileSize)
	if rotation % 2 == 1 then
		return size.Y / 2, size.X / 2
	end
	return size.X / 2, size.Y / 2
end

function CardData.get(id: string): CardDef
	local def = CardData.byId[id]
	assert(def, `Unknown card id {id}`)
	return def
end

function CardData.all(): { CardDef }
	return CARDS
end

return CardData
