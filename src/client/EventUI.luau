--!strict
-- The event banner: which event is running, what to do, a countdown, and whether you're out.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local EventUI = {}

local localPlayer = Players.LocalPlayer
local panel: Frame
local title: TextLabel
local body: TextLabel
local timer: TextLabel
local status: TextLabel
local event: Types.EventPublic? = nil

local function label(name: string, y: number, height: number, size: number, font: Enum.Font): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Position = UDim2.fromOffset(12, y)
	l.Size = UDim2.new(1, -24, 0, height)
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.fromRGB(255, 236, 228)
	l.Font = font
	l.TextSize = size
	l.TextWrapped = true
	l.Parent = panel
	return l
end

function EventUI.init(gui: ScreenGui)
	panel = Instance.new("Frame")
	panel.Name = "Event"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 220)
	panel.Size = UDim2.fromOffset(560, 150)
	panel.BackgroundColor3 = Color3.fromRGB(90, 16, 16)
	panel.BackgroundTransparency = 0.15
	panel.Visible = false
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	title = label("Title", 8, 30, 24, Enum.Font.GothamBlack)
	body = label("Body", 40, 44, 16, Enum.Font.GothamMedium)
	timer = label("Timer", 86, 30, 26, Enum.Font.GothamBold)
	status = label("Status", 118, 24, 15, Enum.Font.GothamMedium)

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
			timer.TextColor3 = if left <= 10 then Color3.fromRGB(255, 120, 100) else Color3.fromRGB(255, 236, 228)
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
	title.Text = `EVENT · {string.upper(current.name)}`
	body.Text = current.text
	local out = table.find(current.eliminated, localPlayer.UserId) ~= nil
	if out then
		status.Text = "You're out. Spectating from the Crawlspace."
	elseif current.over then
		status.Text = "Event over. Back to the table..."
	else
		status.Text = `{#current.eliminated} eliminated so far`
	end
end

return EventUI
