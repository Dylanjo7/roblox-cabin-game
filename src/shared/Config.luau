--!strict
-- Every tunable number in Hollow Pines lives here. Rebalance from this file only.

local Config = {
	-- World
	TileSize = 40, -- studs per map cell; every room is TileSize x TileSize
	ParlorOrigin = Vector3.new(0, 0.5, 0), -- floor-top centre of the Parlor; cell (x, z) = origin + (x*TileSize, 0, z*TileSize)
	GridMin = -6, -- map bounds (inclusive) on both axes
	GridMax = 6,

	-- Placeholder room geometry
	Room = {
		FloorThickness = 1,
		WallHeight = 16, -- the ceiling sits on top; the board camera stays below it
		LampRange = 30,
		LampBrightness = 0.9,
		WallThickness = 1,
		DoorWidth = 8,
		DoorHeight = 9,
	},

	-- Clock track: 9:00 PM to 3:00 AM in 30-minute steps. Positions are step indexes 0..Steps.
	Clock = {
		StartMinutes = 21 * 60, -- step 0 = 9:00 PM
		StepMinutes = 30,
		Steps = 12, -- step 12 = 3:00 AM
		MidnightStep = 6,
	},

	HollowMan = {
		TurnsPerMove = 4, -- he moves once every this many turns, whatever the player count (4 players = once a round; solo = every 4th turn)
		EntryStep = 0, -- his first move puts him on the track at 9:00 PM
		StepsPerRound = 1, -- then +30 min per move
		StepsPerRoundFromMidnight = 2, -- +60 min per move once he is at or past midnight
		DeckOutExtraSteps = 2, -- one-time +60 min when the deck runs out
		MinStep = 0, -- Hold the Line can't push him below 9:00 PM
	},

	HandSize = 3, -- cards dealt to each player at setup
	NoValidSpotPenaltySteps = 1, -- +30 min when a selected room has nowhere valid to go
	PeekCount = 3,

	GameOverSeconds = 8, -- how long the result shows before the table returns to the lobby
	MaxPlayers = 4, -- also set the cabin place's Max Players to 4 on the Creator Dashboard
	LobbyStartSeconds = 20, -- once someone sits, the run starts when everyone has, or after this
	SwapChooseSeconds = 15, -- time to pick who to swap hands with (then the next player is picked)

	-- Which card types go into the shuffled deck.
	DeckTypes = {
		Room = true,
		Progress = true,
		Clue = true,
		Exit = false,
		Event = true,
	} :: { [string]: boolean },

	-- Clock steps each Progress card moves the Candle (1 step = 30 min)
	ProgressSteps = {
		steady_hands = 1,
		second_wind = 1,
		hold_the_line = 1,
		peek = 1,
		long_night = 2,
		cold_draft = 2,
		shaking_floor = 2,
		swap = 2,
	} :: { [string]: number },
	HoldTheLinePushSteps = 1,

	-- Copies of each card in the shuffled deck (the Crawlspace is set aside, not shuffled in)
	CardCopies = {
		-- Rooms: one of each (21, same door-shape mix as RULES.md's 6/6/4/2/3)
		front_hall = 1,
		back_hall = 1,
		gallery = 1,
		pantry = 1,
		stair_hall = 1,
		sun_porch = 1,
		kitchen = 1,
		dining_room = 1,
		living_room = 1,
		laundry_room = 1,
		sewing_room = 1,
		library = 1,
		den = 1,
		sitting_room = 1,
		music_room = 1,
		game_room = 1,
		grand_hall = 1,
		foyer = 1,
		bathroom = 1,
		bedroom = 1,
		linen_closet = 1,
		-- Exit rooms: one of each.
		boathouse = 1,
		root_cellar = 1,
		greenhouse = 1,
		study = 1,
		chapel = 1,
		workshop = 1,
		nursery = 1,
		mudroom = 1,
		steady_hands = 3,
		long_night = 3,
		second_wind = 2,
		hold_the_line = 2,
		peek = 2,
		cold_draft = 1,
		shaking_floor = 1,
		swap = 1,
		-- Events: 1 each per RULES.md.
		fuse_box = 1,
		candlelight = 1,
		rising_water = 1,
		the_knock = 1,
		lockdown = 1,
		he_walks = 1,
		-- Clues: 2 each per RULES.md.
		music_box = 2,
		wet_footprints = 2,
		wrong_reflection = 2,
		frost = 2,
		tally_marks = 2,
		the_doll = 2,
	} :: { [string]: number },
	-- Not in the deck yet
	ExitCopiesEach = 1,

	EventSeconds = {
		fuse_box = 75,
		the_knock = 45,
		candlelight = 90,
		he_walks = 60,
		rising_water = 50,
		lockdown = 60,
		final_escape = 90,
		attic = 60,
	} :: { [string]: number },
	EliminationPenaltySteps = 2, -- +60 min per eliminated player
	Events = {
		ResultSeconds = 3, -- pause on the result before everyone returns to their seats
		ItemSpread = 12, -- event items spawn up to this many studs from a room's centre
		PromptDistance = 8,
		PlayerLightRange = 16, -- light each player carries while the power is out
		DarkClockTime = 0,
		DarkBrightness = 0,
		CandleRooms = 3, -- Candlelight marks this many rooms
		CandleHeight = 2,
		TallyMin = 1, -- Tally Marks: scratches per room
		TallyMax = 5,
		SignPromptDistance = 9,
		WaterMaxDepth = 4, -- how deep a flooded room gets
		WaterUpdateSeconds = 0.2,
		KnockMinSeconds = 5, -- The Knock: gap between knocks at the front door
		KnockMaxSeconds = 9,
		HeWalks = {
			WalkSpeed = 9, -- studs per second while searching
			ChaseSpeed = 13, -- while he can see someone
			ViewDistance = 70,
			ViewAngle = 60, -- degrees either side of where he's facing
			CatchSeconds = 1.2, -- in his sight this long and you're caught
			GrabDistance = 4, -- or this close while he sees you
			GraceSeconds = 5, -- he can't catch anyone for this long after he appears
			HuntChance = 0.65, -- at each room, chance he heads towards the nearest player instead of wandering
			EyeHeight = 10,
			StepSeconds = 0.65, -- footstep sound interval
		},
	},
	FinalEscapeSeconds = 90,

	-- Parlor table (placeholder geometry)
	Table = {
		Radius = 8.2, -- outer edge of the rotating ring
		CenterRadius = 5.6, -- fixed centre disk that holds the cabin map
		TopHeight = 3, -- top of the ring
		CenterRaise = 0.06, -- the centre disk sits this much above the ring
		SeatRadius = 10.2,
		ChairScale = 1.15, -- your chair model (ServerStorage.TableChair) is scaled by this
		ChairSeatHeight = 0.53, -- where its seat is, as a fraction of its height
		SeatCount = 4,
		SeatCooldownSeconds = 1.5, -- a seat ignores touches this long after someone stands up
		RotateSeconds = 1.2,
		StandRadius = 6.2, -- the card stand rides the ring right in front of the active seat
		-- The cabin map zooms to fit what's built (plus a ring of cells around it) inside the
		-- centre disk: tiles are big while the cabin is small, never bigger than MapMaxCellSize.
		MapMaxCellSize = 1.4,
		MapMargin = 1, -- empty cells shown around the built cabin
		TrackArcDegrees = 300, -- the clock track's 13 marks spread over this arc of the ring
		NumeralRadius = 6.95, -- hour numerals engraved on the ring
		MarkRadius = 7.6, -- the clock track's marks
		CandleTrackRadius = 7.6,
		HollowTrackRadius = 7.95,
		FigurineScale = 0.12, -- the Hollow Man's piece is the full figure at this scale
		PlayedCardRadius = 6.2, -- played cards lie face up on the ring at this radius
		PlayedCardSlots = 26, -- cards per lap around the ring; later cards stack on top
		PlayedCardGapDegrees = 30, -- keep this far either side of the stand clear
		CardFlySeconds = 0.6,
		-- The pieces ride on sticks from two wheels inside the table; each wheel turns one ratchet
		-- step at a time (the next turn waits for the Hollow Man's wheel to finish).
		CandleStepSeconds = 0.5,
		HollowStepSeconds = 0.7,
		PieceRaise = 0.35, -- how high the sticks hold the pieces above the ring
	},

	-- Board camera while placing a room (heights are studs above the table top)
	Board = {
		CameraHeight = 6.5,
		MinHeight = 3,
		MaxHeight = 12, -- stays under the Parlor ceiling
		ZoomStep = 1.2,
		CameraSmoothing = 0.2, -- 0..1 per frame; higher snaps faster
	},

	UI = {
		ToastSeconds = 3,
		IntroLineSeconds = 4.5,
		EndingLineSeconds = 4,
	},

	-- The two places of the experience (fill in from the Creator Dashboard once both are published).
	-- 0 = not published yet: the lobby can't send trucks and the cabin stays on its own lobby.
	Places = {
		LobbyPlaceId = 0, -- the ranger station (the experience's start place)
		GamePlaceId = 0, -- the cabin
	},

	-- The ranger station lobby place.
	Lobby = {
		Trucks = 2, -- each truck takes one group of 1 to MaxPlayers
		DepartSeconds = 15, -- once someone climbs on, the truck leaves after this (or as soon as it's full)
		TeleportRetries = 1, -- a failed teleport is tried again this many times per player
		ClockTime = 19.6, -- dusk
	},

	-- Testing switches. Leave off for real games.
	Debug = {
		AllCluesTrue = false, -- every Clue card counts as true (see every sign appear)
	},

	-- Night in the pines (set on the server at boot; Fuse Box darkens from here and restores it)
	Mood = {
		ClockTime = 0.5,
		Brightness = 0.6,
		Ambient = Color3.fromRGB(36, 34, 44),
		OutdoorAmbient = Color3.fromRGB(26, 28, 36),
		FogColor = Color3.fromRGB(12, 14, 18),
	},

	-- Everyone's lantern (key 1 to hold it up).
	Lantern = {
		Range = 18,
		Brightness = 1.3,
	},

	-- The basement under the Crawlspace, where eliminated players wait out an event.
	Basement = {
		Depth = 60, -- studs below the cabin floor (clear of the ground)
		HalfSize = 12, -- the room is 24 x 24
		Height = 14,
	},

	-- The front door: in the Parlor's south wall, beside (not in) the south doorway. X is the
	-- world offset of its centre from the Parlor's centre.
	FrontDoor = {
		X = -8,
		Width = 4,
		Height = 8,
		OpenDegrees = 100,
		SlamSeconds = 0.25,
	},

	-- Outside the cabin, for the walk up from the truck (removed once a room is built south of the Parlor).
	Outside = {
		Siding = Color3.fromRGB(52, 64, 80), -- weathered clapboard
		Trim = Color3.fromRGB(206, 200, 186), -- painted white, peeling
		Roof = Color3.fromRGB(40, 38, 40),
		PathLength = 54, -- from the porch steps to the truck
	},

	-- The pines outside: trees fill empty map cells within Radius cells of the cabin and are
	-- cleared when a room is built there.
	Forest = {
		Radius = 2,
		TreesPerCell = 4,
		MinHeight = 26,
		MaxHeight = 46,
		Ground = Color3.fromRGB(30, 34, 26),
	},

	-- Dread. Lists are indexed by level 1..5.
	-- FogEnd, CreakPerSecond, GlimpseSeconds and WindowGlimpseSeconds follow the gap between the
	-- Candle and the Hollow Man on the clock (1 calm, 2 uneasy, 3 near, 4 close, 5 caught).
	-- AmbienceVolume, DroneVolume, HeartbeatVolume, FlickerPerSecond and Tint follow where he
	-- physically is: SameRoomLevel when he's in your room, NextRoomLevel one room away, else 1.
	-- Level 1 is normal: set AmbienceVolume[1] to 0 for silence when he's not around.
	Dread = {
		SameRoomLevel = 5,
		NextRoomLevel = 4,
		UneasyGap = 3, -- 90 min
		NearGap = 2, -- 60 min
		CloseGap = 1, -- 30 min
		FogEnd = { 220, 150, 100, 70, 45 },
		AmbienceVolume = { 0.25, 0.35, 0.45, 0.5, 0.35 },
		DroneVolume = { 0, 0, 0.15, 0.3, 0.45 },
		HeartbeatVolume = { 0, 0, 0, 0.35, 0.7 },
		FlickerPerSecond = { 0, 0.02, 0.12, 0.3, 0.5 }, -- chance per second that the lights flicker
		CreakPerSecond = { 0.01, 0.03, 0.05, 0.07, 0.05 },
		GlimpseSeconds = { 0, 0, 0, 16, 0 }, -- average gap between glimpses of him (0 = none)
		GlimpseShowSeconds = 1.2,
		WindowGlimpseSeconds = { 0, 40, 25, 15, 0 }, -- him standing in the trees outside a window you're facing
		WindowGlimpseShowSeconds = 3,
		WindowGlimpseRange = 30, -- you have to be this close to the window
		WindowGlimpseDistance = { 26, 40 }, -- how far out among the trees he stands
		GlimpseMinDistance = 25,
		GlimpseMaxDistance = 90,
		Tint = { 0, 0, 0, 0.1, 0.35 }, -- red tint strength
		StepShake = 0.35, -- camera shake (studs) when he moves on the clock
	},

	-- Roblox library audio (Pro Sound Effects, APM Music and DistroKid tracks licensed for Roblox).
	Sounds = {
		ambience = "rbxassetid://9112775624", -- Eerie Presence 3, loop
		drone = "rbxassetid://126189820698933", -- Doomsday Drone Soundscape, loop
		heartbeat = "rbxassetid://9043365842", -- Heartbeat 02 96BPM, loop
		step = "rbxassetid://9114036511", -- Deep Impacts 7
		creak = "rbxassetid://9126282474", -- Wood Strain Stress Creaking
		whisper = "rbxassetid://9126213995", -- Whisper Bursts Eerie
		caught = "rbxassetid://9039981895", -- Hellish (sting)
		ending = "rbxassetid://1846887425", -- Evil Mind 9 (sting)
		flicker = "rbxassetid://9116279560", -- Quick Electrical Burst
		card = "rbxassetid://9118835414", -- Scrapbook Turn Pages
		flood = "rbxassetid://9114492638", -- Flood Massive Flowing Water, loop
		knock = "rbxassetid://9114141162", -- Door Knock 6 (for The Knock)
		lullaby = "rbxassetid://9047785119", -- Music Box Lullaby (APM), the Music Box clue
		ratchet = "rbxassetid://9118047781", -- Ratchet Wrench Gear Winding 3: a piece moving on the clock
		tick = "rbxasset://sounds/clickfast.wav", -- built-in click, pitched down as the clocks' tick (swap for a library tick if you find a better one)
	} :: { [string]: string },
}

return Config
