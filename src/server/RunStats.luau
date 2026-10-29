--!strict
-- What happened in a run, for the summary everyone sees once the ending has played: how long the
-- night lasted, what was built and found, how each event went, and each player's share (cards
-- played, rooms placed, signs written in the Journal, times caught, and who got out). Started
-- when a run is set up and frozen when it ends (see Main's GameOver); it's public from then on.
-- Nothing in it is secret until the run is over (the true exit is only named in the summary).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local RunStats = {}

export type Count = "cards" | "rooms" | "clues" | "caught"
type Tally = { name: string, counts: { [string]: number }, escaped: number? }

local started = os.clock()
local order: { Player } = {}
local tallies: { [Player]: Tally } = {}
local events: { { name: string, caught: number } } = {}
local signs = 0 -- everything written in the Journal, whoever wrote it
local escapes = 0
local summary: Types.SummaryPublic? = nil

-- A new run: these players, from now.
function RunStats.begin(players: { Player })
	started = os.clock()
	order = table.clone(players)
	tallies = {}
	for _, player in order do
		tallies[player] = { name = player.DisplayName, counts = { cards = 0, rooms = 0, clues = 0, caught = 0 } }
	end
	events = {}
	signs = 0
	escapes = 0
	summary = nil
end

function RunStats.count(player: Player, what: Count)
	if summary then
		return
	end
	if what == "clues" then
		signs += 1
	end
	local tally = tallies[player]
	if tally then
		tally.counts[what] += 1
	end
end

-- Got out through the true exit (numbered in the order they did).
function RunStats.escaped(player: Player)
	local tally = tallies[player]
	if tally and not tally.escaped and not summary then
		escapes += 1
		tally.escaped = escapes
	end
end

-- An event card is over, with this many caught.
function RunStats.eventOver(name: string, caught: number)
	if not summary then
		table.insert(events, { name = name, caught = caught })
	end
end

-- The run is over: freeze it. (The rest comes from Main, which can see the board and the clock.)
function RunStats.finish(info: { rounds: number, rooms: number, notes: number, candle: string, trueExit: string?, nextAt: number, toStation: boolean })
	local players: { Types.SummaryPlayer } = {}
	for _, player in order do
		local tally = tallies[player]
		local counts = tally.counts
		table.insert(players, {
			name = tally.name,
			cards = counts.cards,
			rooms = counts.rooms,
			clues = counts.clues,
			caught = counts.caught,
			escaped = tally.escaped,
			left = player.Parent == nil,
		})
	end
	summary = {
		minutes = math.max(1, math.floor((os.clock() - started) / 60 + 0.5)),
		rounds = info.rounds,
		rooms = info.rooms,
		clues = signs,
		notes = info.notes,
		candle = info.candle,
		trueExit = info.trueExit,
		events = table.clone(events),
		players = players,
		nextAt = info.nextAt,
		toStation = info.toStation,
	}
end

function RunStats.clear()
	summary = nil
end

function RunStats.public(): Types.SummaryPublic?
	return summary
end

return RunStats
