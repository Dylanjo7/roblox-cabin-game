--!strict
-- Your hand along the bottom of the screen, plus the Draw button. Clicking a card asks the server
-- to play it; once the server accepts, you're committed to that card.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CardFace = require(Shared:WaitForChild("CardFace"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local Audio = require(script.Parent.Audio)
local Hud = require(script.Parent.Hud)

local HandUI = {}

local localPlayer = Players.LocalPlayer
local panel: Frame
local cardRow: Frame
local hand: { Types.Card } = {}
local myStage: Types.TurnStage? = nil -- current stage while it's my turn, else nil
local deckEmpty = false
local busy = false

local CARD_SIZE = Vector2.new(132, 185)
local LIFT = 16

local function request(remote: string, ...: any)
	if busy then
		return
	end
	busy = true
	local ok, err = Remotes.func(remote):InvokeServer(...)
	busy = false
	if not ok and err then
		Hud.toast(err)
	end
end

local function render()
	for _, child in cardRow:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	-- With the deck empty you may skip taking a clue and play straight from your hand.
	local canPlay = myStage == "Play" or (myStage == "Draw" and deckEmpty)
	for i, card in hand do
		-- A fixed slot in the row; the card inside lifts when you hover it.
		local slot = Instance.new("Frame")
		slot.Name = `Card{i}`
		slot.LayoutOrder = i
		slot.Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y)
		slot.BackgroundTransparency = 1
		slot.Parent = cardRow

		local button = Instance.new("TextButton")
		button.Name = "Card"
		button.Size = UDim2.fromScale(1, 1)
		button.BackgroundTransparency = 1
		button.Text = ""
		button.AutoButtonColor = false
		button.Parent = slot
		CardFace.front(button, card.id)

		if not canPlay then
			local dim = Instance.new("Frame")
			dim.Name = "Dim"
			dim.Size = UDim2.fromScale(1, 1)
			dim.BackgroundColor3 = Color3.new(0, 0, 0)
			dim.BackgroundTransparency = 0.55
			dim.ZIndex = 5
			dim.Parent = button
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.06, 0)
			corner.Parent = dim
		end

		local info = TweenInfo.new(0.15, Enum.EasingStyle.Quad)
		button.MouseEnter:Connect(function()
			TweenService:Create(button, info, { Position = UDim2.fromOffset(0, if canPlay then -LIFT else -LIFT / 3) }):Play()
		end)
		button.MouseLeave:Connect(function()
			TweenService:Create(button, info, { Position = UDim2.fromOffset(0, 0) }):Play()
		end)
		button.Activated:Connect(function()
			if canPlay then
				request("RequestSelectCard", card.uid)
			end
		end)
	end
	panel.Visible = myStage ~= "Placing" -- keep the board clear while placing
end

function HandUI.init(gui: ScreenGui)
	panel = Instance.new("Frame")
	panel.Name = "Hand"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -12)
	panel.Size = UDim2.fromOffset(900, CARD_SIZE.Y)
	panel.BackgroundTransparency = 1
	panel.Parent = gui

	cardRow = Instance.new("Frame")
	cardRow.Name = "Cards"
	cardRow.Size = UDim2.fromScale(1, 1)
	cardRow.BackgroundTransparency = 1
	cardRow.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = cardRow

	render()
end

function HandUI.setHand(cards: { Types.Card })
	if #cards > #hand then
		Audio.play("card", 0.5)
	end
	hand = cards
	render()
end

function HandUI.setState(state: Types.PublicState)
	deckEmpty = state.deckCount == 0
	local turn = state.turn
	if state.phase == "TurnLoop" and turn and turn.activeUserId == localPlayer.UserId then
		myStage = turn.stage
	else
		myStage = nil
	end
	render()
end

return HandUI
