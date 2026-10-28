--!strict
-- The clock track on screen: 9:00 PM to 3:00 AM, the Candle above the track and the Hollow Man
-- below it. A red banner shows when he has reached the Candle and this is a last turn.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClockUtil = require(Shared:WaitForChild("ClockUtil"))
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))

local SLOT_WIDTH = 50
local CANDLE = Color3.fromRGB(255, 190, 90)
local HOLLOW = Color3.fromRGB(200, 60, 60)

local ClockUI = {}

local panel: Frame
local candleMarker: Frame
local hollowMarker: Frame
local summary: TextLabel
local banner: TextLabel

local function marker(name: string, color: Color3, y: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.fromOffset(16, 16)
	f.BackgroundColor3 = color
	f.Position = UDim2.fromOffset(0, y)
	f.Parent = panel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = f
	return f
end

local function slotX(step: number): number
	return 10 + SLOT_WIDTH / 2 + step * SLOT_WIDTH
end

function ClockUI.init(gui: ScreenGui)
	local steps = Config.Clock.Steps
	panel = Instance.new("Frame")
	panel.Name = "ClockTrack"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 86)
	panel.Size = UDim2.fromOffset(20 + (steps + 1) * SLOT_WIDTH, 92)
	panel.BackgroundColor3 = Color3.fromRGB(18, 20, 18)
	panel.BackgroundTransparency = 0.3
	panel.Visible = false
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = panel

	local line = Instance.new("Frame")
	line.Size = UDim2.fromOffset(steps * SLOT_WIDTH, 2)
	line.Position = UDim2.fromOffset(slotX(0), 36)
	line.BackgroundColor3 = Color3.fromRGB(150, 145, 135)
	line.BorderSizePixel = 0
	line.Parent = panel

	for step = 0, steps do
		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.Position = UDim2.fromOffset(slotX(step), 44)
		label.Size = UDim2.fromOffset(SLOT_WIDTH, 14)
		label.BackgroundTransparency = 1
		label.TextColor3 = if step % 2 == 0 then Color3.fromRGB(230, 222, 200) else Color3.fromRGB(150, 145, 135)
		label.Font = Enum.Font.GothamMedium
		label.TextSize = 11
		label.Text = ClockUtil.stepToText(step)
		label.Parent = panel
	end

	candleMarker = marker("Candle", CANDLE, 22)
	hollowMarker = marker("HollowMan", HOLLOW, 66)
	hollowMarker.Size = UDim2.fromOffset(14, 14)
	local square = hollowMarker:FindFirstChildOfClass("UICorner")
	if square then
		square.CornerRadius = UDim.new(0, 2)
	end

	summary = Instance.new("TextLabel")
	summary.Position = UDim2.fromOffset(10, 4)
	summary.Size = UDim2.new(1, -20, 0, 12)
	summary.BackgroundTransparency = 1
	summary.TextColor3 = Color3.fromRGB(200, 192, 172)
	summary.Font = Enum.Font.Gotham
	summary.TextSize = 11
	summary.TextXAlignment = Enum.TextXAlignment.Left
	summary.Parent = panel

	banner = Instance.new("TextLabel")
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 1, 6)
	banner.Size = UDim2.fromOffset(520, 30)
	banner.BackgroundColor3 = Color3.fromRGB(120, 24, 24)
	banner.TextColor3 = Color3.fromRGB(255, 240, 230)
	banner.Font = Enum.Font.GothamBold
	banner.TextSize = 16
	banner.Text = "LAST TURN · the Candle must move forward"
	banner.Visible = false
	banner.Parent = panel
	local bannerCorner = Instance.new("UICorner")
	bannerCorner.CornerRadius = UDim.new(0, 6)
	bannerCorner.Parent = banner
end

function ClockUI.setState(state: Types.PublicState)
	local clock = state.clock
	panel.Visible = clock ~= nil and state.phase ~= "Lobby"
	if not clock then
		return
	end
	candleMarker.Position = UDim2.fromOffset(slotX(clock.candle), 22)
	local hollow = clock.hollow
	if hollow then
		hollowMarker.Visible = true
		hollowMarker.Position = UDim2.fromOffset(slotX(hollow), 66)
		local gap = clock.candle - hollow
		summary.Text = `Candle {ClockUtil.stepToText(clock.candle)} · Hollow Man {ClockUtil.stepToText(hollow)} · gap {gap * Config.Clock.StepMinutes} min`
	else
		hollowMarker.Visible = false
		summary.Text = `Candle {ClockUtil.stepToText(clock.candle)} · Hollow Man off the track (enters after round 1)`
	end
	banner.Visible = clock.lastTurn and state.phase == "TurnLoop"
end

return ClockUI
