--!strict
-- Draws a card as GUI so the same design is used in your hand (ScreenGui) and on the table
-- (SurfaceGui). Everything is laid out in scale, so it fits any card size.
--   front: aged parchment with a fine double ink border and corner diamonds; the card type in
--     small coloured capitals, the title, art, and the rules text.
--     Room art is the room seen from above with its doorways; Progress art is the time it adds;
--     Event art is an open red eye.
--   back: dark green with a brass border and a pine emblem.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CardData = require(Shared:WaitForChild("CardData"))
local Config = require(Shared:WaitForChild("Config"))

local EDGE = Color3.fromRGB(176, 154, 116) -- worn paper edge
local PAPER = Color3.fromRGB(230, 218, 190)
local ART_BG = Color3.fromRGB(214, 198, 164)
local INK = Color3.fromRGB(44, 32, 24)
local FLOOR = Color3.fromRGB(124, 92, 62)
local WALL = Color3.fromRGB(46, 32, 24)
local BACK = Color3.fromRGB(20, 30, 24)
local BRASS = Color3.fromRGB(150, 120, 70)
local PINE = Color3.fromRGB(44, 70, 50)

local ACCENT: { [string]: Color3 } = {
	Room = Color3.fromRGB(140, 98, 58),
	Progress = Color3.fromRGB(70, 100, 150),
	Event = Color3.fromRGB(160, 30, 30),
	Clue = Color3.fromRGB(106, 82, 140),
	Exit = Color3.fromRGB(56, 116, 86),
}

local CardFace = {}

local function frame(parent: Instance, name: string, pos: UDim2, size: UDim2, color: Color3): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Position = pos
	f.Size = size
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function round(obj: GuiObject, scale: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(scale, 0)
	c.Parent = obj
end

local function label(parent: Instance, name: string, text: string, pos: UDim2, size: UDim2, font: Enum.Font, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Position = pos
	l.Size = size
	l.BackgroundTransparency = 1
	l.Text = text
	l.Font = font
	l.TextColor3 = color
	l.TextScaled = true
	l.TextWrapped = true
	l.Parent = parent
	return l
end

local function centred(f: GuiObject)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
end

-- Fine double ink border with a small diamond at each corner, like an old printed card.
local function ornamentBorder(inner: Frame)
	for i, inset in { 0.035, 0.055 } do
		local line = frame(inner, "Border", UDim2.fromScale(inset, inset * 0.72), UDim2.fromScale(1 - inset * 2, 1 - inset * 1.44), PAPER)
		line.BackgroundTransparency = 1
		local stroke = Instance.new("UIStroke")
		stroke.Color = INK
		stroke.Thickness = if i == 1 then 1.5 else 0.8
		stroke.Transparency = 0.15
		stroke.Parent = line
	end
	for _, corner in { Vector2.new(0.045, 0.032), Vector2.new(0.955, 0.032), Vector2.new(0.045, 0.968), Vector2.new(0.955, 0.968) } do
		local diamond = frame(inner, "Corner", UDim2.fromScale(corner.X, corner.Y), UDim2.fromScale(0.07, 0.07), INK)
		diamond.AnchorPoint = Vector2.new(0.5, 0.5)
		diamond.Rotation = 45
		diamond.ZIndex = 2
		local square = Instance.new("UIAspectRatioConstraint")
		square.Parent = diamond
		local dot = frame(diamond, "Dot", UDim2.fromScale(0.3, 0.3), UDim2.fromScale(0.4, 0.4), PAPER)
		dot.ZIndex = 3
	end
end

-- The room from above: floor, walls, and a gap with a warm glow for each doorway.
local function roomArt(art: Frame, doors: { string })
	local floor = frame(art, "Floor", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.78, 0.78), FLOOR)
	centred(floor)
	local square = Instance.new("UIAspectRatioConstraint")
	square.AspectRatio = 1
	square.DominantAxis = Enum.DominantAxis.Height
	square.Parent = floor

	local hasDoor: { [string]: boolean } = {}
	for _, d in doors do
		hasDoor[d] = true
	end
	local t = 0.12
	local function bar(side: string, from: number, to: number, color: Color3)
		local pos, size
		if side == "N" then
			pos, size = UDim2.fromScale(from, 0), UDim2.fromScale(to - from, t)
		elseif side == "S" then
			pos, size = UDim2.fromScale(from, 1 - t), UDim2.fromScale(to - from, t)
		elseif side == "W" then
			pos, size = UDim2.fromScale(0, from), UDim2.fromScale(t, to - from)
		else
			pos, size = UDim2.fromScale(1 - t, from), UDim2.fromScale(t, to - from)
		end
		frame(floor, `Wall{side}`, pos, size, color)
	end
	for _, side in { "N", "E", "S", "W" } do
		if hasDoor[side] then
			bar(side, 0, 0.36, WALL)
			bar(side, 0.64, 1, WALL)
			bar(side, 0.36, 0.64, Color3.fromRGB(240, 196, 120))
		else
			bar(side, 0, 1, WALL)
		end
	end
end

local function progressArt(art: Frame, minutes: number)
	local ring = frame(art, "Ring", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.8, 0.8), ART_BG)
	centred(ring)
	round(ring, 1)
	local square = Instance.new("UIAspectRatioConstraint")
	square.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Color = ACCENT.Progress
	stroke.Thickness = 3
	stroke.Parent = ring
	label(ring, "Time", `+{minutes}`, UDim2.fromScale(0.1, 0.18), UDim2.fromScale(0.8, 0.45), Enum.Font.Fondamento, INK)
	label(ring, "Unit", "MIN", UDim2.fromScale(0.25, 0.62), UDim2.fromScale(0.5, 0.18), Enum.Font.GothamBold, ACCENT.Progress)
end

-- A keyhole: something to find in the cabin.
local function clueArt(art: Frame)
	art.BackgroundColor3 = Color3.fromRGB(58, 48, 72)
	local hole = frame(art, "Keyhole", UDim2.fromScale(0.5, 0.4), UDim2.fromScale(0.34, 0.34), Color3.fromRGB(14, 12, 18))
	centred(hole)
	round(hole, 1)
	local square = Instance.new("UIAspectRatioConstraint")
	square.Parent = hole
	local slot = frame(art, "Slot", UDim2.fromScale(0.5, 0.66), UDim2.fromScale(0.12, 0.34), Color3.fromRGB(14, 12, 18))
	centred(slot)
end

local function eventArt(art: Frame)
	art.BackgroundColor3 = Color3.fromRGB(40, 12, 12)
	local eye = frame(art, "Eye", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.8, 0.42), Color3.fromRGB(220, 206, 190))
	centred(eye)
	round(eye, 1)
	local iris = frame(eye, "Iris", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.42, 0.95), ACCENT.Event)
	centred(iris)
	round(iris, 1)
	local pupil = frame(iris, "Pupil", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.18, 0.8), Color3.new(0, 0, 0))
	centred(pupil)
	round(pupil, 1)
end

-- Build the face of this card filling `parent`.
function CardFace.front(parent: Instance, cardId: string): Frame
	local def = CardData.get(cardId)
	local accent = ACCENT[def.type] or INK

	-- Aged parchment: a worn edge, cream paper, a fine double ink border with corner diamonds.
	local root = frame(parent, "CardFront", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), EDGE)
	round(root, 0.05)
	local inner = frame(root, "Inner", UDim2.fromScale(0.025, 0.018), UDim2.fromScale(0.95, 0.964), PAPER)
	round(inner, 0.04)
	ornamentBorder(inner)

	-- The card type in small coloured capitals over a thin rule.
	local kind = string.upper(def.type)
	if def.red then
		kind = "RED CARD"
	elseif def.type == "Progress" then
		kind = `PROGRESS · +{(Config.ProgressSteps[def.id] or 0) * Config.Clock.StepMinutes} MIN`
	elseif def.type == "Room" and def.doors then
		kind = `{if def.exit then "EXIT ROOM" else "ROOM"} · {#def.doors} DOOR{if #def.doors == 1 then "" else "S"}`
	end
	label(inner, "Type", kind, UDim2.fromScale(0.12, 0.06), UDim2.fromScale(0.76, 0.055), Enum.Font.GothamBold, accent)
	frame(inner, "Rule", UDim2.fromScale(0.2, 0.125), UDim2.fromScale(0.6, 0.006), accent)

	label(inner, "Title", def.name, UDim2.fromScale(0.08, 0.14), UDim2.fromScale(0.84, 0.12), Enum.Font.Fondamento, INK)

	local art = frame(inner, "Art", UDim2.fromScale(0.12, 0.28), UDim2.fromScale(0.76, 0.42), ART_BG)
	round(art, 0.04)
	local artLine = Instance.new("UIStroke")
	artLine.Color = INK
	artLine.Thickness = 1
	artLine.Transparency = 0.3
	artLine.Parent = art
	if def.type == "Room" and def.doors then
		roomArt(art, def.doors)
	elseif def.type == "Progress" then
		progressArt(art, (Config.ProgressSteps[def.id] or 0) * Config.Clock.StepMinutes)
	elseif def.type == "Event" then
		eventArt(art)
	elseif def.type == "Clue" then
		clueArt(art)
	end

	local text = label(inner, "Text", def.text, UDim2.fromScale(0.11, 0.73), UDim2.fromScale(0.78, 0.2), Enum.Font.Merriweather, INK)
	text.TextYAlignment = Enum.TextYAlignment.Top
	return root
end

-- A cabin-map tile on the table: parchment with a fine border and the room's name.
-- (The tile's walls and doorways are drawn as parts by MapTiles, so they turn with the room.)
function CardFace.tile(parent: Instance, cardId: string): Frame
	local def = CardData.get(cardId)
	local root = frame(parent, "Tile", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), PAPER)
	root.BackgroundTransparency = 1
	ornamentBorder(root)
	local name = label(root, "Name", def.name, UDim2.fromScale(0.16, 0.36), UDim2.fromScale(0.68, 0.28), Enum.Font.Fondamento, INK)
	name.TextWrapped = true
	return root
end

-- Build the card back filling `parent`.
function CardFace.back(parent: Instance): Frame
	local root = frame(parent, "CardBack", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), EDGE)
	round(root, 0.06)
	local inner = frame(root, "Inner", UDim2.fromScale(0.06, 0.045), UDim2.fromScale(0.88, 0.91), BACK)
	round(inner, 0.05)
	local stroke = Instance.new("UIStroke")
	stroke.Color = BRASS
	stroke.Thickness = 2
	stroke.Parent = inner

	-- A pine: three stacked diamonds and a trunk.
	local emblem = frame(inner, "Emblem", UDim2.fromScale(0.5, 0.45), UDim2.fromScale(0.6, 0.6), BACK)
	centred(emblem)
	local square = Instance.new("UIAspectRatioConstraint")
	square.Parent = emblem
	for i, s in { 0.62, 0.48, 0.34 } do
		local tier = frame(emblem, "Tier", UDim2.fromScale(0.5, 0.62 - (i - 1) * 0.17), UDim2.fromScale(s, s), PINE)
		centred(tier)
		tier.Rotation = 45
	end
	frame(emblem, "Trunk", UDim2.fromScale(0.45, 0.8), UDim2.fromScale(0.1, 0.18), Color3.fromRGB(70, 50, 34))
	label(inner, "Name", "HOLLOW PINES", UDim2.fromScale(0.1, 0.82), UDim2.fromScale(0.8, 0.08), Enum.Font.Fondamento, BRASS)
	return root
end

return CardFace
