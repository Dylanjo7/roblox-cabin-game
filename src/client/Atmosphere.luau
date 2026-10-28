--!strict
-- Dread. The Hollow Man on the clock is the monster closing in, and the cabin reacts to how close
-- he is to the Candle: fog thickens, the ambience swells, the lights flicker, you start catching
-- glimpses of him in dark doorways, and when he catches the Candle he stands at the Parlor door
-- watching the table. Each time he moves on the clock you hear his steps.
-- Everything here is local to this client and purely cosmetic; it only reads public state.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local HollowManModel = require(Shared:WaitForChild("HollowManModel"))
local RoomShapes = require(Shared:WaitForChild("RoomShapes"))
local Story = require(Shared:WaitForChild("Story"))
local Types = require(Shared:WaitForChild("Types"))

local Audio = require(script.Parent.Audio)
local Cutscene = require(script.Parent.Cutscene)

local Atmosphere = {}

local localPlayer = Players.LocalPlayer
local dread = Config.Dread
local level = 1
local lastHollow: number? = nil
local lastLastTurn = false
local lastEventId: string? = nil
local phase: Types.Phase = "Lobby"
local cabin: { Types.CellPublic } = {}
local tint: ColorCorrectionEffect
local doorFigure: Model? = nil
local rng = Random.new()

local function levelFor(state: Types.PublicState): number
	local clock = state.clock
	if not clock or state.phase == "Lobby" or state.phase == "GameOver" then
		return 1
	end
	if clock.lastTurn then
		return 5
	end
	local hollow = clock.hollow
	if hollow == nil then
		return 1
	end
	local gap = clock.candle - hollow
	if gap <= dread.CloseGap then
		return 4
	elseif gap <= dread.NearGap then
		return 3
	elseif gap <= dread.UneasyGap then
		return 2
	end
	return 1
end

local function root(): BasePart?
	local character = localPlayer.Character
	local part = character and character:FindFirstChild("HumanoidRootPart")
	return if part and part:IsA("BasePart") then part else nil
end

local function applyLevel()
	TweenService:Create(Lighting, TweenInfo.new(3), { FogEnd = dread.FogEnd[level], FogStart = 0 }):Play()
	local strength = dread.Tint[level]
	TweenService:Create(tint, TweenInfo.new(2), {
		TintColor = Color3.new(1, 1 - strength * 0.6, 1 - strength * 0.7),
		Saturation = -0.15 - strength * 0.4,
	}):Play()
	Audio.loopVolume("ambience", dread.AmbienceVolume[level])
	Audio.loopVolume("drone", dread.DroneVolume[level])
	Audio.loopVolume("heartbeat", dread.HeartbeatVolume[level])
end

-- Lights near the player cut out and stutter back.
local function flicker()
	local here = root()
	if not here then
		return
	end
	local lights = {}
	for _, light in CollectionService:GetTagged("RoomLight") do
		if light:IsA("Light") and light.Parent and light.Parent:IsA("BasePart") then
			if (light.Parent.Position - here.Position).Magnitude < 70 then
				table.insert(lights, light)
			end
		end
	end
	if #lights == 0 then
		return
	end
	Audio.play("flicker", 0.25)
	task.spawn(function()
		for _ = 1, rng:NextInteger(2, 5) do
			for _, light in lights do
				light.Enabled = false
			end
			task.wait(rng:NextNumber(0.04, 0.18))
			for _, light in lights do
				light.Enabled = true
			end
			task.wait(rng:NextNumber(0.05, 0.25))
		end
	end)
end

-- The camera jolts when he takes a step on the clock.
local function shake()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	task.spawn(function()
		for i = 1, 8 do
			local s = dread.StepShake * (1 - i / 9)
			humanoid.CameraOffset = Vector3.new(rng:NextNumber(-s, s), rng:NextNumber(-s, s), 0)
			task.wait(0.04)
		end
		humanoid.CameraOffset = Vector3.zero
	end)
end

local function footsteps(count: number)
	task.spawn(function()
		for i = 1, count do
			Audio.play("step", 0.5, nil, 0.8 + rng:NextNumber(0, 0.1))
			shake()
			if i < count then
				task.wait(0.7)
			end
		end
	end)
end

-- A brief glimpse of him standing in a dark doorway some distance away, facing you.
local function glimpse()
	local here = root()
	local camera = workspace.CurrentCamera
	local folder = workspace:FindFirstChild("Cabin")
	if not here or not folder then
		return
	end
	local candidates = {}
	for _, inst in folder:GetDescendants() do
		if inst:IsA("BasePart") and #inst.Name == 1 and string.find("NESW", inst.Name, 1, true) and inst:GetAttribute("Open") then
			local offset = inst.Position - here.Position
			local distance = offset.Magnitude
			local facing = camera.CFrame.LookVector:Dot(offset.Unit)
			if distance > dread.GlimpseMinDistance and distance < dread.GlimpseMaxDistance and facing > 0.35 then
				table.insert(candidates, inst)
			end
		end
	end
	if #candidates == 0 then
		return
	end
	local doorway = candidates[rng:NextInteger(1, #candidates)]
	local floor = doorway.Position - Vector3.new(0, doorway.Size.Y / 2, 0)
	local figure = HollowManModel.build()
	-- The model's front is -Z, which lookAt points at you.
	figure:PivotTo(CFrame.lookAt(floor, Vector3.new(here.Position.X, floor.Y, here.Position.Z)))
	figure.Parent = workspace
	Audio.play("whisper", 0.6, figure.PrimaryPart)
	task.delay(dread.GlimpseShowSeconds, function()
		figure:Destroy()
	end)
end

-- Through a window you're facing: him, standing still out among the pines, watching. Gone a
-- moment later.
local function windowGlimpse()
	local here = root()
	local camera = workspace.CurrentCamera
	if not here then
		return
	end
	local built: { [string]: boolean } = {}
	for _, cell in cabin do
		built[`{cell.x},{cell.z}`] = true
	end
	local options = {}
	for _, glass in CollectionService:GetTagged("CabinWindow") do
		if glass:IsA("BasePart") then
			local offset = glass.Position - here.Position
			if offset.Magnitude < dread.WindowGlimpseRange and camera.CFrame.LookVector:Dot(offset.Unit) > 0.6 then
				table.insert(options, glass)
			end
		end
	end
	if #options == 0 then
		return
	end
	local glass = options[rng:NextInteger(1, #options)]
	local floorY = glass.Position.Y - (glass:GetAttribute("CentreHeight") or 7)
	local out = glass.Position + glass.CFrame.LookVector * rng:NextNumber(dread.WindowGlimpseDistance[1], dread.WindowGlimpseDistance[2])
	local spot = Vector3.new(out.X, floorY, out.Z)
	local x, z = RoomShapes.cellAt(spot)
	if built[`{x},{z}`] then
		return -- that's inside another room, not out in the trees
	end
	local figure = HollowManModel.build()
	figure:PivotTo(CFrame.lookAt(spot, Vector3.new(glass.Position.X, floorY, glass.Position.Z)))
	figure.Parent = workspace
	task.delay(dread.WindowGlimpseShowSeconds, function()
		figure:Destroy()
	end)
end

-- Frost clue: in a room whose windows have iced over (room attribute Frost), your breath fogs.
local breath: ParticleEmitter? = nil
local function updateBreath()
	local here = root()
	local character = localPlayer.Character
	local head = character and character:FindFirstChild("Head")
	local cabinFolder = workspace:FindFirstChild("Cabin")
	if not here or not head or not cabinFolder then
		return
	end
	local x, z = RoomShapes.cellAt(here.Position)
	local cold = false
	for _, room in cabinFolder:GetChildren() do
		if string.find(room.Name, `({x},{z})`, 1, true) and room:GetAttribute("Frost") then
			cold = true
		end
	end
	if cold and not (breath and breath.Parent == head) then
		local puff = Instance.new("ParticleEmitter")
		puff.Name = "Breath"
		puff.Texture = "rbxasset://textures/particles/smoke_main.dds"
		puff.Color = ColorSequence.new(Color3.fromRGB(230, 236, 240))
		puff.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1.2) })
		puff.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
		puff.Lifetime = NumberRange.new(1, 1.6)
		puff.Rate = 2.5
		puff.Speed = NumberRange.new(0.8, 1.4)
		puff.SpreadAngle = Vector2.new(12, 12)
		puff.EmissionDirection = Enum.NormalId.Front
		puff.Parent = head
		breath = puff
	elseif not cold and breath then
		breath:Destroy()
		breath = nil
	end
end

-- When he has caught the Candle, he stands just inside the front door, watching the table.
local function updateDoorFigure()
	local want = level == 5 and phase == "TurnLoop"
	if not want then
		if doorFigure then
			doorFigure:Destroy()
			doorFigure = nil
		end
		return
	end
	if doorFigure then
		return
	end
	local figure = HollowManModel.build()
	-- Just inside the front door; the model's front is -Z, which faces the table.
	figure:PivotTo(RoomShapes.frontDoorInside())
	figure.Parent = workspace
	doorFigure = figure
end

local function onClockChange(state: Types.PublicState)
	local clock = state.clock
	if not clock or state.phase == "Lobby" or state.phase == "Setup" then
		lastHollow = nil
		lastLastTurn = false
		return
	end
	local hollow = clock.hollow
	if hollow ~= nil and lastHollow == nil then
		Cutscene.beat(Story.Beats.enters)
		footsteps(2)
	elseif hollow ~= nil and lastHollow ~= nil and hollow > lastHollow then
		if hollow >= Config.Clock.MidnightStep and lastHollow < Config.Clock.MidnightStep then
			Cutscene.beat(Story.Beats.midnight)
		else
			Cutscene.beat(Story.Beats.moves)
		end
		footsteps(hollow - lastHollow)
	elseif hollow ~= nil and lastHollow ~= nil and hollow < lastHollow then
		Cutscene.beat(Story.Beats.pushedBack)
	end
	if clock.lastTurn and not lastLastTurn then
		Audio.play("caught", 0.7)
		task.delay(1.5, Cutscene.beat, Story.Beats.caught)
	end
	lastHollow = hollow
	lastLastTurn = clock.lastTurn
end

local function onEventChange(state: Types.PublicState)
	local event = state.event
	local id = if event and not event.over then event.id else nil
	if id == lastEventId then
		return
	end
	if lastEventId == "rising_water" then
		Audio.loopVolume("flood", 0, 1.5)
	elseif lastEventId == "he_walks" then
		applyLevel() -- back to the dread the clock calls for
	end
	if id == "fuse_box" then
		Audio.play("flicker", 0.7)
		task.delay(0.3, Audio.play, "flicker", 0.5)
	elseif id == "rising_water" then
		Audio.loopVolume("flood", 0.5, 4)
	elseif id == "he_walks" then
		Audio.play("caught", 0.6)
		Audio.loopVolume("drone", 0.5, 2)
		Audio.loopVolume("heartbeat", 0.6, 2)
		TweenService:Create(Lighting, TweenInfo.new(2), { FogEnd = dread.FogEnd[4] }):Play()
	end -- The Knock and Lockdown play their sounds from the world (server side).
	lastEventId = id
end

function Atmosphere.setState(state: Types.PublicState)
	phase = state.phase
	cabin = state.cabin or cabin
	onClockChange(state)
	onEventChange(state)
	local newLevel = levelFor(state)
	if newLevel ~= level then
		level = newLevel
		applyLevel()
	end
	updateDoorFigure()
end

function Atmosphere.init()
	tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "DreadTint"
	tint.Contrast = 0.08
	tint.Parent = Lighting
	Lighting.FogColor = Config.Mood.FogColor
	applyLevel()

	local glimpseClock = 0
	local windowClock = 0
	local breathClock = 0
	RunService.Heartbeat:Connect(function(dt: number)
		breathClock += dt
		if breathClock > 0.5 then
			breathClock = 0
			updateBreath()
		end
		local windowEvery = dread.WindowGlimpseSeconds[level]
		if windowEvery > 0 and phase == "TurnLoop" then
			windowClock += dt
			if windowClock > windowEvery * rng:NextNumber(0.6, 1.4) then
				windowClock = 0
				windowGlimpse()
			end
		end
		if rng:NextNumber() < dread.FlickerPerSecond[level] * dt then
			flicker()
		end
		if rng:NextNumber() < dread.CreakPerSecond[level] * dt then
			Audio.play("creak", 0.18, nil, rng:NextNumber(0.8, 1.1))
		end
		local every = dread.GlimpseSeconds[level]
		if every > 0 and phase == "TurnLoop" then
			glimpseClock += dt
			if glimpseClock > every * rng:NextNumber(0.6, 1.4) then
				glimpseClock = 0
				glimpse()
			end
		end
	end)
end

return Atmosphere
