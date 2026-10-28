--!strict
-- The group a truck brought from the lobby place. The lobby reserves a private server of this
-- place and teleports its party here with { party = { userIds }, difficulty = id } as teleport
-- data, so the run waits for the whole party (not just whoever has loaded so far), is played at
-- the truck's difficulty, and sends everyone back to the lobby when it's over. On a normal
-- server (Studio, or someone joining directly) there is no party and the cabin's own
-- seat-to-start lobby is used as is.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Places = require(Shared:WaitForChild("Places"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Party = {}

local expected: { [number]: boolean } = {}
local expectedCount = 0
local difficulty: string? = nil

-- This server was reserved by the lobby (not a public or Studio server).
function Party.isReserved(): boolean
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
end

-- How many players the lobby sent (0 when there's no party). Teleport data passes through the
-- client, so it's only trusted for this count, capped at the table's seats.
function Party.expectedCount(): number
	return math.min(expectedCount, Config.MaxPlayers)
end

-- The difficulty the truck was set to (the first one anyone arrives with), if there was a truck.
-- Like the count, it's only the party's own night it changes.
function Party.difficulty(): string?
	return difficulty
end

local function readJoinData(player: Player)
	local ok, data = pcall(function()
		return player:GetJoinData().TeleportData
	end)
	if not ok or typeof(data) ~= "table" then
		return
	end
	if difficulty == nil and typeof(data.difficulty) == "string" and Config.Difficulty.Levels[data.difficulty] then
		difficulty = data.difficulty
	end
	if typeof(data.party) ~= "table" then
		return
	end
	for _, userId in data.party do
		if typeof(userId) == "number" and not expected[userId] then
			expected[userId] = true
			expectedCount += 1
		end
	end
end

-- After a run: back to the lobby place. Returns false if that isn't possible (not a reserved
-- server, no lobby place found, Studio, or the teleport failed), so the cabin's own lobby runs.
function Party.returnToLobby(): boolean
	if not Party.isReserved() or RunService:IsStudio() then
		return false
	end
	local lobbyId = Places.lobby()
	if lobbyId == 0 then
		return false
	end
	local players = Players:GetPlayers()
	if #players == 0 then
		return true
	end
	for _, player in players do
		Remotes.notify(player, "Back to the ranger station...")
	end
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(lobbyId, players)
	end)
	if not ok then
		warn(`Hollow Pines: teleport back to the lobby failed: {err}`)
	end
	return ok
end

function Party.init()
	if not Party.isReserved() then
		return
	end
	for _, player in Players:GetPlayers() do
		readJoinData(player)
	end
	Players.PlayerAdded:Connect(readJoinData)
end

return Party
