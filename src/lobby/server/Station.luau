--!strict
-- Builds the ranger station lobby: a log station on a stone foundation with a covered porch,
-- a firepit and woodpile, a flagpole, a gravel lot with a bay for each truck (lamp posts, painted
-- lines), a road out through a gate into the pines, and the old pickups that take groups up to
-- the cabin, each with a boarding pad behind it, a board above it and a difficulty sign beside
-- it. Inside: the front desk (where the supplies are), a wood stove with the old driver rocking
-- beside it (OldDriver), a bench, shelves, a coat rack, the trail map with how to play, and a
-- shelf of candles for those who didn't come back. All built from parts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local TruckModel = require(Shared:WaitForChild("TruckModel"))

local OldDriver = require(script.Parent.OldDriver)

local PLANK = Color3.fromRGB(92, 66, 44)
local LOG = Color3.fromRGB(104, 74, 48)
local LOG_DARK = Color3.fromRGB(78, 54, 34)
local DARK = Color3.fromRGB(50, 38, 28)
local ROOF = Color3.fromRGB(46, 52, 44)
local STONE = Color3.fromRGB(96, 94, 90)
local GRAVEL = Color3.fromRGB(92, 88, 82)
local PAINT = Color3.fromRGB(64, 84, 62) -- forest-service green
local CREAM = Color3.fromRGB(226, 214, 180)
local WARM = Color3.fromRGB(255, 200, 140)
local SODIUM = Color3.fromRGB(255, 170, 90)
local BARK = Color3.fromRGB(40, 30, 24)
local NEEDLES = Color3.fromRGB(22, 36, 26)

local WIDTH = 48 -- station, along X
local DEPTH = 32 -- along Z; the door is in the south (+Z) wall, facing the lot
local HEIGHT = 14
local WALL = 1
local DOOR = 8
local LOT_Z = DEPTH / 2 + 32 -- the lot's centre
local TRUCK_Z = DEPTH / 2 + 36 -- where the trucks are parked
local BAY = 22 -- between trucks

local TRUCK_PAINT = {
	Color3.fromRGB(122, 38, 32), -- faded red
	Color3.fromRGB(52, 78, 56), -- forest green
	Color3.fromRGB(176, 140, 52), -- mustard
	Color3.fromRGB(88, 120, 150), -- sky blue
	Color3.fromRGB(150, 120, 90), -- tan
}

local Station = {}

export type Truck = {
	model: Model,
	pad: BasePart, -- stand on this to ride
	label: TextLabel, -- the board above the truck
	sign: TextLabel, -- the painted sign by the pad: how hard the night will be
	signBoard: BasePart,
	signPrompt: ProximityPrompt, -- change it
}

export type Built = {
	trucks: { Truck },
	counter: BasePart, -- the front desk, where the supplies are
	candles: { BasePart }, -- the memorial shelf's candles, unlit
	driver: Model, -- the old driver by the stove (OldDriver)
}

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Wood
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Decorative: no collision, no shadow.
local function trim(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = part(parent, name, size, cf, color, material)
	p.CanCollide = false
	p.CastShadow = false
	return p
end

-- A cylinder lying along `axis` (a unit vector in the XZ plane, or up).
local function log(parent: Instance, name: string, radius: number, length: number, at: Vector3, axis: Vector3, color: Color3, material: Enum.Material?): Part
	local up = if math.abs(axis.Y) > 0.9 then Vector3.xAxis else Vector3.yAxis
	local p = part(parent, name, Vector3.new(length, radius * 2, radius * 2), CFrame.fromMatrix(at, axis, up), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function light(parent: BasePart, color: Color3, range: number, brightness: number, shadows: boolean?)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = shadows ~= false
	l.Parent = parent
end

-- Text on one face of a part.
local function writeOn(p: BasePart, face: Enum.NormalId, text: string, textColor: Color3, size: number?, font: Enum.Font?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.8
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -40, 1, -40)
	label.Position = UDim2.fromOffset(20, 20)
	label.BackgroundTransparency = 1
	label.TextColor3 = textColor
	label.Font = font or Enum.Font.Antique
	label.TextSize = size or 48
	label.TextWrapped = true
	label.Text = text
	label.Parent = gui
	return label
end

-- Round logs stacked up the outside face of a stretch of wall, from a to b (on the ground),
-- between heights y0 and y1, pushed out along `out`.
local function logCourses(parent: Instance, a: Vector3, b: Vector3, out: Vector3, y0: number, y1: number)
	local run = b - a
	local length = run.Magnitude
	if length < 0.5 then
		return
	end
	local axis = run.Unit
	local y = y0 + 0.55
	local i = 0
	while y < y1 - 0.2 do
		i += 1
		local at = (a + b) / 2 + out * (WALL / 2 + 0.1) + Vector3.new(0, y, 0)
		log(parent, "Log", 0.55, length, at, axis, if i % 2 == 0 then LOG else LOG_DARK)
		y += 1.1
	end
end

-- The station: foundation, walls (with an opening for the door and a window each side), log
-- courses outside, log ends crossing at the corners, a gable roof and a chimney.
local function buildShell(model: Model)
	local y = HEIGHT / 2
	local hw, hd = WIDTH / 2, DEPTH / 2
	part(model, "Floor", Vector3.new(WIDTH, 1, DEPTH), CFrame.new(0, -0.5, 0), PLANK, Enum.Material.WoodPlanks)
	-- Stone foundation all round.
	for _, side in { -1, 1 } do
		part(model, "Foundation", Vector3.new(WIDTH + 3, 1.2, 1.4), CFrame.new(0, -0.6, side * (hd + 0.6)), STONE, Enum.Material.Cobblestone)
		part(model, "Foundation", Vector3.new(1.4, 1.2, DEPTH + 3), CFrame.new(side * (hw + 0.6), -0.6, 0), STONE, Enum.Material.Cobblestone)
	end

	-- Walls (the solid parts you bump into), plank-faced inside.
	part(model, "NorthWall", Vector3.new(WIDTH, HEIGHT, WALL), CFrame.new(0, y, -hd), PLANK, Enum.Material.WoodPlanks)
	local side = (WIDTH - DOOR) / 2
	for _, s in { -1, 1 } do
		part(model, "SouthWall", Vector3.new(side, HEIGHT, WALL), CFrame.new(s * (DOOR / 2 + side / 2), y, hd), PLANK, Enum.Material.WoodPlanks)
	end
	part(model, "OverDoor", Vector3.new(DOOR, HEIGHT - 10, WALL), CFrame.new(0, 10 + (HEIGHT - 10) / 2, hd), PLANK, Enum.Material.WoodPlanks)
	for _, s in { -1, 1 } do
		local x = s * hw
		local pieceDepth = (DEPTH - 10) / 2
		for _, z in { -1, 1 } do
			part(model, "SideWall", Vector3.new(WALL, HEIGHT, pieceDepth), CFrame.new(x, y, z * (5 + pieceDepth / 2)), PLANK, Enum.Material.WoodPlanks)
		end
		part(model, "UnderWindow", Vector3.new(WALL, 5, 10), CFrame.new(x, 2.5, 0), PLANK, Enum.Material.WoodPlanks)
		part(model, "OverWindow", Vector3.new(WALL, HEIGHT - 10, 10), CFrame.new(x, 10 + (HEIGHT - 10) / 2, 0), PLANK, Enum.Material.WoodPlanks)
		local glass = part(model, "Window", Vector3.new(0.2, 5, 10), CFrame.new(x, 7.5, 0), Color3.fromRGB(150, 170, 180), Enum.Material.Glass)
		glass.Transparency = 0.6
		-- Window frame, sill and a cross of glazing bars.
		trim(model, "Sill", Vector3.new(1.6, 0.3, 11), CFrame.new(x + s * 0.4, 4.9, 0), DARK)
		trim(model, "WindowHead", Vector3.new(1.4, 0.4, 11), CFrame.new(x + s * 0.3, 10.2, 0), DARK)
		trim(model, "GlazingBar", Vector3.new(0.3, 5, 0.25), CFrame.new(x, 7.5, 0), DARK)
		trim(model, "GlazingBar", Vector3.new(0.3, 0.25, 10), CFrame.new(x, 7.5, 0), DARK)
	end

	-- Log courses on the outside faces, broken round the door and windows.
	local n, so = -hd, hd
	logCourses(model, Vector3.new(-hw - 1, 0, n), Vector3.new(hw + 1, 0, n), -Vector3.zAxis, 0, HEIGHT)
	logCourses(model, Vector3.new(-hw - 1, 0, so), Vector3.new(-DOOR / 2, 0, so), Vector3.zAxis, 0, HEIGHT)
	logCourses(model, Vector3.new(DOOR / 2, 0, so), Vector3.new(hw + 1, 0, so), Vector3.zAxis, 0, HEIGHT)
	logCourses(model, Vector3.new(-DOOR / 2, 0, so), Vector3.new(DOOR / 2, 0, so), Vector3.zAxis, 10, HEIGHT)
	for _, s in { -1, 1 } do
		local x = s * hw
		local out = Vector3.new(s, 0, 0)
		logCourses(model, Vector3.new(x, 0, -hd - 1), Vector3.new(x, 0, -5), out, 0, HEIGHT)
		logCourses(model, Vector3.new(x, 0, 5), Vector3.new(x, 0, hd + 1), out, 0, HEIGHT)
		logCourses(model, Vector3.new(x, 0, -5), Vector3.new(x, 0, 5), out, 0, 5)
		logCourses(model, Vector3.new(x, 0, -5), Vector3.new(x, 0, 5), out, 10, HEIGHT)
	end
	-- Log ends crossing at the corners.
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local corner = Vector3.new(sx * (hw + 0.6), 0, sz * (hd + 0.6))
			local yy = 0.55
			local i = 0
			while yy < HEIGHT do
				i += 1
				local axis = if i % 2 == 0 then Vector3.xAxis else Vector3.zAxis
				log(model, "LogEnd", 0.58, 3, corner + Vector3.new(0, yy, 0), axis, LOG)
				yy += 1.1
			end
		end
	end

	part(model, "Ceiling", Vector3.new(WIDTH, 0.6, DEPTH), CFrame.new(0, HEIGHT + 0.3, 0), PLANK, Enum.Material.WoodPlanks)
	for _, x in { -14, 0, 14 } do
		trim(model, "Beam", Vector3.new(1, 1, DEPTH), CFrame.new(x, HEIGHT - 0.5, 0), DARK)
	end

	-- Gable roof, ridge along X, with stepped boards closing the gable ends.
	local pitch = math.rad(25)
	local span = DEPTH / 2 + 2
	local rise = span * math.tan(pitch)
	for _, s in { -1, 1 } do
		local cf = CFrame.new(0, HEIGHT + 0.6 + rise / 2, s * span / 2) * CFrame.Angles(s * pitch, 0, 0)
		part(model, "Roof", Vector3.new(WIDTH + 4, 0.8, span / math.cos(pitch)), cf, ROOF, Enum.Material.Slate)
	end
	trim(model, "Ridge", Vector3.new(WIDTH + 4, 0.6, 1.2), CFrame.new(0, HEIGHT + 0.6 + rise + 0.2, 0), DARK)
	local boards = 4
	for _, s in { -1, 1 } do
		for i = 1, boards do
			local mid = (i - 0.5) / boards * rise
			local width = DEPTH * (1 - mid / rise)
			part(model, "Gable", Vector3.new(WALL, rise / boards, width), CFrame.new(s * WIDTH / 2, HEIGHT + 0.6 + mid, 0), LOG)
		end
	end
	-- The chimney over the stove, smoking.
	local chimney = part(model, "Chimney", Vector3.new(3, 14, 3), CFrame.new(-hw + 4, HEIGHT + 6, -hd + 4), STONE, Enum.Material.Cobblestone)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(120, 118, 116))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 6) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(4, 6)
	smoke.Rate = 3
	smoke.Speed = NumberRange.new(2, 3)
	smoke.SpreadAngle = Vector2.new(15, 15)
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.Parent = chimney
end

-- The covered porch in front of the door: deck, steps, posts, railings, a sloping roof, the
-- station sign on its front edge, a bench, a lantern and the notice board.
local function buildPorch(model: Model)
	local hd = DEPTH / 2
	local front = hd + 7
	part(model, "PorchDeck", Vector3.new(19, 0.6, 7), CFrame.new(0, -0.3, hd + 3.5), PLANK, Enum.Material.WoodPlanks)
	part(model, "PorchStep", Vector3.new(7, 0.4, 1.2), CFrame.new(0, -0.6, front + 0.6), PLANK, Enum.Material.WoodPlanks)
	for _, x in { -9, 9 } do
		part(model, "PorchPost", Vector3.new(0.7, 11, 0.7), CFrame.new(x, 5.5, front - 0.4), LOG)
		part(model, "PorchPost", Vector3.new(0.7, 12.2, 0.7), CFrame.new(x, 6.1, hd + 0.8), LOG)
	end
	-- Railings along the front (with a gap at the steps) and the sides.
	for _, r in { { -9, -3.5 }, { 3.5, 9 } } do
		local x0, x1 = r[1], r[2]
		part(model, "Rail", Vector3.new(x1 - x0, 0.3, 0.3), CFrame.new((x0 + x1) / 2, 3, front - 0.4), LOG_DARK)
		for x = x0 + 0.8, x1 - 0.3, 0.8 do
			trim(model, "Baluster", Vector3.new(0.18, 3, 0.18), CFrame.new(x, 1.5, front - 0.4), LOG_DARK)
		end
	end
	for _, x in { -9, 9 } do
		part(model, "Rail", Vector3.new(0.3, 0.3, 6), CFrame.new(x, 3, hd + 3.6), LOG_DARK)
	end
	-- The roof slopes down from the wall to the posts.
	local drop = 1.4
	local length = 7.8
	local tilt = math.atan(drop / length)
	part(model, "PorchRoof", Vector3.new(21, 0.5, length / math.cos(tilt)), CFrame.new(0, 12.6 - drop / 2, hd + length / 2) * CFrame.Angles(tilt, 0, 0), ROOF, Enum.Material.Slate)
	local fascia = part(model, "Sign", Vector3.new(16, 1.8, 0.3), CFrame.new(0, 10.6, front + 0.05), PAINT)
	writeOn(fascia, Enum.NormalId.Back, "HOLLOW PINES RANGER STATION", CREAM, 44)

	-- A bench by the wall and a lantern hanging by the door.
	part(model, "PorchBench", Vector3.new(5, 0.4, 1.4), CFrame.new(-6, 1.8, hd + 1.4), PLANK)
	part(model, "PorchBenchBack", Vector3.new(5, 1.4, 0.3), CFrame.new(-6, 2.9, hd + 0.75), PLANK)
	for _, x in { -8, -4 } do
		part(model, "PorchBenchLeg", Vector3.new(0.3, 1.6, 1.2), CFrame.new(x, 0.8, hd + 1.4), DARK)
	end
	trim(model, "LanternChain", Vector3.new(0.1, 1.6, 0.1), CFrame.new(5, 11.2, hd + 2.5), DARK, Enum.Material.Metal)
	local lantern = trim(model, "PorchLantern", Vector3.new(0.8, 1.1, 0.8), CFrame.new(5, 9.9, hd + 2.5), WARM, Enum.Material.Neon)
	light(lantern, WARM, 26, 1.3)

	-- The notice board: the trail rules, and the missing.
	local board = part(model, "NoticeBoard", Vector3.new(6, 4.4, 0.3), CFrame.new(6.5, 5.6, hd + 1.35), Color3.fromRGB(140, 104, 70), Enum.Material.Fabric)
	local notices = {
		{ -1.6, 0.9, "MISSING\n\nFour friends, last seen on the Hollow Pines road. Their truck was found with its headlights still on." },
		{ 1.3, 0.6, "TRAIL CLOSED\nAFTER DARK\n\nDo not leave the road." },
		{ -0.2, -1.2, "If you hear knocking,\ndo not answer it." },
	}
	for _, n in notices do
		local paper = trim(model, "Notice", Vector3.new(2.2, 1.9, 0.05), board.CFrame * CFrame.new(n[1], n[2], 0.18) * CFrame.Angles(0, 0, math.rad(n[1] * 3)), CREAM, Enum.Material.SmoothPlastic)
		writeOn(paper, Enum.NormalId.Back, n[3], Color3.fromRGB(40, 30, 22), 14, Enum.Font.SpecialElite)
	end
end

local function buildInside(model: Model): (BasePart, { BasePart })
	local hw, hd = WIDTH / 2, DEPTH / 2
	-- Front desk across the back of the room; the supplies are kept behind it.
	local desk = part(model, "Desk", Vector3.new(16, 3.6, 3), CFrame.new(0, 1.8, -hd + 7), DARK)
	part(model, "DeskTop", Vector3.new(16.6, 0.3, 3.6), desk.CFrame * CFrame.new(0, 1.95, 0), PLANK)
	local bell = part(model, "Bell", Vector3.new(0.6, 0.6, 0.6), desk.CFrame * CFrame.new(5, 2.4, 0), Color3.fromRGB(180, 150, 70), Enum.Material.Metal)
	bell.Shape = Enum.PartType.Ball
	local radio = part(model, "Radio", Vector3.new(2, 1.2, 1.2), desk.CFrame * CFrame.new(-5, 2.7, 0), Color3.fromRGB(40, 44, 40), Enum.Material.Metal)
	light(radio, Color3.fromRGB(255, 90, 60), 4, 0.6, false)
	local deskLamp = trim(model, "DeskLantern", Vector3.new(0.7, 1, 0.7), desk.CFrame * CFrame.new(0, 2.6, 0), WARM, Enum.Material.Neon)
	light(deskLamp, WARM, 14, 0.9)
	local supplies = part(model, "SuppliesSign", Vector3.new(4, 1, 0.2), desk.CFrame * CFrame.new(0, 0.6, 1.61), PAINT)
	writeOn(supplies, Enum.NormalId.Back, "SUPPLIES", CREAM, 28)
	-- Shelves behind the desk with boxes and tins.
	for i = 0, 2 do
		local y = 2.5 + i * 2.6
		part(model, "Shelf", Vector3.new(12, 0.25, 1.6), CFrame.new(0, y, -hd + 1.3), PLANK)
		for j = 0, 5 do
			trim(model, "Goods", Vector3.new(1.2, 1.4, 1), CFrame.new(-5 + j * 2, y + 0.8, -hd + 1.3), if (i + j) % 3 == 0 then Color3.fromRGB(150, 50, 40) elseif (i + j) % 3 == 1 then Color3.fromRGB(70, 90, 70) else Color3.fromRGB(170, 150, 110), Enum.Material.SmoothPlastic)
		end
	end
	-- A wall clock above the shelves, stopped.
	local clock = part(model, "WallClock", Vector3.new(0.3, 2.4, 2.4), CFrame.new(0, 11.5, -hd + 0.65) * CFrame.Angles(0, math.rad(90), 0), CREAM, Enum.Material.SmoothPlastic)
	clock.Shape = Enum.PartType.Cylinder

	-- Wood stove in the north-west corner, glowing.
	local stove = part(model, "Stove", Vector3.new(4, 4, 4), CFrame.new(-hw + 4, 2, -hd + 4), Color3.fromRGB(30, 30, 32), Enum.Material.Metal)
	part(model, "StovePipe", Vector3.new(1, HEIGHT - 4, 1), stove.CFrame * CFrame.new(0, HEIGHT / 2, 0), Color3.fromRGB(30, 30, 32), Enum.Material.Metal)
	local fire = part(model, "Fire", Vector3.new(2.4, 1.2, 0.2), stove.CFrame * CFrame.new(0, -0.3, 2.01), Color3.fromRGB(255, 120, 40), Enum.Material.Neon)
	fire.CanCollide = false
	light(fire, Color3.fromRGB(255, 130, 60), 22, 1.6)

	-- A rug, a bench under the west window, and a coat rack by the door.
	trim(model, "Rug", Vector3.new(14, 0.05, 9), CFrame.new(0, 0.03, 3), Color3.fromRGB(110, 40, 34), Enum.Material.Fabric)
	trim(model, "RugBorder", Vector3.new(15, 0.04, 10), CFrame.new(0, 0.02, 3), Color3.fromRGB(70, 50, 30), Enum.Material.Fabric)
	part(model, "Bench", Vector3.new(3, 0.5, 12), CFrame.new(-hw + 2.5, 2, 0), PLANK)
	for _, z in { -5, 5 } do
		part(model, "BenchLeg", Vector3.new(2.4, 1.8, 0.5), CFrame.new(-hw + 2.5, 0.9, z), DARK)
	end
	part(model, "CoatRack", Vector3.new(0.3, 7, 0.3), CFrame.new(DOOR / 2 + 2.5, 3.5, hd - 2), DARK)
	trim(model, "Coat", Vector3.new(1.6, 3.4, 0.8), CFrame.new(DOOR / 2 + 2.5, 4.8, hd - 2.4), Color3.fromRGB(70, 74, 52), Enum.Material.Fabric)
	trim(model, "Hat", Vector3.new(1.4, 0.5, 1.4), CFrame.new(DOOR / 2 + 2.5, 7.2, hd - 2), Color3.fromRGB(110, 86, 52), Enum.Material.Fabric)

	-- Trail map on the east wall, with how to play.
	local board = part(model, "TrailMap", Vector3.new(0.3, 8, 9.5), CFrame.new(hw - 0.7, 7, -10.5), Color3.fromRGB(196, 182, 140), Enum.Material.Fabric)
	writeOn(
		board,
		Enum.NormalId.Left,
		"HOLLOW PINES TRAIL\nCLOSED AFTER DARK\n\n1 to 4 players. Step onto the pad behind a truck to ride up to the cabin together. "
			.. "The truck leaves when it's full, or "
			.. tostring(Config.Lobby.DepartSeconds)
			.. " seconds after the first person climbs on.\n\nSurvive until 3:00 AM. Find the clues. Pick the right door.",
		Color3.fromRGB(40, 30, 22),
		22
	)

	-- The memorial shelf on the west wall: a candle for each one who didn't come back.
	local shelf = part(model, "MemorialShelf", Vector3.new(1.4, 0.3, 9), CFrame.new(-hw + 1.2, 4.6, -9), DARK)
	local plaque = trim(model, "MemorialPlaque", Vector3.new(0.1, 1.2, 5), CFrame.new(-hw + 0.56, 6.2, -9), Color3.fromRGB(150, 120, 60), Enum.Material.Metal)
	writeOn(plaque, Enum.NormalId.Right, "For those who didn't come back", Color3.fromRGB(40, 30, 20), 22)
	local candles = {}
	for i = 0, 7 do
		local candle = trim(model, "MemorialCandle", Vector3.new(0.35, 0.8, 0.35), shelf.CFrame * CFrame.new(0, 0.55, -3.9 + i * 1.1), Color3.fromRGB(230, 220, 196), Enum.Material.SmoothPlastic)
		table.insert(candles, candle)
	end

	-- Hanging lamp over the middle of the room.
	trim(model, "LampCord", Vector3.new(0.15, 3, 0.15), CFrame.new(0, HEIGHT - 1.5, 2), DARK)
	local bulb = trim(model, "Lamp", Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, HEIGHT - 3.4, 2), Color3.fromRGB(255, 225, 170), Enum.Material.Neon)
	bulb.Shape = Enum.PartType.Ball
	light(bulb, Color3.fromRGB(255, 210, 150), 34, 1.2)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(6, 0.2, 6)
	spawn.CFrame = CFrame.new(0, 0.1, 4)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = model
	return desk, candles
end

-- Outside the station: a firepit with log seats, a woodpile with an axe in a stump, a flagpole.
local function buildYard(model: Model)
	local pit = Vector3.new(-32, -0.8, DEPTH / 2 + 10)
	for i = 0, 9 do
		local a = i * math.pi * 2 / 10
		local stone = part(model, "PitStone", Vector3.new(1.3, 1.3, 1.3), CFrame.new(pit + Vector3.new(math.cos(a) * 2.6, 0.4, math.sin(a) * 2.6)), STONE, Enum.Material.Slate)
		stone.Shape = Enum.PartType.Ball
	end
	for i = 0, 2 do
		log(model, "FireLog", 0.3, 3, pit + Vector3.new(0, 0.5, 0), Vector3.new(math.cos(i * 2.1), 0, math.sin(i * 2.1)), BARK)
	end
	local embers = trim(model, "Embers", Vector3.new(2.6, 0.3, 2.6), CFrame.new(pit + Vector3.new(0, 0.3, 0)), Color3.fromRGB(255, 110, 40), Enum.Material.Neon)
	light(embers, Color3.fromRGB(255, 130, 60), 30, 1.8)
	local flames = Instance.new("Fire")
	flames.Heat = 6
	flames.Size = 4
	flames.Color = Color3.fromRGB(255, 140, 60)
	flames.SecondaryColor = Color3.fromRGB(200, 60, 20)
	flames.Parent = embers
	for _, a in { 0.4, 2.4, 4.4 } do
		log(model, "LogSeat", 0.7, 5, pit + Vector3.new(math.cos(a) * 6.5, 0.6, math.sin(a) * 6.5), Vector3.new(-math.sin(a), 0, math.cos(a)), LOG)
	end

	-- Woodpile against the east wall, and the stump with the axe.
	local pile = Vector3.new(WIDTH / 2 + 3.4, -1, 6)
	for row = 0, 3 do
		for i = 0, 6 - row do
			log(model, "Firewood", 0.45, 3, pile + Vector3.new(0, 0.45 + row * 0.85, -2.7 + i * 0.95 + row * 0.45), Vector3.xAxis, if (row + i) % 2 == 0 then LOG else LOG_DARK)
		end
	end
	local stump = log(model, "Stump", 1.1, 1.6, Vector3.new(WIDTH / 2 + 6, -0.2, 14), Vector3.yAxis, BARK)
	-- The axe: its head bitten into the top of the stump, the handle leaning up and out.
	local head = stump.Position + Vector3.new(0, 0.75, 0)
	part(model, "AxeHead", Vector3.new(0.9, 0.5, 0.2), CFrame.new(head), Color3.fromRGB(80, 80, 84), Enum.Material.Metal)
	part(model, "AxeHandle", Vector3.new(0.18, 2.6, 0.18), CFrame.new(head + Vector3.new(0.73, 1.08, 0)) * CFrame.Angles(0, 0, math.rad(-34)), LOG_DARK)

	-- Flagpole with a torn flag.
	local poleAt = Vector3.new(16, -0.8, DEPTH / 2 + 12)
	part(model, "Flagpole", Vector3.new(0.5, 28, 0.5), CFrame.new(poleAt + Vector3.new(0, 14, 0)), Color3.fromRGB(170, 168, 160), Enum.Material.Metal)
	trim(model, "Flag", Vector3.new(0.1, 3.4, 5.4), CFrame.new(poleAt + Vector3.new(0, 25.5, 2.8)), PAINT, Enum.Material.Fabric)
	trim(model, "FlagTear", Vector3.new(0.12, 1.2, 1.2), CFrame.new(poleAt + Vector3.new(0, 24.4, 5)), Color3.fromRGB(24, 26, 24), Enum.Material.Fabric)
end

-- The lot: gravel, bay lines, lamp posts, and the road out through a gate.
local function buildLot(model: Model, trucks: number)
	local width = math.max(130, trucks * BAY + 30)
	part(model, "Path", Vector3.new(7, 0.2, 9), CFrame.new(0, -0.9, DEPTH / 2 + 11), GRAVEL, Enum.Material.Pebble)
	part(model, "Lot", Vector3.new(width, 0.2, 50), CFrame.new(0, -0.9, LOT_Z), GRAVEL, Enum.Material.Pebble)
	for i = 0, trucks do
		local x = (i - trucks / 2) * BAY
		trim(model, "BayLine", Vector3.new(0.4, 0.05, 22), CFrame.new(x, -0.78, TRUCK_Z - 2), Color3.fromRGB(200, 196, 180), Enum.Material.SmoothPlastic)
	end
	for _, x in { -width / 2 + 10, 0, width / 2 - 10 } do
		local postAt = Vector3.new(x, -0.8, LOT_Z + 22)
		part(model, "LampPost", Vector3.new(0.6, 16, 0.6), CFrame.new(postAt + Vector3.new(0, 8, 0)), Color3.fromRGB(40, 40, 42), Enum.Material.Metal)
		part(model, "LampArm", Vector3.new(0.4, 0.4, 3), CFrame.new(postAt + Vector3.new(0, 15.8, -1.4)), Color3.fromRGB(40, 40, 42), Enum.Material.Metal)
		local head = trim(model, "LampHead", Vector3.new(1.4, 0.5, 1.8), CFrame.new(postAt + Vector3.new(0, 15.5, -2.8)), SODIUM, Enum.Material.Neon)
		light(head, SODIUM, 44, 1.3)
	end
	-- The road away from the lot, into the pines, with a gate and its barrier arm raised.
	local roadStart = LOT_Z + 25
	part(model, "Road", Vector3.new(14, 0.2, 220), CFrame.new(0, -0.9, roadStart + 110), Color3.fromRGB(70, 66, 60), Enum.Material.Pebble)
	for _, x in { -2.5, 2.5 } do
		trim(model, "Rut", Vector3.new(1.4, 0.05, 220), CFrame.new(x, -0.78, roadStart + 110), Color3.fromRGB(52, 48, 42), Enum.Material.Mud)
	end
	for _, x in { -8.5, 8.5 } do
		part(model, "GatePost", Vector3.new(1, 5, 1), CFrame.new(x, 1.7, roadStart + 2), LOG_DARK)
	end
	local arm = part(model, "GateArm", Vector3.new(0.5, 0.5, 15), CFrame.new(-8.5, 4.2, roadStart + 2) * CFrame.Angles(0, math.rad(-90), 0) * CFrame.Angles(math.rad(70), 0, 0) * CFrame.new(0, 0, -7.5), Color3.fromRGB(200, 40, 30))
	arm.CanCollide = false
end

-- A tiered pine, like the ones round the cabin.
local function pine(parent: Instance, base: Vector3, height: number, rng: Random)
	local tree = Instance.new("Model")
	tree.Name = "Pine"
	log(tree, "Trunk", 0.7, height, base + Vector3.new(0, height / 2, 0), Vector3.yAxis, BARK)
	for i = 0, 4 do
		local t = i / 5
		local width = height * 0.42 * (1 - t * 0.8)
		local tier = part(tree, "Needles", Vector3.new(width, height * 0.14, width), CFrame.new(base + Vector3.new(0, height * (0.32 + t * 0.6), 0)) * CFrame.Angles(0, math.rad(i * 23 + rng:NextNumber(0, 40)), 0), NEEDLES, Enum.Material.Grass)
		tier.CanCollide = false
	end
	tree.Parent = parent
end

-- One pickup in its bay, facing the road (+Z), with its boarding pad on the ground behind the
-- bed and a board above it.
local function buildTruck(parent: Instance, index: number, at: CFrame): Truck
	local model = TruckModel.build(at * CFrame.Angles(0, math.pi, 0), {
		body = TRUCK_PAINT[(index - 1) % #TRUCK_PAINT + 1],
		headlightBrightness = 1.2,
	})
	model.Name = `Truck{index}`

	local pad = part(model, "BoardingPad", Vector3.new(9, 0.2, 7), at * CFrame.new(0, 0.1, -13), Color3.fromRGB(230, 210, 140), Enum.Material.Neon)
	pad.Transparency = 0.6
	pad.CanCollide = false
	local number = trim(model, "BayNumber", Vector3.new(4, 0.05, 2.4), at * CFrame.new(0, 0.12, -17.5), Color3.fromRGB(200, 196, 180), Enum.Material.SmoothPlastic)
	writeOn(number, Enum.NormalId.Top, tostring(index), Color3.fromRGB(40, 36, 30), 70, Enum.Font.Antique)

	local boardPart = trim(model, "Board", Vector3.new(1, 1, 1), at * CFrame.new(0, 11, -4), Color3.new(), Enum.Material.SmoothPlastic)
	boardPart.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 78)
	gui.MaxDistance = 140
	gui.Parent = boardPart
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(18, 14, 10)
	label.BackgroundTransparency = 0.25
	label.TextColor3 = CREAM
	label.Font = Enum.Font.Fondamento
	label.TextSize = 20
	label.TextWrapped = true
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = label
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.fromRGB(176, 140, 72)
	edge.Transparency = 0.5
	edge.Parent = label

	-- The difficulty sign: a painted board on a post at the side of the pad, facing the station.
	part(model, "SignPost", Vector3.new(0.35, 4.6, 0.35), at * CFrame.new(6.6, 2.3, -15.2), LOG_DARK)
	local signBoard = part(model, "DifficultySign", Vector3.new(3.8, 1.9, 0.22), at * CFrame.new(6.6, 4.3, -15.42), DARK, Enum.Material.WoodPlanks)
	trim(model, "SignEdge", Vector3.new(4.0, 2.1, 0.12), at * CFrame.new(6.6, 4.3, -15.3), LOG, Enum.Material.Wood)
	local sign = writeOn(signBoard, Enum.NormalId.Front, "", CREAM, 26, Enum.Font.Fondamento)
	;(sign.Parent :: SurfaceGui).PixelsPerStud = 64
	sign.Size = UDim2.new(1, -16, 1, -12)
	sign.Position = UDim2.fromOffset(8, 6)
	sign.RichText = true
	local signPrompt = Instance.new("ProximityPrompt")
	signPrompt.ActionText = "Change"
	signPrompt.ObjectText = "How hard tonight is"
	signPrompt.HoldDuration = 0
	signPrompt.MaxActivationDistance = 10
	signPrompt.RequiresLineOfSight = false
	signPrompt.Parent = signBoard

	model.Parent = parent
	return { model = model, pad = pad, label = label, sign = sign, signBoard = signBoard, signPrompt = signPrompt }
end

-- Build everything.
function Station.build(): Built
	local root = Instance.new("Model")
	root.Name = "RangerStation"

	part(root, "Ground", Vector3.new(600, 1, 600), CFrame.new(0, -1.5, 0), Config.Forest.Ground, Enum.Material.Ground)
	buildShell(root)
	buildPorch(root)
	local counter, candles = buildInside(root)
	-- The old driver in his rocking chair by the stove, turned to the room and the door.
	local driver = OldDriver.build(root, CFrame.lookAt(Vector3.new(-15, 0, -8), Vector3.new(0, 0, 6)))
	buildYard(root)
	local count = Config.Lobby.Trucks
	buildLot(root, count)

	-- Pines all round, clear of the station, the yard, the lot and the road.
	local rng = Random.new(7)
	local trees = Instance.new("Folder")
	trees.Name = "Pines"
	trees.Parent = root
	local lotHalf = math.max(130, count * BAY + 30) / 2
	local placed = 0
	while placed < 190 do
		local x = rng:NextNumber(-220, 220)
		local z = rng:NextNumber(-160, 300)
		local inClearing = math.abs(x) < lotHalf + 8 and z > -DEPTH / 2 - 16 and z < LOT_Z + 34
		local onRoad = math.abs(x) < 14 and z >= LOT_Z + 20
		if not inClearing and not onRoad then
			placed += 1
			pine(trees, Vector3.new(x, -1, z), rng:NextNumber(30, 54), rng)
		end
	end
	for _ = 1, 14 do
		local x = rng:NextNumber(-lotHalf - 20, lotHalf + 20)
		local z = if rng:NextNumber() < 0.5 then rng:NextNumber(-DEPTH / 2 - 26, -DEPTH / 2 - 14) else rng:NextNumber(LOT_Z + 28, LOT_Z + 40)
		if math.abs(x) > 16 then
			local s = rng:NextNumber(1.5, 4)
			local rock = part(root, "Rock", Vector3.new(s * 1.4, s, s * 1.2), CFrame.new(x, -1 + s * 0.35, z) * CFrame.Angles(0, rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)), STONE, Enum.Material.Slate)
			rock.Shape = Enum.PartType.Ball
		end
	end

	local trucks = {}
	for i = 1, count do
		local x = (i - (count + 1) / 2) * BAY
		table.insert(trucks, buildTruck(root, i, CFrame.new(x, -0.8, TRUCK_Z)))
	end

	root.Parent = workspace
	return { trucks = trucks, counter = counter, candles = candles, driver = driver }
end

return Station
