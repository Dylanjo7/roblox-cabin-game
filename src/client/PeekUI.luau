--!strict
-- Peek: shows the next cards in the deck (top first). Reorder them and confirm to put them back.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CardData = require(Shared:WaitForChild("CardData"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local PeekUI = {}

local frame: Frame
local list: Frame
local order: { Types.Card } = {}

local function button(text: string, size: UDim2, parent: Instance, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
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

local function move(from: number, to: number)
	if to < 1 or to > #order then
		return
	end
	order[from], order[to] = order[to], order[from]
end

local function render()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for i, card in order do
		local row = Instance.new("Frame")
		row.LayoutOrder = i
		row.Size = UDim2.new(1, 0, 0, 36)
		row.BackgroundTransparency = 1
		row.Parent = list

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -84, 1, 0)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.fromRGB(235, 225, 200)
		label.Font = Enum.Font.GothamMedium
		label.TextSize = 16
		label.TextXAlignment = Enum.TextXAlignment.Left
		local def = CardData.get(card.id)
		label.Text = `{i}. {def.name} ({def.type})`
		label.Parent = row

		local up = button("▲", UDim2.fromOffset(36, 32), row, function()
			move(i, i - 1)
			render()
		end)
		up.Position = UDim2.new(1, -80, 0, 2)
		local down = button("▼", UDim2.fromOffset(36, 32), row, function()
			move(i, i + 1)
			render()
		end)
		down.Position = UDim2.new(1, -40, 0, 2)
	end
end

function PeekUI.init(gui: ScreenGui)
	frame = Instance.new("Frame")
	frame.Name = "Peek"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.55)
	frame.Size = UDim2.fromOffset(380, 230)
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
	title.Text = "Peek · top of the deck first. Reorder, then confirm."
	title.TextWrapped = true
	title.Parent = frame

	list = Instance.new("Frame")
	list.Position = UDim2.fromOffset(12, 40)
	list.Size = UDim2.new(1, -24, 0, 120)
	list.BackgroundTransparency = 1
	list.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = list

	local confirm = button("Put them back", UDim2.new(1, -24, 0, 36), frame, function()
		local uids = {}
		for _, card in order do
			table.insert(uids, card.uid)
		end
		Remotes.event("SubmitPeekOrder"):FireServer(uids)
	end)
	confirm.Position = UDim2.new(0, 12, 1, -46)
end

-- nil hides the panel (the server accepted the order).
function PeekUI.show(cards: { Types.Card }?)
	if cards then
		order = table.clone(cards)
		render()
		frame.Visible = true
	else
		order = {}
		frame.Visible = false
	end
end

function PeekUI.isOpen(): boolean
	return frame ~= nil and frame.Visible
end

return PeekUI
