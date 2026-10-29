--!strict
-- He Walks: the Hollow Man enters the cabin in person and hunts. He appears in the room farthest
-- from the Parlor and walks room to room through the open archways, usually towards the nearest
-- player, sometimes wandering. You hear his steps. He sees in a cone in front of him, and walls
-- and furniture block his sight; hidden players (wardrobes, under beds) can't be seen. If he sees
-- you he comes straight at you, a little slower than you can run. Being seen from across a room
-- doesn't catch you: he has to reach you, or keep you in sight up close for a moment. He takes
-- one at a time: whoever he catches is held while he gets them (clients play his kill), and for
-- a few seconds after he stays over them and can't catch anyone else, so the rest can run. When
-- time runs out he leaves; everyone not caught is safe.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local HollowManModel = require(Shared:WaitForChild("HollowManModel"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local RoomShapes = require(Shared:WaitForChild("RoomShapes"))
local Types = require(Shared:WaitForChild("Types"))

local Difficulty = require(script.Parent.Parent.Difficulty)
local MapGrid = require(script.Parent.Parent.MapGrid)
local EventKit = require(script.Parent.EventKit)
local Hiding = require(script.Parent.Hiding)

type EventRun = Types.EventRun
type Cell = MapGrid.Cell

local HeWalks = {}

local function centre(cell: Cell): Vector3
	return RoomShapes.cellPosition(cell.x, cell.z)
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

local function cellAt(position: Vector3): Cell?
	local x, z = RoomShapes.cellAt(position)
	return MapGrid.get(x, z)
end

-- Players he could be after: in play, not hidden, with a character.
local function targets(run: EventRun): { Player }
	local out = {}
	for _, player in run.players do
		if run.isActive(player) and not Hiding.isHidden(run, player) and not EventKit.isSeized(run, player) and EventKit.root(player) then
			table.insert(out, player)
		end
	end
	return out
end

-- The next leg of his walk from this room: through a doorway into a neighbouring room, usually
-- the one that leads towards the nearest player.
local function nextLeg(run: EventRun, from: Cell): { Vector3 }
	local cfg = Config.Events.HeWalks
	local options = neighbours(from)
	if #options == 0 then
		return { EventKit.spotIn(from) }
	end
	local choice = options[EventKit.rng:NextInteger(1, #options)]
	if EventKit.rng:NextNumber() < cfg.HuntChance then
		local here = MapGrid.distancesFrom(from.x, from.z)
		local best: Cell? = nil
		local bestDist = math.huge
		for _, player in targets(run) do
			local root = EventKit.root(player)
			local cell = root and cellAt(root.Position)
			local d = cell and here[MapGrid.key(cell.x, cell.z)]
			if cell and d and d > 0 and d < bestDist then
				best, bestDist = cell, d
			end
		end
		if best then
			local toTarget = MapGrid.distancesFrom(best.x, best.z)
			local mine = toTarget[MapGrid.key(from.x, from.z)]
			for _, n in options do
				if mine and toTarget[MapGrid.key(n.x, n.z)] == mine - 1 then
					choice = n
					break
				end
			end
		end
	end
	local doorway = (centre(from) + centre(choice)) / 2
	return { doorway, centre(choice) }
end

function HeWalks.start(run: EventRun)
	local cfg = Config.Events.HeWalks
	local folder = EventKit.folder(run, "HeWalksEvent")
	Hiding.enable(run)

	-- He comes in at the room farthest from the Parlor (never the Crawlspace, where the
	-- eliminated wait).
	-- (The final escape sets run.data.startCell to bring him into the Parlor instead.)
	local dist = MapGrid.distancesFrom(0, 0)
	local start = MapGrid.get(0, 0) :: Cell
	local far = -1
	for _, cell in MapGrid.all() do
		local d = dist[MapGrid.key(cell.x, cell.z)]
		if cell.id ~= "crawlspace" and d and d > far then
			start, far = cell, d
		end
	end
	if run.data.startCell then
		start = run.data.startCell
	end

	-- An invisible marker; each client draws and animates him on it (HollowManView).
	-- (The final escape also sets run.data.startAt: just inside the front door.)
	local position = centre(start)
	local facing = Vector3.new(0, 0, -1)
	local entry = run.data.startAt
	if typeof(entry) == "CFrame" then
		position = entry.Position
		facing = entry.LookVector
	end
	local figure = HollowManModel.marker(CFrame.lookAt(position, position + facing), folder)
	EventKit.notifyAll(run, "He's inside the cabin. Stay out of his sight...")

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exposure: { [Player]: number } = {}
	local warned: { [Player]: boolean } = {}
	-- (The final escape holds him in the doorway a while first, and slows him down.)
	local holdUntil = os.clock() + (run.data.holdSeconds or 0)
	local graceUntil = math.max(os.clock() + cfg.GraceSeconds, holdUntil)
	local pace = Difficulty.get().huntSpeed * (run.data.speedScale or 1)
	local route: { Vector3 } = {}
	local lastStep = 0
	local busyUntil = 0 -- after a catch: he stays put, and can't catch anyone, until then

	task.spawn(function()
		while not run.over and figure.Parent do
			local dt = task.wait(0.05)
			if run.over then
				break
			end

			-- Who can he see? Walls and furniture block him; other players don't.
			local ignore: { Instance } = { folder }
			for _, p in Players:GetPlayers() do
				if p.Character then
					table.insert(ignore, p.Character)
				end
			end
			params.FilterDescendantsInstances = ignore
			local eye = position + Vector3.new(0, cfg.EyeHeight, 0)
			local chase: Vector3? = nil
			local chaseDistance = math.huge
			local busy = os.clock() < busyUntil
			figure:SetAttribute("Killing", busy)
			for _, player in run.players do
				local visible = false
				local root = EventKit.root(player)
				local flatDistance = math.huge
				if root and not busy and run.isActive(player) and not Hiding.isHidden(run, player) and not EventKit.isSeized(run, player) then
					local target = root.Position + Vector3.new(0, 1.5, 0)
					local offset = target - eye
					local flat = Vector3.new(offset.X, 0, offset.Z)
					flatDistance = flat.Magnitude
					if flatDistance < cfg.ViewDistance and flatDistance > 0.01 then
						local angle = math.deg(math.acos(math.clamp(facing:Dot(flat.Unit), -1, 1)))
						if angle <= cfg.ViewAngle and workspace:Raycast(eye, offset, params) == nil then
							visible = true
						end
					end
				end
				if visible and root then
					-- Only up close does being in his sight count against you.
					exposure[player] = if flatDistance < cfg.CloseDistance then (exposure[player] or 0) + dt else 0
					if not warned[player] then
						warned[player] = true
						Remotes.notify(player, "He sees you. RUN.")
					end
					if flatDistance < chaseDistance then
						chase, chaseDistance = Vector3.new(root.Position.X, position.Y, root.Position.Z), flatDistance
					end
					local caught = exposure[player] >= cfg.CatchSeconds or flatDistance < cfg.GrabDistance
					if caught and os.clock() > graceUntil and EventKit.seize(run, player, position) then
						-- Got one. He closes on them and stays over them; everyone else has a moment.
						EventKit.sound("caught", figure, 0.8)
						exposure[player] = 0
						busy = true
						busyUntil = os.clock() + Config.Events.KillPauseSeconds
						figure:SetAttribute("Killing", true)
						local toThem = Vector3.new(root.Position.X - position.X, 0, root.Position.Z - position.Z)
						if toThem.Magnitude > 0.1 then
							facing = toThem.Unit
							position = Vector3.new(root.Position.X, position.Y, root.Position.Z) - facing * 2.6
						end
						chase = nil
						for _, other in run.players do
							if other ~= player and run.isActive(other) then
								Remotes.notify(other, `He's got {player.DisplayName}. Run, while he's busy!`)
							end
						end
						break
					end
				else
					exposure[player] = 0
					warned[player] = false
				end
			end

			-- Walk: straight at whoever he sees, otherwise room to room (not while he's held in the
			-- doorway, or busy with someone).
			local goal: Vector3? = chase
			local speed = cfg.ChaseSpeed * pace
			if busy then
				goal = nil
			elseif os.clock() < holdUntil then
				goal = nil
				if chase then
					facing = (chase - position).Unit
				end
			elseif chase then
				route = {}
			else
				speed = cfg.WalkSpeed * pace
				if #route == 0 then
					local here = cellAt(position) or start
					route = nextLeg(run, here)
				end
				goal = route[1]
			end
			if goal then
				local to = Vector3.new(goal.X - position.X, 0, goal.Z - position.Z)
				if to.Magnitude < 0.6 then
					if not chase then
						table.remove(route, 1)
					end
				else
					position += to.Unit * math.min(speed * dt, to.Magnitude)
					facing = to.Unit
				end
			end
			figure.CFrame = CFrame.lookAt(position, position + facing)
			figure:SetAttribute("Chasing", chase ~= nil)

			if os.clock() - lastStep > cfg.StepSeconds then
				lastStep = os.clock()
				EventKit.sound("step", figure, 0.35)
			end
		end
	end)
end

function HeWalks.onTimeout(run: EventRun): { Player }
	EventKit.notifyAll(run, "His footsteps fade into the pines. He's gone... for now.")
	return {} -- anyone he didn't catch is safe
end

function HeWalks.cleanup(run: EventRun)
	Hiding.cleanup(run)
	EventKit.cleanup(run)
end

return HeWalks
