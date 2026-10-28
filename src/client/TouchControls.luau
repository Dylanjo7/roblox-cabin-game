--!strict
-- On a phone or tablet there are no keys, so the keys become buttons on the right of the screen
-- (above the jump button), each shown only when it does something: Start turn (T) when it's your
-- turn, Rotate (R) and Board (B) while you're placing a room, and the Journal (M) always.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local Input = require(script.Parent.Input)
local Style = require(script.Parent.Style)

local TouchControls = {}

local localPlayer = Players.LocalPlayer
local buttons: { [string]: TextButton } = {}

local ORDER = { "turn", "rotate", "board", "journal" }
local LABELS = { turn = "Start turn", rotate = "Rotate", board = "Board", journal = "Journal" }
local KEYS = { turn = Enum.KeyCode.T, rotate = Enum.KeyCode.R, board = Enum.KeyCode.B, journal = Enum.KeyCode.M }

-- Stack the visible ones upward from just above the jump button.
local function layout()
	local y = -190
	for i = #ORDER, 1, -1 do
		local b = buttons[ORDER[i]]
		if b and b.Visible then
			b.Position = UDim2.new(1, -24, 1, y)
			y -= 58
		end
	end
end

function TouchControls.init(gui: ScreenGui)
	if not UserInputService.TouchEnabled then
		return
	end
	for _, name in ORDER do
		local b = Style.button(gui, LABELS[name], UDim2.fromOffset(124, 48), function()
			Input.trigger(KEYS[name])
		end)
		b.Name = `Touch_{name}`
		b.AnchorPoint = Vector2.new(1, 1)
		b.TextSize = 20
		b.Visible = name == "journal"
		buttons[name] = b
	end
	layout()
end

function TouchControls.setState(state: Types.PublicState)
	if not buttons.journal then
		return
	end
	local turn = state.turn
	local mine = state.phase == "TurnLoop" and turn ~= nil and turn.activeUserId == localPlayer.UserId
	local stage = if turn then turn.stage else nil
	local placing = turn ~= nil and turn.placingId ~= nil and turn.activeUserId == localPlayer.UserId
	buttons.turn.Visible = mine and stage == "WaitingStart"
	buttons.rotate.Visible = placing
	buttons.board.Visible = placing
	layout()
end

return TouchControls
