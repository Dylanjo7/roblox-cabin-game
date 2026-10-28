--!strict
-- Don't Look Away: something pale has climbed out of the mirrors. It only moves while nobody is
-- looking at it, and every so often the lights fail for a blink (each client blacks out when
-- its Blink attribute changes) and it moves anyway. It comes for the nearest player, room to
-- room through the archways; if it reaches you, you're caught. Cover the marked mirrors (a
-- standing mirror in each of up to 3 rooms, never the Parlor or the Crawlspace unless nothing
-- else is built) to send it back. Group task: if any mirror is still bare when time runs out,
-- everyone still in play is caught.
-- "Looking" is where your character faces (the camera is locked first person, so that's where
-- you're looking), within ViewAngle, with nothing solid in between.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local PaleFigureModel = require(Shared:WaitForChild("PaleFigureModel"))
local RoomShapes = require(Shared:WaitForChild("RoomShapes"))
local Types = require(Shared:WaitForChild("Types"))

local Difficulty = require(script.Parent.Parent.Difficulty)
local MapGrid = require(script.Parent.Parent.MapGrid)
local EventItems = require(script.Parent.EventItems)
local EventKit = require(script.Parent.EventKit)

type EventRun = Types.EventRun
type Cell = MapGrid.Cell

local BARE_TEXT = Color3.fromRGB(200, 220, 235)
local COVERED_TEXT = Color3.fromRGB(150, 150, 140)
local SIGHT_HEIGHTS = { 6.9, 4.4, 1.2 } -- its head, chest and hem: seeing any of them counts

local DontLook = {}

local function centre(cell: Cell): Vector3
	return RoomShapes.cellPosition(cell.x, cell.z)
end

local function cellAt(position: Vector3): Cell?
	local x, z = RoomShapes.cellAt(position)
	return MapGrid.get(x, z)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Rooms you can walk to from this one (doorways that line up on both sides).
local function neighbours(cell: Cell): { Cell }
	local out = {}
	for dir in cell.doors do
		local dx, dz = RoomShapes.offset(dir :: RoomShapes.Dir)
		local n = MapGrid.get(cell.x + dx, cell.z + dz)
		if n and n.doors[RoomShapes.opposite(dir :: RoomShapes.Dir)] then
			table.insert(out, n)
		end
	end
	return out
end

-- Inside the room proper, not out in a passage to one of its doorways?
local function inRoom(cell: Cell, at: Vector3): boolean
	local c = centre(cell)
	local hx, hz = MapGrid.halfSize(cell)
	return math.abs(at.X - c.X) <= hx + 0.5 and math.abs(at.Z - c.Z) <= hz + 0.5
end

-- Just inside the room's doorway on the (dx, dz) side. A straight line from here to anywhere in
-- the room stays in the room, so it never cuts through a wall.
local function inner(cell: Cell, dx: number, dz: number): Vector3
	local hx, hz = MapGrid.halfSize(cell)
	return centre(cell) + Vector3.new(dx * (hx - 1.5), 0, dz * (hz - 1.5))
end

-- The way from `position` (in `from`) to the room `to`, through the archways: out through each
-- doorway and in through the next. Empty when it's already in that room.
local function plan(from: Cell, to: Cell, position: Vector3): { Vector3 }
	local points = {}
	if not inRoom(from, position) then
		-- Out in a passage: back into the room first.
		local d = flat(position - centre(from))
		if math.abs(d.X) > math.abs(d.Z) then
			table.insert(points, inner(from, math.sign(d.X), 0))
		else
			table.insert(points, inner(from, 0, math.sign(d.Z)))
		end
	end
	local dist = MapGrid.distancesFrom(to.x, to.z)
	local here = from
	for _ = 1, 40 do
		if here == to then
			break
		end
		local mine = dist[MapGrid.key(here.x, here.z)]
		local step: Cell? = nil
		for _, n in neighbours(here) do
			if mine and dist[MapGrid.key(n.x, n.z)] == mine - 1 then
				step = n
				break
			end
		end
		if not step then
			break
		end
		local dx, dz = step.x - here.x, step.z - here.z
		table.insert(points, inner(here, dx, dz))
		table.insert(points, (centre(here) + centre(step)) / 2)
		table.insert(points, inner(step, -dx, -dz))
		here = step
	end
	return points
end

-- Is anyone still in play looking at it?
local function watched(run: EventRun, position: Vector3, params: RaycastParams): boolean
	local cfg = Config.Events.DontLook
	for _, player in run.players do
		local root = EventKit.root(player)
		if not root or not run.isActive(player) then
			continue
		end
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		local eye = if head and head:IsA("BasePart") then head.Position else root.Position + Vector3.new(0, 1.5, 0)
		local look = flat(root.CFrame.LookVector)
		if look.Magnitude < 0.01 then
			continue
		end
		look = look.Unit
		for _, height in SIGHT_HEIGHTS do
			local offset = position + Vector3.new(0, height, 0) - eye
			local across = flat(offset)
			if across.Magnitude > cfg.ViewDistance then
				break
			end
			local angle = math.deg(math.acos(math.clamp(look:Dot(across.Unit), -1, 1)))
			if angle <= cfg.ViewAngle and workspace:Raycast(eye, offset, params) == nil then
				return true
			end
		end
	end
	return false
end

function DontLook.start(run: EventRun)
	local cfg = Config.Events.DontLook
	local rng = EventKit.rng
	local folder = EventKit.folder(run, "DontLookEvent")

	-- The mirrors to cover, away from the table where there are rooms for them.
	local rooms = EventKit.rooms({ crawlspace = true, parlor = true })
	if #rooms == 0 then
		rooms = EventKit.rooms({ crawlspace = true })
	end
	local picked = EventKit.pick(rooms, cfg.Mirrors)
	local total = #picked
	local covered = 0
	for _, cell in picked do
		local base = EventKit.clearSpot(cell, 1.8)
		local toward = flat(centre(cell) - base)
		local frame, cover = EventItems.mirror(folder, base, if toward.Magnitude > 1 then toward.Unit else Vector3.zAxis)
		local label = EventKit.marker(frame, "Mirror · bare", BARE_TEXT)
		local prompt = EventKit.prompt(frame, "Cover", "Mirror")
		prompt.HoldDuration = cfg.CoverSeconds
		local done = false
		prompt.Triggered:Connect(function(player: Player)
			if done or not run.isActive(player) then
				return
			end
			done = true
			prompt.Enabled = false
			cover()
			label.Text = "Mirror · covered"
			label.TextColor3 = COVERED_TEXT
			covered += 1
			EventKit.notifyAll(run, `{player.DisplayName} covered a mirror ({covered}/{total}).`)
			if covered >= total then
				run.data.detail = "Every mirror is covered."
				run.complete()
			else
				EventKit.setDetail(run, `{covered}/{total} mirrors covered`)
			end
		end)
	end
	EventKit.setDetail(run, `0/{total} mirrors covered`)

	-- It stands in the room farthest from the Parlor (never the Crawlspace), as far from the
	-- table as it can.
	local dist = MapGrid.distancesFrom(0, 0)
	local start = MapGrid.get(0, 0) :: Cell
	local far = -1
	for _, cell in MapGrid.all() do
		local d = dist[MapGrid.key(cell.x, cell.z)]
		if cell.id ~= "crawlspace" and d and d > far then
			start, far = cell, d
		end
	end
	local parlor = RoomShapes.cellPosition(0, 0)
	local position = EventKit.clearSpot(start, 1.5)
	for _ = 1, 6 do
		local other = EventKit.clearSpot(start, 1.5)
		if flat(other - parlor).Magnitude > flat(position - parlor).Magnitude then
			position = other
		end
	end
	local facing = flat(parlor - position)
	facing = if facing.Magnitude > 0.1 then facing.Unit else Vector3.zAxis

	local figure = PaleFigureModel.build(CFrame.lookAt(position, position + facing), nil)
	figure:SetAttribute("Blink", 0)
	CollectionService:AddTag(figure, PaleFigureModel.Tag)
	figure.Parent = folder
	local body = figure.PrimaryPart :: BasePart
	local poseIndex = 1
	local function place()
		PaleFigureModel.pose(figure, CFrame.lookAt(position, position + facing), PaleFigureModel.Poses[poseIndex])
	end
	local function newPose()
		local n = #PaleFigureModel.Poses
		local pick = rng:NextInteger(1, n - 1)
		poseIndex = if pick >= poseIndex then pick + 1 else pick
	end
	EventKit.notifyAll(run, "Something pale is standing in the cabin. Don't take your eyes off it.")

	-- Who it's after: the nearest player still in play (fewest rooms away, then fewest studs).
	local function target(): (BasePart?, Cell?)
		local here = cellAt(position)
		if not here then
			return nil, nil
		end
		local away = MapGrid.distancesFrom(here.x, here.z)
		local bestRoot: BasePart? = nil
		local bestCell: Cell? = nil
		local bestScore = math.huge
		for _, player in run.players do
			local root = EventKit.root(player)
			local cell = root and cellAt(root.Position)
			local roomsAway = cell and away[MapGrid.key(cell.x, cell.z)]
			if root and cell and roomsAway and run.isActive(player) then
				local score = roomsAway * 1000 + flat(root.Position - position).Magnitude
				if score < bestScore then
					bestRoot, bestCell, bestScore = root, cell, score
				end
			end
		end
		return bestRoot, bestCell
	end

	-- Move up to `budget` studs towards its target, ending no closer than `stopShort` to them.
	local route: { Vector3 } = {}
	local routeFor: string? = nil
	local function advance(budget: number, stopShort: number)
		local root, cell = target()
		local here = cellAt(position)
		if not root or not cell or not here then
			return
		end
		local key = MapGrid.key(cell.x, cell.z)
		if routeFor ~= key then
			route = plan(here, cell, position)
			routeFor = key
		end
		while budget > 0.01 do
			local final = #route == 0
			local goal = if final then Vector3.new(root.Position.X, position.Y, root.Position.Z) else route[1]
			local to = flat(goal - position)
			local length = if final then to.Magnitude - stopShort else to.Magnitude
			if length < 0.05 then
				if final then
					break
				end
				table.remove(route, 1)
				continue
			end
			local step = math.min(budget, length)
			position += to.Unit * step
			facing = to.Unit
			budget -= step
			if not final and step >= length then
				table.remove(route, 1)
			end
		end
	end

	local function catch()
		for _, player in run.players do
			local root = EventKit.root(player)
			if root and run.isActive(player) then
				local close = flat(root.Position - position).Magnitude < cfg.CatchDistance
				if close and math.abs(root.Position.Y - position.Y) < 8 then
					EventKit.sound("caught", body, 0.8)
					run.eliminate(player)
				end
			end
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local graceUntil = os.clock() + cfg.GraceSeconds
	local nextBlink = graceUntil + rng:NextNumber(cfg.BlinkMinSeconds, cfg.BlinkMaxSeconds)
	local blinks = 0
	local wasSeen = true

	task.spawn(function()
		while not run.over and figure.Parent do
			local dt = task.wait(0.05)
			if run.over then
				break
			end
			local ignore: { Instance } = { folder }
			for _, p in Players:GetPlayers() do
				if p.Character then
					table.insert(ignore, p.Character)
				end
			end
			params.FilterDescendantsInstances = ignore
			local now = os.clock()
			local seen = watched(run, position, params)

			if now >= nextBlink then
				-- The lights fail. Everyone's dark first, then it moves, and it's somewhere else
				-- when they come back.
				nextBlink = now + rng:NextNumber(cfg.BlinkMinSeconds, cfg.BlinkMaxSeconds)
				blinks += 1
				figure:SetAttribute("Blink", blinks)
				task.wait(cfg.BlinkLeadSeconds)
				if run.over then
					break
				end
				newPose()
				advance(cfg.BlinkStep, cfg.BlinkStopDistance)
				place()
				EventKit.sound("creak", body, 0.5)
				seen = false
			elseif not seen and now > graceUntil then
				-- Nobody's looking: a new pose the moment they turn away, and it comes on fast.
				if wasSeen then
					newPose()
				end
				advance(cfg.Speed * Difficulty.get().huntSpeed * dt, 0)
				place()
			end
			wasSeen = seen
			catch()
		end
	end)
end

function DontLook.onTimeout(run: EventRun): { Player }
	EventKit.notifyAll(run, "The lights go out, and this time they don't come back on.")
	return EventKit.everyoneActive(run)
end

function DontLook.cleanup(run: EventRun)
	EventKit.cleanup(run)
end

return DontLook
