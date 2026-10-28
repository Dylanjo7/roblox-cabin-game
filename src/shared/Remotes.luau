--!strict
-- Creates (server) or fetches (client) every remote by name. Clients only ever send intents;
-- the server validates each one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local EVENTS = {
	"RequestStartTurn", -- client -> server: T pressed while seated
	"SubmitPeekOrder", -- client -> server: new order for the peeked cards
	"RequestToggleExit", -- client -> server: cross an exit out of the Journal (or back in)
	"RequestMarkClue", -- client -> server: cycle a clue result's mark in the Journal (found / ruled out / none)
	"PublicState", -- server -> all: public game state snapshot
	"PrivateHand", -- server -> one player: that player's own hand
	"PeekCards", -- server -> one player: top cards for Peek
	"PlacementOptions", -- server -> one player: legal spots for the room they must place (nil clears)
	"Notify", -- server -> one player: short message
	"SwapOptions", -- server -> one player: who they can trade hands with (nil closes the panel)
	"SubmitSwapTarget", -- client -> server: the UserId picked to swap with
	"SetLanternColour", -- client -> server: pick a lantern flame (Lantern Colours pass, or the free one)
	"RequestScare", -- client -> server: buy a scare for this UserId (prompts the purchase)
	"Scare", -- server -> one player: a bought scare ("face", from whom)
	"ShowNote", -- server -> one player: the note they just picked up (its index in Story.Notes)
}

local FUNCTIONS = {
	"RequestDraw",
	"RequestTakeClue", -- take a Clue off the Altar instead of drawing
	"RequestSelectCard",
	"RequestPlaceRoom",
	"RequestPlayProgress",
	"GetPublicState",
}

local Remotes = {}

local function folder(): Instance
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		assert(existing, "Remotes.init() must run before remotes are used")
		return existing
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

-- Server only: create every remote once at boot.
function Remotes.init()
	assert(RunService:IsServer(), "Remotes.init is server only")
	local f = Instance.new("Folder")
	f.Name = FOLDER_NAME
	for _, name in EVENTS do
		local e = Instance.new("RemoteEvent")
		e.Name = name
		e.Parent = f
	end
	for _, name in FUNCTIONS do
		local fn = Instance.new("RemoteFunction")
		fn.Name = name
		fn.Parent = f
	end
	f.Parent = ReplicatedStorage
end

function Remotes.event(name: string): RemoteEvent
	return folder():WaitForChild(name) :: RemoteEvent
end

function Remotes.func(name: string): RemoteFunction
	return folder():WaitForChild(name) :: RemoteFunction
end

-- Server only: show a short message to one player.
function Remotes.notify(player: Player, text: string)
	Remotes.event("Notify"):FireClient(player, text)
end

return Remotes
