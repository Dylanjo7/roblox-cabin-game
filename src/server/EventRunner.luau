--!strict
-- Runs Event cards. An event starts the moment it's drawn: everyone is stood up from the table,
-- a timer runs, and the event's module decides who fails. A player who fails wakes up in the
-- basement under the Crawlspace (see Basement), locked in until the event ends, and every
-- elimination lets the Hollow Man gain on the Candle, up to Config.EliminationMaxStepsPerEvent
-- an event (the Candle itself only moves for cards). When the event ends, the survivors go back
-- to their seats and the basement door opens for the eliminated to walk back up (elimination
-- costs time, not your spot in the run).
-- Each event lives in its own module under Events/ and only sees the EventRun it's given.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CardData = require(Shared:WaitForChild("CardData"))
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local Basement = require(script.Parent.Basement)
local Clock = require(script.Parent.Clock)
local Difficulty = require(script.Parent.Difficulty)
local RunStats = require(script.Parent.RunStats)
local StateSync = require(script.Parent.StateSync)
local Table = require(script.Parent.Table)

type EventRun = Types.EventRun
type EventModule = Types.EventModule

local EVENTS: { [string]: EventModule } = {
	fuse_box = require(script.Parent.Events.FuseBox),
	candlelight = require(script.Parent.Events.Candlelight),
	rising_water = require(script.Parent.Events.RisingWater),
	the_knock = require(script.Parent.Events.TheKnock),
	lockdown = require(script.Parent.Events.Lockdown),
	he_walks = require(script.Parent.Events.HeWalks),
	final_escape = require(script.Parent.Events.FinalEscape),
	attic = require(script.Parent.Events.Attic),
	dont_look = require(script.Parent.Events.DontLook),
	hush = require(script.Parent.Events.Hush),
}

local EventRunner = {}

local current: EventRun? = nil

-- Run part of an event, and carry on if it fails (an event that errors halfway mustn't leave
-- everyone standing in the cabin forever).
local function safely(what: string, f: () -> ()): boolean
	local ok, err = pcall(f)
	if not ok then
		warn(`Hollow Pines: {what} failed: {err}`)
	end
	return ok
end

local function notifyAll(players: { Player }, text: string)
	for _, p in players do
		Remotes.notify(p, text)
	end
end

local function parts(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	return character, humanoid, if root and root:IsA("BasePart") then root else nil
end

local function standUp(player: Player)
	local _, humanoid = parts(player)
	if humanoid and humanoid.SeatPart then
		local weld = humanoid.SeatPart:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
		humanoid.Sit = false
	end
end

local function eliminate(run: EventRun, player: Player)
	if run.over or run.eliminated[player] then
		return
	end
	run.eliminated[player] = true
	RunStats.count(player, "caught")
	local character = parts(player)
	if character then
		-- Down to the basement under the Crawlspace; its door stays shut until the event ends.
		character:PivotTo(Basement.spawnCFrame())
	end
	Remotes.notify(player, "You're out. You wake up in the basement, and the door won't open until it's over up there.")
	for _, p in run.players do
		if p ~= player then
			Remotes.notify(p, `{player.DisplayName} was eliminated.`)
		end
	end
	if not EVENTS[run.id].noPenalty then
		-- He gains for each player caught, but only so much from one event.
		local gained = run.data.hollowGained or 0
		local steps = math.min(Config.EliminationHollowSteps, Config.EliminationMaxStepsPerEvent - gained)
		if steps > 0 and Clock.hollowGains(steps) then
			run.data.hollowGained = gained + steps
		end
	end
	StateSync.broadcast()
end

-- Everyone who made it goes back to their seat. The eliminated are left in the basement: its
-- door opens now and they have to climb out and walk back to the table (the next turn can't
-- start until everyone is seated).
local function returnToSeats(run: EventRun)
	for _, player in run.players do
		if run.eliminated[player] then
			Remotes.notify(player, "The basement door grinds open. Climb the stairs and get back to the table.")
			continue
		end
		Table.seatPlayer(player, run.seats[player])
	end
end

local function finish(run: EventRun, failures: { Player }, onFinished: () -> ())
	if run.over then
		return
	end
	for _, player in failures do
		eliminate(run, player)
	end
	run.over = true
	safely(`{run.id} cleanup`, function()
		EVENTS[run.id].cleanup(run)
	end)

	local count = 0
	for _ in run.eliminated do
		count += 1
	end
	local name = CardData.get(run.id).name
	if run.id ~= "final_escape" then
		RunStats.eventOver(name, count)
	end
	if EVENTS[run.id].noPenalty then
		notifyAll(run.players, `{name} is over.`)
	elseif count == 0 then
		notifyAll(run.players, `{name} is over. Everyone made it.`)
	else
		local gained = (run.data.hollowGained or 0) * Config.Clock.StepMinutes
		if gained > 0 then
			notifyAll(run.players, `{name} is over. {count} caught: the Hollow Man gains {gained} min on the Candle.`)
		else
			notifyAll(run.players, `{name} is over. {count} caught. He isn't on the clock yet, so it cost nothing... this time.`)
		end
	end
	StateSync.broadcast()

	task.delay(Config.Events.ResultSeconds, function()
		if current ~= run then
			return
		end
		if not EVENTS[run.id].keepPlayers then
			safely("returning players to the table", function()
				returnToSeats(run)
			end)
		end
		Basement.setLocked(false)
		current = nil
		StateSync.broadcast()
		onFinished()
	end)
end

function EventRunner.isImplemented(id: string): boolean
	return EVENTS[id] ~= nil
end

function EventRunner.isRunning(): boolean
	return current ~= nil
end

-- Start an Event card for everyone in the run. onFinished runs once everyone is back at the table.
function EventRunner.start(id: string, players: { Player }, onFinished: () -> ())
	local module = EVENTS[id]
	assert(module, `Event {id} isn't built yet`)
	local seconds = Difficulty.eventSeconds(id) + (module.leadSeconds or 0)

	local run: EventRun
	run = {
		id = id,
		players = table.clone(players),
		seats = {},
		eliminated = {},
		safe = {},
		endsAt = workspace:GetServerTimeNow() + seconds,
		over = false,
		data = {},
		complete = function()
			finish(run, {}, onFinished)
		end,
		eliminate = function(player: Player)
			eliminate(run, player)
		end,
		isActive = function(player: Player): boolean
			return not run.over and not run.eliminated[player] and not run.safe[player]
		end,
	}
	for _, player in run.players do
		run.seats[player] = Table.seatOf(player)
		standUp(player)
	end
	current = run
	Basement.setLocked(true)
	local started = safely(`{id} start`, function()
		module.start(run)
	end)
	StateSync.broadcast()
	if not started and not run.over then
		-- It couldn't set itself up: call it off, nobody fails, and play goes on.
		notifyAll(run.players, `{CardData.get(id).name} fizzles out. Nothing happens... this time.`)
		run.complete()
		return
	end

	task.delay(seconds, function()
		if current == run and not run.over then
			local failures: { Player } = {}
			safely(`{id} timeout`, function()
				failures = module.onTimeout(run)
			end)
			finish(run, failures, onFinished)
		end
	end)
end

-- Stop a running event without finishing it (the run was abandoned).
function EventRunner.abort()
	local run = current
	if not run then
		return
	end
	current = nil
	Basement.setLocked(false)
	if not run.over then
		run.over = true
		safely(`{run.id} cleanup`, function()
			EVENTS[run.id].cleanup(run)
		end)
	end
	for _, player in run.players do
		local _, _, root = parts(player)
		if root then
			root.Anchored = false
		end
	end
	StateSync.broadcast()
end

function EventRunner.init()
	StateSync.register("event", function(): Types.EventPublic?
		local run = current
		if not run then
			return nil
		end
		local def = CardData.get(run.id)
		local out = {}
		for player in run.eliminated do
			table.insert(out, player.UserId)
		end
		return {
			id = run.id,
			name = def.name,
			text = def.text,
			endsAt = run.endsAt,
			over = run.over,
			eliminated = out,
			detail = run.data.detail,
			alert = run.data.alert,
		}
	end)
end

return EventRunner
