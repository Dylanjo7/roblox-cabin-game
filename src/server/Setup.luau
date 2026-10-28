--!strict
-- Setup phase: secret true exit and clues, fresh cabin with the Parlor, empty Altar, shuffled
-- deck, Crawlspace on a Parlor door, then the deal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CardData = require(Shared:WaitForChild("CardData"))
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local Altar = require(script.Parent.Altar)
local ClueSigns = require(script.Parent.ClueSigns)
local Clock = require(script.Parent.Clock)
local Journal = require(script.Parent.Journal)
local Deck = require(script.Parent.Deck)
local GameState = require(script.Parent.GameState)
local Hands = require(script.Parent.Hands)
local MapGrid = require(script.Parent.MapGrid)
local Notes = require(script.Parent.Notes)
local RoomPlacement = require(script.Parent.RoomPlacement)
local Secrets = require(script.Parent.Secrets)
local StateSync = require(script.Parent.StateSync)
local Table = require(script.Parent.Table)
local TurnController = require(script.Parent.TurnController)

local Setup = {}

-- Clear the map back to just the Parlor at cell (0, 0).
function Setup.resetCabin()
	MapGrid.clear()
	RoomPlacement.place("parlor", 0, 0, 0)
	StateSync.broadcast()
end

-- Draw one card for the opening hand. Event cards dealt here go back into the deck at random
-- and a replacement is drawn (agreed default; RULES.md doesn't cover it).
local function dealOne(): Types.Card?
	for _ = 1, Deck.count() do
		local card = Deck.draw()
		if not card or CardData.get(card.id).type ~= "Event" then
			return card
		end
		Deck.insertRandom(card)
	end
	return nil
end

local function deal(players: { Player })
	for _, player in players do
		for _ = 1, Config.HandSize do
			local card = dealOne()
			if card then
				Hands.add(player, card)
			end
		end
	end
end

function Setup.run(players: { Player })
	GameState.clearResult()
	Table.clearPlayedCards()
	ClueSigns.reset()
	Journal.reset()
	Notes.reset()
	Altar.clear()
	Secrets.pick() -- the true exit and its three true clues (server only)
	Setup.resetCabin()
	Deck.build()
	Hands.clear()
	Clock.reset()
	TurnController.beginRun(players)

	-- The Crawlspace is set aside, not shuffled in, and is always the first card played.
	local first = players[1]
	TurnController.requirePlacement(first, Deck.newCard("crawlspace"), function()
		deal(TurnController.players()) -- not `players`: someone may have left during setup
		TurnController.startNextTurn()
		GameState.transition("TurnLoop")
	end)
	Remotes.notify(first, "Place the Crawlspace on one of the Parlor's doors.")
end

return Setup
