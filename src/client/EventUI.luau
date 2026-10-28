--!strict
-- The event banner: which event is running, what to do, a countdown, the event's live status
-- (mirrors covered, "HUSH" while the house listens) and whether you're out.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local Style = require(script.Parent.Style)

local EventUI = {}

local localPlayer = Players.LocalPlayer
local panel: Frame
local title: TextLabel
local body: TextLabel
local timer: TextLabel
local detail: TextLabel
local status: TextLabel
local event: Types.EventPublic? = nil

function EventUI.init(gui: ScreenGui)
	-- No box: the event's name in big red letters across the top, over a band of shadow.
	panel = Instance.new("Frame")
	panel.Name = "Event"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 96)
	panel.Size = UDim2.new(0.7, 0, 0, 206)
	panel.BackgroundColor3 = Color3.new(0, 0, 0)
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	local band = Instance.new("UIGradient")
	band.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.55),
		NumberSequenceKeypoint.new(0.7, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	band.Parent = panel

	local function place(l: TextLabel, y: number, height: number)
		l.Position = UDim2.fromOffset(0, y)
		l.Size = UDim2.new(1, 0, 0, height)
	end
	title = Style.text(panel, "Title", Style.Title, 46)
	title.TextColor3 = Style.Blood
	place(title, 4, 52)
	body = Style.text(panel, "Body", Style.Body, 20)
	place(body, 58, 50)
	timer = Style.text(panel, "Timer", Style.Body, 34)
	place(timer, 106, 38)
	detail = Style.text(panel, "Detail", Style.Body, 24)
	place(detail, 144, 34)
	status = Style.text(panel, "Status", Style.Type, 15)
	status.TextTransparency = 0.2
	place(status, 180, 22)

	RunService.Heartbeat:Connect(function()
		local current = event
		if not current then
			return
		end
		if current.over then
			timer.Text = "Time's up"
		else
			local left = math.max(0, math.ceil(current.endsAt - workspace:GetServerTimeNow()))
			timer.Text = `{left}s`
			timer.TextColor3 = if left <= 10 then Style.Blood else Style.Ink
		end
	end)
end

function EventUI.setState(state: Types.PublicState)
	local current = state.event
	event = current
	panel.Visible = current ~= nil
	if not current then
		return
	end
	title.Text = current.name
	body.Text = current.text
	detail.Text = current.detail or ""
	if current.alert and not current.over then
		detail.Font = Style.Title
		detail.TextSize = 40
		detail.TextColor3 = Style.Blood
	else
		detail.Font = Style.Body
		detail.TextSize = 24
		detail.TextColor3 = Style.Ink
	end
	local out = table.find(current.eliminated, localPlayer.UserId) ~= nil
	if out then
		status.Text = "You're out. The basement door is barred until it's over."
	elseif current.over then
		status.Text = "Event over. Back to the table..."
	else
		status.Text = `{#current.eliminated} eliminated so far`
	end
end

return EventUI
