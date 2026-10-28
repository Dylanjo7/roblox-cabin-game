--!strict
-- The cutscenes, played with Cinema:
--   intro: when the front door slams. The door; the fire and the table with its carved rim; out
--     through a window, him among the pines; the grandfather clock ticking.
--   enters: the first time he comes onto the clock. His piece steps onto nine on the table, then
--     out through a window, he walks out of the trees towards the cabin.
--   midnight: his piece reaches midnight, and he's at the window, much closer, watching.
--   ending: escaped (dawn on the road by the truck), caught (the Candle goes out and he leans
--     over the table), lost (the cabin's lights go out one by one), never built (the card box).
-- Each returns false if it couldn't play, so the caller shows the plain text version instead.
-- The mid-game ones only play while the table is waiting on him (the Clock stage).

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Story = require(Shared:WaitForChild("Story"))

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

------------------------------------------------------------------------------------------------

local function endingLines(key: string): { Cinema.Line }
	local ending = Story.Endings[key]
	local lines = {}
	for i, text in ending.lines do
		table.insert(lines, { at = 3 + (i - 1) * 4.4, line = text, voice = `ending_{key}_{i}` })
	end
	return lines
end

-- Escaped: dawn coming up over the road by the truck.
local function escaped(): boolean
	local outside = workspace:FindFirstChild("Outside")
	local truck = outside and outside:FindFirstChild("Truck")
	local at = if truck and truck:IsA("Model") then truck:GetPivot() else CFrame.new(0, 0, 80)
	local saved = { ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness, FogColor = Lighting.FogColor, FogEnd = Lighting.FogEnd, OutdoorAmbient = Lighting.OutdoorAmbient }
	local road = (at * CFrame.new(0, 2, 40)).Position -- behind the truck, the way back out
	return Cinema.play({
		length = 16,
		title = Story.Endings.escaped.title,
		titleAt = 0.8,
		camera = shots({
			{ from = 0, to = 16, a = CFrame.lookAt((at * CFrame.new(-7, 3, -10)).Position, road), b = CFrame.lookAt((at * CFrame.new(-4, 2.2, 4)).Position, road) },
		}),
		lines = endingLines("escaped"),
		onStart = function()
			Audio.play("ending", 0.5)
			local info = TweenInfo.new(14, Enum.EasingStyle.Sine)
			TweenService:Create(Lighting, info, { ClockTime = 6.2, Brightness = 1.8, FogColor = Color3.fromRGB(190, 176, 168), FogEnd = 400, OutdoorAmbient = Color3.fromRGB(120, 112, 118) }):Play()
		end,
		onEnd = function()
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
