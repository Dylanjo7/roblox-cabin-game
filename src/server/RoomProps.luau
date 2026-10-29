--!strict
-- Furniture, clutter and lamps for each room, built from parts in room-local space (rotation 0,
-- floor top at y = 0, inner wall faces at +-19). Doorways are centred on their sides (8 wide);
-- windows are centred on solid sides (6 wide, 4..10 high), so tall pieces keep clear of both.
-- Every room has exactly one hiding spot (a wardrobe, cabinet or bed, attribute HidingSpot); the
-- Linen Closet has three. Lamps are tagged "RoomLight" so the client can make them flicker.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DARK_WOOD = Color3.fromRGB(58, 40, 28)
local WOOD = Color3.fromRGB(96, 68, 46)
local LIGHT_WOOD = Color3.fromRGB(140, 104, 70)
local FABRIC = Color3.fromRGB(92, 30, 32)
local LINEN = Color3.fromRGB(196, 186, 164)
local PORCELAIN = Color3.fromRGB(214, 210, 200)
local IRON = Color3.fromRGB(44, 44, 48)
local BRASS = Color3.fromRGB(150, 120, 60)
local WARM = Color3.fromRGB(255, 196, 128)
local FELT = Color3.fromRGB(30, 74, 46)
local CANVAS = Color3.fromRGB(40, 44, 38)
local PALE = Color3.fromRGB(196, 186, 170)
local BOOKS = {
	Color3.fromRGB(92, 30, 28),
	Color3.fromRGB(38, 52, 74),
	Color3.fromRGB(46, 66, 40),
	Color3.fromRGB(110, 86, 40),
	Color3.fromRGB(70, 40, 60),
	Color3.fromRGB(150, 130, 100),
}

local RoomProps = {}

local rng = Random.new(1847) -- fixed, so every copy of a room looks the same

local function box(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
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

-- Decorative bits you shouldn't trip on.
local function trim(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = box(parent, name, size, cf, color, material)
	p.CanCollide = false
	p.CastShadow = false
	return p
end

local function ball(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = trim(parent, name, size, cf, color, material)
	p.Shape = Enum.PartType.Ball
	return p
end

local function cylinder(parent: Instance, name: string, radius: number, height: number, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = box(parent, name, Vector3.new(height, radius * 2, radius * 2), cf * CFrame.Angles(0, 0, math.rad(90)), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function group(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function light(parent: BasePart, range: number, brightness: number, color: Color3?): PointLight
	local l = Instance.new("PointLight")
	l.Color = color or WARM
	l.Range = range
	l.Brightness = brightness
	l.Shadows = true
	l.Parent = parent
	CollectionService:AddTag(l, "RoomLight")
	return l
end

-- Floor position and facing. A prop's front faces -Z (north) at 0 degrees, +X at -90, -X at 90.
-- So: against the south wall use 0, north wall 180, east wall 90, west wall -90.
local function place(x: number, z: number, faceDegrees: number): CFrame
	return CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(faceDegrees), 0)
end

-- On a wall at height y, facing into the room (same angles as place).
local function onWall(x: number, y: number, z: number, faceDegrees: number): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(faceDegrees), 0)
end

------------------------------------------------------------------------------------------------
-- Hiding spots

local function wardrobe(parent: Instance, at: CFrame, color: Color3?)
	local m = group(parent, "Wardrobe")
	m:SetAttribute("HidingSpot", true)
	local wood = color or DARK_WOOD
	box(m, "Body", Vector3.new(5, 9, 3), at * CFrame.new(0, 4.5, 0), wood)
	for _, x in { -1.2, 1.2 } do
		box(m, "Door", Vector3.new(2.3, 8, 0.2), at * CFrame.new(x, 4.6, -1.55), WOOD)
		trim(m, "Panel", Vector3.new(1.6, 3, 0.1), at * CFrame.new(x, 6.3, -1.68), wood)
		trim(m, "Panel", Vector3.new(1.6, 3, 0.1), at * CFrame.new(x, 2.8, -1.68), wood)
	end
	trim(m, "Handle", Vector3.new(0.2, 0.8, 0.2), at * CFrame.new(-0.25, 4.6, -1.75), BRASS, Enum.Material.Metal)
	trim(m, "Handle", Vector3.new(0.2, 0.8, 0.2), at * CFrame.new(0.25, 4.6, -1.75), BRASS, Enum.Material.Metal)
	box(m, "Crown", Vector3.new(5.6, 0.5, 3.4), at * CFrame.new(0, 9.25, 0), wood)
	trim(m, "Plinth", Vector3.new(5.4, 0.4, 3.3), at * CFrame.new(0, 0.2, 0), wood)
end

local function bed(parent: Instance, at: CFrame, blanket: Color3?)
	local m = group(parent, "Bed")
	m:SetAttribute("HidingSpot", true)
	box(m, "Frame", Vector3.new(5, 0.8, 8), at * CFrame.new(0, 1.6, 0), IRON, Enum.Material.Metal)
	for _, x in { -2.3, 2.3 } do
		for _, z in { -3.8, 3.8 } do
			box(m, "Leg", Vector3.new(0.3, 1.2, 0.3), at * CFrame.new(x, 0.6, z), IRON, Enum.Material.Metal)
		end
	end
	box(m, "Mattress", Vector3.new(4.6, 0.7, 7.6), at * CFrame.new(0, 2.35, 0), LINEN, Enum.Material.Fabric)
	trim(m, "Blanket", Vector3.new(4.9, 0.25, 5), at * CFrame.new(0, 2.8, -1.3), blanket or FABRIC, Enum.Material.Fabric)
	trim(m, "BlanketDrape", Vector3.new(0.2, 1.4, 5), at * CFrame.new(-2.5, 2.2, -1.3), blanket or FABRIC, Enum.Material.Fabric)
	trim(m, "BlanketDrape", Vector3.new(0.2, 1.4, 5), at * CFrame.new(2.5, 2.2, -1.3), blanket or FABRIC, Enum.Material.Fabric)
	trim(m, "Pillow", Vector3.new(1.8, 0.5, 1.2), at * CFrame.new(-1.1, 2.95, 3), LINEN, Enum.Material.Fabric)
	trim(m, "Pillow", Vector3.new(1.8, 0.5, 1.2), at * CFrame.new(1.1, 2.95, 3), LINEN, Enum.Material.Fabric)
	-- Brass bedstead: posts and rails.
	for _, x in { -2.4, 2.4 } do
		box(m, "Post", Vector3.new(0.25, 5, 0.25), at * CFrame.new(x, 2.5, 4), BRASS, Enum.Material.Metal)
		box(m, "Post", Vector3.new(0.25, 3.2, 0.25), at * CFrame.new(x, 1.6, -4), BRASS, Enum.Material.Metal)
	end
	for _, y in { 3.6, 4.8 } do
		trim(m, "Rail", Vector3.new(4.8, 0.15, 0.15), at * CFrame.new(0, y, 4), BRASS, Enum.Material.Metal)
	end
	trim(m, "FootRail", Vector3.new(4.8, 0.15, 0.15), at * CFrame.new(0, 3.1, -4), BRASS, Enum.Material.Metal)
end

------------------------------------------------------------------------------------------------
-- Furniture

local function rug(parent: Instance, size: Vector2, at: CFrame, color: Color3)
	trim(parent, "Rug", Vector3.new(size.X, 0.08, size.Y), at * CFrame.new(0, 0.04, 0), color, Enum.Material.Fabric)
	trim(parent, "RugBorder", Vector3.new(size.X - 1, 0.09, size.Y - 1), at * CFrame.new(0, 0.045, 0), color:Lerp(Color3.new(0, 0, 0), 0.35), Enum.Material.Fabric)
	trim(parent, "RugField", Vector3.new(size.X - 2, 0.1, size.Y - 2), at * CFrame.new(0, 0.05, 0), color, Enum.Material.Fabric)
end

local function chair(parent: Instance, at: CFrame, color: Color3?)
	local m = group(parent, "Chair")
	local wood = color or WOOD
	box(m, "Seat", Vector3.new(1.8, 0.25, 1.8), at * CFrame.new(0, 2, 0), wood)
	for _, x in { -0.75, 0.75 } do
		for _, z in { -0.75, 0.75 } do
			trim(m, "Leg", Vector3.new(0.2, 2, 0.2), at * CFrame.new(x, 1, z), wood)
		end
		box(m, "BackPost", Vector3.new(0.22, 2.6, 0.22), at * CFrame.new(x, 3.3, 0.8), wood)
	end
	for _, x in { -0.35, 0, 0.35 } do
		trim(m, "Spindle", Vector3.new(0.12, 2.2, 0.12), at * CFrame.new(x, 3.2, 0.8), wood)
	end
	trim(m, "BackTop", Vector3.new(1.9, 0.3, 0.3), at * CFrame.new(0, 4.5, 0.8), wood)
end

local function armchair(parent: Instance, at: CFrame, color: Color3?)
	local m = group(parent, "Armchair")
	local cloth = color or FABRIC
	box(m, "Seat", Vector3.new(3.4, 1.4, 3.2), at * CFrame.new(0, 1.2, 0), cloth, Enum.Material.Fabric)
	trim(m, "Cushion", Vector3.new(2.6, 0.4, 2.6), at * CFrame.new(0, 2.05, -0.2), cloth:Lerp(Color3.new(1, 1, 1), 0.08), Enum.Material.Fabric)
	box(m, "Back", Vector3.new(3.4, 3.8, 0.8), at * CFrame.new(0, 3.2, 1.3), cloth, Enum.Material.Fabric)
	box(m, "ArmL", Vector3.new(0.7, 1.4, 3.2), at * CFrame.new(-1.7, 2.2, 0), cloth, Enum.Material.Fabric)
	box(m, "ArmR", Vector3.new(0.7, 1.4, 3.2), at * CFrame.new(1.7, 2.2, 0), cloth, Enum.Material.Fabric)
	for _, x in { -1.4, 1.4 } do
		for _, z in { -1.3, 1.3 } do
			trim(m, "Foot", Vector3.new(0.3, 0.5, 0.3), at * CFrame.new(x, 0.25, z), DARK_WOOD)
		end
	end
end

local function sofa(parent: Instance, at: CFrame, color: Color3)
	local m = group(parent, "Sofa")
	box(m, "Base", Vector3.new(8, 1.5, 3.2), at * CFrame.new(0, 1.2, 0), color, Enum.Material.Fabric)
	for _, x in { -1.9, 1.9 } do
		trim(m, "Cushion", Vector3.new(3.6, 0.5, 2.6), at * CFrame.new(x, 2.2, -0.2), color:Lerp(Color3.new(1, 1, 1), 0.08), Enum.Material.Fabric)
	end
	box(m, "Back", Vector3.new(8, 3, 0.8), at * CFrame.new(0, 3, 1.3), color, Enum.Material.Fabric)
	box(m, "ArmL", Vector3.new(0.8, 2, 3.2), at * CFrame.new(-4, 2, 0), color, Enum.Material.Fabric)
	box(m, "ArmR", Vector3.new(0.8, 2, 3.2), at * CFrame.new(4, 2, 0), color, Enum.Material.Fabric)
	trim(m, "Throw", Vector3.new(2.5, 0.15, 2.2), at * CFrame.new(2.6, 2.5, 0.2) * CFrame.Angles(0, 0, math.rad(8)), LINEN, Enum.Material.Fabric)
end

local function table_(parent: Instance, at: CFrame, size: Vector2, height: number, top: Color3?): Model
	local m = group(parent, "Table")
	box(m, "Top", Vector3.new(size.X, 0.35, size.Y), at * CFrame.new(0, height, 0), top or WOOD)
	for _, x in { -size.X / 2 + 0.4, size.X / 2 - 0.4 } do
		for _, z in { -size.Y / 2 + 0.4, size.Y / 2 - 0.4 } do
			box(m, "Leg", Vector3.new(0.35, height, 0.35), at * CFrame.new(x, height / 2, z), DARK_WOOD)
		end
	end
	return m
end

local function lamp(parent: Instance, at: CFrame, height: number, range: number?)
	trim(parent, "LampBase", Vector3.new(0.5, 1, 0.5), at * CFrame.new(0, height + 0.5, 0), BRASS, Enum.Material.Metal)
	local shade = trim(parent, "LampShade", Vector3.new(1.4, 1.1, 1.4), at * CFrame.new(0, height + 1.5, 0), Color3.fromRGB(220, 196, 150), Enum.Material.Fabric)
	light(shade, range or 14, 0.7)
end

local function sideTable(parent: Instance, at: CFrame, withLamp: boolean)
	local m = group(parent, "SideTable")
	box(m, "Top", Vector3.new(2.4, 0.3, 2.4), at * CFrame.new(0, 2.6, 0), WOOD)
	box(m, "Leg", Vector3.new(0.4, 2.5, 0.4), at * CFrame.new(0, 1.25, 0), DARK_WOOD)
	trim(m, "Foot", Vector3.new(1.6, 0.2, 1.6), at * CFrame.new(0, 0.1, 0), DARK_WOOD)
	if withLamp then
		lamp(m, at, 2.75)
	end
end

local function floorLamp(parent: Instance, at: CFrame)
	local m = group(parent, "FloorLamp")
	trim(m, "Foot", Vector3.new(1.4, 0.2, 1.4), at * CFrame.new(0, 0.1, 0), BRASS, Enum.Material.Metal)
	trim(m, "Pole", Vector3.new(0.2, 6.5, 0.2), at * CFrame.new(0, 3.3, 0), BRASS, Enum.Material.Metal)
	local shade = trim(m, "Shade", Vector3.new(1.8, 1.4, 1.8), at * CFrame.new(0, 7, 0), Color3.fromRGB(226, 200, 150), Enum.Material.Fabric)
	light(shade, 16, 0.8)
end

local function portrait(parent: Instance, at: CFrame, size: Vector2)
	box(parent, "Frame", Vector3.new(size.X, size.Y, 0.25), at, Color3.fromRGB(120, 92, 40), Enum.Material.Metal)
	trim(parent, "Canvas", Vector3.new(size.X - 0.6, size.Y - 0.6, 0.05), at * CFrame.new(0, 0, -0.14), CANVAS, Enum.Material.SmoothPlastic)
	-- A pale face, just a shape in the dark paint.
	ball(parent, "Face", Vector3.new(size.X * 0.28, size.Y * 0.32, 0.05), at * CFrame.new(0, size.Y * 0.1, -0.17), PALE, Enum.Material.SmoothPlastic)
	trim(parent, "Shoulders", Vector3.new(size.X * 0.6, size.Y * 0.2, 0.04), at * CFrame.new(0, -size.Y * 0.28, -0.17), Color3.fromRGB(26, 24, 22), Enum.Material.SmoothPlastic)
end

local function landscape(parent: Instance, at: CFrame, size: Vector2)
	box(parent, "Frame", Vector3.new(size.X, size.Y, 0.25), at, DARK_WOOD)
	trim(parent, "Canvas", Vector3.new(size.X - 0.5, size.Y - 0.5, 0.05), at * CFrame.new(0, 0, -0.14), Color3.fromRGB(30, 40, 36), Enum.Material.SmoothPlastic)
	for i = 1, 4 do
		local x = -size.X / 2 + i * size.X / 5
		trim(parent, "Pine", Vector3.new(0.25, size.Y * 0.4, 0.04), at * CFrame.new(x, -size.Y * 0.08, -0.17), Color3.fromRGB(14, 20, 16), Enum.Material.SmoothPlastic)
	end
end

local function fireplace(parent: Instance, at: CFrame)
	local m = group(parent, "Fireplace")
	box(m, "Hearth", Vector3.new(9, 0.6, 3), at * CFrame.new(0, 0.3, -0.5), Color3.fromRGB(80, 78, 76), Enum.Material.Slate)
	box(m, "Left", Vector3.new(1.5, 6, 2), at * CFrame.new(-3.75, 3, 0.5), Color3.fromRGB(96, 90, 86), Enum.Material.Brick)
	box(m, "Right", Vector3.new(1.5, 6, 2), at * CFrame.new(3.75, 3, 0.5), Color3.fromRGB(96, 90, 86), Enum.Material.Brick)
	box(m, "Mantel", Vector3.new(10, 0.6, 2.6), at * CFrame.new(0, 6.3, 0.2), DARK_WOOD)
	box(m, "Back", Vector3.new(6, 6, 0.6), at * CFrame.new(0, 3, 1.2), Color3.fromRGB(30, 26, 24), Enum.Material.Brick)
	box(m, "Chimney", Vector3.new(7, 9.4, 1.6), at * CFrame.new(0, 11.3, 1), Color3.fromRGB(86, 80, 76), Enum.Material.Brick)
	for i, x in { -1.2, 0, 1.3 } do
		trim(m, "Log", Vector3.new(0.6, 0.6, 2.6), at * CFrame.new(x, 1, 0.4) * CFrame.Angles(0, math.rad(60 + i * 30), 0), DARK_WOOD)
	end
	local embers = trim(m, "Embers", Vector3.new(3.6, 0.4, 1), at * CFrame.new(0, 0.75, 0.4), Color3.fromRGB(255, 110, 40), Enum.Material.Neon)
	-- Real flames over the logs, and their light dancing on the walls (tag "Firelight": each
	-- client makes it flicker, client/Haunting).
	local flames = Instance.new("Fire")
	flames.Size = 3.2
	flames.Heat = 6
	flames.Color = Color3.fromRGB(255, 150, 60)
	flames.SecondaryColor = Color3.fromRGB(200, 60, 20)
	flames.Parent = embers
	CollectionService:AddTag(light(embers, 20, 0.9, Color3.fromRGB(255, 130, 60)), "Firelight")
	-- Things on the mantel.
	for _, x in { -3.5, 3.5 } do
		trim(m, "Candlestick", Vector3.new(0.3, 1.2, 0.3), at * CFrame.new(x, 7.2, 0), BRASS, Enum.Material.Metal)
	end
	trim(m, "MantelClock", Vector3.new(1.4, 1.2, 0.7), at * CFrame.new(0, 7.2, 0.2), DARK_WOOD)
end

-- A grandfather clock. It's tagged "TickingClock": every client ticks its second hand, swings
-- its pendulum and sets its hands to the time on the Candle (src/client/Clocks). The hands are
-- built pointing at 12 from the centre of the face; the pendulum swings from PivotFromFace.
local function grandfatherClock(parent: Instance, at: CFrame)
	local m = group(parent, "GrandfatherClock")
	box(m, "Case", Vector3.new(2.4, 9, 1.6), at * CFrame.new(0, 4.5, 0), DARK_WOOD)
	trim(m, "Hood", Vector3.new(2.8, 0.6, 1.9), at * CFrame.new(0, 9.3, 0), DARK_WOOD)
	trim(m, "Crown", Vector3.new(2.2, 0.5, 1.7), at * CFrame.new(0, 9.85, 0), DARK_WOOD)
	local face = trim(m, "Face", Vector3.new(1.8, 1.8, 0.1), at * CFrame.new(0, 7.6, -0.85), LINEN, Enum.Material.SmoothPlastic)
	-- Hour marks round the face.
	for i = 0, 11 do
		local a = i * math.pi / 6
		local long = i % 3 == 0
		trim(m, "HourMark", Vector3.new(0.06, if long then 0.18 else 0.1, 0.02), face.CFrame * CFrame.Angles(0, 0, a) * CFrame.new(0, 0.72, -0.06), IRON, Enum.Material.Metal)
	end
	local hands = {
		{ "HandHour", 0.5, 0.09, -0.07, IRON },
		{ "HandMinute", 0.75, 0.06, -0.085, IRON },
		{ "HandSecond", 0.78, 0.025, -0.1, Color3.fromRGB(140, 30, 24) },
	}
	for _, h in hands do
		local name, length, width, depth, color = h[1], h[2], h[3], h[4], h[5]
		-- Pointing up; a short tail past the centre.
		trim(m, name, Vector3.new(width, length, 0.02), face.CFrame * CFrame.new(0, length / 2 - 0.08, depth), color, Enum.Material.Metal)
	end
	ball(m, "Pin", Vector3.new(0.12, 0.12, 0.12), face.CFrame * CFrame.new(0, 0, -0.11), BRASS, Enum.Material.Metal)
	local glass = trim(m, "Window", Vector3.new(1.4, 3.6, 0.1), at * CFrame.new(0, 4, -0.82), Color3.fromRGB(20, 18, 16), Enum.Material.Glass)
	glass.Transparency = 0.35
	local pivotFromFace = Vector3.new(0, -1.9, -0.02)
	local rod = trim(m, "Pendulum", Vector3.new(0.12, 2.6, 0.06), at * CFrame.new(0, 4.4, -0.87), BRASS, Enum.Material.Metal)
	rod:SetAttribute("PivotFromFace", pivotFromFace)
	local bob = ball(m, "Bob", Vector3.new(0.6, 0.6, 0.1), at * CFrame.new(0, 3, -0.89), BRASS, Enum.Material.Metal)
	bob:SetAttribute("PivotFromFace", pivotFromFace)
	CollectionService:AddTag(m, "TickingClock")
end

local function crate(parent: Instance, at: CFrame, size: number)
	box(parent, "Crate", Vector3.new(size, size, size), at * CFrame.new(0, size / 2, 0), Color3.fromRGB(110, 86, 58), Enum.Material.WoodPlanks)
end

local function bookshelf(parent: Instance, at: CFrame, width: number?)
	local w = width or 6
	local m = group(parent, "Bookshelf")
	box(m, "Back", Vector3.new(w, 10, 0.3), at * CFrame.new(0, 5, 0.65), DARK_WOOD)
	box(m, "SideL", Vector3.new(0.3, 10, 1.6), at * CFrame.new(-w / 2 + 0.15, 5, 0), DARK_WOOD)
	box(m, "SideR", Vector3.new(0.3, 10, 1.6), at * CFrame.new(w / 2 - 0.15, 5, 0), DARK_WOOD)
	for shelf = 0, 4 do
		local y = 0.3 + shelf * 2.1
		box(m, "Shelf", Vector3.new(w, 0.2, 1.6), at * CFrame.new(0, y, 0), DARK_WOOD)
		-- Rows of books in a few uneven runs.
		local x = -w / 2 + 0.4
		while x < w / 2 - 0.6 do
			local run = math.min(rng:NextNumber(0.8, 1.8), w / 2 - 0.4 - x)
			local height = rng:NextNumber(1.2, 1.7)
			trim(m, "Books", Vector3.new(run, height, 1.1), at * CFrame.new(x + run / 2, y + 0.1 + height / 2, 0.05), BOOKS[rng:NextInteger(1, #BOOKS)], Enum.Material.Fabric)
			x += run + rng:NextNumber(0.05, 0.4)
		end
	end
	box(m, "Top", Vector3.new(w + 0.3, 0.3, 1.8), at * CFrame.new(0, 10.1, 0), DARK_WOOD)
end

local function shelfUnit(parent: Instance, at: CFrame, width: number, items: string)
	local m = group(parent, "Shelves")
	for _, x in { -width / 2 + 0.15, width / 2 - 0.15 } do
		box(m, "Upright", Vector3.new(0.3, 8, 1.5), at * CFrame.new(x, 4, 0), WOOD)
	end
	for shelf = 0, 3 do
		local y = 0.6 + shelf * 2.3
		box(m, "Shelf", Vector3.new(width, 0.2, 1.5), at * CFrame.new(0, y, 0), WOOD)
		local x = -width / 2 + 0.7
		while x < width / 2 - 0.6 do
			if items == "jars" then
				local h = rng:NextNumber(0.7, 1.3)
				local jar = cylinder(m, "Jar", 0.3, h, at * CFrame.new(x, y + 0.1 + h / 2, 0), Color3.fromRGB(150, 160, 120):Lerp(Color3.fromRGB(120, 70, 40), rng:NextNumber()), Enum.Material.Glass)
				jar.Transparency = 0.25
				jar.CanCollide = false
				x += 0.85
			else -- folded linens
				trim(m, "Linens", Vector3.new(1.4, rng:NextNumber(0.6, 1.4), 1.2), at * CFrame.new(x + 0.3, y + 0.6, 0), LINEN:Lerp(Color3.fromRGB(150, 160, 170), rng:NextNumber()), Enum.Material.Fabric)
				x += 1.7
			end
		end
	end
end

local function counter(parent: Instance, from: number, to: number, z: number, faceDegrees: number)
	local m = group(parent, "Counter")
	local width = to - from
	local at = CFrame.Angles(0, math.rad(faceDegrees), 0) * CFrame.new((from + to) / 2, 0, z)
	box(m, "Cabinets", Vector3.new(width, 3, 2.4), at * CFrame.new(0, 1.5, 0), Color3.fromRGB(150, 140, 110))
	box(m, "Top", Vector3.new(width + 0.2, 0.25, 2.6), at * CFrame.new(0, 3.1, 0), Color3.fromRGB(70, 66, 60), Enum.Material.Marble)
	for x = -width / 2 + 1.5, width / 2 - 1, 3 do
		trim(m, "Door", Vector3.new(2.6, 2.4, 0.1), at * CFrame.new(x, 1.5, -1.24), Color3.fromRGB(130, 120, 94))
		trim(m, "Knob", Vector3.new(0.2, 0.2, 0.15), at * CFrame.new(x + 1, 2.2, -1.32), BRASS, Enum.Material.Metal)
	end
	-- Clutter on top.
	for x = -width / 2 + 1, width / 2 - 1, 2.6 do
		if rng:NextNumber() < 0.6 then
			cylinder(m, "Crock", rng:NextNumber(0.3, 0.5), rng:NextNumber(0.6, 1.2), at * CFrame.new(x, 3.7, 0.3), PORCELAIN:Lerp(Color3.fromRGB(110, 80, 60), rng:NextNumber()), Enum.Material.SmoothPlastic).CanCollide = false
		end
	end
end

local function stove(parent: Instance, at: CFrame)
	local m = group(parent, "Stove")
	box(m, "Body", Vector3.new(4, 3.2, 2.6), at * CFrame.new(0, 1.6, 0), IRON, Enum.Material.Metal)
	trim(m, "OvenDoor", Vector3.new(2.8, 1.6, 0.1), at * CFrame.new(0, 1.3, -1.32), Color3.fromRGB(30, 30, 32), Enum.Material.Metal)
	for _, x in { -1, 1 } do
		cylinder(m, "Burner", 0.6, 0.1, at * CFrame.new(x, 3.25, 0), Color3.fromRGB(20, 20, 22), Enum.Material.Metal)
	end
	cylinder(m, "Pot", 0.55, 0.9, at * CFrame.new(-1, 3.75, 0), Color3.fromRGB(70, 70, 76), Enum.Material.Metal)
	box(m, "Flue", Vector3.new(0.8, 12, 0.8), at * CFrame.new(0, 9.2, 0.8), IRON, Enum.Material.Metal)
	local glow = trim(m, "Glow", Vector3.new(1.6, 0.3, 0.05), at * CFrame.new(0, 0.6, -1.35), Color3.fromRGB(255, 100, 40), Enum.Material.Neon)
	light(glow, 8, 0.6, Color3.fromRGB(255, 120, 60))
end

local function icebox(parent: Instance, at: CFrame)
	local m = group(parent, "Icebox")
	box(m, "Body", Vector3.new(3.4, 7, 2.6), at * CFrame.new(0, 3.5, 0), Color3.fromRGB(190, 184, 166))
	for _, y in { 2, 5.2 } do
		trim(m, "Door", Vector3.new(3, 2.6, 0.1), at * CFrame.new(0, y, -1.32), Color3.fromRGB(176, 170, 152))
		trim(m, "Latch", Vector3.new(0.3, 0.6, 0.2), at * CFrame.new(1.2, y, -1.42), BRASS, Enum.Material.Metal)
	end
end

local function sink(parent: Instance, at: CFrame)
	local m = group(parent, "Sink")
	box(m, "Basin", Vector3.new(3, 0.8, 2), at * CFrame.new(0, 3.2, 0), PORCELAIN, Enum.Material.SmoothPlastic)
	trim(m, "Bowl", Vector3.new(2.4, 0.1, 1.4), at * CFrame.new(0, 3.62, 0), Color3.fromRGB(150, 150, 146), Enum.Material.SmoothPlastic)
	trim(m, "Pedestal", Vector3.new(0.8, 2.8, 0.8), at * CFrame.new(0, 1.4, 0.2), PORCELAIN, Enum.Material.SmoothPlastic)
	trim(m, "Tap", Vector3.new(0.2, 0.7, 0.2), at * CFrame.new(0, 4, 0.8), BRASS, Enum.Material.Metal)
end

local function tub(parent: Instance, at: CFrame)
	local m = group(parent, "Tub")
	box(m, "Body", Vector3.new(3.4, 2.4, 7), at * CFrame.new(0, 1.7, 0), PORCELAIN, Enum.Material.SmoothPlastic)
	trim(m, "Inside", Vector3.new(2.8, 0.1, 6.4), at * CFrame.new(0, 2.85, 0), Color3.fromRGB(120, 126, 120), Enum.Material.SmoothPlastic)
	for _, x in { -1.4, 1.4 } do
		for _, z in { -3, 3 } do
			ball(m, "ClawFoot", Vector3.new(0.6, 0.7, 0.6), at * CFrame.new(x, 0.35, z), BRASS, Enum.Material.Metal)
		end
	end
	trim(m, "Faucet", Vector3.new(0.3, 1, 0.3), at * CFrame.new(0, 3.3, 3.2), BRASS, Enum.Material.Metal)
	trim(m, "Curtain", Vector3.new(0.1, 6, 6.6), at * CFrame.new(-1.8, 5.5, 0), Color3.fromRGB(170, 176, 160), Enum.Material.Fabric).Transparency = 0.15
end

local function toilet(parent: Instance, at: CFrame)
	local m = group(parent, "Toilet")
	box(m, "Bowl", Vector3.new(1.6, 1.8, 2), at * CFrame.new(0, 0.9, -0.3), PORCELAIN, Enum.Material.SmoothPlastic)
	trim(m, "Seat", Vector3.new(1.7, 0.15, 2.1), at * CFrame.new(0, 1.85, -0.3), DARK_WOOD)
	box(m, "Cistern", Vector3.new(2, 1.4, 0.8), at * CFrame.new(0, 6, 0.8), PORCELAIN, Enum.Material.SmoothPlastic)
	trim(m, "Pipe", Vector3.new(0.2, 4, 0.2), at * CFrame.new(0.6, 3.5, 0.9), BRASS, Enum.Material.Metal)
	trim(m, "Chain", Vector3.new(0.06, 1.4, 0.06), at * CFrame.new(-0.7, 4.8, 0.4), BRASS, Enum.Material.Metal)
end

local function mirror(parent: Instance, at: CFrame, size: Vector2)
	box(parent, "MirrorFrame", Vector3.new(size.X, size.Y, 0.25), at, Color3.fromRGB(120, 92, 40), Enum.Material.Metal)
	trim(parent, "MirrorGlass", Vector3.new(size.X - 0.5, size.Y - 0.5, 0.05), at * CFrame.new(0, 0, -0.14), Color3.fromRGB(150, 160, 164), Enum.Material.Glass).Reflectance = 0.25
	trim(parent, "Crack", Vector3.new(0.05, size.Y * 0.7, 0.02), at * CFrame.new(0.4, 0.2, -0.18) * CFrame.Angles(0, 0, math.rad(25)), Color3.fromRGB(230, 230, 230), Enum.Material.SmoothPlastic)
end

local function washer(parent: Instance, at: CFrame)
	local m = group(parent, "Washtub")
	cylinder(m, "Drum", 1.4, 3, at * CFrame.new(0, 1.5, 0), Color3.fromRGB(150, 156, 156), Enum.Material.Metal)
	box(m, "Wringer", Vector3.new(2.6, 0.5, 0.5), at * CFrame.new(0, 3.5, 0), IRON, Enum.Material.Metal)
	trim(m, "Handle", Vector3.new(0.15, 1.2, 0.15), at * CFrame.new(1.5, 3.9, 0), IRON, Enum.Material.Metal)
end

local function clothesline(parent: Instance, from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	local mid = (from + to) / 2
	local line = CFrame.lookAt(mid, to)
	trim(parent, "Line", Vector3.new(0.06, 0.06, length), line, LINEN, Enum.Material.Fabric)
	for i = 1, 3 do
		local t = -length / 2 + i * length / 4
		-- Hangs in the plane of the line.
		trim(parent, "Sheet", Vector3.new(0.05, 5, 3), line * CFrame.new(0, -2.5, t), LINEN, Enum.Material.Fabric).Transparency = 0.1
	end
end

local function dressForm(parent: Instance, at: CFrame)
	local m = group(parent, "DressForm")
	trim(m, "Foot", Vector3.new(1.6, 0.2, 1.6), at * CFrame.new(0, 0.1, 0), DARK_WOOD)
	trim(m, "Pole", Vector3.new(0.2, 3.5, 0.2), at * CFrame.new(0, 1.9, 0), DARK_WOOD)
	ball(m, "Hips", Vector3.new(1.8, 1.4, 1.3), at * CFrame.new(0, 3.9, 0), Color3.fromRGB(150, 120, 100), Enum.Material.Fabric)
	box(m, "Torso", Vector3.new(1.5, 2.2, 1.1), at * CFrame.new(0, 5.2, 0), Color3.fromRGB(150, 120, 100), Enum.Material.Fabric)
	ball(m, "Shoulders", Vector3.new(2, 0.8, 1.1), at * CFrame.new(0, 6.3, 0), Color3.fromRGB(150, 120, 100), Enum.Material.Fabric)
	trim(m, "Neck", Vector3.new(0.4, 0.6, 0.4), at * CFrame.new(0, 6.9, 0), DARK_WOOD)
end

local function sewingTable(parent: Instance, at: CFrame)
	local m = table_(parent, at, Vector2.new(5, 2.6), 3)
	box(m, "Machine", Vector3.new(2, 1, 0.8), at * CFrame.new(-0.6, 3.7, 0.2), IRON, Enum.Material.Metal)
	box(m, "Arm", Vector3.new(0.5, 1.2, 0.6), at * CFrame.new(0.5, 4.2, 0.2), IRON, Enum.Material.Metal)
	for i = 1, 3 do
		cylinder(m, "Spool", 0.15, 0.3, at * CFrame.new(1.4 + i * 0.3, 3.35, -0.6), BOOKS[i], Enum.Material.Fabric).CanCollide = false
	end
end

local function piano(parent: Instance, at: CFrame)
	local m = group(parent, "Piano")
	box(m, "Body", Vector3.new(8, 6, 2.6), at * CFrame.new(0, 3, 0.4), Color3.fromRGB(28, 20, 16))
	box(m, "KeyBed", Vector3.new(7.4, 0.5, 1.4), at * CFrame.new(0, 3.1, -1.4), Color3.fromRGB(28, 20, 16))
	trim(m, "Keys", Vector3.new(6.8, 0.15, 0.9), at * CFrame.new(0, 3.42, -1.45), Color3.fromRGB(226, 220, 204), Enum.Material.SmoothPlastic)
	for x = -3.1, 3.1, 0.55 do
		trim(m, "Sharp", Vector3.new(0.18, 0.15, 0.5), at * CFrame.new(x, 3.52, -1.25), Color3.fromRGB(14, 12, 12), Enum.Material.SmoothPlastic)
	end
	trim(m, "MusicDesk", Vector3.new(4, 1.4, 0.15), at * CFrame.new(0, 4.6, -1) * CFrame.Angles(math.rad(-15), 0, 0), Color3.fromRGB(28, 20, 16))
	trim(m, "Sheet", Vector3.new(1.6, 1.1, 0.05), at * CFrame.new(0, 4.65, -1.1) * CFrame.Angles(math.rad(-15), 0, 0), LINEN, Enum.Material.SmoothPlastic)
	for _, x in { -3.5, 3.5 } do
		trim(m, "Candle", Vector3.new(0.25, 0.8, 0.25), at * CFrame.new(x, 6.4, 0.2), LINEN, Enum.Material.SmoothPlastic)
	end
	box(m, "Bench", Vector3.new(3.6, 0.5, 1.4), at * CFrame.new(0, 2, -3.5), Color3.fromRGB(28, 20, 16))
	for _, x in { -1.5, 1.5 } do
		trim(m, "BenchLeg", Vector3.new(0.3, 1.8, 0.3), at * CFrame.new(x, 0.9, -3.5), Color3.fromRGB(28, 20, 16))
	end
end

local function gramophone(parent: Instance, at: CFrame)
	sideTable(parent, at, false)
	box(parent, "GramophoneBox", Vector3.new(1.6, 0.8, 1.6), at * CFrame.new(0, 3.15, 0), DARK_WOOD)
	local horn = trim(parent, "Horn", Vector3.new(1.6, 1.6, 0.2), at * CFrame.new(0.3, 4.6, -0.3) * CFrame.Angles(math.rad(-30), 0, 0), BRASS, Enum.Material.Metal)
	horn.Shape = Enum.PartType.Cylinder
	horn.Size = Vector3.new(0.2, 1.8, 1.8)
end

local function cardTable(parent: Instance, at: CFrame)
	local m = table_(parent, at, Vector2.new(5, 5), 3, FELT)
	trim(m, "Felt", Vector3.new(4.4, 0.05, 4.4), at * CFrame.new(0, 3.2, 0), FELT, Enum.Material.Fabric)
	for i = 1, 7 do
		trim(m, "Card", Vector3.new(0.5, 0.03, 0.7), at * CFrame.new(rng:NextNumber(-1.6, 1.6), 3.24, rng:NextNumber(-1.6, 1.6)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), LINEN, Enum.Material.SmoothPlastic)
	end
	trim(m, "ScoreCard", Vector3.new(0.8, 0.03, 1.1), at * CFrame.new(1.4, 3.24, 1.4), Color3.fromRGB(230, 220, 190), Enum.Material.SmoothPlastic)
	for _, a in { 0, 90, 180, 270 } do
		chair(parent, at * CFrame.Angles(0, math.rad(a), 0) * CFrame.new(0, 0, 3.4) * CFrame.Angles(0, 0, 0))
	end
end

local function diningTable(parent: Instance, at: CFrame)
	table_(parent, at, Vector2.new(4.5, 12), 3.1, DARK_WOOD)
	trim(parent, "Runner", Vector3.new(1.6, 0.05, 11), at * CFrame.new(0, 3.3, 0), FABRIC, Enum.Material.Fabric)
	for _, z in { -3.8, 0, 3.8 } do
		for _, side in { -1, 1 } do
			chair(parent, at * CFrame.new(side * 3.1, 0, z) * CFrame.Angles(0, math.rad(side * 90), 0))
			cylinder(parent, "Plate", 0.55, 0.06, at * CFrame.new(side * 1.4, 3.3, z), PORCELAIN, Enum.Material.SmoothPlastic).CanCollide = false
		end
	end
	for _, z in { -2, 2 } do
		trim(parent, "Candelabra", Vector3.new(0.3, 1.6, 0.3), at * CFrame.new(0, 4.1, z), BRASS, Enum.Material.Metal)
	end
end

local function desk(parent: Instance, at: CFrame)
	local m = group(parent, "Desk")
	box(m, "Top", Vector3.new(5, 0.3, 2.6), at * CFrame.new(0, 3.1, 0), DARK_WOOD)
	box(m, "Drawers", Vector3.new(1.8, 2.9, 2.4), at * CFrame.new(1.5, 1.5, 0), DARK_WOOD)
	box(m, "LegL", Vector3.new(0.3, 3, 0.3), at * CFrame.new(-2.2, 1.5, -1), DARK_WOOD)
	box(m, "LegL2", Vector3.new(0.3, 3, 0.3), at * CFrame.new(-2.2, 1.5, 1), DARK_WOOD)
	for i = 1, 3 do
		trim(m, "Paper", Vector3.new(0.9, 0.03, 1.2), at * CFrame.new(rng:NextNumber(-1.5, 0.5), 3.27 + i * 0.01, rng:NextNumber(-0.5, 0.5)) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0), LINEN, Enum.Material.SmoothPlastic)
	end
	lamp(m, at * CFrame.new(-1.6, 0, 0.6), 3.25, 12)
end

local function bench(parent: Instance, at: CFrame, length: number)
	box(parent, "Bench", Vector3.new(length, 0.4, 1.6), at * CFrame.new(0, 1.8, 0), WOOD)
	for _, x in { -length / 2 + 0.4, length / 2 - 0.4 } do
		trim(parent, "BenchLeg", Vector3.new(0.3, 1.6, 1.4), at * CFrame.new(x, 0.8, 0), DARK_WOOD)
	end
end

local function coatRack(parent: Instance, at: CFrame)
	trim(parent, "RackPole", Vector3.new(0.3, 7, 0.3), at * CFrame.new(0, 3.5, 0), DARK_WOOD)
	trim(parent, "RackFoot", Vector3.new(1.6, 0.2, 1.6), at * CFrame.new(0, 0.1, 0), DARK_WOOD)
	for i, a in { 0, 120, 240 } do
		local hanging = CFrame.Angles(0, math.rad(a), 0) * CFrame.new(0, 0, -0.6)
		trim(parent, "Coat", Vector3.new(1.4, 3.6, 0.5), at * hanging * CFrame.new(0, 4.8, 0), ({ Color3.fromRGB(46, 40, 34), Color3.fromRGB(70, 30, 26), Color3.fromRGB(40, 44, 50) })[i], Enum.Material.Fabric)
	end
end

local function boots(parent: Instance, at: CFrame)
	for i = 0, 2 do
		for _, x in { -0.35, 0.35 } do
			trim(parent, "Boot", Vector3.new(0.55, 1.2, 1.1), at * CFrame.new(i * 1.6 + x, 0.6, 0), Color3.fromRGB(34, 26, 20), Enum.Material.Fabric)
		end
	end
	trim(parent, "Puddle", Vector3.new(5, 0.03, 1.8), at * CFrame.new(1.6, 0.02, 0), Color3.fromRGB(30, 34, 36), Enum.Material.Glass).Transparency = 0.4
end

local function stairs(parent: Instance, x: number, fromZ: number, toZ: number, width: number)
	local steps = 12
	local rise = (Config.Room.WallHeight - 0.4) / steps
	local run = (fromZ - toZ) / steps
	for i = 1, steps do
		local z = fromZ - (i - 0.5) * run
		box(parent, "Step", Vector3.new(width, rise * i, run), CFrame.new(x, rise * i / 2, z), DARK_WOOD, Enum.Material.WoodPlanks)
		trim(parent, "Baluster", Vector3.new(0.2, 3, 0.2), CFrame.new(x + width / 2 - 0.2, rise * i + 1.5, z), WOOD)
	end
	local length = math.sqrt((fromZ - toZ) ^ 2 + (rise * steps) ^ 2)
	local angle = math.atan2(rise * steps, fromZ - toZ)
	trim(parent, "Handrail", Vector3.new(0.3, 0.3, length), CFrame.new(x + width / 2 - 0.2, (rise * steps) / 2 + 3, (fromZ + toZ) / 2) * CFrame.Angles(angle, 0, 0), DARK_WOOD)
end

local function plant(parent: Instance, at: CFrame)
	cylinder(parent, "Pot", 0.8, 1.6, at * CFrame.new(0, 0.8, 0), Color3.fromRGB(130, 70, 50), Enum.Material.Slate)
	for i = 1, 4 do
		trim(parent, "DeadStem", Vector3.new(0.1, rng:NextNumber(1.5, 3), 0.1), at * CFrame.new(rng:NextNumber(-0.3, 0.3), 2.6, rng:NextNumber(-0.3, 0.3)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-0.4, 0.4)), Color3.fromRGB(70, 56, 36), Enum.Material.Wood)
	end
end

local function trunk(parent: Instance, at: CFrame)
	box(parent, "Trunk", Vector3.new(4, 2.2, 2.4), at * CFrame.new(0, 1.1, 0), Color3.fromRGB(80, 54, 34))
	trim(parent, "TrunkLid", Vector3.new(4.1, 0.5, 2.5), at * CFrame.new(0, 2.3, 0), Color3.fromRGB(70, 46, 30))
	for _, x in { -1.4, 1.4 } do
		trim(parent, "Strap", Vector3.new(0.3, 2.8, 2.6), at * CFrame.new(x, 1.3, 0), IRON, Enum.Material.Metal)
	end
end

local function bust(parent: Instance, at: CFrame)
	box(parent, "Pedestal", Vector3.new(1.6, 4, 1.6), at * CFrame.new(0, 2, 0), Color3.fromRGB(160, 154, 146), Enum.Material.Marble)
	ball(parent, "Head", Vector3.new(1.1, 1.4, 1.1), at * CFrame.new(0, 5.3, 0), Color3.fromRGB(196, 190, 182), Enum.Material.Marble)
	trim(parent, "Chest", Vector3.new(1.6, 0.9, 0.9), at * CFrame.new(0, 4.45, 0), Color3.fromRGB(196, 190, 182), Enum.Material.Marble)
end

local function antlers(parent: Instance, at: CFrame)
	trim(parent, "Plaque", Vector3.new(1.4, 1.6, 0.3), at, DARK_WOOD)
	for _, side in { -1, 1 } do
		for i = 0, 3 do
			trim(parent, "Tine", Vector3.new(0.15, 1.4 - i * 0.15, 0.15), at * CFrame.new(side * (0.5 + i * 0.45), 0.6 + i * 0.35, -0.3) * CFrame.Angles(0, 0, math.rad(side * -(20 + i * 12))), Color3.fromRGB(200, 186, 160), Enum.Material.SmoothPlastic)
		end
	end
end

local function dartboard(parent: Instance, at: CFrame)
	local board = trim(parent, "Dartboard", Vector3.new(0.3, 2.2, 2.2), at * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(30, 24, 20), Enum.Material.Fabric)
	board.Shape = Enum.PartType.Cylinder
	local bull = trim(parent, "Bull", Vector3.new(0.32, 0.5, 0.5), at * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(150, 30, 30), Enum.Material.Fabric)
	bull.Shape = Enum.PartType.Cylinder
end

-- (Hanging lamps and chandeliers are grouped and tagged "HangingLamp", so each client can sway
-- them on their chains: client/Haunting.)
local function chandelier(parent: Instance, x: number, z: number)
	local top = Config.Room.WallHeight
	local m = group(parent, "Chandelier")
	trim(m, "ChandelierChain", Vector3.new(0.15, 3, 0.15), CFrame.new(x, top - 1.5, z), BRASS, Enum.Material.Metal)
	local hub = ball(m, "ChandelierHub", Vector3.new(1, 1, 1), CFrame.new(x, top - 3.2, z), BRASS, Enum.Material.Metal)
	for i = 0, 5 do
		local a = i * math.pi / 3
		local arm = CFrame.new(x + math.cos(a) * 1.6, top - 3.3, z + math.sin(a) * 1.6)
		trim(m, "Arm", Vector3.new(0.12, 0.12, 1.6), CFrame.lookAt(CFrame.new(x, top - 3.3, z).Position, arm.Position) * CFrame.new(0, 0, -0.8), BRASS, Enum.Material.Metal)
		trim(m, "Candle", Vector3.new(0.2, 0.6, 0.2), arm * CFrame.new(0, 0.35, 0), LINEN, Enum.Material.SmoothPlastic)
		ball(m, "Flame", Vector3.new(0.18, 0.28, 0.18), arm * CFrame.new(0, 0.8, 0), WARM, Enum.Material.Neon)
	end
	light(hub, Config.Room.LampRange, Config.Room.LampBrightness)
	CollectionService:AddTag(m, "HangingLamp")
end

local function hangingLamp(parent: Instance, x: number, z: number, range: number?, brightness: number?)
	local top = Config.Room.WallHeight
	local m = group(parent, "HangingLamp")
	trim(m, "LampChain", Vector3.new(0.15, 3, 0.15), CFrame.new(x, top - 1.5, z), IRON, Enum.Material.Metal)
	trim(m, "LampShade", Vector3.new(2.2, 0.6, 2.2), CFrame.new(x, top - 3.2, z), Color3.fromRGB(120, 92, 50), Enum.Material.Metal)
	local bulb = ball(m, "Bulb", Vector3.new(0.7, 0.7, 0.7), CFrame.new(x, top - 3.7, z), WARM, Enum.Material.Neon)
	light(bulb, range or Config.Room.LampRange, brightness or Config.Room.LampBrightness)
	CollectionService:AddTag(m, "HangingLamp")
end

------------------------------------------------------------------------------------------------
-- Rooms (door shapes at rotation 0: straight N+S, corner N+E, three-way N+E+W, four-way, single N)

local BUILDERS: { [string]: (props: Model) -> () } = {
	parlor = function(props)
		rug(props, Vector2.new(24, 24), CFrame.new(), Color3.fromRGB(96, 34, 32))
		fireplace(props, place(12, 17.5, 0))
		wardrobe(props, place(-15, 16.5, 0))
		armchair(props, place(15, -14, 135))
		sideTable(props, place(-15.5, -15.5, 0), true)
		grandfatherClock(props, place(16.5, 8, 90))
		portrait(props, onWall(13, 9, -18.8, 180), Vector2.new(3.5, 4.5))
		portrait(props, onWall(-18.8, 9, 12, -90), Vector2.new(3, 4))
		landscape(props, onWall(-18.8, 9, -12, -90), Vector2.new(6, 3.5))
		-- Two lamps off-centre so the board camera can see the table.
		hangingLamp(props, 11, -11, nil, Config.Room.LampBrightness * 0.8)
		hangingLamp(props, -11, 11, nil, Config.Room.LampBrightness * 0.8)
	end,
	crawlspace = function(props)
		-- The trapdoor down to the basement (Basement adds its prompt).
		box(props, "Trapdoor", Vector3.new(4, 0.15, 4), CFrame.new(-8, 0.08, -8), Color3.fromRGB(46, 34, 26), Enum.Material.WoodPlanks)
		trim(props, "TrapdoorRing", Vector3.new(0.6, 0.12, 0.15), CFrame.new(-8, 0.2, -6.6), IRON, Enum.Material.Metal)
		for _, x in { -9.6, -6.4 } do
			trim(props, "TrapdoorHinge", Vector3.new(0.5, 0.1, 0.3), CFrame.new(x, 0.18, -9.9), IRON, Enum.Material.Metal)
		end
		crate(props, place(-14, 14, 10), 4)
		crate(props, place(-9, 15, -15), 3)
		crate(props, place(14, 12, 40), 3.5)
		trunk(props, place(12, -12, 20))
		box(props, "Pipe", Vector3.new(0.8, 0.8, 38), CFrame.new(16, 12, 0), IRON, Enum.Material.Metal)
		box(props, "Pipe", Vector3.new(38, 0.6, 0.6), CFrame.new(0, 13, 16), IRON, Enum.Material.Metal)
		hangingLamp(props, 0, 4, 18, 0.45)
	end,

	-- Straight through (walls E and W; windows at z -3..3)
	front_hall = function(props)
		-- 14 wide: coats and boots along the east wall, a lamp table on the west.
		rug(props, Vector2.new(5, 34), CFrame.new(), Color3.fromRGB(70, 40, 30))
		coatRack(props, place(4.8, -14, 90))
		bench(props, place(5.3, 0, 90), 5)
		boots(props, place(4.8, 6.5, 90))
		wardrobe(props, place(4.5, 13, 90))
		sideTable(props, place(-5.5, -10, -90), true)
		portrait(props, onWall(-6.8, 9, 10, -90), Vector2.new(3, 4))
		landscape(props, onWall(-6.8, 8, -16, -90), Vector2.new(3, 2))
		hangingLamp(props, 0, -4)
		hangingLamp(props, 0, 12, nil, 0.6)
	end,
	back_hall = function(props)
		-- 12 wide and long.
		rug(props, Vector2.new(4, 34), CFrame.new(), Color3.fromRGB(50, 46, 60))
		wardrobe(props, place(-3.5, -12, -90))
		trunk(props, place(4.3, 10, 90))
		sideTable(props, place(4.3, -4, 90), true)
		portrait(props, onWall(-5.8, 9, 12, -90), Vector2.new(3, 4))
		portrait(props, onWall(5.8, 9, 0, 90), Vector2.new(2.5, 3.5))
		hangingLamp(props, 0, -8)
		hangingLamp(props, 0, 10, nil, 0.5)
	end,
	gallery = function(props)
		-- 16 wide: portraits all along both walls.
		rug(props, Vector2.new(5, 34), CFrame.new(), Color3.fromRGB(80, 24, 26))
		for _, z in { -15, -8, 0, 8, 15 } do
			portrait(props, onWall(-7.8, 8.5, z, -90), Vector2.new(3.4, 4.6))
		end
		for _, z in { -15, -8, 0 } do
			portrait(props, onWall(7.8, 8.5, z, 90), Vector2.new(3.4, 4.6))
		end
		wardrobe(props, place(5.5, 13, 90))
		bust(props, place(-5.5, -4, -90))
		bust(props, place(5.5, 6, 90))
		hangingLamp(props, 0, -8, nil, 0.8)
		hangingLamp(props, 0, 8, nil, 0.8)
	end,
	pantry = function(props)
		-- 14 wide: shelves of jars down both walls.
		for _, z in { -14, -7.5, 0 } do
			shelfUnit(props, place(5.8, z, 90), 5.5, "jars")
		end
		for _, z in { -14, -7.5, 1 } do
			shelfUnit(props, place(-5.8, z, -90), 5.5, "jars")
		end
		wardrobe(props, place(-4.5, 14, -90), WOOD)
		crate(props, place(4.5, 15, 15), 2.5)
		for _, z in { 6, 8.8, 11.6 } do
			cylinder(props, "Barrel", 1.2, 3.2, CFrame.new(5, 1.6, z), Color3.fromRGB(110, 80, 50), Enum.Material.WoodPlanks)
		end
		hangingLamp(props, 0, 0, 24, 0.7)
	end,
	stair_hall = function(props)
		-- 16 wide: stairs up the west side to nowhere.
		stairs(props, -4.5, 17, -9, 5)
		wardrobe(props, place(5.5, 12, 90))
		sideTable(props, place(6.3, -12, 90), true)
		portrait(props, onWall(7.8, 9, 0, 90), Vector2.new(3, 4))
		rug(props, Vector2.new(5, 14), CFrame.new(3, 0, 0), Color3.fromRGB(60, 40, 34))
		hangingLamp(props, 3, 0)
	end,
	sun_porch = function(props)
		armchair(props, place(-12, -8, -60), Color3.fromRGB(170, 150, 110))
		armchair(props, place(-12, 8, -120), Color3.fromRGB(170, 150, 110))
		sideTable(props, place(-15, 0, -90), false)
		for _, z in { -15, -10, 10, 15 } do
			plant(props, place(16.5, z, 90))
		end
		plant(props, place(-16.5, -15, 0))
		wardrobe(props, place(-16.5, 14, -90), LIGHT_WOOD)
		rug(props, Vector2.new(8, 26), CFrame.new(), Color3.fromRGB(110, 96, 60))
		hangingLamp(props, 0, 0, 24, 0.6)
	end,

	-- Corners (doors N and E; walls S and W; windows at S x -3..3 and W z -3..3)
	kitchen = function(props)
		counter(props, -18, 10, 17.6, 0)
		sink(props, place(0, 17.4, 0))
		stove(props, place(14.5, 17.2, 0))
		icebox(props, place(-17.4, -12, -90))
		wardrobe(props, place(-16.5, 10, -90), Color3.fromRGB(130, 120, 94))
		local t = table_(props, place(6, -6, 0), Vector2.new(5, 5), 3, LIGHT_WOOD)
		cylinder(t, "Bowl", 0.8, 0.4, CFrame.new(6, 3.4, -6), PORCELAIN, Enum.Material.SmoothPlastic).CanCollide = false
		chair(props, place(6, -9.2, 0))
		chair(props, place(6, -2.8, 180))
		hangingLamp(props, 4, 2)
	end,
	dining_room = function(props)
		rug(props, Vector2.new(14, 20), CFrame.new(-2, 0, 0), Color3.fromRGB(80, 30, 30))
		diningTable(props, place(-2, 0, 0))
		box(props, "Sideboard", Vector3.new(10, 3, 2), CFrame.new(-2, 1.5, 17.8), DARK_WOOD)
		for _, x in { -5, 1 } do
			cylinder(props, "Tureen", 0.6, 0.8, CFrame.new(x, 3.4, 17.8), PORCELAIN, Enum.Material.SmoothPlastic).CanCollide = false
		end
		wardrobe(props, place(-16.5, 12, -90))
		portrait(props, onWall(-18.8, 9, -12, -90), Vector2.new(3.5, 4.5))
		chandelier(props, -2, 0)
	end,
	living_room = function(props)
		rug(props, Vector2.new(16, 14), CFrame.new(0, 0, 8), Color3.fromRGB(70, 60, 40))
		sofa(props, place(0, 16.4, 0), Color3.fromRGB(80, 70, 50))
		table_(props, place(0, 9, 0), Vector2.new(5, 3), 1.6, DARK_WOOD)
		armchair(props, place(-8, 7, -90), Color3.fromRGB(90, 40, 36))
		armchair(props, place(8, 7, 90), Color3.fromRGB(90, 40, 36))
		floorLamp(props, place(-15.5, 16, 0))
		wardrobe(props, place(-16.5, -12, -90))
		gramophone(props, place(-17, 10, -90))
		landscape(props, onWall(-18.8, 9, 10, -90), Vector2.new(5, 3))
		hangingLamp(props, 0, 0, nil, 0.7)
	end,
	laundry_room = function(props)
		washer(props, place(-15, 16.5, 0))
		washer(props, place(-10.5, 16.5, 0))
		sink(props, place(8, 17.4, 0))
		clothesline(props, Vector3.new(-17, 9, -8), Vector3.new(14, 9, -8))
		trim(props, "Basket", Vector3.new(2.4, 1.6, 1.8), CFrame.new(4, 0.8, 8), Color3.fromRGB(150, 120, 80), Enum.Material.Fabric)
		wardrobe(props, place(-16.5, 12, -90), Color3.fromRGB(110, 110, 104))
		shelfUnit(props, place(-17.8, -14, -90), 5, "linens")
		hangingLamp(props, 2, 4, 26, 0.7)
	end,
	sewing_room = function(props)
		dressForm(props, place(-15.8, 0, -90))
		sewingTable(props, place(-9, 17.3, 0))
		chair(props, place(-9, 14.5, 180))
		wardrobe(props, place(12, 16.5, 0))
		shelfUnit(props, place(-17.8, -13, -90), 5, "linens")
		rug(props, Vector2.new(10, 10), CFrame.new(-4, 0, 6), Color3.fromRGB(100, 60, 70))
		floorLamp(props, place(-16, 14, 0))
		hangingLamp(props, 0, 0, nil, 0.7)
	end,
	library = function(props)
		for _, x in { -15, -9, 9, 15 } do
			bookshelf(props, place(x, 18, 0))
		end
		for _, z in { -15, -9, 9 } do
			bookshelf(props, place(-18, z, -90))
		end
		wardrobe(props, place(-16.5, 15, -90))
		armchair(props, place(4, 6, 180), Color3.fromRGB(60, 40, 30))
		sideTable(props, place(7.5, 6, 0), true)
		desk(props, place(8, -10, 180))
		chair(props, place(8, -12.5, 0))
		rug(props, Vector2.new(12, 10), CFrame.new(4, 0, 6), Color3.fromRGB(50, 56, 40))
		hangingLamp(props, 2, 2, nil, 0.7)
	end,

	-- Three doors (N, E, W; wall S with a window at x -3..3)
	den = function(props)
		fireplace(props, place(11, 17.5, 0))
		antlers(props, onWall(11, 12.5, 17.4, 0)) -- on the chimney breast
		armchair(props, place(8, 8, 160), Color3.fromRGB(80, 50, 30))
		armchair(props, place(14, 8, 200), Color3.fromRGB(80, 50, 30))
		rug(props, Vector2.new(8, 6), CFrame.new(11, 0, 12), Color3.fromRGB(60, 40, 24))
		wardrobe(props, place(-12, 16.5, 0))
		sideTable(props, place(-15.5, -15.5, 0), true)
		hangingLamp(props, 0, 0, nil, 0.7)
	end,
	sitting_room = function(props)
		-- Two chairs turned toward a wall.
		armchair(props, place(-11, 14, 180), Color3.fromRGB(70, 74, 100))
		armchair(props, place(-5.5, 14, 180), Color3.fromRGB(70, 74, 100))
		sideTable(props, place(-8.2, 16.5, 0), false)
		wardrobe(props, place(12, 16.5, 0))
		floorLamp(props, place(15, -15, 0))
		sofa(props, place(-12, -15.5, 180), Color3.fromRGB(70, 74, 100))
		rug(props, Vector2.new(14, 12), CFrame.new(0, 0, 4), Color3.fromRGB(60, 64, 90))
		portrait(props, onWall(-8, 9, 18.8, 0), Vector2.new(3, 4))
		hangingLamp(props, 0, 0, nil, 0.7)
	end,
	music_room = function(props)
		piano(props, place(-11, 17, 0))
		gramophone(props, place(12, 16, 0))
		trim(props, "MusicStand", Vector3.new(0.15, 4, 0.15), CFrame.new(4, 2, 6), BRASS, Enum.Material.Metal)
		trim(props, "StandDesk", Vector3.new(2, 1.4, 0.1), CFrame.new(4, 4.4, 6) * CFrame.Angles(math.rad(-20), 0, 0), BRASS, Enum.Material.Metal)
		chair(props, place(4, 9, 180))
		wardrobe(props, place(15, -16.5, 180))
		rug(props, Vector2.new(16, 10), CFrame.new(-2, 0, 10), Color3.fromRGB(70, 40, 76))
		portrait(props, onWall(-15, 9.5, -18.8, 180), Vector2.new(3, 4))
		hangingLamp(props, 0, 2, nil, 0.7)
	end,
	game_room = function(props)
		cardTable(props, place(0, 6, 0))
		dartboard(props, onWall(12, 7, 18.8, 0))
		shelfUnit(props, place(-12, 17.8, 0), 6, "linens")
		wardrobe(props, place(-15, -16.5, 180))
		armchair(props, place(15, -15, 135), Color3.fromRGB(40, 70, 50))
		hangingLamp(props, 0, 6, 24, 0.9)
	end,

	-- Four doors: corners only
	grand_hall = function(props)
		rug(props, Vector2.new(20, 20), CFrame.new(), Color3.fromRGB(90, 40, 34))
		grandfatherClock(props, place(-14, -17.5, 180))
		bust(props, place(15, -15, 135))
		wardrobe(props, place(15, 16.5, 0))
		bench(props, place(-15, 15, -45), 5)
		plant(props, place(-17, 17, 0))
		portrait(props, onWall(13, 9, -18.8, 180), Vector2.new(3.4, 4.6))
		portrait(props, onWall(-13, 9, 18.8, 0), Vector2.new(3.4, 4.6))
		portrait(props, onWall(18.8, 9, 13, 90), Vector2.new(3, 4))
		portrait(props, onWall(-18.8, 9, -13, -90), Vector2.new(3, 4))
		chandelier(props, 0, 0)
	end,
	foyer = function(props)
		rug(props, Vector2.new(14, 14), CFrame.new(), Color3.fromRGB(70, 46, 40))
		coatRack(props, place(-16, -16, 0))
		wardrobe(props, place(-15, 16.5, 0))
		sideTable(props, place(16, -16, 0), true)
		bench(props, place(16, 15, 45), 4)
		mirror(props, onWall(13, 8, -18.8, 180), Vector2.new(3, 5))
		plant(props, place(16.5, 11, 0))
		hangingLamp(props, 0, 0)
	end,

	-- One door (N; walls E, W, S; windows on each)
	bathroom = function(props)
		-- Small (22 x 22), off a short passage from its door.
		tub(props, place(-7.5, 4, -90))
		sink(props, place(9.4, -5, 90))
		mirror(props, onWall(10.8, 7.5, -5, 90), Vector2.new(2.6, 3.4))
		toilet(props, place(9.2, 5, 90))
		wardrobe(props, place(5.5, 8.5, 0), Color3.fromRGB(150, 146, 136))
		rug(props, Vector2.new(4, 3), CFrame.new(-2.5, 0, 4), Color3.fromRGB(90, 110, 100))
		-- The pull-cord and the outline of a hatch in the ceiling.
		local top = Config.Room.WallHeight
		trim(props, "Hatch", Vector3.new(6, 0.1, 4), CFrame.new(0, top - 0.05, -2), Color3.fromRGB(30, 22, 16))
		trim(props, "PullCord", Vector3.new(0.06, 4, 0.06), CFrame.new(2.6, top - 2, -2), LINEN, Enum.Material.Fabric)
		ball(props, "CordPull", Vector3.new(0.3, 0.3, 0.3), CFrame.new(2.6, top - 4.1, -2), BRASS, Enum.Material.Metal)
		hangingLamp(props, -4, -5, 18, 0.8)
	end,
	bedroom = function(props)
		bed(props, place(-11, 14.6, 0), Color3.fromRGB(60, 70, 96))
		sideTable(props, place(-15.5, 16.5, 0), true)
		box(props, "Dresser", Vector3.new(2.4, 3.6, 6), CFrame.new(17.6, 1.8, 10), DARK_WOOD)
		mirror(props, onWall(18.8, 6.5, 10, 90), Vector2.new(2.4, 2.4))
		armchair(props, place(12, -10, 60), Color3.fromRGB(70, 80, 100))
		trunk(props, place(-11, 8.5, 0))
		rug(props, Vector2.new(10, 8), CFrame.new(-4, 0, 6), Color3.fromRGB(70, 80, 110))
		landscape(props, onWall(-18.8, 9, -10, -90), Vector2.new(4, 3))
		hangingLamp(props, 0, -2, nil, 0.7)
	end,
	linen_closet = function(props)
		-- Small (20 x 20): three deep cupboards to hide in.
		wardrobe(props, place(-6.5, 7.5, 0))
		wardrobe(props, place(0, 7.5, 0))
		wardrobe(props, place(7.5, -3, 90))
		shelfUnit(props, place(-8.8, -4, -90), 6, "linens")
		trim(props, "Basket", Vector3.new(2.4, 1.6, 1.8), CFrame.new(5.5, 0.8, 7), Color3.fromRGB(150, 120, 80), Enum.Material.Fabric)
		rug(props, Vector2.new(7, 6), CFrame.new(0, 0, 0), Color3.fromRGB(60, 40, 30))
		hangingLamp(props, 0, -2, 16, 0.6)
	end,
	-- Exit rooms (outside door: south wall, or east for the straight-through ones; kept clear)
	boathouse = function(props)
		local hull = Color3.fromRGB(86, 58, 40)
		box(props, "Hull", Vector3.new(5, 1.8, 12), CFrame.new(-11, 1.4, 2), hull, Enum.Material.WoodPlanks)
		box(props, "HullBow", Vector3.new(3.4, 1.8, 2), CFrame.new(-11, 1.4, -4.8) * CFrame.Angles(0, math.rad(45), 0), hull, Enum.Material.WoodPlanks)
		box(props, "HullInside", Vector3.new(4, 0.2, 10.5), CFrame.new(-11, 2.25, 2.4), Color3.fromRGB(50, 36, 26), Enum.Material.WoodPlanks)
		for _, z in { -2, 6 } do
			box(props, "Block", Vector3.new(6, 0.5, 1.2), CFrame.new(-11, 0.25, z), DARK_WOOD)
		end
		for _, z in { 0, 3 } do
			trim(props, "Oar", Vector3.new(0.3, 0.2, 8), onWall(-18.6, 7 + z / 2, z - 4, -90), LIGHT_WOOD)
		end
		trim(props, "Net", Vector3.new(0.1, 5, 7), CFrame.new(18.8, 8, -8), Color3.fromRGB(90, 96, 80), Enum.Material.Fabric).Transparency = 0.3
		crate(props, place(14, -14, 10), 4)
		crate(props, place(9, -15.5, -20), 3)
		trunk(props, place(16.5, 6, 90))
		wardrobe(props, place(-12, -16.5, 180), Color3.fromRGB(70, 66, 60))
		for _, at in { Vector3.new(4, 0.02, 6), Vector3.new(-4, 0.02, 12) } do
			trim(props, "Puddle", Vector3.new(4, 0.03, 3), CFrame.new(at), Color3.fromRGB(26, 30, 34), Enum.Material.Glass).Transparency = 0.35
		end
		hangingLamp(props, 2, -2, nil, 0.7)
	end,
	root_cellar = function(props)
		-- Small (24 x 24) and cold.
		for _, z in { -6, 0.5 } do
			shelfUnit(props, place(10.8, z, 90), 5.5, "jars")
			shelfUnit(props, place(-10.8, z, -90), 5.5, "jars")
		end
		wardrobe(props, place(-7, -9.5, 180), DARK_WOOD)
		for _, x in { 6.5, 9 } do
			cylinder(props, "Barrel", 1.2, 3.2, CFrame.new(x, 1.6, 8.5), Color3.fromRGB(100, 72, 46), Enum.Material.WoodPlanks)
		end
		crate(props, place(-8.5, 8.5, 20), 3)
		trim(props, "RootPile", Vector3.new(4, 0.8, 3), CFrame.new(-4, 0.4, 4), Color3.fromRGB(110, 90, 60), Enum.Material.Ground)
		hangingLamp(props, 0, 0, 16, 0.5)
	end,
	greenhouse = function(props)
		for _, z in { -12, 0, 12 } do
			table_(props, place(-8, z, 0), Vector2.new(4, 7), 3)
			for _, dz in { -2, 1.5 } do
				plant(props, CFrame.new(-8, 3.2, z + dz))
			end
		end
		for _, z in { -15, -9, 9, 15 } do
			plant(props, place(-16.5, z, -90))
		end
		table_(props, place(8, -10, 0), Vector2.new(4, 7), 3)
		plant(props, CFrame.new(8, 3.2, -11))
		wardrobe(props, place(14, 14, 90), Color3.fromRGB(70, 80, 66))
		trim(props, "Soil", Vector3.new(6, 0.4, 3), CFrame.new(6, 0.2, 10), Color3.fromRGB(56, 42, 30), Enum.Material.Ground)
		hangingLamp(props, 0, -6, nil, 0.7)
		hangingLamp(props, 0, 10, nil, 0.6)
	end,
	study = function(props)
		desk(props, place(-8, -10, 180))
		chair(props, place(-8, -7.5, 0))
		bookshelf(props, place(-12, -18, 180))
		bookshelf(props, place(-18, -4, -90))
		bookshelf(props, place(-18, 4, -90))
		armchair(props, place(10, 8, -135), Color3.fromRGB(80, 50, 40))
		sideTable(props, place(13.5, 11.5, 0), true)
		wardrobe(props, place(-15, 14, 0))
		rug(props, Vector2.new(12, 10), CFrame.new(-2, 0, -2), Color3.fromRGB(90, 40, 36))
		trim(props, "Letter", Vector3.new(0.8, 0.02, 1.1), CFrame.new(-8.5, 3.27, -10) * CFrame.Angles(0, 0.3, 0), PALE, Enum.Material.Fabric)
		hangingLamp(props, -2, -2, nil, 0.75)
	end,
	chapel = function(props)
		-- Pews face the back, away from the altar.
		for _, z in { -6, 0, 6, 12 } do
			bench(props, place(-8, z, 180), 8)
			bench(props, place(6, z, 180), 8)
		end
		table_(props, place(0, -15, 0), Vector2.new(7, 3), 3.4, LINEN)
		for _, x in { -2.5, 2.5 } do
			cylinder(props, "Candle", 0.25, 1.2, CFrame.new(x, 4.2, -15), PALE)
		end
		trim(props, "Cross", Vector3.new(0.4, 5, 0.3), onWall(0, 10, -18.8, 180), DARK_WOOD)
		trim(props, "CrossBar", Vector3.new(2.6, 0.4, 0.3), onWall(0, 11, -18.8, 180), DARK_WOOD)
		wardrobe(props, place(-15, 14, 0), DARK_WOOD)
		rug(props, Vector2.new(3, 30), CFrame.new(-1, 0, 0), Color3.fromRGB(90, 26, 28))
		hangingLamp(props, 0, -8, nil, 0.7)
		hangingLamp(props, 0, 8, nil, 0.6)
	end,
	workshop = function(props)
		table_(props, place(-6, -6, 0), Vector2.new(9, 4), 3.2, LIGHT_WOOD)
		for _, x in { -9, -5, -2 } do
			trim(props, "ToolOutline", Vector3.new(1.4, 3, 0.05), onWall(x, 8, -18.85, 180), Color3.fromRGB(30, 26, 22))
		end
		trim(props, "Saw", Vector3.new(1.2, 2.6, 0.1), onWall(-9, 8, -18.7, 180), Color3.fromRGB(160, 160, 166), Enum.Material.Metal)
		trim(props, "Hammer", Vector3.new(0.4, 2.4, 0.2), onWall(-2, 8, -18.7, 180), DARK_WOOD)
		shelfUnit(props, place(-17.8, 8, -90), 6, "jars")
		for _, z in { 4, 7 } do
			box(props, "Sawhorse", Vector3.new(4, 0.4, 0.5), CFrame.new(8, 2.4, z), WOOD)
		end
		box(props, "Plank", Vector3.new(1.4, 0.3, 8), CFrame.new(8, 2.75, 5.5), LIGHT_WOOD, Enum.Material.WoodPlanks)
		crate(props, place(14, -14, 5), 3.5)
		crate(props, place(15.5, -9.5, 30), 2.5)
		wardrobe(props, place(15, 14, 0), WOOD)
		hangingLamp(props, -2, -4, nil, 0.75)
	end,
	nursery = function(props)
		bed(props, place(-11, 14.6, 0), Color3.fromRGB(160, 120, 130))
		chair(props, place(10, 6, -135), LIGHT_WOOD)
		trunk(props, place(-15.5, 6, -90))
		wardrobe(props, place(12, 16.5, 0), Color3.fromRGB(150, 130, 120))
		rug(props, Vector2.new(10, 8), CFrame.new(2, 0, 2), Color3.fromRGB(150, 110, 120))
		-- A mobile turning slowly over the bed.
		trim(props, "MobileString", Vector3.new(0.05, 4, 0.05), CFrame.new(-11, Config.Room.WallHeight - 2, 12), LINEN, Enum.Material.Fabric)
		for i = 0, 3 do
			local a = i * math.pi / 2
			ball(props, "MobileStar", Vector3.new(0.5, 0.5, 0.5), CFrame.new(-11 + math.cos(a) * 1.2, Config.Room.WallHeight - 4.4, 12 + math.sin(a) * 1.2), Color3.fromRGB(220, 200, 150), Enum.Material.Fabric)
		end
		landscape(props, onWall(-18.8, 9, -8, -90), Vector2.new(4, 3))
		hangingLamp(props, 0, -4, nil, 0.6)
	end,
	mudroom = function(props)
		-- 30 x 30: everything you'd wear to go outside, by a door you can't open.
		bench(props, place(-12.3, -4, -90), 6)
		boots(props, place(-12.2, 2, -90))
		coatRack(props, place(-12, -11, 0))
		coatRack(props, place(11.5, -11, 0))
		wardrobe(props, place(10, 12.5, 0), WOOD)
		crate(props, place(12, 3, 10), 2.5)
		rug(props, Vector2.new(6, 10), CFrame.new(0, 0, 6), Color3.fromRGB(70, 56, 40))
		trim(props, "Puddle", Vector3.new(3, 0.03, 4), CFrame.new(-2, 0.02, 11), Color3.fromRGB(30, 34, 36), Enum.Material.Glass).Transparency = 0.4
		hangingLamp(props, 0, 0, nil, 0.7)
	end,

}

-- Add this room's furniture and lamps to its template model.
function RoomProps.build(id: string, room: Model)
	local builder = BUILDERS[id]
	if not builder then
		return
	end
	local props = Instance.new("Model")
	props.Name = "Props"
	props.Parent = room
	builder(props)
end

return RoomProps
