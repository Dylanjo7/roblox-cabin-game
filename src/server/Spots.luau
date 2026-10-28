--!strict
-- Finding a clear spot in a room for something to sit (an event's key or fuse, a candle, a
-- clue sign) or someone to stand: open floor with nothing over it (no table, bed, shelf or
-- wardrobe) and nothing beside it at standing height (chair legs, crates, the end of a bed).
-- Random spots are tried; if none is clear, it falls back to just inside one of the room's
-- doorways, which is always kept clear.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RoomShapes = require(Shared:WaitForChild("RoomShapes"))

local MapGrid = require(script.Parent.MapGrid)

local Spots = {}

local TRIES = 40

local function characters(): { Instance }
	local out = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(out, player.Character)
		end
	end
	return out
end

-- Is this floor point clear? `clearance` is half the width of the space that has to be empty.
function Spots.isClear(at: Vector3, floorY: number, clearance: number, ignore: { Instance }?): boolean
	local skip = characters()
	for _, inst in ignore or {} do
		table.insert(skip, inst)
	end
	local rays = RaycastParams.new()
	rays.FilterType = Enum.RaycastFilterType.Exclude
	rays.FilterDescendantsInstances = skip
	-- Dropped from just under the hanging lamps, it has to land on the floor itself.
	local hit = workspace:Raycast(Vector3.new(at.X, floorY + 11, at.Z), Vector3.new(0, -12, 0), rays)
	if not hit or math.abs(hit.Position.Y - floorY) > 0.6 then
		return false
	end
	-- And nothing at standing height around it (rugs and the floor itself are below the box).
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	table.insert(skip, hit.Instance)
	overlap.FilterDescendantsInstances = skip
	local box = CFrame.new(at.X, floorY + 1.9, at.Z)
	return #workspace:GetPartBoundsInBox(box, Vector3.new(clearance * 2, 3, clearance * 2), overlap) == 0
end

-- Just inside one of the room's doorways (the doorway itself is always clear).
local function byDoorway(cell: MapGrid.Cell, rng: Random): Vector3?
	local centre = RoomShapes.cellPosition(cell.x, cell.z)
	local model = cell.model
	if not model then
		return nil
	end
	local doorways = {}
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and #child.Name == 1 and string.find("NESW", child.Name, 1, true) then
			table.insert(doorways, child)
		end
	end
	if #doorways == 0 then
		return nil
	end
	local doorway = doorways[rng:NextInteger(1, #doorways)]
	local inward = (centre - doorway.Position) * Vector3.new(1, 0, 1)
	if inward.Magnitude < 0.1 then
		return nil
	end
	local at = doorway.Position + inward.Unit * 3.5
	return Vector3.new(at.X, centre.Y, at.Z)
end

-- A clear floor point (at floor height) in this room. within: only this far from the middle.
function Spots.clear(cell: MapGrid.Cell, rng: Random?, clearance: number?, within: number?, ignore: { Instance }?): Vector3
	local r = rng or Random.new()
	local need = clearance or 1.5
	local centre = RoomShapes.cellPosition(cell.x, cell.z)
	local hx, hz = MapGrid.halfSize(cell)
	local sx = math.max(0.5, hx - need - 0.8)
	local sz = math.max(0.5, hz - need - 0.8)
	if within then
		sx, sz = math.min(sx, within), math.min(sz, within)
	end
	for _ = 1, TRIES do
		local at = centre + Vector3.new(r:NextNumber(-sx, sx), 0, r:NextNumber(-sz, sz))
		if Spots.isClear(at, centre.Y, need, ignore) then
			return at
		end
	end
	return byDoorway(cell, r) or centre
end

-- A clear corner of the room (for the doll), or any clear spot if every corner is taken.
function Spots.corner(cell: MapGrid.Cell, rng: Random, clearance: number?): (Vector3, Vector3)
	local need = clearance or 1
	local centre = RoomShapes.cellPosition(cell.x, cell.z)
	local hx, hz = MapGrid.halfSize(cell)
	local corners = {
		Vector3.new(1, 0, 1),
		Vector3.new(-1, 0, 1),
		Vector3.new(1, 0, -1),
		Vector3.new(-1, 0, -1),
	}
	-- Shuffle with this room's rng, so it's the same corner every time it reappears.
	for i = #corners, 2, -1 do
		local j = rng:NextInteger(1, i)
		corners[i], corners[j] = corners[j], corners[i]
	end
	for _, corner in corners do
		for inset = 1.6, 6, 1.1 do
			local at = centre + corner * Vector3.new(hx - inset, 0, hz - inset)
			if Spots.isClear(at, centre.Y, need) then
				return at, corner
			end
		end
	end
	local at = Spots.clear(cell, rng, need)
	local away = (at - centre) * Vector3.new(1, 0, 1)
	return at, if away.Magnitude > 0.1 then away.Unit else Vector3.zAxis
end

-- Is the wall space in front of a wall sign free (no wardrobe, shelf or portrait in the way)?
-- `cf` is the sign's frame, facing into the room (-Z); `size` the space it needs (depth outwards).
function Spots.wallClear(cf: CFrame, size: Vector3): boolean
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = characters()
	local box = cf * CFrame.new(0, 0, -(size.Z / 2 + 0.3))
	return #workspace:GetPartBoundsInBox(box, size, overlap) == 0
end

-- Room for a player to be put down here (a little wider than an item needs).
function Spots.forPlayer(cell: MapGrid.Cell): Vector3
	return Spots.clear(cell, nil, 2.2) + Vector3.new(0, 3, 0)
end

return Spots
