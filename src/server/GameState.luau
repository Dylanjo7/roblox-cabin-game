--!strict
-- The game state machine: Lobby -> Setup -> TurnLoop -> Event -> FinalEscape -> GameOver.
-- Any phase may drop back to Lobby (e.g. the last player left).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

type Phase = Types.Phase

local ALLOWED: { [string]: { [string]: boolean } } = {
	Lobby = { Setup = true },
	Setup = { TurnLoop = true, Lobby = true },
	TurnLoop = { Event = true, FinalEscape = true, GameOver = true, Lobby = true },
	Event = { TurnLoop = true, FinalEscape = true, GameOver = true, Lobby = true },
	FinalEscape = { GameOver = true, Lobby = true },
	GameOver = { Lobby = true },
}

local GameState = {}

local current: Phase = "Lobby"
local enterHandlers: { [string]: { (from: Phase) -> () } } = {}
local changed = Instance.new("BindableEvent")

-- Fires (to: Phase, from: Phase) after every transition.
GameState.Changed = changed.Event

function GameState.get(): Phase
	return current
end

local result: Types.ResultPublic? = nil

function GameState.getResult(): Types.ResultPublic?
	return result
end

function GameState.clearResult()
	result = nil
end

-- End the run (win or lose) and move to GameOver.
function GameState.endRun(won: boolean, reason: string, ending: string)
	result = { won = won, reason = reason, ending = ending }
	GameState.transition("GameOver")
end

function GameState.onEnter(phase: Phase, handler: (from: Phase) -> ())
	local list = enterHandlers[phase]
	if not list then
		list = {}
		enterHandlers[phase] = list
	end
	table.insert(list, handler)
end

function GameState.transition(to: Phase)
	local from = current
	assert(ALLOWED[from][to], `Illegal phase change {from} -> {to}`)
	current = to
	changed:Fire(to, from)
	-- One handler failing mustn't stop the others (the next run's countdown, say) from running.
	for _, handler in enterHandlers[to] or {} do
		local ok, err = pcall(handler, from)
		if not ok then
			warn(`Hollow Pines: entering {to} failed: {err}`)
		end
	end
end

return GameState
