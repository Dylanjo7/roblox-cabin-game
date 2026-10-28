--!strict
-- How the cabin map is laid out on the Parlor table. The map zooms to fit: the built rooms plus
-- a margin of empty cells (where the next room could go) are centred on the table's centre disk
-- and scaled to fill it, up to Config.Table.MapMaxCellSize per cell. So tiles are big while the
-- cabin is small and shrink as it grows. Server (table map) and client (board placement) compute
-- it from the same public list of built cells, so they always agree.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

export type View = {
	cx: number, -- map cell coordinates at the disk's centre (may be fractional)
	cz: number,
	size: number, -- studs per cell
	minX: number, -- the cells shown (built rooms plus margin)
	maxX: number,
	minZ: number,
	maxZ: number,
}

local MapView = {}

-- `cells`: built rooms, anything with x and z.
function MapView.compute(cells: { { x: number, z: number } }): View
	local margin = Config.Table.MapMargin
	local minX, maxX, minZ, maxZ = 0, 0, 0, 0
	for _, cell in cells do
		minX, maxX = math.min(minX, cell.x), math.max(maxX, cell.x)
		minZ, maxZ = math.min(minZ, cell.z), math.max(maxZ, cell.z)
	end
	minX, maxX, minZ, maxZ = minX - margin, maxX + margin, minZ - margin, maxZ + margin
	local span = math.max(maxX - minX, maxZ - minZ) + 1
	-- The largest square that fits inside the disk, with a little breathing room.
	local square = Config.Table.CenterRadius * math.sqrt(2) * 0.95
	return {
		cx = (minX + maxX) / 2,
		cz = (minZ + maxZ) / 2,
		size = math.min(Config.Table.MapMaxCellSize, square / span),
		minX = minX,
		maxX = maxX,
		minZ = minZ,
		maxZ = maxZ,
	}
end

-- Centre of cell (x, z) on the table (same axes as the world).
function MapView.cellPosition(view: View, x: number, z: number): Vector3
	return Config.ParlorOrigin
		+ Vector3.new((x - view.cx) * view.size, Config.Table.TopHeight + Config.Table.CenterRaise, (z - view.cz) * view.size)
end

-- The cell under a point on the table.
function MapView.cellAt(view: View, position: Vector3): (number, number)
	local offset = position - Config.ParlorOrigin
	return math.floor(offset.X / view.size + view.cx + 0.5), math.floor(offset.Z / view.size + view.cz + 0.5)
end

-- Is this cell inside the area shown?
function MapView.shows(view: View, x: number, z: number): boolean
	return x >= view.minX and x <= view.maxX and z >= view.minZ and z <= view.maxZ
end

return MapView
