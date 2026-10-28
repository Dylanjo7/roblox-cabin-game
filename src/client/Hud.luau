--!strict
-- Owns the screen GUI: status line at the top (clock, round, what to do next) and short toasts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CardData = require(Shared:WaitForChild("CardData"))
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))

local Hud = {}

local localPlayer = Players.LocalPlayer
local screen: ScreenGui
local statusLabel: TextLabel
local toastLabel: TextLabel
local toastToken = 0

local function makeLabel(name: string, y: number, height: number, parent: Instance): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, y)
	label.Size = UDim2.new(0, 720, 0, height)
	label.BackgroundColor3 = Color3.fromRGB(18, 20, 18)
	label.BackgroundTransparency = 0.3
	label.TextColor3 = Color3.fromRGB(230, 222, 200)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 18
	label.TextWrapped = true
	label.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label
	return label
end

function Hud.init(): ScreenGui
	screen = Instance.new("ScreenGui")
	screen.Name = "HollowPinesHud"
	screen.ResetOnSpawn = false
	statusLabel = makeLabel("Status", 8, 34, screen)
	toastLabel = makeLabel("Toast", 48, 30, screen)
	toastLabel.Visible = false
	screen.Parent = localPlayer:WaitForChild("PlayerGui")
	return screen
end

local function instruction(state: Types.PublicState): string
	local turn = state.turn
	if state.phase == "Lobby" then
		if state.arrival and not state.arrival.doorClosed then
			return "Walk up the path to the cabin. The door is open."
		end
		return "HOLLOW PINES  ·  Sit at the Parlor table to begin. The game starts when everyone is seated."
	elseif state.phase == "Setup" then
		if turn and turn.placingId then
			return "Setup · Place the Crawlspace on one of the Parlor's doors."
		end
		return "Setting up the run..."
	elseif state.phase == "TurnLoop" then
		if not turn or not turn.activeUserId then
			return ""
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
				return "Take the top card, or take a clue back off the ALTAR (bottom left)."
			end
			return "Take the top card (button, or click the card back on the stand)."
		elseif turn.stage == "Play" then
			return "Pick a card to play. Once picked, you're committed."
		elseif turn.stage == "Placing" and turn.placingId then
			return `Place the {CardData.get(turn.placingId).name}. R rotates.`
		elseif turn.stage == "Peeking" then
			return "Peek: put the top cards back in any order."
		end
	elseif state.phase == "Event" then
		return "Event in progress!"
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
	local parts = {}
	if state.phase == "TurnLoop" and state.turn then
		table.insert(parts, `Round {state.turn.round}`)
		local order = state.turn.order
		if order and #order > 1 then
			-- Turn order with the active player in brackets.
			local names = {}
			for _, name in order do
				table.insert(names, if name == state.turn.activeName then `[{name}]` else name)
			end
			table.insert(parts, table.concat(names, " > "))
		end
	end
	if state.deckCount and state.phase ~= "Lobby" then
		table.insert(parts, `Deck {state.deckCount}`)
	end
	table.insert(parts, instruction(state))
	statusLabel.Text = table.concat(parts, "  ·  ")
end

function Hud.toast(text: string)
	toastToken += 1
	local token = toastToken
	toastLabel.Text = text
	toastLabel.Visible = true
	task.delay(Config.UI.ToastSeconds, function()
		if toastToken == token then
			toastLabel.Visible = false
		end
	end)
end

return Hud
