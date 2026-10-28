--!strict
-- The basement under the Crawlspace: concrete walls, an old boiler, a cot, chains and a single
-- bulb, with stairs up to a heavy iron door. The Crawlspace's trapdoor leads down. During an
-- event the door is slammed shut and barred, with a red lamp over it: eliminated players wake up
-- down here and are stuck. When the event is over the bar slides back and the door creaks open
-- onto a stairwell; at the top of it you climb out of the Crawlspace's trapdoor and walk back
-- to the table (EventRunner locks and unlocks it). It's built under wherever the
-- Crawlspace was placed, far enough down to be clear of the ground; the stairs and trapdoor take
-- you between the two.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

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

-- The door at the top of the stairs (rebuilt with the basement).
type Door = { model: Model, hinge: CFrame, angle: NumberValue, bar: BasePart, barShut: CFrame, lamp: BasePart, lampLight: PointLight }
local door: Door? = nil
local DOOR_OPEN_DEGREES = 90
local LAMP_LOCKED = Color3.fromRGB(200, 30, 20)
local LAMP_OPEN = Color3.fromRGB(255, 196, 128)

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

local function sound(name: string, at: BasePart, volume: number, speed: number?)
	local sfx = Instance.new("Sound")
	sfx.SoundId = Config.Sounds[name] or ""
	sfx.Volume = volume
	sfx.PlaybackSpeed = speed or 1
	sfx.RollOffMaxDistance = 80
	sfx.Parent = at
	sfx.Ended:Once(function()
		sfx:Destroy()
	end)
	sfx:Play()
end

local exitDebounce: { [Player]: boolean } = {}
local buildDoorway: (f: Folder, h: number, height: number, top: number) -> ()

-- The north wall with an opening at the top of the stairs, the iron door hung in it, its bar
-- and lamp, and the stairwell behind it that takes you up and out of the trapdoor.
buildDoorway = function(f: Folder, h: number, height: number, top: number)
	local doorWidth, doorHeight = 3.6, 6.6
	local cx = h - 2 -- above the landing
	local x0, x1 = cx - doorWidth / 2, cx + doorWidth / 2
	local y0, y1 = top, top + doorHeight
	local z = -h - 0.5
	local function wall(name: string, xa: number, xb: number, ya: number, yb: number)
		part(f, name, Vector3.new(xb - xa, yb - ya, 1), CFrame.new(base + Vector3.new((xa + xb) / 2, (ya + yb) / 2, z)), BRICK, Enum.Material.Brick)
	end
	wall("Wall", -h - 1, x0, 0, height)
	wall("Wall", x1, h + 1, 0, height)
	wall("Wall", x0, x1, 0, y0)
	wall("Wall", x0, x1, y1, height)
	part(f, "DoorFrame", Vector3.new(doorWidth + 0.6, 0.4, 1.2), CFrame.new(base + Vector3.new(cx, y1 + 0.2, z)), IRON, Enum.Material.Metal, false)

	-- The door: riveted iron, hinged on its left edge, swinging out into the stairwell.
	local model = Instance.new("Model")
	model.Name = "BasementDoor"
	local hinge = CFrame.new(base + Vector3.new(x0, y0, z))
	local panelCf = hinge * CFrame.new(doorWidth / 2, doorHeight / 2, 0)
	local panel = part(model, "Panel", Vector3.new(doorWidth - 0.1, doorHeight - 0.1, 0.4), panelCf, RUST, Enum.Material.CorrodedMetal)
	for _, y in { -2.2, 0, 2.2 } do
		part(model, "Strap", Vector3.new(doorWidth - 0.3, 0.3, 0.5), panelCf * CFrame.new(0, y, 0), IRON, Enum.Material.Metal, false)
		for _, x in { -1.4, -0.5, 0.5, 1.4 } do
			local rivet = part(model, "Rivet", Vector3.new(0.14, 0.14, 0.14), panelCf * CFrame.new(x, y, 0.28), IRON, Enum.Material.Metal, false)
			rivet.Shape = Enum.PartType.Ball
		end
	end
	part(model, "Handle", Vector3.new(0.2, 0.9, 0.2), panelCf * CFrame.new(doorWidth / 2 - 0.5, 0, 0.4), IRON, Enum.Material.Metal, false)
	local pivot = part(model, "Hinge", Vector3.new(0.2, 0.2, 0.2), hinge, IRON, Enum.Material.Metal, false)
	pivot.Transparency = 1
	model.PrimaryPart = pivot
	model.WorldPivot = hinge
	model.Parent = f
	local angle = Instance.new("NumberValue")
	angle.Changed:Connect(function(a: number)
		model:PivotTo(hinge * CFrame.Angles(0, math.rad(a), 0))
	end)

	-- The bar across it on the basement side, in iron brackets; it slides into the wall to open.
	local barShut = CFrame.new(base + Vector3.new(cx, y0 + doorHeight / 2, z + 0.75))
	local bar = part(f, "Bar", Vector3.new(doorWidth + 1.2, 0.35, 0.35), barShut, IRON, Enum.Material.Metal)
	for _, x in { x0 - 0.3, x1 + 0.3 } do
		part(f, "BarBracket", Vector3.new(0.3, 0.7, 0.5), CFrame.new(base + Vector3.new(x, y0 + doorHeight / 2, z + 0.75)), IRON, Enum.Material.Metal, false)
	end
	local lamp = part(f, "DoorLamp", Vector3.new(0.5, 0.5, 0.3), CFrame.new(base + Vector3.new(cx, y1 + 0.8, z + 0.6)), LAMP_OPEN, Enum.Material.Neon, false)
	local lampLight = Instance.new("PointLight")
	lampLight.Range = 12
	lampLight.Brightness = 0.9
	lampLight.Color = LAMP_OPEN
	lampLight.Parent = lamp
	door = { model = model, hinge = hinge, angle = angle, bar = bar, barShut = barShut, lamp = lamp, lampLight = lampLight }

	-- Rattling a barred door does nothing (but tells you why).
	prompt(panel, "Open", "Basement door", function(player: Player)
		if locked then
			sound("knock", panel, 0.6, 0.6)
			Remotes.notify(player, "The door is barred from the other side. Not until it's over up there.")
		end
	end)

	-- The stairwell behind it: a landing, steps up into the dark, and a faint light at the top.
	local zEnd = z - 0.5 - 14
	local inner = doorWidth + 0.8
	part(f, "StairLanding", Vector3.new(inner, 1, 3), CFrame.new(base + Vector3.new(cx, y0 - 0.5, z - 2)), CONCRETE, Enum.Material.Concrete)
	for st = 1, 5 do
		part(f, "StairStep", Vector3.new(inner, st, 2), CFrame.new(base + Vector3.new(cx, y0 + st / 2 - 1 + 0.5, z - 3.5 - (st - 0.5) * 2)), CONCRETE, Enum.Material.Concrete)
	end
	part(f, "StairTop", Vector3.new(inner, 6, 3), CFrame.new(base + Vector3.new(cx, y0 + 2.5, zEnd + 1.5)), CONCRETE, Enum.Material.Concrete)
	for _, side in { -1, 1 } do
		part(f, "StairWall", Vector3.new(1, 18, z - zEnd), CFrame.new(base + Vector3.new(cx + side * (inner / 2 + 0.5), y0 + 8, (z + zEnd) / 2)), BRICK, Enum.Material.Brick)
	end
	part(f, "StairCeiling", Vector3.new(inner + 2, 1, z - zEnd), CFrame.new(base + Vector3.new(cx, y0 + 17, (z + zEnd) / 2)), CONCRETE, Enum.Material.Concrete)
	part(f, "StairEnd", Vector3.new(inner + 2, 18, 1), CFrame.new(base + Vector3.new(cx, y0 + 8, zEnd - 0.5)), BRICK, Enum.Material.Brick)
	local slit = part(f, "LightFromAbove", Vector3.new(2.4, 0.2, 1.4), CFrame.new(base + Vector3.new(cx, y0 + 16.4, zEnd + 1.5)), Color3.fromRGB(200, 190, 170), Enum.Material.Neon, false)
	local above = Instance.new("PointLight")
	above.Range = 16
	above.Brightness = 0.5
	above.Color = Color3.fromRGB(200, 196, 186)
	above.Parent = slit
	CollectionService:AddTag(above, "RoomLight")

	-- At the top of the steps you climb out through the Crawlspace's trapdoor.
	local exit = part(f, "StairExit", Vector3.new(inner, 7, 2), CFrame.new(base + Vector3.new(cx, y0 + 9, zEnd + 1.5)), Color3.new(), Enum.Material.SmoothPlastic, false)
	exit.Transparency = 1
	exit.Touched:Connect(function(hit: BasePart)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player or exitDebounce[player] then
			return
		end
		local up = trapdoorTop()
		if up then
			exitDebounce[player] = true
			teleport(player, up)
			Remotes.notify(player, "You climb out through the trapdoor. Back to the table.")
			task.delay(2, function()
				exitDebounce[player] = nil
			end)
		end
	end)

	-- Shut or open to match the current lock, without animating.
	if locked then
		angle.Value = 0
		lamp.Color = LAMP_LOCKED
		lampLight.Color = LAMP_LOCKED
	else
		angle.Value = DOOR_OPEN_DEGREES
		bar.CFrame = barShut * CFrame.new(doorWidth + 0.8, 0, 0)
	end
	model:PivotTo(hinge * CFrame.Angles(0, math.rad(angle.Value), 0))
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
	for i = 1, 3 do
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
	buildDoorway(f, h, height, top)

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
		door = nil
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

-- While an event runs the door at the top of the stairs is slammed shut and barred; when it's
-- over the bar slides back and the door creaks open.
function Basement.setLocked(value: boolean)
	if locked == value then
		return
	end
	locked = value
	local d = door
	if not d then
		return
	end
	local panel = d.model:FindFirstChild("Panel") :: BasePart
	local barOpen = d.barShut * CFrame.new(d.bar.Size.X - 0.4, 0, 0)
	if value then
		TweenService:Create(d.angle, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = 0 }):Play()
		task.delay(0.35, function()
			sound("step", panel, 0.9, 0.7) -- the slam
			TweenService:Create(d.bar, TweenInfo.new(0.4, Enum.EasingStyle.Back), { CFrame = d.barShut }):Play()
		end)
		d.lamp.Color = LAMP_LOCKED
		d.lampLight.Color = LAMP_LOCKED
	else
		TweenService:Create(d.bar, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { CFrame = barOpen }):Play()
		task.delay(0.8, function()
			if locked then
				return
			end
			sound("creak", panel, 0.9, 0.8)
			TweenService:Create(d.angle, TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Value = DOOR_OPEN_DEGREES }):Play()
		end)
		d.lamp.Color = LAMP_OPEN
		d.lampLight.Color = LAMP_OPEN
	end
end

function Basement.init()
	MapGrid.Changed:Connect(refresh)
	refresh()
end

return Basement
