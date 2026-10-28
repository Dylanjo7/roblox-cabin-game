--!strict
-- Swap: pick who to trade your whole hand with. The server sends the choices (and nil to close);
-- if you don't pick in time it trades with the next player round the table.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Style = require(script.Parent.Style)

export type SwapOption = { userId: number, name: string, cards: number }

local SwapUI = {}

local frame: Frame
local list: Frame

local function button(text: string, parent: Instance, onClick: () -> ()): TextButton
	return Style.button(parent, text, UDim2.new(1, 0, 0, 38), onClick)
end

function SwapUI.init(gui: ScreenGui)
	frame = Style.panel(gui, "Swap")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.55)
	frame.Size = UDim2.fromOffset(340, 230)
	frame.Visible = false

	local title = Style.text(frame, "Title", Style.Body, 20)
	title.Position = UDim2.fromOffset(12, 8)
	title.Size = UDim2.new(1, -24, 0, 24)
	title.Text = "Trade your whole hand with..."

	list = Instance.new("Frame")
	list.Position = UDim2.fromOffset(12, 40)
	list.Size = UDim2.new(1, -24, 1, -52)
	list.BackgroundTransparency = 1
	list.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list
end

-- nil hides the panel (the swap happened).
function SwapUI.show(options: { SwapOption }?)
	for _, child in list:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	if not options then
		frame.Visible = false
		return
	end
	for _, option in options do
		button(`{option.name}  ({option.cards} card{if option.cards == 1 then "" else "s"})`, list, function()
			Remotes.event("SubmitSwapTarget"):FireServer(option.userId)
		end)
	end
	frame.Visible = true
end

function SwapUI.isOpen(): boolean
	return frame ~= nil and frame.Visible
end

return SwapUI
