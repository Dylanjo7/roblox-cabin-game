--!strict
-- Lockdown: every door in the cabin slams shut and each player is shut in a random built room
-- (not the Parlor or Crawlspace; the Parlor if there are no others). Each locked room's key is
-- always in the same place: floating at chest height just inside the door that leads back
-- towards the table (doorways are always kept clear, so it's never under or behind anything).
-- Taking it opens every door along the shortest way from that room back to the Parlor. Judged
-- per player: anyone not seated at the table when time runs out is eliminated. The event ends
-- early once everyone still in play is back in a seat.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RoomShapes = require(Shared:WaitForChild("RoomShapes"))
local Types = require(Shared:WaitForChild("Types"))

local MapGrid = require(script.Parent.Parent.MapGrid)
local Table = require(script.Parent.Parent.Table)
local EventItems = require(script.Parent.EventItems)
local EventKit = require(script.Parent.EventKit)

type EventRun = Types.EventRun
type Cell = MapGrid.Cell

local DOOR = Color3.fromRGB(64, 46, 32)
local KEY = Color3.fromRGB(230, 190, 90)

local Lockdown = {}

-- Open every door of every room on the shortest walk from this cell to the Parlor.
local function openPathFrom(run: EventRun, start: Cell)
	local panels: { [string]: { Part } } = run.data.panels
	local dist = MapGrid.distancesFrom(0, 0)
	local current: Cell? = start
	while current do
		local k = MapGrid.key(current.x, current.z)
		for _, panel in panels[k] or {} do
			panel:Destroy()
		end
		panels[k] = nil
		local here = dist[k]
		if here == nil or here == 0 then
			break
		end
		local nextCell: Cell? = nil
		for dir in current.doors do
			local dx, dz = RoomShapes.offset(dir :: RoomShapes.Dir)
			local neighbour = MapGrid.get(current.x + dx, current.z + dz)
			if neighbour and neighbour.doors[RoomShapes.opposite(dir :: RoomShapes.Dir)] and dist[MapGrid.key(neighbour.x, neighbour.z)] == here - 1 then
				nextCell = neighbour
				break
			end
		end
		current = nextCell
	end
end

-- The floor point just inside this room's door back towards the Parlor (any open door for the
-- Parlor itself), where its key waits.
local function keySpot(cell: Cell): Vector3
	local centre = RoomShapes.cellPosition(cell.x, cell.z)
	local toward: Vector3? = nil
	local dist = MapGrid.distancesFrom(0, 0)
	local here = dist[MapGrid.key(cell.x, cell.z)]
	for dir in cell.doors do
		local dx, dz = RoomShapes.offset(dir :: RoomShapes.Dir)
		local n = MapGrid.get(cell.x + dx, cell.z + dz)
		if n and here and dist[MapGrid.key(n.x, n.z)] == here - 1 then
			toward = RoomShapes.cellPosition(n.x, n.z)
		end
	end
	local best: BasePart? = nil
	local bestScore = math.huge
	for _, doorway in if cell.model then EventKit.doorways(cell.model) else {} do
		local score = if toward then (doorway.Position - toward).Magnitude else 0
		if not doorway:GetAttribute("Open") then
			score += 1e6 -- a sealed one only if there's nothing else
		end
		if score < bestScore then
			best, bestScore = doorway, score
		end
	end
	if not best then
		return EventKit.clearSpot(cell, 1.2)
	end
	local inward = (centre - best.Position) * Vector3.new(1, 0, 1)
	inward = if inward.Magnitude > 0.1 then inward.Unit else Vector3.zAxis
	local at = best.Position + inward * 3.5
	return Vector3.new(at.X, centre.Y, at.Z)
end

local function allSeated(run: EventRun): boolean
	for _, player in run.players do
		if run.isActive(player) and Table.seatOf(player) == nil then
			return false
		end
	end
	return true
end

function Lockdown.start(run: EventRun)
	local folder = EventKit.folder(run, "LockdownEvent")

	-- Every doorway slams shut. Rooms share an edge, so a doorway between two rooms gets a panel
	-- on each side; opening a room removes its own side.
	local panels: { [string]: { Part } } = {}
	for _, cell in MapGrid.all() do
		local list = {}
		if cell.model then
			for _, doorway in EventKit.doorways(cell.model) do
				if not doorway:GetAttribute("Open") then
					continue -- sealed doorways are already wall
				end
				local panel = EventKit.part("Door", doorway.Size, doorway.CFrame, DOOR, folder)
				EventItems.dressDoor(panel)
				table.insert(list, panel)
			end
		end
		panels[MapGrid.key(cell.x, cell.z)] = list
	end
	run.data.panels = panels

	-- Shut each player in a random room with a key in it.
	local rooms = EventKit.rooms({ parlor = true, crawlspace = true })
	local parlor = MapGrid.get(0, 0)
	assert(parlor, "The Parlor is missing")
	local keys: { [string]: boolean } = {}
	for _, player in run.players do
		local cell = if #rooms > 0 then EventKit.pick(rooms, 1)[1] else parlor
		-- Put down somewhere clear (never inside the furniture).
		EventKit.teleport(player, CFrame.new(EventKit.clearSpot(cell, 2.2) + Vector3.new(0, 3, 0)))
		local k = MapGrid.key(cell.x, cell.z)
		local slamAt = (panels[k] or {})[1]
		if slamAt then
			EventKit.sound("step", slamAt, 0.9)
		end
		if not keys[k] then
			keys[k] = true
			-- By the door back to the table, at chest height, glinting over a pool of light.
			local floor = keySpot(cell)
			local keyModel, key = EventItems.key(folder, CFrame.new(floor + Vector3.new(0, 3.6, 0)) * CFrame.Angles(0, EventKit.rng:NextNumber(0, 6), 0))
			local pool = EventItems.pool(folder, floor, KEY)
			local tag = EventKit.marker(key, "Key", KEY).Parent :: BillboardGui
			tag.MaxDistance = 45
			local prompt = EventKit.prompt(key, "Take", "Key")
			prompt.Triggered:Connect(function(player: Player)
				if not run.isActive(player) then
					return
				end
				keyModel:Destroy()
				pool:Destroy()
				openPathFrom(run, cell)
				EventKit.notifyAll(run, `{player.DisplayName} found a key. The way back to the table is open!`)
			end)
		end
	end

	-- Done early once everyone still in play is back at the table.
	run.data.seatConn = Table.SeatChanged:Connect(function()
		if not run.over and allSeated(run) then
			run.complete()
		end
	end)
end

function Lockdown.onTimeout(run: EventRun): { Player }
	local failed = {}
	for _, player in run.players do
		if run.isActive(player) and Table.seatOf(player) == nil then
			table.insert(failed, player)
		end
	end
	return failed
end

function Lockdown.cleanup(run: EventRun)
	if run.data.seatConn then
		run.data.seatConn:Disconnect()
	end
	EventKit.cleanup(run)
end

return Lockdown
