--!strict
-- Builds the ranger station lobby: the station itself (desk, stove, bench, trail map with the
-- rules), a gravel lot in front, and the trucks that take groups up to the cabin. Placeholder
-- geometry made of parts, like the cabin place.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local PLANK = Color3.fromRGB(92, 66, 44)
local LOG = Color3.fromRGB(110, 78, 50)
local DARK = Color3.fromRGB(50, 38, 28)
local ROOF = Color3.fromRGB(46, 52, 44)
local GRAVEL = Color3.fromRGB(96, 92, 86)
local PAINT = Color3.fromRGB(64, 84, 62) -- forest-service green
local CREAM = Color3.fromRGB(226, 214, 180)

local WIDTH = 48 -- station, along X
local DEPTH = 32 -- along Z; the door is in the south (+Z) wall, facing the lot
local HEIGHT = 14
local WALL = 1
local DOOR = 8

local Station = {}

export type Truck = {
	model: Model,
	pad: BasePart, -- stand on this to ride
	label: TextLabel, -- the board above the truck
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

local function light(parent: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = true
	l.Parent = parent
end

-- Text on one face of a part.
local function writeOn(p: BasePart, face: Enum.NormalId, text: string, textColor: Color3, size: number?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -40, 1, -40)
	label.Position = UDim2.fromOffset(20, 20)
	label.BackgroundTransparency = 1
	label.TextColor3 = textColor
	label.Font = Enum.Font.Antique
	label.TextSize = size or 48
	label.TextWrapped = true
	label.Text = text
	label.Parent = gui
end

-- Walls with a door gap in the south wall and a window in each side wall.
local function buildShell(model: Model)
	local y = HEIGHT / 2
	part(model, "Floor", Vector3.new(WIDTH, 1, DEPTH), CFrame.new(0, -0.5, 0), PLANK, Enum.Material.WoodPlanks)
	part(model, "NorthWall", Vector3.new(WIDTH, HEIGHT, WALL), CFrame.new(0, y, -DEPTH / 2), LOG)
	local side = (WIDTH - DOOR) / 2
	for _, s in { -1, 1 } do
		part(model, "SouthWall", Vector3.new(side, HEIGHT, WALL), CFrame.new(s * (DOOR / 2 + side / 2), y, DEPTH / 2), LOG)
	end
	part(model, "OverDoor", Vector3.new(DOOR, HEIGHT - 10, WALL), CFrame.new(0, 10 + (HEIGHT - 10) / 2, DEPTH / 2), LOG)
	for _, s in { -1, 1 } do
		local x = s * WIDTH / 2
		-- Wall around a 10 x 5 window in the middle.
		local pieceDepth = (DEPTH - 10) / 2
		for _, z in { -1, 1 } do
			part(model, "SideWall", Vector3.new(WALL, HEIGHT, pieceDepth), CFrame.new(x, y, z * (5 + pieceDepth / 2)), LOG)
		end
		part(model, "UnderWindow", Vector3.new(WALL, 5, 10), CFrame.new(x, 2.5, 0), LOG)
		part(model, "OverWindow", Vector3.new(WALL, HEIGHT - 10, 10), CFrame.new(x, 10 + (HEIGHT - 10) / 2, 0), LOG)
		local glass = part(model, "Window", Vector3.new(0.2, 5, 10), CFrame.new(x, 7.5, 0), Color3.fromRGB(150, 170, 180), Enum.Material.Glass)
		glass.Transparency = 0.6
	end
	part(model, "Ceiling", Vector3.new(WIDTH, 0.6, DEPTH), CFrame.new(0, HEIGHT + 0.3, 0), PLANK, Enum.Material.WoodPlanks)

	-- Gable roof, ridge along X, with stepped boards closing the gable ends.
	local pitch = math.rad(25)
	local span = DEPTH / 2 + 2
	local rise = span * math.tan(pitch)
	for _, s in { -1, 1 } do
		local cf = CFrame.new(0, HEIGHT + 0.6 + rise / 2, s * span / 2) * CFrame.Angles(s * pitch, 0, 0)
		part(model, "Roof", Vector3.new(WIDTH + 4, 0.8, span / math.cos(pitch)), cf, ROOF, Enum.Material.Slate)
	end
	local boards = 4
	for _, s in { -1, 1 } do
		for i = 1, boards do
			local mid = (i - 0.5) / boards * rise
			local width = DEPTH * (1 - mid / rise)
			part(model, "Gable", Vector3.new(WALL, rise / boards, width), CFrame.new(s * WIDTH / 2, HEIGHT + 0.6 + mid, 0), LOG)
		end
	end

	-- Porch light over the door.
	local lamp = part(model, "PorchLamp", Vector3.new(1, 1, 1), CFrame.new(0, 11, DEPTH / 2 + 1), Color3.fromRGB(255, 220, 150), Enum.Material.Neon)
	light(lamp, Color3.fromRGB(255, 200, 130), 26, 1.4)

	local sign = part(model, "Sign", Vector3.new(22, 3.2, 0.4), CFrame.new(0, HEIGHT - 0.6, DEPTH / 2 + 0.8), PAINT)
	-- The sign faces the lot (+Z), which is the part's Back face.
	writeOn(sign, Enum.NormalId.Back, "HOLLOW PINES RANGER STATION", CREAM, 64)
end

local function buildInside(model: Model)
	-- Front desk across the back of the room.
	local desk = part(model, "Desk", Vector3.new(16, 3.6, 3), CFrame.new(0, 1.8, -DEPTH / 2 + 7), DARK)
	part(model, "DeskTop", Vector3.new(16.6, 0.3, 3.6), desk.CFrame * CFrame.new(0, 1.95, 0), PLANK)
	local bell = part(model, "Bell", Vector3.new(0.6, 0.6, 0.6), desk.CFrame * CFrame.new(5, 2.4, 0), Color3.fromRGB(180, 150, 70), Enum.Material.Metal)
	bell.Shape = Enum.PartType.Ball
	local radio = part(model, "Radio", Vector3.new(2, 1.2, 1.2), desk.CFrame * CFrame.new(-5, 2.7, 0), Color3.fromRGB(40, 44, 40), Enum.Material.Metal)
	light(radio, Color3.fromRGB(255, 90, 60), 4, 0.6)

	-- Wood stove in the north-west corner, glowing.
	local stove = part(model, "Stove", Vector3.new(4, 4, 4), CFrame.new(-WIDTH / 2 + 4, 2, -DEPTH / 2 + 4), Color3.fromRGB(30, 30, 32), Enum.Material.Metal)
	part(model, "StovePipe", Vector3.new(1, HEIGHT - 4, 1), stove.CFrame * CFrame.new(0, HEIGHT / 2, 0), Color3.fromRGB(30, 30, 32), Enum.Material.Metal)
	local fire = part(model, "Fire", Vector3.new(2.4, 1.2, 0.2), stove.CFrame * CFrame.new(0, -0.3, 2.01), Color3.fromRGB(255, 120, 40), Enum.Material.Neon)
	fire.CanCollide = false
	light(fire, Color3.fromRGB(255, 130, 60), 22, 1.6)

	-- Bench under the west window.
	part(model, "Bench", Vector3.new(3, 0.5, 12), CFrame.new(-WIDTH / 2 + 2.5, 2, 0), PLANK)
	for _, z in { -5, 5 } do
		part(model, "BenchLeg", Vector3.new(2.4, 1.8, 0.5), CFrame.new(-WIDTH / 2 + 2.5, 0.9, z), DARK)
	end

	-- Trail map on the east wall, with how to play.
	local board = part(model, "TrailMap", Vector3.new(0.3, 8, 14), CFrame.new(WIDTH / 2 - 0.7, 7, 0), Color3.fromRGB(196, 182, 140), Enum.Material.Fabric)
	writeOn(
		board,
		Enum.NormalId.Left,
		"HOLLOW PINES TRAIL\nCLOSED AFTER DARK\n\n1 to 4 players. Step onto the pad behind a truck to ride up to the cabin together. "
			.. "The truck leaves when it's full, or "
			.. tostring(Config.Lobby.DepartSeconds)
			.. " seconds after the first person climbs on.\n\nSurvive until 3:00 AM. Find the clues. Pick the right door.",
		Color3.fromRGB(40, 30, 22),
		30
	)

	-- Hanging lamp over the middle of the room.
	part(model, "LampCord", Vector3.new(0.15, 3, 0.15), CFrame.new(0, HEIGHT - 1.5, 2), DARK)
	local bulb = part(model, "Lamp", Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, HEIGHT - 3.4, 2), Color3.fromRGB(255, 225, 170), Enum.Material.Neon)
	bulb.Shape = Enum.PartType.Ball
	bulb.CanCollide = false
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
end

local function wheel(parent: Instance, cf: CFrame)
	local w = part(parent, "Wheel", Vector3.new(1.4, 3.2, 3.2), cf, Color3.fromRGB(24, 24, 24), Enum.Material.Rubber)
	w.Shape = Enum.PartType.Cylinder
end

-- One pickup truck facing the road (+Z), with its boarding pad on the ground behind the bed.
local function buildTruck(parent: Instance, index: number, at: CFrame): Truck
	local model = Instance.new("Model")
	model.Name = `Truck{index}`
	local body = Color3.fromRGB(120, 34, 30)
	part(model, "Chassis", Vector3.new(7, 1.4, 18), at * CFrame.new(0, 2.2, 0), Color3.fromRGB(30, 30, 30), Enum.Material.Metal)
	part(model, "Cab", Vector3.new(7, 4.4, 6), at * CFrame.new(0, 5.1, 4), body, Enum.Material.Metal)
	part(model, "Hood", Vector3.new(7, 2, 4), at * CFrame.new(0, 3.9, 9), body, Enum.Material.Metal)
	local windshield = part(model, "Windshield", Vector3.new(6.4, 2.2, 0.2), at * CFrame.new(0, 6, 7.05), Color3.fromRGB(40, 50, 56), Enum.Material.Glass)
	windshield.Transparency = 0.4
	part(model, "BedFloor", Vector3.new(7, 0.4, 8), at * CFrame.new(0, 3.1, -4), body, Enum.Material.Metal)
	for _, s in { -1, 1 } do
		part(model, "BedSide", Vector3.new(0.4, 2, 8), at * CFrame.new(s * 3.3, 4.1, -4), body, Enum.Material.Metal)
	end
	part(model, "Tailgate", Vector3.new(7, 2, 0.4), at * CFrame.new(0, 4.1, -8.2), body, Enum.Material.Metal)
	for _, z in { -5.5, 6 } do
		for _, s in { -1, 1 } do
			wheel(model, at * CFrame.new(s * 3.6, 1.6, z))
		end
	end
	for _, s in { -1, 1 } do
		local head = part(model, "Headlight", Vector3.new(1.2, 0.8, 0.2), at * CFrame.new(s * 2.4, 4, 11.05), Color3.fromRGB(255, 244, 210), Enum.Material.Neon)
		local beam = Instance.new("SpotLight")
		beam.Face = Enum.NormalId.Back -- the part's +Z, the way the truck faces
		beam.Range = 40
		beam.Angle = 50
		beam.Brightness = 3
		beam.Color = Color3.fromRGB(255, 240, 200)
		beam.Parent = head
		part(model, "TailLight", Vector3.new(1, 0.8, 0.2), at * CFrame.new(s * 2.8, 4, -8.45), Color3.fromRGB(200, 30, 20), Enum.Material.Neon)
	end

	local pad = part(model, "BoardingPad", Vector3.new(9, 0.2, 7), at * CFrame.new(0, 0.1, -13), Color3.fromRGB(230, 210, 140), Enum.Material.Neon)
	pad.Transparency = 0.55
	pad.CanCollide = false

	local boardPart = part(model, "Board", Vector3.new(1, 1, 1), at * CFrame.new(0, 11, -4), Color3.new(), Enum.Material.SmoothPlastic)
	boardPart.Transparency = 1
	boardPart.CanCollide = false
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 70)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 120
	gui.Parent = boardPart
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(18, 20, 18)
	label.BackgroundTransparency = 0.25
	label.TextColor3 = CREAM
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.TextWrapped = true
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	model.Parent = parent
	return { model = model, pad = pad, label = label }
end

-- Build everything. Returns the trucks in order.
function Station.build(): { Truck }
	local root = Instance.new("Model")
	root.Name = "RangerStation"

	part(root, "Ground", Vector3.new(400, 1, 400), CFrame.new(0, -1.5, 0), Config.Forest.Ground, Enum.Material.Grass)
	buildShell(root)
	buildInside(root)

	-- Gravel lot from the door out to the road.
	part(root, "Path", Vector3.new(8, 0.2, 8), CFrame.new(0, -0.9, DEPTH / 2 + 4), GRAVEL, Enum.Material.Pebble)
	part(root, "Lot", Vector3.new(100, 0.2, 44), CFrame.new(0, -0.9, DEPTH / 2 + 30), GRAVEL, Enum.Material.Pebble)

	-- Pines around the edge (not on the lot or the station).
	local rng = Random.new(7)
	local trees = Instance.new("Folder")
	trees.Name = "Pines"
	trees.Parent = root
	for _ = 1, 90 do
		local x = rng:NextNumber(-150, 150)
		local z = rng:NextNumber(-150, 150)
		local clear = math.abs(x) < 60 and z > -30 and z < DEPTH / 2 + 56
		if not clear then
			local h = rng:NextNumber(Config.Forest.MinHeight, Config.Forest.MaxHeight)
			part(trees, "Trunk", Vector3.new(1.6, h * 0.4, 1.6), CFrame.new(x, -1 + h * 0.2, z), Color3.fromRGB(58, 42, 30))
			local crown = part(trees, "Crown", Vector3.new(h * 0.8, h * 0.3, h * 0.3), CFrame.new(x, -1 + h * 0.6, z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(28, 46, 34), Enum.Material.Grass)
			crown.Shape = Enum.PartType.Cylinder
		end
	end

	local trucks = {}
	local count = Config.Lobby.Trucks
	for i = 1, count do
		local x = (i - (count + 1) / 2) * 24
		table.insert(trucks, buildTruck(root, i, CFrame.new(x, -0.8, DEPTH / 2 + 34)))
	end

	root.Parent = workspace
	return trucks
end

return Station
