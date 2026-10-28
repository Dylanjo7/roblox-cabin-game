--!strict
-- Owns turn order, the active player and the current turn stage, and validates every turn intent:
-- start (T), take a card, pick a card to play (committed from then on), and place a room.
-- A round is one turn for every player in the run; the Clock resolves the Hollow Man at each turn end.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CardData = require(Shared:WaitForChild("CardData"))
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local Altar = require(script.Parent.Altar)
local CardEffects = require(script.Parent.CardEffects)
local Clock = require(script.Parent.Clock)
local Deck = require(script.Parent.Deck)
local EventRunner = require(script.Parent.EventRunner)
local GameState = require(script.Parent.GameState)
local Hands = require(script.Parent.Hands)
local RoomPlacement = require(script.Parent.RoomPlacement)
local StateSync = require(script.Parent.StateSync)
local Table = require(script.Parent.Table)

type Card = Types.Card
type TurnStage = Types.TurnStage

type PendingPlacement = {
	player: Player,
	card: Card,
	onPlaced: () -> (),
}

local TurnController = {}

local order: { Player } = {}
local activeIndex = 1
local stage: TurnStage = "WaitingStart"
local round = 1
local pending: PendingPlacement? = nil
local roundEnded = Instance.new("BindableEvent")

-- Fires (finishedRound: number) after every player in the run has taken a turn.
TurnController.RoundEnded = roundEnded.Event

local function faceActive()
	local player = order[activeIndex]
	local seat = player and Table.seatOf(player)
	if seat then
		Table.faceSeat(seat)
	end
end

local function sendPlacementOptions(player: Player, options: Types.PlacementOptions?)
	Remotes.event("PlacementOptions"):FireClient(player, options)
end

function TurnController.players(): { Player }
	return order
end

function TurnController.activePlayer(): Player?
	return order[activeIndex]
end

function TurnController.stage(): TurnStage
	return stage
end

function TurnController.setStage(newStage: TurnStage)
	stage = newStage
	StateSync.broadcast()
end

function TurnController.beginRun(players: { Player })
	order = table.clone(players)
	activeIndex = 1
	round = 1
	stage = "WaitingStart"
	pending = nil
	faceActive()
	StateSync.broadcast()
end

-- A player left mid-run: take them out of the turn order. Returns false if nobody is left.
function TurnController.removePlayer(player: Player): boolean
	local index = table.find(order, player)
	if not index then
		return #order > 0
	end
	local wasActive = index == activeIndex
	table.remove(order, index)
	if #order == 0 then
		return false
	end
	if index < activeIndex then
		activeIndex -= 1
	end
	if activeIndex > #order then
		activeIndex = 1
	end
	for _, p in order do
		Remotes.notify(p, `{player.DisplayName} left. The game goes on without them.`)
	end
	if wasActive and stage ~= "Event" then
		-- Their turn just ends; a room they had to place goes nowhere.
		if pending and pending.player == player then
			pending = nil
		end
		TurnController.startNextTurn()
	end
	StateSync.broadcast()
	return true
end

function TurnController.reset()
	if pending then
		sendPlacementOptions(pending.player, nil)
	end
	order = {}
	activeIndex = 1
	round = 1
	stage = "WaitingStart"
	pending = nil
	CardEffects.reset()
	StateSync.broadcast()
end

-- Begin the active player's turn (called after setup and after every turn end).
function TurnController.startNextTurn()
	stage = "WaitingStart"
	Clock.startTurn()
	faceActive()
	StateSync.broadcast()
end

-- Finish the current turn: the Clock checks 3 AM, the last-turn rule and the Hollow Man,
-- then play passes to the next player (in solo it comes back to you).
function TurnController.endTurn()
	activeIndex += 1
	local finished: number? = nil
	if activeIndex > #order then
		activeIndex = 1
		finished = round
		round += 1
	end

	local status = Clock.resolveTurnEnd(finished ~= nil)
	if finished then
		roundEnded:Fire(finished)
	end
	if status == "Over" then
		StateSync.broadcast()
		return
	end
	if status == "LastTurn" then
		for _, p in order do
			Remotes.notify(p, "The Hollow Man has reached the Candle! Last turn: the Candle must move forward before it ends.")
		end
	end
	TurnController.startNextTurn()
end

-- The player must now place this room card somewhere valid; there is no way back to the hand.
-- Returns false (and changes nothing) when the room has no valid spot.
function TurnController.requirePlacement(player: Player, card: Card, onPlaced: () -> ()): boolean
	local placements = RoomPlacement.findAll(card.id)
	if #placements == 0 then
		return false
	end
	pending = { player = player, card = card, onPlaced = onPlaced }
	stage = "Placing"
	sendPlacementOptions(player, { cardId = card.id, placements = placements })
	StateSync.broadcast()
	return true
end

local function isActiveTurn(player: Player, wantStage: TurnStage): (boolean, string?)
	if GameState.get() ~= "TurnLoop" then
		return false, "There's no turn in progress."
	end
	if player ~= order[activeIndex] then
		return false, "It's not your turn."
	end
	if stage ~= wantStage then
		return false, "You can't do that right now."
	end
	return true, nil
end

local function onRequestStartTurn(player: Player)
	if GameState.get() ~= "TurnLoop" then
		Remotes.notify(player, "There's no run in progress. Sit at the Parlor table to begin.")
		return
	end
	if player ~= order[activeIndex] then
		Remotes.notify(player, "It's not your turn.")
		return
	end
	if Table.seatOf(player) == nil then
		Remotes.notify(player, "Sit at the Parlor table to start your turn.")
		return
	end
	if stage ~= "WaitingStart" then
		Remotes.notify(player, "Your turn has already started.")
		return
	end

	if Deck.count() > 0 then
		stage = "Draw"
		if Altar.count() > 0 then
			Remotes.notify(player, "Turn started. Take a card from the draw slot, or a clue off the Altar.")
		else
			Remotes.notify(player, "Turn started. Take a card from the draw slot.")
		end
	elseif Altar.count() > 0 then
		-- With the deck gone, the only card you can take is a clue off the Altar (or none).
		stage = "Draw"
		Remotes.notify(player, "The deck is empty. Take a clue off the Altar, or play a card from your hand.")
	elseif #Hands.get(player) > 0 then
		stage = "Play"
		Remotes.notify(player, "The deck is empty. Play a card from your hand.")
	else
		Remotes.notify(player, "The deck is empty and your hand is empty. Your turn passes.")
		TurnController.endTurn()
		return
	end
	StateSync.broadcast()
end

-- An Event card starts the moment it's drawn: it flies face up from the draw slot onto the ring,
-- everyone is pulled from the table, and onDone runs once they're all back in their seats.
local function runEvent(card: Card, onDone: () -> ())
	local def = CardData.get(card.id)
	Table.addPlayedCard(card.id, nil, true)
	for _, p in order do
		Remotes.notify(p, `Event: {def.name}! {def.text}`)
	end
	if not EventRunner.isImplemented(card.id) then
		onDone()
		return
	end
	stage = "Event"
	GameState.transition("Event")
	EventRunner.start(card.id, order, function()
		GameState.transition("TurnLoop")
		onDone()
	end)
end

-- Run several events one after another (e.g. Second Wind drew more than one), then onDone.
local function runEvents(cards: { Card }, onDone: () -> ())
	local function step(i: number)
		if i > #cards then
			onDone()
		else
			runEvent(cards[i], function()
				step(i + 1)
			end)
		end
	end
	step(1)
end

local function onRequestDraw(player: Player): (boolean, string?)
	local ok, err = isActiveTurn(player, "Draw")
	if not ok then
		return false, err
	end
	local card = Deck.draw()
	if not card then
		return false, "The deck is empty."
	end
	if CardData.get(card.id).type == "Event" then
		-- Your turn ends when the event does.
		runEvent(card, TurnController.endTurn)
		return true, nil
	end
	Table.animateDraw(player)
	Hands.add(player, card)
	stage = "Play"
	StateSync.broadcast()
	return true, nil
end

-- Instead of drawing: take any one Clue card off the Altar into your hand.
local function onRequestTakeClue(player: Player, uid: any): (boolean, string?)
	local ok, err = isActiveTurn(player, "Draw")
	if not ok then
		return false, err
	end
	if typeof(uid) ~= "number" then
		return false, "Unknown card."
	end
	local card = Altar.take(uid)
	if not card then
		return false, "That card isn't on the Altar."
	end
	Table.animateDraw(player, true)
	Hands.add(player, card)
	for _, p in order do
		Remotes.notify(p, `{player.DisplayName} took {CardData.get(card.id).name} back off the Altar.`)
	end
	stage = "Play"
	StateSync.broadcast()
	return true, nil
end

local function onRequestSelectCard(player: Player, uid: any): (boolean, string?)
	local ok, err = isActiveTurn(player, "Play")
	if not ok and stage == "Draw" and Deck.count() == 0 and player == order[activeIndex] and GameState.get() == "TurnLoop" then
		ok = true -- deck empty: playing from your hand means you chose not to take a clue
	end
	if not ok then
		return false, err
	end
	if typeof(uid) ~= "number" then
		return false, "Unknown card."
	end
	local held: Card? = nil
	for _, card in Hands.get(player) do
		if card.uid == uid then
			held = card
		end
	end
	if not held then
		return false, "That card isn't in your hand."
	end
	local def = CardData.get(held.id)
	if def.type ~= "Room" and def.type ~= "Progress" and def.type ~= "Clue" then
		-- Hook: Exit cards are played here.
		return false, "That card type can't be played yet."
	end

	-- Committed: the card leaves the hand now and can't go back.
	local card = Hands.take(player, uid) :: Card

	if def.type == "Clue" then
		-- Onto the top of the Altar: it's the active clue now.
		Table.flyToAltar(card.id, player)
		Altar.push(card)
		for _, p in order do
			Remotes.notify(p, `{player.DisplayName} placed {def.name} on the Altar.`)
		end
		TurnController.endTurn()
		return true, nil
	end

	if def.type == "Progress" then
		Table.addPlayedCard(card.id, player)
		local done = CardEffects.play(card, { player = player, players = order, onDone = TurnController.endTurn })
		if done then
			-- Events drawn by the effect (Second Wind) start now, then the turn ends.
			runEvents(CardEffects.takeDrawnEvents(), TurnController.endTurn)
		else
			TurnController.setStage("Peeking")
		end
		return true, nil
	end

	if not TurnController.requirePlacement(player, card, TurnController.endTurn) then
		local steps = Config.NoValidSpotPenaltySteps
		Remotes.notify(player, `There's nowhere valid for the {def.name}. The card is lost and the Candle moves +{steps * Config.Clock.StepMinutes} min.`)
		Clock.advanceCandle(steps)
		TurnController.endTurn()
	end
	return true, nil
end

local function onRequestPlaceRoom(player: Player, x: any, z: any, rotation: any): (boolean, string?)
	local current = pending
	if not current or current.player ~= player then
		return false, "You have no room to place."
	end
	if typeof(x) ~= "number" or typeof(z) ~= "number" or x ~= math.floor(x) or z ~= math.floor(z) then
		return false, "That isn't a map cell."
	end
	if not RoomPlacement.isValid(current.card.id, x, z, rotation) then
		return false, "The room doesn't fit there. One of its doorways must line up with an open doorway."
	end
	RoomPlacement.place(current.card.id, x, z, rotation)
	Table.addPlayedCard(current.card.id, player)
	if current.card.id == "bathroom" then
		-- The Bathroom unlocks the Attic: its red card goes into the deck somewhere.
		Deck.insertRandom(Deck.newCard("attic"))
		for _, p in order do
			Remotes.notify(p, "Something shifts above the Bathroom ceiling. A red card has gone into the deck.")
		end
	end
	pending = nil
	sendPlacementOptions(player, nil)
	current.onPlaced()
	StateSync.broadcast()
	return true, nil
end

function TurnController.init()
	Remotes.event("RequestStartTurn").OnServerEvent:Connect(onRequestStartTurn)
	Remotes.func("RequestDraw").OnServerInvoke = onRequestDraw
	Remotes.func("RequestTakeClue").OnServerInvoke = onRequestTakeClue
	Remotes.func("RequestSelectCard").OnServerInvoke = onRequestSelectCard
	Remotes.func("RequestPlaceRoom").OnServerInvoke = onRequestPlaceRoom

	-- Clicking the face-down card on the stand is the same intent as the Draw button.
	Table.DrawClicked:Connect(function(player: Player)
		local ok, err = onRequestDraw(player)
		if not ok and err then
			Remotes.notify(player, err)
		end
	end)

	-- Keep the stand pointed at the active player if they change seats.
	Table.SeatChanged:Connect(function(seatIndex: number, player: Player?)
		if player ~= nil and player == order[activeIndex] then
			Table.faceSeat(seatIndex)
		end
	end)

	StateSync.register("turn", function()
		local active = order[activeIndex]
		return {
			activeUserId = active and active.UserId,
			activeName = active and active.DisplayName,
			stage = stage,
			round = round,
			placingId = pending and pending.card.id,
		}
	end)
	StateSync.register("deckCount", Deck.count)
end

return TurnController
