--!strict
-- Candlelight: light candles in 3 marked rooms before time runs out. Marked rooms are random
-- built rooms, never the Crawlspace (fewer than 3 if fewer exist). Each candle has a label that
-- shows through walls. Group task: if any candle is still unlit when time runs out, everyone
-- still in play is eliminated.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))

local EventItems = require(script.Parent.EventItems)
local EventKit = require(script.Parent.EventKit)

type EventRun = Types.EventRun

local UNLIT_TEXT = Color3.fromRGB(235, 225, 200)
local LIT_TEXT = Color3.fromRGB(255, 200, 110)

local Candlelight = {}

function Candlelight.start(run: EventRun)
	local folder = EventKit.folder(run, "CandlelightEvent")
	local rooms = EventKit.pick(EventKit.rooms({ crawlspace = true }), Config.Events.CandleRooms)
	local total = #rooms
	local lit = 0

	for _, cell in rooms do
		-- On clear floor, never under or inside furniture.
		local base = EventKit.clearSpot(cell, 1.2)
		local wax, light = EventItems.candle(folder, base, Config.Events.CandleHeight)
		local label = EventKit.marker(wax, "Candle · unlit", UNLIT_TEXT)

		local done = false
		local prompt = EventKit.prompt(wax, "Light", "Candle")
		prompt.Triggered:Connect(function(player: Player)
			if done or not run.isActive(player) then
				return
			end
			done = true
			prompt.Enabled = false
			light()
			label.Text = "Candle · lit"
			label.TextColor3 = LIT_TEXT
			lit += 1
			EventKit.notifyAll(run, `{player.DisplayName} lit a candle ({lit}/{total}).`)
			if lit >= total then
				run.complete()
			end
		end)
	end
end

function Candlelight.onTimeout(run: EventRun): { Player }
	return EventKit.everyoneActive(run)
end

function Candlelight.cleanup(run: EventRun)
	EventKit.cleanup(run)
end

return Candlelight
