--!strict
-- When a room is placed it rises into place on every screen: its pieces come up out of the
-- ground and fade in, the floor first and the roof last. Purely cosmetic and local; every part
-- ends exactly where the server built it. (The Parlor at (0,0) is rebuilt each run with people
-- standing in it, so it doesn't rise.)

local TweenService = game:GetService("TweenService")

local RoomRise = {}

local DROP = 14 -- studs below where each piece ends up
local SECONDS = 0.7
local SPREAD = 1.1 -- the last piece starts this much later than the first

local function rise(room: Instance)
	if not room:IsA("Model") or string.find(room.Name, "(0,0)", 1, true) then
		return
	end
	-- Give the server a moment to finish filling the model.
	task.wait()
	local parts: { BasePart } = {}
	local low, high = math.huge, -math.huge
	for _, inst in room:GetDescendants() do
		if inst:IsA("BasePart") then
			table.insert(parts, inst)
			low = math.min(low, inst.Position.Y)
			high = math.max(high, inst.Position.Y)
		end
	end
	local span = math.max(high - low, 1)
	for _, p in parts do
		local final = p.CFrame
		local transparency = p.Transparency
		local delay = (p.Position.Y - low) / span * SPREAD + math.random() * 0.15
		p.CFrame = final - Vector3.new(0, DROP, 0)
		if transparency < 1 then
			p.LocalTransparencyModifier = 1
		end
		task.delay(delay, function()
			if not p.Parent then
				return
			end
			TweenService:Create(p, TweenInfo.new(SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = final }):Play()
			TweenService:Create(p, TweenInfo.new(SECONDS * 0.6), { LocalTransparencyModifier = 0 }):Play()
		end)
	end
end

function RoomRise.init()
	task.spawn(function()
		local cabin = workspace:WaitForChild("Cabin")
		cabin.ChildAdded:Connect(function(room: Instance)
			task.spawn(rise, room)
		end)
	end)
end

return RoomRise
