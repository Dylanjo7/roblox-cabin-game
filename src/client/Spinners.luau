--!strict
-- Things waiting to be found in an event (tag "EventSpin": the key, the fuse) bob gently and
-- turn where they float, drawn here on each client so it's smooth. The server removes the tag
-- when someone picks one up. Records on a turntable (tag "EventTurn") go round in place while
-- their Playing attribute is true. The Rocking Chair clue (tag "RockingChair") rocks on its
-- runners, about its pivot, with nobody in it.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Spinners = {}

local RECORD_SPEED = 3.5 -- radians a second: about 33 rpm
local ROCK_ANGLE = math.rad(9)
local ROCK_SPEED = 2.2 -- radians a second of its swing: one rock about every 3 seconds

local spinning: { [Instance]: CFrame } = {} -- each one's resting pivot
local turning: { [Instance]: { rest: CFrame, angle: number } } = {}
local rocking: { [Instance]: { rest: CFrame, phase: number } } = {}

local function add(inst: Instance)
	if inst:IsA("PVInstance") then
		spinning[inst] = inst:GetPivot()
	end
end

local function addTurn(inst: Instance)
	if inst:IsA("PVInstance") then
		turning[inst] = { rest = inst:GetPivot(), angle = 0 }
	end
end

local function addRock(inst: Instance)
	if inst:IsA("PVInstance") then
		rocking[inst] = { rest = inst:GetPivot(), phase = math.random() * math.pi * 2 }
	end
end

function Spinners.init()
	for _, inst in CollectionService:GetTagged("EventSpin") do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal("EventSpin"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("EventSpin"):Connect(function(inst: Instance)
		spinning[inst] = nil
	end)
	for _, inst in CollectionService:GetTagged("EventTurn") do
		addTurn(inst)
	end
	CollectionService:GetInstanceAddedSignal("EventTurn"):Connect(addTurn)
	CollectionService:GetInstanceRemovedSignal("EventTurn"):Connect(function(inst: Instance)
		turning[inst] = nil
	end)
	for _, inst in CollectionService:GetTagged("RockingChair") do
		addRock(inst)
	end
	CollectionService:GetInstanceAddedSignal("RockingChair"):Connect(addRock)
	CollectionService:GetInstanceRemovedSignal("RockingChair"):Connect(function(inst: Instance)
		rocking[inst] = nil
	end)
	RunService.RenderStepped:Connect(function(dt: number)
		local t = os.clock()
		for inst, rest in spinning do
			if not inst.Parent then
				spinning[inst] = nil
				continue
			end
			-- Turning about straight up, whichever way the thing itself is lying.
			local at = rest.Position + Vector3.new(0, math.sin(t * 2) * 0.15, 0)
			;(inst :: PVInstance):PivotTo(CFrame.new(at) * CFrame.Angles(0, t * 1.3, 0) * rest.Rotation)
		end
		for inst, turn in turning do
			if not inst.Parent then
				turning[inst] = nil
				continue
			end
			if inst:GetAttribute("Playing") then
				turn.angle += dt * RECORD_SPEED
				;(inst :: PVInstance):PivotTo(CFrame.new(turn.rest.Position) * CFrame.Angles(0, -turn.angle, 0) * turn.rest.Rotation)
			end
		end
		for inst, rock in rocking do
			if not inst.Parent then
				rocking[inst] = nil
				continue
			end
			;(inst :: PVInstance):PivotTo(rock.rest * CFrame.Angles(math.sin(t * ROCK_SPEED + rock.phase) * ROCK_ANGLE, 0, 0))
		end
	end)
end

return Spinners
