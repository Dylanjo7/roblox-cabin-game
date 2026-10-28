--!strict
-- Builds the Hollow Man from parts: a very tall, gaunt figure in a long tattered coat, with
-- arms that hang past his knees and a narrow ash-grey head with two hollow eye sockets and a
-- faint ember deep inside each. Original design. The pivot is at his feet and he faces -Z.
-- Used for glimpses and his appearance at the door (client) and He Walks (server, later).

local COAT = Color3.fromRGB(16, 15, 17)
local COAT_EDGE = Color3.fromRGB(26, 24, 26)
local SKIN = Color3.fromRGB(118, 114, 108)
local HOLLOW = Color3.fromRGB(4, 4, 5)
local EMBER = Color3.fromRGB(120, 24, 14)

local HollowManModel = {}

local function part(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
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
	p.Parent = model
	return p
end

-- One long arm hanging from the shoulder at x, bent slightly forward at the elbow.
local function arm(model: Model, side: number)
	local shoulder = CFrame.new(side * 1.45, 8, -0.1)
	local upper = shoulder * CFrame.Angles(math.rad(-8), 0, math.rad(side * 4)) * CFrame.new(0, -1.6, 0)
	part(model, "UpperArm", Vector3.new(0.42, 3.2, 0.42), upper, COAT, Enum.Material.Fabric)
	local elbow = upper * CFrame.new(0, -1.6, 0)
	local fore = elbow * CFrame.Angles(math.rad(-14), 0, 0) * CFrame.new(0, -1.6, 0)
	part(model, "Forearm", Vector3.new(0.34, 3.2, 0.34), fore, SKIN, Enum.Material.SmoothPlastic)
	local wrist = fore * CFrame.new(0, -1.6, 0)
	part(model, "Hand", Vector3.new(0.5, 0.6, 0.25), wrist * CFrame.new(0, -0.3, 0), SKIN, Enum.Material.SmoothPlastic)
	for i, x in { -0.18, 0, 0.18 } do
		local length = if i == 2 then 1.4 else 1.15
		part(model, "Finger", Vector3.new(0.08, length, 0.08), wrist * CFrame.new(x, -0.6 - length / 2, 0) * CFrame.Angles(math.rad(-6), 0, 0), SKIN, Enum.Material.SmoothPlastic)
	end
end

function HollowManModel.build(): Model
	local model = Instance.new("Model")
	model.Name = "HollowMan"

	local root = part(model, "Root", Vector3.new(1, 0.2, 1), CFrame.new(0, 0.1, 0), COAT, Enum.Material.Fabric)
	root.Transparency = 1
	model.PrimaryPart = root

	-- Legs: long and thin.
	for _, x in { -0.5, 0.5 } do
		part(model, "Leg", Vector3.new(0.45, 5.4, 0.45), CFrame.new(x, 2.7, 0), COAT, Enum.Material.Fabric)
		part(model, "Foot", Vector3.new(0.5, 0.25, 1.1), CFrame.new(x, 0.13, -0.25), HOLLOW, Enum.Material.SmoothPlastic)
	end

	-- Torso and a hunched shoulder line.
	part(model, "Torso", Vector3.new(2, 3.2, 1), CFrame.new(0, 6.5, 0) * CFrame.Angles(math.rad(-6), 0, 0), COAT, Enum.Material.Fabric)
	part(model, "Shoulders", Vector3.new(3, 0.5, 1.05), CFrame.new(0, 8.05, -0.15) * CFrame.Angles(math.rad(-10), 0, 0), COAT, Enum.Material.Fabric)

	-- The coat hangs in ragged strips of different lengths.
	local strips = { { -0.95, 3.0 }, { -0.5, 2.3 }, { 0, 3.3 }, { 0.5, 2.6 }, { 0.95, 2.9 } }
	for _, s in strips do
		local x, length = s[1], s[2]
		part(model, "CoatFront", Vector3.new(0.48, length, 0.12), CFrame.new(x, 5 - length / 2, -0.55), COAT_EDGE, Enum.Material.Fabric)
		part(model, "CoatBack", Vector3.new(0.48, length + 0.4, 0.12), CFrame.new(x, 5 - (length + 0.4) / 2, 0.55), COAT, Enum.Material.Fabric)
	end

	arm(model, -1)
	arm(model, 1)

	-- Neck and head, tipped forward as if looking down at you.
	local neck = CFrame.new(0, 8.7, -0.35) * CFrame.Angles(math.rad(-20), 0, 0)
	part(model, "Neck", Vector3.new(0.32, 1, 0.32), neck, SKIN, Enum.Material.SmoothPlastic)
	local head = neck * CFrame.new(0, 1.3, -0.15) * CFrame.Angles(math.rad(-6), 0, 0)
	part(model, "Head", Vector3.new(1.1, 1.9, 1.1), head, SKIN, Enum.Material.SmoothPlastic)
	part(model, "Brow", Vector3.new(1.15, 0.25, 0.3), head * CFrame.new(0, 0.3, -0.45), Color3.fromRGB(96, 92, 88), Enum.Material.SmoothPlastic)
	for _, x in { -0.25, 0.25 } do
		part(model, "EyeSocket", Vector3.new(0.3, 0.42, 0.08), head * CFrame.new(x, 0.05, -0.53), HOLLOW, Enum.Material.SmoothPlastic)
		local ember = part(model, "Ember", Vector3.new(0.07, 0.07, 0.02), head * CFrame.new(x, 0.02, -0.575), EMBER, Enum.Material.Neon)
		ember.CastShadow = false
	end
	part(model, "Mouth", Vector3.new(0.5, 0.06, 0.06), head * CFrame.new(0, -0.55, -0.54), HOLLOW, Enum.Material.SmoothPlastic)

	model.WorldPivot = CFrame.new()
	return model
end

return HollowManModel
