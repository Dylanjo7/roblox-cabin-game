--!strict
-- The final escape at 3:00 AM (run through EventRunner like an event, but not a card in the deck).
-- Every built exit room's outside door unseals: its boards and chain fall away and it can be
-- opened. Only the true exit's door leads out; the rest are traps (whoever opens one is out).
-- The Hollow Man comes in by the front door and hunts, as in He Walks. Whoever gets through the
-- true exit is safe outside by the truck; anyone still inside when time runs out is caught. It
-- ends early once nobody is left in play. Eliminations here don't move the Candle (the clock is
-- done). It opens with a cutscene (client/Scenes.three: the clocks strike three, an exit door's
-- boards fall, he bursts in), so the doors unseal partway through it and the hunt and the door
-- prompts only start once it's over; the timer is that much longer (leadSeconds).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CardData = require(Shared:WaitForChild("CardData"))
local Config = require(Shared:WaitForChild("Config"))
local HollowManModel = require(Shared:WaitForChild("HollowManModel"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local RoomShapes = require(Shared:WaitForChild("RoomShapes"))
local Types = require(Shared:WaitForChild("Types"))

local MapGrid = require(script.Parent.Parent.MapGrid)
local RunStats = require(script.Parent.Parent.RunStats)
local Secrets = require(script.Parent.Parent.Secrets)
local EventKit = require(script.Parent.EventKit)
local HeWalks = require(script.Parent.HeWalks)

type EventRun = Types.EventRun

local FinalEscape = {
	noPenalty = true,
	keepPlayers = true,
	leadSeconds = Config.Cinematics.ThreeSeconds,
}

local escapedNames: { string } = {}
local escapedPlayers: { Player } = {}

-- Where you end up when you get out: back on the path by the truck.
local function outside(): CFrame
	local spawn = workspace:FindFirstChild("ArrivalSpawn")
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame * CFrame.new(0, 3, 0)
	end
	return CFrame.new(0, 3, 80)
end

local function anyoneLeft(run: EventRun): boolean
	for _, player in run.players do
		if run.isActive(player) and player.Parent == Players then
			return true
		end
	end
	return false
end

-- Swing an exit door open into its room (about its hinge, the edge away from the knob), or shut
-- again. Its parts' closed places are kept on the run so it can always go back.
local function swing(run: EventRun, cell: MapGrid.Cell, door: Model, open: boolean)
	local panel = door:FindFirstChild("Panel")
	if not panel or not panel:IsA("BasePart") then
		return
	end
	local rests: { [Model]: { [BasePart]: CFrame } } = run.data.doorRests or {}
	run.data.doorRests = rests
	local rest = rests[door]
	if not rest then
		rest = {}
		for _, p in door:GetDescendants() do
			if p:IsA("BasePart") then
				rest[p] = p.CFrame
			end
		end
		rests[door] = rest
	end
	local closed = rest[panel] or panel.CFrame
	local hinge = closed * CFrame.new(-panel.Size.X / 2, 0, 0)
	-- Whichever way brings the door into the room, not out through the wall.
	local centre = RoomShapes.cellPosition(cell.x, cell.z)
	local function turned(angle: number): CFrame
		return hinge * CFrame.Angles(0, angle, 0) * hinge:Inverse()
	end
	local widest = math.rad(80)
	local sign = if ((turned(widest) * closed).Position - centre).Magnitude < ((turned(-widest) * closed).Position - centre).Magnitude then 1 else -1
	task.spawn(function()
		for step = 1, 10 do
			local k = step / 10
			local angle = widest * sign * (if open then k else 1 - k)
			local turn = turned(angle)
			for p, cf in rest do
				if p.Parent then
					p.CFrame = turn * cf
				end
			end
			task.wait(0.04)
		end
	end)
end

-- The true exit: the door swings open on the night (and stays open), and you're through it and
-- out by the truck.
local function escape(run: EventRun, player: Player, cell: MapGrid.Cell, door: Model)
	run.safe[player] = true
	RunStats.escaped(player)
	table.insert(escapedNames, player.DisplayName)
	table.insert(escapedPlayers, player)
	local opened: { [Model]: boolean } = run.data.opened or {}
	run.data.opened = opened
	if not opened[door] then
		opened[door] = true
		swing(run, cell, door, true)
	end
	task.delay(0.5, function()
		local character = player.Character
		if character then
			character:PivotTo(outside())
		end
	end)
	local name = CardData.get(cell.id).name
	Remotes.notify(player, `The {name} door gives way. Cold air. The road. The truck. You're out!`)
	for _, p in run.players do
		if p ~= player then
			Remotes.notify(p, `{player.DisplayName} got out through the {name}.`)
		end
	end
	if not anyoneLeft(run) then
		run.complete()
	end
end

-- A wrong door. It swings open, and he's standing right there in the doorway, waiting: he has
-- you (held a moment while he gets you, then you're out). Then it shuts on him again, ready for
-- the next one who picks it.
local function trap(run: EventRun, player: Player, cell: MapGrid.Cell, door: Model)
	local name = CardData.get(cell.id).name
	local panel = door:FindFirstChild("Panel")
	if not panel or not panel:IsA("BasePart") then
		run.eliminate(player)
		return
	end
	swing(run, cell, door, true)
	local centre = RoomShapes.cellPosition(cell.x, cell.z)
	local out = (panel.Position - centre) * Vector3.new(1, 0, 1)
	out = if out.Magnitude > 0.1 then out.Unit else Vector3.zAxis
	local feet = Vector3.new(panel.Position.X, centre.Y, panel.Position.Z) + out * 0.6
	local decoy = HollowManModel.marker(CFrame.lookAt(feet, feet - out), run.data.folder or workspace)
	decoy:SetAttribute("Killing", true)
	EventKit.sound("caught", panel, 1)
	Remotes.notify(player, `The {name} door opens... and he's standing right there. Wrong door.`)
	for _, p in run.players do
		if p ~= player and run.isActive(p) then
			Remotes.notify(p, `{player.DisplayName} opened the {name} door. He was waiting behind it. That's not the way out.`)
		end
	end
	if not EventKit.seize(run, player, feet) then
		run.eliminate(player)
	end
	task.delay(Config.Events.KillHoldSeconds + 1.2, function()
		decoy:Destroy()
		if not run.over then
			swing(run, cell, door, false)
			if not anyoneLeft(run) then
				run.complete()
			end
		end
	end)
end

function FinalEscape.start(run: EventRun)
	table.clear(escapedNames)
	table.clear(escapedPlayers)
	local trueExit = Secrets.trueExit()
	local prompts: { ProximityPrompt } = {}
	run.data.prompts = prompts
	local count = 0
	local unsealed = false

	-- Unseal every built exit room's outside door (its prompt waits for the cutscene to end).
	local function unseal()
		if unsealed then
			return
		end
		unsealed = true
		for _, cell in MapGrid.all() do
			local door = cell.model and cell.model:FindFirstChild("ExitDoor")
			local panel = door and door:FindFirstChild("Panel")
			if door and panel and panel:IsA("BasePart") then
				count += 1
				local boards = door:FindFirstChild("Boards")
				if boards then
					for _, board in boards:GetChildren() do
						if board:IsA("BasePart") then
							board.Anchored = false
							board.CanCollide = false
						end
					end
					task.delay(2, function()
						boards:Destroy()
					end)
				end
				EventKit.sound("creak", panel, 0.8)
				-- Easy to find and impossible to miss: cold night light round the door, a label once
				-- you're in the room, and its own key (F), always shown, so a wardrobe's "Hide" or a
				-- sign's "Record" prompt next to it can't take its place.
				local glow = Instance.new("PointLight")
				glow.Color = Color3.fromRGB(170, 195, 255)
				glow.Brightness = 1.6
				glow.Range = 16
				glow.Parent = panel
				local label = EventKit.marker(panel, "Door out", Color3.fromRGB(200, 215, 255))
				local tag = label.Parent :: BillboardGui
				tag.MaxDistance = 30
				tag.Enabled = false
				local prompt = EventKit.prompt(panel, "Go through", `{CardData.get(cell.id).name} door`)
				prompt.KeyboardKeyCode = Enum.KeyCode.F
				prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
				prompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
				prompt.MaxActivationDistance = 12
				prompt.HoldDuration = 0.5
				run.data.doorTags = run.data.doorTags or {}
				table.insert(run.data.doorTags, tag)
				run.data.doorLights = run.data.doorLights or {}
				table.insert(run.data.doorLights, glow)
				prompt.Enabled = false
				prompt.Triggered:Connect(function(player: Player)
					if not run.isActive(player) or EventKit.isSeized(run, player) then
						return -- (he has them)
					end
					if trueExit and cell.id == trueExit.id then
						escape(run, player, cell, door :: Model)
					else
						trap(run, player, cell, door :: Model)
					end
				end)
				table.insert(prompts, prompt)
			end
		end
	end

	task.delay(Config.Cinematics.ThreeUnsealAt, function()
		if not run.over then
			unseal()
		end
	end)
	task.delay(FinalEscape.leadSeconds, function()
		if run.over then
			return
		end
		unseal()
		for _, prompt in prompts do
			prompt.Enabled = true
		end
		for _, tag in (run.data.doorTags or {}) :: { BillboardGui } do
			tag.Enabled = true
		end
		if count == 0 then
			EventKit.notifyAll(run, "3:00 AM. Somewhere a lock turns... but no exit room was ever built.")
		else
			EventKit.notifyAll(run, `3:00 AM. {count} outside door{if count == 1 then "" else "s"} unsealed. Only one leads out. Get to it and press F.`)
		end
		-- He's in by the front door. He waits there a moment, then he comes for you.
		local cfg = Config.Events.HeWalks
		run.data.startCell = MapGrid.get(0, 0)
		run.data.startAt = RoomShapes.hollowEntry()
		run.data.holdSeconds = cfg.FinalHoldSeconds
		run.data.speedScale = cfg.FinalSpeed
		HeWalks.start(run)
	end)
end

function FinalEscape.onTimeout(run: EventRun): { Player }
	EventKit.notifyAll(run, "Time's up. The doors swing shut, all of them at once.")
	local caught = {}
	for _, player in run.players do
		if run.isActive(player) then
			table.insert(caught, player)
		end
	end
	return caught
end

function FinalEscape.cleanup(run: EventRun)
	for _, prompt in (run.data.prompts or {}) :: { ProximityPrompt } do
		prompt:Destroy()
	end
	for _, tag in (run.data.doorTags or {}) :: { BillboardGui } do
		tag:Destroy()
	end
	for _, glow in (run.data.doorLights or {}) :: { PointLight } do
		glow:Destroy()
	end
	HeWalks.cleanup(run)
end

-- Display names of everyone who got out through the true exit in the last final escape.
function FinalEscape.escaped(): { string }
	return table.clone(escapedNames)
end

-- Everyone who got out in the last final escape.
function FinalEscape.escapedPlayers(): { Player }
	return table.clone(escapedPlayers)
end

return FinalEscape
