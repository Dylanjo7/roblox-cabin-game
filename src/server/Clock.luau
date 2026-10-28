--!strict
-- The clock track: the group's Candle and the Hollow Man, as step indexes (0 = 9:00 PM, 12 = 3:00 AM).
-- Only Progress cards, card penalties and (later) eliminations move the Candle; turns alone never do.
-- The Hollow Man enters at 9:00 PM after the first full round, then moves +30 min per round,
-- or +60 min per round once he is at or past midnight. If he reaches or passes the Candle the
-- next turn is a last turn: it must move the Candle, or the run is lost.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Deck = require(script.Parent.Deck)
local GameState = require(script.Parent.GameState)
local StateSync = require(script.Parent.StateSync)
local Table = require(script.Parent.Table)

export type TurnEndStatus = "Continue" | "LastTurn" | "Over"

local Clock = {}

local candle = 0
local hollow: number? = nil -- nil while he is off the track
local lastTurn = false -- the turn now being played is a last turn
local movedThisTurn = false
local deckOutUsed = false

local function update()
	Table.setClock(candle, hollow)
	StateSync.broadcast()
end

function Clock.reset()
	candle = 0
	hollow = nil
	lastTurn = false
	movedThisTurn = false
	deckOutUsed = false
	update()
end

function Clock.candle(): number
	return candle
end

-- Call when a new turn begins.
function Clock.startTurn()
	movedThisTurn = false
end

function Clock.advanceCandle(steps: number)
	if steps <= 0 then
		return
	end
	candle = math.min(candle + steps, Config.Clock.Steps)
	movedThisTurn = true
	update()
end

local function moveHollowMan(steps: number)
	local current = hollow
	if current == nil then
		return
	end
	hollow = math.clamp(current + steps, Config.HollowMan.MinStep, Config.Clock.Steps)
	update()
end

-- Hold the Line. Returns false when he isn't on the track yet (nothing to push).
function Clock.pushHollowMan(steps: number): boolean
	if hollow == nil then
		return false
	end
	moveHollowMan(-steps)
	return true
end

local function onRoundEnded()
	local current = hollow
	if current == nil then
		hollow = Config.HollowMan.EntryStep
	elseif current >= Config.Clock.MidnightStep then
		hollow = math.min(current + Config.HollowMan.StepsPerRoundFromMidnight, Config.Clock.Steps)
	else
		hollow = math.min(current + Config.HollowMan.StepsPerRound, Config.Clock.Steps)
	end
end

-- Run once at the end of every turn, before the next one starts.
function Clock.resolveTurnEnd(roundFinished: boolean): TurnEndStatus
	if candle >= Config.Clock.Steps then
		GameState.transition("FinalEscape")
		return "Over"
	end
	if lastTurn and not movedThisTurn then
		GameState.endRun(false, "The Hollow Man caught the Candle and it didn't move on the last turn.", "caught")
		return "Over"
	end
	if roundFinished then
		onRoundEnded()
	end
	local caughtAt = hollow
	lastTurn = caughtAt ~= nil and caughtAt >= candle
	update()
	return if lastTurn then "LastTurn" else "Continue"
end

function Clock.init()
	-- If the deck runs out, the Hollow Man moves an extra 60 minutes, once.
	Deck.Emptied:Connect(function()
		if not deckOutUsed then
			deckOutUsed = true
			moveHollowMan(Config.HollowMan.DeckOutExtraSteps)
		end
	end)

	StateSync.register("clock", function()
		return { candle = candle, hollow = hollow, lastTurn = lastTurn }
	end)
end

return Clock
