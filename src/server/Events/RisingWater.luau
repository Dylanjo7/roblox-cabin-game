--!strict
-- Rising Water: water floods out from the Crawlspace. Get to the room farthest from it on the map.
-- "Farthest" is walking distance through doorways, counted in rooms; if several rooms tie, any of
-- them is safe. Rooms flood in order of distance and the safe rooms stay dry. Judged per player:
-- anyone not standing in a safe room when time runs out is eliminated.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local RoomShapes = require(Shared:WaitForChild("RoomShapes"))
local Types = require(Shared:WaitForChild("Types"))

local MapGrid = require(script.Parent.Parent.MapGrid)
local EventKit = require(script.Parent.EventKit)

type EventRun = Types.EventRun

local WATER = Color3.fromRGB(40, 90, 120)

local RisingWater = {}

function RisingWater.start(run: EventRun)
	local folder = EventKit.folder(run, "RisingWaterEvent")

	local source = EventKit.rooms({})[1]
	for _, cell in MapGrid.all() do
		if cell.id == "crawlspace" then
			source = cell
		end
	end
	local dist = MapGrid.distancesFrom(source.x, source.z)
	local farthest = 0
	for _, d in dist do
		farthest = math.max(farthest, d)
	end
	local safe: { [string]: boolean } = {}
	for k, d in dist do
		if d == farthest then
			safe[k] = true
		end
	end
	run.data.safe = safe

	-- One water sheet per room that will flood.
	local sheets: { { part: Part, dist: number, floor: Vector3 } } = {}
	for _, cell in MapGrid.all() do
		local k = MapGrid.key(cell.x, cell.z)
		local d = dist[k]
		if d ~= nil and not safe[k] then
			local floor = RoomShapes.cellPosition(cell.x, cell.z)
			local hx, hz = MapGrid.halfSize(cell)
			local water = EventKit.part("Water", Vector3.new(hx * 2, 0.05, hz * 2), CFrame.new(floor), WATER, folder)
			water.Transparency = 0.35
			water.Material = Enum.Material.Glass
			water.CanCollide = false
			water.CanQuery = false
			table.insert(sheets, { part = water, dist = d, floor = floor })
		end
	end

	-- Rooms closest to the Crawlspace fill first; the flood front reaches the rooms next to
	-- the safe ones just as time runs out.
	task.spawn(function()
		local duration = math.max(1, run.endsAt - workspace:GetServerTimeNow())
		while not run.over do
			local progress = 1 - math.max(0, run.endsAt - workspace:GetServerTimeNow()) / duration
			for _, sheet in sheets do
				local fill = math.clamp(progress * farthest - sheet.dist + 1, 0, 1)
				local depth = math.max(0.05, fill * Config.Events.WaterMaxDepth)
				sheet.part.Size = Vector3.new(sheet.part.Size.X, depth, sheet.part.Size.Z)
				sheet.part.CFrame = CFrame.new(sheet.floor + Vector3.new(0, depth / 2, 0))
			end
			task.wait(Config.Events.WaterUpdateSeconds)
		end
	end)
end

function RisingWater.onTimeout(run: EventRun): { Player }
	local safe = run.data.safe or {}
	local failed = {}
	for _, player in run.players do
		if run.isActive(player) then
			local x, z = EventKit.cellOf(player)
			if not x or not z or not safe[MapGrid.key(x, z)] then
				table.insert(failed, player)
			end
		end
	end
	return failed
end

function RisingWater.cleanup(run: EventRun)
	EventKit.cleanup(run)
end

return RisingWater
