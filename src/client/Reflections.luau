--!strict
-- The Wrong Reflection clue. Roblox has no real mirrors, so each tagged mirror ("ReflectionMirror")
-- shows a live render of its room from where the mirror hangs, with one piece of furniture
-- missing (attribute Missing). You aren't in it either.

local CollectionService = game:GetService("CollectionService")

local Reflections = {}

local function build(glass: Instance)
	if not glass:IsA("BasePart") then
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
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0
	local view = Instance.new("ViewportFrame")
	view.Size = UDim2.fromScale(1, 1)
	view.BackgroundColor3 = Color3.fromRGB(20, 18, 16)
	view.Ambient = Color3.fromRGB(200, 186, 164)
	view.LightColor = Color3.fromRGB(255, 214, 160)
	view.LightDirection = Vector3.new(0.5, -0.8, 0.3)
	view.ImageTransparency = 0.08
	view.Parent = gui

	local copy = room:Clone()
	local props = copy:FindFirstChild("Props")
	local gone = props and typeof(missing) == "string" and props:FindFirstChild(missing)
	if gone then
		gone:Destroy()
	end
	copy.Parent = view

	local camera = Instance.new("Camera")
	camera.FieldOfView = 70
	camera.CFrame = CFrame.lookAt(glass.Position, glass.Position + glass.CFrame.LookVector)
	camera.Parent = view
	view.CurrentCamera = camera
	gui.Parent = glass
end

function Reflections.init()
	for _, glass in CollectionService:GetTagged("ReflectionMirror") do
		build(glass)
	end
	CollectionService:GetInstanceAddedSignal("ReflectionMirror"):Connect(function(glass: Instance)
		task.defer(build, glass) -- let its attributes and the room replicate first
	end)
end

return Reflections
