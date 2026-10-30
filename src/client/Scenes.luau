--!strict
-- The cutscenes, played with Cinema:
--   intro: when the front door slams. The door; the fire and the table with its carved rim; out
--     through a window, him among the pines; the grandfather clock ticking.
--   enters: the first time he comes onto the clock. His piece steps onto nine on the table, then
--     out through a window, he walks out of the trees towards the cabin.
--   midnight: his piece reaches midnight, and he's at the window, much closer, watching.
--   lastTurn: his piece catches the Candle. Three knocks; the front door creaks open on nothing;
--     a look at the Candle, and back at the door he's standing inside it (Atmosphere keeps him
--     there until the Candle gets away).
--   three: 3:00 AM. The grandfather clock strikes three, the boards fall off an exit room's
--     door, and the front door bursts open: he's in the cabin (the hunt starts as it ends).
--   ending: escaped (the dead truck starts and you drive away at dawn), caught (the Candle goes out and he leans
--     over the table), lost (the cabin's lights go out one by one), never built (the card box).
-- Each returns false if it couldn't play, so the caller shows the plain text version instead.
-- The mid-game ones only play while the table is waiting on him (the Clock stage); three plays
-- while the final escape holds off for it (Config.Cinematics.ThreeSeconds).

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local RoomShapes = require(Shared:WaitForChild("RoomShapes"))
local Story = require(Shared:WaitForChild("Story"))
local TruckModel = require(Shared:WaitForChild("TruckModel"))

local Audio = require(script.Parent.Audio)
local Cinema = require(script.Parent.Cinema)
local HollowManView = require(script.Parent.HollowManView)
local TablePieces = require(script.Parent.TablePieces)

local Scenes = {}

type Shot = { from: number, to: number, a: CFrame, b: CFrame }

local function ease(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

-- A camera that moves from a to b within each shot, holding the last one at the end.
local function shots(list: { Shot }): (number) -> CFrame
	return function(t: number): CFrame
		local chosen = list[#list]
		for _, shot in list do
			if t < shot.to then
				chosen = shot
				break
			end
		end
		return chosen.a:Lerp(chosen.b, ease((t - chosen.from) / (chosen.to - chosen.from)))
	end
end

local function parlor(): Model?
	local cabin = workspace:FindFirstChild("Cabin")
	if not cabin then
		return nil
	end
	for _, room in cabin:GetChildren() do
		if room:IsA("Model") and string.find(room.Name, "(0,0)", 1, true) then
			return room
		end
	end
	return nil
end

-- Something in the Parlor's furniture, by name.
local function prop(name: string): Instance?
	local room = parlor()
	local props = room and room:FindFirstChild("Props")
	return props and props:FindFirstChild(name, true)
end

local function centreOf(inst: Instance?): Vector3?
	if inst and inst:IsA("Model") then
		local cf = inst:GetBoundingBox()
		return cf.Position
	elseif inst and inst:IsA("BasePart") then
		return inst.Position
	end
	return nil
end

-- A window to look out of (its LookVector points outside): in the Parlor if there is one.
local function window(): BasePart?
	local origin = Config.ParlorOrigin
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, glass in CollectionService:GetTagged("CabinWindow") do
		if glass:IsA("BasePart") then
			local d = (glass.Position - origin).Magnitude
			if d < bestDistance then
				best, bestDistance = glass, d
			end
		end
	end
	return best
end

-- Looking out through a window from inside, at a point `out` studs beyond it.
local function throughWindow(glass: BasePart, back: number, out: number): CFrame
	local outside = glass.CFrame.LookVector
	local eye = glass.Position - outside * back
	return CFrame.lookAt(eye, glass.Position + outside * out - Vector3.new(0, 2, 0))
end

-- A close look at the Hollow Man's piece on the table.
local function pieceShot(): (CFrame, CFrame)
	local at = TablePieces.hollowAt().Position
	local centre = Config.ParlorOrigin + Vector3.new(0, Config.Table.TopHeight, 0)
	local out = (at - centre) * Vector3.new(1, 0, 1)
	out = if out.Magnitude > 0.1 then out.Unit else Vector3.zAxis
	local look = at + Vector3.new(0, 0.6, 0)
	return CFrame.lookAt(at + out * 3 + Vector3.new(0, 1.6, 0), look), CFrame.lookAt(at + out * 1.8 + Vector3.new(0, 0.9, 0), look)
end

------------------------------------------------------------------------------------------------

function Scenes.intro(): boolean
	local origin = Config.ParlorOrigin
	local tableTop = origin + Vector3.new(0, Config.Table.TopHeight, 0)
	local list: { Shot } = {}

	-- The door, just slammed.
	local doorModel = workspace:FindFirstChild("FrontDoor")
	local door = if doorModel and doorModel:IsA("Model") then doorModel:GetPivot().Position + Vector3.new(Config.FrontDoor.Width / 2, 4, 0) else origin + Vector3.new(Config.FrontDoor.X, 4, Config.TileSize / 2)
	table.insert(list, { from = 0, to = 5, a = CFrame.lookAt(door + Vector3.new(3, 1.5, -13), door), b = CFrame.lookAt(door + Vector3.new(1, 0.4, -8), door) })

	-- The fire, then down to the table and its carved rim.
	local fire = centreOf(prop("Fireplace")) or (origin + Vector3.new(12, 3, 17))
	local toRoom = (origin - fire) * Vector3.new(1, 0, 1)
	toRoom = if toRoom.Magnitude > 0.1 then toRoom.Unit else Vector3.zAxis
	table.insert(list, { from = 5, to = 9, a = CFrame.lookAt(fire + toRoom * 12 + Vector3.new(0, 3, 0), fire), b = CFrame.lookAt(fire + toRoom * 6.5 + Vector3.new(0, 1, 0), fire - Vector3.new(0, 1, 0)) })
	table.insert(list, { from = 9, to = 13, a = CFrame.lookAt(tableTop + Vector3.new(7, 6, 4), tableTop), b = CFrame.lookAt(tableTop + Vector3.new(-4, 4, 6), tableTop) })

	-- Out through a window: him, standing among the pines.
	local glass = window()
	local figure: HollowManView.Handle? = nil
	if glass then
		table.insert(list, { from = 13, to = 19, a = throughWindow(glass, 7, 30), b = throughWindow(glass, 4, 28) })
	end

	-- The grandfather clock, ticking.
	local face = prop("Face")
	local clockAt = if face and face:IsA("BasePart") then face else nil
	local clockEnd = if glass then 19 else 13
	if clockAt then
		local front = clockAt.CFrame.LookVector
		table.insert(list, { from = clockEnd, to = clockEnd + 5, a = CFrame.lookAt(clockAt.Position + front * 5 + Vector3.new(0, -0.5, 0), clockAt.Position), b = CFrame.lookAt(clockAt.Position + front * 2.4, clockAt.Position) })
	else
		table.insert(list, { from = clockEnd, to = clockEnd + 5, a = CFrame.lookAt(tableTop + Vector3.new(0, 9, 9), tableTop), b = CFrame.lookAt(tableTop + Vector3.new(0, 6, 6), tableTop) })
	end

	local lines = {}
	local starts = { 0.6, 5.4, if glass then 13.4 else 9.4, clockEnd + 0.4 }
	for i, text in Story.Intro do
		table.insert(lines, { at = starts[i] or (clockEnd + 0.4), line = text, voice = `intro_{i}` })
	end

	return Cinema.play({
		length = clockEnd + 5,
		camera = shots(list),
		lines = lines,
		onFrame = function(t: number)
			if glass and t >= 13 and t < 19 and not figure then
				local outside = glass.CFrame.LookVector
				local feet = Vector3.new(0, origin.Y, 0) + (glass.Position + outside * 26) * Vector3.new(1, 0, 1)
				figure = HollowManView.spawnLocal(CFrame.lookAt(feet, Vector3.new(glass.Position.X, origin.Y, glass.Position.Z)), true, false)
				Audio.play("whisper", 0.5)
			elseif figure and t >= 19 then
				figure.destroy()
				figure = nil
			end
		end,
		onEnd = function()
			if figure then
				figure.destroy()
			end
		end,
	})
end

-- His piece steps onto the clock, and out in the pines, he steps out of the trees.
function Scenes.enters(): boolean
	local glass = window()
	if not glass then
		return false
	end
	local origin = Config.ParlorOrigin
	local a, b = pieceShot()
	local outside = glass.CFrame.LookVector
	local base = Vector3.new(glass.Position.X, origin.Y, glass.Position.Z)
	local from = base + outside * 36
	local to = base + outside * 24
	local figure: HollowManView.Handle? = nil
	return Cinema.play({
		length = 7,
		fadeIn = 0.5,
		camera = shots({
			{ from = 0, to = 2.6, a = a, b = b },
			{ from = 2.6, to = 7, a = throughWindow(glass, 6, 30), b = throughWindow(glass, 3.5, 26) },
		}),
		lines = { { at = 2.8, line = Story.Beats.enters, voice = "beat_enters" } },
		onFrame = function(t: number)
			if t >= 2.6 then
				local u = math.clamp((t - 2.6) / 4.2, 0, 1)
				local at = from:Lerp(to, u)
				if not figure then
					figure = HollowManView.spawnLocal(CFrame.lookAt(at, to), false, false)
					Audio.play("step", 0.5, nil, 0.8)
				end
				figure.setPivot(CFrame.lookAt(at, to + (to - from)), if u < 1 then 3 else 0)
			end
		end,
		onEnd = function()
			if figure then
				figure.destroy()
			end
		end,
	})
end

-- Midnight: his piece on the twelve, and he's right outside the window, watching.
function Scenes.midnight(): boolean
	local glass = window()
	if not glass then
		return false
	end
	local origin = Config.ParlorOrigin
	local a, b = pieceShot()
	local outside = glass.CFrame.LookVector
	local feet = Vector3.new(glass.Position.X, origin.Y, glass.Position.Z) + outside * 9
	local figure: HollowManView.Handle? = nil
	return Cinema.play({
		length = 6,
		fadeIn = 0.5,
		camera = shots({
			{ from = 0, to = 2.3, a = a, b = b },
			{ from = 2.3, to = 6, a = throughWindow(glass, 6, 10), b = throughWindow(glass, 2.5, 9) },
		}),
		lines = { { at = 2.5, line = Story.Beats.midnight, voice = "beat_midnight" } },
		onFrame = function(t: number)
			if t >= 2.3 and not figure then
				figure = HollowManView.spawnLocal(CFrame.lookAt(feet, Vector3.new(glass.Position.X, origin.Y, glass.Position.Z)), true, false)
				Audio.play("whisper", 0.8)
				Audio.play("caught", 0.4)
			end
		end,
		onEnd = function()
			if figure then
				figure.destroy()
			end
		end,
	})
end

-- The front door model and where it hangs closed (its pivot is the hinge), to swing it open
-- just for this client and put it back after.
local function frontDoor(): (Model?, CFrame)
	local door = workspace:FindFirstChild("FrontDoor")
	if door and door:IsA("Model") then
		return door, door:GetPivot()
	end
	return nil, CFrame.new()
end

-- Looking at the front door from beside the table.
local function doorShot(push: number): (CFrame, CFrame)
	local origin = Config.ParlorOrigin
	local door = origin + Vector3.new(Config.FrontDoor.X, 4, Config.TileSize / 2)
	return CFrame.lookAt(origin + Vector3.new(Config.FrontDoor.X + 6, 6, 4), door), CFrame.lookAt(origin + Vector3.new(Config.FrontDoor.X + 3, 5, 4 + push), door)
end

-- His piece has caught the Candle. Three knocks at the front door, and it creaks open on an
-- empty doorway. A look at the Candle; back at the door, it's shut again, and he's inside it.
-- (Where he stands is where Atmosphere keeps him for the rest of the last turn.)
function Scenes.lastTurn(): boolean
	local door, closed = frontDoor()
	if not door then
		return false
	end
	local length = Config.Cinematics.LastTurnSeconds
	local candle = TablePieces.candleAt().Position
	local centre = Config.ParlorOrigin + Vector3.new(0, Config.Table.TopHeight, 0)
	local out = (candle - centre) * Vector3.new(1, 0, 1)
	out = if out.Magnitude > 0.1 then out.Unit else Vector3.zAxis
	local side = out:Cross(Vector3.yAxis)
	local look = candle + Vector3.new(0, 0.5, 0)
	local flame = candle + Vector3.new(0, 0.9, 0)
	local a, b = doorShot(3)
	local c, d = doorShot(5)
	local figure: HollowManView.Handle? = nil
	local knocks = 0
	local opened = false
	local whispered = false
	local panel = door:FindFirstChild("Door")
	local at = if panel and panel:IsA("BasePart") then panel else nil
	return Cinema.play({
		length = length,
		fadeIn = 0.4,
		camera = shots({
			-- The two pieces side by side on the rim; the door; the Candle's flame; the door.
			{ from = 0, to = 2.8, a = CFrame.lookAt(candle + out * 2.6 + side * 1.2 + Vector3.new(0, 1.4, 0), look), b = CFrame.lookAt(candle + out * 1.6 + side * 0.5 + Vector3.new(0, 0.8, 0), look) },
			{ from = 2.8, to = 6, a = a, b = b },
			{ from = 6, to = 7.2, a = CFrame.lookAt(flame + out * 1.3 + Vector3.new(0, 0.2, 0), flame), b = CFrame.lookAt(flame + out * 0.9 + Vector3.new(0, 0.1, 0), flame) },
			{ from = 7.2, to = length, a = c, b = d },
		}),
		lines = { { at = 3.2, line = Story.Beats.caught, voice = "beat_caught" } },
		onStart = function()
			Audio.play("caught", 0.6)
		end,
		onFrame = function(t: number)
			while knocks < 3 and t >= 3.1 + knocks * 0.55 do
				knocks += 1
				Audio.play("knock", 0.9, at)
			end
			if t >= 4.8 and t < 6 then
				if not opened then
					opened = true
					Audio.play("creak", 0.8, at)
				end
				door:PivotTo(closed * CFrame.Angles(0, math.rad(80 * ease((t - 4.8) / 1.4)), 0))
			elseif t >= 6 and not figure then
				-- While you looked away: the door's shut, and he's in.
				door:PivotTo(closed)
				figure = HollowManView.spawnLocal(RoomShapes.frontDoorInside(), true, true)
			end
			if figure and t >= 7.2 and not whispered then
				whispered = true
				Audio.play("whisper", 0.7)
			end
		end,
		onEnd = function()
			door:PivotTo(closed)
			if figure then
				figure.destroy()
			end
		end,
	})
end

-- 3:00 AM. The clock strikes three, an exit door's boards fall, and the front door bursts open:
-- he's inside, where the hunt starts (RoomShapes.hollowEntry) when this ends.
function Scenes.three(): boolean
	local door, closed = frontDoor()
	local length = Config.Cinematics.ThreeSeconds
	local origin = Config.ParlorOrigin
	local tableTop = origin + Vector3.new(0, Config.Table.TopHeight, 0)
	local list: { Shot } = {}

	-- The grandfather clock (or the table, if there isn't one).
	local face = prop("Face")
	if face and face:IsA("BasePart") then
		local front = face.CFrame.LookVector
		table.insert(list, { from = 0, to = 3.6, a = CFrame.lookAt(face.Position + front * 4.6 + Vector3.new(0, -0.6, 0), face.Position), b = CFrame.lookAt(face.Position + front * 2.2, face.Position) })
	else
		table.insert(list, { from = 0, to = 3.6, a = CFrame.lookAt(tableTop + Vector3.new(0, 9, 9), tableTop), b = CFrame.lookAt(tableTop + Vector3.new(0, 6, 6), tableTop) })
	end

	-- The exit door nearest the Parlor, from inside its room, as its boards come away.
	local exitPanel: BasePart? = nil
	local cabin = workspace:FindFirstChild("Cabin")
	if cabin then
		local best = math.huge
		for _, inst in cabin:GetDescendants() do
			if inst.Name == "ExitDoor" and inst:IsA("Model") then
				local p = inst:FindFirstChild("Panel")
				if p and p:IsA("BasePart") and (p.Position - origin).Magnitude < best then
					exitPanel, best = p, (p.Position - origin).Magnitude
				end
			end
		end
	end
	local doorFrom = 3.6
	if exitPanel then
		local x, z = RoomShapes.cellAt(exitPanel.Position)
		local into = (RoomShapes.cellPosition(x, z) - exitPanel.Position) * Vector3.new(1, 0, 1)
		into = if into.Magnitude > 0.1 then into.Unit else Vector3.zAxis
		local target = exitPanel.Position
		table.insert(list, { from = 3.6, to = 6.6, a = CFrame.lookAt(target + into * 11 + Vector3.new(0, 1.5, 0), target), b = CFrame.lookAt(target + into * 7 + Vector3.new(0, 0.5, 0), target) })
		doorFrom = 6.6
	end

	-- The front door.
	local a, b = doorShot(2)
	table.insert(list, { from = doorFrom, to = length, a = a, b = b })

	local figure: HollowManView.Handle? = nil
	local booms = 0
	local burst = false
	local slammed = false
	local panel = door and door:FindFirstChild("Door")
	local at = if panel and panel:IsA("BasePart") then panel else nil
	local burstAt = doorFrom + 0.5
	return Cinema.play({
		length = length,
		fadeIn = 0.4,
		camera = shots(list),
		lines = { { at = 0.8, line = Story.Beats.three, voice = "beat_three" } },
		onFrame = function(t: number)
			-- The clock strikes three: deep, slow.
			while booms < 3 and t >= 0.5 + booms * 1.0 do
				booms += 1
				Audio.play("step", 0.9, nil, 0.45)
			end
			if t < burstAt then
				return
			end
			if not burst then
				burst = true
				Audio.play("caught", 0.8)
				Audio.play("step", 1, at, 0.7)
			end
			-- Flung open on the dark; the lights stutter and he's in; it slams behind him.
			if door then
				local open = ease((t - burstAt) / 0.35)
				local shut = ease((t - (burstAt + 1.0)) / 0.3)
				door:PivotTo(closed * CFrame.Angles(0, math.rad(100 * open * (1 - shut)), 0))
				if shut >= 1 and not slammed then
					slammed = true
					Audio.play("step", 0.8, at, 0.9)
				end
			end
			if t >= burstAt + 0.8 and not figure then
				Audio.play("flicker", 0.7)
				figure = HollowManView.spawnLocal(RoomShapes.hollowEntry(), true, true)
			end
		end,
		onEnd = function()
			if door then
				door:PivotTo(closed)
			end
			if figure then
				figure.destroy()
			end
		end,
	})
end

------------------------------------------------------------------------------------------------

local function endingLines(key: string): { Cinema.Line }
	local ending = Story.Endings[key]
	local lines = {}
	for i, text in ending.lines do
		table.insert(lines, { at = 3 + (i - 1) * 4.4, line = text, voice = `ending_{key}_{i}` })
	end
	return lines
end

-- Escaped: you drive away. The truck that died at the end of the path coughs and starts, its
-- headlights come up, and it pulls away down the road as dawn comes up through the pines; behind
-- it the cabin's windows go dark one by one, and its tail lights shrink into the trees.
local function escaped(): boolean
	local outside = workspace:FindFirstChild("Outside")
	local dead = outside and outside:FindFirstChild("Truck")
	-- Where it starts: the dead truck's spot, or (if a room was built over the path) clear of the
	-- southernmost room.
	local startAt: Vector3
	if dead and dead:IsA("Model") then
		startAt = dead:GetPivot().Position
	else
		local south = Config.ParlorOrigin.Z + Config.TileSize / 2
		local cabin = workspace:FindFirstChild("Cabin")
		for _, room in if cabin then cabin:GetChildren() else {} do
			if room:IsA("Model") then
				south = math.max(south, room:GetPivot().Position.Z + Config.TileSize / 2)
			end
		end
		startAt = Vector3.new(Config.ParlorOrigin.X - 3, 0, south + 18)
	end
	startAt = Vector3.new(startAt.X, 0, startAt.Z)
	local away = CFrame.new(startAt) * CFrame.Angles(0, math.pi, 0) -- facing down the road (+Z)
	local truck = TruckModel.build(away, { body = Color3.fromRGB(112, 58, 40), trim = Color3.fromRGB(196, 186, 160), cargo = true })
	local beams: { Light } = {}
	for _, inst in truck:GetDescendants() do
		if inst:IsA("SpotLight") or inst:IsA("PointLight") then
			table.insert(beams, inst)
			inst.Enabled = false
		end
	end
	local deadTruck: Model? = if dead and dead:IsA("Model") then dead else nil
	local savedDead = if deadTruck then deadTruck:GetPivot() else nil
	local lights: { Light } = {}
	for _, light in CollectionService:GetTagged("RoomLight") do
		if light:IsA("Light") and light.Enabled then
			table.insert(lights, light)
		end
	end
	local out = 0
	local saved = { ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness, FogColor = Lighting.FogColor, FogEnd = Lighting.FogEnd, OutdoorAmbient = Lighting.OutdoorAmbient }
	-- Everyone who got out is in the truck, so nobody's left standing by the road.
	local function hidePeople(hidden: boolean)
		for _, player in Players:GetPlayers() do
			for _, inst in if player.Character then player.Character:GetDescendants() else {} do
				if inst:IsA("BasePart") or inst:IsA("Decal") then
					inst.LocalTransparencyModifier = if hidden then 1 else 0
				end
			end
		end
	end

	-- How far down the road it is at t: still for a moment, then pulling away, faster and faster.
	local GO = 3.2
	local function along(t: number): number
		local u = math.max(0, t - GO)
		return math.min(0.5 * 5 * u * u, 28 * u)
	end
	local function truckAt(t: number): CFrame
		local moving = if t > GO then 1 else 0
		return away * CFrame.new(0, math.sin(t * 9) * 0.05 * moving, -along(t))
	end
	local cabinAt = Config.ParlorOrigin + Vector3.new(0, 7, 0)
	return Cinema.play({
		length = 18,
		title = Story.Endings.escaped.title,
		titleAt = 0.8,
		camera = function(t: number): CFrame
			local body = truckAt(t).Position + Vector3.new(0, 2.5, 0)
			if t < 4 then
				-- Beside it as it turns over.
				local eye = (away * CFrame.new(-7, 3.2, -6)).Position
				return CFrame.lookAt(eye:Lerp((away * CFrame.new(-6, 2.6, -2)).Position, ease(t / 4)), body)
			elseif t < 11 then
				-- From the path, watching it go.
				local eye = (away * CFrame.new(-3, 3.5, 9)).Position
				return CFrame.lookAt(eye, body:Lerp(body + Vector3.new(0, 1, 0), (t - 4) / 7))
			end
			-- High over the road: the tail lights into the pines, the dark cabin behind.
			local u = ease((t - 11) / 7)
			local eye = (away * CFrame.new(10, 16 + u * 6, 14)).Position
			return CFrame.lookAt(eye, body:Lerp(cabinAt, 0.25 + u * 0.15))
		end,
		lines = endingLines("escaped"),
		onStart = function()
			Audio.play("ending", 0.5)
			truck.Parent = workspace
			hidePeople(true)
			if deadTruck and savedDead then
				deadTruck:PivotTo(savedDead + Vector3.new(0, -500, 0)) -- (it's this one, running now)
			end
			local info = TweenInfo.new(16, Enum.EasingStyle.Sine)
			TweenService:Create(Lighting, info, { ClockTime = 6.2, Brightness = 1.8, FogColor = Color3.fromRGB(190, 176, 168), FogEnd = 400, OutdoorAmbient = Color3.fromRGB(120, 112, 118) }):Play()
		end,
		onFrame = function(t: number)
			truck:PivotTo(truckAt(t))
			-- It starts first time: a shudder, the headlights flicker, then they come up.
			if t > 1.2 then
				local on = t > 2.2 or (t > 1.5 and t < 1.7)
				for _, light in beams do
					light.Enabled = on
				end
			end
			if t > 1.2 and t < 2.2 then
				truck:PivotTo(truckAt(t) * CFrame.new(math.sin(t * 60) * 0.05, 0, 0))
			end
			-- Behind it, one window after another goes dark.
			local want = math.clamp(math.floor((t - 6) / 0.35), 0, #lights)
			while out < want do
				out += 1
				lights[out].Enabled = false
			end
		end,
		onEnd = function()
			truck:Destroy()
			hidePeople(false)
			if deadTruck and savedDead then
				deadTruck:PivotTo(savedDead)
			end
			for _, light in lights do
				light.Enabled = true
			end
			for prop, value in saved do
				(Lighting :: any)[prop] = value
			end
		end,
	})
end

-- Caught: the Candle goes out, and he's standing over the table.
local function caught(): boolean
	local origin = Config.ParlorOrigin
	local candle = TablePieces.candleAt().Position
	local centre = origin + Vector3.new(0, Config.Table.TopHeight, 0)
	local out = (candle - centre) * Vector3.new(1, 0, 1)
	out = if out.Magnitude > 0.1 then out.Unit else Vector3.zAxis
	local feet = Vector3.new(centre.X, origin.Y, centre.Z) - out * (Config.Table.Radius + 2)
	local figure: HollowManView.Handle? = nil
	local head = feet + Vector3.new(0, 10, 0)
	return Cinema.play({
		length = 13,
		title = Story.Endings.caught.title,
		titleAt = 8,
		camera = shots({
			{ from = 0, to = 4, a = CFrame.lookAt(candle + out * 2.5 + Vector3.new(0, 1.2, 0), candle + Vector3.new(0, 0.6, 0)), b = CFrame.lookAt(candle + out * 1.6 + Vector3.new(0, 0.8, 0), candle + Vector3.new(0, 0.6, 0)) },
			{ from = 4, to = 13, a = CFrame.lookAt(candle + out * 3 + Vector3.new(0, 2, 0), head), b = CFrame.lookAt(candle + out * 1 + Vector3.new(0, 5, 0), head) },
		}),
		lines = endingLines("caught"),
		onFrame = function(t: number)
			if t >= 2.2 and not figure then
				TablePieces.snuff(true)
				Audio.play("flicker", 0.5)
				figure = HollowManView.spawnLocal(CFrame.lookAt(feet, Vector3.new(centre.X, origin.Y, centre.Z)), true, false)
			end
		end,
		onEnd = function()
			TablePieces.snuff(false)
			if figure then
				figure.destroy()
			end
		end,
	})
end

-- Lost: outside in the dark, the cabin's lights go out one window at a time.
local function lost(): boolean
	local origin = Config.ParlorOrigin
	local eye = origin + Vector3.new(14, 7, Config.TileSize / 2 + 36)
	local lights: { Light } = {}
	for _, light in CollectionService:GetTagged("RoomLight") do
		if light:IsA("Light") and light.Enabled then
			table.insert(lights, light)
		end
	end
	local out = 0
	return Cinema.play({
		length = 13,
		title = Story.Endings.lost.title,
		titleAt = 0.8,
		camera = shots({
			{ from = 0, to = 13, a = CFrame.lookAt(eye, origin + Vector3.new(0, 6, 0)), b = CFrame.lookAt(eye + Vector3.new(-6, -2, 8), origin + Vector3.new(0, 7, 0)) },
		}),
		lines = endingLines("lost"),
		onStart = function()
			Audio.play("ending", 0.5)
		end,
		onFrame = function(t: number)
			-- One goes out every half second from two seconds in.
			local want = math.clamp(math.floor((t - 2) / 0.5), 0, #lights)
			while out < want do
				out += 1
				lights[out].Enabled = false
			end
		end,
		onEnd = function()
			for _, light in lights do
				light.Enabled = true
			end
		end,
	})
end

-- Never built: the card box, the next card still sticking out of it.
local function neverBuilt(): boolean
	local tableModel = workspace:FindFirstChild("ParlorTable")
	local box = tableModel and tableModel:FindFirstChild("CardBox", true)
	if not box or not box:IsA("BasePart") then
		return false
	end
	local front = box.CFrame.LookVector -- the box's front (its -Z) faces the player's seat
	local look = box.Position + Vector3.new(0, 0.1, 0)
	return Cinema.play({
		length = 12,
		title = Story.Endings.never_built.title,
		titleAt = 0.8,
		camera = shots({
			{ from = 0, to = 12, a = CFrame.lookAt(box.Position + front * 6 + Vector3.new(0, 2.5, 0), look), b = CFrame.lookAt(box.Position + front * 2.6 + Vector3.new(0, 0.9, 0), look) },
		}),
		lines = endingLines("never_built"),
		onStart = function()
			Audio.play("ending", 0.5)
		end,
	})
end

function Scenes.ending(key: string): boolean
	if key == "escaped" then
		return escaped()
	elseif key == "caught" then
		return caught()
	elseif key == "lost" then
		return lost()
	elseif key == "never_built" then
		return neverBuilt()
	end
	return false
end

return Scenes
