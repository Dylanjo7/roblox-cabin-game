--!strict
-- The two pieces on the table's clock track, drawn and animated here (the server only says where
-- they are, as CandleStep / HollowStep attributes on the ring). Each piece stands on a brass
-- stick coming up through the track from its own wheel inside the table. When a piece moves its
-- wheel turns one ratchet step at a time (a clunk, a little overshoot, settle) with a mechanical
-- sound, and that wheel's cog spins where it pokes out of the table's rim. The Candle's wheel
-- goes first, then the Hollow Man's. He stands rigid on his stick; only his head turns to watch you.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClockTrack = require(Shared:WaitForChild("ClockTrack"))
local Config = require(Shared:WaitForChild("Config"))

local Audio = require(script.Parent.Audio)
local HollowManRig = require(script.Parent.HollowManRig)

local BRASS = Color3.fromRGB(176, 140, 72)
local WAX = Color3.fromRGB(236, 226, 196)

local TablePieces = {}

local hollowStepped = Instance.new("BindableEvent")
-- Fires each time the Hollow Man's figure lands a step on the track.
TablePieces.HollowStepped = hollowStepped.Event

local localPlayer = Players.LocalPlayer
local ring: Model? = nil
local candleParts: { BasePart } = {}
local candleRest: { CFrame } = {}
local flameLight: PointLight
local rig: HollowManRig.Rig
local base: BasePart

type Wheel = { stick: BasePart, collar: BasePart, cog: { BasePart }, cogRest: { CFrame }, cogAngle: number, sign: number }
local candleWheel: Wheel
local hollowWheel: Wheel

local candleShown = 0 -- may be fractional while moving
local hollowShown = -1
local candleTurning = false
local hollowTurning = false
local running = false

local function piecePart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function cylinder(parent: Instance, name: string, radius: number, height: number, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = piecePart(parent, name, Vector3.new(height, radius * 2, radius * 2), cf * CFrame.Angles(0, 0, math.rad(90)), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- The Candle: a brass dish, a dripping candle and its flame (built at the origin).
local function buildCandle()
	local model = Instance.new("Model")
	model.Name = "CandlePiece"
	cylinder(model, "Dish", 0.36, 0.08, CFrame.new(0, 0.04, 0), BRASS, Enum.Material.Metal)
	piecePart(model, "DishHandle", Vector3.new(0.08, 0.06, 0.25), CFrame.new(0.4, 0.06, 0), BRASS, Enum.Material.Metal)
	cylinder(model, "Wax", 0.15, 0.75, CFrame.new(0, 0.45, 0), WAX)
	for i, a in { 0.4, 2.3, 4.1 } do
		piecePart(model, "Drip", Vector3.new(0.06, 0.18 + i * 0.06, 0.06), CFrame.Angles(0, a, 0) * CFrame.new(0, 0.7 - i * 0.03, 0.15), WAX)
	end
	piecePart(model, "Wick", Vector3.new(0.03, 0.08, 0.03), CFrame.new(0, 0.86, 0), Color3.fromRGB(20, 16, 12))
	local flame = piecePart(model, "Flame", Vector3.new(0.12, 0.22, 0.12), CFrame.new(0, 0.99, 0), Color3.fromRGB(255, 170, 60), Enum.Material.Neon)
	flame.Shape = Enum.PartType.Ball
	flameLight = Instance.new("PointLight")
	flameLight.Color = Color3.fromRGB(255, 180, 90)
	flameLight.Range = 7
	flameLight.Brightness = 1.6
	flameLight.Parent = flame
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			table.insert(candleParts, p)
			table.insert(candleRest, p.CFrame)
		end
	end
	model.Parent = workspace
end

-- The Hollow Man's piece: the same figure that walks the cabin, in miniature, on a base.
local function buildFigure()
	rig = HollowManRig.new(Config.Table.FigurineScale)
	for _, inst in rig.model:GetDescendants() do
		if inst:IsA("BasePart") then
			inst.CastShadow = false
		elseif inst:IsA("ParticleEmitter") or inst:IsA("Light") then
			inst:Destroy() -- too big at this scale
		end
	end
	rig.model.Name = "HollowManPiece"
	rig.model.Parent = workspace
	base = cylinder(workspace, "HollowManPieceBase", 0.3, 0.08, CFrame.new(), Color3.fromRGB(20, 18, 18), Enum.Material.Metal)
end

-- A piece's stick and collar, and the cog of its wheel (built at the origin; moved every frame).
local function buildWheel(name: string, sign: number): Wheel
	local stick = piecePart(workspace, `{name}Stick`, Vector3.new(0.07, Config.Table.PieceRaise + 0.3, 0.07), CFrame.new(), BRASS, Enum.Material.Metal)
	local collar = cylinder(workspace, `{name}Collar`, 0.11, 0.04, CFrame.new(), Color3.fromRGB(120, 96, 52), Enum.Material.Metal)
	local cogModel = Instance.new("Model")
	cogModel.Name = `{name}Cog`
	local cog: { BasePart } = {}
	local cogRest: { CFrame } = {}
	local function add(p: BasePart)
		table.insert(cog, p)
		table.insert(cogRest, p.CFrame)
	end
	add(cylinder(cogModel, "Hub", 0.3, 0.12, CFrame.new(), BRASS, Enum.Material.Metal))
	for i = 1, 10 do
		local a = i * math.pi * 2 / 10
		add(piecePart(cogModel, "Tooth", Vector3.new(0.09, 0.12, 0.12), CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 0.34), BRASS, Enum.Material.Metal))
	end
	cogModel.Parent = workspace
	return { stick = stick, collar = collar, cog = cog, cogRest = cogRest, cogAngle = 0, sign = sign }
end

local function target(name: string): number
	local r = ring
	local v = r and r:GetAttribute(name)
	return if typeof(v) == "number" then v else (if name == "HollowStep" then -1 else 0)
end

-- A ratchet step: snaps forward, overshoots a touch, settles back (easeOutBack).
local function ratchet(u: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (u - 1) ^ 3 + c1 * (u - 1) ^ 2
end

-- Turn a wheel from step a to step b over seconds, calling set(value) each frame.
local function turn(a: number, b: number, seconds: number, set: (number) -> ())
	local t = 0
	while t < seconds do
		t += RunService.Heartbeat:Wait()
		local u = math.clamp(t / seconds, 0, 1)
		set(a + (b - a) * ratchet(u))
	end
	set(b)
end

-- Play out every change, one ratchet step at a time: the Candle's wheel first, then his.
local function run()
	if running then
		return
	end
	running = true
	while true do
		local candleTarget = target("CandleStep")
		local hollowTarget = target("HollowStep")
		if candleTarget < candleShown - 0.01 then
			candleShown = candleTarget -- a new run: straight back to 9:00
		elseif hollowTarget == -1 and hollowShown ~= -1 then
			hollowShown = -1 -- a new run: back off the track
		elseif candleTarget > candleShown + 0.01 then
			local from = math.floor(candleShown + 0.5)
			Audio.play("ratchet", 0.6, candleWheel.collar)
			candleTurning = true
			turn(from, from + 1, Config.Table.CandleStepSeconds, function(v: number)
				candleShown = v
			end)
			candleTurning = false
		elseif math.abs(hollowTarget - hollowShown) > 0.01 then
			local from = math.floor(hollowShown + 0.5)
			local to = if hollowTarget > hollowShown then from + 1 else from - 1
			Audio.play("ratchet", 0.7, hollowWheel.collar, 0.85) -- his wheel is heavier
			hollowTurning = true
			turn(from, to, Config.Table.HollowStepSeconds, function(v: number)
				hollowShown = v
			end)
			hollowTurning = false
			hollowStepped:Fire()
		else
			break
		end
	end
	running = false
end

-- Place a wheel's stick under its piece and spin its cog (in the rim behind the stand) while it turns.
local function placeWheel(wheel: Wheel, pivot: CFrame, step: number, radius: number, turning: boolean, dt: number)
	local raise = Config.Table.PieceRaise
	local at = pivot * ClockTrack.localCFrame(step, radius)
	wheel.stick.CFrame = at * CFrame.new(0, (raise - 0.3) / 2, 0)
	wheel.collar.CFrame = at * CFrame.new(0, 0.02, 0) * CFrame.Angles(0, 0, math.rad(90))
	if turning then
		wheel.cogAngle += dt * 9 * wheel.sign
	end
	local cogAt = pivot * CFrame.Angles(0, math.pi + wheel.sign * 0.09, 0) * CFrame.new(0, Config.Table.TopHeight - 0.25, Config.Table.Radius) * CFrame.Angles(0, wheel.cogAngle, 0)
	local cframes = table.create(#wheel.cog)
	for i, rest in wheel.cogRest do
		cframes[i] = cogAt * rest
	end
	workspace:BulkMoveTo(wheel.cog, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

local function headPosition(): Vector3?
	local character = localPlayer.Character
	local head = character and character:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head.Position else nil
end

function TablePieces.init()
	buildCandle()
	buildFigure()
	candleWheel = buildWheel("Candle", 1)
	hollowWheel = buildWheel("HollowMan", -1)
	task.spawn(function()
		local tableModel = workspace:WaitForChild("ParlorTable")
		local r = tableModel:WaitForChild("Ring") :: Model
		ring = r
		candleShown = target("CandleStep")
		hollowShown = target("HollowStep")
		r:GetAttributeChangedSignal("CandleStep"):Connect(function()
			task.spawn(run)
		end)
		r:GetAttributeChangedSignal("HollowStep"):Connect(function()
			task.spawn(run)
		end)
	end)

	RunService.RenderStepped:Connect(function(dt: number)
		local r = ring
		if not r then
			return
		end
		local pivot = r:GetPivot()
		local raise = CFrame.new(0, Config.Table.PieceRaise, 0)
		placeWheel(candleWheel, pivot, candleShown, Config.Table.CandleTrackRadius, candleTurning, dt)
		placeWheel(hollowWheel, pivot, hollowShown, Config.Table.HollowTrackRadius, hollowTurning, dt)

		local candleAt = pivot * ClockTrack.localCFrame(candleShown, Config.Table.CandleTrackRadius) * raise
		local cframes = table.create(#candleParts)
		for i, rest in candleRest do
			cframes[i] = candleAt * rest
		end
		workspace:BulkMoveTo(candleParts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		flameLight.Brightness = 1.5 + math.noise(os.clock() * 6) * 0.6

		-- He faces the way the clock runs (the track frame's +X), rigid on his stick.
		local hollowAt = pivot * ClockTrack.localCFrame(hollowShown, Config.Table.HollowTrackRadius) * raise * CFrame.Angles(0, -math.pi / 2, 0)
		base.CFrame = hollowAt * CFrame.new(0, 0.04, 0) * CFrame.Angles(0, 0, math.rad(90))
		HollowManRig.pose(rig, hollowAt * CFrame.new(0, 0.08, 0), dt, 0, false, if hollowTurning then nil else headPosition())
	end)
end

return TablePieces
