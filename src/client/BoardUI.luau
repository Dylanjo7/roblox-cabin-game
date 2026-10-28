--!strict
-- The board. When you must place a room, the camera zooms onto the cabin map on the table.
-- Hover a cell to see the room there, R rotates, scroll zooms, left click places.
-- B leaves or reopens the board at any time (standing up leaves it too). Leaving doesn't cancel:
-- the room stays committed until it is placed.
-- The Place prompt only shows where one of the room's doorways lines up with an open doorway,
-- using the server's list of legal spots. The server re-checks every placement.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local MapTiles = require(Shared:WaitForChild("MapTiles"))
local MapView = require(Shared:WaitForChild("MapView"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local RoomShapes = require(Shared:WaitForChild("RoomShapes"))
local Types = require(Shared:WaitForChild("Types"))

local Hud = require(script.Parent.Hud)

local VALID = Color3.fromRGB(120, 210, 130)
local INVALID = Color3.fromRGB(210, 90, 80)
local RENDER_STEP = "HollowPinesBoard"
local BOARD_HINT = "R rotate  ·  Scroll zoom  ·  Left click place  ·  B leave board"
local AWAY_HINT = "You still have a room to place  ·  B opens the board"

local BoardUI = {}

local camera = workspace.CurrentCamera
local options: Types.PlacementOptions? = nil
local viewing = false -- the board camera is active
local rotation = 0
local height = Config.Board.CameraHeight
local hoverX: number? = nil
local hoverZ: number? = nil
local busy = false
local view: MapView.View = MapView.compute({}) -- how the table map is zoomed (from the built cabin)

local overlay: Folder -- local-only parts: legal-cell markers, grid border, ghost
local markers: Folder
local ghost: Model? = nil
local prompt: TextLabel
local hint: TextLabel

local function isLegal(x: number, z: number, r: number): boolean
	local current = options
	if not current then
		return false
	end
	for _, p in current.placements do
		if p.x == x and p.z == z and p.rotation == r then
			return true
		end
	end
	return false
end

-- The centre of the table's map disk (the map is always centred on it).
local function mapCenter(): Vector3
	return Config.ParlorOrigin + Vector3.new(0, Config.Table.TopHeight + Config.Table.CenterRaise, 0)
end

-- Straight down at the map, north at the top of the screen.
local function targetCFrame(): CFrame
	local center = mapCenter()
	return CFrame.lookAt(center + Vector3.new(0, height, 0), center, Vector3.new(0, 0, -1))
end

local function cellUnderMouse(): (number?, number?)
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local planeY = mapCenter().Y
	if math.abs(ray.Direction.Y) < 1e-4 then
		return nil, nil
	end
	local t = (planeY - ray.Origin.Y) / ray.Direction.Y
	if t < 0 then
		return nil, nil
	end
	local hit = ray.Origin + ray.Direction * t
	local x, z = MapView.cellAt(view, hit)
	if not RoomShapes.inBounds(x, z) or not MapView.shows(view, x, z) then
		return nil, nil
	end
	return x, z
end

-- Faint squares on every cell where the room fits at the current rotation, plus the grid border.
local function drawMarkers()
	markers:ClearAllChildren()
	local current = options
	if not current then
		return
	end
	for _, p in current.placements do
		if p.rotation == rotation then
			MapTiles.marker(view, p.x, p.z, VALID, 0.65, markers)
		end
	end
	-- Border round the cells shown (the built cabin plus a ring around it), kept inside the build bounds.
	local s = view.size
	local lo = MapView.cellPosition(view, math.max(view.minX, Config.GridMin), math.max(view.minZ, Config.GridMin)) - Vector3.new(s / 2, 0, s / 2)
	local hi = MapView.cellPosition(view, math.min(view.maxX, Config.GridMax), math.min(view.maxZ, Config.GridMax)) + Vector3.new(s / 2, 0, s / 2)
	local mid = (lo + hi) / 2
	local w, d = hi.X - lo.X, hi.Z - lo.Z
	local edges = {
		{ Vector3.new(w, 0.02, 0.04), Vector3.new(mid.X, mid.Y, lo.Z) },
		{ Vector3.new(w, 0.02, 0.04), Vector3.new(mid.X, mid.Y, hi.Z) },
		{ Vector3.new(0.04, 0.02, d), Vector3.new(lo.X, mid.Y, mid.Z) },
		{ Vector3.new(0.04, 0.02, d), Vector3.new(hi.X, mid.Y, mid.Z) },
	}
	for i, edge in edges do
		local p = Instance.new("Part")
		p.Name = `Border{i}`
		p.Size = edge[1]
		p.Position = edge[2] + Vector3.new(0, 0.01, 0)
		p.Color = Color3.fromRGB(235, 225, 200)
		p.Transparency = 0.4
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.Parent = markers
	end
end

local function drawGhost()
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	local current = options
	local x, z = hoverX, hoverZ
	if not current or not x or not z then
		return
	end
	local color = if isLegal(x, z, rotation) then VALID else INVALID
	ghost = MapTiles.make(view, current.cardId, x, z, rotation, overlay, color, 0.25)
end

local function onRender()
	camera.CFrame = camera.CFrame:Lerp(targetCFrame(), Config.Board.CameraSmoothing)

	local x, z = cellUnderMouse()
	if x ~= hoverX or z ~= hoverZ then
		hoverX, hoverZ = x, z
		drawGhost()
	end

	local legal = x ~= nil and z ~= nil and isLegal(x, z, rotation)
	prompt.Visible = legal
	if legal then
		local mouse = UserInputService:GetMouseLocation()
		prompt.Position = UDim2.fromOffset(mouse.X + 18, mouse.Y - 18)
	end
end

local function openView()
	if viewing then
		return
	end
	viewing = true
	camera.CameraType = Enum.CameraType.Scriptable
	height = Config.Board.CameraHeight
	hoverX, hoverZ = nil, nil
	drawMarkers()
	hint.Text = BOARD_HINT
	hint.Visible = true
	RunService:BindToRenderStep(RENDER_STEP, Enum.RenderPriority.Camera.Value + 1, onRender)
end

local function closeView()
	if viewing then
		viewing = false
		RunService:UnbindFromRenderStep(RENDER_STEP)
		markers:ClearAllChildren()
		if ghost then
			ghost:Destroy()
			ghost = nil
		end
		prompt.Visible = false
		-- Roblox's default camera can't start from a straight-down view (its pitch clamp errors
		-- every frame and the camera freezes), so put it back behind the character first.
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local look = root.CFrame.LookVector
			camera.CFrame = CFrame.lookAt(root.Position - look * 10 + Vector3.new(0, 4, 0), root.Position)
		else
			camera.CFrame = CFrame.lookAt(camera.CFrame.Position, camera.CFrame.Position + Vector3.new(0, -0.4, -1))
		end
		camera.CameraType = Enum.CameraType.Custom
	end
	-- Still committed to a room: keep a reminder on screen.
	hint.Text = AWAY_HINT
	hint.Visible = options ~= nil
end

local function tryPlace()
	local x, z = hoverX, hoverZ
	if busy or not viewing or not options or not x or not z or not isLegal(x, z, rotation) then
		return
	end
	busy = true
	local ok, err = Remotes.func("RequestPlaceRoom"):InvokeServer(x, z, rotation)
	busy = false
	if not ok and err then
		Hud.toast(err)
	end
end

function BoardUI.init(gui: ScreenGui)
	overlay = Instance.new("Folder")
	overlay.Name = "BoardOverlay"
	overlay.Parent = workspace
	markers = Instance.new("Folder")
	markers.Name = "Markers"
	markers.Parent = overlay

	prompt = Instance.new("TextLabel")
	prompt.Name = "PlacePrompt"
	prompt.AnchorPoint = Vector2.new(0, 1)
	prompt.Size = UDim2.fromOffset(110, 30)
	prompt.BackgroundColor3 = Color3.fromRGB(40, 90, 50)
	prompt.TextColor3 = Color3.fromRGB(240, 240, 230)
	prompt.Font = Enum.Font.GothamBold
	prompt.TextSize = 16
	prompt.Text = "Place (click)"
	prompt.Visible = false
	prompt.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = prompt

	hint = Instance.new("TextLabel")
	hint.Name = "BoardHint"
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -16)
	hint.Size = UDim2.fromOffset(560, 30)
	hint.BackgroundColor3 = Color3.fromRGB(18, 20, 18)
	hint.BackgroundTransparency = 0.3
	hint.TextColor3 = Color3.fromRGB(230, 222, 200)
	hint.Font = Enum.Font.GothamMedium
	hint.TextSize = 16
	hint.Text = BOARD_HINT
	hint.Visible = false
	hint.Parent = gui
	local hintCorner = Instance.new("UICorner")
	hintCorner.CornerRadius = UDim.new(0, 6)
	hintCorner.Parent = hint

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if viewing and not gameProcessed and input.UserInputType == Enum.UserInputType.MouseButton1 then
			tryPlace()
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if viewing and input.UserInputType == Enum.UserInputType.MouseWheel then
			local cfg = Config.Board
			height = math.clamp(height - input.Position.Z * cfg.ZoomStep, cfg.MinHeight, cfg.MaxHeight)
		end
	end)

	-- Standing up leaves the board.
	local function watchSeat(character: Model)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.Seated:Connect(function(active: boolean)
			if not active then
				closeView()
			end
		end)
	end
	local localPlayer = Players.LocalPlayer
	if localPlayer.Character then
		task.spawn(watchSeat, localPlayer.Character)
	end
	localPlayer.CharacterAdded:Connect(watchSeat)
end

function BoardUI.setOptions(newOptions: Types.PlacementOptions?)
	local wasPlacing = options ~= nil
	options = newOptions
	if newOptions then
		if #newOptions.placements > 0 then
			rotation = newOptions.placements[1].rotation
		end
		if not wasPlacing then
			openView()
		elseif viewing then
			drawMarkers()
			drawGhost()
		end
	else
		closeView()
	end
end

-- Keep the zoom in step with the built cabin (public state).
function BoardUI.setCabin(cells: { Types.CellPublic })
	local new = MapView.compute(cells)
	local same = new.size == view.size and new.cx == view.cx and new.cz == view.cz
	view = new
	if viewing and not same then
		drawMarkers()
		drawGhost()
	end
end

-- B: leave the board, or go back to it while a room is still waiting to be placed.
function BoardUI.toggle()
	if viewing then
		closeView()
	elseif options then
		openView()
	end
end

function BoardUI.rotate()
	if viewing and options then
		rotation = (rotation + 1) % 4
		drawMarkers()
		drawGhost()
	end
end

function BoardUI.isViewing(): boolean
	return viewing
end

return BoardUI
