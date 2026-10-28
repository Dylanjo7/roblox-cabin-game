--!strict
-- Builds the Hollow Man from parts. Original design: a starved, stooped figure nearly twice your
-- height in a long coat rotted to strips. His neck is too long and his head hangs tipped to one
-- side. His face is corpse-grey and cracked, with deep sockets and a pinpoint ember burning in
-- each, two slits for a nose, and a grin cut far too wide, its corners split up towards the
-- ears, with a jaw that hangs open on uneven teeth. Ribs show through the torn coat, and dead
-- pine branches have grown out through his back and shoulders. His arms hang past his knees and
-- end in long clawed fingers; his feet are bare. The pivot is at his feet and he faces -Z.
--
-- Every part carries a "Limb" attribute naming the joint it hangs from (see HollowManModel.Joints),
-- so the client rig (src/client/HollowManRig) can animate him. The server never moves the full
-- model: it moves an invisible marker (HollowManModel.marker) and each client draws him there.

local CollectionService = game:GetService("CollectionService")

local COAT = Color3.fromRGB(14, 13, 15)
local COAT_EDGE = Color3.fromRGB(24, 22, 24)
local SKIN = Color3.fromRGB(132, 128, 120) -- corpse grey
local SKIN_DARK = Color3.fromRGB(86, 82, 78)
local BONE = Color3.fromRGB(176, 164, 136)
local GUM = Color3.fromRGB(56, 18, 18)
local HOLLOW = Color3.fromRGB(3, 3, 4)
local EMBER = Color3.fromRGB(255, 70, 30)
local DEADWOOD = Color3.fromRGB(46, 36, 28)

export type Joint = { parent: string?, at: Vector3 } -- at: joint position in model space (unscaled)

local HollowManModel = {}

-- The tag on the server's invisible marker part.
HollowManModel.Tag = "HollowMan"

local HIP_Y = 5.4
local KNEE_Y = 2.7
local UPPER_ARM = 3.2
local FOREARM = 3.8

local function shoulderAt(side: number): Vector3
	return Vector3.new(side * 1.3, 8.1, -0.2)
end

-- The upper arm hangs from the shoulder, angled forward and a little out.
local function upperArmCFrame(side: number): CFrame
	return CFrame.new(shoulderAt(side)) * CFrame.Angles(math.rad(-12), 0, math.rad(side * 5)) * CFrame.new(0, -UPPER_ARM / 2, 0)
end

local function elbowCFrame(side: number): CFrame
	return upperArmCFrame(side) * CFrame.new(0, -UPPER_ARM / 2, 0)
end

-- The neck juts forward and the head hangs off it, tipped to one side.
local NECK_BASE = Vector3.new(0, 8.45, -0.4)
local function neckCFrame(): CFrame
	return CFrame.new(NECK_BASE) * CFrame.Angles(math.rad(-38), 0, math.rad(6)) * CFrame.new(0, 0.8, 0)
end
local function headCFrame(): CFrame
	return neckCFrame() * CFrame.new(0, 1.55, -0.1) * CFrame.Angles(math.rad(8), 0, math.rad(16))
end
-- The jaw hinges just under the ears.
local function jawHinge(): CFrame
	return headCFrame() * CFrame.new(0, -0.55, 0.2)
end

-- Joints, parents first. Coat strips are added below.
local Joints: { [string]: Joint } = {
	Body = { parent = nil, at = Vector3.new(0, HIP_Y - 0.4, 0) },
	LegL = { parent = nil, at = Vector3.new(-0.45, HIP_Y, 0) },
	LegR = { parent = nil, at = Vector3.new(0.45, HIP_Y, 0) },
	ShinL = { parent = "LegL", at = Vector3.new(-0.45, KNEE_Y, 0) },
	ShinR = { parent = "LegR", at = Vector3.new(0.45, KNEE_Y, 0) },
	ArmL = { parent = "Body", at = shoulderAt(-1) },
	ArmR = { parent = "Body", at = shoulderAt(1) },
	ForeL = { parent = "ArmL", at = elbowCFrame(-1).Position },
	ForeR = { parent = "ArmR", at = elbowCFrame(1).Position },
	Neck = { parent = "Body", at = NECK_BASE },
	Jaw = { parent = "Neck", at = jawHinge().Position },
}
local Order = { "Body", "LegL", "LegR", "ShinL", "ShinR", "ArmL", "ArmR", "ForeL", "ForeR", "Neck", "Jaw" }

-- The coat hangs in ragged strips of different lengths, front and back, each swinging on its own.
local STRIPS = { { -0.85, 3.1 }, { -0.45, 2.2 }, { 0, 3.5 }, { 0.45, 2.5 }, { 0.85, 3.3 } }
for i, s in STRIPS do
	for _, side in { "Front", "Back" } do
		local name = `Coat{side}{i}`
		Joints[name] = { parent = "Body", at = Vector3.new(s[1], 5, if side == "Front" then -0.5 else 0.5) }
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

local function ball(model: Model, limb: string, name: string, size: number, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = part(model, limb, name, Vector3.new(size, size, size), cf, color, material)
	p.Shape = Enum.PartType.Ball
	return p
end

local function arm(model: Model, side: number)
	local upperLimb = if side < 0 then "ArmL" else "ArmR"
	local foreLimb = if side < 0 then "ForeL" else "ForeR"
	part(model, upperLimb, "UpperArm", Vector3.new(0.4, UPPER_ARM, 0.4), upperArmCFrame(side), COAT, Enum.Material.Fabric)
	part(model, upperLimb, "Cuff", Vector3.new(0.5, 0.4, 0.5), upperArmCFrame(side) * CFrame.new(0, -UPPER_ARM / 2 + 0.2, 0) * CFrame.Angles(0, 0, math.rad(side * 8)), COAT_EDGE, Enum.Material.Fabric)
	local elbow = elbowCFrame(side)
	ball(model, foreLimb, "Elbow", 0.42, elbow, SKIN_DARK, Enum.Material.SmoothPlastic)
	local fore = elbow * CFrame.Angles(math.rad(-16), 0, 0) * CFrame.new(0, -FOREARM / 2, 0)
	part(model, foreLimb, "Forearm", Vector3.new(0.26, FOREARM, 0.26), fore, SKIN, Enum.Material.SmoothPlastic)
	-- A tendon standing out along it.
	part(model, foreLimb, "Tendon", Vector3.new(0.08, FOREARM * 0.8, 0.08), fore * CFrame.new(0, 0, -0.13), SKIN_DARK, Enum.Material.SmoothPlastic)
	local wrist = fore * CFrame.new(0, -FOREARM / 2, 0)
	part(model, foreLimb, "Hand", Vector3.new(0.5, 0.7, 0.2), wrist * CFrame.new(0, -0.35, 0), SKIN, Enum.Material.SmoothPlastic)
	-- Five long fingers, each with a second joint curling in and a black claw.
	for i, x in { -0.21, -0.1, 0.01, 0.12, 0.23 } do
		local length = if i == 1 then 0.7 else (if i == 3 then 1.25 else 1.1)
		local spread = (x - 0.01) * -28
		local base = wrist * CFrame.new(x, -0.68, 0) * CFrame.Angles(math.rad(-10), 0, math.rad(spread))
		part(model, foreLimb, "Finger", Vector3.new(0.065, length, 0.065), base * CFrame.new(0, -length / 2, 0), SKIN, Enum.Material.SmoothPlastic)
		local knuckle = base * CFrame.new(0, -length, 0)
		ball(model, foreLimb, "Knuckle", 0.09, knuckle, SKIN_DARK, Enum.Material.SmoothPlastic)
		local tip = knuckle * CFrame.Angles(math.rad(-32), 0, 0)
		part(model, foreLimb, "FingerTip", Vector3.new(0.055, length * 0.75, 0.055), tip * CFrame.new(0, -length * 0.375, 0), SKIN_DARK, Enum.Material.SmoothPlastic)
		local claw = tip * CFrame.new(0, -length * 0.75, 0) * CFrame.Angles(math.rad(-25), 0, 0)
		part(model, foreLimb, "Claw", Vector3.new(0.05, 0.32, 0.05), claw * CFrame.new(0, -0.16, 0), HOLLOW, Enum.Material.SmoothPlastic)
	end
end

-- A dead pine branch grown out through him: a crooked limb with a couple of offshoots.
local function branch(model: Model, from: CFrame, length: number)
	part(model, "Body", "Branch", Vector3.new(0.14, length, 0.14), from * CFrame.new(0, length / 2, 0), DEADWOOD, Enum.Material.Wood)
	for i, t in { 0.45, 0.75 } do
		local side = if i == 1 then 1 else -1
		local twig = from * CFrame.new(0, length * t, 0) * CFrame.Angles(0, 0, math.rad(side * 40))
		part(model, "Body", "Twig", Vector3.new(0.07, length * 0.4, 0.07), twig * CFrame.new(0, length * 0.2, 0), DEADWOOD, Enum.Material.Wood)
	end
end

local function face(model: Model, head: CFrame)
	local front = -0.53
	-- Heavy brow, sunken cheeks, two nose slits.
	part(model, "Neck", "Brow", Vector3.new(1.0, 0.22, 0.3), head * CFrame.new(0, 0.42, front + 0.08), SKIN_DARK, Enum.Material.SmoothPlastic)
	for _, x in { -0.32, 0.32 } do
		part(model, "Neck", "Cheek", Vector3.new(0.22, 0.6, 0.1), head * CFrame.new(x, -0.2, front + 0.04), SKIN_DARK, Enum.Material.SmoothPlastic)
		part(model, "Neck", "NoseSlit", Vector3.new(0.035, 0.22, 0.04), head * CFrame.new(x * 0.18, -0.08, front - 0.01) * CFrame.Angles(0, 0, math.rad(x * 30)), HOLLOW, Enum.Material.SmoothPlastic)
	end
	-- Deep sockets with an ember burning at the bottom of each.
	for _, x in { -0.24, 0.24 } do
		part(model, "Neck", "EyeSocket", Vector3.new(0.32, 0.46, 0.1), head * CFrame.new(x, 0.18, front) * CFrame.Angles(0, 0, math.rad(x * -25)), HOLLOW, Enum.Material.SmoothPlastic)
		local ember = ball(model, "Neck", "Ember", 0.085, head * CFrame.new(x, 0.13, front - 0.04), EMBER, Enum.Material.Neon)
		ember.CastShadow = false
	end
	-- The grin: a dark wide mouth, uneven teeth along the top, and the corners split up towards the ears.
	part(model, "Neck", "Mouth", Vector3.new(0.84, 0.3, 0.06), head * CFrame.new(0, -0.5, front), GUM, Enum.Material.SmoothPlastic)
	for i = 1, 11 do
		local x = -0.38 + (i - 1) * 0.076
		local long = (i * 7) % 3 == 0
		part(model, "Neck", "Tooth", Vector3.new(0.05, if long then 0.17 else 0.11, 0.04), head * CFrame.new(x, -0.4 - (if long then 0.04 else 0.01), front - 0.03) * CFrame.Angles(0, 0, math.rad((i % 2) * 8 - 4)), BONE, Enum.Material.SmoothPlastic)
	end
	for _, side in { -1, 1 } do
		part(model, "Neck", "Split", Vector3.new(0.4, 0.035, 0.04), head * CFrame.new(side * 0.52, -0.38, front + 0.06) * CFrame.Angles(0, side * math.rad(-30), math.rad(side * 32)), GUM, Enum.Material.SmoothPlastic)
	end
	-- Cracks in the skin.
	local cracks = { { -0.15, 0.62, 25, 0.4 }, { 0.2, 0.7, -40, 0.3 }, { 0.38, -0.05, 70, 0.35 }, { -0.4, 0.4, -10, 0.25 } }
	for _, c in cracks do
		part(model, "Neck", "Crack", Vector3.new(0.025, c[4], 0.03), head * CFrame.new(c[1], c[2], front + 0.01) * CFrame.Angles(0, 0, math.rad(c[3])), HOLLOW, Enum.Material.SmoothPlastic)
	end
	-- A few long lank strands hanging from the back of his skull.
	for i, x in { -0.35, -0.1, 0.15, 0.38 } do
		local length = 1.4 + (i % 2) * 0.9
		part(model, "Neck", "Hair", Vector3.new(0.05, length, 0.05), head * CFrame.new(x, 0.9 - length / 2, 0.45) * CFrame.Angles(math.rad(10), 0, math.rad(x * 15)), HOLLOW, Enum.Material.Fabric)
	end
end

function HollowManModel.build(): Model
	local model = Instance.new("Model")
	model.Name = "HollowMan"

	local root = part(model, "Root", "Root", Vector3.new(1, 0.2, 1), CFrame.new(0, 0.1, 0), COAT, Enum.Material.Fabric)
	root.Transparency = 1
	model.PrimaryPart = root

	-- Legs: long and thin, with knobbly knees and bare feet with long toes.
	for _, side in { -1, 1 } do
		local x = side * 0.45
		local leg = if side < 0 then "LegL" else "LegR"
		local shin = if side < 0 then "ShinL" else "ShinR"
		part(model, leg, "Thigh", Vector3.new(0.44, HIP_Y - KNEE_Y, 0.44), CFrame.new(x, (HIP_Y + KNEE_Y) / 2, 0), COAT, Enum.Material.Fabric)
		ball(model, shin, "Knee", 0.5, CFrame.new(x, KNEE_Y, -0.06), SKIN_DARK, Enum.Material.SmoothPlastic)
		part(model, shin, "Shin", Vector3.new(0.3, KNEE_Y, 0.3), CFrame.new(x, KNEE_Y / 2, 0), SKIN, Enum.Material.SmoothPlastic)
		part(model, shin, "Foot", Vector3.new(0.42, 0.2, 0.8), CFrame.new(x, 0.1, -0.2), SKIN, Enum.Material.SmoothPlastic)
		for t, dx in { -0.14, 0, 0.14 } do
			local length = if t == 2 then 0.6 else 0.48
			part(model, shin, "Toe", Vector3.new(0.08, 0.08, length), CFrame.new(x + dx, 0.05, -0.6 - length / 2), SKIN_DARK, Enum.Material.SmoothPlastic)
		end
	end

	-- A narrow, hunched torso with the shoulders drawn up high around the neck.
	local chest = CFrame.new(0, 6.6, 0) * CFrame.Angles(math.rad(-16), 0, 0)
	part(model, "Body", "Torso", Vector3.new(1.7, 3.3, 0.9), chest, COAT, Enum.Material.Fabric)
	part(model, "Body", "Shoulders", Vector3.new(2.8, 0.5, 1.0), CFrame.new(0, 8.15, -0.15) * CFrame.Angles(math.rad(-14), 0, 0), COAT, Enum.Material.Fabric)
	for _, side in { -1, 1 } do
		-- Shoulder blades poking up through the coat.
		part(model, "Body", "ShoulderBlade", Vector3.new(0.6, 0.9, 0.2), CFrame.new(side * 0.7, 7.9, 0.5) * CFrame.Angles(math.rad(20), 0, math.rad(side * -15)), COAT_EDGE, Enum.Material.Fabric)
	end
	-- The coat hangs open at the chest: grey skin stretched over ribs.
	part(model, "Body", "Chest", Vector3.new(0.8, 2.2, 0.1), chest * CFrame.new(0, 0.3, -0.46), SKIN_DARK, Enum.Material.SmoothPlastic)
	for i = 0, 4 do
		local y = 1.1 - i * 0.42
		for _, side in { -1, 1 } do
			part(model, "Body", "Rib", Vector3.new(0.42, 0.07, 0.06), chest * CFrame.new(side * 0.2, y + 0.3, -0.52) * CFrame.Angles(0, 0, math.rad(side * -18)), SKIN, Enum.Material.SmoothPlastic)
		end
	end
	for i, x in { -0.65, -0.22, 0.22, 0.65 } do
		part(model, "Body", "Collar", Vector3.new(0.4, 1.0 + (i % 2) * 0.35, 0.12), CFrame.new(x, 8.7, 0.25) * CFrame.Angles(math.rad(18), 0, math.rad(x * -20)), COAT_EDGE, Enum.Material.Fabric)
	end
	for i = 0, 4 do
		ball(model, "Body", "Spine", 0.22, CFrame.new(0, 8.0 - i * 0.55, 0.52 + i * 0.03), SKIN_DARK, Enum.Material.SmoothPlastic)
	end

	-- Dead pine branches grown out through his back and shoulders.
	branch(model, CFrame.new(-0.6, 7.6, 0.5) * CFrame.Angles(math.rad(35), 0, math.rad(30)), 2.6)
	branch(model, CFrame.new(0.7, 7.8, 0.45) * CFrame.Angles(math.rad(28), 0, math.rad(-38)), 3.1)
	branch(model, CFrame.new(0.15, 6.6, 0.55) * CFrame.Angles(math.rad(55), 0, math.rad(-10)), 2.0)
	branch(model, CFrame.new(-1.2, 8.2, 0) * CFrame.Angles(math.rad(10), 0, math.rad(55)), 1.6)

	for i, s in STRIPS do
		local x, length = s[1], s[2]
		part(model, `CoatFront{i}`, "CoatFront", Vector3.new(0.44, length, 0.1), CFrame.new(x, 5 - length / 2, -0.5), COAT_EDGE, Enum.Material.Fabric)
		part(model, `CoatBack{i}`, "CoatBack", Vector3.new(0.44, length + 0.5, 0.1), CFrame.new(x, 5 - (length + 0.5) / 2, 0.5), COAT, Enum.Material.Fabric)
	end

	arm(model, -1)
	arm(model, 1)

	-- The long crooked neck and the head hanging off it.
	local neck = neckCFrame()
	part(model, "Neck", "Neck", Vector3.new(0.28, 1.6, 0.28), neck, SKIN, Enum.Material.SmoothPlastic)
	part(model, "Neck", "Throat", Vector3.new(0.1, 1.2, 0.08), neck * CFrame.new(0, 0, -0.15), SKIN_DARK, Enum.Material.SmoothPlastic)
	local head = headCFrame()
	part(model, "Neck", "Head", Vector3.new(1.0, 2.1, 1.05), head, SKIN, Enum.Material.SmoothPlastic)
	face(model, head)
	local glow = Instance.new("PointLight")
	glow.Name = "EyeGlow"
	glow.Color = EMBER
	glow.Range = 6
	glow.Brightness = 1.2
	glow.Parent = model:FindFirstChild("Head")

	-- The jaw, hanging open on its hinge, lower teeth jutting up.
	local hinge = jawHinge()
	part(model, "Jaw", "Jaw", Vector3.new(0.8, 0.28, 0.75), hinge * CFrame.new(0, -0.2, -0.42), SKIN, Enum.Material.SmoothPlastic)
	part(model, "Jaw", "JawGum", Vector3.new(0.7, 0.06, 0.6), hinge * CFrame.new(0, -0.05, -0.42), GUM, Enum.Material.SmoothPlastic)
	for i = 1, 8 do
		local x = -0.3 + (i - 1) * 0.086
		part(model, "Jaw", "Tooth", Vector3.new(0.05, if i % 3 == 0 then 0.16 else 0.1, 0.04), hinge * CFrame.new(x, 0.02, -0.76) * CFrame.Angles(0, 0, math.rad((i % 2) * -10 + 5)), BONE, Enum.Material.SmoothPlastic)
	end

	-- Dark smoke curling off the hem of his coat.
	local hem = part(model, "Body", "Hem", Vector3.new(2, 0.2, 1.2), CFrame.new(0, 2, 0), COAT, Enum.Material.Fabric)
	hem.Transparency = 1
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(8, 8, 10))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 2.6) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.65), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(1.2, 2.2)
	smoke.Rate = 8
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
