--!strict
-- The drive up to the cabin: a ~30-second cinematic each player sees when they first arrive
-- (before they walk up from the dead truck). Built locally, far off the map, and thrown away
-- after. Shots: following the truck's headlights down the forest road; inside the cab beside the
-- driver while he talks and the radio breaks up; a roadside shot as the truck passes someone
-- standing in the trees; the headlights stutter and the engine dies; a light through the pines.
-- Dialogue is in Story.Trip; recorded lines (Config.Voice trip_1..) play with their subtitles,
-- each waiting for the one before to finish (the drive runs on a little if it has to). Click to
-- skip.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Story = require(Shared:WaitForChild("Story"))
local TruckModel = require(Shared:WaitForChild("TruckModel"))

local Audio = require(script.Parent.Audio)
local HollowManView = require(script.Parent.HollowManView)

local Trip = {}

local LENGTH = 30
local SPEED = 38 -- studs per second until the engine dies
local DIES_AT = 21
local STOPS_AT = 26
local ROAD_X = 0
local START_Z = 3040 -- far south of the map; the truck drives towards -Z
local BARK = Color3.fromRGB(40, 30, 24)
local NEEDLES = Color3.fromRGB(20, 32, 24)
local SKIN = Color3.fromRGB(196, 156, 128)

local localPlayer = Players.LocalPlayer

-- How far the truck has come at time t.
local function travelled(t: number): number
	if t < DIES_AT then
		return SPEED * t
	end
	local decel = SPEED / (STOPS_AT - DIES_AT)
	local d = math.min(t, STOPS_AT) - DIES_AT
	return SPEED * DIES_AT + SPEED * d - 0.5 * decel * d * d
end

local function truckCFrame(t: number): CFrame
	local z = START_Z - travelled(t)
	-- A little sway and bounce on the gravel while it's moving.
	local moving = if t < STOPS_AT then 1 - math.max(0, t - DIES_AT) / (STOPS_AT - DIES_AT) else 0
	local bounce = math.sin(t * 9) * 0.06 * moving
	local sway = math.sin(t * 1.3) * 0.015 * moving
	return CFrame.new(ROAD_X + 2.5, bounce, z) * CFrame.Angles(0, sway, 0)
end

local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = parent
	return p
end

-- The road, the pines either side of it, the path to the cabin and its far-off light.
local function buildScene(folder: Folder): Vector3
	local stopZ = START_Z - travelled(STOPS_AT)
	local fromZ, toZ = stopZ - 120, START_Z + 60
	part(folder, Vector3.new(800, 1, toZ - fromZ + 400), CFrame.new(ROAD_X, -0.5, (fromZ + toZ) / 2), Color3.fromRGB(26, 30, 22), Enum.Material.Ground)
	part(folder, Vector3.new(14, 0.2, toZ - fromZ), CFrame.new(ROAD_X, 0.05, (fromZ + toZ) / 2), Color3.fromRGB(64, 60, 54), Enum.Material.Pebble)
	-- The path off to the left where the truck dies, and the light at the end of it.
	local pathZ = stopZ - 4
	part(folder, Vector3.new(60, 0.15, 4), CFrame.new(ROAD_X - 36, 0.06, pathZ), Color3.fromRGB(58, 54, 48), Enum.Material.Pebble)
	local window = part(folder, Vector3.new(2, 2.5, 0.4), CFrame.new(ROAD_X - 80, 6, pathZ), Color3.fromRGB(255, 190, 120), Enum.Material.Neon)
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 180, 110)
	glow.Range = 16
	glow.Brightness = 1.5
	glow.Parent = window

	local rng = Random.new(31)
	local z = fromZ
	while z < toZ do
		for _, side in { -1, 1 } do
			local x = ROAD_X + side * rng:NextNumber(11, 46)
			local onPath = side < 0 and math.abs(z - pathZ) < 7 and x > ROAD_X - 70
			if not onPath then
				local height = rng:NextNumber(30, 50)
				local trunk = part(folder, Vector3.new(height, 1.4, 1.4), CFrame.new(x, height / 2, z) * CFrame.Angles(0, 0, math.rad(90)), BARK, Enum.Material.Wood)
				trunk.Shape = Enum.PartType.Cylinder
				for i = 0, 2 do
					local t = i / 3
					local width = height * 0.42 * (1 - t * 0.75)
					part(folder, Vector3.new(width, height * 0.18, width), CFrame.new(x, height * (0.38 + t * 0.5), z) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), NEEDLES, Enum.Material.Grass)
				end
			end
		end
		z += rng:NextNumber(5, 8)
	end
	return Vector3.new(ROAD_X - 80, 6, pathZ)
end

-- The driver: an old man in a cap, hands on the wheel. Built relative to the truck (truck frame).
local function buildDriver(folder: Folder): { { part: BasePart, offset: CFrame } }
	local pieces = {}
	local function piece(size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?)
		local p = part(folder, size, CFrame.new(), color, material or Enum.Material.SmoothPlastic)
		table.insert(pieces, { part = p, offset = offset })
		return p
	end
	-- Sized to fit under the cab roof (the seat is at 5.1, the roof at 6.8).
	local seat = CFrame.new(-1.3, 0, 0.8)
	piece(Vector3.new(1.3, 1.1, 0.75), seat * CFrame.new(0, 5.65, 0.1), Color3.fromRGB(70, 60, 44), Enum.Material.Fabric) -- jacket
	local head = piece(Vector3.new(0.7, 0.7, 0.7), seat * CFrame.new(0, 6.45, 0), SKIN)
	head.Shape = Enum.PartType.Ball
	piece(Vector3.new(0.76, 0.18, 0.76), seat * CFrame.new(0, 6.72, 0.02), Color3.fromRGB(150, 40, 32), Enum.Material.Fabric) -- cap
	piece(Vector3.new(0.66, 0.06, 0.4), seat * CFrame.new(0, 6.66, -0.48), Color3.fromRGB(150, 40, 32), Enum.Material.Fabric) -- brim
	piece(Vector3.new(0.6, 0.25, 0.2), seat * CFrame.new(0, 6.2, -0.3), Color3.fromRGB(200, 196, 190), Enum.Material.Fabric) -- grey beard
	for _, x in { -0.5, 0.5 } do
		-- Arms out to the wheel.
		piece(Vector3.new(0.26, 0.26, 1.6), seat * CFrame.new(x * 0.9, 5.75, -0.75) * CFrame.Angles(math.rad(12), 0, 0), Color3.fromRGB(70, 60, 44), Enum.Material.Fabric)
	end
	return pieces
end

local function makeGui(): (ScreenGui, TextLabel, TextLabel, TextLabel, Frame)
	local gui = Instance.new("ScreenGui")
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Name = "Trip"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 40
	gui.ResetOnSpawn = false
	local black = Instance.new("Frame")
	black.Size = UDim2.fromScale(1, 1)
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.BorderSizePixel = 0
	black.ZIndex = 5
	black.Parent = gui
	for _, top in { true, false } do
		local bar = Instance.new("Frame")
		bar.Size = UDim2.fromScale(1, 0.12)
		bar.Position = if top then UDim2.fromScale(0, 0) else UDim2.fromScale(0, 0.88)
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.BorderSizePixel = 0
		bar.ZIndex = 2
		bar.Parent = gui
	end
	local function label(y: number, size: number, font: Enum.Font): TextLabel
		local l = Instance.new("TextLabel")
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, y)
		l.Size = UDim2.new(0.7, 0, 0, size + 16)
		l.BackgroundTransparency = 1
		l.TextColor3 = Color3.fromRGB(232, 220, 192)
		l.TextStrokeColor3 = Color3.new(0, 0, 0)
		l.TextStrokeTransparency = 0.4
		l.Font = font
		l.TextSize = size
		l.TextWrapped = true
		l.RichText = true
		l.TextTransparency = 1
		l.ZIndex = 6
		l.Parent = gui
		return l
	end
	local title = label(0.42, 64, Enum.Font.Fondamento)
	title.Text = Story.Title
	local subtitle = label(0.8, 22, Enum.Font.Fondamento)
	local hint = label(0.95, 14, Enum.Font.Fondamento)
	hint.Text = "Click to skip"
	return gui, title, subtitle, hint, black
end

local function fade(obj: Instance, props: { [string]: any }, seconds: number)
	TweenService:Create(obj, TweenInfo.new(seconds, Enum.EasingStyle.Sine), props):Play()
end

-- Play the drive up. Returns when it's over or skipped.
function Trip.play()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "TripScene"
	folder.Parent = workspace
	local cabinLight = buildScene(folder)
	local truck = TruckModel.build(truckCFrame(0), { body = Color3.fromRGB(112, 58, 40), trim = Color3.fromRGB(196, 186, 160), cargo = true })
	truck.Parent = folder
	local driver = buildDriver(folder)
	local beams = {}
	for _, inst in truck:GetDescendants() do
		if inst:IsA("SpotLight") then
			table.insert(beams, inst)
		end
	end

	-- No walking, no HUD, the camera is ours.
	local controls: any = nil
	pcall(function()
		local module = localPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)
		if module then
			controls = (require(module :: ModuleScript) :: any):GetControls()
			controls:Disable()
		end
	end)
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local hud = playerGui:FindFirstChild("HollowPinesHud")
	if hud and hud:IsA("ScreenGui") then
		hud.Enabled = false
	end
	local gui, title, subtitle, hint, black = makeGui()
	local skipButton = Instance.new("TextButton")
	skipButton.Size = UDim2.fromScale(1, 1)
	skipButton.BackgroundTransparency = 1
	skipButton.Text = ""
	skipButton.ZIndex = 10
	skipButton.Parent = gui
	gui.Parent = playerGui
	camera.CameraType = Enum.CameraType.Scriptable

	local skipped = false
	skipButton.Activated:Connect(function()
		skipped = true
	end)

	-- The recorded lines, loaded first (behind the black screen) so they can be timed.
	local voices: { [number]: Sound } = {}
	for i, entry in Story.Trip do
		local sound = Audio.voiceSound(`trip_{i}`, entry.speaker == "Radio")
		if sound then
			voices[i] = sound
		end
	end
	local deadline = os.clock() + 3
	for _, sound in voices do
		while not sound.IsLoaded and os.clock() < deadline do
			task.wait()
		end
	end
	-- When each line comes up and goes: at its time, or once the line before has been said.
	local schedule: { { start: number, stop: number } } = {}
	local free = 0
	for i, entry in Story.Trip do
		local following = Story.Trip[i + 1]
		local sound = voices[i]
		local spoken = if sound and sound.IsLoaded then sound.TimeLength else 0
		local start = math.max(entry.at, free)
		local shown = if entry.hold > 0 then entry.hold elseif following then following.at - entry.at - 0.3 else 3
		schedule[i] = { start = start, stop = start + math.max(shown, spoken + 0.3) }
		free = start + spoken + 0.25
	end
	local total = math.max(LENGTH, schedule[#schedule].stop + 1.6)

	local figure: HollowManView.Handle? = nil
	local nextLine = 1
	local showing: { start: number, stop: number }? = nil
	local cues: { [string]: boolean } = {}
	local function cue(name: string, at: number, t: number, action: () -> ())
		if t >= at and not cues[name] then
			cues[name] = true
			action()
		end
	end

	fade(black, { BackgroundTransparency = 1 }, 2.5)
	fade(hint, { TextTransparency = 0.5 }, 2)
	local started = os.clock()
	while not skipped do
		local t = os.clock() - started
		if t >= total then
			break
		end
		local truckAt = truckCFrame(t)
		truck:PivotTo(truckAt)
		for _, d in driver do
			d.part.CFrame = truckAt * d.offset
		end

		cue("title", 0.8, t, function()
			fade(title, { TextTransparency = 0 }, 1.5)
		end)
		cue("titleOut", 3.6, t, function()
			fade(title, { TextTransparency = 1 }, 1.2)
		end)
		cue("radio", 12.5, t, function()
			Audio.play("flicker", 0.35, nil, 0.7)
		end)
		cue("figure", 15, t, function()
			-- Out in the trees on the far side of the road, where the headlights will catch him.
			local at = START_Z - travelled(17.6)
			figure = HollowManView.spawnLocal(CFrame.lookAt(Vector3.new(ROAD_X + 17, 0, at), Vector3.new(ROAD_X, 0, at)), false, false)
		end)
		cue("whisper", 16.6, t, function()
			Audio.play("whisper", 0.6)
		end)
		cue("figureGone", 21, t, function()
			if figure then
				figure.destroy()
				figure = nil
			end
		end)
		cue("sputter", DIES_AT, t, function()
			Audio.play("ratchet", 0.8, nil, 0.45)
			task.delay(1.2, Audio.play, "ratchet", 0.6, nil, 0.35)
			task.delay(STOPS_AT - DIES_AT, Audio.play, "step", 0.5, nil, 0.6)
		end)
		cue("fadeOut", total - 1.8, t, function()
			fade(black, { BackgroundTransparency = 0 }, 1.6)
		end)

		-- The headlights stutter as the engine dies, then hold, dim.
		if t > DIES_AT and t < STOPS_AT + 0.5 then
			local on = math.noise(t * 12) > -0.15
			for _, beam in beams do
				beam.Enabled = on
				beam.Brightness = 1.1
			end
		end

		-- Subtitles, and the recorded lines with them.
		local entry = Story.Trip[nextLine]
		local slot = schedule[nextLine]
		if entry and slot and t >= slot.start then
			local sound = voices[nextLine]
			if sound then
				sound:Play()
			end
			nextLine += 1
			showing = slot
			subtitle.Text = `<font color="#B08C48">{string.upper(entry.speaker)}</font>   {entry.line}`
			fade(subtitle, { TextTransparency = 0 }, 0.3)
		elseif showing and t >= showing.stop then
			showing = nil
			fade(subtitle, { TextTransparency = 1 }, 0.4)
		end

		-- The camera.
		local truckPos = truckAt.Position
		if t < 5 then
			-- Behind and above, following the headlights down the road.
			local behind = truckAt * CFrame.new(5, 9 - t * 0.4, 26 - t * 1.2)
			camera.CFrame = CFrame.lookAt(behind.Position, (truckAt * CFrame.new(0, 3, -30)).Position)
		elseif t < 15 then
			-- In the passenger seat, looking out past the driver at the road.
			local seat = truckAt * CFrame.new(1.25, 6.35 + math.sin(t * 8) * 0.03, 0.9)
			local look = truckAt * CFrame.new(-0.6 + math.sin(t * 0.4) * 0.5, 5.4, -20)
			camera.CFrame = CFrame.lookAt(seat.Position, look.Position)
		elseif t < DIES_AT then
			-- At the roadside, low, as the truck goes by.
			local at = START_Z - travelled(17.6)
			local eye = Vector3.new(ROAD_X - 9, 3, at + 6)
			camera.CFrame = CFrame.lookAt(eye, truckPos + Vector3.new(0, 3, 0))
		elseif t < STOPS_AT + 1 then
			-- Ahead of it, as it rolls to a stop with its lights failing.
			local stopZ = START_Z - travelled(STOPS_AT)
			local eye = Vector3.new(ROAD_X + 7, 2.5, stopZ - 18)
			camera.CFrame = CFrame.lookAt(eye, truckPos + Vector3.new(0, 3.5, 0))
		else
			-- Out of the cab, looking up the path at the light.
			local eye = (truckAt * CFrame.new(-4.5, 5.5, -2)).Position
			camera.CFrame = CFrame.lookAt(eye, cabinLight)
		end
		RunService.RenderStepped:Wait()
	end

	-- Back to the game: black, then the real world fades up beside the dead truck.
	black.BackgroundTransparency = 0
	title.TextTransparency = 1
	subtitle.TextTransparency = 1
	hint.TextTransparency = 1
	if figure then
		figure.destroy()
	end
	for _, sound in voices do
		sound:Destroy()
	end
	folder:Destroy()
	local character = localPlayer.Character
	local head = character and character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		camera.CFrame = head.CFrame
	end
	camera.CameraType = Enum.CameraType.Custom
	if controls then
		pcall(function()
			controls:Enable()
		end)
	end
	if hud and hud:IsA("ScreenGui") then
		hud.Enabled = true
	end
	gui:Destroy()
end

return Trip
