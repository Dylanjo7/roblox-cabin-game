--!strict
-- The old man by the stove in the ranger station: the driver from the trip up. He sits in his
-- rocking chair in a red cap and a flannel shirt with a tin mug, and his head turns to follow
-- you (lobby client DriverView turns his HeadGroup). Talk to him and he says the next of
-- Story.Driver (sent to you alone with "DriverSays"; the client shows it and plays his voice
-- line, Config.Voice driver_N, if it's been recorded).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Story = require(Shared:WaitForChild("Story"))

local OldDriver = {}

local SKIN = Color3.fromRGB(196, 150, 122)
local SKIN_DARK = Color3.fromRGB(170, 124, 100)
local GREY = Color3.fromRGB(176, 174, 166)
local FLANNEL = Color3.fromRGB(128, 34, 28)
local FLANNEL_DARK = Color3.fromRGB(56, 18, 16)
local DENIM = Color3.fromRGB(62, 74, 96)
local BOOT = Color3.fromRGB(70, 48, 32)
local CAP = Color3.fromRGB(150, 30, 26)
local WOOD = Color3.fromRGB(96, 66, 42)
local TIN = Color3.fromRGB(150, 150, 146)

local TALK_COOLDOWN = 1.5

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Build him in his chair. `at` is the floor under the middle of the chair; he faces its -Z.
function OldDriver.build(parent: Instance, at: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "OldDriver"

	-- The rocking chair.
	for _, x in { -0.95, 0.95 } do
		part(model, "Rocker", Vector3.new(0.18, 0.22, 3.4), at * CFrame.new(x, 0.12, 0.1) * CFrame.Angles(math.rad(-3), 0, 0), WOOD, Enum.Material.Wood)
		for _, z in { -0.85, 0.85 } do
			part(model, "Leg", Vector3.new(0.2, 1.6, 0.2), at * CFrame.new(x, 1.0, z), WOOD, Enum.Material.Wood)
		end
		part(model, "Upright", Vector3.new(0.22, 3.6, 0.22), at * CFrame.new(x, 3.4, 1.15) * CFrame.Angles(math.rad(10), 0, 0), WOOD, Enum.Material.Wood)
		part(model, "Armrest", Vector3.new(0.26, 0.18, 2.1), at * CFrame.new(x * 1.08, 2.85, -0.05), WOOD, Enum.Material.Wood)
		part(model, "ArmPost", Vector3.new(0.16, 1.0, 0.16), at * CFrame.new(x * 1.08, 2.3, -0.9), WOOD, Enum.Material.Wood)
	end
	local seat = part(model, "Seat", Vector3.new(2.2, 0.25, 2.0), at * CFrame.new(0, 1.82, 0), WOOD, Enum.Material.Wood)
	seat.CanCollide = true
	for i, y in { 2.7, 3.5, 4.3, 5.05 } do
		part(model, if i == 4 then "TopRail" else "Slat", Vector3.new(2.0, if i == 4 then 0.32 else 0.22, 0.12), at * CFrame.new(0, y, 1.0 + (y - 1.8) * math.tan(math.rad(10))) * CFrame.Angles(math.rad(10), 0, 0), WOOD, Enum.Material.Wood)
	end

	-- Him, sitting back in it.
	for _, x in { -0.42, 0.42 } do
		part(model, "Thigh", Vector3.new(0.72, 0.72, 1.9), at * CFrame.new(x, 2.3, -0.55), DENIM, Enum.Material.Fabric)
		part(model, "Shin", Vector3.new(0.66, 1.75, 0.66), at * CFrame.new(x, 1.25, -1.35), DENIM, Enum.Material.Fabric)
		part(model, "Boot", Vector3.new(0.74, 0.5, 1.15), at * CFrame.new(x, 0.25, -1.55), BOOT, Enum.Material.Leather)
	end
	local lean = at * CFrame.new(0, 2.4, 0.35) * CFrame.Angles(math.rad(8), 0, 0)
	local torso = part(model, "Torso", Vector3.new(1.9, 2.1, 1.05), lean * CFrame.new(0, 1.05, 0), FLANNEL, Enum.Material.Fabric)
	-- Plaid: dark bands across and down the shirt, and a paunch.
	for _, y in { 0.35, 1.45 } do
		part(model, "Plaid", Vector3.new(1.93, 0.14, 1.08), lean * CFrame.new(0, y, 0), FLANNEL_DARK, Enum.Material.Fabric)
	end
	for _, x in { -0.5, 0.5 } do
		part(model, "Plaid", Vector3.new(0.14, 2.12, 1.08), lean * CFrame.new(x, 1.05, 0), FLANNEL_DARK, Enum.Material.Fabric)
	end
	part(model, "Belly", Vector3.new(1.5, 1.0, 0.4), lean * CFrame.new(0, 0.6, -0.6), FLANNEL, Enum.Material.Fabric)
	part(model, "Belt", Vector3.new(1.95, 0.22, 1.12), lean * CFrame.new(0, 0.05, 0), BOOT, Enum.Material.Leather)
	-- Arms: elbows down on the armrests, the mug in his right hand.
	for _, x in { -1, 1 } do
		part(model, "UpperArm", Vector3.new(0.58, 1.4, 0.6), lean * CFrame.new(x * 1.18, 1.35, 0.05), FLANNEL, Enum.Material.Fabric)
		part(model, "Forearm", Vector3.new(0.52, 0.52, 1.5), at * CFrame.new(x * 1.12, 3.2, -0.35), FLANNEL, Enum.Material.Fabric)
		part(model, "Hand", Vector3.new(0.46, 0.44, 0.5), at * CFrame.new(x * 1.12, 3.2, -1.25), SKIN, Enum.Material.SmoothPlastic)
	end
	local mug = part(model, "Mug", Vector3.new(0.6, 0.5, 0.5), at * CFrame.new(1.12, 3.62, -1.3) * CFrame.Angles(0, 0, math.rad(90)), TIN, Enum.Material.Metal)
	mug.Shape = Enum.PartType.Cylinder
	part(model, "MugHandle", Vector3.new(0.1, 0.36, 0.22), at * CFrame.new(1.42, 3.62, -1.3), TIN, Enum.Material.Metal)
	part(model, "Neck", Vector3.new(0.6, 0.4, 0.6), lean * CFrame.new(0, 2.25, 0), SKIN, Enum.Material.SmoothPlastic)

	-- His head, as its own model so the client can turn it (its pivot is at the neck).
	local headGroup = Instance.new("Model")
	headGroup.Name = "HeadGroup"
	local neck = lean * CFrame.new(0, 2.4, 0)
	local head = neck * CFrame.new(0, 0.62, -0.02)
	local skull = part(headGroup, "Head", Vector3.new(1.15, 1.25, 1.1), head, SKIN, Enum.Material.SmoothPlastic)
	part(headGroup, "Beard", Vector3.new(1.2, 0.8, 0.5), head * CFrame.new(0, -0.48, -0.42), GREY, Enum.Material.Fabric)
	part(headGroup, "Moustache", Vector3.new(0.72, 0.16, 0.14), head * CFrame.new(0, -0.08, -0.6), GREY, Enum.Material.Fabric)
	part(headGroup, "Nose", Vector3.new(0.22, 0.32, 0.22), head * CFrame.new(0, 0.06, -0.62), SKIN_DARK, Enum.Material.SmoothPlastic)
	for _, x in { -0.25, 0.25 } do
		part(headGroup, "Eye", Vector3.new(0.14, 0.1, 0.05), head * CFrame.new(x, 0.2, -0.56), Color3.fromRGB(26, 22, 20), Enum.Material.SmoothPlastic)
		part(headGroup, "Brow", Vector3.new(0.32, 0.09, 0.07), head * CFrame.new(x, 0.34, -0.57) * CFrame.Angles(0, 0, math.rad(x * -24)), GREY, Enum.Material.Fabric)
		part(headGroup, "Ear", Vector3.new(0.12, 0.32, 0.22), head * CFrame.new(x * 2.36, 0.05, 0.02), SKIN_DARK, Enum.Material.SmoothPlastic)
	end
	part(headGroup, "Hair", Vector3.new(1.2, 0.42, 0.32), head * CFrame.new(0, 0.18, 0.48), GREY, Enum.Material.Fabric)
	part(headGroup, "Cap", Vector3.new(1.22, 0.46, 1.16), head * CFrame.new(0, 0.74, 0.02), CAP, Enum.Material.Fabric)
	part(headGroup, "Brim", Vector3.new(1.02, 0.08, 0.62), head * CFrame.new(0, 0.56, -0.8) * CFrame.Angles(math.rad(-8), 0, 0), CAP, Enum.Material.Fabric)
	part(headGroup, "CapPatch", Vector3.new(0.44, 0.24, 0.03), head * CFrame.new(0, 0.78, -0.58), Color3.fromRGB(226, 214, 180), Enum.Material.SmoothPlastic)
	headGroup.PrimaryPart = skull
	headGroup.WorldPivot = neck
	headGroup.Parent = model

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Talk"
	prompt.ActionText = "Talk"
	prompt.ObjectText = "Old driver"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = torso

	model.Parent = parent
	return model
end

-- Talking to him: each player hears his lines in order, then round again from
-- Story.DriverLoopFrom.
function OldDriver.init(model: Model)
	local says = Instance.new("RemoteEvent")
	says.Name = "DriverSays"
	says.Parent = ReplicatedStorage

	local nextLine: { [Player]: number } = {}
	local lastTalk: { [Player]: number } = {}
	local torso = model:FindFirstChild("Torso")
	local prompt = torso and torso:FindFirstChild("Talk")
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return
	end
	prompt.Triggered:Connect(function(player: Player)
		local now = os.clock()
		if now - (lastTalk[player] or -math.huge) < TALK_COOLDOWN then
			return
		end
		lastTalk[player] = now
		local index = nextLine[player] or 1
		local lines = Story.Driver
		says:FireClient(player, lines[index], `driver_{index}`)
		nextLine[player] = if index >= #lines then math.min(Story.DriverLoopFrom, #lines) else index + 1
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		nextLine[player] = nil
		lastTalk[player] = nil
	end)
end

return OldDriver
