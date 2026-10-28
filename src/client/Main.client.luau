--!strict
-- Client boot: HUD, clock track, hand, board, Peek, events, Altar, Journal, story and dread, input, and listening
-- for server state and messages.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local AltarUI = require(script.Parent.AltarUI)
local Atmosphere = require(script.Parent.Atmosphere)
local BoardUI = require(script.Parent.BoardUI)
local ClockUI = require(script.Parent.ClockUI)
local Cursor = require(script.Parent.Cursor)
local Cutscene = require(script.Parent.Cutscene)
local EventUI = require(script.Parent.EventUI)
local HandUI = require(script.Parent.HandUI)
local Hud = require(script.Parent.Hud)
local Input = require(script.Parent.Input)
local JournalUI = require(script.Parent.JournalUI)
local PeekUI = require(script.Parent.PeekUI)
local SwapUI = require(script.Parent.SwapUI)
local Reflections = require(script.Parent.Reflections)

local gui = Hud.init()
ClockUI.init(gui)
HandUI.init(gui)
BoardUI.init(gui)
PeekUI.init(gui)
SwapUI.init(gui)
EventUI.init(gui)
AltarUI.init(gui)
JournalUI.init(gui)
Cutscene.init(gui)
Atmosphere.init()
Reflections.init()
Cursor.init(gui, function(): boolean
	return JournalUI.isOpen() or PeekUI.isOpen() or SwapUI.isOpen() or AltarUI.isOpen() or BoardUI.isViewing() or Cutscene.isShowing()
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

local function setState(state)
	Hud.setState(state)
	ClockUI.setState(state)
	EventUI.setState(state)
	HandUI.setState(state)
	if state.cabin then
		BoardUI.setCabin(state.cabin)
	end
	AltarUI.setState(state)
	JournalUI.setState(state)
	Atmosphere.setState(state)

	-- Story: arriving by the truck, the intro when the front door slams behind you, and the
	-- ending when a run is over.
	local doorClosed = state.arrival ~= nil and state.arrival.doorClosed
	if doorWasClosed == nil and not doorClosed then
		Cutscene.playArrival()
	elseif doorWasClosed == false and doorClosed then
		Cutscene.playIntro()
	end
	doorWasClosed = doorClosed
	if state.phase ~= lastPhase then
		if state.phase == "GameOver" and state.result then
			Cutscene.playEnding(state.result.ending)
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
