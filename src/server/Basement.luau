--!strict
-- The basement under the Crawlspace: concrete walls, an old boiler, a cot, chains and a single
-- bulb, with stairs up to a heavy door. The Crawlspace's trapdoor leads down; the door at the top
-- of the stairs leads back up. During an event eliminated players wake up down here, and the
-- door won't open until the event is over (EventRunner locks it). It's built under wherever the
-- Crawlspace was placed, far enough down to be clear of the ground; the stairs and trapdoor take
-- you between the two.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local RoomShapes = require(Shared:WaitForChild("RoomShapes"))

local MapGrid = require(script.Parent.MapGrid)

local CONCRETE = Color3.fromRGB(78, 76, 72)
local BRICK = Color3.fromRGB(88, 66, 56)
local IRON = Color3.fromRGB(44, 44, 48)
local RUST = Color3.fromRGB(96, 56, 36)
local WARM = Color3.fromRGB(255, 196, 128)

local Basement = {}

local folder: Folder? = nil
local builtAt: string? = nil -- MapGrid key of the Crawlspace it's under
local base = Vector3.zero -- basement floor-top centre
local locked = false
local trapdoorPrompt: ProximityPrompt? = nil

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = collide ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function prompt(at: BasePart, action: string, object: string, onUse: (Player) -> ()): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0.3
	p.MaxActivationDistance = 8
	p.RequiresLineOfSight = false
	p.Triggered:Connect(onUse)
	p.Parent = at
	return p
end

local function teleport(player: Player, cf: CFrame)
	local character = player.Character
	if character then
		character:PivotTo(cf)
	end
end

-- Where you stand when you arrive at the bottom (or wake up down here).
function Basement.spawnCFrame(): CFrame
	return CFrame.lookAt(base + Vector3.new(-2, 3, 5), base + Vector3.new(-2, 3, -10))
end

local function trapdoorTop(): CFrame?
	local key = builtAt
	if not key then
		return nil
	end
	for _, cell in MapGrid.all() do
		if cell.id == "crawlspace" and cell.model then
			local hatch = cell.model:FindFirstChild("Trapdoor", true)
			if hatch and hatch:IsA("BasePart") then
				return CFrame.new(hatch.Position + Vector3.new(0, 3, 0)) * CFrame.new(2.5, 0, 0)
			end
		end
	end
	return nil
end

local function build(cellX: number, cellZ: number)
	local f = Instance.new("Folder")
	f.Name = "Basement"
	local cfg = Config.Basement
	local h, height = cfg.HalfSize, cfg.Height
	base = RoomShapes.cellPosition(cellX, cellZ) - Vector3.new(0, cfg.Depth, 0)

	-- Shell: floor, ceiling and four brick walls.
	part(f, "Floor", Vector3.new(h * 2 + 2, 1, h * 2 + 2), CFrame.new(base - Vector3.new(0, 0.5, 0)), CONCRETE, Enum.Material.Concrete)
	part(f, "Ceiling", Vector3.new(h * 2 + 2, 1, h * 2 + 2), CFrame.new(base + Vector3.new(0, height + 0.5, 0)), CONCRETE, Enum.Material.Concrete)
	for i = 0, 3 do
		local turn = CFrame.new(base) * CFrame.Angles(0, i * math.pi / 2, 0)
		part(f, "Wall", Vector3.new(h * 2 + 2, height, 1), turn * CFrame.new(0, height / 2, -h - 0.5), BRICK, Enum.Material.Brick)
	end

	-- Stairs up the east wall to a heavy door in the north wall.
	local steps = 9
	local top = height / 2
	for s = 1, steps do
		local rise = top * s / steps
		part(f, "Step", Vector3.new(4, rise, 2), CFrame.new(base + Vector3.new(h - 2, rise / 2, h - 2 - (s - 0.5) * 2)), CONCRETE, Enum.Material.Concrete)
	end
	part(f, "Landing", Vector3.new(4, top, 3), CFrame.new(base + Vector3.new(h - 2, top / 2, -h + 1.5)), CONCRETE, Enum.Material.Concrete)
	local door = part(f, "Door", Vector3.new(3.4, 6.4, 0.5), CFrame.new(base + Vector3.new(h - 2, top + 3.2, -h + 0.25)), RUST, Enum.Material.Metal)
	part(f, "DoorBar", Vector3.new(3, 0.3, 0.3), door.CFrame * CFrame.new(0, 0, 0.4), IRON, Enum.Material.Metal, false)
	prompt(door, "Open", "Basement door", function(player: Player)
		if locked then
			Remotes.notify(player, "The door won't budge. Not until it's over up there.")
			return
		end
		local up = trapdoorTop()
		if up then
			teleport(player, up)
		end
	end)

	-- An old boiler, pipes, a cot, chains and one bulb.
	local boiler = part(f, "Boiler", Vector3.new(6, 4, 4), CFrame.new(base + Vector3.new(-7, 3, -8)) * CFrame.Angles(0, 0, math.rad(90)), RUST, Enum.Material.Metal)
	boiler.Shape = Enum.PartType.Cylinder
	part(f, "BoilerDoor", Vector3.new(1.4, 1.4, 0.2), CFrame.new(base + Vector3.new(-7, 2, -5.9)), IRON, Enum.Material.Metal, false)
	local glow = part(f, "BoilerGlow", Vector3.new(1, 0.2, 0.1), CFrame.new(base + Vector3.new(-7, 1.5, -5.85)), Color3.fromRGB(255, 90, 40), Enum.Material.Neon, false)
	local ember = Instance.new("PointLight")
	ember.Color = Color3.fromRGB(255, 110, 50)
	ember.Range = 10
	ember.Brightness = 0.6
	ember.Parent = glow
	part(f, "Pipe", Vector3.new(0.7, 0.7, h * 2), CFrame.new(base + Vector3.new(-7, height - 1, 0)), IRON, Enum.Material.Metal, false)
	part(f, "Pipe", Vector3.new(h * 2, 0.5, 0.5), CFrame.new(base + Vector3.new(0, height - 1.6, -h + 1)), IRON, Enum.Material.Metal, false)
	part(f, "Cot", Vector3.new(3, 1.2, 7), CFrame.new(base + Vector3.new(-h + 2, 1, 6)), Color3.fromRGB(110, 104, 90), Enum.Material.Fabric)
	for i, x in { -2, 1, 4 } do
		part(f, "Chain", Vector3.new(0.15, 3 + i, 0.15), CFrame.new(base + Vector3.new(x, height - (3 + i) / 2, 2)), IRON, Enum.Material.Metal, false)
	end
	part(f, "Drain", Vector3.new(1.4, 0.05, 1.4), CFrame.new(base + Vector3.new(0, 0.03, 0)), IRON, Enum.Material.DiamondPlate, false)
	part(f, "Puddle", Vector3.new(5, 0.03, 4), CFrame.new(base + Vector3.new(1, 0.02, -1)), Color3.fromRGB(26, 30, 32), Enum.Material.Glass, false).Transparency = 0.3
	local bulb = part(f, "Bulb", Vector3.new(0.6, 0.6, 0.6), CFrame.new(base + Vector3.new(0, height - 2.5, 3)), WARM, Enum.Material.Neon, false)
	bulb.Shape = Enum.PartType.Ball
	part(f, "BulbCord", Vector3.new(0.08, 2.2, 0.08), CFrame.new(base + Vector3.new(0, height - 1.1, 3)), IRON, Enum.Material.Metal, false)
	local light = Instance.new("PointLight")
	light.Color = WARM
	light.Range = 22
	light.Brightness = 0.7
	light.Shadows = true
	light.Parent = bulb
	CollectionService:AddTag(light, "RoomLight")

	f.Parent = workspace
	folder = f
end

-- Build or move the basement to sit under the Crawlspace, and hook up its trapdoor.
local function refresh()
	local crawl: MapGrid.Cell? = nil
	for _, cell in MapGrid.all() do
		if cell.id == "crawlspace" then
			crawl = cell
		end
	end
	local key = if crawl then MapGrid.key(crawl.x, crawl.z) else nil
	if key == builtAt then
		return
	end
	if folder then
		folder:Destroy()
		folder = nil
	end
	if trapdoorPrompt then
		trapdoorPrompt:Destroy()
		trapdoorPrompt = nil
	end
	builtAt = key
	if not crawl or not crawl.model then
		return
	end
	build(crawl.x, crawl.z)
	local hatch = crawl.model:FindFirstChild("Trapdoor", true)
	if hatch and hatch:IsA("BasePart") then
		trapdoorPrompt = prompt(hatch, "Go down", "Trapdoor", function(player: Player)
			teleport(player, Basement.spawnCFrame())
		end)
	end
end

-- While an event runs, the door at the top of the stairs stays shut.
function Basement.setLocked(value: boolean)
	locked = value
end

function Basement.init()
	MapGrid.Changed:Connect(refresh)
	refresh()
end

return Basement
