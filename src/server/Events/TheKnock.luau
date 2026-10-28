--!strict
-- The Knock: something knocks at the front door (in the Parlor's south wall).
-- Every player must be hidden in a wardrobe or under a bed (see Hiding) when it opens.
-- Judged per player: when time runs out the door opens, he's standing there, and anyone not
-- hidden is eliminated.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local HollowManModel = require(Shared:WaitForChild("HollowManModel"))
local Types = require(Shared:WaitForChild("Types"))

local EventKit = require(script.Parent.EventKit)
local Hiding = require(script.Parent.Hiding)

type EventRun = Types.EventRun

local TheKnock = {}

function TheKnock.start(run: EventRun)
	local folder = EventKit.folder(run, "TheKnockEvent")
	local door = EventKit.part("FrontDoor", Vector3.new(1, 1, 1), EventKit.frontDoor() * CFrame.new(0, 4, 0), Color3.new(), folder)
	door.Transparency = 1
	door.CanCollide = false
	door.CanQuery = false
	run.data.door = door

	-- Knocks keep coming until the door opens.
	task.spawn(function()
		while not run.over do
			EventKit.sound("knock", door, 0.9)
			task.wait(EventKit.rng:NextNumber(Config.Events.KnockMinSeconds, Config.Events.KnockMaxSeconds))
		end
	end)

	Hiding.enable(run)
end

function TheKnock.onTimeout(run: EventRun): { Player }
	-- The door opens. He's standing in it.
	local folder = run.data.folder
	if folder then
		local figure = HollowManModel.build()
		figure:PivotTo(EventKit.frontDoor())
		figure.Parent = folder
		EventKit.sound("caught", run.data.door, 0.8)
	end
	local failed = {}
	for _, player in run.players do
		if run.isActive(player) and not Hiding.isHidden(run, player) then
			table.insert(failed, player)
		end
	end
	return failed
end

function TheKnock.cleanup(run: EventRun)
	Hiding.cleanup(run)
	-- Leave him standing in the doorway while the result shows.
	task.delay(Config.Events.ResultSeconds, EventKit.cleanup, run)
end

return TheKnock
