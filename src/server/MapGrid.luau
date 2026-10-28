--!strict
-- The cabin map: which room is in which cell, its rotated doorways, and its world model.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CardData = require(Shared:WaitForChild("CardData"))
local Config = require(Shared:WaitForChild("Config"))
local RoomShapes = require(Shared:WaitForChild("RoomShapes"))
local Types = require(Shared:WaitForChild("Types"))

export type Cell = {
	x: number,
	z: number,
	id: string,
	rotation: number,
	doors: { [string]: boolean }, -- world-facing doorways after rotation
	buildable: boolean,
	model: Model?,
	-- The room's four sides, keyed by world direction (see RoomBuilder): which variants it has
	-- and the doorway part on door sides.
	sides: { [string]: Side }?,
}

export type Side = {
	container: Model,
	variants: { [string]: Model },
	doorway: BasePart?,
}

local MapGrid = {}

local cells: { [string]: Cell } = {}
local changed = Instance.new("BindableEvent")

-- Fires after a room is added or the map is cleared.
MapGrid.Changed = changed.Event

local function key(x: number, z: number): string
	return `{x},{z}`
end

function MapGrid.clear()
	for _, cell in cells do
		if cell.model then
			cell.model:Destroy()
		end
	end
	cells = {}
	changed:Fire()
end

function MapGrid.inBounds(x: number, z: number): boolean
	return RoomShapes.inBounds(x, z)
end

function MapGrid.get(x: number, z: number): Cell?
	return cells[key(x, z)]
end

function MapGrid.set(cell: Cell)
	cells[key(cell.x, cell.z)] = cell
	changed:Fire()
end

function MapGrid.all(): { Cell }
	local list = {}
	for _, cell in cells do
		table.insert(list, cell)
	end
	return list
end

MapGrid.key = key

-- Walking distance, in rooms, from cell (x, z) to every room reachable through doorways that
-- line up on both sides. Keyed by MapGrid.key(x, z).
function MapGrid.distancesFrom(x: number, z: number): { [string]: number }
	local start = MapGrid.get(x, z)
	if not start then
		return {}
	end
	local dist: { [string]: number } = { [key(x, z)] = 0 }
	local queue: { Cell } = { start }
	local head = 1
	while head <= #queue do
		local cell = queue[head]
		head += 1
		for dir in cell.doors do
			local dx, dz = RoomShapes.offset(dir :: RoomShapes.Dir)
			local neighbour = MapGrid.get(cell.x + dx, cell.z + dz)
			if neighbour and neighbour.doors[RoomShapes.opposite(dir :: RoomShapes.Dir)] then
				local k = key(neighbour.x, neighbour.z)
				if dist[k] == nil then
					dist[k] = dist[key(cell.x, cell.z)] + 1
					table.insert(queue, neighbour)
				end
			end
		end
	end
	return dist
end

-- Half the inside size of the room in this cell, along world x and z (smaller rooms sit in the
-- middle of their tile).
function MapGrid.halfSize(cell: Cell): (number, number)
	local limit = Config.TileSize / 2 - Config.Room.WallThickness
	local hx, hz = CardData.roomHalf(cell.id, cell.rotation)
	return math.min(hx, limit), math.min(hz, limit)
end

function MapGrid.publicCells(): { Types.CellPublic }
	local list = {}
	for _, cell in cells do
		table.insert(list, { x = cell.x, z = cell.z, id = cell.id, rotation = cell.rotation })
	end
	return list
end

return MapGrid
