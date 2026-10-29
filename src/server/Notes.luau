--!strict
-- The notes the missing four left in the cabin (Story.Notes). As rooms are built, each new one
-- (not the Parlor or the Crawlspace) may hold the next note in the story, lying on clear floor.
-- Reading it ("Read" prompt) takes it: the reader sees it, everyone is told, and it goes into
-- the Journal's "Their notes" pages (public state "notes"). Reset for every run.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Story = require(Shared:WaitForChild("Story"))

local MapGrid = require(script.Parent.MapGrid)
local Spots = require(script.Parent.Spots)
local StateSync = require(script.Parent.StateSync)

local PAPER = Color3.fromRGB(214, 200, 168)
local INK = Color3.fromRGB(60, 46, 36)

local Notes = {}

local folder: Folder
local rng = Random.new()
local seen: { [string]: boolean } = {} -- rooms already given their chance
local nextNote = 1
local found: { number } = {}

-- A folded page lying on the floor, a corner weighed down with a stone.
local function placeNote(cell: MapGrid.Cell, index: number)
	local floor = Spots.clear(cell, rng, 0.9)
	local model = Instance.new("Model")
	model.Name = `Note{index}`
	local turn = CFrame.new(floor + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0)
	local page = Instance.new("Part")
	page.Name = "Page"
	page.Size = Vector3.new(1.1, 0.03, 1.45)
	page.CFrame = turn * CFrame.Angles(0, 0, math.rad(2))
	page.Color = PAPER
	page.Material = Enum.Material.Fabric
	page.Anchored = true
	page.CanCollide = false
	page.Parent = model
	for i = 0, 4 do
		local line = Instance.new("Part")
		line.Name = "Writing"
		line.Size = Vector3.new(0.8 - (i % 2) * 0.2, 0.005, 0.03)
		line.CFrame = page.CFrame * CFrame.new(-(i % 2) * 0.1, 0.018, -0.5 + i * 0.22)
		line.Color = INK
		line.Material = Enum.Material.SmoothPlastic
		line.Anchored = true
		line.CanCollide = false
		line.CanQuery = false
		line.Parent = model
	end
	local stone = Instance.new("Part")
	stone.Name = "Stone"
	stone.Shape = Enum.PartType.Ball
	stone.Size = Vector3.new(0.35, 0.35, 0.35)
	stone.CFrame = page.CFrame * CFrame.new(0.4, 0.12, 0.55)
	stone.Color = Color3.fromRGB(90, 88, 84)
	stone.Material = Enum.Material.Slate
	stone.Anchored = true
	stone.CanCollide = false
	stone.Parent = model

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Read"
	prompt.ObjectText = "A note"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = page
	prompt.Triggered:Connect(function(player: Player)
		if not model.Parent then
			return
		end
		model:Destroy()
		table.insert(found, index)
		Remotes.event("ShowNote"):FireClient(player, index)
		local note = Story.Notes[index]
		for _, p in Players:GetPlayers() do
			if p ~= player then
				Remotes.notify(p, `{player.DisplayName} found a note from {note.by}. It's in the Journal.`)
			end
		end
		StateSync.broadcast()
	end)
	model.Parent = folder
end

-- Give each newly built room its chance of holding the next note.
local function onMapChanged()
	for _, cell in MapGrid.all() do
		local k = MapGrid.key(cell.x, cell.z)
		if not seen[k] then
			seen[k] = true
			local eligible = cell.id ~= "parlor" and cell.id ~= "crawlspace" and cell.model ~= nil
			if eligible and nextNote <= #Story.Notes and rng:NextNumber() < Config.Notes.ChancePerRoom then
				-- After the room has finished building (and its furniture is in place).
				local index = nextNote
				nextNote += 1
				task.defer(placeNote, cell, index)
			end
		end
	end
end

function Notes.reset()
	folder:ClearAllChildren()
	seen = {}
	nextNote = 1
	found = {}
	StateSync.broadcast()
end

-- How many notes have been read this run.
function Notes.foundCount(): number
	return #found
end

function Notes.init()
	folder = Instance.new("Folder")
	folder.Name = "Notes"
	folder.Parent = workspace
	MapGrid.Changed:Connect(onMapChanged)
	StateSync.register("notes", function(): { number }
		return found
	end)
end

return Notes
