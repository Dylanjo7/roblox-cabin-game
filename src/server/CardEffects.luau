--!strict
-- Plays non-room cards. Each Progress card moves the Candle by Config.ProgressSteps[id], then
-- runs the side effect named by its `effect` id in CardData. Clue, Exit and Event cards hook in here later.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CardData = require(Shared:WaitForChild("CardData"))
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local Altar = require(script.Parent.Altar)
local Clock = require(script.Parent.Clock)
local Deck = require(script.Parent.Deck)
local Hands = require(script.Parent.Hands)
local Table = require(script.Parent.Table)

type Card = Types.Card

export type Context = {
	player: Player, -- who played the card
	players: { Player }, -- everyone in the run
	onDone: () -> (), -- call to finish the turn after an effect that waits for input
}

-- A handler returns true when the turn can end now, false when it waits for the player (Peek).
type Handler = (ctx: Context) -> boolean

local CardEffects = {}

local pendingPeek: { player: Player, uids: { number }, onDone: () -> () }? = nil
local pendingSwap: { player: Player, options: { Player }, players: { Player }, onDone: () -> (), token: number }? = nil
local swapToken = 0
local drawnEvents: { Card } = {} -- Event cards drawn by an effect; they start once it resolves

local function notifyAll(players: { Player }, text: string)
	for _, p in players do
		Remotes.notify(p, text)
	end
end

local function swapWith(player: Player, other: Player, players: { Player })
	Hands.swap(player, other)
	notifyAll(players, `Swap: {player.DisplayName} and {other.DisplayName} traded hands.`)
end

local HANDLERS: { [string]: Handler } = {
	none = function(_ctx)
		return true
	end,

	all_draw = function(ctx)
		for _, p in ctx.players do
			local card = Deck.draw()
			if card and CardData.get(card.id).type == "Event" then
				table.insert(drawnEvents, card)
				Remotes.notify(p, "Second Wind: you drew an Event card!")
			elseif card then
				Table.animateDraw(p)
				Hands.add(p, card)
				Remotes.notify(p, `Second Wind: you drew {CardData.get(card.id).name}.`)
			else
				Remotes.notify(p, "Second Wind: the deck is empty, so there's nothing to draw.")
			end
		end
		return true
	end,

	push_hollow_man = function(ctx)
		if Clock.pushHollowMan(Config.HoldTheLinePushSteps) then
			notifyAll(ctx.players, "Hold the Line: the Hollow Man is pushed back 30 min.")
		else
			notifyAll(ctx.players, "Hold the Line: the Hollow Man isn't on the track yet.")
		end
		return true
	end,

	peek = function(ctx)
		local top = Deck.peekTop(Config.PeekCount)
		if #top == 0 then
			Remotes.notify(ctx.player, "Peek: the deck is empty.")
			return true
		end
		local uids = {}
		for _, card in top do
			table.insert(uids, card.uid)
		end
		pendingPeek = { player = ctx.player, uids = uids, onDone = ctx.onDone }
		Remotes.event("PeekCards"):FireClient(ctx.player, top)
		return false
	end,

	altar_wipe = function(ctx)
		local wiped = Altar.wipe()
		if wiped > 0 then
			notifyAll(ctx.players, `Cold Draft: an icy gust sweeps the Altar. {wiped} clue card{if wiped == 1 then " is" else "s are"} gone for good.`)
		else
			notifyAll(ctx.players, "Cold Draft: an icy gust, but the Altar was already empty.")
		end
		return true
	end,

	all_discard_random = function(ctx)
		for _, p in ctx.players do
			local card = Hands.takeRandom(p)
			if card then
				Remotes.notify(p, `Shaking Floor: you lost {CardData.get(card.id).name}.`)
			else
				Remotes.notify(p, "Shaking Floor: your hand is empty, so you lost nothing.")
			end
		end
		return true
	end,

	swap_hands = function(ctx)
		if #ctx.players < 2 then
			Remotes.notify(ctx.player, "Swap: there's nobody to trade hands with.")
			return true
		end
		-- Choose who to trade with (only one choice in a 2-player run, so it's automatic). The list
		-- runs round the table from the next player, so the timeout default is the next player.
		local options = {}
		local start = table.find(ctx.players, ctx.player) or 0
		for i = 1, #ctx.players - 1 do
			local p = ctx.players[(start + i - 1) % #ctx.players + 1]
			if p ~= ctx.player and p.Parent then
				table.insert(options, p)
			end
		end
		if #options == 0 then
			Remotes.notify(ctx.player, "Swap: there's nobody to trade hands with.")
			return true
		end
		if #options == 1 then
			swapWith(ctx.player, options[1], ctx.players)
			return true
		end
		swapToken += 1
		local token = swapToken
		pendingSwap = { player = ctx.player, options = options, players = ctx.players, onDone = ctx.onDone, token = token }
		local list = {}
		for _, p in options do
			table.insert(list, { userId = p.UserId, name = p.DisplayName, cards = #Hands.get(p) })
		end
		Remotes.event("SwapOptions"):FireClient(ctx.player, list)
		-- Not choosing in time trades with the next player round the table.
		task.delay(Config.SwapChooseSeconds, function()
			local swap = pendingSwap
			if swap and swap.token == token then
				pendingSwap = nil
				Remotes.event("SwapOptions"):FireClient(swap.player, nil)
				for _, other in swap.options do
					if other.Parent then
						swapWith(swap.player, other, swap.players)
						break
					end
				end
				swap.onDone()
			end
		end)
		return false
	end,
}

-- Play a card that has already left the player's hand. Returns true when the turn can end now.
function CardEffects.play(card: Card, ctx: Context): boolean
	local def = CardData.get(card.id)
	assert(def.type == "Progress", `{def.name} can't be played as a Progress card`)
	local steps = Config.ProgressSteps[def.id] or 0
	Remotes.notify(ctx.player, `{def.name}: the Candle moves +{steps * Config.Clock.StepMinutes} min.`)
	Clock.advanceCandle(steps)
	local handler = HANDLERS[def.effect or "none"]
	assert(handler, `No handler for effect {def.effect}`)
	return handler(ctx)
end

-- A player left the game: drop a Peek or Swap they were in the middle of, so it can't finish
-- their turn later. Returns true if they had one pending.
function CardEffects.cancelFor(player: Player): boolean
	local had = false
	if pendingPeek and pendingPeek.player == player then
		pendingPeek = nil
		had = true
	end
	if pendingSwap and pendingSwap.player == player then
		pendingSwap = nil
		had = true
	end
	return had
end

-- Out of time on a Peek or a Swap choice: finish it as it stands (Peek: the cards stay in the
-- order they're in; Swap: with the next player round the table). Returns true if there was one.
function CardEffects.finishFor(player: Player): boolean
	local peek = pendingPeek
	if peek and peek.player == player then
		pendingPeek = nil
		Remotes.event("PeekCards"):FireClient(player, nil)
		Remotes.notify(player, "Out of time: the cards go back as they are.")
		peek.onDone()
		return true
	end
	local swap = pendingSwap
	if swap and swap.player == player then
		pendingSwap = nil
		Remotes.event("SwapOptions"):FireClient(player, nil)
		for _, other in swap.options do
			if other.Parent then
				swapWith(player, other, swap.players)
				break
			end
		end
		swap.onDone()
		return true
	end
	return false
end

function CardEffects.reset()
	pendingPeek = nil
	pendingSwap = nil
	drawnEvents = {}
end

-- Event cards drawn by the last effect, in draw order. Clears the list.
function CardEffects.takeDrawnEvents(): { Card }
	local events = drawnEvents
	drawnEvents = {}
	return events
end

local function onSubmitPeekOrder(player: Player, uids: any)
	local peek = pendingPeek
	if not peek or peek.player ~= player then
		return
	end
	if typeof(uids) ~= "table" or #uids ~= #peek.uids then
		Remotes.notify(player, "That isn't a valid order.")
		return
	end
	for _, uid in uids do
		if typeof(uid) ~= "number" or not table.find(peek.uids, uid) then
			Remotes.notify(player, "That isn't a valid order.")
			return
		end
	end
	if not Deck.reorderTop(uids) then
		Remotes.notify(player, "That isn't a valid order.")
		return
	end
	pendingPeek = nil
	Remotes.event("PeekCards"):FireClient(player, nil)
	peek.onDone()
end

local function onSubmitSwapTarget(player: Player, userId: any)
	local swap = pendingSwap
	if not swap or swap.player ~= player or typeof(userId) ~= "number" then
		return
	end
	for _, other in swap.options do
		if other.UserId == userId and other.Parent then
			pendingSwap = nil
			Remotes.event("SwapOptions"):FireClient(player, nil)
			swapWith(player, other, swap.players)
			swap.onDone()
			return
		end
	end
end

function CardEffects.init()
	Remotes.event("SubmitPeekOrder").OnServerEvent:Connect(onSubmitPeekOrder)
	Remotes.event("SubmitSwapTarget").OnServerEvent:Connect(onSubmitSwapTarget)
end

return CardEffects
