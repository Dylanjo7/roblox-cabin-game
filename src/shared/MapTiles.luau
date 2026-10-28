--!strict
-- Builds one room tile for the cabin map on the Parlor table: a parchment square with the room's
-- name, ink walls along its edges and gaps where its doorways are (drawn as parts, so they always
-- match the room's rotation). The server uses it for built rooms; the client uses the plain
-- coloured version (pass a colour) for the placement ghost and highlights. Positions and size
-- come from the MapView (the map zooms to fit the cabin).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CardData = require(Shared:WaitForChild("CardData"))
local CardFace = require(Shared:WaitForChild("CardFace"))
local MapView = require(Shared:WaitForChild("MapView"))
local RoomShapes = require(Shared:WaitForChild("RoomShapes"))

local DOOR = Color3.fromRGB(240, 220, 170)
local PARCHMENT = Color3.fromRGB(226, 212, 182)
local INK = Color3.fromRGB(44, 32, 24)

local MapTiles = {}

local function makePart(name: string, size: Vector3, cf: CFrame, color: Color3, transparency: number, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Transparency = transparency
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

-- Ink walls along the tile's edges, with a gap for each doorway (world directions).
local function walls(model: Model, centre: Vector3, s: number, doors: { [string]: boolean }, alpha: number, color: Color3)
	local half = s * 0.47
	local t = s * 0.07
	for _, dir in RoomShapes.DIRS do
		local dx, dz = RoomShapes.offset(dir)
		local along = if dx == 0 then Vector3.new(1, 0, 0) else Vector3.new(0, 0, 1)
		local edge = centre + Vector3.new(dx, 0, dz) * (half - t / 2) + Vector3.new(0, 0.07, 0)
		local pieces = if doors[dir] then { { -half, -half * 0.36 }, { half * 0.36, half } } else { { -half, half } }
		for _, piece in pieces do
			local a, b = piece[1], piece[2]
			local length = b - a
			local size = if dx == 0 then Vector3.new(length, 0.04, t) else Vector3.new(t, 0.04, length)
			makePart(`Wall{dir}`, size, CFrame.new(edge + along * ((a + b) / 2)), color, alpha, model)
		end
	end
end

function MapTiles.make(view: MapView.View, cardId: string, x: number, z: number, rotation: number, parent: Instance, color: Color3?, transparency: number?): Model
	local def = CardData.get(cardId)
	local s = view.size
	local alpha = transparency or 0
	local centre = MapView.cellPosition(view, x, z)
	local doors: { [string]: boolean } = {}
	for _, dir in RoomShapes.rotate(def.doors or {}, rotation) do
		doors[dir] = true
	end

	local model = Instance.new("Model")
	model.Name = `{def.name} ({x},{z})`
	if color then
		-- Plain coloured version: the placement ghost.
		makePart("Tile", Vector3.new(s * 0.94, 0.06, s * 0.94), CFrame.new(centre + Vector3.new(0, 0.03, 0)), color, alpha, model)
		walls(model, centre, s, doors, alpha, color:Lerp(Color3.new(0, 0, 0), 0.5))
		for dir in doors do
			local dx, dz = RoomShapes.offset(dir :: RoomShapes.Dir)
			local size = if dz ~= 0 then Vector3.new(s * 0.3, 0.08, s * 0.14) else Vector3.new(s * 0.14, 0.08, s * 0.3)
			makePart(`Door{dir}`, size, CFrame.new(centre + Vector3.new(dx * s * 0.43, 0.05, dz * s * 0.43)), DOOR, alpha, model)
		end
	else
		-- Parchment tile, turned with the room so its name reads the way the room faces.
		-- (A quarter turn so the name reads left to right with north up.)
		local tile = makePart("Tile", Vector3.new(s * 0.96, 0.05, s * 0.96), CFrame.new(centre + Vector3.new(0, 0.025, 0)) * RoomShapes.rotationCFrame(rotation) * CFrame.Angles(0, math.rad(-90), 0), PARCHMENT, alpha, model)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Top
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = math.floor(260 / s)
		gui.LightInfluence = 0.8
		CardFace.tile(gui, cardId)
		gui.Parent = tile
		walls(model, centre, s, doors, alpha, INK)
	end
	model.Parent = parent
	return model
end

-- A flat square marking a cell (used for highlights).
function MapTiles.marker(view: MapView.View, x: number, z: number, color: Color3, transparency: number, parent: Instance): Part
	local s = view.size
	return makePart(`Marker ({x},{z})`, Vector3.new(s * 0.95, 0.02, s * 0.95), CFrame.new(MapView.cellPosition(view, x, z) + Vector3.new(0, 0.01, 0)), color, transparency, parent)
end

return MapTiles
