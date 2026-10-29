--!strict
-- The clock track: the group's Candle and the Hollow Man, as step indexes (0 = 9:00 PM, 12 = 3:00 AM).
-- Only cards move the Candle (Progress cards, and the penalty for a room with nowhere to go):
-- never a turn, a round or an event. Players caught in an event let the Hollow Man gain on it.
-- The Hollow Man moves once every turnsPerMove turns (Config.Difficulty; on Normal 4: once round
-- the table with 4 players; solo, every 4th of your turns). His first move puts him on the track at
-- 9:00 PM; after that he moves +30 min, or +60 min once he is at or past midnight. If he
-- reaches or passes the Candle the next turn is a last turn: it must move the Candle, or the
-- run is lost.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Deck = require(script.Parent.Deck)
local Difficulty = require(script.Parent.Difficulty)
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
-- The cutscene clients play at the end of a turn ("enters" / "midnight" for his scheduled move,
-- "last_turn" when he catches the Candle); the id changes each time there's a new one.
local sceneId = 0
local sceneKind: string? = nil

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
	sceneKind = nil
	update()
end

function Clock.candle(): number
	return candle
end

-- The turn being played is a last turn (he has caught the Candle): it must move or the run is lost.
function Clock.isLastTurn(): boolean
	return lastTurn
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

-- Someone was caught in an event: he gains this many steps on the Candle. Returns false when
-- he isn't on the track yet (then it costs nothing).
function Clock.hollowGains(steps: number): boolean
	if hollow == nil or steps <= 0 then
		return false
	end
	moveHollowMan(steps)
	return true
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
-- (coming onto the track counts as one), and the seconds of cutscene that go with it.
local function moveOnSchedule(): (number, number)
	local current = hollow
	if current == nil then
		hollow = Config.HollowMan.EntryStep
		sceneId += 1
		sceneKind = "enters"
		return Config.HollowMan.EntryStep + 1, Config.Cinematics.EnterSeconds
	end
	local steps = if current >= Config.Clock.MidnightStep then Config.HollowMan.StepsPerRoundFromMidnight else Config.HollowMan.StepsPerRound
	local after = math.min(current + steps, Config.Clock.Steps)
	hollow = after
	if current < Config.Clock.MidnightStep and after >= Config.Clock.MidnightStep then
		sceneId += 1
		sceneKind = "midnight"
		return after - current, Config.Cinematics.MidnightSeconds
	end
	return after - current, 0
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
	local hollowSteps, sceneSeconds = 0, 0
	turnsSinceMove += 1
	if turnsSinceMove >= Difficulty.get().turnsPerMove then
		turnsSinceMove = 0
		hollowSteps, sceneSeconds = moveOnSchedule()
	end
	local wasLastTurn = lastTurn
	local caughtAt = hollow
	lastTurn = caughtAt ~= nil and caughtAt >= candle
	if lastTurn and not wasLastTurn then
		-- He's caught the Candle: him at the front door (instead of any other scene this turn).
		sceneId += 1
		sceneKind = "last_turn"
		sceneSeconds = Config.Cinematics.LastTurnSeconds
	end
	update()
	return if lastTurn then "LastTurn" else "Continue", animationSeconds(hollowSteps) + sceneSeconds
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
		return { candle = candle, hollow = hollow, lastTurn = lastTurn, sceneId = sceneId, scene = sceneKind }
	end)
end

return Clock
