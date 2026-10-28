--!strict
-- The Journal (M): the shared record of clues found in the cabin, beside the table of exit rooms
-- and their three clues. Recorded clues light up in the table; click an exit to cross it out (or
-- back in) for the whole group. Tally marks are listed with their counts for you to add up.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClueData = require(Shared:WaitForChild("ClueData"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local PAPER = Color3.fromRGB(226, 212, 182)
local INK = Color3.fromRGB(44, 32, 24)
local FADED = Color3.fromRGB(150, 136, 112)
local FOUND = Color3.fromRGB(150, 40, 30)

local JournalUI = {}

local book: Frame
local leftList: ScrollingFrame
local rightList: Frame
local journal: Types.JournalPublic = { entries = {}, crossed = {} }

local function text(parent: Instance, value: string, size: number, font: Enum.Font, color: Color3, height: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, height)
	l.BackgroundTransparency = 1
	l.Text = value
	l.TextSize = size
	l.Font = font
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.RichText = true
	l.Parent = parent
	return l
end

local function page(name: string, x: number): Frame
	local p = Instance.new("Frame")
	p.Name = name
	p.Position = UDim2.new(x, 12, 0, 12)
	p.Size = UDim2.new(0.5, -24, 1, -24)
	p.BackgroundTransparency = 1
	p.Parent = book
	return p
end

local function render()
	for _, child in leftList:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	for _, child in rightList:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	-- Left page: what's been found.
	local found: { [string]: boolean } = {}
	local tallies = {}
	if #journal.entries == 0 then
		text(leftList, "<i>Nothing yet. When a clue's sign appears in the cabin, find it and record it here.</i>", 15, Enum.Font.Merriweather, FADED, 60)
	end
	for i, entry in journal.entries do
		local line = text(leftList, `<b>{entry.label}</b> · {entry.room}  <font color="#968870">({entry.by})</font>`, 16, Enum.Font.Merriweather, INK, 24)
		line.LayoutOrder = i
		if entry.clue == "tally" then
			table.insert(tallies, `{entry.count or 0}`)
		else
			found[entry.clue] = true
		end
	end
	if #tallies > 0 then
		local sum = 0
		for _, n in tallies do
			sum += tonumber(n) or 0
		end
		local line = text(leftList, `<i>Tally marks: {table.concat(tallies, " + ")} = {sum}</i>`, 15, Enum.Font.Merriweather, INK, 24)
		line.LayoutOrder = 1000
	end

	-- Right page: the exit rooms.
	local crossed: { [string]: boolean } = {}
	for _, id in journal.crossed do
		crossed[id] = true
	end
	for i, exit in ClueData.Exits do
		local row = Instance.new("TextButton")
		row.LayoutOrder = i
		row.Size = UDim2.new(1, 0, 0, 44)
		row.BackgroundTransparency = 1
		row.Text = ""
		row.Parent = rightList
		local clues = {}
		for _, result in exit.clues do
			local name = ClueData.Results[result]
			table.insert(clues, if found[result] then `<font color="#962818"><b>{name}</b></font>` else name)
		end
		local isCrossed = crossed[exit.id] == true
		text(row, `<b>{exit.name}</b>  <font size="12">{exit.doors} door{if exit.doors == 1 then "" else "s"}</font>`, 17, Enum.Font.Fondamento, if isCrossed then FADED else INK, 20)
		local detail = text(row, table.concat(clues, " · "), 13, Enum.Font.Merriweather, if isCrossed then FADED else INK, 20)
		detail.Position = UDim2.fromOffset(0, 20)
		if isCrossed then
			local strike = Instance.new("Frame")
			strike.Size = UDim2.new(1, 0, 0, 2)
			strike.Position = UDim2.fromOffset(0, 11)
			strike.BackgroundColor3 = FOUND
			strike.BorderSizePixel = 0
			strike.Parent = row
		end
		row.Activated:Connect(function()
			Remotes.event("RequestToggleExit"):FireServer(exit.id)
		end)
	end
end

function JournalUI.init(gui: ScreenGui)
	book = Instance.new("Frame")
	book.Name = "Journal"
	book.AnchorPoint = Vector2.new(0.5, 0.5)
	book.Position = UDim2.fromScale(0.5, 0.52)
	book.Size = UDim2.fromOffset(860, 470)
	book.BackgroundColor3 = PAPER
	book.Visible = false
	book.ZIndex = 20
	book.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = book
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(90, 60, 40)
	stroke.Thickness = 4
	stroke.Parent = book
	local spine = Instance.new("Frame")
	spine.AnchorPoint = Vector2.new(0.5, 0)
	spine.Position = UDim2.fromScale(0.5, 0)
	spine.Size = UDim2.new(0, 3, 1, 0)
	spine.BackgroundColor3 = Color3.fromRGB(150, 120, 90)
	spine.BorderSizePixel = 0
	spine.Parent = book

	local left = page("Clues", 0)
	text(left, "<b>Clues found</b>", 26, Enum.Font.Fondamento, INK, 34)
	leftList = Instance.new("ScrollingFrame")
	leftList.Position = UDim2.fromOffset(0, 40)
	leftList.Size = UDim2.new(1, 0, 1, -70)
	leftList.BackgroundTransparency = 1
	leftList.ScrollBarThickness = 4
	leftList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	leftList.CanvasSize = UDim2.new()
	leftList.Parent = left
	local leftLayout = Instance.new("UIListLayout")
	leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
	leftLayout.Padding = UDim.new(0, 4)
	leftLayout.Parent = leftList
	local foot = text(left, "<i>A clue that isn't one of the three true clues shows nothing. Note that too.</i>", 13, Enum.Font.Merriweather, FADED, 28)
	foot.Position = UDim2.new(0, 0, 1, -28)

	local right = page("Exits", 0.5)
	text(right, "<b>Ways out</b>  <font size=\"14\">(click to cross out)</font>", 26, Enum.Font.Fondamento, INK, 34)
	rightList = Instance.new("Frame")
	rightList.Position = UDim2.fromOffset(0, 40)
	rightList.Size = UDim2.new(1, 0, 1, -40)
	rightList.BackgroundTransparency = 1
	rightList.Parent = right
	local rightLayout = Instance.new("UIListLayout")
	rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rightLayout.Padding = UDim.new(0, 4)
	rightLayout.Parent = rightList

	render()
end

function JournalUI.toggle()
	book.Visible = not book.Visible
end

function JournalUI.setState(state: Types.PublicState)
	if state.journal then
		journal = state.journal
		render()
	end
end

function JournalUI.isOpen(): boolean
	return book ~= nil and book.Visible
end

return JournalUI
