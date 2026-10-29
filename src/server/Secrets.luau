--!strict
-- The run's secrets: the true exit room and its three true clues, picked at setup.
-- Server only. Nothing here is ever registered with StateSync or sent to a client; clients only
-- ever see clue signs appear in the world.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClueData = require(Shared:WaitForChild("ClueData"))
local Config = require(Shared:WaitForChild("Config"))

local Secrets = {}

local trueExit: ClueData.Exit? = nil
local trueClues: { [string]: boolean } = {}
local rng = Random.new()

function Secrets.pick()
	trueExit = ClueData.Exits[rng:NextInteger(1, #ClueData.Exits)]
	trueClues = {}
	for _, result in (trueExit :: ClueData.Exit).clues do
		trueClues[result] = true
	end
end

function Secrets.trueExit(): ClueData.Exit?
	return trueExit
end

function Secrets.isTrueClue(result: string): boolean
	return trueClues[result] == true
end

-- For a played Clue card: the true result it reveals, or nil if it isn't a true clue.
function Secrets.trueResultFor(cardId: string): string?
	if Config.Debug.AllCluesTrue then
		return ClueData.resultsFor(cardId)[1]
	end
	for _, result in ClueData.resultsFor(cardId) do
		if trueClues[result] then
			return result
		end
	end
	return nil
end

return Secrets
