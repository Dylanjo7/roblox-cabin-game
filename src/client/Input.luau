--!strict
-- Keyboard input (and the touch buttons, through trigger). Keys only trigger client actions or
-- send intents; the server decides what's allowed.

local UserInputService = game:GetService("UserInputService")

local Input = {}

local bindings: { [Enum.KeyCode]: () -> () } = {}

function Input.bind(key: Enum.KeyCode, action: () -> ())
	bindings[key] = action
end

-- Run a key's action as if it had been pressed (the on-screen touch buttons use this).
function Input.trigger(key: Enum.KeyCode)
	local action = bindings[key]
	if action then
		action()
	end
end

function Input.init()
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		local action = bindings[input.KeyCode]
		if action then
			action()
		end
	end)
end

return Input
