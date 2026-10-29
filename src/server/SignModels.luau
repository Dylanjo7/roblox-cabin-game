--!strict
-- The clue signs, built from parts in world space. Each builder returns a Model with a part
-- named "PromptAnchor" where the "Record in Journal" prompt goes.
--   Music Box: a small open box with a dancer, playing a faint lullaby you can follow.
--   Wet Footprints: bare wet prints from a doorway that stop dead in the middle of the room.
--   Rocking Chair: an empty rocking chair on open floor, rocking by itself (tag "RockingChair";
--     each client rocks it) and creaking, loud enough to follow.
--   Frost: the room's windows ice over, frost creeps across the floor, a cold light; the client
--     makes your breath fog in there (room attribute "Frost").
--   Tally Marks: groups of scratches gouged into a wall.
--   The Doll: a cloth doll sitting in a corner, facing the wall. Its stitched mouth is a smile,
--     or a frown (setFrown) once a decoy is exposed.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local SignModels = {}

local WET = Color3.fromRGB(26, 30, 32)
local CLOTH = Color3.fromRGB(150, 120, 104)
local STITCH = Color3.fromRGB(40, 20, 20)
local SCRATCH = Color3.fromRGB(200, 186, 160)
local FROST = Color3.fromRGB(214, 232, 240)

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- A spot on the inner face of one of a room's walls, away from doorways and windows, facing
-- into the room. `centre` is the room's floor-top centre.
-- `half`: half the room's inside size along world x and z.
function SignModels.wallSpot(centre: Vector3, half: Vector2, rng: Random, height: number): CFrame
	local quarter = rng:NextInteger(0, 3)
	local turn = quarter * math.pi / 2
	-- Walls turned an odd number of quarters face along x (their length runs along z).
	local depth, length = if quarter % 2 == 0 then half.Y else half.X, if quarter % 2 == 0 then half.X else half.Y
	local inner = depth - 0.1
	local along = rng:NextNumber(math.min(length * 0.4, 8), math.max(length - 4, 2)) * (if rng:NextNumber() < 0.5 then -1 else 1)
	-- Built on the north wall (facing south, +Z), then turned to the chosen wall.
	return CFrame.new(centre) * CFrame.Angles(0, turn, 0) * CFrame.new(along, height, -inner) * CFrame.Angles(0, math.pi, 0)
end

function SignModels.musicBox(parent: Instance, at: CFrame): Model
	local m = model(parent, "MusicBox")
	local box = part(m, "PromptAnchor", Vector3.new(1.3, 0.6, 0.9), at * CFrame.new(0, 0.3, 0), Color3.fromRGB(70, 40, 30), Enum.Material.Wood)
	box.CanCollide = true
	part(m, "Velvet", Vector3.new(1.1, 0.05, 0.7), at * CFrame.new(0, 0.6, 0), Color3.fromRGB(120, 20, 30), Enum.Material.Fabric)
	part(m, "Lid", Vector3.new(1.3, 0.08, 0.9), at * CFrame.new(0, 0.95, 0.45) * CFrame.Angles(math.rad(-75), 0, 0) * CFrame.new(0, 0, -0.45), Color3.fromRGB(70, 40, 30), Enum.Material.Wood)
	part(m, "LidMirror", Vector3.new(1, 0.02, 0.6), at * CFrame.new(0, 0.95, 0.45) * CFrame.Angles(math.rad(-75), 0, 0) * CFrame.new(0, -0.05, -0.45), Color3.fromRGB(170, 180, 186), Enum.Material.Glass)
	part(m, "Dancer", Vector3.new(0.1, 0.35, 0.1), at * CFrame.new(0, 0.82, 0), Color3.fromRGB(230, 220, 214))
	part(m, "Skirt", Vector3.new(0.24, 0.06, 0.24), at * CFrame.new(0, 0.78, 0), Color3.fromRGB(230, 200, 210), Enum.Material.Fabric)
	part(m, "Key", Vector3.new(0.4, 0.15, 0.05), at * CFrame.new(0.75, 0.3, 0), Color3.fromRGB(150, 120, 60), Enum.Material.Metal)
	local sound = Instance.new("Sound")
	sound.SoundId = Config.Sounds.lullaby or ""
	sound.Looped = true
	sound.Volume = 0.55
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 6
	sound.RollOffMaxDistance = 110
	sound.Parent = box
	sound:Play()
	return m
end

-- Bare footprints from `from` to `to` (floor level), left and right in turn, ending in place.
function SignModels.footprints(parent: Instance, from: Vector3, to: Vector3): Model
	local m = model(parent, "WetFootprints")
	local dir = (to - from) * Vector3.new(1, 0, 1)
	local length = dir.Magnitude
	local facing = CFrame.lookAt(from, from + dir)
	local steps = math.max(2, math.floor(length / 1.5))
	for i = 0, steps do
		local side = if i % 2 == 0 then -0.35 else 0.35
		local foot = facing * CFrame.new(side, 0.02, -i * length / steps)
		if i == steps then
			-- Standing still: both feet together.
			foot = facing * CFrame.new(-0.3, 0.02, -length)
			part(m, "Sole", Vector3.new(0.42, 0.03, 0.7), facing * CFrame.new(0.3, 0.02, -length), WET, Enum.Material.Glass)
			part(m, "Toes", Vector3.new(0.46, 0.03, 0.2), facing * CFrame.new(0.3, 0.02, -length - 0.5), WET, Enum.Material.Glass)
		end
		local sole = part(m, if i == steps then "PromptAnchor" else "Sole", Vector3.new(0.42, 0.03, 0.7), foot, WET, Enum.Material.Glass)
		sole.Reflectance = 0.2
		part(m, "Toes", Vector3.new(0.46, 0.03, 0.2), foot * CFrame.new(0, 0, -0.5), WET, Enum.Material.Glass).Reflectance = 0.2
	end
	-- A small puddle where they stopped.
	part(m, "Puddle", Vector3.new(2.2, 0.02, 2.4), facing * CFrame.new(0, 0.015, -length), WET, Enum.Material.Glass).Transparency = 0.35
	return m
end

-- An empty rocking chair. `at` is the floor under the middle of its rockers (its pivot, the
-- point it rocks about); it faces -Z.
function SignModels.rockingChair(parent: Instance, at: CFrame): Model
	local m = model(parent, "RockingChair")
	local wood = Color3.fromRGB(92, 62, 40)
	local lean = math.tan(math.rad(12))
	for _, x in { -0.9, 0.9 } do
		-- A runner each side, curling up at both ends.
		part(m, "Rocker", Vector3.new(0.16, 0.2, 2.4), at * CFrame.new(x, 0.1, 0), wood, Enum.Material.Wood)
		for _, z in { -1, 1 } do
			part(m, "RockerTip", Vector3.new(0.16, 0.18, 0.7), at * CFrame.new(x, 0.22, z * 1.45) * CFrame.Angles(math.rad(z * 24), 0, 0), wood, Enum.Material.Wood)
		end
		for _, z in { -0.75, 0.75 } do
			part(m, "Leg", Vector3.new(0.17, 1.55, 0.17), at * CFrame.new(x, 0.95, z), wood, Enum.Material.Wood)
		end
		part(m, "Upright", Vector3.new(0.2, 3.4, 0.2), at * CFrame.new(x, 3.35, 0.9 + 1.55 * lean) * CFrame.Angles(math.rad(12), 0, 0), wood, Enum.Material.Wood)
		part(m, "Armrest", Vector3.new(0.22, 0.16, 1.9), at * CFrame.new(x * 1.06, 2.7, 0), wood, Enum.Material.Wood)
		part(m, "ArmPost", Vector3.new(0.14, 0.95, 0.14), at * CFrame.new(x * 1.06, 2.15, -0.8), wood, Enum.Material.Wood)
	end
	local seat = part(m, "PromptAnchor", Vector3.new(1.95, 0.22, 1.8), at * CFrame.new(0, 1.8, 0), wood, Enum.Material.Wood)
	seat.CanCollide = true
	-- Spindles up the back, leaning back with it, and a top rail.
	for i = -2, 2 do
		part(m, "Spindle", Vector3.new(0.1, 2.6, 0.1), at * CFrame.new(i * 0.34, 3.3, 0.9 + 1.5 * lean) * CFrame.Angles(math.rad(12), 0, 0), wood, Enum.Material.Wood)
	end
	part(m, "TopRail", Vector3.new(2.0, 0.34, 0.16), at * CFrame.new(0, 4.75, 0.9 + 2.95 * lean) * CFrame.Angles(math.rad(12), 0, 0), wood, Enum.Material.Wood)
	-- An old blanket thrown over one arm.
	part(m, "Blanket", Vector3.new(0.5, 1.2, 1.4), at * CFrame.new(1.05, 2.4, 0.1), Color3.fromRGB(110, 36, 34), Enum.Material.Fabric)
	m.WorldPivot = at
	local creak = Instance.new("Sound")
	creak.SoundId = Config.Sounds.creak or ""
	creak.Looped = true
	creak.Volume = 0.5
	creak.PlaybackSpeed = 0.85
	creak.RollOffMode = Enum.RollOffMode.InverseTapered
	creak.RollOffMinDistance = 6
	creak.RollOffMaxDistance = 90
	creak.Parent = seat
	creak:Play()
	CollectionService:AddTag(m, "RockingChair")
	return m
end

-- Ice over every window in the room; returns a function that thaws them again.
function SignModels.frost(parent: Instance, room: Model, centre: Vector3, half: Vector2, rng: Random): (Model, () -> ())
	local m = model(parent, "Frost")
	local saved: { { glass: BasePart, color: Color3, material: Enum.Material, transparency: number } } = {}
	for _, inst in room:GetDescendants() do
		if inst:IsA("BasePart") and CollectionService:HasTag(inst, "CabinWindow") then
			table.insert(saved, { glass = inst, color = inst.Color, material = inst.Material, transparency = inst.Transparency })
			inst.Color = FROST
			inst.Material = Enum.Material.Ice
			inst.Transparency = 0.15
		end
	end
	room:SetAttribute("Frost", true)
	-- Frost creeping across the floor, and a cold light.
	for i = 1, 6 do
		local spot = centre + Vector3.new(rng:NextNumber(-half.X + 4, half.X - 4), 0.02, rng:NextNumber(-half.Y + 4, half.Y - 4))
		part(m, if i == 1 then "PromptAnchor" else "Rime", Vector3.new(rng:NextNumber(2, 5), 0.03, rng:NextNumber(2, 5)), CFrame.new(spot) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), FROST, Enum.Material.Ice).Transparency = 0.25
	end
	local glow = part(m, "ColdLight", Vector3.new(0.5, 0.5, 0.5), CFrame.new(centre + Vector3.new(0, 10, 0)), FROST)
	glow.Transparency = 1
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(160, 200, 255)
	light.Range = 24
	light.Brightness = 0.6
	light.Parent = glow
	local function thaw()
		for _, s in saved do
			s.glass.Color = s.color
			s.glass.Material = s.material
			s.glass.Transparency = s.transparency
		end
		room:SetAttribute("Frost", nil)
	end
	return m, thaw
end

-- `count` scratches gouged into a wall, in groups of five (four down, one across).
function SignModels.tally(parent: Instance, at: CFrame, count: number): Model
	local m = model(parent, "TallyMarks")
	local x = -(count + math.floor(count / 5)) * 0.25
	for i = 1, count do
		local isCross = i % 5 == 0
		if isCross then
			part(m, "Scratch", Vector3.new(0.1, 2.2, 0.04), at * CFrame.new(x - 0.6, 0, -0.03) * CFrame.Angles(0, 0, math.rad(60)), SCRATCH, Enum.Material.Wood)
			x += 0.5
		else
			part(m, "Scratch", Vector3.new(0.09, 1.4, 0.04), at * CFrame.new(x, 0, -0.03) * CFrame.Angles(0, 0, math.rad(4)), SCRATCH, Enum.Material.Wood)
			x += 0.32
		end
	end
	local anchor = part(m, "PromptAnchor", Vector3.new(2.5, 1.6, 0.05), at * CFrame.new(0, 0, -0.04), SCRATCH)
	anchor.Transparency = 1
	return m
end

local function mouth(doll: Model, frown: boolean)
	for _, child in doll:GetChildren() do
		if child.Name == "Mouth" then
			child:Destroy()
		end
	end
	local head = doll:FindFirstChild("Head") :: BasePart
	local tilt = if frown then 25 else -25
	for _, side in { -1, 1 } do
		local seg = part(doll, "Mouth", Vector3.new(0.18, 0.03, 0.02), head.CFrame * CFrame.new(side * 0.08, -0.1, -0.24) * CFrame.Angles(0, 0, math.rad(side * tilt)), STITCH, Enum.Material.Fabric)
		seg.CanQuery = false
	end
end

-- Sits in a room corner, facing the walls (so you have to lean round to see its face).
-- The doll at `spot` on the floor, facing `toward` (into its corner, away from the room).
function SignModels.doll(parent: Instance, spot: Vector3, toward: Vector3, frown: boolean): Model
	local m = model(parent, "TheDoll")
	local at = CFrame.lookAt(spot, spot + toward) -- facing into the corner
	part(m, "PromptAnchor", Vector3.new(0.9, 0.9, 0.7), at * CFrame.new(0, 0.45, 0), CLOTH, Enum.Material.Fabric)
	local head = part(m, "Head", Vector3.new(0.7, 0.7, 0.7), at * CFrame.new(0, 1.2, -0.05), Color3.fromRGB(210, 196, 176), Enum.Material.Fabric)
	head.Shape = Enum.PartType.Ball
	part(m, "Hair", Vector3.new(0.74, 0.3, 0.6), at * CFrame.new(0, 1.5, 0.08), Color3.fromRGB(60, 34, 24), Enum.Material.Fabric)
	for _, side in { -1, 1 } do
		part(m, "Arm", Vector3.new(0.18, 0.6, 0.18), at * CFrame.new(side * 0.5, 0.5, 0) * CFrame.Angles(0, 0, math.rad(side * 15)), CLOTH, Enum.Material.Fabric)
		part(m, "Leg", Vector3.new(0.2, 0.2, 0.7), at * CFrame.new(side * 0.2, 0.1, -0.45), CLOTH, Enum.Material.Fabric)
		part(m, "Eye", Vector3.new(0.09, 0.09, 0.02), head.CFrame * CFrame.new(side * 0.14, 0.07, -0.34), Color3.fromRGB(10, 10, 10), Enum.Material.Fabric)
	end
	mouth(m, frown)
	return m
end

function SignModels.setFrown(doll: Model)
	mouth(doll, true)
end

return SignModels
