--!strict
-- The group a truck brought from the lobby place. The lobby reserves a private server of this
-- place and teleports its party here with { party = { userIds } } as teleport data, so the run
-- waits for the whole party (not just whoever has loaded so far) and sends everyone back to the
-- lobby when it's over. On a normal server (Studio, or someone joining directly) there is no
-- party and the cabin's own seat-to-start lobby is used as is.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Party = {}

local expected: { [number]: boolean } = {}
local expectedCount = 0

-- This server was reserved by the lobby (not a public or Studio server).
function Party.isReserved(): boolean
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
end

-- How many players the lobby sent (0 when there's no party). Teleport data passes through the
-- client, so it's only trusted for this count, capped at the table's seats.
function Party.expectedCount(): number
	return math.min(expectedCount, Config.MaxPlayers)
end

local function readJoinData(player: Player)
	local ok, data = pcall(function()
		return player:GetJoinData().TeleportData
	end)
	if not ok or typeof(data) ~= "table" or typeof(data.party) ~= "table" then
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
-- server, no lobby place id set, Studio, or the teleport failed), so the cabin's own lobby runs.
function Party.returnToLobby(): boolean
	local lobbyId = Config.Places.LobbyPlaceId
	if not Party.isReserved() or lobbyId == 0 or RunService:IsStudio() then
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
