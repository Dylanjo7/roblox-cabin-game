--!strict
-- Doorway directions, rotation and map-cell maths shared by server and client.
-- Map axes: N = -Z, E = +X, S = +Z, W = -X. Rotation r (0..3) turns a room 90 degrees clockwise
-- (seen from above) r times, so a door on N ends up on E after one turn.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

export type Dir = "N" | "E" | "S" | "W"

local RoomShapes = {}

RoomShapes.DIRS = { "N", "E", "S", "W" } :: { Dir } -- clockwise

local INDEX: { [string]: number } = { N = 0, E = 1, S = 2, W = 3 }
local OFFSET: { [string]: { number } } = {
	N = { 0, -1 },
	E = { 1, 0 },
	S = { 0, 1 },
	W = { -1, 0 },
}

function RoomShapes.rotateDir(dir: Dir, rotation: number): Dir
	return RoomShapes.DIRS[(INDEX[dir] + rotation) % 4 + 1]
end

function RoomShapes.rotate(doors: { Dir }, rotation: number): { Dir }
	local out = {}
	for _, dir in doors do
		table.insert(out, RoomShapes.rotateDir(dir, rotation))
	end
	return out
end

function RoomShapes.opposite(dir: Dir): Dir
	return RoomShapes.rotateDir(dir, 2)
end

-- Map offset (dx, dz) of the neighbouring cell through this doorway.
function RoomShapes.offset(dir: Dir): (number, number)
	local o = OFFSET[dir]
	return o[1], o[2]
end

-- Number of clockwise turns that take N to this direction.
function RoomShapes.turnsFromNorth(dir: Dir): number
	return INDEX[dir]
end

function RoomShapes.isRotation(value: any): boolean
	return typeof(value) == "number" and value == math.floor(value) and value >= 0 and value <= 3
end

-- World rotation for a room turned clockwise `rotation` times.
function RoomShapes.rotationCFrame(rotation: number): CFrame
	return CFrame.Angles(0, -rotation * math.pi / 2, 0)
end

-- Floor-top centre of map cell (x, z).
function RoomShapes.cellPosition(x: number, z: number): Vector3
	return Config.ParlorOrigin + Vector3.new(x * Config.TileSize, 0, z * Config.TileSize)
end

-- Floor-level CFrame just inside the front door, facing into the Parlor (towards the table).
function RoomShapes.frontDoorInside(): CFrame
	local origin = Config.ParlorOrigin
	local spot = origin + Vector3.new(Config.FrontDoor.X, 0, Config.TileSize / 2 - 2)
	return CFrame.lookAt(spot, Vector3.new(origin.X, spot.Y, origin.Z))
end

-- The map cell a world position falls in.
function RoomShapes.cellAt(position: Vector3): (number, number)
	local offset = position - Config.ParlorOrigin
	return math.floor(offset.X / Config.TileSize + 0.5), math.floor(offset.Z / Config.TileSize + 0.5)
end

function RoomShapes.inBounds(x: number, z: number): boolean
	return x >= Config.GridMin and x <= Config.GridMax and z >= Config.GridMin and z <= Config.GridMax
end

return RoomShapes
