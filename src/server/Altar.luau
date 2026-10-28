--!strict
-- The Altar: the stack of Clue cards on top of the card stand. Played Clue cards go on top and
-- only the top card is the active clue. At the start of a turn a player may take any one Clue
-- back into their hand instead of drawing (the card beneath the top becomes active). An Altar
-- Wipe removes every card for the run. The Altar is public: everyone can look through it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local StateSync = require(script.Parent.StateSync)

type Card = Types.Card

local Altar = {}

local stack: { Card } = {} -- bottom first; the last card is the active clue
local changed = Instance.new("BindableEvent")

-- Fires (reason: "push" | "take" | "wipe" | "clear") whenever the stack changes.
Altar.Changed = changed.Event

local function update(reason: string)
	changed:Fire(reason)
	StateSync.broadcast()
end

function Altar.clear()
	stack = {}
	update("clear")
end

function Altar.count(): number
	return #stack
end

function Altar.top(): Card?
	return stack[#stack]
end

-- Cards top first (for display).
function Altar.cards(): { Card }
	local out = {}
	for i = #stack, 1, -1 do
		table.insert(out, stack[i])
	end
	return out
end

function Altar.push(card: Card)
	table.insert(stack, card)
	update("push")
end

-- Remove and return the card with this uid, or nil if it isn't on the Altar.
function Altar.take(uid: number): Card?
	for i, card in stack do
		if card.uid == uid then
			table.remove(stack, i)
			update("take")
			return card
		end
	end
	return nil
end

-- Altar Wipe: every card is gone for the run. Returns how many were wiped.
function Altar.wipe(): number
	local count = #stack
	stack = {}
	update("wipe")
	return count
end

function Altar.init()
	StateSync.register("altar", Altar.cards)
end

return Altar
