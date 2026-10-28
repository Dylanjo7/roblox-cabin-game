--!strict
-- The draw deck. Server only: its order is never sent to clients (only its size).
-- The last element of `cards` is the top of the deck.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CardData = require(Shared:WaitForChild("CardData"))
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))

type Card = Types.Card

local Deck = {}

local cards: { Card } = {}
local nextUid = 0
local rng = Random.new()
local emptied = Instance.new("BindableEvent")

-- Fires when the last card is drawn.
Deck.Emptied = emptied.Event

function Deck.newCard(id: string): Card
	nextUid += 1
	return { uid = nextUid, id = id }
end

function Deck.build()
	cards = {}
	for _, def in CardData.all() do
		if def.inDeck and Config.DeckTypes[def.type] then
			for _ = 1, Config.CardCopies[def.id] or 0 do
				table.insert(cards, Deck.newCard(def.id))
			end
		end
	end
	Deck.shuffle()
end

function Deck.shuffle()
	for i = #cards, 2, -1 do
		local j = rng:NextInteger(1, i)
		cards[i], cards[j] = cards[j], cards[i]
	end
end

function Deck.draw(): Card?
	local card = table.remove(cards)
	if card and #cards == 0 then
		emptied:Fire()
	end
	return card
end

-- The next n cards, top first.
function Deck.peekTop(n: number): { Card }
	local top = {}
	for i = #cards, math.max(1, #cards - n + 1), -1 do
		table.insert(top, cards[i])
	end
	return top
end

-- Put the top cards back in a new order (uids top first). Must be exactly the current top cards.
function Deck.reorderTop(uids: { number }): boolean
	local top = Deck.peekTop(#uids)
	if #top ~= #uids then
		return false
	end
	local byUid: { [number]: Card } = {}
	for _, card in top do
		byUid[card.uid] = card
	end
	local ordered = {}
	for _, uid in uids do
		local card = byUid[uid]
		if not card then
			return false
		end
		byUid[uid] = nil
		table.insert(ordered, card)
	end
	for i, card in ordered do
		cards[#cards - i + 1] = card
	end
	return true
end

-- Put a card back into the deck at a random position.
function Deck.insertRandom(card: Card)
	table.insert(cards, rng:NextInteger(1, #cards + 1), card)
end

function Deck.count(): number
	return #cards
end

return Deck
