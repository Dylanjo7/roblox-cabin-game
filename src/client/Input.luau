--!strict
-- Keyboard input. Keys only trigger client actions or send intents; the server decides what's allowed.

local UserInputService = game:GetService("UserInputService")

local Input = {}

local bindings: { [Enum.KeyCode]: () -> () } = {}

function Input.bind(key: Enum.KeyCode, action: () -> ())
	bindings[key] = action
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
