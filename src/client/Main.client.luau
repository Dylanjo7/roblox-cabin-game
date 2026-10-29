--!strict
-- Client boot: HUD, hand, board, Peek, events, Altar, Journal, story and dread, the Hollow Man,
-- the table's clock pieces, the ticking clocks, rooms rising into place, the storm, the
-- end-of-night summary, input, and listening for server state and messages. (The time is only
-- shown on the table and the clocks, never on screen.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local AltarUI = require(script.Parent.AltarUI)
local Atmosphere = require(script.Parent.Atmosphere)
local BoardUI = require(script.Parent.BoardUI)
local Clocks = require(script.Parent.Clocks)
local Cursor = require(script.Parent.Cursor)
local Cutscene = require(script.Parent.Cutscene)
local EventFx = require(script.Parent.EventFx)
local EventUI = require(script.Parent.EventUI)
local HandUI = require(script.Parent.HandUI)
local Haunting = require(script.Parent.Haunting)
local HollowManView = require(script.Parent.HollowManView)
local Hud = require(script.Parent.Hud)
local Input = require(script.Parent.Input)
local JournalUI = require(script.Parent.JournalUI)
local NoteUI = require(script.Parent.NoteUI)
local PeekUI = require(script.Parent.PeekUI)
local SwapUI = require(script.Parent.SwapUI)
local RoomRise = require(script.Parent.RoomRise)
local Scenes = require(script.Parent.Scenes)
local Scares = require(script.Parent.Scares)
local Spinners = require(script.Parent.Spinners)
local Storm = require(script.Parent.Storm)
local SummaryUI = require(script.Parent.SummaryUI)
local TablePieces = require(script.Parent.TablePieces)
local TouchControls = require(script.Parent.TouchControls)
local Trip = require(script.Parent.Trip)

local gui = Hud.init()
HandUI.init(gui)
BoardUI.init(gui)
PeekUI.init(gui)
SwapUI.init(gui)
EventUI.init(gui)
EventFx.init(gui)
AltarUI.init(gui)
JournalUI.init(gui)
NoteUI.init(gui)
Cutscene.init(gui)
SummaryUI.init()
HollowManView.init()
TablePieces.init()
Clocks.init()
RoomRise.init()
Scares.init(gui)
Spinners.init()
Haunting.init()
Storm.init()
TouchControls.init(gui)
Atmosphere.init()
Cursor.init(gui, function(): boolean
	return JournalUI.isOpen() or NoteUI.isOpen() or PeekUI.isOpen() or SwapUI.isOpen() or AltarUI.isOpen() or BoardUI.isViewing() or Cutscene.isShowing() or SummaryUI.isOpen()
end)

Input.bind(Enum.KeyCode.T, function()
	Remotes.event("RequestStartTurn"):FireServer()
end)
Input.bind(Enum.KeyCode.R, BoardUI.rotate)
Input.bind(Enum.KeyCode.B, BoardUI.toggle)
Input.bind(Enum.KeyCode.M, JournalUI.toggle)
Input.init()

local lastPhase: string? = nil
local doorWasClosed: boolean? = nil -- nil until the first state arrives

-- No resetting your character during an event (it would carry you out of the basement or a
-- locked room, or take the fuse with you). The rest of the time it's how to get unstuck.
local resetAllowed: boolean? = nil
local resetToken = 0
local function allowReset(allow: boolean)
	if resetAllowed == allow then
		return
	end
	resetAllowed = allow
	resetToken += 1
	local token = resetToken
	task.spawn(function()
		-- SetCore isn't ready the moment the game loads; keep trying for a little while.
		for _ = 1, 20 do
			if token ~= resetToken or pcall(StarterGui.SetCore, StarterGui, "ResetButtonCallback", allow) then
				return
			end
			task.wait(0.5)
		end
	end)
end

local function setState(state)
	allowReset(state.phase ~= "Event" and state.phase ~= "FinalEscape")
	Hud.setState(state)
	Clocks.setState(state)
	Scares.setState(state)
	TouchControls.setState(state)
	EventUI.setState(state)
	EventFx.setState(state)
	HandUI.setState(state)
	if state.cabin then
		BoardUI.setCabin(state.cabin)
	end
	AltarUI.setState(state)
	JournalUI.setState(state)
	Atmosphere.setState(state)
	SummaryUI.setState(state)
	Storm.setState(state)

	-- Story: arriving by the truck, the intro when the front door slams behind you, and the
	-- ending when a run is over.
	local doorClosed = state.arrival ~= nil and state.arrival.doorClosed
	if doorWasClosed == nil and not doorClosed then
		-- The drive up first, then you're standing by the dead truck.
		task.spawn(function()
			Trip.play()
			Cutscene.playArrival(true)
		end)
	elseif doorWasClosed == false and doorClosed then
		-- The intro cutscene (the plain text version if it can't play).
		task.spawn(function()
			if not Scenes.intro() then
				Cutscene.playIntro()
			end
		end)
	end
	doorWasClosed = doorClosed
	if state.phase ~= lastPhase then
		if state.phase == "GameOver" and state.result then
			local ending = state.result.ending
			task.spawn(function()
				if not Scenes.ending(ending) then
					Cutscene.playEnding(ending)
				end
				SummaryUI.showAfterEnding() -- then the night in numbers
			end)
		end
		lastPhase = state.phase
	end
end

Remotes.event("PublicState").OnClientEvent:Connect(setState)
Remotes.event("PrivateHand").OnClientEvent:Connect(HandUI.setHand)
Remotes.event("PlacementOptions").OnClientEvent:Connect(BoardUI.setOptions)
Remotes.event("PeekCards").OnClientEvent:Connect(PeekUI.show)
Remotes.event("SwapOptions").OnClientEvent:Connect(SwapUI.show)
Remotes.event("Notify").OnClientEvent:Connect(Hud.toast)
setState(Remotes.func("GetPublicState"):InvokeServer())
