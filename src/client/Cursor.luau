--!strict
-- Everyone plays in first person, which locks the mouse to the centre of the screen. While you
-- need to click things (seated at the table with your hand out, or a panel or cutscene open),
-- an invisible modal button frees the cursor.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Cursor = {}

function Cursor.init(gui: ScreenGui, panelOpen: () -> boolean)
	local free = Instance.new("TextButton")
	free.Name = "FreeCursor"
	free.Size = UDim2.fromOffset(0, 0)
	free.BackgroundTransparency = 1
	free.Text = ""
	free.Modal = false
	free.Parent = gui

	local localPlayer = Players.LocalPlayer
	RunService.RenderStepped:Connect(function()
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seated = humanoid ~= nil and humanoid.Sit
		free.Modal = seated or panelOpen()
	end)
end

return Cursor
