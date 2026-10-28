--!strict
-- Plays a cinematic: the camera follows a scene's path, black bars top and bottom, subtitles (and
-- their recorded voice lines, Config.Voice) and an optional title; walking and the HUD are off
-- while it runs, and a click skips it. Whatever happens (even an error in a scene), the camera,
-- the controls and the HUD are put back afterwards. Returns false if the scene failed, so the
-- caller can fall back to the plain text version.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Audio = require(script.Parent.Audio)

export type Line = {
	at: number, -- seconds into the scene
	line: string,
	speaker: string?, -- shown before the line, in brass
	voice: string?, -- Config.Voice key
	radio: boolean?,
	hold: number?, -- seconds to stay up (default: until the next line, or 3.5)
}

export type Scene = {
	length: number,
	camera: (t: number) -> CFrame, -- where the camera is t seconds in
	fov: ((t: number) -> number)?,
	lines: { Line }?,
	title: string?, -- big, centred, near the start
	titleAt: number?,
	onStart: (() -> ())?,
	onFrame: ((t: number) -> ())?,
	onEnd: (() -> ())?, -- always called (put back anything the scene changed)
	fadeIn: number?,
	fadeOut: number?,
}

local Cinema = {}

local localPlayer = Players.LocalPlayer
local playing = false

function Cinema.isPlaying(): boolean
	return playing
end

local function fade(obj: Instance, props: { [string]: any }, seconds: number)
	TweenService:Create(obj, TweenInfo.new(seconds, Enum.EasingStyle.Sine), props):Play()
end

local function label(parent: Instance, y: number, size: number, font: Enum.Font): TextLabel
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, y)
	l.Size = UDim2.new(0.72, 0, 0, size * 2 + 20)
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.fromRGB(232, 220, 192)
	l.TextStrokeColor3 = Color3.new(0, 0, 0)
	l.TextStrokeTransparency = 0.4
	l.Font = font
	l.TextSize = size
	l.TextWrapped = true
	l.RichText = true
	l.TextTransparency = 1
	l.ZIndex = 6
	l.Parent = parent
	return l
end

-- Play a scene; yields until it's over or skipped. Returns true if it ran without an error.
function Cinema.play(scene: Scene): boolean
	if playing then
		return false
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return false
	end
	playing = true

	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "Cinema"
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 40
	gui.ResetOnSpawn = false
	local black = Instance.new("Frame")
	black.Size = UDim2.fromScale(1, 1)
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.BorderSizePixel = 0
	black.ZIndex = 5
	black.Parent = gui
	local bars: { Frame } = {}
	for _, top in { true, false } do
		local bar = Instance.new("Frame")
		table.insert(bars, bar)
		bar.Size = UDim2.fromScale(1, 0.11)
		bar.Position = if top then UDim2.fromScale(0, 0) else UDim2.fromScale(0, 0.89)
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.BorderSizePixel = 0
		bar.ZIndex = 2
		bar.Parent = gui
	end
	local title = label(gui, 0.42, 58, Enum.Font.Fondamento)
	local subtitle = label(gui, 0.81, 22, Enum.Font.Fondamento)
	local hint = label(gui, 0.955, 14, Enum.Font.Fondamento)
	hint.Text = "Click to skip"
	local skip = Instance.new("TextButton")
	skip.Size = UDim2.fromScale(1, 1)
	skip.BackgroundTransparency = 1
	skip.Text = ""
	skip.ZIndex = 10
	skip.Parent = gui
	local skipped = false
	skip.Activated:Connect(function()
		skipped = true
	end)
	gui.Parent = playerGui

	-- No walking, no HUD, the camera is ours.
	local controls: any = nil
	pcall(function()
		local module = localPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)
		if module then
			controls = (require(module :: ModuleScript) :: any):GetControls()
			controls:Disable()
		end
	end)
	local hud = playerGui:FindFirstChild("HollowPinesHud")
	if hud and hud:IsA("ScreenGui") then
		hud.Enabled = false
	end
	local oldFov = camera.FieldOfView
	camera.CameraType = Enum.CameraType.Scriptable

	local ok, err = pcall(function()
		-- Recorded lines, loaded behind the black first so they can be timed.
		local lines = scene.lines or {}
		local voices: { [number]: Sound } = {}
		for i, line in lines do
			if line.voice then
				local sound = Audio.voiceSound(line.voice, line.radio)
				if sound then
					voices[i] = sound
				end
			end
		end
		local deadline = os.clock() + 2.5
		for _, sound in voices do
			while not sound.IsLoaded and os.clock() < deadline do
				task.wait()
			end
		end
		-- Each line at its time, or once the one before has been said.
		local slots: { { start: number, stop: number } } = {}
		local free = 0
		for i, line in lines do
			local following = lines[i + 1]
			local sound = voices[i]
			local spoken = if sound and sound.IsLoaded then sound.TimeLength else 0
			local start = math.max(line.at, free)
			local shown = line.hold or (if following then following.at - line.at - 0.3 else 3.5)
			slots[i] = { start = start, stop = start + math.max(shown, spoken + 0.3) }
			free = start + spoken + 0.25
		end
		local length = scene.length
		if #slots > 0 then
			length = math.max(length, slots[#slots].stop + 0.8)
		end
		local fadeOut = scene.fadeOut or 1.2

		if scene.onStart then
			scene.onStart()
		end
		camera.CFrame = scene.camera(0)
		fade(black, { BackgroundTransparency = 1 }, scene.fadeIn or 1.2)
		fade(hint, { TextTransparency = 0.5 }, 1.5)
		local titleShown, titleGone, fadingOut = false, false, false
		local nextLine = 1
		local showing: { start: number, stop: number }? = nil
		local started = os.clock()
		while not skipped do
			local t = os.clock() - started
			if t >= length then
				break
			end
			camera.CFrame = scene.camera(t)
			if scene.fov then
				camera.FieldOfView = scene.fov(t)
			end
			if scene.onFrame then
				scene.onFrame(t)
			end
			if scene.title then
				local at = scene.titleAt or 0.6
				if not titleShown and t >= at then
					titleShown = true
					title.Text = scene.title
					fade(title, { TextTransparency = 0 }, 1.2)
				elseif titleShown and not titleGone and t >= at + 3 then
					titleGone = true
					fade(title, { TextTransparency = 1 }, 1)
				end
			end
			local line = lines[nextLine]
			local slot = slots[nextLine]
			if line and slot and t >= slot.start then
				local sound = voices[nextLine]
				if sound then
					sound:Play()
				end
				nextLine += 1
				showing = slot
				subtitle.Text = if line.speaker then `<font color="#B08C48">{string.upper(line.speaker)}</font>   {line.line}` else `<i>{line.line}</i>`
				fade(subtitle, { TextTransparency = 0 }, 0.4)
			elseif showing and t >= showing.stop then
				showing = nil
				fade(subtitle, { TextTransparency = 1 }, 0.5)
			end
			if not fadingOut and t >= length - fadeOut then
				fadingOut = true
				fade(black, { BackgroundTransparency = 0 }, fadeOut)
			end
			RunService.RenderStepped:Wait()
		end
		for _, sound in voices do
			sound:Destroy()
		end
	end)
	if not ok then
		warn(`Hollow Pines cinematic failed: {err}`)
	end

	-- Put everything back.
	if scene.onEnd then
		pcall(scene.onEnd)
	end
	camera.FieldOfView = oldFov
	local character = localPlayer.Character
	local head = character and character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		camera.CFrame = head.CFrame
	end
	camera.CameraType = Enum.CameraType.Custom
	if controls then
		pcall(function()
			controls:Enable()
		end)
	end
	if hud and hud:IsA("ScreenGui") then
		hud.Enabled = true
	end
	-- Fade back from black over the real view.
	black.BackgroundTransparency = 0
	title.TextTransparency = 1
	subtitle.TextTransparency = 1
	hint.TextTransparency = 1
	skip:Destroy()
	fade(black, { BackgroundTransparency = 1 }, 0.8)
	for _, bar in bars do
		fade(bar, { BackgroundTransparency = 1 }, 0.8)
	end
	task.delay(0.9, function()
		gui:Destroy()
	end)
	playing = false
	return ok
end

return Cinema
