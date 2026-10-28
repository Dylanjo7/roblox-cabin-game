--!strict
-- Lockdown: every door in the cabin slams shut and each player is shut in a random built room
-- (not the Parlor or Crawlspace; the Parlor if there are no others). A glowing key lies somewhere
-- in each locked room. Taking it opens every door along the shortest way from that room back to
-- the Parlor. Judged per player: anyone not seated at the table when time runs out is eliminated.
-- The event ends early once everyone still in play is back in a seat.

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
			-- On clear floor (never under a table), floating and glinting over a pool of light.
			local floor = EventKit.clearSpot(cell, 1.2)
			local keyModel, key = EventItems.key(folder, CFrame.new(floor + Vector3.new(0, 2.2, 0)) * CFrame.Angles(0, EventKit.rng:NextNumber(0, 6), 0))
			local pool = EventItems.pool(folder, floor, KEY)
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
