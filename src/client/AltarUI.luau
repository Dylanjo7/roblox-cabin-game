--!strict
-- The Altar panel: anyone can look through the Clue cards on the Altar (top card = active clue).
-- At the start of your turn (the Draw step) you can take any one of them back instead of drawing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CardFace = require(Shared:WaitForChild("CardFace"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local Hud = require(script.Parent.Hud)
local Style = require(script.Parent.Style)

local CARD = Vector2.new(96, 134)

local AltarUI = {}

local localPlayer = Players.LocalPlayer
local toggle: TextButton
local panel: Frame
local row: ScrollingFrame
local cards: { Types.Card } = {}
local canTake = false
local busy = false

local function button(parent: Instance, text: string, size: UDim2): TextButton
	local b = Style.button(parent, text, size)
	b.TextSize = 16
	return b
end

local function take(uid: number)
	if busy then
		return
	end
	busy = true
	local ok, err = Remotes.func("RequestTakeClue"):InvokeServer(uid)
	busy = false
	if ok then
		panel.Visible = false
	elseif err then
		Hud.toast(err)
	end
end

local function render()
	toggle.Visible = #cards > 0
	toggle.Text = `ALTAR ({#cards})`
	if #cards == 0 then
		panel.Visible = false
	end
	for _, child in row:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for i, card in cards do
		local slot = Instance.new("Frame")
		slot.LayoutOrder = i
		slot.Size = UDim2.fromOffset(CARD.X, CARD.Y + 30)
		slot.BackgroundTransparency = 1
		slot.Parent = row
		local face = Instance.new("Frame")
		face.Size = UDim2.fromOffset(CARD.X, CARD.Y)
		face.BackgroundTransparency = 1
		face.Parent = slot
		CardFace.front(face, card.id)
		if i == 1 then
			local active = Instance.new("TextLabel")
			active.Size = UDim2.new(1, 0, 0, 16)
			active.Position = UDim2.fromOffset(0, -18)
			active.BackgroundTransparency = 1
			active.TextColor3 = Color3.fromRGB(255, 210, 140)
			active.Font = Enum.Font.Fondamento
			active.TextSize = 12
			active.Text = "ACTIVE CLUE"
			active.Parent = slot
		end
		if canTake then
			local b = button(slot, "Take", UDim2.new(1, 0, 0, 26))
			b.Position = UDim2.fromOffset(0, CARD.Y + 4)
			b.Activated:Connect(function()
				take(card.uid)
			end)
		end
	end
end

function AltarUI.init(gui: ScreenGui)
	toggle = button(gui, "ALTAR", UDim2.fromOffset(120, 34))
	toggle.Name = "AltarToggle"
	toggle.AnchorPoint = Vector2.new(0, 1)
	toggle.Position = UDim2.new(0, 16, 1, -16)
	toggle.Visible = false

	panel = Instance.new("Frame")
	panel.Name = "Altar"
	panel.AnchorPoint = Vector2.new(0, 1)
	panel.Position = UDim2.new(0, 16, 1, -60)
	panel.Size = UDim2.fromOffset(560, CARD.Y + 76)
	panel.BackgroundColor3 = Color3.fromRGB(14, 11, 9)
	panel.BackgroundTransparency = 0.15
	panel.Visible = false
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(12, 6)
	title.Size = UDim2.new(1, -24, 0, 18)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(235, 225, 200)
	title.Font = Enum.Font.Fondamento
	title.TextSize = 14
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "The Altar · top card first. Take one back instead of drawing."
	title.Parent = panel

	row = Instance.new("ScrollingFrame")
	row.Position = UDim2.fromOffset(12, 44)
	row.Size = UDim2.new(1, -24, 1, -50)
	row.BackgroundTransparency = 1
	row.ScrollBarThickness = 4
	row.AutomaticCanvasSize = Enum.AutomaticSize.X
	row.CanvasSize = UDim2.new()
	row.ScrollingDirection = Enum.ScrollingDirection.X
	row.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.Parent = row

	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)
	render()
end

function AltarUI.setState(state: Types.PublicState)
	cards = state.altar or {}
	local turn = state.turn
	canTake = state.phase == "TurnLoop" and turn ~= nil and turn.activeUserId == localPlayer.UserId and turn.stage == "Draw"
	render()
end

function AltarUI.isOpen(): boolean
	return panel ~= nil and panel.Visible
end

return AltarUI
