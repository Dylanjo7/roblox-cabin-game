--!strict
-- Fuse Box: the power dies. The spare fuse is always in the same place, the middle of the
-- Crawlspace (marked so it shows through the walls): fetch it and carry it back to the fuse box
-- in the Parlor. Group task: if the fuse isn't in the box when time runs out, everyone still in
-- play is eliminated. If whoever has it leaves the game, it turns up again where it was found.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local RoomShapes = require(Shared:WaitForChild("RoomShapes"))
local Types = require(Shared:WaitForChild("Types"))

local MapGrid = require(script.Parent.Parent.MapGrid)
local EventItems = require(script.Parent.EventItems)
local EventKit = require(script.Parent.EventKit)

type EventRun = Types.EventRun

local FUSE_COLOR = Color3.fromRGB(255, 205, 80)

local FuseBox = {}

-- Where the spare fuse is kept, every time: the middle of the Crawlspace (the room every run
-- starts with, and the middle of it is always open floor), or the Parlor if it's missing.
local function fuseSpot(): Vector3
	for _, cell in MapGrid.all() do
		if cell.id == "crawlspace" then
			return RoomShapes.cellPosition(cell.x, cell.z)
		end
	end
	return EventKit.clearSpot(MapGrid.get(0, 0) :: MapGrid.Cell, 1.2)
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

	-- The fuse: floating, turning and glowing over a pool of light, so it can be found in the dark.
	local floor = fuseSpot()
	local fuseModel: Model
	local function placeFuse()
		local model, fuse = EventItems.fuse(folder, CFrame.new(floor + Vector3.new(0, 1.8, 0)))
		fuseModel = model
		local pool = EventItems.pool(folder, floor, FUSE_COLOR)
		EventKit.marker(fuse, "Fuse", FUSE_COLOR)
		local pickUp = EventKit.prompt(fuse, "Pick up", "Fuse")
		pickUp.Triggered:Connect(function(player: Player)
			if not run.isActive(player) or run.data.carrier then
				return
			end
			local root = EventKit.root(player)
			if not root then
				return
			end
			run.data.carrier = player
			run.data.carrierRoot = root
			pickUp.Enabled = false
			pool:Destroy()
			EventItems.carry(model, root, CFrame.new(1.2, 0, -0.8))
			EventKit.notifyAll(run, `{player.DisplayName} has the fuse. Get it to the fuse box in the Parlor!`)
		end)
	end
	placeFuse()

	-- Whoever had it is gone (left the game, lost their character, or is out): it goes back.
	task.spawn(function()
		while not run.over do
			task.wait(0.5)
			local carrier = run.data.carrier
			if carrier and not run.over and (carrier.Parent == nil or not run.isActive(carrier) or EventKit.root(carrier) ~= run.data.carrierRoot) then
				run.data.carrier = nil
				run.data.carrierRoot = nil
				fuseModel:Destroy()
				placeFuse()
				EventKit.notifyAll(run, "The fuse has turned up again where it was found.")
			end
		end
	end)

	-- The fuse cabinet, on the Parlor's north wall, facing into the room.
	local parlor = RoomShapes.cellPosition(0, 0)
	local inner = Config.TileSize / 2 - Config.Room.WallThickness
	local box, powerOn = EventItems.fuseBox(folder, CFrame.new(parlor + Vector3.new(-12, 5, -inner + 0.8)) * CFrame.Angles(0, math.pi, 0))
	local insert = EventKit.prompt(box, "Insert fuse", "Fuse box")
	insert.Triggered:Connect(function(player: Player)
		if not run.isActive(player) then
			return
		end
		if run.data.carrier ~= player then
			Remotes.notify(player, "You need the fuse.")
			return
		end
		fuseModel:Destroy()
		powerOn()
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
