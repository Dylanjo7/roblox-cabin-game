--!strict
-- Server boot: creates remotes, builds the Parlor and its table, and drives Lobby -> Setup -> TurnLoop.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- An edit-mode preview left in the place (see Preview) is replaced by the real thing.
for _, container in { workspace, ServerStorage } do
	for _, child in (container :: Instance):GetChildren() do
		if child:GetAttribute("EditPreview") then
			child:Destroy()
		end
	end
end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClockUtil = require(Shared:WaitForChild("ClockUtil"))
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
Remotes.init()

local Altar = require(script.Parent.Altar)
local Arrival = require(script.Parent.Arrival)
local Badges = require(script.Parent.Badges)
local Basement = require(script.Parent.Basement)
local CardEffects = require(script.Parent.CardEffects)
local ClueSigns = require(script.Parent.ClueSigns)
local Journal = require(script.Parent.Journal)
local Lanterns = require(script.Parent.Lanterns)
local Clock = require(script.Parent.Clock)
local Difficulty = require(script.Parent.Difficulty)
local EventRunner = require(script.Parent.EventRunner)
local FinalEscape = require(script.Parent.Events.FinalEscape)
local Forest = require(script.Parent.Forest)
local GameState = require(script.Parent.GameState)
local Hands = require(script.Parent.Hands)
local MapGrid = require(script.Parent.MapGrid)
local Notes = require(script.Parent.Notes)
local Party = require(script.Parent.Party)
local RunStats = require(script.Parent.RunStats)
local Secrets = require(script.Parent.Secrets)
local Setup = require(script.Parent.Setup)
local Shop = require(script.Parent.Shop)
local StateSync = require(script.Parent.StateSync)
local Table = require(script.Parent.Table)
local TableMap = require(script.Parent.TableMap)
local TurnController = require(script.Parent.TurnController)

-- Everyone plays in first person.
game:GetService("StarterPlayer").CameraMode = Enum.CameraMode.LockFirstPerson
for _, player in Players:GetPlayers() do
	player.CameraMode = Enum.CameraMode.LockFirstPerson
end
Players.PlayerAdded:Connect(function(player: Player)
	player.CameraMode = Enum.CameraMode.LockFirstPerson
end)

-- Night in the pines. (Fuse Box darkens from here and restores these values.)
local Lighting = game:GetService("Lighting")
Lighting.ClockTime = Config.Mood.ClockTime
Lighting.Brightness = Config.Mood.Brightness
Lighting.Ambient = Config.Mood.Ambient
Lighting.OutdoorAmbient = Config.Mood.OutdoorAmbient
Lighting.FogColor = Config.Mood.FogColor

Table.build()
TableMap.init()
Forest.init()
StateSync.init()
StateSync.register("phase", GameState.get)
StateSync.register("cabin", MapGrid.publicCells)
StateSync.register("result", GameState.getResult)
StateSync.register("summary", RunStats.public)
Clock.init()
Altar.init()
-- Keep the stack on the stand in step with the Altar (after a played clue has landed).
Altar.Changed:Connect(function(reason: string)
	local function redraw()
		local ids = {}
		for _, card in Altar.cards() do
			table.insert(ids, card.id)
		end
		Table.setAltar(ids)
	end
	if reason == "push" then
		task.delay(Config.Table.CardFlySeconds, redraw)
	else
		redraw()
	end
end)
Journal.init()
Notes.init()
ClueSigns.init()
CardEffects.init()
EventRunner.init()
TurnController.init()
Setup.resetCabin()
Party.init()
Difficulty.init()
Arrival.init() -- after the Parlor exists: porch, door, and the walk up from the truck
Basement.init() -- follows the Crawlspace wherever it is placed
Lanterns.init()
Shop.init()

GameState.Changed:Connect(function()
	StateSync.broadcast()
end)

local pendingPlayers: { Player } = {}

GameState.onEnter("Setup", function()
	-- Nobody starts a run with the front door still open (or a friend still out by the truck).
	Arrival.forceClose()
	Badges.awardAll(pendingPlayers, "FirstNight")
	Setup.run(pendingPlayers)
end)

GameState.onEnter("Lobby", function(from)
	EventRunner.abort()
	TurnController.reset()
	RunStats.clear()
	-- Out of the chairs, so the next run starts only when people sit down again.
	Table.standAll()
	if from == "GameOver" then
		-- Everyone back inside the Parlor: whoever escaped is outside by the truck (and the front
		-- door is locked for good), the caught are in the basement.
		for _, player in Players:GetPlayers() do
			task.spawn(function()
				player:LoadCharacter()
			end)
		end
	end
end)

-- 3:00 AM: the final escape. Win if anyone gets out through the true exit.
GameState.onEnter("FinalEscape", function()
	EventRunner.start("final_escape", TurnController.players(), function()
		if GameState.get() ~= "FinalEscape" then
			return
		end
		local exit = Secrets.trueExit()
		local exitName = if exit then exit.name else "true exit"
		local built = false
		for _, cell in MapGrid.all() do
			if exit and cell.id == exit.id then
				built = true
			end
		end
		local escaped = FinalEscape.escaped()
		local out = FinalEscape.escapedPlayers()
		Badges.awardAll(out, "Escaped")
		if #out > 0 and #out >= #TurnController.players() then
			Badges.awardAll(out, "AllOut")
		end
		if #escaped > 0 then
			GameState.endRun(true, `{table.concat(escaped, ", ")} got out through the {exitName}.`, "escaped")
		elseif not built then
			GameState.endRun(false, `The true exit, the {exitName}, was never built.`, "never_built")
		else
			GameState.endRun(false, `Nobody made it through the {exitName} in time.`, "lost")
		end
	end)
end)

GameState.onEnter("GameOver", function()
	local result = GameState.getResult()
	if result and not result.won then
		Badges.awardAll(TurnController.players(), "Caught")
	end
	-- The night in numbers, for everyone to see once the ending has played (and the way out,
	-- named at last).
	local exit = Secrets.trueExit()
	RunStats.finish({
		rounds = TurnController.round(),
		rooms = #MapGrid.all() - 1,
		notes = Notes.foundCount(),
		candle = ClockUtil.stepToText(Clock.candle()),
		trueExit = exit and exit.name,
		nextAt = workspace:GetServerTimeNow() + Config.GameOverSeconds,
		toStation = Party.isReserved(),
	})
	StateSync.broadcast()
	task.delay(Config.GameOverSeconds, function()
		if GameState.get() ~= "GameOver" then
			return
		end
		-- A party from the ranger station goes back there; otherwise the table resets for another run.
		if not Party.returnToLobby() then
			GameState.transition("Lobby")
			return
		end
		-- Anyone the teleport didn't take (it can fail after starting) gets the table back.
		task.delay(20, function()
			if GameState.get() == "GameOver" and #Players:GetPlayers() > 0 then
				GameState.transition("Lobby")
			end
		end)
	end)
end)

-- Starting a run: everyone in the server sits at the table (1-4 players). It starts as soon as
-- everyone is seated, or Config.LobbyStartSeconds after the first person sits, with whoever is
-- seated then. A party sent by the lobby place counts players still loading in, so it waits
-- for them (up to the countdown). Turn order goes round the table by seat.
local countdownToken = 0 -- bumped to cancel a pending start
local countdownRunning = false

local function seatedPlayers(): { Player }
	local seated = {}
	for _, player in Players:GetPlayers() do
		if Table.seatOf(player) then
			table.insert(seated, player)
		end
	end
	table.sort(seated, function(a: Player, b: Player)
		return (Table.seatOf(a) or 0) < (Table.seatOf(b) or 0)
	end)
	return seated
end

local function cancelStart()
	countdownToken += 1
	countdownRunning = false
end

local function startRun()
	cancelStart()
	if GameState.get() ~= "Lobby" then
		return
	end
	local seated = seatedPlayers()
	if #seated == 0 then
		return
	end
	pendingPlayers = seated
	GameState.transition("Setup")
end

-- Start startRun after `seconds` unless something cancels it first.
local function scheduleStart(seconds: number)
	local token = countdownToken
	task.delay(seconds, function()
		if countdownToken == token then
			startRun()
		end
	end)
end

local function checkLobby()
	if GameState.get() ~= "Lobby" then
		return
	end
	local seated = seatedPlayers()
	local everyone = math.min(math.max(#Players:GetPlayers(), Party.expectedCount()), Config.MaxPlayers)
	if #seated == 0 then
		cancelStart() -- everyone stood up again
		return
	end
	if #seated >= everyone then
		-- Everyone's down: start in a moment (standing up again in that moment cancels it).
		cancelStart()
		scheduleStart(1)
		return
	end
	if not countdownRunning then
		cancelStart()
		countdownRunning = true
		for _, player in Players:GetPlayers() do
			Remotes.notify(player, `{#seated} of {everyone} seated. The game starts when everyone sits down, or in {Config.LobbyStartSeconds} seconds.`)
		end
		scheduleStart(Config.LobbyStartSeconds)
	end
end

Table.SeatChanged:Connect(function()
	checkLobby()
end)
GameState.onEnter("Lobby", function()
	cancelStart() -- nothing left over from before
	task.defer(checkLobby)
end)

-- Joining while a run is going: you watch this one and play the next.
Players.PlayerAdded:Connect(function(player: Player)
	if GameState.get() ~= "Lobby" then
		task.delay(3, function()
			if player.Parent and not table.find(TurnController.players(), player) then
				Remotes.notify(player, "A run is already under way. You'll be dealt in to the next one.")
			end
		end)
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	Hands.remove(player)
	if GameState.get() == "Lobby" then
		task.defer(checkLobby)
	elseif table.find(TurnController.players(), player) then
		-- The run carries on without them; if nobody is left, back to the lobby.
		if not TurnController.removePlayer(player) then
			GameState.transition("Lobby")
		end
	end
end)
