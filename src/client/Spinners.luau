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

-- Where a model rests, once it's really here. A client can be told about a model before its
-- parts arrive (with streaming on, parts load by distance); reading its pivot then gives the
-- world origin, the middle of the Parlor, and the key and fuse were being dragged there, under
-- the table, every frame. So: wait until its main part is in.
local function whenReady(inst: Instance, use: (CFrame) -> ())
	if not inst:IsA("PVInstance") then
		return
	end
	task.spawn(function()
		local model = if inst:IsA("Model") then inst else nil
		local deadline = os.clock() + 30
		while model and not model.PrimaryPart and inst.Parent and os.clock() < deadline do
			task.wait(0.1)
		end
		if inst.Parent and (not model or model.PrimaryPart) then
			use((inst :: PVInstance):GetPivot())
		end
	end)
end

local function add(inst: Instance)
	whenReady(inst, function(rest: CFrame)
		if CollectionService:HasTag(inst, "EventSpin") then
			spinning[inst] = rest
		end
	end)
end

local function addTurn(inst: Instance)
	whenReady(inst, function(rest: CFrame)
		turning[inst] = { rest = rest, angle = 0 }
	end)
end

local function addRock(inst: Instance)
	whenReady(inst, function(rest: CFrame)
		rocking[inst] = { rest = rest, phase = math.random() * math.pi * 2 }
	end)
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
