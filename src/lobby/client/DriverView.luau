--!strict
-- The old driver by the stove (lobby server OldDriver), on this client: his head turns to follow
-- you when you're near him, and what he says to you comes up as a line at the bottom of the
-- screen, in his voice when it's been recorded (Config.Voice driver_N, played from where he sits).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DriverView = {}

local WATCH_DISTANCE = 28
local MAX_YAW = math.rad(70)
local MAX_PITCH = math.rad(25)
local LINE_SECONDS = 6

local localPlayer = Players.LocalPlayer
local lineLabel: TextLabel
local lineToken = 0
local voice: Sound? = nil

local function soundId(key: string): string?
	local id = Config.Voice[key]
	if typeof(id) ~= "string" or id == "" then
		return nil
	end
	return if string.match(id, "^%d+$") then `rbxassetid://{id}` else id
end

local function say(text: string, voiceKey: string, from: BasePart?)
	lineToken += 1
	local mine = lineToken
	lineLabel.Text = `<font color="#B08C48">Old driver</font>   {text}`
	lineLabel.TextTransparency = 1
	lineLabel.Visible = true
	TweenService:Create(lineLabel, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
	if voice then
		voice:Destroy()
		voice = nil
	end
	local seconds = LINE_SECONDS
	local id = soundId(voiceKey)
	if id and from then
		local sound = Instance.new("Sound")
		sound.SoundId = id
		sound.Volume = Config.VoiceVolume
		sound.RollOffMaxDistance = 60
		sound.Parent = from
		sound.Ended:Once(function()
			sound:Destroy()
		end)
		sound:Play()
		voice = sound
		-- Stay up as long as he's talking (its length is known once it's loaded).
		local waited = 0
		while not sound.IsLoaded and waited < 2 do
			waited += task.wait()
		end
		seconds = math.max(seconds, sound.TimeLength + 1)
	end
	task.delay(seconds, function()
		if lineToken == mine then
			TweenService:Create(lineLabel, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		end
	end)
end

function DriverView.init(screen: ScreenGui)
	lineLabel = Instance.new("TextLabel")
	lineLabel.Name = "DriverLine"
	lineLabel.AnchorPoint = Vector2.new(0.5, 1)
	lineLabel.Position = UDim2.new(0.5, 0, 1, -40)
	lineLabel.Size = UDim2.new(0.7, 0, 0, 70)
	lineLabel.BackgroundTransparency = 1
	lineLabel.TextColor3 = Color3.fromRGB(232, 220, 192)
	lineLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	lineLabel.TextStrokeTransparency = 0.35
	lineLabel.Font = Enum.Font.Fondamento
	lineLabel.TextSize = 22
	lineLabel.TextWrapped = true
	lineLabel.RichText = true
	lineLabel.Visible = false
	lineLabel.Parent = screen

	task.spawn(function()
		local station = workspace:WaitForChild("RangerStation", 30)
		local driver = station and station:WaitForChild("OldDriver", 30)
		local headGroup = driver and driver:WaitForChild("HeadGroup", 30)
		if not headGroup or not headGroup:IsA("Model") then
			return
		end
		local head = headGroup.PrimaryPart
		local rest = headGroup:GetPivot()
		local current = rest
		local says = ReplicatedStorage:WaitForChild("DriverSays") :: RemoteEvent
		says.OnClientEvent:Connect(function(text: string, voiceKey: string)
			say(text, voiceKey, head)
		end)

		-- He watches you while you're near; otherwise he looks back at the room.
		RunService.RenderStepped:Connect(function(dt: number)
			local character = localPlayer.Character
			local yours = character and character:FindFirstChild("Head")
			local want = rest
			if yours and yours:IsA("BasePart") and (yours.Position - rest.Position).Magnitude < WATCH_DISTANCE then
				local dir = rest:PointToObjectSpace(yours.Position)
				local flat = math.sqrt(dir.X * dir.X + dir.Z * dir.Z)
				local yaw = math.clamp(math.atan2(-dir.X, -dir.Z), -MAX_YAW, MAX_YAW)
				local pitch = math.clamp(math.atan2(dir.Y, math.max(flat, 0.01)), -MAX_PITCH, MAX_PITCH)
				want = rest * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
			end
			current = current:Lerp(want, math.min(1, dt * 3))
			headGroup:PivotTo(current)
		end)
	end)
end

return DriverView
