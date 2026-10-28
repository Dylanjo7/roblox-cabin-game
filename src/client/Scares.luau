--!strict
-- Jump scares, rare and spaced out (Config.Scares), only while you're up and walking the cabin
-- (never at the table) and only once he's on the clock. All local and cosmetic; none of them is
-- him really being there, so they don't set the lights off.
--   Behind you: spin round quickly and he's standing right there, gone a blink later.
--   The corner: walk into a room and he's standing in the far corner, facing the wall. Look at
--     him and his head snaps round to you, then he's gone.
--   The face: when you're caught in an event, his face fills the screen.
--   The book: late in the night, opening the Journal, something has written in it.
--   The window: a heavy slap on a window you're near, and his handprint left on the glass.
--   The doorway: something tall runs past an open doorway you're looking down.
--   The empty chair: at the table, look at an empty chair and he's standing behind it.
--   Your name: whispered, faint, at the edge of the screen.
--   (And now and then, knocks in the walls; not a scare as such.)
--   Bought: someone paid (Journal > Favours) to put his face on your screen; you're told who.
--   (The mirror: Reflections claims a slot here for him standing behind you in it.)

local CollectionService = game:GetService("CollectionService")
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
local BoardUI = require(script.Parent.BoardUI)
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
local whisperLabel: TextLabel

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

-- At the table (and not placing a room): the empty chair can happen.
local function readySeated(): boolean
	return not busy and phase == "TurnLoop" and hollow ~= nil and seated() and not BoardUI.isViewing() and os.clock() - lastScare > cfg.MinGapSeconds
end

-- A sharp jolt of the camera.
local function jolt(strength: number)
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	task.spawn(function()
		for i = 1, 8 do
			local s = strength * (1 - i / 9)
			humanoid.CameraOffset = Vector3.new(rng:NextNumber(-s, s), rng:NextNumber(-s, s), 0)
			task.wait(0.03)
		end
		humanoid.CameraOffset = Vector3.zero
	end)
end

-- Windows near you that you're facing (their LookVector points outside).
local function windowInView(range: number): BasePart?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local best: BasePart? = nil
	local bestDot = 0.55
	for _, glass in CollectionService:GetTagged("CabinWindow") do
		if glass:IsA("BasePart") then
			local offset = glass.Position - camera.CFrame.Position
			if offset.Magnitude < range then
				local dot = camera.CFrame.LookVector:Dot(offset.Unit)
				if dot > bestDot then
					best, bestDot = glass, dot
				end
			end
		end
	end
	return best
end

-- The window: a slap on the glass from outside, and a handprint that fades.
local function windowBang(glass: BasePart)
	begin()
	local outside = glass.CFrame.LookVector
	local offset = glass.CFrame.RightVector * rng:NextNumber(-glass.Size.X * 0.3, glass.Size.X * 0.3) + glass.CFrame.UpVector * rng:NextNumber(-glass.Size.Y * 0.2, glass.Size.Y * 0.25)
	local at = glass.Position + offset + outside * (glass.Size.Z / 2 + 0.03)
	local hand = CFrame.lookAt(at, at - outside, glass.CFrame.UpVector) * CFrame.Angles(0, 0, rng:NextNumber(-0.4, 0.4))
	local handprint = Instance.new("Model")
	handprint.Name = "Handprint"
	local pieces: { BasePart } = {}
	local function smear(size: Vector3, cf: CFrame)
		local p = Instance.new("Part")
		p.Size = size
		p.CFrame = hand * cf
		p.Color = Color3.fromRGB(16, 12, 12)
		p.Material = Enum.Material.SmoothPlastic
		p.Transparency = 0.2
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.Parent = handprint
		table.insert(pieces, p)
	end
	smear(Vector3.new(0.9, 1.0, 0.02), CFrame.new())
	for i, x in { -0.33, -0.11, 0.11, 0.33 } do
		local length = if i == 2 or i == 3 then 1.25 else 1.0
		smear(Vector3.new(0.17, length, 0.02), CFrame.new(x * 1.1, 0.5 + length / 2, 0) * CFrame.Angles(0, 0, x * -0.25))
	end
	smear(Vector3.new(0.18, 0.7, 0.02), CFrame.new(-0.6, 0.05, 0) * CFrame.Angles(0, 0, 0.9))
	handprint.Parent = workspace
	Audio.play("knock", 1, glass, 0.55)
	Audio.play("caught", 0.45)
	jolt(0.5)
	task.delay(0.8, function()
		busy = false
	end)
	task.delay(1.6, function()
		for _, p in pieces do
			TweenService:Create(p, TweenInfo.new(2.5), { Transparency = 1 }):Play()
		end
		task.wait(2.6)
		handprint:Destroy()
	end)
end

-- The doorway: something runs past an open doorway you're looking down, a little way off.
local function doorwayInView(): BasePart?
	local camera = workspace.CurrentCamera
	local cabinFolder = workspace:FindFirstChild("Cabin")
	if not camera or not cabinFolder then
		return nil
	end
	local options = {}
	for _, inst in cabinFolder:GetDescendants() do
		if inst:IsA("BasePart") and #inst.Name == 1 and string.find("NESW", inst.Name, 1, true) and inst:GetAttribute("Open") then
			local offset = inst.Position - camera.CFrame.Position
			local distance = offset.Magnitude
			if distance > 18 and distance < 60 and camera.CFrame.LookVector:Dot(offset.Unit) > 0.85 then
				table.insert(options, inst)
			end
		end
	end
	return if #options > 0 then options[rng:NextInteger(1, #options)] else nil
end

local function runner(doorway: BasePart)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	begin()
	local away = (doorway.Position - camera.CFrame.Position) * Vector3.new(1, 0, 1)
	away = if away.Magnitude > 0.1 then away.Unit else Vector3.zAxis
	local across = doorway.CFrame.RightVector
	local floorY = doorway.Position.Y - doorway.Size.Y / 2
	local base = Vector3.new(doorway.Position.X, floorY, doorway.Position.Z) + away * 3
	local from, to = base - across * 7, base + across * 7
	if rng:NextNumber() < 0.5 then
		from, to = to, from
	end
	local figure = HollowManView.spawnLocal(CFrame.lookAt(from, to), false, false)
	Audio.play("step", 0.45, doorway, 1.3)
	task.delay(0.3, Audio.play, "step", 0.4, doorway, 1.25)
	task.spawn(function()
		local t = 0
		local seconds = 0.6
		while t < seconds do
			t += RunService.Heartbeat:Wait()
			figure.setPivot(CFrame.lookAt(from:Lerp(to, math.min(1, t / seconds)), to), 26)
		end
		figure.destroy()
		busy = false
	end)
end

-- The empty chair: he's standing right behind it, watching you, for a moment.
local function emptySeats(): { Seat }
	local tableModel = workspace:FindFirstChild("ParlorTable")
	local out = {}
	if tableModel then
		for _, inst in tableModel:GetDescendants() do
			if inst:IsA("Seat") and inst.Occupant == nil then
				table.insert(out, inst)
			end
		end
	end
	return out
end

local function behindChair(seat: Seat)
	begin()
	local centre = Config.ParlorOrigin
	local out = (seat.Position - centre) * Vector3.new(1, 0, 1)
	out = if out.Magnitude > 0.1 then out.Unit else Vector3.zAxis
	local feet = Vector3.new(seat.Position.X, centre.Y, seat.Position.Z) + out * 2.8
	local figure = HollowManView.spawnLocal(CFrame.lookAt(feet, Vector3.new(centre.X, feet.Y, centre.Z)), true, false)
	Audio.play("caught", 0.6)
	Audio.play("whisper", 0.6)
	task.delay(0.8, function()
		figure.destroy()
		busy = false
	end)
end

-- Your name, whispered, at the edge of the screen.
local function whisperName()
	begin()
	whisperLabel.Text = `{localPlayer.DisplayName}...`
	whisperLabel.Position = UDim2.fromScale(rng:NextNumber(0.12, 0.88), if rng:NextNumber() < 0.5 then 0.2 else 0.78)
	whisperLabel.Rotation = rng:NextNumber(-8, 8)
	Audio.play("whisper", 0.9)
	TweenService:Create(whisperLabel, TweenInfo.new(0.6), { TextTransparency = 0.35 }):Play()
	task.delay(1.4, function()
		TweenService:Create(whisperLabel, TweenInfo.new(1.2), { TextTransparency = 1 }):Play()
		busy = false
	end)
end

-- Three slow knocks from somewhere close: inside a wall, or the glass of a window nearby.
local function knocks()
	local here = root()
	if not here then
		return
	end
	local emitter: BasePart? = nil
	local nearest = 45
	for _, glass in CollectionService:GetTagged("CabinWindow") do
		if glass:IsA("BasePart") then
			local d = (glass.Position - here.Position).Magnitude
			if d < nearest then
				emitter, nearest = glass, d
			end
		end
	end
	if not emitter then
		return
	end
	local at = emitter
	task.spawn(function()
		for i = 1, 3 do
			Audio.play("knock", 0.35, at, 0.75 + i * 0.02)
			task.wait(rng:NextNumber(0.7, 1.1))
		end
	end)
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

-- For scares run by other modules (the mirror): take the slot if a scare may happen now. Call
-- release() when it's over.
function Scares.claim(): boolean
	if not ready() then
		return false
	end
	begin()
	return true
end

function Scares.release()
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
	faceGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
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

	whisperLabel = Instance.new("TextLabel")
	whisperLabel.Name = "Whisper"
	whisperLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	whisperLabel.Size = UDim2.fromOffset(420, 60)
	whisperLabel.BackgroundTransparency = 1
	whisperLabel.Font = Enum.Font.IndieFlower
	whisperLabel.TextSize = 40
	whisperLabel.TextColor3 = Color3.fromRGB(200, 190, 180)
	whisperLabel.TextStrokeTransparency = 1
	whisperLabel.TextTransparency = 1
	whisperLabel.ZIndex = 30
	whisperLabel.Parent = gui

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

	-- The book: late in the night on his clock, sometimes something has written in it.
	JournalUI.Opened:Connect(function()
		local h = hollow
		if h and h >= cfg.JournalFromStep and not busy and os.clock() - lastScare > cfg.MinGapSeconds and rng:NextNumber() < cfg.JournalChance then
			lastScare = os.clock()
			task.delay(0.6, function()
				Audio.play("whisper", 0.9)
				Audio.play("caught", 0.5)
				JournalUI.scrawl(SCRAWLS[rng:NextInteger(1, #SCRAWLS)], 1.1)
			end)
		end
	end)

	-- Watch for spinning round, for walking into a new room, for windows and doorways, and for
	-- glances at the empty chairs.
	local lastLook: Vector3? = nil
	local turned = 0 -- degrees turned in the last moment
	local lastCell: string? = nil
	local checkClock = 0
	local glancing: { [Seat]: boolean } = {}
	RunService.Heartbeat:Connect(function(dt: number)
		-- Knocks in the walls, any time in play once he's on the clock.
		if (phase == "TurnLoop" or phase == "Event") and hollow ~= nil and rng:NextNumber() < cfg.KnockPerSecond * dt then
			knocks()
		end
		checkClock += dt
		if checkClock >= 0.5 then
			checkClock = 0
			if ready() then
				local glass = windowInView(10)
				local doorway = doorwayInView()
				if glass and rng:NextNumber() < cfg.WindowBangChance then
					windowBang(glass)
				elseif doorway and rng:NextNumber() < cfg.RunnerChance then
					runner(doorway)
				elseif rng:NextNumber() < cfg.WhisperPerSecond * 0.5 then
					whisperName()
				end
			end
			-- At the table: a fresh look at an empty chair.
			local cam = workspace.CurrentCamera
			if cam and seated() then
				for _, seat in emptySeats() do
					local toSeat = seat.Position - cam.CFrame.Position
					local looking = toSeat.Magnitude < 30 and cam.CFrame.LookVector:Dot(toSeat.Unit) > 0.93
					if looking and not glancing[seat] and readySeated() and rng:NextNumber() < cfg.EmptyChairChance then
						behindChair(seat)
					end
					glancing[seat] = looking
				end
			end
		end
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
