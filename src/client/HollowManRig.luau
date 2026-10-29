--!strict
-- Animates a client-side Hollow Man figure: a stiff, loping walk with knees and elbows, the
-- coat strips trailing and swaying, slow breathing, a head that twitches and snaps round (or
-- follows you), arms reaching forward when he's chasing, his kill (hunched right over whoever
-- he's caught, arms clutching, jaw wide, shaking), and embers that flicker in his eyes.
-- All parts are anchored and posed every frame from their rest CFrames (no Humanoid).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HollowManModel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HollowManModel"))

export type Rig = {
	model: Model,
	scale: number,
	parts: { BasePart },
	limbs: { string },
	rest: { CFrame },
	embers: { BasePart },
	joints: { [string]: Vector3 }, -- scaled joint positions
	phase: number, -- walk cycle
	stride: number, -- 0 standing .. 1 walking .. more when running
	chase: number, -- 0..1, eased
	kill: number, -- 0..1, eased: he's got someone
	t: number,
	headYaw: number,
	headRoll: number,
	twitchYaw: number,
	twitchRoll: number,
	nextTwitch: number,
}

local HollowManRig = {}

local WALK_SPEED = 9 -- studs per second that counts as a full stride
local rng = Random.new()

-- Build a figure (scaled about his feet) and get it ready to pose. Parent rig.model yourself.
function HollowManRig.new(scale: number?): Rig
	local s = scale or 1
	local model = HollowManModel.build()
	if s ~= 1 then
		model:ScaleTo(s)
	end
	local rig: Rig = {
		model = model,
		scale = s,
		parts = {},
		limbs = {},
		rest = {},
		embers = {},
		joints = {},
		phase = rng:NextNumber(0, math.pi * 2),
		stride = 0,
		chase = 0,
		kill = 0,
		t = rng:NextNumber(0, 10),
		headYaw = 0,
		headRoll = 0,
		twitchYaw = 0,
		twitchRoll = 0,
		nextTwitch = 1,
	}
	for name, joint in HollowManModel.Joints do
		rig.joints[name] = joint.at * s
	end
	for _, inst in model:GetDescendants() do
		if inst:IsA("BasePart") then
			table.insert(rig.parts, inst)
			table.insert(rig.limbs, (inst:GetAttribute("Limb") :: string?) or "Root")
			table.insert(rig.rest, inst.CFrame) -- the model was built at the origin
			if inst.Name == "Ember" then
				table.insert(rig.embers, inst)
			end
		end
	end
	return rig
end

local function around(at: Vector3, rotation: CFrame): CFrame
	return CFrame.new(at) * rotation * CFrame.new(-at)
end

-- Pose the figure at `pivot` (his feet, facing -Z). speed: studs per second he's moving at.
-- chasing: he has seen someone. lookAt: a world point his head turns towards (nil = he twitches).
-- killing: he has caught someone and is over them.
function HollowManRig.pose(rig: Rig, pivot: CFrame, dt: number, speed: number, chasing: boolean, lookAt: Vector3?, killing: boolean?)
	rig.t += dt
	local t = rig.t
	local targetStride = math.clamp(speed / WALK_SPEED, 0, 1.4)
	rig.stride += (targetStride - rig.stride) * math.min(1, dt * 6)
	rig.chase += ((if chasing then 1 else 0) - rig.chase) * math.min(1, dt * 4)
	rig.kill += ((if killing then 1 else 0) - rig.kill) * math.min(1, dt * (if killing then 9 else 2))
	local s, c, k = rig.stride, rig.chase, rig.kill
	local shake = math.sin(t * 23) * k -- the clutching tremor
	-- Long legs: a slow cadence that quickens when he runs.
	rig.phase += dt * (1.2 + speed * 0.55)
	local p = rig.phase
	local swing = math.sin(p)

	-- Head: either follows the point, or holds still and then snaps somewhere new.
	if lookAt then
		local localTarget = pivot:PointToObjectSpace(lookAt)
		local yaw = math.atan2(-localTarget.X, -localTarget.Z)
		rig.twitchYaw = math.clamp(yaw, -1.1, 1.1)
		rig.twitchRoll = math.sin(t * 0.7) * 0.12
	elseif t >= rig.nextTwitch then
		rig.nextTwitch = t + rng:NextNumber(0.8, 3.5)
		rig.twitchYaw = rng:NextNumber(-0.6, 0.6)
		rig.twitchRoll = if rng:NextNumber() < 0.3 then rng:NextNumber(-0.5, 0.5) else rng:NextNumber(-0.12, 0.12)
	end
	local snap = math.min(1, dt * (if lookAt then 5 else 16)) -- twitches are fast and jerky
	rig.headYaw += (rig.twitchYaw - rig.headYaw) * snap
	rig.headRoll += (rig.twitchRoll - rig.headRoll) * snap

	local breathe = math.sin(t * 1.4)
	local bob = ((1 - math.abs(swing)) * 0.3 * s + breathe * 0.04) * rig.scale
	local j = rig.joints

	local rot: { [string]: CFrame } = {
		Body = CFrame.Angles(-(0.05 + 0.1 * s + 0.32 * c * (1 - k) + 0.62 * k) + breathe * 0.015, swing * 0.1 * s, shake * 0.02),
		LegL = CFrame.Angles(swing * 0.55 * s, 0, 0),
		LegR = CFrame.Angles(-swing * 0.55 * s, 0, 0),
		ShinL = CFrame.Angles(-math.max(0, math.cos(p)) * 0.95 * s, 0, 0),
		ShinR = CFrame.Angles(-math.max(0, -math.cos(p)) * 0.95 * s, 0, 0),
		ArmL = CFrame.Angles(-swing * 0.4 * s + c * 1.15 * (1 - k) + k * 1.45 + shake * 0.06 + math.sin(t * 0.9) * 0.04, 0, -(0.04 + c * 0.18) + k * 0.32),
		ArmR = CFrame.Angles(swing * 0.4 * s + c * 1.15 * (1 - k) + k * 1.45 - shake * 0.06 + math.sin(t * 0.9 + 1) * 0.04, 0, 0.04 + c * 0.18 - k * 0.32),
		ForeL = CFrame.Angles(0.15 + 0.2 * s + c * 0.35 + k * 0.75, 0, 0),
		ForeR = CFrame.Angles(0.15 + 0.2 * s + c * 0.35 + k * 0.75, 0, 0),
		Neck = CFrame.Angles(-0.1 * c - 0.4 * k + breathe * 0.03, rig.headYaw * (1 - k), rig.headRoll * (1 - k) + shake * 0.12),
		-- His jaw hangs slack, working slowly; it gapes when he's after you, and wide on a kill.
		Jaw = CFrame.Angles(-(0.12 + c * 0.45 + k * 0.5 + (math.sin(t * 0.8) * 0.5 + 0.5) * 0.08), 0, math.sin(t * 0.5) * 0.04),
	}

	local xf: { [string]: CFrame } = { Root = CFrame.new(0, bob, 0) }
	for i, name in HollowManModel.JointOrder do
		local joint = HollowManModel.Joints[name]
		local parent = xf[joint.parent or "Root"]
		local r = rot[name]
		if not r then
			-- Coat strips trail behind as he walks and sway on their own.
			r = CFrame.Angles(-0.28 * s - 0.15 * c + math.sin(t * 3.1 + i) * 0.06, 0, math.sin(t * 2.3 + i * 1.7) * 0.05)
		end
		xf[name] = parent * around(j[name], r)
	end

	local cframes = table.create(#rig.parts)
	for i, part in rig.parts do
		cframes[i] = pivot * xf[rig.limbs[i]] * rig.rest[i]
	end
	workspace:BulkMoveTo(rig.parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)

	for _, ember in rig.embers do
		ember.Transparency = 0.05 + math.abs(math.noise(t * 4, ember.Position.X)) * 0.6
	end
end

return HollowManRig
