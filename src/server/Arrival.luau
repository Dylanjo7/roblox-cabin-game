--!strict
-- The arrival. Players first spawn beside the truck outside and walk up the path to the cabin,
-- where the front door stands open. Once everyone is inside the Parlor, the door slams and locks
-- for good; from then on players spawn inside. The porch, path and truck stay outside until a
-- room is built in the Parlor's south cell, which takes their place.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local Forest = require(script.Parent.Forest)
local MapGrid = require(script.Parent.MapGrid)
local Outside = require(script.Parent.Outside)
local StateSync = require(script.Parent.StateSync)

local DOOR = Color3.fromRGB(196, 186, 160)
local DOOR_PANEL = Color3.fromRGB(176, 166, 140)
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
	part(door, "Door", Vector3.new(fd.Width - 0.1, fd.Height - 0.1, 0.4), panelCf, DOOR)
	for _, y in { 1.9, -1.9 } do
		for _, side in { -1, 1 } do
			local panel = part(door, "Panel", Vector3.new(fd.Width - 1, fd.Height / 2 - 1.2, 0.1), panelCf * CFrame.new(0, y, side * 0.24), DOOR_PANEL)
			panel.CanCollide = false
		end
	end
	for _, side in { -1, 1 } do
		local knob = part(door, "Knob", Vector3.new(0.35, 0.35, 0.35), panelCf * CFrame.new(fd.Width / 2 - 0.5, -0.2, side * 0.35), BRASS, Enum.Material.Metal)
		knob.Shape = Enum.PartType.Ball
		knob.CanCollide = false
	end
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

	-- The door slams once everyone in the server has come inside.
	task.spawn(function()
		while not closed do
			task.wait(0.3)
			local players = Players:GetPlayers()
			local everyoneIn = #players > 0
			for _, player in players do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if not root or not root:IsA("BasePart") or not insideParlor(root.Position) then
					everyoneIn = false
				end
			end
			if everyoneIn then
				slam()
			end
		end
	end)

	StateSync.register("arrival", function()
		return { doorClosed = closed }
	end)
end

return Arrival
