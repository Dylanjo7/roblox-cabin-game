--!strict
-- An old pickup truck built from parts (an original design, no real make): two-tone paint gone
-- to rust at the edges and mud along the bottom, rounded wheel arches, running boards, chrome
-- bumpers, a slatted grille with round headlights, a cab with pillars, mirrors and a bench seat
-- inside, and a wooden-floored bed with a tailgate and tail lights. It faces -Z from `at`
-- (pivot on the ground under its middle). Used by the cabin (the truck that died at the end of
-- the path: hood popped and steaming) and the lobby (the trucks that take you up there).

export type Options = {
	body: Color3, -- main paint
	trim: Color3?, -- second tone (roof and stripe)
	broken: boolean?, -- hood popped up, steam leaking from the grille
	cargo: boolean?, -- gear under a tarp in the bed
	headlightBrightness: number?,
}

local TYRE = Color3.fromRGB(22, 21, 21)
local CHROME = Color3.fromRGB(170, 168, 162)
local GLASS = Color3.fromRGB(34, 40, 46)
local FRAME = Color3.fromRGB(26, 25, 25)
local RUST = Color3.fromRGB(104, 52, 30)
local MUD = Color3.fromRGB(56, 46, 34)
local SEAT = Color3.fromRGB(82, 60, 44)

local TruckModel = {}

function TruckModel.build(at: CFrame, opts: Options): Model
	local m = Instance.new("Model")
	m.Name = "Truck"
	local body = opts.body
	local trim = opts.trim or Color3.fromRGB(206, 196, 170)

	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, collide: boolean?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = at * cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = collide == true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = m
		return p
	end
	local function paint(name: string, size: Vector3, cf: CFrame, color: Color3?, collide: boolean?): Part
		local p = part(name, size, cf, color or body, Enum.Material.SmoothPlastic, collide)
		p.Reflectance = 0.04
		return p
	end
	local function chrome(name: string, size: Vector3, cf: CFrame): Part
		local p = part(name, size, cf, CHROME, Enum.Material.Metal)
		p.Reflectance = 0.25
		return p
	end
	local function glass(name: string, size: Vector3, cf: CFrame): Part
		local p = part(name, size, cf, GLASS, Enum.Material.Glass)
		p.Transparency = 0.35
		return p
	end
	-- A disc facing along Z (front or back of the truck).
	local function disc(name: string, radius: number, thick: number, cf: CFrame, color: Color3, material: Enum.Material): Part
		local p = part(name, Vector3.new(thick, radius * 2, radius * 2), cf * CFrame.Angles(0, math.rad(90), 0), color, material)
		p.Shape = Enum.PartType.Cylinder
		return p
	end

	-- Frame and the solid body you bump into (one invisible collision box keeps it simple).
	part("Frame", Vector3.new(5.2, 0.7, 15.4), CFrame.new(0, 1.65, 0), FRAME, Enum.Material.Metal)
	local hull = part("Hull", Vector3.new(6.2, 4.6, 16), CFrame.new(0, 3.6, 0), FRAME, Enum.Material.SmoothPlastic, true)
	hull.Transparency = 1

	-- Wheels: tyre, hubcap, lug nuts.
	for _, z in { -4.9, 4.5 } do
		for _, side in { -1, 1 } do
			local hubAt = CFrame.new(side * 2.75, 1.55, z)
			local tyre = part("Tyre", Vector3.new(1.15, 3.1, 3.1), hubAt, TYRE, Enum.Material.Rubber)
			tyre.Shape = Enum.PartType.Cylinder
			local cap = part("Hubcap", Vector3.new(0.12, 1.5, 1.5), hubAt * CFrame.new(side * 0.58, 0, 0), CHROME, Enum.Material.Metal)
			cap.Shape = Enum.PartType.Cylinder
			cap.Reflectance = 0.3
			for i = 0, 4 do
				local a = i * math.pi * 2 / 5
				local nut = part("LugNut", Vector3.new(0.12, 0.12, 0.12), hubAt * CFrame.new(side * 0.65, math.sin(a) * 0.42, math.cos(a) * 0.42), FRAME, Enum.Material.Metal)
				nut.Shape = Enum.PartType.Ball
			end
			-- The arch over it: a top and two sloped ends.
			paint("Fender", Vector3.new(1.4, 0.35, 2.4), CFrame.new(side * 2.85, 3.35, z))
			for _, e in { -1, 1 } do
				paint("FenderEnd", Vector3.new(1.4, 0.35, 1.5), CFrame.new(side * 2.85, 2.85, z + e * 1.65) * CFrame.Angles(math.rad(e * 40), 0, 0))
			end
			-- Rust eating the arch, mud thrown up behind the wheel.
			part("Rust", Vector3.new(1.42, 0.3, 0.9), CFrame.new(side * 2.86, 3.32, z + 0.8), RUST, Enum.Material.CorrodedMetal)
			part("Mud", Vector3.new(0.05, 0.7, 1.6), CFrame.new(side * 3.58, 2.3, z + 2.0), MUD, Enum.Material.Mud)
		end
	end
	for _, side in { -1, 1 } do
		part("RunningBoard", Vector3.new(0.7, 0.18, 4.6), CFrame.new(side * 3.05, 1.95, -0.2), FRAME, Enum.Material.DiamondPlate)
	end

	-- Front end: hood, grille, headlights, bumper.
	local hoodHinge = CFrame.new(0, 4.35, -2.7)
	local hoodAngle = if opts.broken then math.rad(32) else 0
	paint("Hood", Vector3.new(5.3, 0.25, 4.7), hoodHinge * CFrame.Angles(hoodAngle, 0, 0) * CFrame.new(0, 0, -2.35))
	paint("Nose", Vector3.new(5.5, 1.6, 4.8), CFrame.new(0, 3.45, -5.1))
	for _, side in { -1, 1 } do
		paint("Stripe", Vector3.new(0.05, 0.3, 4.8), CFrame.new(side * 2.76, 3.8, -5.1), trim)
	end
	chrome("GrilleFrame", Vector3.new(4.6, 1.5, 0.2), CFrame.new(0, 3.35, -7.55))
	for i = 0, 4 do
		part("GrilleSlat", Vector3.new(4.2, 0.12, 0.1), CFrame.new(0, 2.85 + i * 0.25, -7.66), FRAME, Enum.Material.Metal)
	end
	for _, side in { -1, 1 } do
		local lampAt = CFrame.new(side * 2.0, 3.4, -7.6)
		disc("HeadlightBezel", 0.55, 0.15, lampAt, CHROME, Enum.Material.Metal).Reflectance = 0.3
		disc("Headlight", 0.42, 0.1, lampAt * CFrame.new(0, 0, -0.08), Color3.fromRGB(255, 238, 196), Enum.Material.Neon)
		part("Indicator", Vector3.new(0.4, 0.22, 0.08), CFrame.new(side * 2.0, 2.65, -7.62), Color3.fromRGB(230, 140, 40), Enum.Material.Neon)
		-- The beam (an unrotated helper so the light points straight ahead).
		local beamPart = part("Beam", Vector3.new(0.2, 0.2, 0.2), lampAt * CFrame.new(0, 0, -0.2), Color3.new(), Enum.Material.SmoothPlastic)
		beamPart.Transparency = 1
		local beam = Instance.new("SpotLight")
		beam.Face = Enum.NormalId.Front
		beam.Angle = 55
		beam.Range = 50
		beam.Brightness = opts.headlightBrightness or 1.8
		beam.Color = Color3.fromRGB(255, 232, 190)
		beam.Shadows = true
		beam.Parent = beamPart
	end
	chrome("FrontBumper", Vector3.new(6.6, 0.55, 0.5), CFrame.new(0, 2.15, -7.85))
	part("Plate", Vector3.new(1.4, 0.6, 0.05), CFrame.new(0, 2.15, -8.12), Color3.fromRGB(220, 214, 196), Enum.Material.SmoothPlastic)
	if opts.broken then
		-- Steam leaking out from under the hood.
		local vent = part("Steam", Vector3.new(4, 0.2, 3), CFrame.new(0, 4.2, -5.2), Color3.new(), Enum.Material.SmoothPlastic)
		vent.Transparency = 1
		local steam = Instance.new("ParticleEmitter")
		steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
		steam.Color = ColorSequence.new(Color3.fromRGB(200, 200, 196))
		steam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 3) })
		steam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) })
		steam.Lifetime = NumberRange.new(1.5, 2.5)
		steam.Rate = 5
		steam.Speed = NumberRange.new(1, 2)
		steam.SpreadAngle = Vector2.new(25, 25)
		steam.Parent = vent
		-- The engine under the open hood.
		part("Engine", Vector3.new(3, 1, 3), CFrame.new(0, 4, -5), Color3.fromRGB(40, 40, 42), Enum.Material.Metal)
	end

	-- The cab: lower body, roof, pillars, glass, doors, mirrors.
	paint("CabBody", Vector3.new(5.8, 2.2, 4.6), CFrame.new(0, 3.75, -0.4))
	paint("Roof", Vector3.new(5.5, 0.25, 3.7), CFrame.new(0, 6.95, 0.0), trim)
	for _, side in { -1, 1 } do
		-- A pillar (sloped, by the windscreen), B pillar, and the back corner.
		paint("APillar", Vector3.new(0.2, 2.2, 0.25), CFrame.new(side * 2.7, 5.85, -2.05) * CFrame.Angles(math.rad(14), 0, 0), trim)
		paint("BPillar", Vector3.new(0.2, 2.1, 0.3), CFrame.new(side * 2.75, 5.85, 0.5), trim)
		paint("CPillar", Vector3.new(0.2, 2.1, 0.35), CFrame.new(side * 2.75, 5.85, 1.75), trim)
		glass("SideWindow", Vector3.new(0.1, 1.8, 3.6), CFrame.new(side * 2.78, 5.85, -0.2))
		part("DoorSeam", Vector3.new(0.04, 2.0, 0.05), CFrame.new(side * 2.92, 3.8, 0.55), FRAME, Enum.Material.SmoothPlastic)
		part("DoorSeam", Vector3.new(0.04, 2.0, 0.05), CFrame.new(side * 2.92, 3.8, -2.4), FRAME, Enum.Material.SmoothPlastic)
		chrome("DoorHandle", Vector3.new(0.08, 0.12, 0.45), CFrame.new(side * 2.95, 4.4, 0.2))
		paint("Stripe", Vector3.new(0.05, 0.3, 4.6), CFrame.new(side * 2.92, 3.8, -0.4), trim)
		-- Side mirror on its arm.
		chrome("MirrorArm", Vector3.new(0.6, 0.08, 0.08), CFrame.new(side * 3.15, 5.2, -2.1))
		chrome("Mirror", Vector3.new(0.12, 0.6, 0.45), CFrame.new(side * 3.45, 5.3, -2.1))
	end
	glass("Windscreen", Vector3.new(5.2, 2.15, 0.1), CFrame.new(0, 5.85, -2.15) * CFrame.Angles(math.rad(14), 0, 0))
	glass("RearWindow", Vector3.new(5.1, 1.3, 0.1), CFrame.new(0, 6.0, 1.9))
	paint("BackWall", Vector3.new(5.5, 0.9, 0.15), CFrame.new(0, 5.2, 1.9))
	paint("BackTop", Vector3.new(5.5, 0.25, 0.15), CFrame.new(0, 6.75, 1.9))
	chrome("Aerial", Vector3.new(0.05, 3, 0.05), CFrame.new(2.6, 6.6, -2.6) * CFrame.Angles(math.rad(-10), 0, 0))
	-- Inside: bench seat, dash, steering wheel.
	part("Seat", Vector3.new(5, 0.6, 1.4), CFrame.new(0, 4.8, 0.8), SEAT, Enum.Material.Fabric)
	part("SeatBack", Vector3.new(5, 1.6, 0.4), CFrame.new(0, 5.6, 1.5) * CFrame.Angles(math.rad(-10), 0, 0), SEAT, Enum.Material.Fabric)
	part("Dash", Vector3.new(5.2, 0.8, 0.9), CFrame.new(0, 5.1, -1.9), FRAME, Enum.Material.SmoothPlastic)
	local wheelAt = CFrame.new(-1.3, 5.45, -1.2) * CFrame.Angles(math.rad(-35), 0, 0)
	disc("SteeringWheel", 0.55, 0.1, wheelAt, FRAME, Enum.Material.SmoothPlastic)
	part("Column", Vector3.new(0.12, 0.12, 0.9), wheelAt * CFrame.new(0, 0, -0.45), FRAME, Enum.Material.Metal)

	-- The bed: sides, front wall, tailgate, a plank floor, wheel wells.
	local bedZ = 5.0 -- its front wall sits just behind the cab
	for _, side in { -1, 1 } do
		paint("BedSide", Vector3.new(0.25, 1.7, 6.2), CFrame.new(side * 2.8, 3.95, bedZ))
		chrome("BedRail", Vector3.new(0.3, 0.1, 6.2), CFrame.new(side * 2.8, 4.85, bedZ))
		paint("WheelWell", Vector3.new(0.9, 0.9, 2.6), CFrame.new(side * 2.2, 3.3, bedZ - 0.2))
		part("TailLight", Vector3.new(0.12, 0.7, 0.4), CFrame.new(side * 2.95, 4.1, bedZ + 3.0), Color3.fromRGB(190, 24, 18), Enum.Material.Neon)
	end
	paint("BedFront", Vector3.new(5.6, 1.7, 0.25), CFrame.new(0, 3.95, bedZ - 3.0))
	paint("Tailgate", Vector3.new(5.6, 1.6, 0.25), CFrame.new(0, 3.9, bedZ + 3.1))
	part("TailgateRust", Vector3.new(1.6, 0.5, 0.05), CFrame.new(-1.4, 3.4, bedZ + 3.24), RUST, Enum.Material.CorrodedMetal)
	part("BedFloor", Vector3.new(5.3, 0.2, 6), CFrame.new(0, 3.1, bedZ), Color3.fromRGB(84, 66, 48), Enum.Material.WoodPlanks)
	chrome("RearBumper", Vector3.new(6.2, 0.45, 0.45), CFrame.new(0, 2.2, bedZ + 3.4))
	part("Exhaust", Vector3.new(0.25, 0.25, 1.2), CFrame.new(1.8, 1.6, bedZ + 3.2), FRAME, Enum.Material.Metal)
	if opts.cargo then
		part("Tarp", Vector3.new(4.4, 1.2, 3.2), CFrame.new(0.2, 3.8, bedZ + 0.6) * CFrame.Angles(0, math.rad(4), math.rad(3)), Color3.fromRGB(58, 66, 48), Enum.Material.Fabric)
		part("TarpLump", Vector3.new(1.6, 0.8, 1.6), CFrame.new(-1, 4.5, bedZ + 0.2), Color3.fromRGB(58, 66, 48), Enum.Material.Fabric)
		part("GasCan", Vector3.new(0.8, 1.1, 0.5), CFrame.new(1.9, 3.75, bedZ - 2.3), Color3.fromRGB(150, 30, 24), Enum.Material.Metal)
		local spare = part("SpareTyre", Vector3.new(1.0, 2.6, 2.6), CFrame.new(-1.5, 3.4, bedZ + 2.2) * CFrame.Angles(0, 0, math.rad(90)), TYRE, Enum.Material.Rubber)
		spare.Shape = Enum.PartType.Cylinder
	end

	m.WorldPivot = at
	return m
end

return TruckModel
