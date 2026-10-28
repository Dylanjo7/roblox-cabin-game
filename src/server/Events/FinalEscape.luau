--!strict
-- The final escape at 3:00 AM (run through EventRunner like an event, but not a card in the deck).
-- Every built exit room's outside door unseals: its boards and chain fall away and it can be
-- opened. Only the true exit's door leads out; the rest are traps (whoever opens one is out).
-- The Hollow Man comes into the Parlor and hunts, as in He Walks. Whoever gets through the true
-- exit is safe outside by the truck; anyone still inside when time runs out is caught. It ends
-- early once nobody is left in play. Eliminations here don't move the Candle (the clock is done).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CardData = require(Shared:WaitForChild("CardData"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local MapGrid = require(script.Parent.Parent.MapGrid)
local Secrets = require(script.Parent.Parent.Secrets)
local EventKit = require(script.Parent.EventKit)
local HeWalks = require(script.Parent.HeWalks)

type EventRun = Types.EventRun

local FinalEscape = {
	noPenalty = true,
	keepPlayers = true,
}

local escapedNames: { string } = {}
local escapedPlayers: { Player } = {}

-- Where you end up when you get out: back on the path by the truck.
local function outside(): CFrame
	local spawn = workspace:FindFirstChild("ArrivalSpawn")
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame * CFrame.new(0, 3, 0)
	end
	return CFrame.new(0, 3, 80)
end

local function anyoneLeft(run: EventRun): boolean
	for _, player in run.players do
		if run.isActive(player) and player.Parent == Players then
			return true
		end
	end
	return false
end

local function escape(run: EventRun, player: Player, cell: MapGrid.Cell)
	run.safe[player] = true
	table.insert(escapedNames, player.DisplayName)
	table.insert(escapedPlayers, player)
	local character = player.Character
	if character then
		character:PivotTo(outside())
	end
	local name = CardData.get(cell.id).name
	Remotes.notify(player, `The {name} door gives way. Cold air. The road. You're out!`)
	for _, p in run.players do
		if p ~= player then
			Remotes.notify(p, `{player.DisplayName} got out through the {name}.`)
		end
	end
	if not anyoneLeft(run) then
		run.complete()
	end
end

local function trap(run: EventRun, player: Player, cell: MapGrid.Cell)
	local name = CardData.get(cell.id).name
	Remotes.notify(player, `The {name} door opens onto black pines... and something was waiting on the other side.`)
	run.eliminate(player)
	if not anyoneLeft(run) then
		run.complete()
	end
end

function FinalEscape.start(run: EventRun)
	table.clear(escapedNames)
	table.clear(escapedPlayers)
	local trueExit = Secrets.trueExit()
	local prompts: { ProximityPrompt } = {}
	run.data.prompts = prompts

	-- Unseal every built exit room's outside door.
	local count = 0
	for _, cell in MapGrid.all() do
		local door = cell.model and cell.model:FindFirstChild("ExitDoor")
		local panel = door and door:FindFirstChild("Panel")
		if door and panel and panel:IsA("BasePart") then
			count += 1
			local boards = door:FindFirstChild("Boards")
			if boards then
				for _, board in boards:GetChildren() do
					if board:IsA("BasePart") then
						board.Anchored = false
						board.CanCollide = false
					end
				end
				task.delay(2, function()
					boards:Destroy()
				end)
			end
			EventKit.sound("creak", panel, 0.8)
			local prompt = EventKit.prompt(panel, "Go through", `{CardData.get(cell.id).name} door`)
			prompt.Triggered:Connect(function(player: Player)
				if not run.isActive(player) then
					return
				end
				if trueExit and cell.id == trueExit.id then
					escape(run, player, cell)
				else
					trap(run, player, cell)
				end
			end)
			table.insert(prompts, prompt)
		end
	end

	if count == 0 then
		EventKit.notifyAll(run, "3:00 AM. Somewhere a lock turns... but no exit room was ever built.")
	else
		EventKit.notifyAll(run, `3:00 AM. {count} outside door{if count == 1 then "" else "s"} unsealed. Only one leads out. Choose.`)
	end

	-- He comes for you, starting in the Parlor.
	run.data.startCell = MapGrid.get(0, 0)
	HeWalks.start(run)
end

function FinalEscape.onTimeout(run: EventRun): { Player }
	EventKit.notifyAll(run, "Time's up. The doors swing shut, all of them at once.")
	local caught = {}
	for _, player in run.players do
		if run.isActive(player) then
			table.insert(caught, player)
		end
	end
	return caught
end

function FinalEscape.cleanup(run: EventRun)
	for _, prompt in (run.data.prompts or {}) :: { ProximityPrompt } do
		prompt:Destroy()
	end
	HeWalks.cleanup(run)
end

-- Display names of everyone who got out through the true exit in the last final escape.
function FinalEscape.escaped(): { string }
	return table.clone(escapedNames)
end

-- Everyone who got out in the last final escape.
function FinalEscape.escapedPlayers(): { Player }
	return table.clone(escapedPlayers)
end

return FinalEscape
