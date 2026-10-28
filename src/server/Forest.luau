--!strict
-- The pines outside the cabin. Every empty map cell near the cabin (inside or outside the build
-- bounds) holds a few tall, dark, stylised pines, so every window looks out into close-packed
-- trees. Trees in a cell are cleared the moment a room is built there. Each cell's trees are
-- seeded from its coordinates, so the forest looks the same every time it's rebuilt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local RoomShapes = require(Shared:WaitForChild("RoomShapes"))

local MapGrid = require(script.Parent.MapGrid)

local BARK = Color3.fromRGB(40, 30, 24)
local NEEDLES = Color3.fromRGB(20, 32, 24)

local Forest = {}

local folder: Folder
local trees: { [string]: Model } = {}
local clearing: { [string]: boolean } = {} -- cells kept free of trees (the path to the porch)

local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A pine: a bare trunk with five tiers of needles that shrink and twist towards the top.
-- maxHalfWidth keeps its needles inside its own cell, clear of the cabin's walls.
local function pine(parent: Instance, base: Vector3, height: number, rng: Random, maxHalfWidth: number)
	local tree = Instance.new("Model")
	tree.Name = "Pine"
	local trunk = part(tree, Vector3.new(height, 1.4, 1.4), CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), BARK, Enum.Material.Wood)
	trunk.Shape = Enum.PartType.Cylinder
	local tint = rng:NextNumber(-0.02, 0.02)
	local color = Color3.new(NEEDLES.R + tint, NEEDLES.G + tint, NEEDLES.B + tint)
	for i = 0, 4 do
		local t = i / 5
		local width = math.min(height * 0.42 * (1 - t * 0.8), maxHalfWidth * 2)
		local y = height * (0.32 + t * 0.6)
		local tier = part(
			tree,
			Vector3.new(width, height * 0.14, width),
			CFrame.new(base + Vector3.new(0, y, 0)) * CFrame.Angles(0, math.rad(i * 23 + rng:NextNumber(0, 40)), 0),
			color,
			Enum.Material.Grass
		)
		tier.CanCollide = false
		tier.CastShadow = true
	end
	tree.Parent = parent
end

local function plant(x: number, z: number): Model
	local cell = Instance.new("Model")
	cell.Name = `Trees ({x},{z})`
	local rng = Random.new(x * 7919 + z * 104729 + 17)
	local centre = RoomShapes.cellPosition(x, z)
	local half = Config.TileSize / 2
	local reach = half - 8
	for _ = 1, Config.Forest.TreesPerCell do
		local dx, dz = rng:NextNumber(-reach, reach), rng:NextNumber(-reach, reach)
		-- How far its needles can spread before they'd cross into the next cell (where a room
		-- may stand), less a little for the room's siding and eaves.
		local room = half - math.max(math.abs(dx), math.abs(dz)) - 2
		pine(cell, centre + Vector3.new(dx, 0, dz), rng:NextNumber(Config.Forest.MinHeight, Config.Forest.MaxHeight), rng, room)
	end
	cell.Parent = folder
	return cell
end

-- Bring the forest in line with the map: trees in empty cells near the cabin, none in built ones.
function Forest.update()
	local wanted: { [string]: { number } } = {}
	local radius = Config.Forest.Radius
	for _, cell in MapGrid.all() do
		for dx = -radius, radius do
			for dz = -radius, radius do
				local x, z = cell.x + dx, cell.z + dz
				if not MapGrid.get(x, z) and not clearing[MapGrid.key(x, z)] then
					wanted[MapGrid.key(x, z)] = { x, z }
				end
			end
		end
	end
	for k, model in trees do
		if not wanted[k] then
			model:Destroy()
			trees[k] = nil
		end
	end
	for k, xz in wanted do
		if not trees[k] then
			trees[k] = plant(xz[1], xz[2])
		end
	end
end

-- Keep these cells (MapGrid keys) free of trees.
function Forest.setClearing(cells: { [string]: boolean })
	clearing = cells
	Forest.update()
end

function Forest.init()
	folder = Instance.new("Folder")
	folder.Name = "Forest"
	folder.Parent = workspace

	-- Dark forest floor instead of the bright default baseplate.
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Color = Config.Forest.Ground
		baseplate.Material = Enum.Material.Ground
		for _, child in baseplate:GetChildren() do
			if child:IsA("Texture") or child:IsA("Decal") then
				child:Destroy()
			end
		end
	end

	MapGrid.Changed:Connect(Forest.update)
	Forest.update()
end

return Forest
