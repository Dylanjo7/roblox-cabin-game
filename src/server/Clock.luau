--!strict
-- The clock track: the group's Candle and the Hollow Man, as step indexes (0 = 9:00 PM, 12 = 3:00 AM).
-- Only Progress cards, card penalties and (later) eliminations move the Candle; turns alone never do.
-- The Hollow Man moves once every Config.HollowMan.TurnsPerMove turns (4: once round the table
-- with 4 players; solo, every 4th of your turns). His first move puts him on the track at
-- 9:00 PM; after that he moves +30 min, or +60 min once he is at or past midnight. If he
-- reaches or passes the Candle the next turn is a last turn: it must move the Candle, or the
-- run is lost.

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
local candleStepsThisTurn = 0 -- for timing the table animation
local turnsSinceMove = 0
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
	candleStepsThisTurn = 0
	turnsSinceMove = 0
	deckOutUsed = false
	update()
end

function Clock.candle(): number
	return candle
end

-- Call when a new turn begins.
function Clock.startTurn()
	movedThisTurn = false
	candleStepsThisTurn = 0
end

function Clock.advanceCandle(steps: number)
	if steps <= 0 then
		return
	end
	local before = candle
	candle = math.min(candle + steps, Config.Clock.Steps)
	candleStepsThisTurn += candle - before
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

-- His move after every TurnsPerMove turns. Returns how many steps his piece walks on the table
-- (coming onto the track counts as one).
local function moveOnSchedule(): number
	local current = hollow
	if current == nil then
		hollow = Config.HollowMan.EntryStep
		return Config.HollowMan.EntryStep + 1
	end
	local steps = if current >= Config.Clock.MidnightStep then Config.HollowMan.StepsPerRoundFromMidnight else Config.HollowMan.StepsPerRound
	local after = math.min(current + steps, Config.Clock.Steps)
	hollow = after
	return after - current
end

-- How long the table needs to show this turn's moves (the Candle's hops, then his steps).
local function animationSeconds(hollowSteps: number): number
	if hollowSteps == 0 then
		return 0
	end
	return candleStepsThisTurn * Config.Table.CandleStepSeconds + hollowSteps * Config.Table.HollowStepSeconds + 0.6
end

-- Run once at the end of every turn, before the next one starts. Also returns how many seconds
-- to wait before the next turn so everyone sees the pieces move.
function Clock.resolveTurnEnd(): (TurnEndStatus, number)
	if candle >= Config.Clock.Steps then
		GameState.transition("FinalEscape")
		return "Over", 0
	end
	if lastTurn and not movedThisTurn then
		GameState.endRun(false, "The Hollow Man caught the Candle and it didn't move on the last turn.", "caught")
		return "Over", 0
	end
	local hollowSteps = 0
	turnsSinceMove += 1
	if turnsSinceMove >= Config.HollowMan.TurnsPerMove then
		turnsSinceMove = 0
		hollowSteps = moveOnSchedule()
	end
	local caughtAt = hollow
	lastTurn = caughtAt ~= nil and caughtAt >= candle
	update()
	return if lastTurn then "LastTurn" else "Continue", animationSeconds(hollowSteps)
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
