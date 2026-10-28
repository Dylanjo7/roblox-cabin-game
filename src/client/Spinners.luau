--!strict
-- Things waiting to be found in an event (tag "EventSpin": the key, the fuse) bob gently and
-- turn where they float, drawn here on each client so it's smooth. The server removes the tag
-- when someone picks one up.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Spinners = {}

local spinning: { [Instance]: CFrame } = {} -- each one's resting pivot

local function add(inst: Instance)
	if inst:IsA("PVInstance") then
		spinning[inst] = inst:GetPivot()
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
	RunService.RenderStepped:Connect(function()
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
	end)
end

return Spinners
