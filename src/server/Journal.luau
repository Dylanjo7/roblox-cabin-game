--!strict
-- The Journal, shared by the whole group. A clue is "discovered" when someone uses a sign's
-- "Record in Journal" prompt. The Journal also holds the group's marks on the 7 clue results
-- (found / ruled out, clicked on and off in the book; recording a sign marks it found) and the
-- exit rooms the group has crossed out.
-- Everything in it is public (the signs are in plain sight); it never knows the true exit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClueData = require(Shared:WaitForChild("ClueData"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local RunStats = require(script.Parent.RunStats)
local StateSync = require(script.Parent.StateSync)

local Journal = {}

local entries: { Types.JournalEntry } = {}
local recorded: { [string]: boolean } = {} -- sign keys already written down
local crossed: { [string]: boolean } = {}
local marks: { [string]: string } = {} -- clue result id -> "found" | "ruled_out"

function Journal.reset()
	entries = {}
	recorded = {}
	crossed = {}
	marks = {}
	StateSync.broadcast()
end

-- Write a sign into the Journal (once per sign).
function Journal.record(player: Player, key: string, entry: { clue: string, label: string, room: string, count: number? })
	if recorded[key] then
		Remotes.notify(player, "That's already in the Journal.")
		return
	end
	recorded[key] = true
	table.insert(entries, { clue = entry.clue, label = entry.label, room = entry.room, count = entry.count, by = player.DisplayName })
	RunStats.count(player, "clues")
	if ClueData.Results[entry.clue] and not marks[entry.clue] then
		marks[entry.clue] = "found"
	end
	for _, p in game:GetService("Players"):GetPlayers() do
		Remotes.notify(p, `{player.DisplayName} wrote "{entry.label}" ({entry.room}) in the Journal. Press M to read it.`)
	end
	StateSync.broadcast()
end

local function onToggleExit(_player: Player, exitId: any)
	if typeof(exitId) ~= "string" then
		return
	end
	for _, exit in ClueData.Exits do
		if exit.id == exitId then
			crossed[exitId] = not crossed[exitId] or nil
			StateSync.broadcast()
			return
		end
	end
end

-- Clicking a clue in the book: unknown -> found -> ruled out -> unknown.
local function onMarkClue(_player: Player, resultId: any)
	if typeof(resultId) ~= "string" or not ClueData.Results[resultId] then
		return
	end
	local now = marks[resultId]
	marks[resultId] = if now == nil then "found" elseif now == "found" then "ruled_out" else nil
	StateSync.broadcast()
end

function Journal.init()
	Remotes.event("RequestToggleExit").OnServerEvent:Connect(onToggleExit)
	Remotes.event("RequestMarkClue").OnServerEvent:Connect(onMarkClue)
	StateSync.register("journal", function(): Types.JournalPublic
		local out = {}
		for id in crossed do
			table.insert(out, id)
		end
		return { entries = entries, crossed = out, marks = marks }
	end)
end

return Journal
