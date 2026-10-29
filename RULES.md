# Hollow Pines — Game Rules

*Working title — rename freely.*

## Overview

The card game follows the same rules structure as the cabin game. Every name, clue, event, room and visual in this doc is original.

1 to 4 players are trapped in a cabin in the woods, and the only way out is the card game on the table in the Parlor. Players take turns playing cards to build new rooms, push a shared clock toward 3:00 AM, and test clues that point to the one true exit room. The Hollow Man follows the group's clock piece, and if he catches it and the group can't move forward, the run is over.

The goal is to survive until 3:00 AM, work out the correct exit from three clues, and get through it.

## The table

All card play happens at one round table in the Parlor, and players must be seated for a turn to start. Walk into a chair to sit, or press E at it (the prompt always works).

- **Cabin map (center):** a model of the cabin. Every Room card played is added here and also built at full size in the world.
- **Clock track (outer ring):** runs from 9:00 PM to 3:00 AM in 30-minute steps, 12 steps in all. The group shares one piece, the Candle. The Hollow Man's piece also moves on this track. Each piece stands on a stick from its own wheel inside the table, and the wheel ratchets round one step at a time. The time is shown only here and on the cabin's clocks, never on screen.
- **Card box:** a small wooden box carved "It is your turn" that sits in front of the active player. The next card sticks out of it face down (take it from there), and the Altar sits on top, where Clue cards are stacked.
- **Played cards:** stay face up around the table's edge. There's no discard pile, and a card removed by an effect is gone for the run.
- **Rotation:** after each turn, the outer ring turns so the card stand faces the next player. In solo play it keeps coming back to you.

## Setup

1. Players meet in a lobby (a ranger station works), set difficulty, then get into a truck together to start the run.
2. The run begins in the Parlor, the fixed starting room with a door on all four sides. Everyone walks up from the dead truck. The front door slams once the whole group is inside, or 45 seconds after the first player gets in, whichever comes first (anyone still outside is brought in). It also slams the moment a run starts.
3. The server secretly picks the true exit room and its three true clues (see Exit rooms).
4. The Candle starts at 9:00 PM. The Hollow Man starts off the track and enters at 9:00 PM after the first 4 turns.
5. The first card played is always the Crawlspace, a one-door room attached to any Parlor doorway. It can't be built from, so the cabin grows from the Parlor's other three doors.
6. Each player is dealt 3 cards and normal turns begin.

## Taking a turn

The card stand faces the active player, who starts the turn once everyone is seated.

1. **Take one card.** Either take the face-down card from the draw slot, or take any one Clue card off the Altar into your hand. Never both. You can look through the Altar first without committing.
2. **If you drew an Event card,** it starts immediately and your turn ends when the event does.
3. **Play one card from your hand** and follow its type's rules (below). Once you pick a card to play, you're committed to it.
4. **End the turn.** The ring rotates to the next player.

A round is one turn for every seated player. Only cards move the Candle: never a turn, a round or an event.

**Nobody holds up the table (2+ players).** Each step of a turn has a time limit, with a countdown on screen for the last 12 seconds. When it runs out, the game takes the step for you.

| Step | Limit | What happens |
| --- | --- | --- |
| Starting your turn | 60 s | Anyone not in their chair is put back in it, and your turn starts. |
| Taking a card | 40 s | You take the card from the box. With the deck empty, it's treated as the play step. |
| Playing a card | 50 s | A card is played for you: an exit room first, then a clue, a room, and a Progress card last. On a last turn a Progress card comes first, since only that can save the run. With an empty hand you take the top clue off the Altar, or your turn passes. |
| Placing a room | 60 s | The room goes in a random valid spot. |
| Peek or Swap | 40 s | Peek leaves the cards as they are. Swap trades with the next player round the table. |

Solo, the table waits for you.

## Room cards

Room cards add a room to the map and build it in the world at the matching spot.

- Selecting a Room card zooms the camera onto the map. R rotates the room, scroll zooms, left click places it.
- A Place prompt shows only when one of the room's doorways lines up with an open doorway on the map.
- Once selected, you can't cancel back to your hand. You must place that room somewhere valid. If there's nowhere valid, the card is lost and the Candle moves +30 minutes as a penalty.
- Each map cell is one 40×40 stud tile in the world, so cell (x, z) builds at Parlor position + (x × 40, 0, z × 40).
- Layout matters later. Clues can only appear in built rooms, the exit has to be built to escape through it, and dead ends make events harder to survive.

## Progress cards and the clock

Progress cards move the shared Candle forward 30 or 60 minutes, and most also carry a side effect that can help or hurt. The Candle moves only when a card is played: Progress cards, and the penalty for a room card with nowhere to go.

| Card | Time | Side effect |
| --- | --- | --- |
| Steady Hands | +30 min | None |
| Second Wind | +30 min | Every player draws 1 card |
| Hold the Line | +30 min | Push the Hollow Man back 30 min |
| Peek | +30 min | Look at the next 3 cards in the deck and put them back in any order |
| Long Night | +60 min | None |
| Cold Draft | +60 min | Altar Wipe: every Clue card on the Altar is gone |
| Shaking Floor | +60 min | Every player discards 1 random card |
| Swap | +60 min | Trade your whole hand with another player's |

Rushing the clock keeps the Hollow Man behind you but leaves less time to find clues. Stalling to search lets him catch up.

## Clues and the Altar

Playing a Clue card puts it on top of the Altar stack, and only the top card is the active clue. If that clue is one of the three true clues, its sign appears in a random built room, straight away. If it isn't, nothing appears, and that's information too.

- **Searching:** players get up from the table and walk the cabin to find the sign. It's always in a room that's already built (never the Crawlspace), so "nothing appeared" really does mean the clue is false (except The Doll, below).
- **Revealed vs. discovered:** a clue is revealed when its sign appears in the world, and discovered when a player records it in the Journal (M key).
- **Taking clues back:** at the start of a turn you can take any Clue card off the Altar instead of drawing. The card beneath it becomes the active clue. Taking a clue back protects it from an Altar Wipe.

**Clue types**

| Clue | The sign |
| --- | --- |
| Music Box | A faint lullaby starts playing somewhere. Follow the sound to a small open music box. |
| Wet Footprints | Bare, wet footprints track across a floor and stop in the middle of a room. |
| Rocking Chair | An empty rocking chair rocks by itself in one room, creaking loud enough to follow. |
| Frost | One room's windows ice over and players' breath fogs inside it. |
| Tally Marks | Scratch marks gouged into a wall in one room, in fives, like someone counting the days. It's there or it isn't, like the others (the number doesn't matter). |
| The Doll | A cloth doll sits facing the wall. It can be a decoy: if it's fake, its stitched smile turns into a frown once the third true clue is revealed. |

That's 6 clue results, one per Clue card. (Tally Marks used to split into Odd and Even by adding up scratches across rooms. Playtesters couldn't follow it, so it's a plain clue now, and every exit still has its own three.)

## Exit rooms

Eight Room cards are exit rooms, one copy each, and only one is the true exit in any run. Each has a sealed outside door and a unique combination of three clues, listed in the Journal. Matching discovered clues to this table is how players deduce the exit.

| Exit room | Doors | Clue 1 | Clue 2 | Clue 3 |
| --- | --- | --- | --- | --- |
| Boathouse | 1 | Music Box | Frost | Tally Marks |
| Root Cellar | 1 | Wet Footprints | Rocking Chair | The Doll |
| Greenhouse | 2 | Frost | Wet Footprints | Tally Marks |
| Study | 2 | Music Box | Rocking Chair | Tally Marks |
| Chapel | 2 | The Doll | Frost | Music Box |
| Workshop | 2 | Wet Footprints | Tally Marks | Rocking Chair |
| Nursery | 3 | The Doll | Tally Marks | Wet Footprints |
| Mudroom | 3 | Music Box | Rocking Chair | Frost |

The true exit has to be built before 3:00 AM to escape through it, so holding exit cards and choosing when to play them is part of the strategy.

## The Hollow Man

The Hollow Man chases the group's Candle on the clock track, not the players themselves. On Normal he moves once every 4 turns, whatever the player count (once round the table with 4 players; every 4th turn solo): 30 minutes, or 60 minutes from midnight on. The next turn waits while his piece moves.

- **Caught:** if his piece reaches or passes the Candle, the group gets one last turn. That turn plays normally, but the Candle has to move forward before it ends.
- **Lost:** if the last turn ends without the Candle moving, the run is over for everyone.
- **The trap:** on the last turn, drawing an unknown card is risky. An Event or a card that ends your turn early can cost the run, so taking a clue off the Altar and playing a Progress card already in your hand is the safer line.

His piece shows on the track at all times, so the group always knows how close he is.

## Difficulty

Each truck in the lobby has a difficulty, shown on the sign by its boarding pad. Anyone on the truck (or anyone, while it's empty) can change it at the sign. The run is played at the truck's difficulty.

| Difficulty | He moves every | Cards dealt | Event timers | He moves in events | Scares |
| --- | --- | --- | --- | --- | --- |
| Normal | 4 turns | 3 each | as listed | normal speed | normal |
| Hard | 3 turns | 3 each | 85% | 12% faster | more often |
| Nightmare | 3 turns | 2 each | 75% | 25% faster | twice as often |

The final escape is always 90 seconds.

## Event cards and elimination

An Event card starts the moment it's drawn and pulls every player away from the table into a timed, real-time challenge in the cabin. Normal turns resume when it ends.

| Event | What players must do | Time |
| --- | --- | --- |
| Fuse Box | The power dies. The spare fuse is always in the middle of the Crawlspace (marked through the walls): carry it to the fuse box in the Parlor. | 55 s |
| The Knock | Something knocks at the front door. Every player must be hidden in a closet or under a bed when it opens. If the cabin doesn't have enough hiding places for everyone, there's room under the Parlor table. | 45 s |
| Candlelight | Light candles in 3 marked rooms before the last one burns out. | 90 s |
| He Walks | The Hollow Man enters the cabin in person and hunts. If he sees you he comes for you, a little slower than you can run. Being seen doesn't catch you: he has to reach you (or keep you in sight up close for a moment). Hide or outrun him until he leaves. | 60 s |
| Rising Water | Water floods out from the Crawlspace. Get to the room farthest from it on the map. | 32 s |
| Lockdown | All doors slam shut. Your room's key always floats just inside its door back to the table: take it to open the way, then sit back down. | 60 s |
| Don't Look Away | Something pale climbs out of the mirrors. It only moves while nobody is looking at it, and every so often the lights fail for a blink and it moves anyway. It comes for the nearest player; if it reaches you, you're out. Cover the marked mirrors (up to 3) to send it back. If any mirror is still bare at the end, everyone still in play is out. | 75 s |
| Hush | A gramophone starts playing somewhere in the cabin. Move while the music plays. When the needle lifts, freeze: anyone who moves (turning to look is fine) before it plays again is out. Find it and lift the needle for good. After 25 seconds everyone is told which room it's in. If it's still playing at the end, everyone still in play is out. | 70 s |

**Elimination**

- You can't reset your character during an event or the final escape.
- **One at a time.** When he (or the pale thing) catches someone, it holds them for a moment while it gets them, and for 5 seconds after it stays where it is and can't catch anyone else, so the players near them can get away.
- A player who fails an event wakes up in the basement under the Crawlspace. Its door is barred until the event ends.
- Every player caught lets the Hollow Man gain 30 minutes on the Candle (if he's on the track yet), up to 1 hour from any one event, however many are caught. The Candle itself doesn't move.
- When the event ends the basement door opens, and eliminated players climb out and walk back to the table. The next turn waits until everyone is seated. Elimination costs time, not your spot in the run.

## 3 AM and the final escape

Reaching 3:00 AM isn't a loss. It starts the final escape, whether or not the group found all three clues.

1. The clocks strike three (a 10-second cutscene; the 90 seconds start after it). Every built exit room's outside door unseals. Only the true exit's door leads out; the rest are traps.
2. The Hollow Man bursts in through the front door. He stands in the doorway for 8 seconds, then hunts, a bit slower than in He Walks.
3. Each player has 90 seconds to reach the exit room they believe is right and go through its door. Unsealed doors glow and are labelled once you're in their room; press **F** at one to go through (its own key, so a nearby Hide or Record prompt can't get in the way).
4. A player who picks a wrong door, or is caught, is out.

**Win:** at least one player escapes through the true exit. Everyone who got out is credited with the win.

**Lose:** nobody escapes, the true exit was never built, or the Hollow Man ends the run before 3:00 AM.

With fewer than three clues, players have to guess between the exits that still fit, which is why skipping clues to rush the clock is risky.

**The end of the night.** After the ending plays, everyone sees the night in numbers: how long it took, the rounds played, the time the Candle reached, rooms built, signs written in the Journal, notes found, how each event went, and which exit was the true one. Each player gets a line (cards played, rooms placed, signs written, times caught, and whether they got out), and a few get a title: First Out, The Detective (most signs), The Builder (most rooms), Untouchable (never caught, 2+ events), His Favourite (caught the most). The table resets, or the party goes back to the ranger station, 36 seconds after the run ends.

## Deck list

A run's shuffled deck holds 49 cards. The rooms and the events are pools: each run deals in 10 of the 21 rooms (by number of doorways, so the cabin always has room to grow) and 6 of the 8 events, at random, so no two nights are the same. The Crawlspace is set aside for setup and isn't shuffled in.

| Card | Type | Copies in a run |
| --- | --- | --- |
| 2 of the 3 one-door rooms (Bathroom, Bedroom, Linen Closet) | Room | 2 |
| 5 of the 12 two-door rooms (straight halls and corners) | Room | 5 |
| 2 of the 4 three-door rooms | Room | 2 |
| 1 of the 2 four-door rooms | Room | 1 |
| Exit rooms (8 different, see Exit rooms) | Room | 8 |
| Steady Hands | Progress | 3 |
| Long Night | Progress | 4 |
| Second Wind | Progress | 2 |
| Hold the Line | Progress | 2 |
| Peek | Progress | 1 |
| Cold Draft | Progress | 1 |
| Shaking Floor | Progress | 1 |
| Swap | Progress | 1 |
| Music Box, Wet Footprints, Rocking Chair, Frost, Tally Marks, The Doll | Clue | 2 each, 12 total |
| 6 of: Fuse Box, The Knock, Candlelight, He Walks, Rising Water, Lockdown, Don't Look Away, Hush | Event | 6 |

If the deck runs out, players can only take clues off the Altar, and the Hollow Man moves an extra 60 minutes once.

**Why these numbers.** They come from simulating thousands of runs of these rules (a bot playing sensibly: build exits as soon as they're drawn, test clues it hasn't tried, keep the Candle just ahead of him, then run for 3:00 AM once it knows the way out). The old 64-card deck was too big for the time he allows: the run is over by about turn 25-40, so the single true exit card often never came up (it was built in only about half of runs), and with 4 players a failed group event gave him 2 hours. On Normal the bot now wins about 55% of runs at any player count (it was about 30%), Hard about 35% and Nightmare about 23%. About 1 Normal run in 4 is still lost because the true exit never came out of the deck in time; Peek and Second Wind help dig for it.

## Build notes and MVP scope

The first playable version proves the turn loop: take a card, play it, watch the cabin grow while the Hollow Man closes in on the clock.

**MVP (build first)**

- [ ] Single player at the table, with the card stand that rotates to the active player
- [ ] Parlor, Crawlspace setup, and the 5 basic Room cards with rotation and doorway matching
- [ ] Map cells building full-size rooms in the world
- [ ] Clock track, the Candle, Progress cards and the Hollow Man's movement and catch rule

**Then add, in order**

1. Clue cards, the Altar stack, clue signs spawning in built rooms, and the Journal
2. The 8 exit rooms and the 3 AM final escape
3. Event cards and elimination
4. Multiplayer for 1 to 4 players with turn rotation
5. Lobby, cosmetics and polish

**Rules for the code**

- The server owns the deck, every hand, the true exit and the true clues. Clients send only actions like "play card X at cell Y with rotation R", and the server validates them. Otherwise exploiters can read the answer.
- Every room is a Model with the same 40×40 footprint and doorway markers named N, E, S and W, so one placement script handles all of them.
- Keep every number in this doc (times, card counts, event timers) in one config ModuleScript so you can rebalance without digging through code.
- Keep names, art, sounds and clue designs your own. The rules match the original; the look and content must not.
