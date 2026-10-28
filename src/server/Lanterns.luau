--!strict
-- Everyone carries an oil lantern (a Tool in their backpack, key 1 to hold it). It's lit while
-- you hold it: a warm, shadow-casting light for when an event plunges the cabin into the dark.
-- It isn't tagged RoomLight, so it doesn't flicker with the house lights.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local IRON = Color3.fromRGB(40, 38, 36)
local BRASS = Color3.fromRGB(150, 120, 60)
local FLAME = Color3.fromRGB(255, 170, 70)

local Lanterns = {}

local told: { [Player]: boolean } = {}

local function piece(tool: Tool, handle: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = handle.CFrame * offset
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = p
	weld.Parent = p
	p.Parent = tool
	return p
end

local function build(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Lantern"
	tool.ToolTip = "Your lantern"
	tool.CanBeDropped = false
	tool.ManualActivationOnly = true -- clicking the table doesn't do anything to it
	tool.RequiresHandle = true
	-- Held out a little in front, hanging from its ring.
	tool.Grip = CFrame.new(0, -0.9, 0.4)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.3, 0.3)
	handle.Color = IRON
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Massless = true
	handle.CFrame = CFrame.new()
	handle.Parent = tool

	piece(tool, handle, "Ring", Vector3.new(0.08, 0.5, 0.5), CFrame.new(0, 0.1, 0), IRON, Enum.Material.Metal)
	piece(tool, handle, "Cap", Vector3.new(0.9, 0.2, 0.9), CFrame.new(0, -0.25, 0), IRON, Enum.Material.Metal)
	local glass = piece(tool, handle, "Glass", Vector3.new(0.7, 1, 0.7), CFrame.new(0, -0.85, 0), Color3.fromRGB(230, 210, 170), Enum.Material.Glass)
	glass.Transparency = 0.55
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			piece(tool, handle, "Bar", Vector3.new(0.06, 1, 0.06), CFrame.new(x * 0.37, -0.85, z * 0.37), IRON, Enum.Material.Metal)
		end
	end
	piece(tool, handle, "Base", Vector3.new(0.95, 0.22, 0.95), CFrame.new(0, -1.45, 0), BRASS, Enum.Material.Metal)
	local flame = piece(tool, handle, "Flame", Vector3.new(0.18, 0.3, 0.18), CFrame.new(0, -0.9, 0), FLAME, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Name = "Glow"
	light.Color = FLAME
	light.Range = Config.Lantern.Range
	light.Brightness = Config.Lantern.Brightness
	light.Shadows = true
	light.Parent = flame
	return tool
end

local function give(player: Player)
	local backpack = player:WaitForChild("Backpack", 10)
	if not backpack or backpack:FindFirstChild("Lantern") then
		return
	end
	build().Parent = backpack
	if not told[player] then
		told[player] = true
		task.delay(6, function()
			if player.Parent then
				Remotes.notify(player, "You have a lantern. Press 1 to hold it up when the lights go out.")
			end
		end)
	end
end

function Lanterns.init()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			give(player)
		end)
		if player.Character then
			give(player)
		end
	end
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(player: Player)
		told[player] = nil
	end)
end

return Lanterns
