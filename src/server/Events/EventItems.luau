--!strict
-- The things events ask you to find and use, built from parts: an old brass skeleton key, a
-- glass cartridge fuse with a glowing filament, a fuse cabinet for the Parlor wall, and a
-- church candle on a brass dish. Things to be found float a little off the floor, turn slowly
-- (tag "EventSpin", turned by each client) and glint, with a soft pool of light under them,
-- so they can be spotted across a room.

local CollectionService = game:GetService("CollectionService")

local EventItems = {}

local BRASS = Color3.fromRGB(196, 156, 70)
local IRON = Color3.fromRGB(46, 44, 42)
local GLASS = Color3.fromRGB(220, 232, 236)
local WAX = Color3.fromRGB(236, 226, 200)
local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A cylinder along the X axis of `cf`.
local function rod(parent: Instance, name: string, radius: number, length: number, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = part(parent, name, Vector3.new(length, radius * 2, radius * 2), cf, color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function glint(at: BasePart, color: Color3)
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "Glint"
	sparkle.Texture = SPARKLES
	sparkle.Color = ColorSequence.new(color)
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Lifetime = NumberRange.new(0.6, 1.2)
	sparkle.Rate = 6
	sparkle.Speed = NumberRange.new(0.3, 0.8)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Parent = at
end

local function glow(at: BasePart, color: Color3, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Name = "Glow"
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = true
	light.Parent = at
end

-- Weld every part of the model to its handle, so it moves as one once it's picked up.
local function weldTo(model: Model, handle: BasePart)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p ~= handle then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = p
			weld.Parent = p
		end
	end
end

-- A faint pool of light on the floor under something to be found.
function EventItems.pool(parent: Instance, floor: Vector3, color: Color3): Part
	local disc = part(parent, "LightPool", Vector3.new(0.05, 3.2, 3.2), CFrame.new(floor + Vector3.new(0, 0.04, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.Neon)
	disc.Shape = Enum.PartType.Cylinder
	disc.Transparency = 0.82
	return disc
end

-- Something that's picked up: no longer turning, unanchored and carried (welded to `to`).
function EventItems.carry(model: Model, to: BasePart, offset: CFrame)
	CollectionService:RemoveTag(model, "EventSpin")
	local handle = model.PrimaryPart :: BasePart
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.Massless = true
			p.CanCollide = false
		end
	end
	handle.CFrame = to.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = to
	weld.Part1 = handle
	weld.Parent = handle
end

-- An old skeleton key, floating at `at` (its middle). Returns the model and the part to prompt on.
function EventItems.key(parent: Instance, at: CFrame): (Model, BasePart)
	local m = Instance.new("Model")
	m.Name = "Key"
	local handle = part(m, "Handle", Vector3.new(1.9, 0.8, 0.5), at, BRASS, Enum.Material.Metal)
	handle.Transparency = 1
	-- The bow: a ring of short pieces.
	local bowCentre = at * CFrame.new(-0.62, 0, 0)
	for i = 0, 9 do
		local a = i * math.pi * 2 / 10
		part(m, "Bow", Vector3.new(0.2, 0.1, 0.12), bowCentre * CFrame.Angles(0, 0, a) * CFrame.new(0, 0.26, 0), BRASS, Enum.Material.Metal).Reflectance = 0.2
	end
	-- The shank and its collar, and the bit with its teeth.
	rod(m, "Shank", 0.055, 1.05, at * CFrame.new(0.2, 0, 0), BRASS, Enum.Material.Metal).Reflectance = 0.2
	rod(m, "Collar", 0.09, 0.08, at * CFrame.new(-0.3, 0, 0), BRASS, Enum.Material.Metal)
	part(m, "Bit", Vector3.new(0.28, 0.3, 0.08), at * CFrame.new(0.6, -0.18, 0), BRASS, Enum.Material.Metal)
	part(m, "Tooth", Vector3.new(0.08, 0.12, 0.08), at * CFrame.new(0.52, -0.36, 0), BRASS, Enum.Material.Metal)
	part(m, "Tooth", Vector3.new(0.08, 0.2, 0.08), at * CFrame.new(0.68, -0.4, 0), BRASS, Enum.Material.Metal)
	glow(handle, Color3.fromRGB(255, 210, 120), 10, 1.2)
	glint(handle, Color3.fromRGB(255, 230, 160))
	m.PrimaryPart = handle
	m.Parent = parent
	CollectionService:AddTag(m, "EventSpin")
	return m, handle
end

-- A glass cartridge fuse with brass caps and a glowing filament, standing at `at` (its middle).
function EventItems.fuse(parent: Instance, at: CFrame): (Model, BasePart)
	local m = Instance.new("Model")
	m.Name = "Fuse"
	local upright = at * CFrame.Angles(0, 0, math.rad(90)) -- the rods run along X; stand it up
	local handle = part(m, "Handle", Vector3.new(1.3, 0.7, 0.7), upright, BRASS, Enum.Material.Metal)
	handle.Transparency = 1
	local tube = rod(m, "Glass", 0.2, 0.8, upright, GLASS, Enum.Material.Glass)
	tube.Transparency = 0.5
	for _, x in { -0.5, 0.5 } do
		rod(m, "Cap", 0.24, 0.22, upright * CFrame.new(x, 0, 0), BRASS, Enum.Material.Metal).Reflectance = 0.25
		rod(m, "Contact", 0.1, 0.12, upright * CFrame.new(x * 1.32, 0, 0), BRASS, Enum.Material.Metal)
	end
	rod(m, "Filament", 0.025, 0.8, upright, Color3.fromRGB(255, 200, 90), Enum.Material.Neon)
	rod(m, "Label", 0.205, 0.22, upright * CFrame.new(0.15, 0, 0), Color3.fromRGB(200, 60, 40), Enum.Material.SmoothPlastic)
	glow(handle, Color3.fromRGB(255, 205, 80), 12, 1.3)
	glint(handle, Color3.fromRGB(255, 220, 140))
	weldTo(m, handle)
	m.PrimaryPart = handle
	m.Parent = parent
	CollectionService:AddTag(m, "EventSpin")
	return m, handle
end

-- The fuse cabinet on a wall: `at` is its face's centre, facing out of the wall (-Z). Returns
-- the part to prompt on and a function that shows the fuse in place and the power coming back.
function EventItems.fuseBox(parent: Instance, at: CFrame): (BasePart, () -> ())
	local m = Instance.new("Model")
	m.Name = "FuseBox"
	local cabinet = part(m, "Cabinet", Vector3.new(3, 4, 0.8), at * CFrame.new(0, 0, 0.4), Color3.fromRGB(78, 82, 86), Enum.Material.DiamondPlate)
	cabinet.CanCollide = true
	-- Its door hangs open on the left, showing the empty slot.
	part(m, "Door", Vector3.new(2.9, 3.9, 0.1), at * CFrame.new(-1.45, 0, 0) * CFrame.Angles(0, math.rad(-70), 0) * CFrame.new(-1.45, 0, 0), Color3.fromRGB(70, 74, 78), Enum.Material.Metal)
	part(m, "Back", Vector3.new(2.7, 3.7, 0.05), at * CFrame.new(0, 0, 0.05), Color3.fromRGB(30, 30, 32), Enum.Material.SmoothPlastic)
	for i = 0, 2 do
		part(m, "Breaker", Vector3.new(0.6, 0.3, 0.15), at * CFrame.new(-0.6, 1.2 - i * 0.5, -0.05), Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic)
	end
	local slot = part(m, "Slot", Vector3.new(0.6, 1.4, 0.1), at * CFrame.new(0.6, 0.2, -0.05), Color3.fromRGB(40, 36, 30), Enum.Material.SmoothPlastic)
	local warning = part(m, "Warning", Vector3.new(1.6, 0.6, 0.02), at * CFrame.new(0, -1.5, -0.02), Color3.fromRGB(230, 190, 40), Enum.Material.SmoothPlastic)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "DANGER · HIGH VOLTAGE"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.fromRGB(20, 18, 14)
	label.Parent = gui
	gui.Parent = warning
	-- The conduit up the wall to the ceiling.
	rod(m, "Conduit", 0.18, 7, at * CFrame.new(0, 5.5, 0.4) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(90, 90, 92), Enum.Material.Metal)
	local lamp = part(m, "Lamp", Vector3.new(0.3, 0.3, 0.1), at * CFrame.new(1.1, 1.7, -0.05), Color3.fromRGB(120, 20, 16), Enum.Material.Neon)
	m.Parent = parent
	return cabinet, function()
		slot.Color = Color3.fromRGB(255, 205, 80)
		slot.Material = Enum.Material.Neon
		lamp.Color = Color3.fromRGB(80, 255, 120)
	end
end

-- A thick church candle on a brass dish, standing on the floor at `base`. Returns the wax (to
-- prompt on) and a function that lights it.
function EventItems.candle(parent: Instance, base: Vector3, height: number): (BasePart, () -> ())
	local m = Instance.new("Model")
	m.Name = "Candle"
	local dish = rod(m, "Dish", 0.85, 0.18, CFrame.new(base + Vector3.new(0, 0.09, 0)) * CFrame.Angles(0, 0, math.rad(90)), BRASS, Enum.Material.Metal)
	dish.Reflectance = 0.2
	rod(m, "Rim", 0.9, 0.06, CFrame.new(base + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), BRASS, Enum.Material.Metal)
	local wax = rod(m, "Wax", 0.32, height, CFrame.new(base + Vector3.new(0, 0.18 + height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), WAX, Enum.Material.SmoothPlastic)
	wax.CanCollide = true
	for i, a in { 0.5, 2.2, 3.9, 5.3 } do
		part(m, "Drip", Vector3.new(0.12, 0.3 + i * 0.12, 0.12), CFrame.new(base + Vector3.new(math.cos(a) * 0.3, 0.18 + height - 0.2 - i * 0.06, math.sin(a) * 0.3)), WAX, Enum.Material.SmoothPlastic)
	end
	local top = base + Vector3.new(0, 0.18 + height, 0)
	part(m, "Wick", Vector3.new(0.04, 0.16, 0.04), CFrame.new(top + Vector3.new(0, 0.08, 0)), Color3.fromRGB(20, 16, 12), Enum.Material.SmoothPlastic)
	local flame = part(m, "Flame", Vector3.new(0.22, 0.42, 0.22), CFrame.new(top + Vector3.new(0, 0.34, 0)), Color3.fromRGB(255, 176, 70), Enum.Material.Neon)
	flame.Transparency = 1
	m.Parent = parent
	return wax, function()
		flame.Transparency = 0
		local fire = Instance.new("Fire")
		fire.Size = 1.2
		fire.Heat = 3
		fire.Color = Color3.fromRGB(255, 170, 60)
		fire.SecondaryColor = Color3.fromRGB(255, 90, 30)
		fire.Parent = flame
		glow(flame, Color3.fromRGB(255, 170, 60), 16, 1.4)
	end
end

-- Dress a door panel (a part filling a doorway) as a heavy plank door with iron straps.
function EventItems.dressDoor(panel: BasePart)
	local size = panel.Size
	panel.Color = Color3.fromRGB(64, 46, 32)
	panel.Material = Enum.Material.WoodPlanks
	for _, side in { -1, 1 } do
		for _, y in { -size.Y * 0.3, size.Y * 0.3 } do
			local strap = part(panel, "Strap", Vector3.new(size.X - 0.4, 0.35, 0.08), panel.CFrame * CFrame.new(0, y, side * (size.Z / 2 + 0.03)), IRON, Enum.Material.Metal)
			strap.CanQuery = false
		end
		local ring = rod(panel, "Ring", 0.25, 0.08, panel.CFrame * CFrame.new(size.X * 0.32, 0, side * (size.Z / 2 + 0.05)) * CFrame.Angles(0, math.rad(90), 0), IRON, Enum.Material.Metal)
		ring.CanQuery = false
	end
end

return EventItems
