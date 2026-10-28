--!strict
-- Tonight's difficulty (Config.Difficulty): picked on the truck in the lobby and sent with the
-- party (see Party), or Config.Difficulty.Default on a server the lobby didn't reserve (Studio,
-- or someone joining directly). Whatever changes with it reads Difficulty.get(). Public, so the
-- Journal and the scares can use it too.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Party = require(script.Parent.Party)
local StateSync = require(script.Parent.StateSync)

local Difficulty = {}

function Difficulty.id(): string
	local picked = Party.difficulty()
	if picked and Config.Difficulty.Levels[picked] then
		return picked
	end
	return Config.Difficulty.Default
end

function Difficulty.get()
	return Config.Difficulty.Levels[Difficulty.id()]
end

-- An event's timer at this difficulty (the final escape's never changes).
function Difficulty.eventSeconds(id: string): number
	local seconds = Config.EventSeconds[id]
	if id == "final_escape" then
		return seconds
	end
	return math.floor(seconds * Difficulty.get().eventTime + 0.5)
end

function Difficulty.init()
	StateSync.register("difficulty", function()
		local level = Difficulty.get()
		return { id = Difficulty.id(), name = level.name, turnsPerMove = level.turnsPerMove, scareGap = level.scareGap }
	end)
end

return Difficulty
