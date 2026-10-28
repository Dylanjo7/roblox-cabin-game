--!strict
-- Builds the Parlor table from placeholder parts and owns its seats and the rotating outer ring.
-- The fixed centre disk holds the cabin map. The ring carries the card stand (draw slot + Altar),
-- the clock track and every played card, and turns so the stand sits right in front of the active seat.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CardFace = require(Shared:WaitForChild("CardFace"))
local Config = require(Shared:WaitForChild("Config"))
local ClockTrack = require(Shared:WaitForChild("ClockTrack"))

local WOOD = Color3.fromRGB(92, 64, 44)
local DARK_WOOD = Color3.fromRGB(52, 36, 26)
local BAND = Color3.fromRGB(74, 54, 40)
local CARD_BACK = Color3.fromRGB(28, 34, 30)
local SEAT = Color3.fromRGB(110, 80, 56)
local BRASS = Color3.fromRGB(176, 140, 72)
local CARD_SIZE = Vector3.new(0.75, 0.05, 1.05) -- lying flat: width, thickness, length

local Table = {}

local seats: { Seat } = {}
local ring: Model
local playedFolder: Folder
local drawSlot: Part
local altarTray: Part
local altarStack: Folder
local center = CFrame.new()
local ringAngle = 0
local playedCount = 0
local angleValue = Instance.new("NumberValue")
local seatChanged = Instance.new("BindableEvent")
local drawClicked = Instance.new("BindableEvent")

-- Fires (seatIndex: number, player: Player?) whenever someone sits down or stands up.
Table.SeatChanged = seatChanged.Event
-- Fires (player: Player) when someone clicks the face-down card in the draw slot.
Table.DrawClicked = drawClicked.Event

local function makePart(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Wood -- metal and glass parts override this
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Vertical cylinder centred on cf.
local function makeCylinder(name: string, radius: number, height: number, cf: CFrame, color: Color3, parent: Instance): Part
	local p = makePart(name, Vector3.new(height, radius * 2, radius * 2), cf * CFrame.Angles(0, 0, math.rad(90)), color, parent)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function addLabel(p: BasePart, text: string, face: Enum.NormalId, pixelsPerStud: number?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud or 50
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(235, 225, 200)
	label.Text = text
	label.Parent = gui
	gui.Parent = p
end

local function playerIn(seat: Seat): Player?
	local humanoid = seat.Occupant
	if not humanoid then
		return nil
	end
	return Players:GetPlayerFromCharacter(humanoid.Parent :: Model)
end

function Table.seatAngle(index: number): number
	return (index - 1) * (2 * math.pi / Config.Table.SeatCount)
end

function Table.seatPart(index: number): Seat
	return seats[index]
end

-- First seat with nobody in it, if any.
function Table.freeSeat(): number?
	for i, seat in seats do
		if not seat.Occupant then
			return i
		end
	end
	return nil
end

-- Get everyone out of their chairs (back in the lobby after a run, so sitting down again is what
-- starts the next one).
function Table.standAll()
	for _, seat in seats do
		local humanoid = seat.Occupant
		if humanoid then
			local weld = seat:FindFirstChild("SeatWeld")
			if weld then
				weld:Destroy()
			end
			humanoid.Sit = false
		end
	end
end

function Table.seatOf(player: Player): number?
	for i, seat in seats do
		if playerIn(seat) == player then
			return i
		end
	end
	return nil
end

local trackLocal = ClockTrack.localCFrame

-- Ring-local CFrame of the i-th played card (0-based). Cards go round the ring, skipping the
-- stand; after a full lap they stack on top of the earlier ones.
local function playedSlotLocal(index: number): CFrame
	local cfg = Config.Table
	local slots = cfg.PlayedCardSlots
	local gap = math.rad(cfg.PlayedCardGapDegrees)
	local lap = index // slots
	local angle = gap + (index % slots) * (2 * math.pi - 2 * gap) / (slots - 1)
	return CFrame.Angles(0, angle, 0) * CFrame.new(0, cfg.TopHeight + CARD_SIZE.Y / 2 + lap * 0.06, cfg.PlayedCardRadius)
end

-- The Candle and Hollow Man pieces are drawn and animated by each client (TablePieces): the
-- server only publishes where they are, as attributes on the ring.
function Table.setClock(candle: number, hollow: number?)
	ring:SetAttribute("CandleStep", candle)
	ring:SetAttribute("HollowStep", hollow or -1)
end

-- Text engraved flat on the ring, readable from outside the table (its top faces the centre).
local function engrave(parent: Instance, name: string, text: string, size: Vector2, cf: CFrame, color: Color3, font: Enum.Font)
	local plate = makePart(name, Vector3.new(size.X, 0.02, size.Y), cf, BAND, parent)
	plate.Transparency = 1
	plate.CanCollide = false
	plate.CanQuery = false
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 120
	gui.LightInfluence = 0.7
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = font
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	gui.Parent = plate
end

-- The clock track engraved round the ring: a groove, hour marks with numerals (9 to 3),
-- half-hour studs, and the words carved into the gap behind the stand.
local function buildTrack(model: Model, origin: CFrame)
	local cfg = Config.Table
	local markY = 0.035
	-- The groove: short segments following the arc.
	local segments = Config.Clock.Steps * 3
	for i = 0, segments - 1 do
		local a = origin * trackLocal(i / 3, cfg.MarkRadius)
		local b = origin * trackLocal((i + 1) / 3, cfg.MarkRadius)
		local length = (b.Position - a.Position).Magnitude
		local groove = makePart("Groove", Vector3.new(0.09, 0.03, length + 0.02), CFrame.lookAt((a.Position + b.Position) / 2, b.Position) * CFrame.new(0, 0.015, 0), Color3.fromRGB(34, 24, 18), model)
		groove.CanCollide = false
		groove.CastShadow = false
	end
	for step = 0, Config.Clock.Steps do
		local onHour = step % 2 == 0
		local at = origin * trackLocal(step, cfg.MarkRadius) * CFrame.new(0, markY, 0)
		if onHour then
			local mark = makePart(`Mark{step}`, Vector3.new(0.12, 0.07, 0.55), at, BRASS, model)
			mark.Material = Enum.Material.Metal
			mark.CanCollide = false
			local hour = (9 + step // 2 - 1) % 12 + 1
			engrave(model, `Numeral{step}`, tostring(hour), Vector2.new(0.75, 0.6), origin * trackLocal(step, cfg.NumeralRadius) * CFrame.new(0, 0.03, 0), Color3.fromRGB(226, 206, 160), Enum.Font.Fondamento)
		else
			local stud = makePart(`Mark{step}`, Vector3.new(0.2, 0.08, 0.2), at, BRASS, model)
			stud.Shape = Enum.PartType.Ball
			stud.Material = Enum.Material.Metal
			stud.CanCollide = false
		end
	end
	-- Carved into the rim, in the gap behind the stand.
	engrave(model, "Carving", "PLAY UNTIL THREE", Vector2.new(4.2, 0.6), origin * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, cfg.TopHeight + 0.03, cfg.MarkRadius), Color3.fromRGB(180, 150, 110), Enum.Font.Fondamento)
end

-- Draw a card design (CardFace) onto one face of a part.
local function cardGui(p: BasePart, face: Enum.NormalId, cardId: string?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 200
	gui.LightInfluence = 0.8
	if cardId then
		CardFace.front(gui, cardId)
	else
		CardFace.back(gui)
	end
	gui.Parent = p
end

-- The card box: a small dark wooden box at the edge of the ring, right in front of the active
-- seat (the ring turns it to whoever's turn it is). "It is your turn" is carved on its front in
-- a crooked hand, the next card sticks out of a slot underneath towards you (click it to take
-- it), and the Altar's clue cards stand in a tilted rack on top, the active one facing you.
-- In the box's frame the player is towards -Z.
local function buildStand(model: Model, origin: CFrame)
	local cfg = Config.Table
	local base = origin * CFrame.new(0, cfg.TopHeight, cfg.StandRadius) * CFrame.Angles(0, math.pi, 0)
	local w, h, d = 2.3, 0.85, 1.0
	local zc = 0.1 -- box centre: its back stays clear of the map disk
	local body = makePart("CardBox", Vector3.new(w, h, d), base * CFrame.new(0, 0.12 + h / 2, zc), DARK_WOOD, model)
	body.Material = Enum.Material.WoodPlanks
	-- A plinth it sits on (the slot is the gap between the two) and a moulding round the lid.
	makePart("Plinth", Vector3.new(w + 0.12, 0.1, d + 0.12), base * CFrame.new(0, 0.05, zc), DARK_WOOD, model)
	makePart("Lid", Vector3.new(w + 0.1, 0.08, d + 0.1), body.CFrame * CFrame.new(0, h / 2 + 0.04, 0), WOOD, model)
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			local bracket = makePart("Bracket", Vector3.new(0.14, 0.14, 0.03), body.CFrame * CFrame.new(x * (w / 2 - 0.1), y * (h / 2 - 0.1), -d / 2 - 0.015), Color3.fromRGB(60, 56, 50), model)
			bracket.Material = Enum.Material.Metal
		end
	end

	-- The carved plaque.
	local plaque = makePart("Plaque", Vector3.new(w - 0.4, 0.42, 0.03), body.CFrame * CFrame.new(0, 0.04, -d / 2 - 0.015), Color3.fromRGB(40, 28, 20), model)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 140
	gui.LightInfluence = 0.6
	local carved = Instance.new("TextLabel")
	carved.Size = UDim2.fromScale(1, 1)
	carved.BackgroundTransparency = 1
	carved.TextScaled = true
	carved.Font = Enum.Font.Creepster
	carved.TextColor3 = Color3.fromRGB(214, 196, 160)
	carved.TextStrokeColor3 = Color3.fromRGB(16, 10, 8)
	carved.TextStrokeTransparency = 0.3
	carved.Text = "It is your turn"
	carved.Parent = gui
	gui.Parent = plaque

	-- The next card, face down, sticking half out of the slot towards you.
	drawSlot = makePart("DrawSlot", CARD_SIZE, base * CFrame.new(0, 0.12, zc - d / 2 - CARD_SIZE.Z / 2 + 0.3) * CFrame.Angles(math.rad(-4), 0, 0), CARD_BACK, model)
	cardGui(drawSlot, Enum.NormalId.Top, nil)
	cardGui(drawSlot, Enum.NormalId.Bottom, nil)
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = cfg.SeatRadius + 3
	click.MouseClick:Connect(function(player: Player)
		drawClicked:Fire(player)
	end)
	click.Parent = drawSlot

	-- The Altar: a rack on the lid, tilted towards you, where the Clue cards stack.
	altarTray = makePart("Altar", Vector3.new(w - 0.2, 0.12, d - 0.1), body.CFrame * CFrame.new(0, h / 2 + 0.2, 0.05) * CFrame.Angles(math.rad(-25), 0, 0), WOOD, model)
	addLabel(altarTray, "ALTAR", Enum.NormalId.Front, 100)
	makePart("AltarLip", Vector3.new(w - 0.2, 0.12, 0.06), altarTray.CFrame * CFrame.new(0, 0.1, -(d - 0.1) / 2), WOOD, model)
	altarStack = Instance.new("Folder")
	altarStack.Name = "AltarStack"
	altarStack.Parent = model
end

-- A card lying flat: its face (or its back, if faceId is nil) on top, the back underneath.
local function makeCard(name: string, cf: CFrame, faceId: string?, parent: Instance): Part
	local card = makePart(name, CARD_SIZE, cf, CARD_BACK, parent)
	card.CanCollide = false
	card.CanQuery = false
	card.CanTouch = false
	card.CastShadow = false
	cardGui(card, Enum.NormalId.Top, faceId)
	cardGui(card, Enum.NormalId.Bottom, nil)
	return card
end

-- Where a player's cards are held: just in front of their chest, over the table edge.
local function handCFrame(player: Player): CFrame
	local seatIndex = Table.seatOf(player)
	local from: Vector3
	if seatIndex then
		from = seats[seatIndex].Position
	else
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		from = if root and root:IsA("BasePart") then root.Position else (center * CFrame.new(0, 0, Config.Table.SeatRadius)).Position
	end
	local inward = Vector3.new(center.X - from.X, 0, center.Z - from.Z)
	inward = if inward.Magnitude > 1e-3 then inward.Unit else Vector3.zAxis
	local pos = from + inward * 1.6 + Vector3.new(0, 2.4, 0)
	return CFrame.lookAt(pos, pos + inward) * CFrame.Angles(math.rad(50), 0, 0)
end

-- Fly a card along an arc. The target is re-read every frame so it follows the turning ring.
local function flyCard(card: BasePart, from: CFrame, target: () -> CFrame, onDone: () -> ())
	local alpha = Instance.new("NumberValue")
	alpha.Changed:Connect(function(a: number)
		card.CFrame = from:Lerp(target(), a) + Vector3.new(0, math.sin(a * math.pi) * 1.2, 0)
	end)
	local info = TweenInfo.new(Config.Table.CardFlySeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(alpha, info, { Value = 1 })
	tween.Completed:Once(function()
		alpha:Destroy()
		onDone()
	end)
	tween:Play()
end

-- World CFrame for the i-th card (1 = bottom) in the Altar stack.
local function altarSlot(index: number): CFrame
	return altarTray.CFrame * CFrame.new(0, 0.075 + CARD_SIZE.Y / 2 + (index - 1) * 0.05, 0) * CFrame.Angles(0, math.rad(90), 0)
end

-- Redraw the Altar stack from these card ids (top first), top card face up.
function Table.setAltar(ids: { string })
	altarStack:ClearAllChildren()
	for i = #ids, 1, -1 do
		local index = #ids - i + 1
		makeCard(`Clue{index}`, altarSlot(index), ids[i], altarStack)
	end
end

-- A played Clue card flies from the player onto the top of the Altar.
function Table.flyToAltar(cardId: string, player: Player)
	local start = handCFrame(player)
	local card = makeCard("ClueInFlight", start, cardId, workspace)
	local index = #altarStack:GetChildren() + 1
	flyCard(card, start, function()
		return altarSlot(index)
	end, function()
		card:Destroy()
	end)
end

-- A face-down card lifts out of the draw slot (or a clue off the Altar) and flies to the player.
function Table.animateDraw(player: Player, fromAltar: boolean?)
	local start = if fromAltar then altarSlot(#altarStack:GetChildren() + 1) else drawSlot.CFrame
	local card = makeCard("DrawnCard", start, nil, workspace)
	flyCard(card, start, function()
		return handCFrame(player)
	end, function()
		card:Destroy()
	end)
end

-- A played card flies from the player (or, for an Event, straight out of the draw slot, face up)
-- and lands face up on the ring, where it stays for the run and turns with the ring.
function Table.addPlayedCard(cardId: string, player: Player?, fromDrawSlot: boolean?)
	local slot = playedSlotLocal(playedCount)
	playedCount += 1
	local start = if fromDrawSlot
		then drawSlot.CFrame
		elseif player then handCFrame(player)
		else ring:GetPivot() * slot * CFrame.new(0, 2, 0)
	local card = makeCard(`Played{playedCount}`, start, cardId, workspace)
	flyCard(card, start, function()
		return ring:GetPivot() * slot
	end, function()
		card.CFrame = ring:GetPivot() * slot
		card.Parent = playedFolder
	end)
end

function Table.clearPlayedCards()
	playedFolder:ClearAllChildren()
	playedCount = 0
end

-- Turn the outer ring (the shortest way round) so the card stand faces this seat.
function Table.faceSeat(index: number)
	local target = Table.seatAngle(index)
	local delta = (target - ringAngle + math.pi) % (2 * math.pi) - math.pi
	if math.abs(delta) < 1e-3 then
		return
	end
	ringAngle += delta
	local info = TweenInfo.new(Config.Table.RotateSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	TweenService:Create(angleValue, info, { Value = ringAngle }):Play()
end

local function buildSpawn(parent: Instance)
	-- The default Baseplate spawn sits where the table goes, so the run uses its own.
	for _, inst in workspace:GetDescendants() do
		if inst:IsA("SpawnLocation") then
			inst:Destroy()
		end
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "ParlorSpawn"
	spawn.Size = Vector3.new(4, 1, 4)
	spawn.CFrame = center * CFrame.new(0, -0.4, Config.TileSize / 2 - 4) -- behind Seat1, clear of the wall
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = DARK_WOOD
	spawn.Parent = parent
end

function Table.build()
	local cfg = Config.Table
	center = CFrame.new(Config.ParlorOrigin)

	local model = Instance.new("Model")
	model.Name = "ParlorTable"

	-- Fixed centre disk (the cabin map sits on it), slightly above the ring.
	makeCylinder("Top", cfg.CenterRadius, 0.7, center * CFrame.new(0, cfg.TopHeight + cfg.CenterRaise - 0.35, 0), WOOD, model)
	-- A dark inlay ring around the map, and a fixed apron under the turning band.
	makeCylinder("Inlay", cfg.CenterRadius + 0.18, 0.1, center * CFrame.new(0, cfg.TopHeight - 0.02, 0), Color3.fromRGB(30, 20, 14), model).CanCollide = false
	makeCylinder("Apron", cfg.Radius + 0.15, 0.4, center * CFrame.new(0, cfg.TopHeight - 0.7, 0), DARK_WOOD, model)
	-- A heavy pedestal: column on a wide round foot.
	local legHeight = cfg.TopHeight - 0.5
	makeCylinder("Column", 0.9, legHeight, center * CFrame.new(0, legHeight / 2, 0), DARK_WOOD, model)
	makeCylinder("Foot", 2.6, 0.5, center * CFrame.new(0, 0.25, 0), DARK_WOOD, model)
	makeCylinder("Collar", 1.4, 0.4, center * CFrame.new(0, legHeight - 0.2, 0), DARK_WOOD, model)

	-- Your chair model (ServerStorage.TableChair, front facing +Z) if it's there; otherwise a
	-- built one. Either way an invisible Seat sits on the chair's seat and does the sitting.
	local chairTemplate = ServerStorage:FindFirstChild("TableChair")
	for i = 1, cfg.SeatCount do
		local a = Table.seatAngle(i)
		local floor = (center * CFrame.new(math.sin(a) * cfg.SeatRadius, 0, math.cos(a) * cfg.SeatRadius)).Position
		local facing = CFrame.lookAt(floor, Vector3.new(center.X, floor.Y, center.Z)) -- -Z towards the table
		local seatHeight = 1
		if chairTemplate and chairTemplate:IsA("BasePart") then
			local chair = chairTemplate:Clone()
			chair.Name = `Chair{i}`
			chair.Size = chairTemplate.Size * cfg.ChairScale
			chair.Anchored = true
			chair.CFrame = facing * CFrame.new(0, chair.Size.Y / 2, 0) * CFrame.Angles(0, math.pi, 0)
			chair.Parent = model
			seatHeight = chair.Size.Y * cfg.ChairSeatHeight
		end

		local seat = Instance.new("Seat")
		seat.Name = `Seat{i}`
		seat.Size = Vector3.new(1.8, 0.3, 1.8)
		seat.CFrame = facing * CFrame.new(0, seatHeight - 0.15, 0)
		seat.Color = Color3.fromRGB(96, 34, 32)
		seat.Material = Enum.Material.Fabric
		seat.Anchored = true
		seat.TopSurface = Enum.SurfaceType.Smooth
		seat.Parent = model
		seats[i] = seat

		if not (chairTemplate and chairTemplate:IsA("BasePart")) then
			-- Built chair: a tall slatted back and four legs (the seat faces the table, -Z).
			local chair = Instance.new("Model")
			chair.Name = `Chair{i}`
			makePart("Back", Vector3.new(2.2, 3.6, 0.3), seat.CFrame * CFrame.new(0, 2.2, 1.05), SEAT, chair)
			makePart("BackTop", Vector3.new(2.5, 0.4, 0.45), seat.CFrame * CFrame.new(0, 4.1, 1.05), DARK_WOOD, chair)
			for _, x in { -0.85, 0.85 } do
				for _, z in { -0.85, 0.85 } do
					makePart("Leg", Vector3.new(0.3, 0.6, 0.3), seat.CFrame * CFrame.new(x, -0.6, z), DARK_WOOD, chair).CanCollide = false
				end
			end
			chair.Parent = model
		else
			seat.Transparency = 1 -- the chair model shows; this only seats you
		end
		seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			if not seat.Occupant then
				-- Jumping off lands you back on the seat; don't let it grab you straight away.
				seat.Disabled = true
				task.delay(cfg.SeatCooldownSeconds, function()
					seat.Disabled = false
				end)
			end
			seatChanged:Fire(i, playerIn(seat))
		end)
	end

	-- Rotating outer ring. At angle 0 its local +Z points at Seat1, where the stand sits.
	ring = Instance.new("Model")
	ring.Name = "Ring"
	local hub = makePart("Hub", Vector3.one, center, BAND, ring)
	hub.Transparency = 1
	hub.CanCollide = false
	ring.PrimaryPart = hub
	makeCylinder("Band", cfg.Radius, 0.5, center * CFrame.new(0, cfg.TopHeight - 0.25, 0), BAND, ring)

	buildStand(ring, center)
	buildTrack(ring, center)
	playedFolder = Instance.new("Folder")
	playedFolder.Name = "PlayedCards"
	playedFolder.Parent = ring

	ring.Parent = model
	angleValue.Changed:Connect(function(angle: number)
		ring:PivotTo(center * CFrame.Angles(0, angle, 0))
	end)

	buildSpawn(model)
	model.Parent = workspace
	Table.setClock(0, nil)
end

return Table
