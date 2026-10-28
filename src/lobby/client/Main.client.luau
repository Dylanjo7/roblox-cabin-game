--!strict
-- Lobby client: a hint line at the top, short messages from the server (trucks, teleports), the
-- supplies panel at the front desk, and the old driver by the stove.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DriverView = require(script.Parent.DriverView)
local ShopUI = require(script.Parent.ShopUI)

local screen = Instance.new("ScreenGui")
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Name = "LobbyHud"
screen.ResetOnSpawn = false

local function label(name: string, y: number, height: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = UDim2.new(0.5, 0, 0, y)
	l.Size = UDim2.new(0, 640, 0, height)
	l.BackgroundColor3 = Color3.fromRGB(18, 20, 18)
	l.BackgroundTransparency = 0.3
	l.TextColor3 = Color3.fromRGB(230, 222, 200)
	l.Font = Enum.Font.GothamMedium
	l.TextSize = 18
	l.TextWrapped = true
	l.Parent = screen
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = l
	return l
end

local hint = label("Hint", 8, 34)
hint.Text = `HOLLOW PINES  ·  Step onto the pad behind a truck to ride up to the cabin (1 to {Config.MaxPlayers} players).`
local toast = label("Toast", 48, 30)
toast.Visible = false
ShopUI.init(screen)
DriverView.init(screen)
screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local token = 0
local remote = ReplicatedStorage:WaitForChild("LobbyNotify") :: RemoteEvent
remote.OnClientEvent:Connect(function(text: string)
	token += 1
	local mine = token
	toast.Text = text
	toast.Visible = true
	task.delay(Config.UI.ToastSeconds + 1, function()
		if token == mine then
			toast.Visible = false
		end
	end)
end)
