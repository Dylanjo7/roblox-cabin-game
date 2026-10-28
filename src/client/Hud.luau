--!strict
-- Owns the screen GUI: one line of what to do next, the turn order in multiplayer, and short
-- messages that fade in and out. No clock: the time is only on the table.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
local toastLabel: TextLabel
local toastToken = 0

function Hud.init(): ScreenGui
	screen = Instance.new("ScreenGui")
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
	-- Messages fade in a third of the way down and fade away.
	toastLabel = Style.text(screen, "Toast", Style.Body, 24)
	toastLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	toastLabel.Position = UDim2.fromScale(0.5, 0.3)
	toastLabel.Size = UDim2.new(0.55, 0, 0, 64)
	toastLabel.TextTransparency = 1
	toastLabel.TextStrokeTransparency = 1
	screen.Parent = localPlayer:WaitForChild("PlayerGui")
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
	toastToken += 1
	local token = toastToken
	toastLabel.Text = text
	local fadeIn = TweenInfo.new(0.25)
	TweenService:Create(toastLabel, fadeIn, { TextTransparency = 0, TextStrokeTransparency = 0.35 }):Play()
	task.delay(Config.UI.ToastSeconds, function()
		if toastToken == token then
			TweenService:Create(toastLabel, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

return Hud
