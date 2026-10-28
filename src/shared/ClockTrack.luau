--!strict
-- Where clock-track positions are on the Parlor table's ring (shared so the server engraves the
-- track and the client moves the pieces with the same numbers).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local ClockTrack = {}

-- Ring-local CFrame of a clock-track position, on top of the ring. The 13 marks spread over an
-- arc centred on the side facing the active player. Step -1 is "off the track". Fractional
-- steps are in between (pieces moving). The frame's +X points the way the clock runs.
function ClockTrack.localCFrame(step: number, radius: number): CFrame
	local arc = math.rad(Config.Table.TrackArcDegrees)
	local angle = -arc / 2 + step * arc / Config.Clock.Steps
	return CFrame.Angles(0, angle, 0) * CFrame.new(0, Config.Table.TopHeight, radius)
end

return ClockTrack
