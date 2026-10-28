--!strict
-- Swap: pick who to trade your whole hand with. The server sends the choices (and nil to close);
-- if you don't pick in time it trades with the next player round the table.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

export type SwapOption = { userId: number, name: string, cards: number }

local SwapUI = {}

local frame: Frame
local list: Frame

local function button(text: string, parent: Instance, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 38)
	b.BackgroundColor3 = Color3.fromRGB(64, 52, 40)
	b.TextColor3 = Color3.fromRGB(235, 225, 200)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 16
	b.Text = text
	b.Activated:Connect(onClick)
	b.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = b
	return b
end

function SwapUI.init(gui: ScreenGui)
	frame = Instance.new("Frame")
	frame.Name = "Swap"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.55)
	frame.Size = UDim2.fromOffset(340, 230)
	frame.BackgroundColor3 = Color3.fromRGB(18, 20, 18)
	frame.BackgroundTransparency = 0.15
	frame.Visible = false
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(12, 8)
	title.Size = UDim2.new(1, -24, 0, 24)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(235, 225, 200)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.Text = "Swap · trade your whole hand with..."
	title.Parent = frame

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
