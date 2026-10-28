--!strict
-- The approach to the cabin: a porch on the Parlor's south side (white posts, railings, steps,
-- a little roof and a flickering porch light), a gravel path through a gap in the pines, a
-- wooden sign, and the truck that died at the end of it with its headlights still on.
-- Built in world space south of the Parlor; removed if a room is built in the Parlor's south cell.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local TruckModel = require(Shared:WaitForChild("TruckModel"))

local TRIM = Config.Outside.Trim
local DECK = Color3.fromRGB(86, 70, 56)
local GRAVEL = Color3.fromRGB(62, 60, 56)
local WARM = Color3.fromRGB(255, 196, 128)

local Outside = {}

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

local function porch(parent: Instance, doorX: number, wallZ: number, floorY: number)
	local m = Instance.new("Model")
	m.Name = "Porch"
	local depth, width = 7, 14
	local x0, x1 = doorX - width / 2, doorX + width / 2
	local zFront = wallZ + depth
	part(m, "Deck", Vector3.new(width, 1, depth), CFrame.new(doorX, floorY - 0.5, wallZ + depth / 2), DECK, Enum.Material.WoodPlanks)
	for i = 1, 2 do
		part(m, "Step", Vector3.new(4.6, floorY - (i - 1) * 0.25, 1.2), CFrame.new(doorX, (floorY - (i - 1) * 0.25) / 2, zFront + 0.6 + (i - 1) * 1.2), DECK, Enum.Material.WoodPlanks)
	end
	-- Posts, railings with balusters (a gap for the steps), and a little roof on brackets.
	local postHeight = 10
	for _, x in { x0 + 0.4, x1 - 0.4 } do
		part(m, "Post", Vector3.new(0.7, postHeight, 0.7), CFrame.new(x, floorY + postHeight / 2, zFront - 0.4), TRIM)
		part(m, "Post", Vector3.new(0.7, postHeight, 0.7), CFrame.new(x, floorY + postHeight / 2, wallZ + 0.4), TRIM)
		part(m, "Bracket", Vector3.new(0.4, 1.4, 1.4), CFrame.new(x, floorY + postHeight - 0.8, zFront - 1) * CFrame.Angles(math.rad(45), 0, 0), TRIM).CanCollide = false
	end
	local railSpans = { { x0 + 0.4, doorX - 2.6 }, { doorX + 2.6, x1 - 0.4 } }
	for _, span in railSpans do
		local a, b = span[1], span[2]
		part(m, "Rail", Vector3.new(b - a, 0.3, 0.4), CFrame.new((a + b) / 2, floorY + 3.2, zFront - 0.4), TRIM)
		part(m, "BottomRail", Vector3.new(b - a, 0.2, 0.3), CFrame.new((a + b) / 2, floorY + 0.5, zFront - 0.4), TRIM)
		for x = a + 0.6, b - 0.4, 0.8 do
			part(m, "Baluster", Vector3.new(0.18, 2.7, 0.18), CFrame.new(x, floorY + 1.85, zFront - 0.4), TRIM).CanCollide = false
		end
	end
	for _, x in { x0 + 0.4, x1 - 0.4 } do
		part(m, "SideRail", Vector3.new(0.4, 0.3, depth - 0.8), CFrame.new(x, floorY + 3.2, wallZ + depth / 2), TRIM)
	end
	part(m, "Roof", Vector3.new(width + 1.4, 0.5, depth + 1.2), CFrame.new(doorX, floorY + postHeight + 0.45, wallZ + depth / 2 + 0.2) * CFrame.Angles(math.rad(-6), 0, 0), Config.Outside.Roof, Enum.Material.Slate)
	part(m, "Beam", Vector3.new(width, 0.6, 0.6), CFrame.new(doorX, floorY + postHeight - 0.1, zFront - 0.4), TRIM)

	-- Porch light beside the door; it flickers with the rest (tagged RoomLight).
	local lantern = part(m, "PorchLight", Vector3.new(0.7, 1, 0.7), CFrame.new(doorX + 3.2, floorY + 7, wallZ + 0.5), WARM, Enum.Material.Neon)
	lantern.CanCollide = false
	local glow = Instance.new("PointLight")
	glow.Color = WARM
	glow.Range = 22
	glow.Brightness = 1.2
	glow.Shadows = true
	glow.Parent = lantern
	CollectionService:AddTag(glow, "RoomLight")
	part(m, "Doormat", Vector3.new(4, 0.06, 2.4), CFrame.new(doorX, floorY + 0.03, wallZ + 1.6), Color3.fromRGB(80, 60, 40), Enum.Material.Fabric).CanCollide = false
	m.Parent = parent
end

local function sign(parent: Instance, at: CFrame)
	local m = Instance.new("Model")
	m.Name = "Sign"
	part(m, "Post", Vector3.new(0.5, 6, 0.5), at * CFrame.new(-2.2, 3, 0), Color3.fromRGB(70, 54, 40))
	part(m, "Post", Vector3.new(0.5, 6, 0.5), at * CFrame.new(2.2, 3, 0), Color3.fromRGB(70, 54, 40))
	local board = part(m, "Board", Vector3.new(5.6, 1.6, 0.3), at * CFrame.new(0, 5, 0) * CFrame.Angles(0, 0, math.rad(-3)), Color3.fromRGB(96, 76, 54), Enum.Material.WoodPlanks)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 1
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Fondamento
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(230, 220, 196)
	label.Text = "HOLLOW PINES"
	label.Parent = gui
	gui.Parent = board
	m.Parent = parent
end

-- Build everything outside; returns the folder and the truck-side spot to spawn at.
function Outside.build(): (Folder, CFrame)
	local folder = Instance.new("Folder")
	folder.Name = "Outside"
	local origin = Config.ParlorOrigin
	local doorX = origin.X + Config.FrontDoor.X
	local wallZ = origin.Z + Config.TileSize / 2
	local floorY = origin.Y

	porch(folder, doorX, wallZ, floorY)
	local pathStart = wallZ + 9
	local length = Config.Outside.PathLength
	part(folder, "Path", Vector3.new(5, 0.1, length), CFrame.new(doorX, 0.05, pathStart + length / 2), GRAVEL, Enum.Material.Pebble).CanCollide = false
	sign(folder, CFrame.new(doorX - 5, 0, pathStart + length * 0.45) * CFrame.Angles(0, math.rad(-70), 0))
	-- The truck that brought you: it died at the end of the path, hood up and steaming, headlights still on.
	local truck = TruckModel.build(CFrame.new(doorX + 5, 0, pathStart + length + 2) * CFrame.Angles(0, math.rad(8), 0), {
		body = Color3.fromRGB(112, 58, 40),
		trim = Color3.fromRGB(196, 186, 160),
		broken = true,
		cargo = true,
	})
	truck.Parent = folder

	local spawnAt = CFrame.lookAt(Vector3.new(doorX, 0.6, pathStart + length - 2), Vector3.new(doorX, 0.6, wallZ))
	folder.Parent = workspace
	return folder, spawnAt
end

return Outside
