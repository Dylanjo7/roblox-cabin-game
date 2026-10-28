--!strict
-- The client side of two events.
--   Don't Look Away: when the lights fail (the pale figure's Blink attribute goes up), your
--     screen goes black for a moment, and when it comes back the thing has moved.
--   Hush: while the house is listening, the colour drains out and you hear your own heart.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local PaleFigureModel = require(Shared:WaitForChild("PaleFigureModel"))
local Types = require(Shared:WaitForChild("Types"))

local Audio = require(script.Parent.Audio)

local EventFx = {}

local black: Frame
local drain: ColorCorrectionEffect
local pulse: Sound -- its own heartbeat, apart from the dread one (Atmosphere)
local hushed = false
local blinkToken = 0

local function blink()
	blinkToken += 1
	local token = blinkToken
	Audio.play("flicker", 0.45)
	black.BackgroundTransparency = 0
	black.Visible = true
	task.delay(Config.Events.DontLook.BlinkSeconds, function()
		if token ~= blinkToken then
			return
		end
		local fade = TweenService:Create(black, TweenInfo.new(0.12), { BackgroundTransparency = 1 })
		fade.Completed:Once(function()
			if token == blinkToken then
				black.Visible = false
			end
		end)
		fade:Play()
	end)
end

local function watch(figure: Instance)
	figure:GetAttributeChangedSignal("Blink"):Connect(function()
		local count = figure:GetAttribute("Blink")
		if typeof(count) == "number" and count > 0 then
			blink()
		end
	end)
end

local function setHushed(on: boolean)
	if on == hushed then
		return
	end
	hushed = on
	TweenService:Create(drain, TweenInfo.new(if on then 0.25 else 0.8), {
		Saturation = if on then -0.75 else 0,
		Contrast = if on then 0.12 else 0,
	}):Play()
	TweenService:Create(pulse, TweenInfo.new(if on then 0.3 else 1), { Volume = if on then 0.6 else 0 }):Play()
end

function EventFx.setState(state: Types.PublicState)
	local event = state.event
	setHushed(event ~= nil and event.id == "hush" and event.alert == true and not event.over)
end

function EventFx.init(gui: ScreenGui)
	local screen = Instance.new("ScreenGui")
	screen.Name = "Blink"
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 40 -- over the HUD, under the jump scares
	screen.ResetOnSpawn = false
	screen.Parent = gui.Parent
	black = Instance.new("Frame")
	black.Size = UDim2.fromScale(1, 1)
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.BorderSizePixel = 0
	black.Visible = false
	black.Parent = screen

	drain = Instance.new("ColorCorrectionEffect")
	drain.Name = "HushDrain"
	drain.Parent = Lighting
	pulse = Instance.new("Sound")
	pulse.Name = "HushHeartbeat"
	pulse.SoundId = Config.Sounds.heartbeat
	pulse.Looped = true
	pulse.Volume = 0
	pulse.PlaybackSpeed = 1.15
	pulse.Parent = SoundService
	pulse:Play()

	for _, figure in CollectionService:GetTagged(PaleFigureModel.Tag) do
		watch(figure)
	end
	CollectionService:GetInstanceAddedSignal(PaleFigureModel.Tag):Connect(watch)
end

return EventFx
