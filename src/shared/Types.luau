--!strict
-- Shared type aliases. Public state is what every client may see; nothing secret goes in here.

export type Phase = "Lobby" | "Setup" | "TurnLoop" | "Event" | "FinalEscape" | "GameOver"

export type TurnStage = "WaitingStart" | "Draw" | "Play" | "Placing" | "Peeking" | "Event" | "Clock" -- Clock: the table pieces are moving between turns

-- One physical card. uid is unique for the run so intents can name an exact card.
export type Card = {
	uid: number,
	id: string,
}

export type Placement = {
	x: number,
	z: number,
	rotation: number,
}

-- Sent only to the player who must place a room (a hint; the server re-validates).
export type PlacementOptions = {
	cardId: string,
	placements: { Placement },
}

export type TurnPublic = {
	activeUserId: number?,
	activeName: string?,
	stage: TurnStage,
	round: number,
	placingId: string?, -- the committed room being placed (played cards are public)
	order: { string }?, -- display names in turn order
	unseated: { string }?, -- players in the run who aren't at the table yet
}

export type CellPublic = {
	x: number,
	z: number,
	id: string,
	rotation: number,
}

export type ClockPublic = {
	candle: number,
	hollow: number?, -- nil while the Hollow Man is off the track
	lastTurn: boolean, -- he has reached the Candle: the Candle must move this turn
}

export type EventPublic = {
	id: string,
	name: string,
	text: string,
	endsAt: number, -- workspace:GetServerTimeNow() when time runs out
	over: boolean,
	eliminated: { number }, -- UserIds sent to the Crawlspace this event
}

-- Server-side state of one running event, handed to the event's module.
export type EventRun = {
	id: string,
	players: { Player },
	seats: { [Player]: number }, -- where each player sat when it started
	eliminated: { [Player]: boolean },
	safe: { [Player]: boolean }, -- out of it without failing (escaped); no longer in play
	endsAt: number,
	over: boolean,
	data: { [string]: any }, -- scratch space for the event module
	complete: () -> (), -- the task is done: end now, nobody else fails
	eliminate: (player: Player) -> (),
	isActive: (player: Player) -> boolean, -- still in play (not eliminated or safe, event not over)
}

-- One event's behaviour. onTimeout returns who fails when time runs out.
export type EventModule = {
	start: (run: EventRun) -> (),
	onTimeout: (run: EventRun) -> { Player },
	cleanup: (run: EventRun) -> (),
	noPenalty: boolean?, -- eliminations don't move the Candle
	keepPlayers: boolean?, -- nobody is put back in their seat afterwards
}

-- One clue sign written into the shared Journal.
export type JournalEntry = {
	clue: string, -- a clue result id (e.g. "frost"), or "tally" for scratch marks
	label: string,
	room: string,
	count: number?, -- tally marks at that spot
	by: string, -- who recorded it
}

export type JournalPublic = {
	entries: { JournalEntry },
	crossed: { string }, -- exit ids the group has crossed out
}

export type ResultPublic = {
	won: boolean,
	reason: string,
	ending: string, -- key into Story.Endings
}

export type PublicState = {
	phase: Phase,
	turn: TurnPublic?,
	cabin: { CellPublic }?,
	clock: ClockPublic?,
	deckCount: number?,
	result: ResultPublic?,
	event: EventPublic?,
	altar: { Card }?, -- Clue cards on the Altar, top (active) first
	arrival: { doorClosed: boolean }?, -- the front door has slammed behind the players
	journal: JournalPublic?,
}

return {}
