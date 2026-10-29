--!strict
-- A storm over the pines, drawn on each client. Every so often lightning flashes (a flicker, a
-- beat of dark, then the real flash, the way it does), lighting each nearby room through its
-- windows and washing out the picture for a moment; outside it lights up everything. The
-- thunder follows a second or three later, muffled by the walls, and the hanging lamps shiver.
-- It comes more often once he's on the clock, and on the last turn and at three o'clock it's
-- right overhead. Purely cosmetic: it never changes Lighting itself (the Fuse Box event does),
-- and it waits while a cutscene is playing.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local RoomShapes = require(Shared:WaitForChild("RoomShapes"))
local Types = require(Shared:WaitForChild("Types"))

local Cinema = require(script.Parent.Cinema)
local Haunting = require(script.Parent.Haunting)

local Storm = {}

local cfg = Config.Storm
local rng = Random.new()
local hunting = false -- the Hollow Man is on the clock
local overhead = false -- the last turn, or three o'clock
local cabin: { Types.CellPublic } = {}
local flash: ColorCorrectionEffect

local LIGHT = Color3.fromRGB(205, 220, 255)

-- How bright the flash is `t` seconds in: a flicker, a beat of dark, the flash, then it fades.
local function envelope(t: number): number
	if t < 0.07 then
		return 0.55
	elseif t < 0.15 then
		return 0.05
	elseif t < 0.27 then
		return 1
	end
	return math.max(0, 1 - (t - 0.27) / 0.5)
end

type Where = "out" | "in" | "under"

-- Where you are: out under the sky, in one of the built rooms, or under the ground (the
-- basement, where you only hear it).
local function whereIs(at: Vector3): Where
	if at.Y < Config.ParlorOrigin.Y - 8 then
		return "under"
	end
	local half = Config.TileSize / 2 + 1
	for _, cell in cabin do
		local centre = RoomShapes.cellPosition(cell.x, cell.z)
		if math.abs(at.X - centre.X) < half and math.abs(at.Z - centre.Z) < half and at.Y - centre.Y < 30 then
			return "in"
		end
	end
	return "out"
end

-- The windows nearest you (only those actually in the cabin: walls with a room behind them
-- aren't windows any more).
local function nearWindows(at: Vector3): { BasePart }
	local found: { { part: BasePart, distance: number } } = {}
	for _, glass in CollectionService:GetTagged("CabinWindow") do
		if glass:IsA("BasePart") and glass:IsDescendantOf(workspace) then
			local distance = (glass.Position - at).Magnitude
			if distance < cfg.WindowRange then
				table.insert(found, { part = glass, distance = distance })
			end
		end
	end
	table.sort(found, function(a, b)
		return a.distance < b.distance
	end)
	local out = {}
	for i = 1, math.min(#found, cfg.MaxWindows) do
		table.insert(out, found[i].part)
	end
	return out
end

local function thunder(volume: number, where: Where)
	-- Two takes of a deep impact, slowed right down, one just after the other: a rolling boom.
	for take = 1, 2 do
		local sound = Instance.new("Sound")
		sound.Name = "Thunder"
		sound.SoundId = Config.Sounds.thunder
		sound.Volume = volume * (if take == 1 then 1 else 0.55)
		sound.PlaybackSpeed = rng:NextNumber(0.36, 0.48) * (if take == 1 then 1 else 0.8)
		local eq = Instance.new("EqualizerSoundEffect")
		eq.LowGain = 6
		eq.MidGain = if where == "out" then -2 else -6
		eq.HighGain = if where == "out" then -12 elseif where == "in" then -24 else -32
		eq.Parent = sound
		local reverb = Instance.new("ReverbSoundEffect")
		reverb.DecayTime = 3.5
		reverb.Density = 1
		reverb.Diffusion = 1
		reverb.WetLevel = -4
		reverb.Parent = sound
		sound.Parent = SoundService
		task.delay(if take == 1 then 0 else rng:NextNumber(0.15, 0.4), function()
			sound:Play()
		end)
		Debris:AddItem(sound, 14)
	end
end

local function strike()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	local where = whereIs(eye)
	local windows = if where == "in" then nearWindows(eye) else {}
	local lights: { SurfaceLight } = {}
	for _, glass in windows do
		-- The glass faces out (its front); light comes in through the back, into the room.
		local light = Instance.new("SurfaceLight")
		light.Name = "Lightning"
		light.Face = Enum.NormalId.Back
		light.Angle = 115
		light.Range = 28
		light.Color = LIGHT
		light.Brightness = 0
		light.Shadows = true
		light.Parent = glass
		table.insert(lights, light)
	end
	-- Out in the open it lights up everything; in a room with no window, only a little gets in.
	local screen = cfg.ScreenFlash * (if where == "out" then 1.6 elseif where == "under" then 0 elseif #windows > 0 then 1 else 0.3)
	flash.Enabled = screen > 0

	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		local level = envelope(t)
		flash.Brightness = screen * level
		flash.TintColor = Color3.new(1, 1, 1):Lerp(LIGHT, level)
		for _, light in lights do
			light.Brightness = cfg.WindowBrightness * level
		end
		if t > 0.8 then
			connection:Disconnect()
			flash.Enabled = false
			flash.Brightness = 0
			for _, light in lights do
				light:Destroy()
			end
		end
	end)

	-- Then the thunder (sooner, and louder, when it's right overhead), and the lamps shiver.
	local after = if overhead then rng:NextNumber(0.3, 1) else rng:NextNumber(cfg.ThunderDelay[1], cfg.ThunderDelay[2])
	task.delay(after, function()
		local muffled = if where == "out" then 1 elseif where == "in" then 0.8 else 0.45
		thunder(cfg.ThunderVolume * (if overhead then 1.25 else 1) * muffled, where)
		Haunting.shudder(if overhead then 0.8 else 0.4)
	end)
end

local function gap(): number
	local range = if overhead then cfg.GapOverhead elseif hunting then cfg.GapHunting else cfg.Gap
	return rng:NextNumber(range[1], range[2])
end

function Storm.setState(state: Types.PublicState)
	local clock = state.clock
	local live = state.phase ~= "Lobby" and state.phase ~= "GameOver"
	hunting = live and clock ~= nil and clock.hollow ~= nil
	overhead = live and ((clock ~= nil and clock.lastTurn) or state.phase == "FinalEscape")
	cabin = state.cabin or cabin
end

function Storm.init()
	flash = Instance.new("ColorCorrectionEffect")
	flash.Name = "LightningFlash"
	flash.Enabled = false
	flash.Parent = Lighting
	task.spawn(function()
		local due = os.clock() + rng:NextNumber(10, 25) -- not the moment you arrive
		while true do
			task.wait(1)
			-- Closer storms come sooner: don't sit out a long wait once it's overhead.
			local soonest = os.clock() + (if overhead then cfg.GapOverhead[2] elseif hunting then cfg.GapHunting[2] else cfg.Gap[2])
			due = math.min(due, soonest)
			if os.clock() >= due and not Cinema.isPlaying() then
				local ok, err = pcall(strike)
				if not ok then
					warn(`Hollow Pines: lightning failed: {err}`)
				end
				due = os.clock() + gap()
			end
		end
	end)
end

return Storm
