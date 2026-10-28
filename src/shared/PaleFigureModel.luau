--!strict
-- The thing from Don't Look Away: tall, thin and pale, in a long grey nightgown, black hair
-- hanging over a head with no face at all. It never moves while anyone is looking, so it has
-- no animation: each time it moves it's in a new pose (pose()), and you only ever see the
-- result. Built from parts; the pivot is on the floor between its feet, facing -Z.

local PaleFigureModel = {}

PaleFigureModel.Tag = "PaleFigure"

local SKIN = Color3.fromRGB(206, 214, 220)
local GOWN = Color3.fromRGB(176, 174, 164)
local HEM = Color3.fromRGB(116, 108, 94)
local HAIR = Color3.fromRGB(12, 10, 10)

export type Pose = {
	lean: number, -- degrees the body leans forward from the waist
	headTilt: number, -- degrees the head lolls to the side
	headPitch: number, -- degrees the head tips forward (negative: back)
	armL: { number }, -- { shoulder forward, shoulder out, elbow } in degrees
	armR: { number },
}

-- Hanging still; one arm reaching; both reaching; broken elbows and a lolling head; right up close.
PaleFigureModel.Poses = {
	{ lean = 4, headTilt = 0, headPitch = 18, armL = { 0, 9, 0 }, armR = { 0, 9, 0 } },
	{ lean = 10, headTilt = 32, headPitch = 6, armL = { 4, 10, 0 }, armR = { 84, 0, 4 } },
	{ lean = 16, headTilt = -12, headPitch = 0, armL = { 80, 2, 6 }, armR = { 86, 2, 2 } },
	{ lean = 22, headTilt = 58, headPitch = 22, armL = { 30, 26, -70 }, armR = { 60, 10, -40 } },
	{ lean = 6, headTilt = -26, headPitch = -24, armL = { 150, 18, 10 }, armR = { 120, 30, 20 } },
} :: { Pose }

local function part(model: Model, name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- A vertical cylinder (Roblox cylinders lie along X).
local function upright(cf: CFrame): CFrame
	return cf * CFrame.Angles(0, 0, math.rad(90))
end

-- Every part's place for this pose, with the pivot at `at`.
local function layout(at: CFrame, pose: Pose): { [string]: CFrame }
	local out: { [string]: CFrame } = {}
	-- The gown flares out from the waist in three rings, and never leans.
	out.Hem = upright(at * CFrame.new(0, 1.0, 0))
	out.Skirt = upright(at * CFrame.new(0, 2.3, 0))
	out.Hips = upright(at * CFrame.new(0, 3.4, 0))
	-- Torn strips hanging below the hem, each facing out.
	for i = 1, 6 do
		local a = (i / 6) * math.pi * 2
		local spot = Vector3.new(math.cos(a) * 1.25, 0.3, math.sin(a) * 1.25)
		out[`Tatter{i}`] = at * CFrame.lookAt(spot, spot * Vector3.new(2, 1, 2)) * CFrame.Angles(math.rad(-6), 0, math.rad(i * 7 - 24))
	end
	out.FootL = at * CFrame.new(-0.36, 0.14, -0.95)
	out.FootR = at * CFrame.new(0.4, 0.14, -0.85) * CFrame.Angles(0, math.rad(-14), 0)

	local waist = at * CFrame.new(0, 3.7, 0) * CFrame.Angles(math.rad(-pose.lean), 0, 0)
	out.Bodice = waist * CFrame.new(0, 1.0, 0)
	local neck = waist * CFrame.new(0, 2.15, 0)
	out.Neck = upright(neck * CFrame.new(0, 0.3, 0))
	local head = neck * CFrame.new(0, 0.55, 0) * CFrame.Angles(math.rad(pose.headPitch), 0, math.rad(pose.headTilt)) * CFrame.new(0, 0.66, 0)
	out.Head = head
	out.HairBack = head * CFrame.new(0, -0.95, 0.5)
	out.HairTop = head * CFrame.new(0, 0.62, 0.06)
	for i, x in { -0.36, -0.14, 0.1, 0.34 } do
		out[`Strand{i}`] = head * CFrame.new(x, -0.4 - (i % 2) * 0.25, -0.56) * CFrame.Angles(0, 0, math.rad(x * 8))
	end

	for _, side in { "L", "R" } do
		local s = if side == "L" then -1 else 1
		local arm = if side == "L" then pose.armL else pose.armR
		local shoulder = waist * CFrame.new(s * 1.02, 1.85, 0) * CFrame.Angles(math.rad(arm[1]), 0, math.rad(s * arm[2]))
		out[`Upper{side}`] = shoulder * CFrame.new(0, -1.0, 0)
		local elbow = shoulder * CFrame.new(0, -2.0, 0) * CFrame.Angles(math.rad(arm[3]), 0, 0)
		out[`Fore{side}`] = elbow * CFrame.new(0, -0.95, 0)
		out[`Hand{side}`] = elbow * CFrame.new(0, -2.1, 0)
		-- Long fingers, the middle two longest.
		for f = 1, 4 do
			local fx = -0.16 + (f - 1) * 0.105
			out[`Finger{side}{f}`] = elbow * CFrame.new(fx, -2.75 - (if f == 2 or f == 3 then 0.1 else 0), 0) * CFrame.Angles(0, 0, math.rad(fx * 20))
		end
	end
	return out
end

-- Build it standing at `at` (floor point between its feet, facing -Z of `at`) in pose 1.
function PaleFigureModel.build(at: CFrame, parent: Instance?): Model
	local m = Instance.new("Model")
	m.Name = "PaleFigure"
	local root = part(m, "Root", Vector3.new(1, 1, 1), SKIN, Enum.Material.SmoothPlastic)
	root.Transparency = 1
	root.CastShadow = false
	m.PrimaryPart = root

	local hem = part(m, "Hem", Vector3.new(1.4, 2.7, 2.7), HEM, Enum.Material.Fabric)
	hem.Shape = Enum.PartType.Cylinder
	local skirt = part(m, "Skirt", Vector3.new(1.4, 2.3, 2.3), GOWN, Enum.Material.Fabric)
	skirt.Shape = Enum.PartType.Cylinder
	local hips = part(m, "Hips", Vector3.new(1.0, 1.9, 1.9), GOWN, Enum.Material.Fabric)
	hips.Shape = Enum.PartType.Cylinder
	for i = 1, 6 do
		part(m, `Tatter{i}`, Vector3.new(0.5, 0.5, 0.06), HEM, Enum.Material.Fabric)
	end
	part(m, "FootL", Vector3.new(0.38, 0.28, 0.75), SKIN, Enum.Material.SmoothPlastic)
	part(m, "FootR", Vector3.new(0.38, 0.28, 0.75), SKIN, Enum.Material.SmoothPlastic)
	part(m, "Bodice", Vector3.new(1.75, 2.1, 1.0), GOWN, Enum.Material.Fabric)
	local neck = part(m, "Neck", Vector3.new(0.7, 0.38, 0.38), SKIN, Enum.Material.SmoothPlastic)
	neck.Shape = Enum.PartType.Cylinder
	-- The head: smooth all over. No eyes, no mouth.
	local head = part(m, "Head", Vector3.new(1.0, 1.32, 1.06), SKIN, Enum.Material.SmoothPlastic)
	head.Reflectance = 0.04
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = head
	part(m, "HairBack", Vector3.new(1.16, 2.7, 0.24), HAIR, Enum.Material.SmoothPlastic)
	part(m, "HairTop", Vector3.new(1.08, 0.34, 1.02), HAIR, Enum.Material.SmoothPlastic)
	for i = 1, 4 do
		part(m, `Strand{i}`, Vector3.new(0.15, 1.6 + (i % 2) * 0.5, 0.08), HAIR, Enum.Material.SmoothPlastic)
	end
	for _, side in { "L", "R" } do
		part(m, `Upper{side}`, Vector3.new(0.34, 2.0, 0.34), GOWN, Enum.Material.Fabric)
		part(m, `Fore{side}`, Vector3.new(0.28, 1.9, 0.28), SKIN, Enum.Material.SmoothPlastic)
		part(m, `Hand{side}`, Vector3.new(0.42, 0.5, 0.13), SKIN, Enum.Material.SmoothPlastic)
		for f = 1, 4 do
			part(m, `Finger{side}{f}`, Vector3.new(0.07, 0.9, 0.07), SKIN, Enum.Material.SmoothPlastic)
		end
	end

	-- A faint cold glow about it, so it can be made out across a dark room.
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(170, 200, 255)
	light.Range = 7
	light.Brightness = 0.35
	light.Shadows = false
	light.Parent = m:FindFirstChild("Bodice")

	PaleFigureModel.pose(m, at, PaleFigureModel.Poses[1])
	m.Parent = parent
	return m
end

-- Put it at `at` in this pose, all at once (nobody sees anything in between). Works out of the
-- world too (a ViewportFrame, or before it's parented).
function PaleFigureModel.pose(model: Model, at: CFrame, pose: Pose)
	local places = layout(at, pose)
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			local cf = if child.Name == "Root" then at * CFrame.new(0, 0.5, 0) else places[child.Name]
			if cf then
				child.CFrame = cf
			end
		end
	end
end

return PaleFigureModel
