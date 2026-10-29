--!strict
-- The Journal (M): an old notebook left in the cabin by the last people who tried to leave.
-- The first pages are the rules, in their hand. After those, the group's own pages: the 6 clue
-- results to tick off (click to cycle found / ruled out / unknown, shared with everyone; recording
-- a sign marks it found), the signs recorded so far, and the 8 ways out with
-- their three clues. Ways out that no longer fit what you've marked fade; click one to cross it
-- out for the whole group. The last page, "Favours", is where the Robux items are (Config.Shop):
-- your lantern's flame colour, and scaring a friend. Turn pages with the arrows at the bottom or
-- the Left/Right keys.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClueData = require(Shared:WaitForChild("ClueData"))
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Story = require(Shared:WaitForChild("Story"))
local Types = require(Shared:WaitForChild("Types"))

local Audio = require(script.Parent.Audio)

local PAPER = Color3.fromRGB(226, 212, 182)
local INK = Color3.fromRGB(44, 32, 24)
local FADED = Color3.fromRGB(150, 136, 112)
local RED = Color3.fromRGB(150, 40, 30)
local HAND = Enum.Font.Fondamento -- headings, in the last visitor's hand
local BODY = Enum.Font.Merriweather

local JournalUI = {}

local opened = Instance.new("BindableEvent")
-- Fires each time the book is opened.
JournalUI.Opened = opened.Event

local book: Frame
local spreadHolder: Frame
local pageLabel: TextLabel
local prevButton: TextButton
local nextButton: TextButton
local scrawlLabel: TextLabel
local journal: Types.JournalPublic = { entries = {}, crossed = {}, marks = {} }
local notes: { number } = {} -- Story.Notes found, in the order they were read
local difficulty: Types.DifficultyPublic? = nil -- tonight's (the rules pages say how often he moves)
local spread = 1
local SPREADS = 5
local CLUE_SPREAD = 3
local NOTES_SPREAD = 4 -- their notes; the last spread is the Favours
local localPlayer = Players.LocalPlayer
local prices: { [string]: number } = {} -- "pass" / "scare" -> Robux, once known

local function text(parent: Instance, value: string, size: number, font: Enum.Font, color: Color3, height: number?): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, height or 0)
	l.AutomaticSize = if height then Enum.AutomaticSize.None else Enum.AutomaticSize.Y
	l.BackgroundTransparency = 1
	l.Text = value
	l.TextSize = size
	l.Font = font
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.TextWrapped = true
	l.RichText = true
	l.Parent = parent
	return l
end

-- One page of the current spread: a column that stacks what's put in it.
local function page(x: number): Frame
	local p = Instance.new("Frame")
	p.Position = UDim2.new(x, 22, 0, 18)
	p.Size = UDim2.new(0.5, -40, 1, -64)
	p.BackgroundTransparency = 1
	p.Parent = spreadHolder
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = p
	return p
end

local order = 0
-- Stack this next on its page.
local function add(inst: GuiObject)
	order += 1
	inst.LayoutOrder = order
end

local function heading(p: Frame, value: string)
	add(text(p, `<b>{value}</b>`, 26, HAND, INK, 32))
end

local function para(p: Frame, value: string)
	add(text(p, value, 14, BODY, INK))
end

------------------------------------------------------------------------------------------------
-- The rules, as the last visitors wrote them down.

local function rulesOne(left: Frame, right: Frame)
	heading(left, "How to leave")
	add(text(left, "<i>Whoever had this book before you didn't get out. Read it anyway.</i>", 14, BODY, FADED))
	if difficulty and difficulty.id ~= Config.Difficulty.Default then
		add(text(left, `<b>Tonight is {difficulty.name}.</b> {Config.Difficulty.Levels[difficulty.id].blurb}`, 14, BODY, RED))
	end
	para(left, "Stay alive until <b>three o'clock</b>. Work out which room is the way out. Be standing at its door when the clock strikes, and go through.")
	para(left, "Everything happens at the round table in the Parlor. <b>Everyone has to be sitting</b> before a turn can start. When the box turns to face you it's your turn: press <b>T</b>.")
	para(left, "<b>On your turn</b>\n1. Take the card sticking out of the box, <i>or</i> take one clue back off the Altar on top of it. Never both.\n2. If you drew an Event, it starts at once.\n3. Play one card from your hand. Once you pick it, you're committed.")

	heading(right, "The cards")
	para(right, "<b>Rooms</b> build the cabin, on the table and around you. R turns the room, click to set it down. One of its doorways has to meet an open doorway. If it fits nowhere, the card is lost and the Candle moves on 30 minutes.")
	para(right, "<b>Progress</b> cards move the Candle forward 30 or 60 minutes. Most do something else too, good or bad.")
	para(right, "<b>Clues</b> go on the Altar. Only the top one counts. If it's one of the three true clues, its sign shows up somewhere in the cabin. If nothing shows up, that tells you something as well.")
	para(right, "<b>Events</b> are the red cards. They start the moment they're drawn.")
end

local function rulesTwo(left: Frame, right: Frame)
	local turns = if difficulty then difficulty.turnsPerMove else Config.Difficulty.Levels[Config.Difficulty.Default].turnsPerMove
	local penalty = Config.EliminationHollowSteps * Config.Clock.StepMinutes
	local most = Config.EliminationMaxStepsPerEvent * Config.Clock.StepMinutes
	heading(left, "Him")
	para(left, `His piece follows our Candle round the table. Every {turns} turns he takes a step: half an hour, then a whole hour at a time once he's past midnight.`)
	para(left, "If he reaches the Candle you get <b>one last turn</b>, and the Candle has to move before it ends. If it doesn't, that's the end of you. Keep a Progress card back for that turn. Taking a clue off the Altar is safer than drawing blind.")
	para(left, `In an event, if you fail you wake up in the <b>basement</b>. The door stays barred until it's over up there. Every one of us he gets lets him gain {penalty} minutes on the Candle, up to {most} minutes an event.`)
	para(left, "The Candle only moves when we play a card. Nothing else moves it: not the turns, not him.")
	add(text(left, "<i>He doesn't flicker the lights unless he's close. If they flicker, move.</i>", 14, BODY, RED))

	heading(right, "Three o'clock")
	para(right, "When the Candle reaches three, every <b>way out</b> that's been built unseals its outside door. Only one of them is real. The rest are his.")
	para(right, `He comes in by the front door, waits a moment, then hunts. You'll have about {Config.EventSeconds.final_escape} seconds to get to the door you believe in. It glows; press <b>F</b> at it to go through.`)
	para(right, "The way out has to be <b>built</b> before three. Hold on to those cards, and play them in time.")
	para(right, "<b>M</b> this book   <b>T</b> start your turn   <b>R</b> turn a room   <b>B</b> the board   <b>1</b> your lantern")
end

------------------------------------------------------------------------------------------------
-- Our pages: what we found, and the ways out.

local function cluePages(left: Frame, right: Frame)
	local marks = journal.marks or {}
	heading(left, "What we found")
	add(text(left, "<i>Click a clue: ✓ found, ✗ ruled out, click again to clear.</i>", 13, BODY, FADED))
	for _, id in { "music_box", "wet_footprints", "rocking_chair", "frost", "tally_marks", "the_doll" } do
		local mark = marks[id]
		local row = Instance.new("TextButton")
		add(row)
		row.Size = UDim2.new(1, 0, 0, 24)
		row.BackgroundTransparency = 1
		row.Text = ""
		row.Parent = left
		local box = if mark == "found" then "✓" elseif mark == "ruled_out" then "✗" else "–"
		local name = ClueData.Results[id]
		local line = if mark == "found"
			then `<font color="#962818"><b>{box}  {name}</b></font>`
			elseif mark == "ruled_out" then `<font color="#968870">{box}  <s>{name}</s></font>`
			else `{box}  {name}`
		text(row, line, 17, HAND, INK, 24)
		row.Activated:Connect(function()
			Remotes.event("RequestMarkClue"):FireServer(id)
			Audio.play("card", 0.25, nil, 1.6)
		end)
	end

	add(text(left, "<b>Signs written down</b>", 16, HAND, INK, 22))
	if #journal.entries == 0 then
		add(text(left, "<i>Nothing yet. When a clue's sign appears in the cabin, find it and write it down here.</i>", 13, BODY, FADED))
	end
	for _, entry in journal.entries do
		add(text(left, `{entry.label} · {entry.room}  <font color="#968870">({entry.by})</font>`, 13, BODY, INK))
	end

	-- The ways out. One fits if nothing it needs is ruled out and it has every clue found.
	local crossed: { [string]: boolean } = {}
	for _, id in journal.crossed do
		crossed[id] = true
	end
	local found = {}
	for id, mark in marks do
		if mark == "found" then
			table.insert(found, id)
		end
	end
	heading(right, "Ways out")
	add(text(right, "<i>Click one to cross it out. The faded ones don't fit what we've marked.</i>", 13, BODY, FADED))
	local fitting = {}
	for _, exit in ClueData.Exits do
		local fits = true
		for _, id in found do
			if not table.find(exit.clues, id) then
				fits = false
			end
		end
		for _, id in exit.clues do
			if marks[id] == "ruled_out" then
				fits = false
			end
		end
		local isCrossed = crossed[exit.id] == true
		if fits and not isCrossed then
			table.insert(fitting, exit.name)
		end
		local row = Instance.new("TextButton")
		add(row)
		row.Size = UDim2.new(1, 0, 0, 40)
		row.BackgroundTransparency = 1
		row.Text = ""
		row.Parent = right
		local colour = if isCrossed or not fits then FADED else INK
		local clues = {}
		for _, id in exit.clues do
			local name = ClueData.Results[id]
			table.insert(clues, if marks[id] == "found" then `<font color="#962818"><b>{name}</b></font>` elseif marks[id] == "ruled_out" then `<s>{name}</s>` else name)
		end
		text(row, `<b>{exit.name}</b>  <font size="12">{exit.doors} door{if exit.doors == 1 then "" else "s"}</font>`, 17, HAND, colour, 20)
		local detail = text(row, table.concat(clues, " · "), 12, BODY, colour, 18)
		detail.Position = UDim2.fromOffset(0, 20)
		if isCrossed then
			local strike = Instance.new("Frame")
			strike.Size = UDim2.new(1, 0, 0, 2)
			strike.Position = UDim2.fromOffset(0, 10)
			strike.BackgroundColor3 = RED
			strike.BorderSizePixel = 0
			strike.Parent = row
		end
		row.Activated:Connect(function()
			Remotes.event("RequestToggleExit"):FireServer(exit.id)
			Audio.play("card", 0.25, nil, 1.3)
		end)
	end
	if #fitting == 1 and #found > 0 then
		add(text(right, `<i>Only the {fitting[1]} still fits.</i>`, 15, HAND, RED))
	elseif #fitting == 0 then
		add(text(right, "<i>Nothing fits. Something we marked is wrong.</i>", 15, HAND, RED))
	end
end

------------------------------------------------------------------------------------------------
-- Their notes: the pages the missing four left around the house, as they're found.

local function notePages(left: Frame, right: Frame)
	heading(left, "Their notes")
	if #notes == 0 then
		add(text(left, "<i>Four people came here before you. They left pages lying around the house. Some of them may still be there, in the rooms you haven't built yet.</i>", 14, BODY, FADED))
		return
	end
	-- The first half on the left page, the rest on the right.
	local half = math.ceil(#notes / 2)
	for i, index in notes do
		local note = Story.Notes[index]
		if note then
			local p = if i <= half then left else right
			add(text(p, `{note.text}  <i><font color="#962818">— {note.by}</font></i>`, 13, BODY, INK))
		end
	end
end

------------------------------------------------------------------------------------------------
-- Favours: the Robux items, kept quiet at the back of the book.

local function priceText(key: string): string
	local price = prices[key]
	return if price then `  ·  R$ {price}` else ""
end

local function favourButton(p: Frame, label: string, onClick: () -> ())
	local b = Instance.new("TextButton")
	add(b)
	b.Size = UDim2.new(1, 0, 0, 26)
	b.BackgroundTransparency = 1
	b.Text = ""
	b.Parent = p
	text(b, label, 16, HAND, INK, 26)
	b.Activated:Connect(function()
		Audio.play("card", 0.25, nil, 1.4)
		onClick()
	end)
end

local function favourPages(left: Frame, right: Frame)
	local shop = Config.Shop
	heading(left, "Favours")
	add(text(left, "<i>Some things in this house can still be bought. None of them will get you out.</i>", 13, BODY, FADED))
	add(text(left, "<b>Your lantern's flame</b>", 16, HAND, INK, 22))
	local owns = localPlayer:GetAttribute("OwnsLanternColours") == true
	local current = localPlayer:GetAttribute("LanternColour") or "ember"
	for _, option in shop.LanternColours do
		local usable = option.free or owns
		local hex = option.color:ToHex()
		local mark = if option.id == current then "✓" else "–"
		local label = `{mark}  <font color="#{hex}">●</font>  {option.name}`
		if usable then
			favourButton(left, label, function()
				Remotes.event("SetLanternColour"):FireServer(option.id)
			end)
		else
			add(text(left, `<font color="#968870">{label}</font>`, 16, HAND, INK, 26))
		end
	end
	if not owns then
		if shop.LanternColoursPass == 0 then
			add(text(left, "<i>(The Lantern Colours pass isn't set up yet.)</i>", 13, BODY, FADED))
		else
			favourButton(left, `<b>Get the Lantern Colours pass</b>{priceText("pass")}`, function()
				MarketplaceService:PromptGamePassPurchase(localPlayer, shop.LanternColoursPass)
			end)
		end
	end

	heading(right, "Scare a friend")
	para(right, "Pick someone. His face will fill their screen, and a moment later they'll find out it was you.")
	if shop.ScareProduct == 0 then
		add(text(right, "<i>(Scares aren't set up yet.)</i>", 13, BODY, FADED))
		return
	end
	local others = 0
	for _, p in Players:GetPlayers() do
		if p ~= localPlayer then
			others += 1
			favourButton(right, `<b>{p.DisplayName}</b>{priceText("scare")}`, function()
				Remotes.event("RequestScare"):FireServer(p.UserId)
			end)
		end
	end
	if others == 0 then
		add(text(right, "<i>Nobody else is here. Yet.</i>", 13, BODY, FADED))
	end
end

------------------------------------------------------------------------------------------------

local function render()
	for _, child in spreadHolder:GetChildren() do
		child:Destroy()
	end
	order = 0
	local left, right = page(0), page(0.5)
	if spread == 1 then
		rulesOne(left, right)
	elseif spread == 2 then
		rulesTwo(left, right)
	elseif spread == CLUE_SPREAD then
		cluePages(left, right)
	elseif spread == NOTES_SPREAD then
		notePages(left, right)
	else
		favourPages(left, right)
	end
	pageLabel.Text = `{spread * 2 - 1} – {spread * 2}`
	prevButton.Visible = spread > 1
	nextButton.Visible = spread < SPREADS
end

local function turnTo(n: number)
	n = math.clamp(n, 1, SPREADS)
	if n == spread then
		return
	end
	local forward = n > spread
	spread = n
	Audio.play("card", 0.45)
	render()
	-- The new pages slide in from the side they were turned from.
	spreadHolder.Position = UDim2.fromOffset(if forward then 26 else -26, 0)
	local info = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(spreadHolder, info, { Position = UDim2.fromOffset(0, 0) }):Play()
end

local function arrow(label: string, x: number, anchor: number, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(anchor, 1)
	b.Position = UDim2.new(x, if anchor == 0 then 16 else -16, 1, -8)
	b.Size = UDim2.fromOffset(60, 34)
	b.BackgroundTransparency = 1
	b.Text = label
	b.TextSize = 34
	b.Font = HAND
	b.TextColor3 = INK
	b.ZIndex = 22
	b.Activated:Connect(onClick)
	b.Parent = book
	return b
end

function JournalUI.init(gui: ScreenGui)
	book = Instance.new("Frame")
	book.Name = "Journal"
	book.AnchorPoint = Vector2.new(0.5, 0.5)
	book.Position = UDim2.fromScale(0.5, 0.52)
	book.Size = UDim2.fromOffset(900, 540)
	book.BackgroundColor3 = PAPER
	book.Visible = false
	book.ZIndex = 20
	book.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = book
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(70, 46, 30)
	stroke.Thickness = 6
	stroke.Parent = book
	-- Age: darker edges and a stain.
	local age = Instance.new("UIGradient")
	age.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 184, 150)),
		ColorSequenceKeypoint.new(0.15, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(235, 228, 214)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(190, 172, 140)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(235, 228, 214)),
		ColorSequenceKeypoint.new(0.85, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 184, 150)),
	})
	age.Parent = book
	local stain = Instance.new("Frame")
	stain.AnchorPoint = Vector2.new(0.5, 0.5)
	stain.Position = UDim2.fromScale(0.82, 0.8)
	stain.Size = UDim2.fromOffset(110, 90)
	stain.BackgroundColor3 = Color3.fromRGB(150, 110, 70)
	stain.BackgroundTransparency = 0.88
	stain.Parent = book
	local stainCorner = Instance.new("UICorner")
	stainCorner.CornerRadius = UDim.new(0.5, 0)
	stainCorner.Parent = stain

	spreadHolder = Instance.new("Frame")
	spreadHolder.Name = "Spread"
	spreadHolder.Size = UDim2.fromScale(1, 1)
	spreadHolder.BackgroundTransparency = 1
	spreadHolder.ZIndex = 21
	spreadHolder.Parent = book

	pageLabel = text(book, "", 14, HAND, FADED, 20)
	pageLabel.AnchorPoint = Vector2.new(0.5, 1)
	pageLabel.Position = UDim2.new(0.5, 0, 1, -12)
	pageLabel.Size = UDim2.fromOffset(120, 20)
	pageLabel.TextXAlignment = Enum.TextXAlignment.Center
	prevButton = arrow("‹", 0, 0, function()
		turnTo(spread - 1)
	end)
	nextButton = arrow("›", 1, 1, function()
		turnTo(spread + 1)
	end)

	-- A scare can scrawl across the pages (see Scares).
	scrawlLabel = text(book, "", 64, Enum.Font.Creepster, RED, 0)
	scrawlLabel.AutomaticSize = Enum.AutomaticSize.None
	scrawlLabel.Size = UDim2.fromScale(1, 1)
	scrawlLabel.TextXAlignment = Enum.TextXAlignment.Center
	scrawlLabel.TextYAlignment = Enum.TextYAlignment.Center
	scrawlLabel.Rotation = -6
	scrawlLabel.ZIndex = 30
	scrawlLabel.Visible = false

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or not book.Visible then
			return
		end
		if input.KeyCode == Enum.KeyCode.Left then
			turnTo(spread - 1)
		elseif input.KeyCode == Enum.KeyCode.Right then
			turnTo(spread + 1)
		end
	end)

	-- The favours page follows who's here, what you own and the prices.
	local function refresh()
		if spread == SPREADS then
			render()
		end
	end
	Players.PlayerAdded:Connect(refresh)
	Players.PlayerRemoving:Connect(function()
		task.defer(refresh)
	end)
	localPlayer:GetAttributeChangedSignal("OwnsLanternColours"):Connect(refresh)
	localPlayer:GetAttributeChangedSignal("LanternColour"):Connect(refresh)
	task.spawn(function()
		local shop = Config.Shop
		local function price(key: string, id: number, kind: Enum.InfoType)
			if id == 0 then
				return
			end
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(id, kind)
			end)
			if ok and typeof(info) == "table" and typeof(info.PriceInRobux) == "number" then
				prices[key] = info.PriceInRobux
			end
		end
		price("pass", shop.LanternColoursPass, Enum.InfoType.GamePass)
		price("scare", shop.ScareProduct, Enum.InfoType.Product)
		refresh()
	end)

	render()
end

function JournalUI.toggle()
	book.Visible = not book.Visible
	if book.Visible then
		Audio.play("card", 0.4, nil, 0.8)
		opened:Fire()
	end
end

-- Scrawl words in red across the open pages for a moment (a scare).
function JournalUI.scrawl(words: string, seconds: number)
	if not book.Visible then
		return
	end
	scrawlLabel.Text = words
	scrawlLabel.Visible = true
	spreadHolder.Visible = false
	task.delay(seconds, function()
		scrawlLabel.Visible = false
		spreadHolder.Visible = true
	end)
end

function JournalUI.setState(state: Types.PublicState)
	if state.difficulty and (difficulty == nil or difficulty.id ~= state.difficulty.id) then
		difficulty = state.difficulty
		if spread == 1 or spread == 2 then
			render()
		end
	end
	if state.notes and #state.notes ~= #notes then
		notes = state.notes
		if spread == NOTES_SPREAD then
			render()
		end
	end
	if state.journal then
		local first = #journal.entries == 0 and #state.journal.entries > 0
		journal = state.journal
		if first and not book.Visible then
			spread = CLUE_SPREAD -- the first sign recorded: open to our own pages next time
		end
		render()
	end
end

function JournalUI.isOpen(): boolean
	return book ~= nil and book.Visible
end

return JournalUI
