--!strict
-- The Journal, shared by the whole group. A clue is "discovered" when someone uses a sign's
-- "Record in Journal" prompt. The Journal also holds the exit rooms the group has crossed out.
-- Everything in it is public (the signs are in plain sight); it never knows the true exit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClueData = require(Shared:WaitForChild("ClueData"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local StateSync = require(script.Parent.StateSync)

local Journal = {}

local entries: { Types.JournalEntry } = {}
local recorded: { [string]: boolean } = {} -- sign keys already written down
local crossed: { [string]: boolean } = {}

function Journal.reset()
	entries = {}
	recorded = {}
	crossed = {}
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

function Journal.init()
	Remotes.event("RequestToggleExit").OnServerEvent:Connect(onToggleExit)
	StateSync.register("journal", function(): Types.JournalPublic
		local out = {}
		for id in crossed do
			table.insert(out, id)
		end
		return { entries = entries, crossed = out }
	end)
end

return Journal
