--!strict
-- Jump scares, rare and spaced out (Config.Scares), only while you're up and walking the cabin
-- (never at the table) and only once he's on the clock. All local and cosmetic; none of them is
-- him really being there, so they don't set the lights off.
--   Behind you: spin round quickly and he's standing right there, gone a blink later.
--   The corner: walk into a room and he's standing in the far corner, facing the wall. Look at
--     him and his head snaps round to you, then he's gone.
--   The face: when you're caught in an event, his face fills the screen.
--   The book: late in the night, opening the Journal, something has written in it.
--   Bought: someone paid (Journal > Favours) to put his face on your screen; you're told who.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CardData = require(Shared:WaitForChild("CardData"))
local Config = require(Shared:WaitForChild("Config"))
local RoomShapes = require(Shared:WaitForChild("RoomShapes"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local Audio = require(script.Parent.Audio)
local Hud = require(script.Parent.Hud)
local HollowManRig = require(script.Parent.HollowManRig)
local HollowManView = require(script.Parent.HollowManView)
local JournalUI = require(script.Parent.JournalUI)

local cfg = Config.Scares
local Scares = {}

local localPlayer = Players.LocalPlayer
local rng = Random.new()
local phase: Types.Phase = "Lobby"
local hollow: number? = nil
local cabin: { [string]: string } = {} -- "x,z" -> room id
local lastScare = -math.huge
local wasOut = false
local busy = false
local faceGui: ScreenGui

local SCRAWLS = { "BEHIND YOU", "I SEE YOU READING", "NOT A GAME", "STAY", "ONE OF YOU STAYS", "HE KNOWS WHICH DOOR" }

local function root(): BasePart?
	local character = localPlayer.Character
	local part = character and character:FindFirstChild("HumanoidRootPart")
	return if part and part:IsA("BasePart") then part else nil
end

local function seated(): boolean
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.SeatPart ~= nil
end

-- A scare can happen now: up and about during play, he's on the clock, and it's been a while.
local function ready(): boolean
	return not busy
		and (phase == "TurnLoop" or phase == "Event")
		and hollow ~= nil
		and not seated()
		and os.clock() - lastScare > cfg.MinGapSeconds
		and root() ~= nil
end

local function begin()
	busy = true
	lastScare = os.clock()
end

local function floorBelow(at: Vector3): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local character = localPlayer.Character
	params.FilterDescendantsInstances = if character then { character } else {}
	local hit = workspace:Raycast(at + Vector3.new(0, 3, 0), Vector3.new(0, -14, 0), params)
	return if hit then hit.Position.Y else nil
end

-- Behind you: he's there when you turn round.
local function behindYou(look: Vector3)
	local camera = workspace.CurrentCamera
	local here = root()
	if not camera or not here then
		return
	end
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 then
		return
	end
	local spot = here.Position + flat.Unit * 4.5
	-- Only if there's room for him there (no wall in between).
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { localPlayer.Character :: Instance }
	if workspace:Raycast(here.Position, spot - here.Position, params) then
		return
	end
	local y = floorBelow(spot)
	if not y then
		return
	end
	begin()
	local feet = Vector3.new(spot.X, y, spot.Z)
	local figure = HollowManView.spawnLocal(CFrame.lookAt(feet, Vector3.new(here.Position.X, y, here.Position.Z)), true, false)
	Audio.play("caught", 0.9)
	Audio.play("whisper", 0.7)
	task.delay(cfg.BehindYouShowSeconds, function()
		figure.destroy()
		busy = false
	end)
end

-- The corner: he's in the far corner of the room you just walked into, facing the wall.
local function corner(x: number, z: number)
	local here = root()
	local id = cabin[`{x},{z}`]
	if not here or not id or id == "parlor" or id == "crawlspace" then
		return
	end
	local def = CardData.get(id)
	local size = def.size or Vector2.new(Config.TileSize - 2, Config.TileSize - 2)
	local reach = math.min(size.X, size.Y) / 2 - 3
	local centre = RoomShapes.cellPosition(x, z)
	local rel = here.Position - centre
	-- The corner diagonally opposite where you came in.
	local cx = if rel.X > 0 then -reach else reach
	local cz = if rel.Z > 0 then -reach else reach
	local spot = centre + Vector3.new(cx, 0, cz)
	local y = floorBelow(spot) or centre.Y
	local feet = Vector3.new(spot.X, y, spot.Z)
	-- Facing into the corner, his back to the room.
	local into = feet + Vector3.new(cx, 0, cz).Unit
	begin()
	local figure = HollowManView.spawnLocal(CFrame.lookAt(feet, Vector3.new(into.X, y, into.Z)), false, false)
	task.spawn(function()
		local started = os.clock()
		while os.clock() - started < cfg.CornerWaitSeconds do
			task.wait(0.05)
			local camera = workspace.CurrentCamera
			local me = root()
			if not camera or not me then
				break
			end
			local head = feet + Vector3.new(0, 9.5, 0)
			local toHim = head - camera.CFrame.Position
			if toHim.Magnitude < 60 and camera.CFrame.LookVector:Dot(toHim.Unit) > 0.95 then
				-- You've seen him. His head snaps round to you.
				figure.setWatch(true)
				Audio.play("whisper", 0.8)
				task.wait(0.45)
				Audio.play("caught", 0.8)
				task.wait(0.15)
				break
			end
		end
		figure.destroy()
		busy = false
	end)
end

-- The face: his face fills the screen for a moment.
local function face()
	if busy then
		return
	end
	busy = true
	lastScare = os.clock()
	local viewport = faceGui:FindFirstChildOfClass("ViewportFrame") :: ViewportFrame
	viewport:ClearAllChildren()
	local rig = HollowManRig.new() -- built standing at the origin, as he is
	rig.model.Parent = viewport
	local headPart = rig.model:FindFirstChild("Head") :: BasePart
	local headAt = headPart.Position
	local camera = Instance.new("Camera")
	camera.FieldOfView = 55
	viewport.CurrentCamera = camera
	camera.Parent = viewport
	faceGui.Enabled = true
	Audio.play("caught", 1)
	local t = 0
	local seconds = cfg.FaceSeconds
	while t < seconds do
		t += RunService.RenderStepped:Wait()
		local u = t / seconds
		-- Rushing at you, shaking.
		local distance = 3.2 - u * 1.6
		local shake = Vector3.new(rng:NextNumber(-0.05, 0.05), rng:NextNumber(-0.05, 0.05), 0)
		local from = headAt + Vector3.new(0, 0.1, -distance) + shake
		camera.CFrame = CFrame.lookAt(from, headAt)
	end
	local black = faceGui:FindFirstChild("Black") :: Frame
	black.BackgroundTransparency = 0
	viewport.Visible = false
	TweenService:Create(black, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	task.wait(0.6)
	faceGui.Enabled = false
	viewport.Visible = true
	viewport:ClearAllChildren()
	busy = false
end

function Scares.setState(state: Types.PublicState)
	phase = state.phase
	hollow = state.clock and state.clock.hollow
	if state.cabin then
		local map = {}
		for _, cell in state.cabin do
			map[`{cell.x},{cell.z}`] = cell.id
		end
		cabin = map
	end
	-- Caught in an event: the face.
	local event = state.event
	local out = event ~= nil and table.find(event.eliminated, localPlayer.UserId) ~= nil
	if out and not wasOut then
		task.spawn(face)
	end
	wasOut = out
end

function Scares.init(gui: ScreenGui)
	faceGui = Instance.new("ScreenGui")
	faceGui.Name = "Scare"
	faceGui.IgnoreGuiInset = true
	faceGui.DisplayOrder = 50
	faceGui.Enabled = false
	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundColor3 = Color3.new(0, 0, 0)
	viewport.Ambient = Color3.fromRGB(70, 60, 60)
	viewport.LightColor = Color3.fromRGB(255, 120, 100)
	viewport.LightDirection = Vector3.new(0.3, -1, 0.6)
	viewport.Parent = faceGui
	local black = Instance.new("Frame")
	black.Name = "Black"
	black.Size = UDim2.fromScale(1, 1)
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.BackgroundTransparency = 1
	black.ZIndex = 2
	black.Parent = faceGui
	faceGui.Parent = gui.Parent

	-- Bought for you by someone else: his face, whatever you're doing, then who it was.
	Remotes.event("Scare").OnClientEvent:Connect(function(kind: any, from: any)
		if kind ~= "face" then
			return
		end
		task.spawn(function()
			while busy do
				task.wait(0.1)
			end
			face()
			task.wait(Config.Shop.ScareRevealSeconds)
			if typeof(from) == "string" then
				Hud.toast(`That was {from}.`)
			end
		end)
	end)

	-- The book: after midnight on his clock, sometimes something has written in it.
	JournalUI.Opened:Connect(function()
		local h = hollow
		if h and h >= Config.Clock.MidnightStep and not busy and os.clock() - lastScare > cfg.MinGapSeconds and rng:NextNumber() < cfg.JournalChance then
			lastScare = os.clock()
			task.delay(0.6, function()
				Audio.play("whisper", 0.9)
				Audio.play("caught", 0.5)
				JournalUI.scrawl(SCRAWLS[rng:NextInteger(1, #SCRAWLS)], 1.1)
			end)
		end
	end)

	-- Watch for spinning round, and for walking into a new room.
	local lastLook: Vector3? = nil
	local turned = 0 -- degrees turned in the last moment
	local lastCell: string? = nil
	RunService.Heartbeat:Connect(function(dt: number)
		local camera = workspace.CurrentCamera
		local here = root()
		if not camera or not here then
			return
		end
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if lastLook and flat.Magnitude > 0.1 then
			local a = math.deg(math.acos(math.clamp(lastLook:Dot(flat.Unit), -1, 1)))
			turned = turned * math.max(0, 1 - dt * 3) + a -- decays over about a third of a second
		end
		lastLook = if flat.Magnitude > 0.1 then flat.Unit else lastLook
		if turned > 150 then
			turned = 0
			if ready() and rng:NextNumber() < cfg.BehindYouChance then
				behindYou(look)
			end
		end

		local x, z = RoomShapes.cellAt(here.Position)
		local key = `{x},{z}`
		if key ~= lastCell then
			lastCell = key
			if ready() and rng:NextNumber() < cfg.CornerChance then
				corner(x, z)
			end
		end
	end)
end

return Scares
