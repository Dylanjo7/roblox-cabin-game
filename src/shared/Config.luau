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
		-- (How many turns between his moves depends on the difficulty: Difficulty.Levels.)
		EntryStep = 0, -- his first move puts him on the track at 9:00 PM
		StepsPerRound = 1, -- then +30 min per move
		StepsPerRoundFromMidnight = 2, -- +60 min per move once he is at or past midnight
		DeckOutExtraSteps = 2, -- one-time +60 min when the deck runs out
		MinStep = 0, -- Hold the Line can't push him below 9:00 PM
	},

	-- How hard the night is. Each truck in the lobby has one (Lobby.TruckDifficulty; whoever's on
	-- the truck can change it at the sign by its pad) and it's sent to the cabin with the party.
	-- A cabin server the lobby didn't send anyone to (Studio, or joining directly) uses Default.
	--   turnsPerMove: he moves once every this many turns, whatever the player count (4 = once
	--     a round with 4 players; solo, every 4th of your turns)
	--   handSize: cards dealt to each player at setup
	--   eventTime: event timers are multiplied by this (not the final escape)
	--   huntSpeed: how fast he (and the pale thing) moves in events, times this
	--   scareGap: the gap between jump scares, times this
	Difficulty = {
		Default = "normal",
		Order = { "normal", "hard", "nightmare" },
		Levels = {
			normal = { name = "Normal", turnsPerMove = 4, handSize = 3, eventTime = 1, huntSpeed = 1, scareGap = 1, blurb = "He moves once a round." },
			hard = { name = "Hard", turnsPerMove = 3, handSize = 3, eventTime = 0.85, huntSpeed = 1.12, scareGap = 0.75, blurb = "He moves more often. Events are shorter." },
			nightmare = { name = "Nightmare", turnsPerMove = 3, handSize = 2, eventTime = 0.75, huntSpeed = 1.25, scareGap = 0.5, blurb = "Fewer cards, less time, and he's faster." },
		} :: { [string]: { name: string, turnsPerMove: number, handSize: number, eventTime: number, huntSpeed: number, scareGap: number, blurb: string } },
	},
	NoValidSpotPenaltySteps = 1, -- +30 min when a selected room has nowhere valid to go
	PeekCount = 3,

	GameOverSeconds = 36, -- the ending's cutscene, then the night in numbers, before the table returns to the lobby
	MaxPlayers = 4, -- also set the cabin place's Max Players to 4 on the Creator Dashboard
	LobbyStartSeconds = 20, -- once someone sits, the run starts when everyone has, or after this
	SwapChooseSeconds = 15, -- time to pick who to swap hands with (then the next player is picked)
	-- With more than one player, nobody can hold the table up: if the player whose turn it is
	-- doesn't act, the game does it for them after this long (each step has its own wait), and
	-- anyone not in their chair when a turn should start is put back in it. Solo, it waits.
	Turn = {
		StartSeconds = 60, -- to press T (anyone still away from the table is brought back first)
		DrawSeconds = 40, -- to take a card (or a clue)
		PlaySeconds = 50, -- to pick a card to play
		PlaceSeconds = 60, -- to put a room down
		PeekSeconds = 40, -- to reorder a Peek
		WarnSeconds = 12, -- the countdown shows on screen for this long before
	},

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
	-- Tuned by simulating thousands of runs of these rules (TODO.md, section O): a run's deck is
	-- about 49 cards, so the true exit usually turns up before 3:00 AM.
	CardCopies = {
		-- Rooms: the pool. Each run uses RoomsPerRun of them, picked at random, so every room
		-- turns up but no two cabins are the same. Set one to 0 to take it out.
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
		bathroom = 1, -- unlocks the Attic
		bedroom = 1,
		linen_closet = 1,
		-- Exit rooms: one of each, every run.
		boathouse = 1,
		root_cellar = 1,
		greenhouse = 1,
		study = 1,
		chapel = 1,
		workshop = 1,
		nursery = 1,
		mudroom = 1,
		-- Progress: 15 cards, 22 steps (the Candle needs 12, plus whatever he gains).
		steady_hands = 3,
		long_night = 4,
		second_wind = 2,
		hold_the_line = 2,
		peek = 1,
		cold_draft = 1,
		shaking_floor = 1,
		swap = 1,
		-- Events: the pool. Each run uses EventsPerRun of them, picked at random.
		fuse_box = 1,
		candlelight = 1,
		rising_water = 1,
		the_knock = 1,
		lockdown = 1,
		he_walks = 1,
		dont_look = 1,
		hush = 1,
		-- Clues: 2 each (12). Every true clue's sign now shows (signs only go in built rooms), so
		-- these show more than 3 each did before.
		music_box = 2,
		wet_footprints = 2,
		rocking_chair = 2,
		frost = 2,
		tally_marks = 2,
		the_doll = 2,
	} :: { [string]: number },
	-- Rooms in a run, by how many doorways they have (10 in all: 2 one-door, 5 two-door, 2
	-- three-door, 1 four-door). Picked from the rooms above at random each run.
	RoomsPerRun = { [1] = 2, [2] = 5, [3] = 2, [4] = 1 } :: { [number]: number },
	EventsPerRun = 6, -- events in a run, picked at random from the ones above
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
		dont_look = 75,
		hush = 70,
	} :: { [string]: number },
	-- Each player caught in an event lets the Hollow Man gain this many steps (30 min each) on the
	-- Candle, up to EliminationMaxStepsPerEvent from any one event (with 4 players, a failed
	-- group task used to cost 2 hours). The Candle itself never moves for events: only cards.
	EliminationHollowSteps = 1,
	EliminationMaxStepsPerEvent = 2,
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
		-- Don't Look Away: the pale thing only moves while nobody in play is looking at it.
		DontLook = {
			Mirrors = 3, -- standing mirrors to cover (fewer if fewer rooms are built)
			CoverSeconds = 1.2, -- hold to throw the sheet over one
			Speed = 15, -- studs per second while nobody's looking
			ViewDistance = 90,
			ViewAngle = 45, -- degrees either side of where you face that count as looking at it
			CatchDistance = 3.2,
			GraceSeconds = 6, -- it doesn't move at all for this long after it appears
			BlinkMinSeconds = 8, -- the lights fail for a blink this often...
			BlinkMaxSeconds = 13,
			BlinkSeconds = 0.5, -- ...for this long (each screen goes black)
			BlinkLeadSeconds = 0.15, -- it moves this long after the dark starts
			BlinkStep = 8, -- how far it gets in the dark
			BlinkStopDistance = 4.5, -- a blink never leaves it closer than this to you
		},
		-- Hush: move while the gramophone plays, freeze when it stops.
		Hush = {
			FirstPlaySeconds = 9,
			PlayMinSeconds = 5,
			PlayMaxSeconds = 9,
			QuietMinSeconds = 3.5,
			QuietMaxSeconds = 5.5,
			ReactSeconds = 0.8, -- after the music stops, moving doesn't count for this long
			MoveTolerance = 1.2, -- studs you can drift in the silence (turning round is fine)
			JumpTolerance = 1.5,
			StopSeconds = 0.8, -- hold to lift the needle
			HintSeconds = 25, -- then everyone's told which room the music is in
			Volume = 1,
			PlaybackSpeed = 0.82, -- slowed, like an old record
			HearDistance = 150,
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

	-- The two places of the experience. Leave these 0: once the cabin is published as the
	-- experience's second place, the lobby and the cabin find each other (shared/Places). Only
	-- fill them in if the experience ever has more than two places.
	Places = {
		LobbyPlaceId = 0, -- the ranger station (the experience's start place)
		GamePlaceId = 0, -- the cabin
	},

	-- The ranger station lobby place.
	Lobby = {
		Trucks = 5, -- each truck is its own lobby: one group of 1 to MaxPlayers, sent to its own cabin server
		TruckDifficulty = { "normal", "normal", "hard", "hard", "nightmare" }, -- each truck's to start with (Difficulty.Order)
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

	-- Jump scares (client/Scares): rare, never at the table, only once he's on the clock.
	Scares = {
		MinGapSeconds = 55, -- at least this long between any two scares
		BehindYouChance = 0.35, -- each time you spin round quickly
		BehindYouShowSeconds = 0.45,
		CornerChance = 0.14, -- each time you walk into another room
		CornerWaitSeconds = 10, -- he waits in the corner this long for you to notice him
		FaceSeconds = 0.55, -- his face when you're caught in an event
		JournalChance = 0.25, -- opening the Journal once he's at 11 PM or later on the clock
		JournalFromStep = 4, -- 11 PM
		WindowBangChance = 0.06, -- each half second you're close to a window and facing it
		RunnerChance = 0.03, -- each half second an open doorway is in view a little way off
		EmptyChairChance = 0.3, -- each time you look at an empty chair while you're at the table
		WhisperPerSecond = 0.004, -- someone whispers your name (about every 4 minutes of walking)
		KnockPerSecond = 0.006, -- knocks in the walls (not a scare slot; they just happen)
	},

	-- Badges (Creator Dashboard > your experience > Engagement > Badges). Paste each badge's id;
	-- 0 = that badge is off.
	Badges = {
		FirstNight = 0, -- sat down for your first run
		Escaped = 0, -- got out through the true exit
		AllOut = 0, -- everyone in the run got out
		Caught = 0, -- a run ended with him winning
	} :: { [string]: number },

	-- Recorded voice lines (see VOICE_LINES.md for the script). Upload each clip to Roblox as
	-- audio, then paste its id here ("rbxassetid://123456" or just the number). An empty one is
	-- silent: the line still shows as text.
	VoiceVolume = 1,
	Voice = {
		-- The drive up (Story.Trip)
		trip_1 = "",
		trip_2 = "",
		trip_3 = "", -- the radio: played through a radio filter
		trip_4 = "",
		trip_5 = "",
		trip_6 = "",
		-- Arriving by the dead truck (Story.ArrivalAfterTrip)
		arrival_1 = "",
		arrival_2 = "",
		-- Inside, when the door slams (Story.Intro)
		intro_1 = "",
		intro_2 = "",
		intro_3 = "",
		intro_4 = "",
		-- When he moves on the clock (Story.Beats)
		beat_enters = "",
		beat_moves = "",
		beat_midnight = "",
		beat_caught = "",
		beat_pushedBack = "",
		beat_three = "", -- 3:00 AM, as the final escape begins
		-- Endings (Story.Endings)
		ending_caught_1 = "",
		ending_caught_2 = "",
		ending_escaped_1 = "",
		ending_escaped_2 = "",
		ending_escaped_3 = "",
		ending_lost_1 = "",
		ending_lost_2 = "",
		ending_never_built_1 = "",
		ending_never_built_2 = "",
		-- The old driver in the ranger station (Story.Driver), heard from where he sits
		driver_1 = "",
		driver_2 = "",
		driver_3 = "",
		driver_4 = "",
		driver_5 = "",
		driver_6 = "",
		driver_7 = "",
		driver_8 = "",
		driver_9 = "",
	} :: { [string]: string },

	-- Mid-game cutscenes: how long the table (or the final escape) waits for them (client/Scenes).
	Cinematics = {
		EnterSeconds = 7.5, -- he comes onto the clock
		MidnightSeconds = 6.5, -- he reaches midnight
		LastTurnSeconds = 9, -- he catches the Candle: knocks at the front door
		ThreeSeconds = 10, -- 3:00 AM: the final escape holds off this long for its cutscene
		ThreeUnsealAt = 3.6, -- the exit doors' boards fall this far into it
	},

	-- Robux items. Make them on the Creator Dashboard (your experience > Monetization) and put
	-- their ids here; 0 = not set up yet (the item says so instead of opening a purchase).
	-- Cosmetic and pranks only: nothing you can buy helps you escape.
	Shop = {
		LanternColoursPass = 0, -- game pass: change your lantern's flame
		ScareProduct = 0, -- developer product: the Hollow Man's face on a friend's screen
		OfferingProduct = 0, -- developer product: light a memorial candle with your name at the ranger station
		LanternColours = {
			{ id = "ember", name = "Ember", color = Color3.fromRGB(255, 170, 70), free = true },
			{ id = "witchfire", name = "Witchfire", color = Color3.fromRGB(90, 255, 120), free = false },
			{ id = "cold", name = "Cold Light", color = Color3.fromRGB(120, 180, 255), free = false },
			{ id = "blood", name = "Blood Moon", color = Color3.fromRGB(255, 50, 40), free = false },
		},
		ScareRevealSeconds = 2, -- how long before the scared player is told who paid for it
	},

	-- Notes from the missing four (Story.Notes): each newly built room (not the Parlor or the
	-- Crawlspace) has this chance of holding the next one, until they've all been placed.
	Notes = {
		ChancePerRoom = 0.55,
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

	-- The walk up from the truck: once anyone is inside, the rest have this long before they're
	-- brought in and the door slams anyway.
	Arrival = {
		WaitSeconds = 45,
	},

	-- Lightning over the pines (client/Storm): seconds between flashes, sooner as he closes in.
	Storm = {
		Gap = { 45, 95 }, -- before he's on the clock
		GapHunting = { 25, 60 }, -- once he's on the track
		GapOverhead = { 10, 25 }, -- the last turn, and three o'clock
		WindowRange = 90, -- windows this close to you light up
		MaxWindows = 6,
		WindowBrightness = 7,
		ScreenFlash = 0.22, -- how much the picture brightens at the peak (in a room with a window)
		ThunderDelay = { 0.8, 3.2 }, -- seconds from the flash to the thunder
		ThunderVolume = 0.7,
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
		thunder = "rbxassetid://9114036511", -- Deep Impacts 7 again, slowed right down and muffled (client/Storm); swap for a library thunder clap if you find one
	} :: { [string]: string },
}

return Config
