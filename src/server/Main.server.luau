--!strict
-- Server boot: creates remotes, builds the Parlor and its table, and drives Lobby -> Setup -> TurnLoop.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
Remotes.init()

local Altar = require(script.Parent.Altar)
local Arrival = require(script.Parent.Arrival)
local Basement = require(script.Parent.Basement)
local CardEffects = require(script.Parent.CardEffects)
local ClueSigns = require(script.Parent.ClueSigns)
local Journal = require(script.Parent.Journal)
local Clock = require(script.Parent.Clock)
local EventRunner = require(script.Parent.EventRunner)
local FinalEscape = require(script.Parent.Events.FinalEscape)
local Forest = require(script.Parent.Forest)
local GameState = require(script.Parent.GameState)
local Hands = require(script.Parent.Hands)
local MapGrid = require(script.Parent.MapGrid)
local Secrets = require(script.Parent.Secrets)
local Setup = require(script.Parent.Setup)
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
ClueSigns.init()
CardEffects.init()
EventRunner.init()
TurnController.init()
Setup.resetCabin()
Arrival.init() -- after the Parlor exists: porch, door, and the walk up from the truck
Basement.init() -- follows the Crawlspace wherever it is placed

GameState.Changed:Connect(function()
	StateSync.broadcast()
end)

local pendingPlayers: { Player } = {}

GameState.onEnter("Setup", function()
	Setup.run(pendingPlayers)
end)

GameState.onEnter("Lobby", function()
	EventRunner.abort()
	TurnController.reset()
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
	task.delay(Config.GameOverSeconds, function()
		if GameState.get() == "GameOver" then
			GameState.transition("Lobby")
		end
	end)
end)

-- Starting a run: everyone in the server sits at the table (1-4 players). It starts as soon as
-- everyone is seated, or Config.LobbyStartSeconds after the first person sits, with whoever is
-- seated then. Turn order goes round the table by seat.
local countdownToken = 0

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

local function startRun()
	countdownToken += 1
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

local function checkLobby()
	if GameState.get() ~= "Lobby" then
		return
	end
	local seated = seatedPlayers()
	local everyone = #Players:GetPlayers()
	if #seated == 0 then
		countdownToken += 1 -- everyone stood up again
		return
	end
	if #seated >= everyone or #seated >= Config.MaxPlayers then
		task.delay(1, startRun)
		return
	end
	if countdownToken % 2 == 0 then
		-- Start the countdown (odd token = running).
		countdownToken += 1
		local token = countdownToken
		for _, player in Players:GetPlayers() do
			Remotes.notify(player, `{#seated} of {everyone} seated. The game starts when everyone sits down, or in {Config.LobbyStartSeconds} seconds.`)
		end
		task.delay(Config.LobbyStartSeconds, function()
			if countdownToken == token then
				startRun()
			end
		end)
	end
end

Table.SeatChanged:Connect(function()
	checkLobby()
end)
GameState.onEnter("Lobby", function()
	countdownToken += countdownToken % 2 -- stop any countdown left from before
	task.defer(checkLobby)
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
