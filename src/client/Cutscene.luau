--!strict
-- Story on screen: the intro when a run starts, the ending when it's over, and short "beats"
-- (one line at the bottom of the screen) as the Hollow Man closes in. Text lives in Story.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Story = require(Shared:WaitForChild("Story"))

local Audio = require(script.Parent.Audio)

local Cutscene = {}

local overlay: TextButton -- full-screen; a click skips
local title: TextLabel
local line: TextLabel
local hint: TextLabel
local beatLabel: TextLabel
local playToken = 0
local beatToken = 0

local function fade(obj: GuiObject, props: { [string]: any }, seconds: number)
	TweenService:Create(obj, TweenInfo.new(seconds, Enum.EasingStyle.Sine), props):Play()
end

local function text(name: string, parent: Instance, font: Enum.Font, size: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.fromRGB(226, 216, 196)
	l.Font = font
	l.TextSize = size
	l.TextWrapped = true
	l.TextTransparency = 1
	l.Parent = parent
	return l
end

function Cutscene.init(gui: ScreenGui)
	-- Its own full-screen layer above everything, covering the top bar too.
	local layer = Instance.new("ScreenGui")
	layer.Name = "HollowPinesCutscene"
	layer.IgnoreGuiInset = true
	layer.ResetOnSpawn = false
	layer.DisplayOrder = 10
	layer.Parent = gui.Parent

	overlay = Instance.new("TextButton")
	overlay.Name = "Cutscene"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 1
	overlay.AutoButtonColor = false
	overlay.Text = ""
	overlay.ZIndex = 50
	overlay.Visible = false
	overlay.Parent = layer

	title = text("Title", overlay, Enum.Font.Fondamento, 54)
	title.Position = UDim2.fromScale(0.5, 0.38)
	title.Size = UDim2.new(0.8, 0, 0, 70)
	title.ZIndex = 51
	line = text("Line", overlay, Enum.Font.Merriweather, 24)
	line.Position = UDim2.fromScale(0.5, 0.52)
	line.Size = UDim2.new(0.6, 0, 0, 140)
	line.ZIndex = 51
	hint = text("Hint", overlay, Enum.Font.Fondamento, 14)
	hint.Position = UDim2.new(0.5, 0, 1, -40)
	hint.Size = UDim2.new(0.5, 0, 0, 20)
	hint.ZIndex = 51
	hint.Text = "Click to skip"

	beatLabel = text("Beat", gui, Enum.Font.Merriweather, 22)
	beatLabel.Position = UDim2.new(0.5, 0, 1, -230)
	beatLabel.Size = UDim2.new(0.7, 0, 0, 40)
	beatLabel.TextStrokeTransparency = 1
	beatLabel.TextColor3 = Color3.fromRGB(220, 200, 190)

	overlay.Activated:Connect(function()
		playToken += 1 -- stops the running sequence
		fade(overlay, { BackgroundTransparency = 1 }, 0.6)
		fade(title, { TextTransparency = 1 }, 0.4)
		fade(line, { TextTransparency = 1 }, 0.4)
		fade(hint, { TextTransparency = 1 }, 0.4)
		task.delay(0.6, function()
			overlay.Visible = false
		end)
	end)
end

-- Black screen, a title, then each line in turn (spoken too if it's been recorded: voice key
-- `{voicePrefix}_{n}`; a line stays up until its recording is over). Returns when done or skipped.
local function play(heading: string, lines: { string }, lineSeconds: number, voicePrefix: string)
	playToken += 1
	local token = playToken
	overlay.Visible = true
	overlay.BackgroundTransparency = 1
	fade(overlay, { BackgroundTransparency = 0 }, 1)
	title.Text = heading
	fade(title, { TextTransparency = 0 }, 1.5)
	fade(hint, { TextTransparency = 0.5 }, 1.5)
	task.wait(2)
	for i, entry in lines do
		if token ~= playToken then
			return
		end
		line.Text = entry
		fade(line, { TextTransparency = 0 }, 0.8)
		local spoken = Audio.speak(`{voicePrefix}_{i}`)
		task.wait(math.max(lineSeconds, spoken + 0.6))
		if token ~= playToken then
			return
		end
		fade(line, { TextTransparency = 1 }, 0.6)
		task.wait(0.7)
	end
	if token ~= playToken then
		return
	end
	fade(title, { TextTransparency = 1 }, 1)
	fade(hint, { TextTransparency = 1 }, 1)
	fade(overlay, { BackgroundTransparency = 1 }, 1.5)
	task.wait(1.5)
	if token == playToken then
		overlay.Visible = false
	end
end

function Cutscene.playIntro()
	task.spawn(play, Story.Title, Story.Intro, Config.UI.IntroLineSeconds, "intro")
end

function Cutscene.playEnding(key: string)
	local ending = Story.Endings[key]
	if not ending then
		return
	end
	Audio.play("ending", 0.6)
	task.spawn(play, ending.title, ending.lines, Config.UI.EndingLineSeconds, `ending_{key}`)
end

-- Arriving by the truck: the screen fades up from black, then the arrival lines appear one by
-- one low on the screen while you walk. afterTrip: the drive up (Trip) just played, so no title
-- and the lines that follow on from it.
function Cutscene.playArrival(afterTrip: boolean?)
	-- Shares the token with play(): if the intro starts (you got inside fast), this stops.
	playToken += 1
	local token = playToken
	overlay.Visible = true
	overlay.BackgroundTransparency = 0
	title.Text = Story.Title
	title.TextTransparency = if afterTrip then 1 else 0
	task.spawn(function()
		task.wait(if afterTrip then 0.3 else 1.5)
		if token ~= playToken then
			return
		end
		fade(title, { TextTransparency = 1 }, 1.5)
		fade(overlay, { BackgroundTransparency = 1 }, 2.5)
		task.wait(2.5)
		if token ~= playToken then
			return
		end
		overlay.Visible = false
		for i, entry in (if afterTrip then Story.ArrivalAfterTrip else Story.Arrival) do
			if token ~= playToken then
				return
			end
			Cutscene.beat(entry, if afterTrip then `arrival_{i}` else nil)
			task.wait(5.5)
		end
	end)
end

-- One line low on the screen that fades in and out (and its recording, if voiceKey has one).
function Cutscene.beat(textLine: string, voiceKey: string?)
	if voiceKey then
		task.spawn(Audio.speak, voiceKey)
	end
	beatToken += 1
	local token = beatToken
	beatLabel.Text = textLine
	fade(beatLabel, { TextTransparency = 0.05 }, 0.8)
	task.delay(4, function()
		if token == beatToken then
			fade(beatLabel, { TextTransparency = 1 }, 1.2)
		end
	end)
end

function Cutscene.isShowing(): boolean
	return overlay ~= nil and overlay.Visible
end

return Cutscene
