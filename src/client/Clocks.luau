--!strict
-- Every grandfather clock in the cabin (tagged "TickingClock" by RoomProps) ticks: the second
-- hand jumps once a real second with a tick you can hear nearby, the pendulum swings in time,
-- and the hour and minute hands show the time on the Candle, sweeping round when it moves.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))

type Clock = {
	model: Model,
	face: BasePart,
	hands: { [string]: { part: BasePart, rest: CFrame } }, -- rest: relative to the face, at 12
	pendulum: { { part: BasePart, rest: CFrame, pivot: Vector3 } },
	tick: Sound,
}

local Clocks = {}

local TICK_HEARING = 60 -- only clocks this close to the camera play their tick
local clocks: { [Instance]: Clock } = {}
local shownMinutes = Config.Clock.StartMinutes -- eased towards the Candle's time
local targetMinutes = Config.Clock.StartMinutes
local lastSecond = -1

local function add(inst: Instance)
	if not inst:IsA("Model") or clocks[inst] then
		return
	end
	local face = inst:WaitForChild("Face", 5)
	if not face or not face:IsA("BasePart") then
		return
	end
	local clock: Clock = { model = inst, face = face, hands = {}, pendulum = {}, tick = Instance.new("Sound") }
	for _, name in { "HandHour", "HandMinute", "HandSecond" } do
		local hand = inst:FindFirstChild(name)
		if hand and hand:IsA("BasePart") then
			clock.hands[name] = { part = hand, rest = face.CFrame:ToObjectSpace(hand.CFrame) }
		end
	end
	for _, child in inst:GetChildren() do
		local pivot = child:GetAttribute("PivotFromFace")
		if child:IsA("BasePart") and typeof(pivot) == "Vector3" then
			table.insert(clock.pendulum, { part = child, rest = face.CFrame:ToObjectSpace(child.CFrame), pivot = pivot })
		end
	end
	local sound = clock.tick
	sound.Name = "Tick"
	sound.SoundId = Config.Sounds.tick or ""
	sound.Volume = 0.35
	sound.PlaybackSpeed = 0.55
	sound.RollOffMinDistance = 6
	sound.RollOffMaxDistance = 45
	sound.Parent = face
	clocks[inst] = clock
end

local function remove(inst: Instance)
	local clock = clocks[inst]
	if clock then
		clock.tick:Destroy()
		clocks[inst] = nil
	end
end

-- A hand's rotation for an angle clockwise from 12 (radians), seen from the front.
local function handCFrame(clock: Clock, rest: CFrame, angle: number): CFrame
	return clock.face.CFrame * CFrame.Angles(0, 0, angle) * rest
end

function Clocks.setState(state: Types.PublicState)
	local clock = state.clock
	local step = if clock and state.phase ~= "Lobby" then clock.candle else 0
	local minutes = Config.Clock.StartMinutes + step * Config.Clock.StepMinutes
	if minutes < targetMinutes then
		shownMinutes = minutes -- a new run
	end
	targetMinutes = minutes
end

function Clocks.init()
	for _, inst in CollectionService:GetTagged("TickingClock") do
		task.spawn(add, inst)
	end
	CollectionService:GetInstanceAddedSignal("TickingClock"):Connect(function(inst: Instance)
		task.spawn(add, inst)
	end)
	CollectionService:GetInstanceRemovedSignal("TickingClock"):Connect(remove)

	RunService.RenderStepped:Connect(function(dt: number)
		-- When the Candle moves, the hands sweep round to the new time over a couple of seconds.
		shownMinutes += (targetMinutes - shownMinutes) * math.min(1, dt * 1.6)
		if math.abs(targetMinutes - shownMinutes) < 0.05 then
			shownMinutes = targetMinutes
		end
		local now = os.clock()
		local second = math.floor(now)
		local sinceTick = now - second
		local ticked = second ~= lastSecond
		lastSecond = second
		-- The second hand jumps, overshoots a hair and settles.
		local secondAngle = ((second % 60) + math.max(0, 0.08 - sinceTick) * -1.5) * math.pi / 30
		local minuteAngle = (shownMinutes % 60) / 60 * math.pi * 2
		local hourAngle = ((shownMinutes / 60) % 12) / 12 * math.pi * 2
		-- One swing a second, crossing the middle on each tick.
		local swing = math.sin((now - 0.5) * math.pi) * 0.16
		local camera = workspace.CurrentCamera
		for _, clock in clocks do
			if not clock.face.Parent then
				continue
			end
			local hands = clock.hands
			if hands.HandHour then
				hands.HandHour.part.CFrame = handCFrame(clock, hands.HandHour.rest, hourAngle)
			end
			if hands.HandMinute then
				hands.HandMinute.part.CFrame = handCFrame(clock, hands.HandMinute.rest, minuteAngle)
			end
			if hands.HandSecond then
				hands.HandSecond.part.CFrame = handCFrame(clock, hands.HandSecond.rest, secondAngle)
			end
			for _, piece in clock.pendulum do
				local pivot = clock.face.CFrame * CFrame.new(piece.pivot)
				local offset = CFrame.new(piece.pivot):Inverse() * piece.rest
				piece.part.CFrame = pivot * CFrame.Angles(0, 0, swing) * offset
			end
			if ticked and camera and (camera.CFrame.Position - clock.face.Position).Magnitude < TICK_HEARING then
				clock.tick:Play()
			end
		end
	end)
end

return Clocks
