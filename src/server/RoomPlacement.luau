--!strict
-- The one placement module for every room: rotation, doorway matching and spawning.
-- A spot is valid when the cell is empty and in bounds and at least one of the room's
-- doorways lines up with an open doorway of a neighbouring room that can be built from.
-- Cell (x, z) spawns at Parlor position + (x*TileSize, 0, z*TileSize).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CardData = require(Shared:WaitForChild("CardData"))
local RoomShapes = require(Shared:WaitForChild("RoomShapes"))
local Types = require(Shared:WaitForChild("Types"))

local MapGrid = require(script.Parent.MapGrid)
local RoomBuilder = require(script.Parent.RoomBuilder)

type Dir = RoomShapes.Dir
type Placement = Types.Placement

local RoomPlacement = {}

local cabinFolder: Folder

local function cabin(): Folder
	if not cabinFolder then
		cabinFolder = Instance.new("Folder")
		cabinFolder.Name = "Cabin"
		cabinFolder.Parent = workspace
	end
	return cabinFolder
end

-- World-facing doorways of a room card at this rotation.
function RoomPlacement.doorsFor(id: string, rotation: number): { Dir }
	local doors = CardData.get(id).doors
	assert(doors, `{id} is not a room card`)
	return RoomShapes.rotate(doors, rotation)
end

function RoomPlacement.isValid(id: string, x: number, z: number, rotation: number): boolean
	if not RoomShapes.isRotation(rotation) or not MapGrid.inBounds(x, z) or MapGrid.get(x, z) then
		return false
	end
	for _, dir in RoomPlacement.doorsFor(id, rotation) do
		local dx, dz = RoomShapes.offset(dir)
		local neighbour = MapGrid.get(x + dx, z + dz)
		if neighbour and neighbour.buildable and neighbour.doors[RoomShapes.opposite(dir)] then
			return true
		end
	end
	return false
end

-- Every valid (cell, rotation) for this room card. Only cells behind an open doorway can match.
function RoomPlacement.findAll(id: string): { Placement }
	local found: { Placement } = {}
	local seen: { [string]: boolean } = {}
	for _, cell in MapGrid.all() do
		if cell.buildable then
			for dir in cell.doors do
				local dx, dz = RoomShapes.offset(dir :: Dir)
				local x, z = cell.x + dx, cell.z + dz
				for rotation = 0, 3 do
					local k = `{x},{z},{rotation}`
					if not seen[k] and RoomPlacement.isValid(id, x, z, rotation) then
						seen[k] = true
						table.insert(found, { x = x, z = z, rotation = rotation })
					end
				end
			end
		end
	end
	return found
end

-- The room's sides keyed by world direction, read from the "Side<dir>" models RoomBuilder made.
local function collectSides(model: Model, rotation: number): { [string]: MapGrid.Side }
	local sides = {}
	for _, dir in RoomShapes.DIRS do
		local container = model:FindFirstChild(`Side{dir}`)
		if container and container:IsA("Model") then
			local variants = {}
			for _, child in container:GetChildren() do
				if child:IsA("Model") then
					variants[child.Name] = child
				end
			end
			local doorway = model:FindFirstChild(dir)
			sides[RoomShapes.rotateDir(dir, rotation)] = {
				container = container,
				variants = variants,
				doorway = if doorway and doorway:IsA("BasePart") then doorway else nil,
			}
		end
	end
	return sides
end

local function show(side: MapGrid.Side, name: string)
	for variantName, model in side.variants do
		model.Parent = if variantName == name then side.container else nil
	end
end

-- Pick each side's look from what's next door: a doorway is an open archway only when the
-- neighbour has a doorway facing back; otherwise it's sealed (with a window if nothing is built
-- there yet). A solid wall is a window onto the pines unless another room is behind it.
local function refreshSides(cell: MapGrid.Cell)
	for dir, side in cell.sides or {} do
		local dx, dz = RoomShapes.offset(dir :: Dir)
		local neighbour = MapGrid.get(cell.x + dx, cell.z + dz)
		if side.variants.Open then
			local open = neighbour ~= nil and neighbour.doors[RoomShapes.opposite(dir :: Dir)] == true
			show(side, if open then "Open" elseif neighbour then "Sealed" else "SealedWindow")
			if side.doorway then
				side.doorway:SetAttribute("Open", open)
			end
		else
			show(side, if neighbour then "Wall" else "Window")
		end
	end
end

-- Your own decorations for this room (ServerStorage.RoomDecor.<room id>, saved from the edit-mode
-- preview, see Preview): copied into the room in a "Decor" folder, positioned relative to it, so
-- they turn and move with the room wherever it's built.
local function addDecor(model: Model, id: string)
	local store = ServerStorage:FindFirstChild("RoomDecor")
	local saved = store and store:FindFirstChild(id)
	if not saved then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Decor"
	local pivot = model:GetPivot()
	for _, item in saved:GetChildren() do
		if item:IsA("PVInstance") then
			local copy = item:Clone() :: PVInstance
			copy:PivotTo(pivot * item:GetPivot()) -- saved relative to the room
			copy.Parent = folder
		end
	end
	folder.Parent = model
end

-- Spawn the room in the world and record it on the map. Callers validate first
-- (the Parlor is the only room placed without a neighbour).
function RoomPlacement.place(id: string, x: number, z: number, rotation: number): Model
	local def = CardData.get(id)
	local model = RoomBuilder.template(id):Clone()
	addDecor(model, id)
	model.Name = `{def.name} ({x},{z})`
	model:PivotTo(CFrame.new(RoomShapes.cellPosition(x, z)) * RoomShapes.rotationCFrame(rotation))

	local doors: { [string]: boolean } = {}
	for _, dir in RoomPlacement.doorsFor(id, rotation) do
		doors[dir] = true
	end
	local cell: MapGrid.Cell = {
		x = x,
		z = z,
		id = id,
		rotation = rotation,
		doors = doors,
		buildable = def.buildable ~= false,
		model = model,
		sides = collectSides(model, rotation),
	}
	refreshSides(cell)
	model.Parent = cabin()
	MapGrid.set(cell)

	-- The rooms around it may now open an archway into it, or lose a window to it.
	for _, dir in RoomShapes.DIRS do
		local dx, dz = RoomShapes.offset(dir)
		local neighbour = MapGrid.get(x + dx, z + dz)
		if neighbour then
			refreshSides(neighbour)
		end
	end
	return model
end

return RoomPlacement
