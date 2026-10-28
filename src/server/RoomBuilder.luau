--!strict
-- Generates room Models from card data: plank floor, trimmed wood walls, a ceiling with beams,
-- a faint floor label, furniture and lamps (RoomProps), and an invisible doorway part named
-- N/E/S/W for each door at the tile's edge. Every room takes one TileSize tile and its pivot is
-- the floor-top centre, so one placement module handles all; smaller rooms (CardData size) sit in
-- the middle of the tile with short passages out to their doorways.
--
-- Each side of a room is a Model "Side<dir>" (dir in the room's own frame) holding two variants,
-- and RoomPlacement shows one of them depending on what's next door:
--   door side:  "Open" (an archway into a connecting room), "Sealed" (plain wall: a room is
--               there but doesn't connect) or "SealedWindow" (nothing built there yet)
--   solid side: "Window" (looks out at the pines) or "Wall" (another room is behind it)
-- Templates are cached in ServerStorage.RoomTemplates; swap in art models there later.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CardData = require(Shared:WaitForChild("CardData"))
local Config = require(Shared:WaitForChild("Config"))
local RoomShapes = require(Shared:WaitForChild("RoomShapes"))

local RoomProps = require(script.Parent.RoomProps)

type Dir = RoomShapes.Dir

local WALL = Color3.fromRGB(104, 84, 64)
local WAINSCOT = Color3.fromRGB(62, 44, 32)
local TRIM = Color3.fromRGB(44, 31, 22)
local CEILING = Color3.fromRGB(46, 34, 26)
local BEAM = Color3.fromRGB(36, 26, 20)
local GLASS = Color3.fromRGB(30, 40, 52)

local WAINSCOT_HEIGHT = 4
local WINDOW_WIDTH = 6
local WINDOW_BOTTOM = 4
local WINDOW_TOP = 10

local STRIPE_SPACING = 2 -- wallpaper stripes, studs apart
local TILED = { kitchen = true, laundry_room = true, bathroom = true } -- tiled floors, not planks

local RoomBuilder = {}

local templates: Folder
local wallpaper = WALL -- wallpaper colour of the room currently being built

local function makePart(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Wood
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function variant(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Builds the pieces of one side in the frame of the north wall; `turn` swings them into place.
-- `e` is how far the wall stands from the room's centre (defaults to the tile's edge).
local function sideBuilder(turn: CFrame, e: number?)
	local room = Config.Room
	local half = e or Config.TileSize / 2
	local z = -(half - room.WallThickness / 2)
	local inner = -(half - room.WallThickness) -- the room-side face of the wall

	local function at(x: number, y: number, dz: number?): CFrame
		return turn * CFrame.new(x, y, z + (dz or 0))
	end

	-- A rectangle of wall from x0..x1, y0..y1: striped wallpaper above dark wainscoting, and
	-- crown moulding if it reaches the ceiling.
	local function segment(parent: Instance, x0: number, x1: number, y0: number, y1: number)
		local width, height = x1 - x0, y1 - y0
		if width <= 0.01 or height <= 0.01 then
			return
		end
		local cx = (x0 + x1) / 2
		local wall = makePart("Wall", Vector3.new(width, height, room.WallThickness), at(cx, (y0 + y1) / 2), wallpaper, parent)
		wall.Material = Enum.Material.Fabric
		-- Clapboard on the outside face (hidden between rooms, seen from the pines).
		local siding = makePart("Siding", Vector3.new(width, height, 0.12), at(cx, (y0 + y1) / 2, -room.WallThickness / 2 - 0.06), Config.Outside.Siding, parent)
		siding.Material = Enum.Material.WoodPlanks
		siding.CastShadow = false

		local paperBottom, paperTop = math.max(y0, WAINSCOT_HEIGHT), math.min(y1, room.WallHeight - 0.5)
		if paperTop - paperBottom > 0.5 then
			local stripe = wallpaper:Lerp(Color3.new(0, 0, 0), 0.18)
			local first = math.ceil(x0 / STRIPE_SPACING) * STRIPE_SPACING
			for x = first, x1 - 0.2, STRIPE_SPACING do
				local s = makePart("Stripe", Vector3.new(0.3, paperTop - paperBottom, 0.04), turn * CFrame.new(x, (paperBottom + paperTop) / 2, inner + 0.02), stripe, parent)
				s.Material = Enum.Material.Fabric
				s.CanCollide = false
				s.CanQuery = false
				s.CastShadow = false
			end
		end

		local wainscotTop = math.min(y1, WAINSCOT_HEIGHT)
		if y0 < wainscotTop then
			local panel = makePart("Wainscot", Vector3.new(width, wainscotTop - y0, 0.15), turn * CFrame.new(cx, (y0 + wainscotTop) / 2, inner + 0.075), WAINSCOT, parent)
			panel.CanCollide = false
			if y0 == 0 then
				makePart("Baseboard", Vector3.new(width, 0.6, 0.3), turn * CFrame.new(cx, 0.3, inner + 0.15), TRIM, parent).CanCollide = false
			end
			if wainscotTop < y1 then
				makePart("Rail", Vector3.new(width, 0.25, 0.3), turn * CFrame.new(cx, wainscotTop, inner + 0.15), TRIM, parent).CanCollide = false
			end
		end
		if y1 >= room.WallHeight then
			makePart("Crown", Vector3.new(width, 0.5, 0.45), turn * CFrame.new(cx, room.WallHeight - 0.25, inner + 0.22), TRIM, parent).CanCollide = false
		end
	end

	return at, segment, inner
end

-- Wall filling x0..x1, y0..y1 with a window (centred on x = 0, `width` wide, from `bottom` to
-- `top`) looking out at the pines. `e`: the wall's distance from the centre.
local function windowWall(parent: Instance, turn: CFrame, e: number, x0: number, x1: number, y0: number, y1: number, width: number, bottom: number, top: number)
	local room = Config.Room
	local at, segment, inner = sideBuilder(turn, e)
	local w = width / 2
	segment(parent, x0, -w, y0, y1)
	segment(parent, w, x1, y0, y1)
	segment(parent, -w, w, y0, bottom)
	segment(parent, -w, w, top, y1)
	local mid = (bottom + top) / 2
	local height = top - bottom
	local glass = makePart("Glass", Vector3.new(width, height, 0.1), at(0, mid), GLASS, parent)
	glass.Material = Enum.Material.Glass
	glass.Transparency = 0.55
	glass.CastShadow = false
	glass:SetAttribute("CentreHeight", mid) -- above the floor
	CollectionService:AddTag(glass, "CabinWindow") -- its LookVector points outside
	for _, x in { -w - 0.25, w + 0.25 } do
		makePart("WindowFrame", Vector3.new(0.5, height + 1, room.WallThickness + 0.3), at(x, mid), TRIM, parent)
	end
	makePart("WindowHead", Vector3.new(width + 1, 0.5, room.WallThickness + 0.3), at(0, top + 0.25), TRIM, parent)
	makePart("Sill", Vector3.new(width + 1.6, 0.4, room.WallThickness + 1), turn * CFrame.new(0, bottom - 0.2, inner + 0.2), TRIM, parent)
	makePart("MullionV", Vector3.new(0.25, height, 0.3), at(0, mid), TRIM, parent).CanCollide = false
	makePart("MullionH", Vector3.new(width, 0.25, 0.3), at(0, mid), TRIM, parent).CanCollide = false
end

-- A wooden archway frame in the doorway of the wall `e` from the centre.
local function archway(parent: Instance, turn: CFrame, e: number)
	local room = Config.Room
	local gap = room.DoorWidth / 2
	local at = sideBuilder(turn, e)
	for _, x in { -gap - 0.3, gap + 0.3 } do
		makePart("ArchPost", Vector3.new(0.7, room.DoorHeight, room.WallThickness + 0.5), at(x, room.DoorHeight / 2), TRIM, parent)
	end
	makePart("ArchHeader", Vector3.new(room.DoorWidth + 1.4, 0.9, room.WallThickness + 0.5), at(0, room.DoorHeight + 0.2), TRIM, parent)
	for _, x in { -gap + 0.6, gap - 0.6 } do
		local corbel = makePart("ArchCorbel", Vector3.new(1, 1, room.WallThickness + 0.3), at(x, room.DoorHeight - 0.5) * CFrame.Angles(0, 0, math.rad(45)), TRIM, parent)
		corbel.CanCollide = false
	end
end

-- A short passage from a doorway in the room's wall (`e` from the centre) out to the tile's
-- edge, where the doorway that joins the next room is.
local function passage(parent: Instance, turn: CFrame, e: number)
	local room = Config.Room
	local length = Config.TileSize / 2 - e
	local mid = -(e + length / 2)
	local width = room.DoorWidth + 2
	local thickness = room.FloorThickness
	local floor = makePart("PassageFloor", Vector3.new(width, thickness, length), turn * CFrame.new(0, -thickness / 2, mid), CardData.DEFAULT_ROOM_COLOR, parent)
	floor.Material = Enum.Material.WoodPlanks
	for _, x in { -(room.DoorWidth / 2 + 0.5), room.DoorWidth / 2 + 0.5 } do
		local outward = if x < 0 then -1 else 1
		local wall = makePart("PassageWall", Vector3.new(room.WallThickness, room.WallHeight, length), turn * CFrame.new(x, room.WallHeight / 2, mid), wallpaper, parent)
		wall.Material = Enum.Material.Fabric
		local siding = makePart("Siding", Vector3.new(0.12, room.WallHeight, length), turn * CFrame.new(x + outward * (room.WallThickness / 2 + 0.06), room.WallHeight / 2, mid), Config.Outside.Siding, parent)
		siding.Material = Enum.Material.WoodPlanks
		siding.CastShadow = false
		makePart("PassageWainscot", Vector3.new(0.15, WAINSCOT_HEIGHT, length), turn * CFrame.new(x - outward * (room.WallThickness / 2 + 0.075), WAINSCOT_HEIGHT / 2, mid), WAINSCOT, parent).CanCollide = false
	end
	local ceiling = makePart("PassageCeiling", Vector3.new(width + 1, 1, length), turn * CFrame.new(0, room.WallHeight + 0.5, mid), CEILING, parent)
	ceiling.Material = Enum.Material.WoodPlanks
	local roof = makePart("PassageRoof", Vector3.new(width + 1, 0.6, length), turn * CFrame.new(0, room.WallHeight + 1.3, mid), Config.Outside.Roof, parent)
	roof.Material = Enum.Material.Slate
end

-- A side with a doorway. `e`/`w`: the wall's distance from the centre and its half-length.
-- `frontDoorAt`: the Parlor's south side also has the front door, centred at this x (in this
-- side's own frame, which lies right of the doorway); Arrival hangs the door in the opening.
local function buildDoorSide(side: Model, turn: CFrame, e: number, w: number, frontDoorAt: number?)
	local room = Config.Room
	local edge = Config.TileSize / 2
	local gap = room.DoorWidth / 2
	local at, segment = sideBuilder(turn, e)

	-- The room's own wall either side of the doorway and above it.
	segment(side, -w, -gap, 0, room.WallHeight)
	if frontDoorAt then
		local d0, d1 = frontDoorAt - Config.FrontDoor.Width / 2, frontDoorAt + Config.FrontDoor.Width / 2
		segment(side, gap, d0, 0, room.WallHeight)
		segment(side, d1, w, 0, room.WallHeight)
		segment(side, d0, d1, Config.FrontDoor.Height, room.WallHeight)
		for _, x in { d0 - 0.3, d1 + 0.3 } do
			makePart("DoorCasing", Vector3.new(0.6, Config.FrontDoor.Height + 0.6, room.WallThickness + 0.4), at(x, Config.FrontDoor.Height / 2), Config.Outside.Trim, side)
		end
		makePart("DoorHead", Vector3.new(Config.FrontDoor.Width + 1.2, 0.6, room.WallThickness + 0.4), at(frontDoorAt, Config.FrontDoor.Height + 0.3), Config.Outside.Trim, side)
	else
		segment(side, gap, w, 0, room.WallHeight)
	end
	segment(side, -gap, gap, room.DoorHeight, room.WallHeight)

	local edgeSegment = segment
	if e < edge - 0.01 then
		-- A smaller room: its own doorway is always open onto a passage out to the tile's edge,
		-- and the far end of the passage is what opens, seals or shows a window.
		archway(side, turn, e)
		passage(side, turn, e)
		local _, s = sideBuilder(turn, edge)
		edgeSegment = s
		edgeSegment(side, -gap - 1, gap + 1, room.DoorHeight, room.WallHeight)
	end

	-- Open: an archway with a wooden frame.
	archway(variant(side, "Open"), turn, edge)
	-- Sealed: the doorway is just wall, because a room that doesn't connect is behind it.
	edgeSegment(variant(side, "Sealed"), -gap, gap, 0, room.DoorHeight)
	-- SealedWindow: nothing built there yet, so the bricked-up doorway has a window onto the pines.
	windowWall(variant(side, "SealedWindow"), turn, edge, -gap, gap, 0, room.DoorHeight, WINDOW_WIDTH, WINDOW_BOTTOM, room.DoorHeight - 0.6)
end

-- An exit room's outside door: a wall with a door in it, boarded and chained shut until the final
-- escape (FinalEscape pulls the boards off and puts a prompt on the panel). It's the same whether
-- the pines or another room are behind it, so its Wall/Window variants are left empty.
local function buildExitDoorSide(side: Model, model: Model, turn: CFrame, e: number, w: number)
	local room = Config.Room
	local at, segment, inner = sideBuilder(turn, e)
	local width, height = Config.FrontDoor.Width, Config.FrontDoor.Height
	local d = width / 2
	segment(side, -w, -d, 0, room.WallHeight)
	segment(side, d, w, 0, room.WallHeight)
	segment(side, -d, d, height, room.WallHeight)
	for _, x in { -d - 0.3, d + 0.3 } do
		makePart("DoorCasing", Vector3.new(0.6, height + 0.6, room.WallThickness + 0.4), at(x, height / 2), TRIM, side)
	end
	makePart("DoorHead", Vector3.new(width + 1.2, 0.6, room.WallThickness + 0.4), at(0, height + 0.3), TRIM, side)
	variant(side, "Wall")
	variant(side, "Window")

	local door = Instance.new("Model")
	door.Name = "ExitDoor"
	door.Parent = model
	local panel = makePart("Panel", Vector3.new(width, height, 0.4), at(0, height / 2), Color3.fromRGB(52, 36, 26), door)
	panel.Material = Enum.Material.WoodPlanks
	makePart("Knob", Vector3.new(0.3, 0.3, 0.3), turn * CFrame.new(d - 0.6, height / 2, inner + 0.25), Color3.fromRGB(150, 120, 60), door).CanCollide = false
	local boards = Instance.new("Model")
	boards.Name = "Boards"
	boards.Parent = door
	for i, y in { 1.6, 4, 6.4 } do
		local tilt = math.rad(if i % 2 == 0 then -14 else 12)
		local board = makePart("Board", Vector3.new(width + 1.6, 0.6, 0.25), turn * CFrame.new(0, y, inner + 0.4) * CFrame.Angles(0, 0, tilt), Color3.fromRGB(110, 86, 58), boards)
		board.Material = Enum.Material.WoodPlanks
		board.CanCollide = false
		for _, x in { -d - 0.3, d + 0.3 } do
			makePart("Nail", Vector3.new(0.12, 0.12, 0.12), turn * CFrame.new(x, y + x * math.tan(tilt), inner + 0.55), Color3.fromRGB(40, 40, 44), boards).CanCollide = false
		end
	end
	local chain = makePart("Chain", Vector3.new(width + 0.6, 0.2, 0.2), turn * CFrame.new(0, height / 2, inner + 0.6), Color3.fromRGB(44, 44, 48), boards)
	chain.Material = Enum.Material.DiamondPlate
	chain.CanCollide = false
	local lock = makePart("Padlock", Vector3.new(0.7, 0.9, 0.35), turn * CFrame.new(0.4, height / 2 - 0.4, inner + 0.7), Color3.fromRGB(120, 96, 50), boards)
	lock.Material = Enum.Material.Metal
	lock.CanCollide = false
end

local function buildSolidSide(side: Model, turn: CFrame, e: number, w: number)
	local room = Config.Room
	local _, segment = sideBuilder(turn, e)

	-- Wall: another room is on the other side.
	segment(variant(side, "Wall"), -w, w, 0, room.WallHeight)

	-- Window: the outside of the cabin.
	windowWall(variant(side, "Window"), turn, e, -w, w, 0, room.WallHeight, WINDOW_WIDTH, WINDOW_BOTTOM, WINDOW_TOP)
end

-- One side of the room, built as the north side and then turned into place. `hx`/`hz`: half the
-- room's inside size at rotation 0.
local function buildSide(model: Model, dir: Dir, hasDoor: boolean, hx: number, hz: number, frontDoorAt: number?, exitDoor: boolean?)
	local room = Config.Room
	local turn = RoomShapes.rotationCFrame(RoomShapes.turnsFromNorth(dir))
	local side = Instance.new("Model")
	side.Name = `Side{dir}`
	side.Parent = model
	-- This side's wall: its distance from the centre and its half-length (walls run a wall's
	-- thickness past the inside so the corners close).
	local northSouth = dir == "N" or dir == "S"
	local e = (if northSouth then hz else hx) + room.WallThickness
	local w = (if northSouth then hx else hz) + room.WallThickness

	if hasDoor then
		buildDoorSide(side, turn, e, w, frontDoorAt)
		-- The doorway itself, at the tile's edge: invisible, used to find doorways (attribute
		-- Open says if it leads anywhere).
		local z = -(Config.TileSize / 2 - room.WallThickness / 2)
		local doorway = makePart(dir, Vector3.new(room.DoorWidth, room.DoorHeight, room.WallThickness), turn * CFrame.new(0, room.DoorHeight / 2, z), WALL, model)
		doorway.Transparency = 1
		doorway.CanCollide = false
		doorway.CanQuery = false
		doorway.CanTouch = false
		doorway:SetAttribute("Open", false)
	elseif exitDoor then
		buildExitDoorSide(side, model, turn, e, w)
	else
		buildSolidSide(side, turn, e, w)
	end
end

local function addFloorLabel(floor: BasePart, text: string)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 10
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.8, 0.15)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(235, 225, 200)
	label.TextTransparency = 0.8 -- faint: a hint for finding your way, not a sign
	label.Text = text
	label.Parent = gui
	gui.Parent = floor
end

local function build(id: string): Model
	local def = CardData.get(id)
	local doors = def.doors
	assert(def.type == "Room" and doors, `{id} is not a room card`)
	wallpaper = def.wall or WALL
	-- Inside half-size at rotation 0 (smaller rooms sit in the middle of the tile).
	local t = Config.Room.WallThickness
	local hx, hz = CardData.roomHalf(id, 0)
	hx, hz = math.min(hx, Config.TileSize / 2 - t), math.min(hz, Config.TileSize / 2 - t)

	local model = Instance.new("Model")
	model.Name = def.name
	model:SetAttribute("CardId", id)
	model:SetAttribute("HalfX", hx)
	model:SetAttribute("HalfZ", hz)

	local thickness = Config.Room.FloorThickness
	local outerX, outerZ = (hx + t) * 2, (hz + t) * 2
	local floor = makePart("Floor", Vector3.new(outerX, thickness, outerZ), CFrame.new(0, -thickness / 2, 0), def.color or CardData.DEFAULT_ROOM_COLOR, model)
	floor.Material = if id == "crawlspace"
		then Enum.Material.Slate
		elseif TILED[id] then Enum.Material.Marble
		else Enum.Material.WoodPlanks
	addFloorLabel(floor, def.name)

	local hasDoor: { [string]: boolean } = {}
	for _, dir in doors do
		hasDoor[dir] = true
	end
	-- An exit room's outside door goes in its first solid side (south if it can).
	local exitDir: string? = nil
	if def.exit then
		for _, dir in { "S", "E", "W", "N" } do
			if not hasDoor[dir] then
				exitDir = dir
				break
			end
		end
	end
	for _, dir in RoomShapes.DIRS do
		-- The south side is turned half round, so its own x runs opposite to world x.
		local frontDoorAt = if id == "parlor" and dir == "S" then -Config.FrontDoor.X else nil
		buildSide(model, dir, hasDoor[dir] == true, hx, hz, frontDoorAt, dir == exitDir)
	end

	local height = Config.Room.WallHeight
	local ceiling = makePart("Ceiling", Vector3.new(outerX, 1, outerZ), CFrame.new(0, height + 0.5, 0), CEILING, model)
	ceiling.Material = Enum.Material.WoodPlanks
	for _, z in { -hz / 2, hz / 2 } do
		makePart("Beam", Vector3.new(hx * 2, 0.8, 1.2), CFrame.new(0, height - 0.4, z), BEAM, model)
	end
	-- Roof: shingles over the ceiling, with a painted fascia (rooms butt up seamlessly).
	local roof = makePart("Roof", Vector3.new(outerX, 0.6, outerZ), CFrame.new(0, height + 1.3, 0), Config.Outside.Roof, model)
	roof.Material = Enum.Material.Slate
	local fascia = makePart("Fascia", Vector3.new(outerX + 0.3, 0.9, outerZ + 0.3), CFrame.new(0, height + 0.55, 0), Config.Outside.Trim, model)
	fascia.CastShadow = false

	RoomProps.build(id, model)

	model.PrimaryPart = floor
	model.WorldPivot = CFrame.new()
	return model
end

-- The cached template Model for a room card (rotation 0, pivot at the origin).
function RoomBuilder.template(id: string): Model
	if not templates then
		templates = Instance.new("Folder")
		templates.Name = "RoomTemplates"
		templates.Parent = ServerStorage
	end
	local existing = templates:FindFirstChild(id)
	if existing then
		return existing :: Model
	end
	local model = build(id)
	model.Name = id
	model.Parent = templates
	return model
end

return RoomBuilder
