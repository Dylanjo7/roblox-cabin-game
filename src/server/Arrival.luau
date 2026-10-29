--!strict
-- The arrival. Players first spawn beside the truck outside and walk up the path to the cabin,
-- where the front door stands open. Once everyone is inside the Parlor, the door slams and locks
-- for good; from then on players spawn inside. Nobody is left waiting on someone who won't come
-- in: once anyone is inside, the rest have Config.Arrival.WaitSeconds, then they're brought in
-- and the door slams anyway (and it always does as a run starts). The porch, path and truck
-- stay outside until a room is built in the Parlor's south cell, which takes their place.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local RoomShapes = require(Shared:WaitForChild("RoomShapes"))

local Forest = require(script.Parent.Forest)
local MapGrid = require(script.Parent.MapGrid)
local Outside = require(script.Parent.Outside)
local StateSync = require(script.Parent.StateSync)

local DOOR = Color3.fromRGB(64, 44, 30) -- old, dark, weathered oak
local DOOR_PANEL = Color3.fromRGB(78, 54, 36)
local IRON = Color3.fromRGB(34, 32, 30)
local BRASS = Color3.fromRGB(150, 120, 60)

local Arrival = {}

local closed = false
local door: Model
local hinge = CFrame.new()
local angle = Instance.new("NumberValue")
local outside: Folder? = nil
local arrivalSpawn: SpawnLocation? = nil
local spawnAt = CFrame.new()

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Wood
	p.Anchored = true
	p.Parent = parent
	return p
end

-- The front door, hung in the Parlor's south wall. Its pivot is the hinge at floor level; it
-- swings in towards the table.
local function buildDoor()
	local fd = Config.FrontDoor
	local origin = Config.ParlorOrigin
	local wallZ = origin.Z + Config.TileSize / 2 - Config.Room.WallThickness / 2
	local x0 = origin.X + fd.X - fd.Width / 2
	hinge = CFrame.new(x0, origin.Y, wallZ)

	door = Instance.new("Model")
	door.Name = "FrontDoor"
	local pivot = part(door, "Hinge", Vector3.new(0.2, 0.2, 0.2), hinge, BRASS, Enum.Material.Metal)
	pivot.Transparency = 1
	pivot.CanCollide = false
	door.PrimaryPart = pivot
	local panelCf = hinge * CFrame.new(fd.Width / 2, fd.Height / 2, 0)
	local w, h = fd.Width - 0.1, fd.Height - 0.1
	part(door, "Door", Vector3.new(w, h, 0.4), panelCf, DOOR, Enum.Material.WoodPlanks)
	local function deco(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
		local p = part(door, name, size, cf, color, material)
		p.CanCollide = false
		return p
	end
	-- Both faces: a small four-pane window up top, then four raised panels in a stile frame.
	for _, side in { -1, 1 } do
		local face = panelCf * CFrame.new(0, 0, side * 0.21)
		deco("Stile", Vector3.new(0.35, h, 0.06), face * CFrame.new(-w / 2 + 0.18, 0, 0), DOOR_PANEL)
		deco("Stile", Vector3.new(0.35, h, 0.06), face * CFrame.new(w / 2 - 0.18, 0, 0), DOOR_PANEL)
		deco("Rail", Vector3.new(w, 0.35, 0.06), face * CFrame.new(0, -h / 2 + 0.3, 0), DOOR_PANEL)
		deco("Rail", Vector3.new(w, 0.3, 0.06), face * CFrame.new(0, 0.6, 0), DOOR_PANEL)
		deco("Rail", Vector3.new(w, 0.3, 0.06), face * CFrame.new(0, h / 2 - 2.2, 0), DOOR_PANEL)
		deco("Rail", Vector3.new(w, 0.3, 0.06), face * CFrame.new(0, h / 2 - 0.18, 0), DOOR_PANEL)
		for _, x in { -0.8, 0.8 } do
			for _, y in { -1.9, -0.25 } do
				deco("RaisedPanel", Vector3.new(1.2, 1.3, 0.08), face * CFrame.new(x, y, side * 0.02), DOOR_PANEL, Enum.Material.Wood)
			end
		end
	end
	-- The window: grimy glass with a cross of glazing bars, set through the door.
	local glass = deco("Window", Vector3.new(w - 1, 1.5, 0.1), panelCf * CFrame.new(0, h / 2 - 1.2, 0), Color3.fromRGB(60, 70, 64), Enum.Material.Glass)
	glass.Transparency = 0.45
	for _, z in { -0.22, 0.22 } do
		deco("GlazingBar", Vector3.new(0.1, 1.5, 0.06), panelCf * CFrame.new(0, h / 2 - 1.2, z), DOOR_PANEL)
		deco("GlazingBar", Vector3.new(w - 1, 0.1, 0.06), panelCf * CFrame.new(0, h / 2 - 1.2, z), DOOR_PANEL)
	end
	-- Iron strap hinges on the hinge side, outside face, and studs along them.
	for _, y in { -h / 2 + 1.1, h / 2 - 1.1 } do
		deco("StrapHinge", Vector3.new(w * 0.55, 0.22, 0.05), panelCf * CFrame.new(-w / 2 + w * 0.275, y, 0.27), IRON, Enum.Material.Metal)
		for i = 0, 2 do
			local stud = deco("Stud", Vector3.new(0.1, 0.1, 0.1), panelCf * CFrame.new(-w / 2 + 0.3 + i * 0.7, y, 0.3), IRON, Enum.Material.Metal)
			stud.Shape = Enum.PartType.Ball
		end
	end
	-- Handles both sides, an iron ring knocker outside, a keyhole plate.
	for _, side in { -1, 1 } do
		local knob = deco("Knob", Vector3.new(0.32, 0.32, 0.32), panelCf * CFrame.new(w / 2 - 0.45, -0.3, side * 0.36), BRASS, Enum.Material.Metal)
		knob.Shape = Enum.PartType.Ball
		deco("KeyPlate", Vector3.new(0.22, 0.5, 0.04), panelCf * CFrame.new(w / 2 - 0.45, -0.75, side * 0.23), BRASS, Enum.Material.Metal)
	end
	local ring = deco("Knocker", Vector3.new(0.08, 0.6, 0.6), panelCf * CFrame.new(0, 1.2, 0.3) * CFrame.Angles(0, math.rad(90), 0), IRON, Enum.Material.Metal)
	ring.Shape = Enum.PartType.Cylinder
	deco("KnockerMount", Vector3.new(0.25, 0.25, 0.1), panelCf * CFrame.new(0, 1.55, 0.27), IRON, Enum.Material.Metal)
	door.WorldPivot = hinge
	door.Parent = workspace
	angle.Changed:Connect(function(a: number)
		door:PivotTo(hinge * CFrame.Angles(0, math.rad(a), 0))
	end)
end

local function playSound(name: string, at: BasePart, volume: number)
	local sound = Instance.new("Sound")
	sound.SoundId = Config.Sounds[name] or ""
	sound.Volume = volume
	sound.RollOffMaxDistance = 200
	sound.Parent = at
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

-- Porch, path and truck exist while the Parlor's south cell is empty; the path's cells stay
-- clear of trees while they do.
local function refreshOutside()
	local south = MapGrid.get(0, 1)
	if south and outside then
		outside:Destroy()
		outside = nil
		Forest.setClearing({})
	elseif not south and not outside then
		local folder, at = Outside.build()
		outside = folder
		spawnAt = at
		Forest.setClearing({ [MapGrid.key(0, 1)] = true, [MapGrid.key(0, 2)] = true })
	end
end

local function insideParlor(position: Vector3): boolean
	local offset = position - Config.ParlorOrigin
	local inner = Config.TileSize / 2 - Config.Room.WallThickness - 0.5
	return math.abs(offset.X) < inner and math.abs(offset.Z) < inner
end

local function slam()
	closed = true
	local info = TweenInfo.new(Config.FrontDoor.SlamSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(angle, info, { Value = 0 }):Play()
	local panel = door:FindFirstChild("Door") :: BasePart
	task.delay(Config.FrontDoor.SlamSeconds, function()
		playSound("step", panel, 1)
		playSound("creak", panel, 0.6)
	end)
	-- From now on, everyone (re)spawns inside.
	local parlorSpawn = workspace:FindFirstChild("ParlorSpawn", true)
	if parlorSpawn and parlorSpawn:IsA("SpawnLocation") then
		parlorSpawn.Enabled = true
	end
	if arrivalSpawn then
		arrivalSpawn:Destroy()
		arrivalSpawn = nil
	end
	StateSync.broadcast()
end

function Arrival.isDoorClosed(): boolean
	return closed
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Bring anyone still outside in (a few steps inside the door, clear of its swing) and slam it.
function Arrival.forceClose()
	if closed then
		return
	end
	local inside = RoomShapes.frontDoorInside() * CFrame.new(0, 3, -5)
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		local character = player.Character
		if root and character and not insideParlor(root.Position) then
			character:PivotTo(inside)
			Remotes.notify(player, "Something hurries you up the path and through the door.")
		end
	end
	slam()
end

function Arrival.init()
	buildDoor()
	refreshOutside()
	MapGrid.Changed:Connect(refreshOutside)

	-- Start with the door open and players spawning by the truck.
	angle.Value = Config.FrontDoor.OpenDegrees
	local parlorSpawn = workspace:FindFirstChild("ParlorSpawn", true)
	if parlorSpawn and parlorSpawn:IsA("SpawnLocation") then
		parlorSpawn.Enabled = false
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "ArrivalSpawn"
	spawn.Size = Vector3.new(5, 0.4, 5)
	spawn.CFrame = spawnAt * CFrame.new(0, -0.4, 0)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = workspace
	arrivalSpawn = spawn

	-- The door slams once everyone in the server has come inside, or a while after the first
	-- one did.
	task.spawn(function()
		local firstInAt: number? = nil
		while not closed do
			task.wait(0.3)
			local players = Players:GetPlayers()
			local everyoneIn = #players > 0
			local anyoneIn = false
			for _, player in players do
				local root = rootOf(player)
				if root and insideParlor(root.Position) then
					anyoneIn = true
				else
					everyoneIn = false
				end
			end
			if everyoneIn then
				slam()
			elseif anyoneIn then
				firstInAt = firstInAt or os.clock()
				if os.clock() - firstInAt > Config.Arrival.WaitSeconds then
					Arrival.forceClose()
				end
			end
		end
	end)

	StateSync.register("arrival", function()
		return { doorClosed = closed }
	end)
end

return Arrival
