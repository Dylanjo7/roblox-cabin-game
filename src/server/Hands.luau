--!strict
-- Every player's hand. Server only: each player is sent their own hand and nobody else's.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

type Card = Types.Card

local Hands = {}

local hands: { [Player]: { Card } } = {}
local rng = Random.new()

local function send(player: Player)
	Remotes.event("PrivateHand"):FireClient(player, hands[player] or {})
end

function Hands.clear()
	for player in hands do
		hands[player] = nil
		send(player)
	end
end

function Hands.get(player: Player): { Card }
	return hands[player] or {}
end

function Hands.add(player: Player, card: Card)
	local hand = hands[player]
	if not hand then
		hand = {}
		hands[player] = hand
	end
	table.insert(hand, card)
	send(player)
end

-- Remove and return the card with this uid, or nil if the player doesn't hold it.
function Hands.take(player: Player, uid: number): Card?
	local hand = hands[player]
	if not hand then
		return nil
	end
	for i, card in hand do
		if card.uid == uid then
			table.remove(hand, i)
			send(player)
			return card
		end
	end
	return nil
end

-- Remove and return a random card, or nil if the hand is empty.
function Hands.takeRandom(player: Player): Card?
	local hand = hands[player]
	if not hand or #hand == 0 then
		return nil
	end
	local card = table.remove(hand, rng:NextInteger(1, #hand))
	send(player)
	return card
end

-- Trade two players' whole hands.
function Hands.swap(a: Player, b: Player)
	hands[a], hands[b] = hands[b], hands[a]
	send(a)
	send(b)
end

function Hands.remove(player: Player)
	hands[player] = nil
end

return Hands
