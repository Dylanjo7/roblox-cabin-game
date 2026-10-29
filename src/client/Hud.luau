--!strict
-- Owns the screen GUI: one line of what to do next, the turn order in multiplayer, a countdown
-- when the game is about to take a step for someone (Config.Turn), and short messages that fade
-- in and out (a few at once, newest at the bottom). No clock: the time is only on the table.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CardData = require(Shared:WaitForChild("CardData"))
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))

local Style = require(script.Parent.Style)

local Hud = {}

local localPlayer = Players.LocalPlayer
local screen: ScreenGui
local statusLabel: TextLabel
local orderLabel: TextLabel
local timerLabel: TextLabel
local toastList: Frame
local toastCount = 0
local lastState: Types.PublicState? = nil

local MAX_TOASTS = 3

-- "Back to your chair in 8s" and the like, once a step is close to happening by itself.
local function countdown(): string
	local state = lastState
	local turn = state and state.turn
	if not state or not turn or not turn.deadline or (state.phase ~= "TurnLoop" and state.phase ~= "Setup") then
		return ""
	end
	local left = math.ceil(turn.deadline - workspace:GetServerTimeNow())
	if left > Config.Turn.WarnSeconds or left < 0 then
		return ""
	end
	local mine = turn.activeUserId == localPlayer.UserId
	if turn.stage == "WaitingStart" then
		for _, name in turn.unseated or {} do
			if name == localPlayer.DisplayName then
				return `Back to your chair in {left}s.`
			end
		end
		return if mine then `Your turn starts by itself in {left}s.` else `{turn.activeName}'s turn starts in {left}s.`
	end
	if mine then
		return `Out of time in {left}s: the game will choose for you.`
	end
	return `{turn.activeName} has {left}s.`
end

function Hud.init(): ScreenGui
	screen = Instance.new("ScreenGui")
	-- Children always draw over their parents (the Journal's pages over its paper, a card's
	-- art over the card). Left on the old Global setting, they could draw underneath instead.
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Name = "HollowPinesHud"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	Style.vignette(screen)

	-- What to do next: a single line of ink near the top, no box.
	statusLabel = Style.text(screen, "Status", Style.Body, 22)
	statusLabel.AnchorPoint = Vector2.new(0.5, 0)
	statusLabel.Position = UDim2.new(0.5, 0, 0, 46)
	statusLabel.Size = UDim2.new(0.6, 0, 0, 30)
	-- Turn order (multiplayer only), small and faint under it.
	orderLabel = Style.text(screen, "Order", Style.Type, 14)
	orderLabel.AnchorPoint = Vector2.new(0.5, 0)
	orderLabel.Position = UDim2.new(0.5, 0, 0, 76)
	orderLabel.Size = UDim2.new(0.6, 0, 0, 18)
	orderLabel.TextTransparency = 0.3
	-- The countdown before the game takes a step for someone, in red under that.
	timerLabel = Style.text(screen, "Timer", Style.Body, 18)
	timerLabel.AnchorPoint = Vector2.new(0.5, 0)
	timerLabel.Position = UDim2.new(0.5, 0, 0, 96)
	timerLabel.Size = UDim2.new(0.6, 0, 0, 22)
	timerLabel.TextColor3 = Style.Blood
	timerLabel.Text = ""
	-- Messages fade in a quarter of the way down, stack (newest last) and fade away.
	toastList = Instance.new("Frame")
	toastList.Name = "Toasts"
	toastList.AnchorPoint = Vector2.new(0.5, 0)
	toastList.Position = UDim2.fromScale(0.5, 0.24)
	toastList.Size = UDim2.new(0.55, 0, 0, 0)
	toastList.AutomaticSize = Enum.AutomaticSize.Y
	toastList.BackgroundTransparency = 1
	toastList.Parent = screen
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 4)
	layout.Parent = toastList
	screen.Parent = localPlayer:WaitForChild("PlayerGui")

	RunService.Heartbeat:Connect(function()
		timerLabel.Text = countdown()
	end)
	return screen
end

local function instruction(state: Types.PublicState): string
	local turn = state.turn
	if state.phase == "Lobby" then
		if state.arrival and not state.arrival.doorClosed then
			return "Walk up the path to the cabin. The door is open."
		end
		return "Sit at the table. It begins when everyone is seated."
	elseif state.phase == "Setup" then
		if turn and turn.placingId then
			return "Setup · Place the Crawlspace on one of the Parlor's doors."
		end
		return "Setting up the run..."
	elseif state.phase == "TurnLoop" then
		if not turn or not turn.activeUserId then
			return ""
		end
		if turn.stage == "Clock" then
			return "The Hollow Man takes his steps..."
		end
		local standing = if turn.stage == "WaitingStart" and turn.unseated and #turn.unseated > 0
			then `Waiting for {table.concat(turn.unseated, ", ")} to sit down.`
			else nil
		if turn.activeUserId ~= localPlayer.UserId then
			return if standing then `{turn.activeName}'s turn · {standing}` else `Waiting for {turn.activeName}`
		end
		if turn.stage == "WaitingStart" then
			return standing or "Your turn. Be seated and press T to start."
		elseif turn.stage == "Draw" then
			local altar = state.altar and #state.altar or 0
			if state.deckCount == 0 then
				return "Deck empty: take a clue off the ALTAR, or play a card from your hand."
			elseif altar > 0 then
				return "Take the card sticking out of the box, or take a clue back off the Altar (bottom left)."
			end
			return "Take the card sticking out of the box in front of you."
		elseif turn.stage == "Play" then
			return "Pick a card to play. Once picked, you're committed."
		elseif turn.stage == "Placing" and turn.placingId then
			return `Place the {CardData.get(turn.placingId).name}. R rotates.`
		elseif turn.stage == "Peeking" then
			return "Peek: put the top cards back in any order."
		end
	elseif state.phase == "Event" then
		return ""
	elseif state.phase == "GameOver" then
		local result = state.result
		if result then
			return `{if result.won then "You escaped!" else "Run lost."} {result.reason}`
		end
		return "The run is over."
	end
	return ""
end

function Hud.setState(state: Types.PublicState)
	lastState = state
	statusLabel.Text = instruction(state)
	local order = state.turn and state.turn.order
	if state.phase == "TurnLoop" and order and #order > 1 then
		-- Turn order with the active player in brackets.
		local names = {}
		for _, name in order do
			table.insert(names, if state.turn and name == state.turn.activeName then `[{name}]` else name)
		end
		orderLabel.Text = table.concat(names, "  ·  ")
	else
		orderLabel.Text = ""
	end
end

function Hud.toast(text: string)
	local showing: { TextLabel } = {}
	for _, child in toastList:GetChildren() do
		if child:IsA("TextLabel") then
			if child.Text == text then
				-- The same message again just stays up longer.
				child:SetAttribute("Until", os.clock() + Config.UI.ToastSeconds)
				return
			end
			table.insert(showing, child)
		end
	end
	if #showing >= MAX_TOASTS then
		table.sort(showing, function(a: TextLabel, b: TextLabel)
			return a.LayoutOrder < b.LayoutOrder
		end)
		showing[1]:Destroy() -- the oldest makes room
	end
	toastCount += 1
	local label = Style.text(toastList, "Toast", Style.Body, 22)
	label.LayoutOrder = toastCount
	label.Size = UDim2.new(1, 0, 0, 28)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Text = text
	label.TextTransparency = 1
	label.TextStrokeTransparency = 1
	label:SetAttribute("Until", os.clock() + Config.UI.ToastSeconds)
	TweenService:Create(label, TweenInfo.new(0.25), { TextTransparency = 0, TextStrokeTransparency = 0.35 }):Play()
	task.spawn(function()
		while label.Parent and os.clock() < ((label:GetAttribute("Until") :: number?) or 0) do
			task.wait(0.2)
		end
		if label.Parent then
			local fade = TweenService:Create(label, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 })
			fade:Play()
			fade.Completed:Wait()
			label:Destroy()
		end
	end)
end

return Hud
