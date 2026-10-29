--!strict
-- Your hand along the bottom of the screen. Clicking a card asks the server to play it; once
-- the server accepts, you're committed to that card. A card you play lifts out of the hand and
-- flies up towards the table; a card you're dealt slides up into place. The hand is only rebuilt
-- when it actually changes (not on every update from the server), and shrinks to fit a small
-- screen.

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
local screen: ScreenGui
local panel: Frame
local cardRow: Frame
local scale: UIScale
local hand: { Types.Card } = {}
local myStage: Types.TurnStage? = nil -- current stage while it's my turn, else nil
local deckEmpty = false
local busy = false
local shownKey = "" -- what the row was last built from
local arriving: { [number]: boolean } = {} -- uids just dealt, to slide in

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

local function canPlay(): boolean
	-- With the deck empty you may skip taking a clue and play straight from your hand.
	return myStage == "Play" or (myStage == "Draw" and deckEmpty)
end

local function render()
	local playable = canPlay()
	local keyParts = { if playable then "play" else "wait", if myStage == "Placing" then "placing" else "" }
	for _, card in hand do
		table.insert(keyParts, tostring(card.uid))
	end
	local key = table.concat(keyParts, ",")
	if key == shownKey then
		return
	end
	shownKey = key

	for _, child in cardRow:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for i, card in hand do
		-- A fixed slot in the row; the card inside lifts when you hover it.
		local slot = Instance.new("Frame")
		slot.Name = `Card{i}`
		slot.LayoutOrder = i
		slot.Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y)
		slot.BackgroundTransparency = 1
		slot:SetAttribute("Uid", card.uid)
		slot:SetAttribute("CardId", card.id)
		slot.Parent = cardRow

		local button = Instance.new("TextButton")
		button.Name = "Card"
		button.Size = UDim2.fromScale(1, 1)
		button.BackgroundTransparency = 1
		button.Text = ""
		button.AutoButtonColor = false
		button.Parent = slot
		CardFace.front(button, card.id)

		if not playable then
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

		-- Just dealt: it slides up from below the screen.
		if arriving[card.uid] then
			arriving[card.uid] = nil
			button.Position = UDim2.fromOffset(0, CARD_SIZE.Y + 40)
			TweenService:Create(button, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(0, 0) }):Play()
		end

		local info = TweenInfo.new(0.15, Enum.EasingStyle.Quad)
		button.MouseEnter:Connect(function()
			TweenService:Create(button, info, { Position = UDim2.fromOffset(0, if playable then -LIFT else -LIFT / 3) }):Play()
		end)
		button.MouseLeave:Connect(function()
			TweenService:Create(button, info, { Position = UDim2.fromOffset(0, 0) }):Play()
		end)
		button.Activated:Connect(function()
			if playable then
				request("RequestSelectCard", card.uid)
			end
		end)
	end
	panel.Visible = myStage ~= "Placing" -- keep the board clear while placing
end

-- A card that's left your hand lifts out of its slot and flies up towards the table.
local function flyAway(slot: Frame)
	local id = slot:GetAttribute("CardId")
	if typeof(id) ~= "string" then
		return
	end
	local at = slot.AbsolutePosition
	local size = slot.AbsoluteSize
	if size.X < 1 then
		return
	end
	local ghost = Instance.new("Frame")
	ghost.Name = "PlayedCard"
	ghost.BackgroundTransparency = 1
	ghost.Position = UDim2.fromOffset(at.X, at.Y)
	ghost.Size = UDim2.fromOffset(size.X, size.Y)
	ghost.ZIndex = 20
	ghost.Parent = screen
	CardFace.front(ghost, id)
	local camera = workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local goal = Vector2.new(view.X / 2 - size.X * 0.3, view.Y * 0.28)
	local tween = TweenService:Create(ghost, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.fromOffset(goal.X, goal.Y),
		Size = UDim2.fromOffset(size.X * 0.6, size.Y * 0.6),
		Rotation = if at.X + size.X / 2 < view.X / 2 then 8 else -8,
	})
	tween.Completed:Once(function()
		ghost:Destroy()
	end)
	tween:Play()
end

-- Shrink everything a little on a short screen (a phone held sideways).
local function fit()
	local camera = workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else 720
	scale.Scale = math.clamp(height / 860, 0.55, 1)
end

function HandUI.init(gui: ScreenGui)
	screen = gui
	panel = Instance.new("Frame")
	panel.Name = "Hand"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -12)
	panel.Size = UDim2.fromOffset(900, CARD_SIZE.Y)
	panel.BackgroundTransparency = 1
	panel.Parent = gui
	scale = Instance.new("UIScale")
	scale.Parent = panel
	fit()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end

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
	local had: { [number]: boolean } = {}
	for _, card in hand do
		had[card.uid] = true
	end
	local has: { [number]: boolean } = {}
	for _, card in cards do
		has[card.uid] = true
		if not had[card.uid] and #hand > 0 then
			arriving[card.uid] = true -- (not the opening deal: that just appears)
		end
	end
	-- Played (or taken by Shaking Floor / Swap): off it goes, before the row is rebuilt.
	for _, child in cardRow:GetChildren() do
		local uid = child:GetAttribute("Uid")
		if child:IsA("Frame") and typeof(uid) == "number" and not has[uid] then
			flyAway(child)
		end
	end
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
