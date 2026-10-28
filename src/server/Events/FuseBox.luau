--!strict
-- Fuse Box: the power dies. Find the fuse in a random built room and carry it back to the
-- fuse box in the Parlor. Group task: if the fuse isn't in the box when time runs out,
-- everyone still in play is eliminated.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local RoomShapes = require(Shared:WaitForChild("RoomShapes"))
local Types = require(Shared:WaitForChild("Types"))

local MapGrid = require(script.Parent.Parent.MapGrid)
local EventKit = require(script.Parent.EventKit)

type EventRun = Types.EventRun

local FUSE_COLOR = Color3.fromRGB(255, 205, 80)
local BOX_COLOR = Color3.fromRGB(90, 92, 96)

local FuseBox = {}

-- A random built room other than the Parlor and Crawlspace (the Parlor if there's none).
local function fuseSpot(): Vector3
	local rooms = EventKit.rooms({ parlor = true, crawlspace = true })
	local cell = if #rooms > 0 then EventKit.pick(rooms, 1)[1] else MapGrid.get(0, 0)
	assert(cell, "The Parlor is missing")
	return EventKit.spotIn(cell) + Vector3.new(0, 0.8, 0)
end

local function darken(run: EventRun)
	run.data.lighting = {
		ClockTime = Lighting.ClockTime,
		Brightness = Lighting.Brightness,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
	}
	Lighting.ClockTime = Config.Events.DarkClockTime
	Lighting.Brightness = Config.Events.DarkBrightness
	Lighting.Ambient = Color3.fromRGB(20, 20, 26)
	Lighting.OutdoorAmbient = Color3.fromRGB(16, 16, 22)

	-- Each player carries a small light so they can still find their way.
	local lights = {}
	for _, player in run.players do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local light = Instance.new("PointLight")
			light.Name = "EventLight"
			light.Range = Config.Events.PlayerLightRange
			light.Brightness = 1.2
			light.Color = Color3.fromRGB(255, 225, 180)
			light.Parent = root
			table.insert(lights, light)
		end
	end
	run.data.lights = lights
end

function FuseBox.start(run: EventRun)
	darken(run)
	local folder = EventKit.folder(run, "FuseBoxEvent")

	-- The fuse: glows so it can be found in the dark.
	local fuse = EventKit.part("Fuse", Vector3.new(0.6, 1.2, 0.6), CFrame.new(fuseSpot()), FUSE_COLOR, folder)
	fuse.Material = Enum.Material.Neon
	fuse.CanCollide = false
	local glow = Instance.new("PointLight")
	glow.Color = FUSE_COLOR
	glow.Range = 10
	glow.Parent = fuse
	local pickUp = EventKit.prompt(fuse, "Pick up", "Fuse")
	pickUp.Triggered:Connect(function(player: Player)
		if not run.isActive(player) or run.data.carrier then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return
		end
		run.data.carrier = player
		pickUp.Enabled = false
		fuse.Anchored = false
		fuse.Massless = true
		fuse.CFrame = root.CFrame * CFrame.new(1.2, 0, -0.8)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = fuse
		weld.Parent = fuse
		EventKit.notifyAll(run, `{player.DisplayName} has the fuse. Get it to the fuse box in the Parlor!`)
	end)

	-- The fuse box, on the Parlor's north wall.
	local parlor = RoomShapes.cellPosition(0, 0)
	local inner = Config.TileSize / 2 - Config.Room.WallThickness
	local box = EventKit.part("FuseBox", Vector3.new(3, 4, 0.6), CFrame.new(parlor + Vector3.new(-12, 5, -inner + 0.3)), BOX_COLOR, folder)
	local insert = EventKit.prompt(box, "Insert fuse", "Fuse box")
	insert.Triggered:Connect(function(player: Player)
		if not run.isActive(player) then
			return
		end
		if run.data.carrier ~= player then
			Remotes.notify(player, "You need the fuse.")
			return
		end
		box.Color = FUSE_COLOR
		run.complete()
	end)
end

function FuseBox.onTimeout(run: EventRun): { Player }
	return EventKit.everyoneActive(run)
end

function FuseBox.cleanup(run: EventRun)
	local saved = run.data.lighting
	if saved then
		Lighting.ClockTime = saved.ClockTime
		Lighting.Brightness = saved.Brightness
		Lighting.Ambient = saved.Ambient
		Lighting.OutdoorAmbient = saved.OutdoorAmbient
	end
	for _, light in run.data.lights or {} do
		light:Destroy()
	end
	EventKit.cleanup(run)
end

return FuseBox
