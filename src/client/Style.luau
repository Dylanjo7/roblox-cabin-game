--!strict
-- One look for every screen: faded ink on old paper, period type, no grey boxes. Text floats
-- over the scene with a dark halo so it reads against anything.

local Style = {}

Style.Ink = Color3.fromRGB(232, 220, 192) -- pale parchment text
Style.Shadow = Color3.fromRGB(8, 6, 4)
Style.Blood = Color3.fromRGB(176, 34, 26)
Style.Wood = Color3.fromRGB(46, 32, 22)
Style.Brass = Color3.fromRGB(176, 140, 72)

Style.Title = Enum.Font.Creepster -- event names, the big moments
Style.Body = Enum.Font.Fondamento -- everything else
Style.Type = Enum.Font.SpecialElite -- small print

-- Floating text with a dark halo.
function Style.text(parent: Instance, name: string, font: Enum.Font, size: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.TextColor3 = Style.Ink
	l.TextStrokeColor3 = Style.Shadow
	l.TextStrokeTransparency = 0.35
	l.Font = font
	l.TextSize = size
	l.TextWrapped = true
	l.Parent = parent
	return l
end

-- A button like a small dark wooden plaque with a brass edge.
function Style.button(parent: Instance, text: string, size: UDim2, onClick: (() -> ())?): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.AutoButtonColor = true
	b.BackgroundColor3 = Style.Wood
	b.BackgroundTransparency = 0.1
	b.TextColor3 = Style.Ink
	b.Font = Style.Body
	b.TextSize = 18
	b.Text = text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 3)
	corner.Parent = b
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = Style.Brass
	edge.Transparency = 0.45
	edge.Thickness = 1
	edge.Parent = b
	if onClick then
		b.Activated:Connect(onClick)
	end
	b.Parent = parent
	return b
end

-- A panel: dark, soft-edged, mostly see-through, for things that need a backing (the Altar,
-- Peek, Swap).
function Style.panel(parent: Instance, name: string): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = Color3.fromRGB(14, 11, 9)
	f.BackgroundTransparency = 0.25
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = f
	local edge = Instance.new("UIStroke")
	edge.Color = Style.Brass
	edge.Transparency = 0.7
	edge.Parent = f
	f.Parent = parent
	return f
end

-- Darkened screen edges (no image assets: four gradient strips).
function Style.vignette(parent: Instance)
	local holder = Instance.new("Frame")
	holder.Name = "Vignette"
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 0
	holder.Parent = parent
	local sides = {
		{ UDim2.fromScale(1, 0.22), UDim2.fromScale(0, 0), 90 },
		{ UDim2.fromScale(1, 0.22), UDim2.fromScale(0, 0.78), -90 },
		{ UDim2.fromScale(0.16, 1), UDim2.fromScale(0, 0), 0 },
		{ UDim2.fromScale(0.16, 1), UDim2.fromScale(0.84, 0), 180 },
	}
	for _, s in sides do
		local f = Instance.new("Frame")
		f.Size = s[1]
		f.Position = s[2]
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.ZIndex = 0
		f.Parent = holder
		local g = Instance.new("UIGradient")
		g.Rotation = s[3]
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = f
	end
end

return Style
