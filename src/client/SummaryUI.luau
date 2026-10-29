--!strict
-- The night in numbers: once the ending has played, how the run went. How long it took, what
-- the Candle got to, what was built and found, how each event went, what the true exit was all
-- along, and a line for each player (with a title or two for the table to argue about). Stays up
-- until the table resets or the party goes back to the station; Close puts it away sooner.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))

local Cinema = require(script.Parent.Cinema)
local Cutscene = require(script.Parent.Cutscene)
local Style = require(script.Parent.Style)

local SummaryUI = {}

local localPlayer = Players.LocalPlayer
local screen: ScreenGui
local backdrop: Frame
local panel: Frame
local scale: UIScale
local footer: TextLabel
local phase: Types.Phase = "Lobby"
local summary: Types.SummaryPublic? = nil
local result: Types.ResultPublic? = nil
local open = false
local showToken = 0

local WIDTH = 760
local MARGIN = 28
local COLUMNS = { { "Cards", 0.33 }, { "Rooms", 0.41 }, { "Signs", 0.49 }, { "Caught", 0.57 } }

local function fade(obj: Instance, props: { [string]: any }, seconds: number)
	TweenService:Create(obj, TweenInfo.new(seconds, Enum.EasingStyle.Sine), props):Play()
end

local function plural(n: number, one: string, many: string?): string
	return `{n} {if n == 1 then one else many or one .. "s"}`
end

-- The line under the title: how it ended.
local function verdict(s: Types.SummaryPublic, r: Types.ResultPublic?): string
	local ending = r and r.ending
	local out = 0
	for _, p in s.players do
		if p.escaped then
			out += 1
		end
	end
	if ending == "escaped" then
		return if out >= #s.players then "Everyone got out." else `{out} of {#s.players} got out.`
	elseif ending == "caught" then
		return `The Candle went out at {s.candle}.`
	elseif ending == "never_built" then
		return "Three o'clock came, and the way out was never built."
	end
	return "Three o'clock came, and nobody got out."
end

-- One title each, at most, for the table to argue about.
local function titles(s: Types.SummaryPublic): { [number]: string }
	local out: { [number]: string } = {}
	-- Whoever has the most of something (at least `least`), if nobody ties with them.
	local function best(field: string, least: number): number?
		local top = least - 1
		local who: number? = nil
		local tie = false
		for i, p in s.players do
			local n = (p :: any)[field] :: number
			if n > top then
				top, who, tie = n, i, false
			elseif n == top then
				tie = true
			end
		end
		return if tie then nil else who
	end
	local function give(i: number?, title: string)
		if i and not out[i] then
			out[i] = title
		end
	end
	if #s.players > 1 then
		for i, p in s.players do
			if p.escaped == 1 then
				give(i, "First Out")
			end
		end
	end
	give(best("clues", 2), "The Detective")
	give(best("rooms", 2), "The Builder")
	if #s.events >= 2 then
		for i, p in s.players do
			if p.caught == 0 and not p.left then
				give(i, "Untouchable")
			end
		end
	end
	give(best("caught", 2), "His Favourite")
	return out
end

-- A line of text across the panel at `y`, as tall as it needs to be once wrapped. Returns it
-- and the y below it.
local function line(parent: Instance, name: string, font: Enum.Font, size: number, y: number, text: string): (TextLabel, number)
	local width = WIDTH - MARGIN * 2
	local height = math.max(size + 4, TextService:GetTextSize(text, size, font, Vector2.new(width, 10000)).Y + 4)
	local l = Style.text(parent, name, font, size)
	l.Position = UDim2.fromOffset(MARGIN, y)
	l.Size = UDim2.fromOffset(width, height)
	l.Text = text
	return l, y + height
end

local function build(s: Types.SummaryPublic)
	for _, child in panel:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local y = 18
	local _, below = line(panel, "Title", Style.Title, 46, y, "THE NIGHT IN NUMBERS")
	_, y = line(panel, "Verdict", Style.Body, 22, below + 2, verdict(s, result))
	if s.trueExit then
		local reveal
		reveal, y = line(panel, "Reveal", Style.Body, 20, y + 2, `The way out was the {s.trueExit}.`)
		reveal.TextColor3 = Style.Brass
	end
	y += 10
	local facts = {
		plural(s.minutes, "minute"),
		plural(s.rounds, "round"),
		`{plural(s.rooms, "room")} built`,
		`{plural(s.clues, "sign")} in the Journal`,
		`{plural(s.notes, "note")} found`,
	}
	_, y = line(panel, "Facts", Style.Type, 17, y, table.concat(facts, "  ·  "))
	y += 6

	-- The events, in the order they came up.
	local parts = {}
	for _, e in s.events do
		table.insert(parts, `{e.name} ({if e.caught == 0 then "all made it" else `{e.caught} caught`})`)
	end
	local events
	events, y = line(panel, "Events", Style.Type, 15, y, if #parts > 0 then "Events: " .. table.concat(parts, "  ·  ") else "No events came up tonight.")
	events.TextTransparency = 0.15
	y += 14

	-- A row each, under the column names.
	local head = Instance.new("Frame")
	head.Name = "Header"
	head.BackgroundTransparency = 1
	head.Position = UDim2.fromOffset(20, y)
	head.Size = UDim2.new(1, -40, 0, 18)
	head.Parent = panel
	for _, column in COLUMNS do
		local c = Style.text(head, column[1], Style.Type, 14)
		c.TextColor3 = Style.Brass
		c.Position = UDim2.fromScale(column[2], 0)
		c.Size = UDim2.fromScale(0.08, 1)
		c.Text = column[1]
	end
	y += 22
	local named = titles(s)
	for i, p in s.players do
		local row = Instance.new("Frame")
		row.Name = `Player{i}`
		row.BackgroundColor3 = if p.name == localPlayer.DisplayName then Style.Brass else Color3.new(0, 0, 0)
		row.BackgroundTransparency = if p.name == localPlayer.DisplayName then 0.85 else 1
		row.BorderSizePixel = 0
		row.Position = UDim2.fromOffset(20, y)
		row.Size = UDim2.new(1, -40, 0, 30)
		row.Parent = panel
		local name = Style.text(row, "Name", Style.Body, 20)
		name.Position = UDim2.fromOffset(8, 0)
		name.Size = UDim2.new(0.32, -8, 1, 0)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.TextWrapped = false
		name.Text = p.name
		for c, value in { p.cards, p.rooms, p.clues, p.caught } do
			local n = Style.text(row, COLUMNS[c][1], Style.Type, 18)
			n.Position = UDim2.fromScale(COLUMNS[c][2], 0)
			n.Size = UDim2.fromScale(0.08, 1)
			n.Text = tostring(value)
		end
		local status = Style.text(row, "Status", Style.Body, 18)
		status.Position = UDim2.new(0.66, 0, 0, 0)
		status.Size = UDim2.new(0.34, -8, 1, 0)
		status.TextXAlignment = Enum.TextXAlignment.Right
		status.TextWrapped = false
		local title = named[i]
		local state = if p.escaped then "Got out" elseif p.left then "Left early" else "Taken"
		status.RichText = true
		status.Text = if title then `{state} · <font color="#B08C48"><i>{title}</i></font>` else state
		status.TextColor3 = if p.escaped then Style.Ink elseif p.left then Color3.fromRGB(150, 140, 125) else Style.Blood
		y += 32
	end

	footer, y = line(panel, "Footer", Style.Type, 15, y + 10, "")
	footer.TextTransparency = 0.3
	y += 8
	local close = Style.button(panel, "Close", UDim2.fromOffset(120, 32), function()
		SummaryUI.hide()
	end)
	close.AnchorPoint = Vector2.new(0.5, 0)
	close.Position = UDim2.new(0.5, 0, 0, y)
	y += 50
	panel.Size = UDim2.fromOffset(WIDTH, y)
end

local function refresh()
	local s = summary
	if not open or not s then
		return
	end
	local left = math.max(0, math.ceil(s.nextAt - workspace:GetServerTimeNow()))
	footer.Text = if s.toStation then `Back to the ranger station in {left}s.` else `The table resets for another night in {left}s.`
end

function SummaryUI.isOpen(): boolean
	return open
end

function SummaryUI.hide()
	showToken += 1
	if not open then
		return
	end
	open = false
	fade(backdrop, { BackgroundTransparency = 1 }, 0.3)
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 }):Play()
	task.delay(0.3, function()
		if not open then
			screen.Enabled = false
		end
	end)
end

-- Once the ending has finished playing (and the numbers are in), up it comes.
function SummaryUI.showAfterEnding()
	showToken += 1
	local token = showToken
	task.spawn(function()
		local giveUp = os.clock() + 45
		while token == showToken and os.clock() < giveUp do
			if phase ~= "GameOver" then
				return
			end
			if summary and not Cinema.isPlaying() and not Cutscene.isShowing() then
				break
			end
			task.wait(0.25)
		end
		local s = summary
		if token ~= showToken or phase ~= "GameOver" or not s then
			return
		end
		build(s)
		open = true
		screen.Enabled = true
		local camera = workspace.CurrentCamera
		local height = if camera then camera.ViewportSize.Y else 720
		local fit = math.clamp(height / 820, 0.55, 1)
		scale.Scale = 0
		backdrop.BackgroundTransparency = 1
		fade(backdrop, { BackgroundTransparency = 0.35 }, 0.8)
		TweenService:Create(scale, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = fit }):Play()
		refresh()
		while open and token == showToken do
			task.wait(0.5)
			refresh()
		end
	end)
end

function SummaryUI.setState(state: Types.PublicState)
	phase = state.phase
	summary = state.summary
	result = state.result
	if phase ~= "GameOver" and open then
		SummaryUI.hide()
	end
end

function SummaryUI.init()
	screen = Instance.new("ScreenGui")
	screen.Name = "NightSummary"
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 30
	screen.Enabled = false
	backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 1
	backdrop.BorderSizePixel = 0
	backdrop.Parent = screen
	panel = Style.panel(backdrop, "Panel")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(WIDTH, 480)
	panel.BackgroundTransparency = 0.12
	scale = Instance.new("UIScale")
	scale.Parent = panel
	screen.Parent = localPlayer:WaitForChild("PlayerGui")
end

return SummaryUI
