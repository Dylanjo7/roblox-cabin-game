--!strict
-- Hush: a gramophone starts playing by itself somewhere in the cabin, and something in the
-- walls is listening. While the record plays you can move. When the needle lifts, freeze: after
-- a moment to react, anyone who moves before it plays again is caught (turning to look round is
-- fine; walking or jumping isn't). Follow the music to the gramophone and lift the needle for
-- good to end it. After a while everyone's told which room it's in. Group task: if it's still
-- playing when time runs out, everyone still in play is caught.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CardData = require(Shared:WaitForChild("CardData"))
local Config = require(Shared:WaitForChild("Config"))
local RoomShapes = require(Shared:WaitForChild("RoomShapes"))
local Types = require(Shared:WaitForChild("Types"))

local EventItems = require(script.Parent.EventItems)
local EventKit = require(script.Parent.EventKit)

type EventRun = Types.EventRun

local PLAYING = "The record is playing. Move."
local QUIET = "HUSH. DON'T MOVE."
local FOUND_TEXT = Color3.fromRGB(235, 200, 140)

local Hush = {}

function Hush.start(run: EventRun)
	local cfg = Config.Events.Hush
	local rng = EventKit.rng
	local folder = EventKit.folder(run, "HushEvent")

	-- The gramophone: in a room away from the table where there is one.
	local rooms = EventKit.rooms({ crawlspace = true, parlor = true })
	if #rooms == 0 then
		rooms = EventKit.rooms({ crawlspace = true })
	end
	local cell = rooms[rng:NextInteger(1, #rooms)]
	local base = EventKit.clearSpot(cell, 1.7)
	local toward = (RoomShapes.cellPosition(cell.x, cell.z) - base) * Vector3.new(1, 0, 1)
	local case, mouth, setNeedle = EventItems.gramophone(folder, base, if toward.Magnitude > 1 then toward.Unit else Vector3.zAxis)

	-- The record: the lullaby, slowed and thinned out like an old 78, coming from the horn.
	local music = Instance.new("Sound")
	music.Name = "Record"
	music.SoundId = Config.Sounds.lullaby
	music.Looped = true
	music.Volume = cfg.Volume
	music.PlaybackSpeed = cfg.PlaybackSpeed
	music.RollOffMinDistance = 10
	music.RollOffMaxDistance = cfg.HearDistance
	local eq = Instance.new("EqualizerSoundEffect")
	eq.LowGain = -8
	eq.MidGain = 3
	eq.HighGain = -10
	eq.Parent = music
	local crackle = Instance.new("DistortionSoundEffect")
	crackle.Level = 0.22
	crackle.Parent = music
	music.Parent = mouth

	local stopped = false
	local prompt = EventKit.prompt(case, "Lift the needle", "Gramophone")
	prompt.HoldDuration = cfg.StopSeconds
	prompt.Triggered:Connect(function(player: Player)
		if stopped or not run.isActive(player) then
			return
		end
		stopped = true
		prompt.Enabled = false
		setNeedle(false)
		music:Stop()
		run.data.detail = "The record stops. Just silence now."
		run.data.alert = false
		EventKit.notifyAll(run, `{player.DisplayName} lifted the needle. The house lets its breath out.`)
		run.complete()
	end)
	EventKit.notifyAll(run, "Music, somewhere in the cabin. When it stops, don't move.")

	task.spawn(function()
		local started = os.clock()
		local hinted = false
		local first = true
		while not run.over and not stopped do
			-- The needle goes down and the record plays: move.
			setNeedle(true)
			if music.IsPaused then
				music:Resume()
			else
				music:Play()
			end
			EventKit.setDetail(run, PLAYING, false)
			local playFor = if first then cfg.FirstPlaySeconds else rng:NextNumber(cfg.PlayMinSeconds, cfg.PlayMaxSeconds)
			first = false
			local playUntil = os.clock() + playFor
			while os.clock() < playUntil and not run.over and not stopped do
				task.wait(0.1)
				if not hinted and os.clock() - started > cfg.HintSeconds then
					hinted = true
					EventKit.marker(case, "Gramophone", FOUND_TEXT)
					EventKit.notifyAll(run, `The music is coming from the {CardData.get(cell.id).name}.`)
				end
			end
			if run.over or stopped then
				break
			end

			-- The needle lifts. A moment to stop, then whoever's still where they stopped is safe.
			setNeedle(false)
			music:Pause()
			EventKit.sound("creak", case, 0.5)
			EventKit.setDetail(run, QUIET, true)
			task.wait(cfg.ReactSeconds)
			if run.over or stopped then
				break
			end
			local still: { [Player]: Vector3 } = {}
			local listening: { Player } = {}
			for _, player in run.players do
				local root = EventKit.root(player)
				if root and run.isActive(player) then
					still[player] = root.Position
					table.insert(listening, player)
				end
			end
			-- Something breathes close by one of you.
			if #listening > 0 then
				local near = EventKit.root(listening[rng:NextInteger(1, #listening)])
				if near then
					EventKit.sound("whisper", near, 0.35)
				end
			end
			local quietUntil = os.clock() + rng:NextNumber(cfg.QuietMinSeconds, cfg.QuietMaxSeconds)
			while os.clock() < quietUntil and not run.over and not stopped do
				task.wait(0.1)
				for player, at in still do
					local root = EventKit.root(player)
					if not root or not run.isActive(player) then
						still[player] = nil
						continue
					end
					local moved = root.Position - at
					if Vector3.new(moved.X, 0, moved.Z).Magnitude > cfg.MoveTolerance or math.abs(moved.Y) > cfg.JumpTolerance then
						still[player] = nil
						EventKit.sound("caught", case, 0.7)
						run.eliminate(player)
					end
				end
			end
		end
	end)
end

function Hush.onTimeout(run: EventRun): { Player }
	run.data.detail = "The record runs out."
	run.data.alert = false
	EventKit.notifyAll(run, "The record runs out. In the silence, it finds you.")
	return EventKit.everyoneActive(run)
end

function Hush.cleanup(run: EventRun)
	EventKit.cleanup(run)
end

return Hush
