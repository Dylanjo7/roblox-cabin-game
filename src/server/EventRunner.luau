--!strict
-- Runs Event cards. An event starts the moment it's drawn: everyone is stood up from the table,
-- a timer runs, and the event's module decides who fails. A player who fails wakes up in the
-- basement under the Crawlspace (see Basement), locked in until the event ends, and every
-- elimination moves the Candle +60 min. When the event ends, the survivors go back to their
-- seats and the basement door opens for the eliminated to walk back up (elimination costs
-- time, not your spot in the run).
-- Each event lives in its own module under Events/ and only sees the EventRun it's given.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CardData = require(Shared:WaitForChild("CardData"))
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local Basement = require(script.Parent.Basement)
local Clock = require(script.Parent.Clock)
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
}

local EventRunner = {}

local current: EventRun? = nil

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
		Clock.advanceCandle(Config.EliminationPenaltySteps)
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
		local character, humanoid, root = parts(player)
		if character and humanoid and root then
			root.Anchored = false
			local index = run.seats[player] or Table.freeSeat()
			if index then
				local seat = Table.seatPart(index)
				seat.Disabled = false
				character:PivotTo(seat.CFrame * CFrame.new(0, 3, 0))
				seat:Sit(humanoid)
			end
		end
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
	EVENTS[run.id].cleanup(run)

	local count = 0
	for _ in run.eliminated do
		count += 1
	end
	local name = CardData.get(run.id).name
	if EVENTS[run.id].noPenalty then
		notifyAll(run.players, `{name} is over.`)
	elseif count == 0 then
		notifyAll(run.players, `{name} is over. Everyone made it.`)
	else
		notifyAll(run.players, `{name} is over. {count} eliminated: the Candle moved +{count * Config.EliminationPenaltySteps * Config.Clock.StepMinutes} min.`)
	end
	StateSync.broadcast()

	task.delay(Config.Events.ResultSeconds, function()
		if current ~= run then
			return
		end
		if not EVENTS[run.id].keepPlayers then
			returnToSeats(run)
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
	local seconds = Config.EventSeconds[id]

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
	module.start(run)
	StateSync.broadcast()

	task.delay(seconds, function()
		if current == run and not run.over then
			finish(run, module.onTimeout(run), onFinished)
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
		EVENTS[run.id].cleanup(run)
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
		}
	end)
end

return EventRunner
