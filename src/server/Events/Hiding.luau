--!strict
-- Hiding spots for events: every room prop tagged HidingSpot (wardrobes and beds; one per room,
-- three in the Closet Room) gets a "Hide" prompt. One player per spot; "Leave" comes back out.
-- Hidden players are shut inside the wardrobe or lie flat under the bed, held in place. If
-- there are fewer spots than players (a small cabin), there's room under the Parlor table for
-- the rest.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local EventKit = require(script.Parent.EventKit)

type EventRun = Types.EventRun
type Entry = { spot: Model, body: BasePart, prompt: ProximityPrompt }

local Hiding = {}

-- Where a hidden character goes: inside the wardrobe, or lying flat under the bed.
local function hideCFrame(spot: Model, body: BasePart): CFrame
	if spot.Name == "Bed" or spot.Name == "UnderTable" then
		return body.CFrame * CFrame.new(0, -1.05, 0) * CFrame.Angles(math.rad(-90), 0, 0)
	end
	return body.CFrame * CFrame.new(0, -1.5, 0)
end

-- Where they step back out: in front of the spot, standing.
local function exitCFrame(body: BasePart): CFrame
	local out = body.Position + body.CFrame.LookVector * 3.5
	return CFrame.new(Vector3.new(out.X, body.Position.Y - body.Size.Y / 2 + 3, out.Z))
end

local function unhide(run: EventRun, player: Player)
	local hidden: { [Player]: Entry } = run.data.hidden
	local entry = hidden[player]
	if not entry then
		return
	end
	hidden[player] = nil
	run.data.occupant[entry.spot] = nil
	entry.prompt.ActionText = "Hide"
	local root = EventKit.root(player)
	if root then
		EventKit.teleport(player, exitCFrame(entry.body))
		root.Anchored = false
	end
end

-- Put a Hide prompt on every hiding spot in the cabin for this event.
function Hiding.enable(run: EventRun)
	local hidden: { [Player]: Entry } = {}
	local occupant: { [Model]: Player } = {}
	local prompts: { ProximityPrompt } = {}
	run.data.hidden = hidden
	run.data.occupant = occupant
	run.data.hidePrompts = prompts

	local function addSpot(spot: Model, body: BasePart, object: string)
		local prompt = EventKit.prompt(body, "Hide", object)
		table.insert(prompts, prompt)
		prompt.Triggered:Connect(function(player: Player)
			if not run.isActive(player) then
				return
			end
			local current = occupant[spot]
			if current == player then
				unhide(run, player)
				return
			elseif current then
				Remotes.notify(player, "Someone is already hiding there.")
				return
			elseif hidden[player] then
				Remotes.notify(player, "You're already hiding somewhere else.")
				return
			end
			local root = EventKit.root(player)
			if not root then
				return
			end
			occupant[spot] = player
			hidden[player] = { spot = spot, body = body, prompt = prompt }
			prompt.ActionText = "Leave"
			EventKit.teleport(player, hideCFrame(spot, body))
			root.Anchored = true
			Remotes.notify(player, "You're hidden. Stay still...")
		end)
	end

	local cabin = workspace:FindFirstChild("Cabin")
	for _, inst in if cabin then cabin:GetDescendants() else {} do
		if inst:IsA("Model") and inst:GetAttribute("HidingSpot") then
			local body = inst:FindFirstChild("Body") or inst:FindFirstChild("Frame")
			if body and body:IsA("BasePart") then
				addSpot(inst, body, if inst.Name == "Bed" then "Under the bed" else "Wardrobe")
			end
		end
	end

	-- Not enough places for everyone: under the Parlor table, between the chairs.
	local short = #EventKit.everyoneActive(run) - #prompts
	local folder = run.data.folder
	if short > 0 and folder then
		for i = 1, math.min(short, Config.Table.SeatCount) do
			local a = (i - 0.5) * math.pi * 2 / Config.Table.SeatCount
			local out = Vector3.new(math.sin(a), 0, math.cos(a))
			local at = Config.ParlorOrigin + out * 5 + Vector3.new(0, 1.6, 0)
			local spot = Instance.new("Model")
			spot.Name = "UnderTable"
			local body = EventKit.part("Body", Vector3.new(2, 1, 4), CFrame.lookAt(at, at + out), Color3.new(), spot)
			body.Transparency = 1
			body.CanCollide = false
			body.CanQuery = false
			spot.Parent = folder
			addSpot(spot, body, "Under the table")
		end
	end
end

function Hiding.isHidden(run: EventRun, player: Player): boolean
	local hidden = run.data.hidden
	return hidden ~= nil and hidden[player] ~= nil
end

-- Bring everyone out and remove the prompts.
function Hiding.cleanup(run: EventRun)
	for player in run.data.hidden or {} do
		unhide(run, player)
	end
	for _, prompt in run.data.hidePrompts or {} do
		prompt:Destroy()
	end
end

return Hiding
