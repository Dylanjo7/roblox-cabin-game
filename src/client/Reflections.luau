--!strict
-- The Wrong Reflection clue. Roblox has no real mirrors, so each tagged mirror ("ReflectionMirror")
-- draws one: a ViewportFrame on the glass holding a copy of its room reflected across the glass,
-- seen from your own eye every frame, so it shifts as you move like real glass would. The copy
-- is missing one piece of furniture (attribute Missing), and you aren't in it. Now and then, the
-- first time you lean in close to a mirror, he's standing right behind you in it; turn round and
-- there's nothing there (a scare, through Scares).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HollowManModel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HollowManModel"))

local Audio = require(script.Parent.Audio)
local Scares = require(script.Parent.Scares)

type Mirror = {
	glass: BasePart,
	view: ViewportFrame,
	camera: Camera,
	origin: Vector3, -- a point on the mirror's surface
	normal: Vector3, -- out of the glass, into the room
	floorY: number,
	triedScare: boolean,
}

local Reflections = {}

local GHOST_CHANCE = 0.35 -- the first time you lean in close to a mirror
local UPDATE_RANGE = 60 -- mirrors further away than this aren't redrawn
local rng = Random.new()
local mirrors: { [BasePart]: Mirror } = {}

-- Reflect a CFrame across the plane through `origin` with normal `n`. A reflection turns the
-- axes left-handed, so X is flipped back (boxes, cylinders and balls look the same either way).
local function reflect(cf: CFrame, origin: Vector3, n: Vector3): CFrame
	local function r(v: Vector3): Vector3
		return v - 2 * v:Dot(n) * n
	end
	local p = cf.Position
	local position = p - 2 * (p - origin):Dot(n) * n
	return CFrame.fromMatrix(position, -r(cf.RightVector), r(cf.UpVector), r(-cf.LookVector))
end

-- Nothing in the reflection makes a sound, gives light, smokes, ticks, or can be clicked, and
-- none of it is tagged (so nothing else in the game mistakes it for the real room).
local function strip(root: Instance)
	for _, inst in root:GetDescendants() do
		for _, tag in CollectionService:GetTags(inst) do
			CollectionService:RemoveTag(inst, tag)
		end
		if
			inst:IsA("Sound")
			or inst:IsA("Light")
			or inst:IsA("ParticleEmitter")
			or inst:IsA("Fire")
			or inst:IsA("Smoke")
			or inst:IsA("ProximityPrompt")
			or inst:IsA("ClickDetector")
			or inst:IsA("BillboardGui")
			or inst:IsA("BaseScript")
		then
			inst:Destroy()
		end
	end
end

-- Put a copy of `source` into the mirror's world, reflected. Anything behind the glass (its own
-- wall) is left out: reflected, it would land in front of the glass and block the view.
local function reflectInto(mirror: Mirror, source: Instance): Instance
	local copy = source:Clone()
	strip(copy)
	for _, inst in copy:GetDescendants() do
		if inst:IsA("BasePart") then
			if (inst.Position - mirror.origin):Dot(mirror.normal) < 0 then
				inst:Destroy()
			else
				inst.CFrame = reflect(inst.CFrame, mirror.origin, mirror.normal)
			end
		end
	end
	copy.Parent = mirror.view
	return copy
end

local function build(glass: Instance)
	if not glass:IsA("BasePart") or mirrors[glass] then
		return
	end
	local roomName = glass:GetAttribute("Room")
	local missing = glass:GetAttribute("Missing")
	local cabin = workspace:FindFirstChild("Cabin")
	local room = cabin and typeof(roomName) == "string" and cabin:FindFirstChild(roomName)
	if not room then
		return
	end

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 80
	gui.LightInfluence = 0
	local view = Instance.new("ViewportFrame")
	view.Size = UDim2.fromScale(1, 1)
	view.BackgroundColor3 = Color3.fromRGB(10, 9, 8)
	-- Lit like the room: dim and warm, a touch greyer than life.
	view.Ambient = Color3.fromRGB(74, 66, 58)
	view.LightColor = Color3.fromRGB(150, 122, 92)
	view.LightDirection = Vector3.new(0.3, -1, 0.2)
	view.ImageColor3 = Color3.fromRGB(214, 214, 220)
	view.Parent = gui
	local camera = Instance.new("Camera")
	camera.Parent = view
	view.CurrentCamera = camera

	local normal = glass.CFrame.LookVector -- the glass's front faces into the room
	local mirror: Mirror = {
		glass = glass,
		view = view,
		camera = camera,
		origin = glass.Position + normal * (glass.Size.Z / 2),
		normal = normal,
		floorY = glass.Position.Y - 6.5, -- mirrors hang at 6.5 above the floor (ClueSigns)
		triedScare = false,
	}

	local copy = room:Clone()
	local props = copy:FindFirstChild("Props")
	local gone = props and typeof(missing) == "string" and props:FindFirstChild(missing)
	if gone then
		gone:Destroy()
	end
	reflectInto(mirror, copy)
	copy:Destroy()
	gui.Parent = glass
	mirrors[glass] = mirror
end

-- He's behind you, in the mirror only, for a moment.
local function ghost(mirror: Mirror, eye: CFrame)
	local flat = Vector3.new(eye.LookVector.X, 0, eye.LookVector.Z)
	if flat.Magnitude < 0.1 then
		return
	end
	flat = flat.Unit
	local feet = Vector3.new(eye.Position.X, mirror.floorY, eye.Position.Z) - flat * 4.5
	local figure = HollowManModel.build()
	-- Facing your back (his front is -Z).
	figure:PivotTo(CFrame.lookAt(feet, feet + flat))
	local shown = reflectInto(mirror, figure)
	figure:Destroy()
	Audio.play("whisper", 0.8)
	task.delay(1.1, function()
		shown:Destroy()
		Scares.release()
	end)
end

function Reflections.init()
	for _, glass in CollectionService:GetTagged("ReflectionMirror") do
		build(glass)
	end
	CollectionService:GetInstanceAddedSignal("ReflectionMirror"):Connect(function(glass: Instance)
		task.defer(build, glass) -- let its attributes and the room replicate first
	end)
	CollectionService:GetInstanceRemovedSignal("ReflectionMirror"):Connect(function(glass: Instance)
		mirrors[glass :: BasePart] = nil
	end)

	-- Every frame, look through each nearby mirror from your eye.
	RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local eye = cam.CFrame
		for glass, mirror in mirrors do
			if not glass.Parent then
				mirrors[glass] = nil
				continue
			end
			local toGlass = glass.Position - eye.Position
			local distance = toGlass.Magnitude
			if distance > UPDATE_RANGE then
				continue
			end
			-- From behind the wall there's nothing to see.
			local inFront = (eye.Position - mirror.origin):Dot(mirror.normal) > 0
			mirror.view.Visible = inFront
			if not inFront then
				continue
			end
			-- Aim at the glass and open the view just wide enough to fill it.
			local fov = math.deg(2 * math.atan((glass.Size.Y / 2) / math.max(distance, 0.5)))
			mirror.camera.FieldOfView = math.clamp(fov, 4, 110)
			mirror.camera.CFrame = CFrame.lookAt(eye.Position, glass.Position, glass.CFrame.UpVector)

			-- Leaning in close and looking straight at it: sometimes, him.
			if not mirror.triedScare and distance < 9 and eye.LookVector:Dot(toGlass.Unit) > 0.9 then
				mirror.triedScare = true
				if rng:NextNumber() < GHOST_CHANCE and Scares.claim() then
					ghost(mirror, eye)
				end
			end
		end
	end)
end

return Reflections
