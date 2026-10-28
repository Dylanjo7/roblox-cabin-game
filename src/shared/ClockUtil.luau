--!strict
-- Converts clock-track step indexes to display times.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local ClockUtil = {}

function ClockUtil.stepToText(step: number): string
	local minutes = Config.Clock.StartMinutes + step * Config.Clock.StepMinutes
	local hour24 = (minutes // 60) % 24
	local minute = minutes % 60
	local suffix = if hour24 >= 12 then "PM" else "AM"
	local hour12 = hour24 % 12
	if hour12 == 0 then
		hour12 = 12
	end
	return string.format("%d:%02d %s", hour12, minute, suffix)
end

return ClockUtil
