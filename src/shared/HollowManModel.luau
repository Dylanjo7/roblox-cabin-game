--!strict
-- Builds the Hollow Man from parts: a very tall, gaunt figure in a long tattered coat, with
-- arms that hang past his knees and a narrow ash-grey head with two hollow eye sockets and a
-- faint ember deep inside each. Original design. The pivot is at his feet and he faces -Z.
--
-- Every part carries a "Limb" attribute naming the joint it hangs from (see HollowManModel.Joints),
-- so the client rig (src/client/HollowManRig) can walk him. The server never moves the full model:
-- it moves an invisible marker (HollowManModel.marker) and each client draws and animates him there.

local CollectionService = game:GetService("CollectionService")

local COAT = Color3.fromRGB(16, 15, 17)
local COAT_EDGE = Color3.fromRGB(26, 24, 26)
local SKIN = Color3.fromRGB(118, 114, 108)
local SKIN_DARK = Color3.fromRGB(88, 84, 80)
local HOLLOW = Color3.fromRGB(4, 4, 5)
local EMBER = Color3.fromRGB(150, 30, 16)

export type Joint = { parent: string?, at: Vector3 } -- at: joint position in model space (unscaled)

local HollowManModel = {}

-- The tag on the server's invisible marker part.
HollowManModel.Tag = "HollowMan"

local HIP_Y = 5.4
local KNEE_Y = 2.7

local function shoulderAt(side: number): Vector3
	return Vector3.new(side * 1.45, 8, -0.1)
end

-- The upper arm hangs from the shoulder, angled slightly forward and out.
local function upperArmCFrame(side: number): CFrame
	return CFrame.new(shoulderAt(side)) * CFrame.Angles(math.rad(-8), 0, math.rad(side * 4)) * CFrame.new(0, -1.6, 0)
end

local function elbowCFrame(side: number): CFrame
	return upperArmCFrame(side) * CFrame.new(0, -1.6, 0)
end

-- Joints, parents first. Coat strips are added below.
local Joints: { [string]: Joint } = {
	Body = { parent = nil, at = Vector3.new(0, HIP_Y - 0.4, 0) },
	LegL = { parent = nil, at = Vector3.new(-0.5, HIP_Y, 0) },
	LegR = { parent = nil, at = Vector3.new(0.5, HIP_Y, 0) },
	ShinL = { parent = "LegL", at = Vector3.new(-0.5, KNEE_Y, 0) },
	ShinR = { parent = "LegR", at = Vector3.new(0.5, KNEE_Y, 0) },
	ArmL = { parent = "Body", at = shoulderAt(-1) },
	ArmR = { parent = "Body", at = shoulderAt(1) },
	ForeL = { parent = "ArmL", at = elbowCFrame(-1).Position },
	ForeR = { parent = "ArmR", at = elbowCFrame(1).Position },
	Neck = { parent = "Body", at = Vector3.new(0, 8.4, -0.3) },
}
local Order = { "Body", "LegL", "LegR", "ShinL", "ShinR", "ArmL", "ArmR", "ForeL", "ForeR", "Neck" }

-- The coat hangs in ragged strips of different lengths, front and back, each swinging on its own.
local STRIPS = { { -0.95, 3.0 }, { -0.5, 2.3 }, { 0, 3.3 }, { 0.5, 2.6 }, { 0.95, 2.9 } }
for i, s in STRIPS do
	for _, side in { "Front", "Back" } do
		local name = `Coat{side}{i}`
		Joints[name] = { parent = "Body", at = Vector3.new(s[1], 5, if side == "Front" then -0.55 else 0.55) }
		table.insert(Order, name)
	end
end

HollowManModel.Joints = Joints
HollowManModel.JointOrder = Order

local function part(model: Model, limb: string, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p:SetAttribute("Limb", limb)
	p.Parent = model
	return p
end

local function arm(model: Model, side: number)
	local upperLimb = if side < 0 then "ArmL" else "ArmR"
	local foreLimb = if side < 0 then "ForeL" else "ForeR"
	part(model, upperLimb, "UpperArm", Vector3.new(0.42, 3.2, 0.42), upperArmCFrame(side), COAT, Enum.Material.Fabric)
	-- A torn cuff where the coat sleeve ends.
	part(model, upperLimb, "Cuff", Vector3.new(0.52, 0.35, 0.52), upperArmCFrame(side) * CFrame.new(0, -1.45, 0) * CFrame.Angles(0, 0, math.rad(side * 6)), COAT_EDGE, Enum.Material.Fabric)
	local elbow = elbowCFrame(side)
	part(model, foreLimb, "Elbow", Vector3.new(0.4, 0.4, 0.4), elbow, SKIN_DARK, Enum.Material.SmoothPlastic).Shape = Enum.PartType.Ball
	local fore = elbow * CFrame.Angles(math.rad(-14), 0, 0) * CFrame.new(0, -1.6, 0)
	part(model, foreLimb, "Forearm", Vector3.new(0.3, 3.2, 0.3), fore, SKIN, Enum.Material.SmoothPlastic)
	local wrist = fore * CFrame.new(0, -1.6, 0)
	part(model, foreLimb, "Hand", Vector3.new(0.5, 0.65, 0.22), wrist * CFrame.new(0, -0.32, 0), SKIN, Enum.Material.SmoothPlastic)
	-- Long two-jointed fingers, curling in.
	for i, x in { -0.19, -0.06, 0.07, 0.2 } do
		local length = if i == 2 or i == 3 then 0.95 else 0.8
		local base = wrist * CFrame.new(x, -0.62, 0) * CFrame.Angles(math.rad(-8), 0, math.rad((x) * -20))
		part(model, foreLimb, "Finger", Vector3.new(0.07, length, 0.07), base * CFrame.new(0, -length / 2, 0), SKIN, Enum.Material.SmoothPlastic)
		local tip = base * CFrame.new(0, -length, 0) * CFrame.Angles(math.rad(-28), 0, 0)
		part(model, foreLimb, "FingerTip", Vector3.new(0.06, length * 0.8, 0.06), tip * CFrame.new(0, -length * 0.4, 0), SKIN_DARK, Enum.Material.SmoothPlastic)
	end
end

function HollowManModel.build(): Model
	local model = Instance.new("Model")
	model.Name = "HollowMan"

	local root = part(model, "Root", "Root", Vector3.new(1, 0.2, 1), CFrame.new(0, 0.1, 0), COAT, Enum.Material.Fabric)
	root.Transparency = 1
	model.PrimaryPart = root

	-- Legs: long and thin, with knobbly knees.
	for _, side in { -1, 1 } do
		local x = side * 0.5
		local leg = if side < 0 then "LegL" else "LegR"
		local shin = if side < 0 then "ShinL" else "ShinR"
		part(model, leg, "Thigh", Vector3.new(0.48, HIP_Y - KNEE_Y, 0.48), CFrame.new(x, (HIP_Y + KNEE_Y) / 2, 0), COAT, Enum.Material.Fabric)
		part(model, shin, "Knee", Vector3.new(0.5, 0.5, 0.5), CFrame.new(x, KNEE_Y, -0.05), COAT_EDGE, Enum.Material.Fabric).Shape = Enum.PartType.Ball
		part(model, shin, "Shin", Vector3.new(0.4, KNEE_Y, 0.4), CFrame.new(x, KNEE_Y / 2, 0), COAT, Enum.Material.Fabric)
		part(model, shin, "Foot", Vector3.new(0.5, 0.25, 1.2), CFrame.new(x, 0.13, -0.28), HOLLOW, Enum.Material.SmoothPlastic)
	end

	-- Torso, a hunched shoulder line, a high ragged collar and the knobs of his spine.
	part(model, "Body", "Torso", Vector3.new(2, 3.2, 1), CFrame.new(0, 6.5, 0) * CFrame.Angles(math.rad(-6), 0, 0), COAT, Enum.Material.Fabric)
	part(model, "Body", "Shoulders", Vector3.new(3, 0.5, 1.05), CFrame.new(0, 8.05, -0.15) * CFrame.Angles(math.rad(-10), 0, 0), COAT, Enum.Material.Fabric)
	for i, x in { -0.7, -0.25, 0.25, 0.7 } do
		part(model, "Body", "Collar", Vector3.new(0.4, 0.9 + (i % 2) * 0.3, 0.12), CFrame.new(x, 8.6, 0.25) * CFrame.Angles(math.rad(14), 0, math.rad(x * -18)), COAT_EDGE, Enum.Material.Fabric)
	end
	for i = 0, 3 do
		part(model, "Body", "Spine", Vector3.new(0.22, 0.22, 0.22), CFrame.new(0, 7.9 - i * 0.6, 0.55 + i * 0.03), SKIN_DARK, Enum.Material.SmoothPlastic).Shape = Enum.PartType.Ball
	end

	for i, s in STRIPS do
		local x, length = s[1], s[2]
		part(model, `CoatFront{i}`, "CoatFront", Vector3.new(0.48, length, 0.12), CFrame.new(x, 5 - length / 2, -0.55), COAT_EDGE, Enum.Material.Fabric)
		part(model, `CoatBack{i}`, "CoatBack", Vector3.new(0.48, length + 0.4, 0.12), CFrame.new(x, 5 - (length + 0.4) / 2, 0.55), COAT, Enum.Material.Fabric)
	end

	arm(model, -1)
	arm(model, 1)

	-- Neck and head, tipped forward as if looking down at you.
	local neck = CFrame.new(0, 8.7, -0.35) * CFrame.Angles(math.rad(-20), 0, 0)
	part(model, "Neck", "Neck", Vector3.new(0.32, 1, 0.32), neck, SKIN, Enum.Material.SmoothPlastic)
	local head = neck * CFrame.new(0, 1.3, -0.15) * CFrame.Angles(math.rad(-6), 0, 0)
	part(model, "Neck", "Head", Vector3.new(1.1, 1.9, 1.1), head, SKIN, Enum.Material.SmoothPlastic)
	part(model, "Neck", "Brow", Vector3.new(1.15, 0.25, 0.3), head * CFrame.new(0, 0.3, -0.45), SKIN_DARK, Enum.Material.SmoothPlastic)
	part(model, "Neck", "Cheeks", Vector3.new(1.0, 0.5, 0.2), head * CFrame.new(0, -0.3, -0.46), SKIN_DARK, Enum.Material.SmoothPlastic)
	for _, x in { -0.25, 0.25 } do
		part(model, "Neck", "EyeSocket", Vector3.new(0.3, 0.42, 0.08), head * CFrame.new(x, 0.05, -0.53), HOLLOW, Enum.Material.SmoothPlastic)
		local ember = part(model, "Neck", "Ember", Vector3.new(0.08, 0.08, 0.02), head * CFrame.new(x, 0.02, -0.575), EMBER, Enum.Material.Neon)
		ember.CastShadow = false
	end
	local glow = Instance.new("PointLight")
	glow.Name = "EyeGlow"
	glow.Color = EMBER
	glow.Range = 5
	glow.Brightness = 0.8
	glow.Parent = model:FindFirstChild("Head")
	part(model, "Neck", "Mouth", Vector3.new(0.55, 0.06, 0.06), head * CFrame.new(0, -0.6, -0.54), HOLLOW, Enum.Material.SmoothPlastic)

	-- Dark smoke curling off the hem of his coat.
	local hem = part(model, "Body", "Hem", Vector3.new(2, 0.2, 1.2), CFrame.new(0, 2, 0), COAT, Enum.Material.Fabric)
	hem.Transparency = 1
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(10, 10, 12))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 2.4) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(1.2, 2)
	smoke.Rate = 6
	smoke.Speed = NumberRange.new(0.3, 0.8)
	smoke.SpreadAngle = Vector2.new(40, 40)
	smoke.Parent = hem

	model.WorldPivot = CFrame.new()
	return model
end

-- Server: the invisible stand-in for him in the world, at his feet (facing -Z). Clients draw
-- and animate the real figure on it. Attributes it reads: Chasing (bool), Watch (bool: his
-- head follows you).
function HollowManModel.marker(cf: CFrame, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = "HollowManMarker"
	p.Size = Vector3.new(1, 0.2, 1)
	p.CFrame = cf
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = parent
	CollectionService:AddTag(p, HollowManModel.Tag)
	return p
end

return HollowManModel
