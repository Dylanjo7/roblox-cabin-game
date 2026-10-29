--!strict
-- Small things in the cabin that move by themselves, drawn on each client (the server never
-- moves them):
--   Hanging lamps (tag "HangingLamp") sway a little on their chains, and swing hard for a moment
--     each time the Hollow Man takes a step on the clock, as if the whole house shuddered (and a
--     little with the thunder; see Storm).
--   The Doll (tag "WatchingDoll") sits facing its corner. Stay in the room without looking at it
--     and its head turns right round to watch you; look back and it's already staring. Leave the
--     room for a while and it faces the corner again.
--   The Music Box's dancer (tag "Twirl") turns slowly on her spindle.
--   Fire and flame: the hearth's light (tag "Firelight") dances, and every lantern's flame (tag
--     "LanternFlame") gutters.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TablePieces = require(script.Parent.TablePieces)

local Haunting = {}

local LAMP_SWAY = math.rad(1.2) -- the swing they always have
local LAMP_JOLT = math.rad(7) -- extra, right after one of his steps
local LAMP_SETTLE = 3 -- seconds a new lamp waits (its room rises into place first)
local DOLL_NOTICE = 4 -- seconds unwatched (close by) before the doll's head turns
local DOLL_FORGET = 6 -- seconds away from it before it faces the corner again
local DOLL_RANGE = 40
local TWIRL_SPEED = 1.1

type Lamp = { parts: { BasePart }, rel: { CFrame }, hang: CFrame?, phase: number, from: number }
type Doll = { rest: { [BasePart]: CFrame }, turned: boolean, unseen: number, away: number }

local lamps: { [Instance]: Lamp } = {}
local dolls: { [Instance]: Doll } = {}
local twirls: { [Instance]: CFrame } = {}
local fires: { [Instance]: { base: number, seed: number } } = {} -- lights, by their resting brightness
local jolt = 0

local HEAD_PIECES: { [string]: boolean } = { Head = true, Hair = true, Eye = true, Mouth = true }

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function addLamp(inst: Instance)
	if inst:IsA("Model") then
		lamps[inst] = { parts = {}, rel = {}, hang = nil, phase = math.random() * math.pi * 2, from = os.clock() + LAMP_SETTLE }
	end
end

-- Where a lamp hangs from (the top of its chain), and where each piece sits from there.
local function settle(model: Instance, lamp: Lamp): boolean
	local chain: BasePart? = nil
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and string.find(child.Name, "Chain", 1, true) then
			chain = child
		end
	end
	if not chain then
		return false
	end
	local hang = CFrame.new(chain.Position + Vector3.new(0, chain.Size.Y / 2, 0))
	lamp.hang = hang
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") then
			table.insert(lamp.parts, child)
			table.insert(lamp.rel, hang:ToObjectSpace(child.CFrame))
		end
	end
	return true
end

local function updateLamps(t: number, dt: number)
	jolt = math.max(0, jolt - dt * (0.5 + jolt))
	local amount = LAMP_SWAY + LAMP_JOLT * jolt
	for inst, lamp in lamps do
		if not inst.Parent then
			lamps[inst] = nil
			continue
		end
		if t < lamp.from then
			continue
		end
		if not lamp.hang and not settle(inst, lamp) then
			lamps[inst] = nil
			continue
		end
		local swing = (lamp.hang :: CFrame) * CFrame.Angles(math.sin(t * 1.3 + lamp.phase) * amount, 0, math.sin(t * 0.9 + lamp.phase * 1.7) * amount * 0.7)
		local cframes = table.create(#lamp.parts)
		for i, rel in lamp.rel do
			cframes[i] = swing * rel
		end
		workspace:BulkMoveTo(lamp.parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- Turn the doll's head (every piece of it) about straight up through its middle: by `yaw`
-- radians from where it rests, or back to rest.
local function turnHead(doll: Doll, head: BasePart, yaw: number?)
	local rest = doll.rest[head]
	if not rest then
		return
	end
	local centre = rest.Position
	local turn = if yaw then CFrame.new(centre) * CFrame.Angles(0, yaw, 0) * CFrame.new(-centre) else CFrame.new()
	for part, cf in doll.rest do
		if part.Parent then
			part.CFrame = turn * cf
		else
			doll.rest[part] = nil
		end
	end
end

local function updateDolls(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame
	for inst, doll in dolls do
		if not inst.Parent then
			dolls[inst] = nil
			continue
		end
		local head = inst:FindFirstChild("Head")
		if not head or not head:IsA("BasePart") then
			continue
		end
		-- Pieces it hasn't seen yet are where the server put them (at rest). (A decoy's mouth is
		-- redone when it's found out.)
		for _, child in inst:GetChildren() do
			if child:IsA("BasePart") and HEAD_PIECES[child.Name] and not doll.rest[child] then
				doll.rest[child] = child.CFrame
				if doll.turned then
					doll.turned = false -- put the new piece and the rest back together
					turnHead(doll, head, nil)
				end
			end
		end
		local rest = doll.rest[head]
		if not rest then
			continue
		end
		local to = rest.Position - eye.Position
		local close = to.Magnitude < DOLL_RANGE
		local looking = close and eye.LookVector:Dot(to.Unit) > 0.5
		if close then
			doll.away = 0
			doll.unseen = if looking then 0 else doll.unseen + dt
			if not doll.turned and doll.unseen >= DOLL_NOTICE then
				-- While you're not looking: its face turns to you.
				local face = flat(rest.LookVector)
				local you = flat(eye.Position - rest.Position)
				if face.Magnitude > 0.01 and you.Magnitude > 0.01 then
					local a, b = face.Unit, you.Unit
					doll.turned = true
					turnHead(doll, head, math.atan2(a.Z * b.X - a.X * b.Z, a.X * b.X + a.Z * b.Z))
				end
			end
		else
			doll.unseen = 0
			doll.away += dt
			if doll.turned and doll.away >= DOLL_FORGET then
				doll.turned = false
				turnHead(doll, head, nil)
			end
		end
	end
end

-- The house shudders: every hanging lamp swings, `amount` (0-1) as hard as at one of his steps.
function Haunting.shudder(amount: number)
	jolt = math.max(jolt, amount)
end

local function watch(tag: string, onAdd: (Instance) -> (), onRemove: (Instance) -> ())
	for _, inst in CollectionService:GetTagged(tag) do
		onAdd(inst)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(onAdd)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(onRemove)
end

function Haunting.init()
	watch("HangingLamp", addLamp, function(inst: Instance)
		lamps[inst] = nil
	end)
	watch("WatchingDoll", function(inst: Instance)
		dolls[inst] = { rest = {}, turned = false, unseen = 0, away = 0 }
	end, function(inst: Instance)
		dolls[inst] = nil
	end)
	watch("Twirl", function(inst: Instance)
		if inst:IsA("BasePart") then
			twirls[inst] = inst.CFrame
		end
	end, function(inst: Instance)
		twirls[inst] = nil
	end)
	local function addFire(light: Instance?)
		if light and light:IsA("Light") and not fires[light] then
			fires[light] = { base = light.Brightness, seed = math.random() * 100 }
		end
	end
	watch("Firelight", addFire, function(inst: Instance)
		fires[inst] = nil
	end)
	watch("LanternFlame", function(inst: Instance)
		addFire(inst:FindFirstChild("Glow"))
	end, function(inst: Instance)
		local glow = inst:FindFirstChild("Glow")
		if glow then
			fires[glow] = nil
		end
	end)
	TablePieces.HollowStepped:Connect(function()
		jolt = 1
	end)
	RunService.RenderStepped:Connect(function(dt: number)
		local t = os.clock()
		updateLamps(t, dt)
		updateDolls(dt)
		for inst, fire in fires do
			local light = inst :: Light
			if light.Parent then
				light.Brightness = fire.base * (0.78 + 0.44 * (math.noise(t * 3.1, fire.seed) * 0.5 + 0.5))
			else
				fires[inst] = nil
			end
		end
		for inst, rest in twirls do
			local part = inst :: BasePart
			if part.Parent then
				part.CFrame = CFrame.new(rest.Position) * CFrame.Angles(0, t * TWIRL_SPEED, 0) * rest.Rotation
			else
				twirls[inst] = nil
			end
		end
	end)
end

return Haunting
