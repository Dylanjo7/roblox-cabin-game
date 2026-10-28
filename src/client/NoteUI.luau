--!strict
-- A note from the missing four, held up to read: an old page in their handwriting, signed.
-- Opens when you pick one up (ShowNote from the server); click anywhere to put it down. Every
-- note found is kept in the Journal ("Their notes").

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Story = require(Shared:WaitForChild("Story"))

local Audio = require(script.Parent.Audio)

local NoteUI = {}

local holder: TextButton
local paper: Frame
local body: TextLabel
local signature: TextLabel

function NoteUI.init(gui: ScreenGui)
	-- A full-screen button behind the page: click anywhere to put it down.
	holder = Instance.new("TextButton")
	holder.Name = "Note"
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundColor3 = Color3.new(0, 0, 0)
	holder.BackgroundTransparency = 0.45
	holder.AutoButtonColor = false
	holder.Text = ""
	holder.ZIndex = 40
	holder.Visible = false
	holder.Parent = gui

	paper = Instance.new("Frame")
	paper.AnchorPoint = Vector2.new(0.5, 0.5)
	paper.Position = UDim2.fromScale(0.5, 0.5)
	paper.Size = UDim2.fromOffset(440, 520)
	paper.Rotation = -2
	paper.BackgroundColor3 = Color3.fromRGB(222, 208, 176)
	paper.Parent = holder
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(120, 96, 64)
	stroke.Thickness = 2
	stroke.Parent = paper
	local age = Instance.new("UIGradient")
	age.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(190, 170, 130)),
		ColorSequenceKeypoint.new(0.2, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.8, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 160, 120)),
	})
	age.Rotation = 70
	age.Parent = paper
	-- Ruled lines.
	for i = 1, 14 do
		local line = Instance.new("Frame")
		line.Position = UDim2.new(0, 30, 0, 60 + i * 30)
		line.Size = UDim2.new(1, -60, 0, 1)
		line.BackgroundColor3 = Color3.fromRGB(150, 160, 180)
		line.BackgroundTransparency = 0.55
		line.BorderSizePixel = 0
		line.Parent = paper
	end

	body = Instance.new("TextLabel")
	body.Position = UDim2.fromOffset(34, 64)
	body.Size = UDim2.new(1, -68, 1, -150)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.IndieFlower
	body.TextSize = 26
	body.LineHeight = 1.05
	body.TextColor3 = Color3.fromRGB(44, 34, 30)
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.ZIndex = 2
	body.Parent = paper

	signature = Instance.new("TextLabel")
	signature.AnchorPoint = Vector2.new(1, 1)
	signature.Position = UDim2.new(1, -34, 1, -54)
	signature.Size = UDim2.fromOffset(240, 40)
	signature.BackgroundTransparency = 1
	signature.Font = Enum.Font.IndieFlower
	signature.TextSize = 30
	signature.TextColor3 = Color3.fromRGB(60, 40, 34)
	signature.TextXAlignment = Enum.TextXAlignment.Right
	signature.ZIndex = 2
	signature.Parent = paper

	local hint = Instance.new("TextLabel")
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -14)
	hint.Size = UDim2.fromOffset(300, 20)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Fondamento
	hint.TextSize = 14
	hint.TextColor3 = Color3.fromRGB(120, 100, 80)
	hint.Text = "Click to put it down · it's in the Journal now"
	hint.ZIndex = 2
	hint.Parent = paper

	holder.Activated:Connect(function()
		holder.Visible = false
		Audio.play("card", 0.3, nil, 0.9)
	end)
	Remotes.event("ShowNote").OnClientEvent:Connect(function(index: any)
		if typeof(index) == "number" then
			NoteUI.show(index)
		end
	end)
end

function NoteUI.show(index: number)
	local note = Story.Notes[index]
	if not note then
		return
	end
	body.Text = note.text
	signature.Text = `— {note.by}`
	holder.Visible = true
	paper.Position = UDim2.fromScale(0.5, 0.56)
	TweenService:Create(paper, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	Audio.play("card", 0.5, nil, 0.8)
end

function NoteUI.isOpen(): boolean
	return holder ~= nil and holder.Visible
end

return NoteUI
