# Hollow Pines — TODO

RULES.md is the source of truth. MVP only for now.

## Setup
- [x] Rokit 1.2.0 installed (`~/.rokit/bin` on PATH)
- [x] Rojo 7.7.1 pinned in `rokit.toml`
- [x] Rojo Studio plugin in `%LOCALAPPDATA%\Roblox\Plugins\Rojo.rbxm`
- [x] `default.project.json` with src/server, src/client, src/shared

## MVP
- [x] **Step 1:** single player seated at the Parlor table, T starts the turn, card stand faces the active player *(tested OK)*
  - Config, Types, Remotes, GameState machine, StateSync, Table, TurnController, HUD, T input
- [x] **Step 2:** Parlor + Crawlspace setup, 5 basic room cards, R rotate, doorway matching, commit rule, +30 min penalty when no valid spot *(tested OK)*
  - CardData, Deck, Hands, RoomShapes, RoomBuilder, RoomPlacement, MapGrid, Setup, minimal Clock (Candle only)
  - Draw via button or clicking DRAW on the stand; hand UI; turn ends after the room is placed
  - Deck holds room cards only for now (`Config.DeckTypes.Progress = false` until Step 4)
- [x] **Step 3:** board UI (map grid) with placed rooms spawning full-size in the world *(tested OK)*
  - Cabin map on the table centre (TableMap + shared MapTiles), updated from MapGrid.Changed
  - BoardUI: camera zooms top-down onto the map while placing, hover ghost (green/red), legal-cell markers, grid border, R rotate, scroll zoom, left click places, Place prompt only on legal cells
  - Temporary list picker removed
  - B leaves / reopens the board any time; standing up leaves it. The room stays committed (reminder shown).
- [x] **Step 4:** clock track (9 PM to 3 AM), the Candle, all 8 Progress cards with side effects, Hollow Man movement, caught / last turn / lose *(awaiting your test)*
  - Clock: Candle + Hollow Man, round-end movement (+30, +60 from midnight), deck-out +60 once, turn-end resolution order: 3 AM -> last-turn loss -> Hollow Man moves -> catch check
  - CardEffects: all 8 Progress cards (Cold Draft's Altar Wipe and multiplayer Swap are hooks until Clues / multiplayer exist)
  - Clock track on the table's outer ring (marks, Candle piece, Hollow Man piece) + on-screen ClockUI with LAST TURN banner
  - Peek reorder panel (PeekUI + SubmitPeekOrder); GameOver result shown, back to Lobby after `Config.GameOverSeconds`
  - FinalEscape is a stub: reaching 3:00 AM ends the run

### Polish after playtest (2026-10-28)
- [x] Camera no longer freezes when leaving the board (the default camera can't start from a straight-down view; we reset it behind the character first). Verified in Studio.
- [x] Seats ignore touches for `SeatCooldownSeconds` after you stand, so jumping off doesn't re-seat you. Verified in Studio.
- [x] Table rebuilt: fixed centre disk for the cabin map, wide rotating ring carrying the stand, clock track and played cards
- [x] Card stand sits right in front of the active seat (low, tilted); click DRAW there
- [x] Draw animation (card flies from the slot to you); every played card flies from you and lands face up on the ring, turning with it

## Events (pulled forward at your request)
- [x] **E1:** Event system + Fuse Box *(tested OK)*
  - Red Event cards; drawn = starts immediately, flies face up from the draw slot onto the ring, turn ends when the event does
  - EventRunner: stands everyone up, countdown, eliminations (Crawlspace spectate, +60 min each), result pause, back to seats
  - Events from Second Wind start after the Progress card resolves; Events dealt at setup are shuffled back
  - Fuse Box: power out (dark + player lights), glowing fuse in a random built room (Parlor if none), carry to fuse box on the Parlor's north wall; group task
  - Unbuilt events stay at 0 copies in `Config.CardCopies` until their step is done
- [x] **E2:** Candlelight + Rising Water *(verified in Studio, awaiting your test)*
  - Shared `Events/EventKit` (parts, prompts, labels through walls, room picking, which room a player is in); Fuse Box moved onto it
  - `MapGrid.distancesFrom`: walking distance in rooms through doorways that line up on both sides
  - Candlelight: candles with see-through-walls labels in up to 3 random built rooms (not the Crawlspace); light all = success
  - Rising Water: rooms flood in order of distance from the Crawlspace; the farthest room(s) stay dry; anyone outside them at the end is out
- [x] **E3:** The Knock + Lockdown *(built, not yet run in Studio)*
  - The Knock: knocks from the front door (Parlor doorway to the Crawlspace); "Hide" prompt on every wardrobe and bed (1 player each, "Leave" to come out); at time-up the door opens with the Hollow Man in it; anyone not hidden is out
  - Lockdown: every doorway gets a door panel; each player is shut in a random room (not Parlor/Crawlspace) with a glowing key; taking the key opens every door on the shortest way back to the Parlor; anyone not seated at time-up is out; ends early when everyone in play is seated

## Horror pass (your request, 2026-10-28) *(boots without errors; awaiting your look)*
- [x] Story (`src/shared/Story.luau`): intro on run start, beats as he moves, endings (caught, 3 AM). Original text; rewrite freely.
- [x] Night mood set on the server (`Config.Mood`); fog/tint/ambience on the client
- [x] Cabin look: plank floors, wood walls, ceilings with beams, hanging lamps, faint room names
- [x] Furniture per room (`RoomProps`): Parlor fireplace/coat closet/armchair/rug; hallway wardrobe/side table/pictures; corner bed/armchair; T-junction grandfather clock/wardrobe; crossroads bed/crate; Closet Room 3 wardrobes; Crawlspace crates/pipes
- [x] Hollow Man model (`HollowManModel`): tall, gaunt, tattered coat, long arms, hollow eyes with embers
- [x] Dread levels from the Candle-Hollow Man gap (`Config.Dread`): fog, ambience/drone/heartbeat, flicker, creaks, glimpses of him in doorways at 30 min, him standing at the Parlor door on a last turn with a red tint
- [x] His steps on the clock: thuds + camera shake + a story line; "enters", "midnight", "pushed back", "caught" beats
- [x] Audio from Roblox's licensed library (Pro Sound Effects, APM, DistroKid), all verified to load: `Config.Sounds`
- [ ] Not yet: lobby/truck intro scene, win ending (needs exits + final escape)

## Cabin & models pass (your request, 2026-10-28) *(verified in Studio; visuals not screenshotted)*
- [x] Doorways start sealed: a doorway with nothing built behind it is wall with a window; it opens into a framed archway when a connecting room is placed; it becomes plain wall if the room behind doesn't connect. The Parlor starts fully closed in.
- [x] Solid walls are windows onto the pines unless another room is behind them
- [x] Walls: dark wainscoting, baseboards, chair rail, crown moulding; window frames, sills, mullions
- [x] Pine forest (`Forest`): trees fill empty cells within 2 of the cabin and clear when a room is built; dark ground instead of the baseplate grid
- [x] Card designs (`CardFace`): type band, title, art (room door diagram / time ring / red eye), rules text; card backs with a pine emblem. Used in the hand (hover lift) and on the table (draw slot, flying and played cards)
- [x] Chairs with backs and legs; table pedestal with a round foot
- [x] Him standing among the trees outside a window you're facing (`Config.Dread.WindowGlimpseSeconds`)
- [x] **E4:** He Walks *(built, not yet run in Studio)*
  - Appears in the room farthest from the Parlor (never the Crawlspace); walks room to room through open archways, usually toward the nearest player (`HuntChance`), with footstep sounds
  - Sight: cone in front of him (`ViewAngle`, `ViewDistance`), blocked by walls/furniture; hidden players can't be seen (shared `Events/Hiding`, also used by The Knock)
  - Seen = he charges at you; in sight `CatchSeconds` or within `GrabDistance` = caught (eliminated at once, +60 min); `GraceSeconds` after he appears
  - Time up = he leaves; everyone not caught is safe
  - Tunables: `Config.Events.HeWalks`
- **All six Events are now in the deck (1 copy each).**

## Clues (in progress, usage limit hit mid-C1)
- [x] C1 server: ClueData (7 results, 8-exit table), Secrets (true exit picked at setup, server only), 12 Clue cards in the deck, Altar (push/take/wipe, public stack), playing a Clue onto the Altar, taking a clue back instead of drawing (`RequestTakeClue`), empty-deck rule, Cold Draft wipes the Altar, Altar stack shown on the stand with card flights
- [x] C1 client: Altar panel (ALTAR button bottom-left; look through the stack; "Take" during your Draw step), play from hand at Draw when the deck is empty, keyhole art on Clue cards, HUD text
- [x] C1 tested in Studio: playing a Clue puts it on the Altar and ends the turn. Taking one back not yet tested (play session was stopped).

## Proposed next (2026-10-28 request, awaiting your OK on the plan + questions)
- [x] A. 21 uniquely named rooms (1 copy each, same 5 door shapes), each with its own furniture and clutter (incl. Bathroom) *(built, not yet run in Studio)*
  - Rooms: Front Hall, Back Hall, Gallery, Pantry, Stair Hall, Sun Porch | Kitchen, Dining Room, Living Room, Laundry Room, Sewing Room, Library | Den, Sitting Room, Music Room, Game Room | Grand Hall, Foyer | Bathroom, Bedroom, Linen Closet
  - Per-room wallpaper colour with fine stripes, tiled floors in Kitchen/Laundry/Bathroom
  - Furniture library in RoomProps (bookshelves, piano, stove, tub, clothesline, dress form, staircase, chandeliers, portraits...); one hiding spot per room, three in the Linen Closet; Bathroom has the attic hatch + pull-cord ready for step F
  - Cards restyled: aged parchment, double ink border, corner diamonds (style taken from your reference images; names/art original)
- Decisions agreed 2026-10-28: room list as above; exit "Attic" becomes "Root Cellar" (same clues); Attic card = red, only after the Bathroom is built, 60 s search, no eliminations, ledger records one true clue; front door in the Parlor's south wall beside the doorway, porch removed if a room is built south; lobby is its own place, published by you
- [x] B. Opening *(tested OK)*: spawn by the truck (headlights on), gravel path through a gap in the pines, HOLLOW PINES sign, porch with white posts/railings/steps/roof and a flickering porch light, front door open in the Parlor's south wall. Once everyone is inside, the door slams and locks, the intro plays, players respawn inside from then on. Porch/path/truck vanish if a room is built south of the Parlor. Every room now has clapboard siding outside and a roof. The Knock and the last-turn Hollow Man use the real front door.
  - Fixed: the arrival sequence could hide the intro if you got inside quickly.
- [x] C. Table *(checked in Studio with screenshots)*: table ~30% bigger (radius 9.6, map disk 6.4, chairs at 11.8), map tiles 50% bigger as parchment cards with the room name and ink walls/door gaps, clock ring with engraved groove, brass hour marks, numerals 9-3 and half-hour studs, "PLAY UNTIL THREE" carved in the gap, Candle in a brass dish with drips, Hollow Man piece = the full model at 0.13 scale on a base, wood grain, inlay ring and apron, board camera starts closer
- [x] C fix: table back near original size (radius 8.2); the cabin map now zooms to fit what's built (tiles up to 1.4 studs, about 3x the old size, shrinking as the cabin grows; `MapView`)
- [x] D. Clue signs + Journal *(sign models built and checked in Studio; full Altar-to-sign flow not seen end to end)*
  - `ClueSigns`: follows the Altar's top card; true clue -> sign in a random built room (not the Crawlspace) or an empty cell past an open doorway (appears when built); covered = hidden, uncovered = back in the same place, off the Altar = gone; second copy re-rolls
  - `SignModels`: Music Box (plays a lullaby you can follow), Wet Footprints (doorway to mid-room), Wrong Reflection (mirror rendering the room minus one piece of furniture, client `Reflections`), Frost (windows ice over, floor rime, cold light, your breath fogs), Tally Marks (up to 3 rooms, parity matches), The Doll (corner, facing the wall; a decoy frowns after the 3rd true clue)
  - `Journal`: "Record in Journal" prompt on every sign; shared entries; M opens the book (clues found, tally sum, exit table with found clues highlighted, click to cross out)
  - `Config.Debug.AllCluesTrue` makes every clue true for testing
  - The exit "Attic" is now "Root Cellar" (same clues)
  - Mirror reflection couldn't be confirmed in screenshots (the capture tool doesn't show rendered GUI views); check it by eye
- Next (your new requests): rooms of different sizes (e.g. small Bathroom), a basement under the Crawlspace where the eliminated wait behind a locked door until the event ends, a mechanical sound when pieces move on the clock
- E. 8 exit rooms + 3 AM final escape + escape ending: the game becomes winnable
- F. Bathroom -> Attic red card and attic search
- [x] G. Multiplayer 1-4 *(written, not yet run in Studio: needs a 2-4 player local test server)*
  - Start: everyone in the server sits (or `Config.LobbyStartSeconds` after the first person sits, with whoever is seated); turn order by seat
  - A turn can only start when everyone in the run is seated (RULES.md); the HUD names who's still standing and shows the turn order
  - Swap: pick who to trade with (panel, `Config.SwapChooseSeconds`); timeout = next player round the table; players who left are skipped
  - Leaving mid-run: out of the turn order; on their turn the turn ends (room/Peek/Swap dropped); during an event it ends with the event; leaving while placing the Crawlspace hands it to the next player; nobody left = back to the lobby
  - After a run everyone is stood up, so a new run starts only when people sit again (it used to restart straight away)
  - Joining mid-run: told you'll be dealt in to the next run
- [x] H. Lobby place *(written, not yet run in Studio; teleports only work in a published experience)*
  - `lobby.project.json` + `src/lobby/`: ranger station (desk, stove, bench, trail map with how to play, sign), gravel lot, pines, `Config.Lobby.Trucks` pickup trucks with boarding pads and a board showing aboard/countdown
  - Stand on a pad to join that truck (max 4); leaves when full or `Config.Lobby.DepartSeconds` after the first person gets on; `ReserveServer` + `TeleportAsync` with `{ party = userIds }`; failed teleports retry once
  - Cabin side (`Party`): in a reserved server, waits for the whole party to sit; after the run, everyone goes back to the lobby place
  - To finish: publish both places, put their ids in `Config.Places`, set the cabin place's Max Players to 4
  - Difficulty (RULES.md setup step 1) isn't defined anywhere yet, so the lobby has no difficulty setting
- [x] I. Pacing, table, Hollow Man, clocks, UI pass (2026-10-28 request) *(written, not yet run in Studio)*
  - The Hollow Man moves once every `Config.HollowMan.TurnsPerMove` (4) turns, not every round; solo runs no longer end in a few turns
  - Table pieces are client-side on brass sticks from two wheels in the table; each wheel ratchets one step at a time with a mechanical sound and a spinning cog in the rim; Candle first, then him; the next turn waits (`Clock` stage)
  - Card box replaces the stand: "It is your turn" carved in Creepster, next card sticks out of a slot (click it), Altar rack on top; the on-screen draw button is gone
  - Hollow Man rig: knees, elbows, two-jointed fingers, coat strips, collar, spine, eye glow, hem smoke; loping walk, chase lean with arms reaching, head twitches or follows you. Server moves an invisible marker (`HollowManModel.marker`), clients animate (`HollowManView`, `HollowManRig`)
  - Bug: flicker/drone/heartbeat/red tint followed the clock gap; now only when he's physically in your room or the next one, back to normal when he's gone. Fog and glimpses still follow the clock gap
  - Every grandfather clock ticks (second hand, pendulum, tick sound) and shows the Candle's time; on-screen clock removed
  - Rooms rise into place when built; bloom; vignette; new UI style (`Style`): period fonts, no grey boxes, fading messages
  - Basement: real barred iron door with a red lamp during events, opens after; stairwell up to the trapdoor; the eliminated walk back
  - Lanterns for everyone (key 1)
  - After a run everyone respawns inside (escaped players were stuck outside the locked front door)
  - Set Lighting.Technology to Future in Studio (scripts can't): lanterns and lamps then cast real shadows
- [x] J. Journal, scares, fixes *(written, not yet run in Studio)*
  - Journal is a book with pages (arrows / Left-Right keys): 2 spreads of rules in the last visitors' hand, then the group's pages: 7 clues to click found / ruled out / clear (shared; recording a sign marks it found), signs written down with the tally sum, the 8 ways out with matches highlighted, ones that no longer fit faded, click to cross out
  - Jump scares (`Scares`, `Config.Scares`): behind you when you spin round, him in a room's far corner facing the wall (head snaps round when you look), his face full-screen when you're caught, red scrawl in the Journal after midnight
  - Trees no longer poke through walls (each pine's needles stay inside its own cell)
  - Front door redone: dark oak, raised panels, four-pane window, strap hinges, knocker
- [x] K. Scarier Hollow Man, trucks, 5-truck lobby, shop, edit preview, the drive up *(written, not yet run in Studio)*
  - Hollow Man rebuilt: stooped, long crooked neck, head tipped, split grin with uneven teeth and a hanging jaw (animated; gapes when chasing), ember pinpoint eyes, nose slits, cracked skin, ribs through the coat, dead pine branches out of his back, clawed five-fingered hands, bare feet
  - `TruckModel`: old two-tone pickup (rust, mud, chrome, round headlights, cab interior, bed, tailgate); the cabin's truck is dead with its hood up and steaming
  - Lobby: 5 trucks (each its own lobby/server), log station with stone foundation and corner log ends, porch with sign, lantern and notice board, firepit, woodpile, flagpole, bays, lamp posts, gated road, tiered pines, haze + colour grade
  - Shop (`Config.Shop`, ids 0 until made on the Creator Dashboard): Lantern Colours pass (flame colours; Journal > Favours), Scare a Friend product (their screen; they're told who), Light a Candle product (memorial shelf at the ranger station, with your name). Lobby: Supplies at the front desk
  - Edit-mode preview: `require(game.ServerScriptService.Server.Preview).build()` / `.save()` / `.clear()`; room decorations saved to ServerStorage.RoomDecor follow their room every run
  - The drive up (`Trip`, `Story.Trip`): ~30 s cinematic with dialogue on arrival, skippable
- [x] L. Mirror, voice, mobile, places, badges *(written, not yet run in Studio)*
  - Mirror (Wrong Reflection) rebuilt: the room reflected across the glass and seen from your eye each frame (it shifts as you move), dim room lighting, no stray clock ticks or tags from the copy; rare scare: him behind you in it
  - Voice lines: `Config.Voice` keys for every story line (trip, arrival, intro, beats, endings), script and recording/upload steps in VOICE_LINES.md; lines wait for their recording; the radio line gets a radio filter
  - Mobile: on-screen Start turn / Rotate / Board / Journal buttons; tap once to preview a room on the board, tap again to place
  - The lobby and cabin find each other (`shared/Places`): no place ids to paste
  - Badges (`Config.Badges`, 0 = off): FirstNight, Escaped, AllOut, Caught
- [ ] C2: clue signs in rooms (lullaby audio still to find)
- [ ] C3: Journal (M)
- Clue decisions: the 9 defaults agreed on 2026-10-28 (sign placement, sign shown only while active, second copy re-rolls the spot, Tally 3 rooms 1-5 marks, Doll always appears/fake frowns after 3rd true clue, shared Journal with "Record" prompt, manual cross-out, exits not in deck yet, faked mirror)

### Event decisions (agreed defaults)
1. Players are stood up in the Parlor; they run from there.
2. Fuse Box and Candlelight are group tasks: fail = everyone still in play is eliminated.
3. The Knock, Rising Water, Lockdown, He Walks are judged per player.
4. Rising Water "farthest": walking route through doorways, counted in rooms; ties are all safe.
5. Lockdown: each player is locked in a random built room, finds the key, returns to their seat in time.
6. Hiding spots: 1 per room, 3 in the Closet Room, 1 player each.
7. The Knock's "front door": the Parlor door that leads to the Crawlspace.
8. Candlelight: 3 random built rooms, never the Crawlspace (fewer if fewer exist).
9. Fuse: random built room other than Parlor/Crawlspace, else the Parlor.
10. An Event drawn by Second Wind starts after the Progress card resolves, then the turn ends.
11. An Event dealt at setup goes back into the deck and a replacement is dealt.
12. Elimination time counts as the Candle moving on a last turn.

**MVP complete once Step 4 passes.** Next up: Clue cards, Altar, signs, Journal.

## Decisions (agreed defaults)
1. The Hollow Man entering at 9:00 PM while the Candle is still at 9:00 counts as a catch.
2. He switches to 60 min/round once **his** position is at or past midnight.
3. After a last turn where the Candle moved, the catch is checked again; a run is lost only when a last turn ends with no Candle movement.
4. The +30 min no-valid-spot penalty counts as the Candle moving.
5. Only one doorway has to line up; other doors may face walls.
6. Hold the Line can't push him below 9:00 PM, and does nothing before he has entered.
7. Solo: Swap does nothing (time still moves), Second Wind draws you 1 card, Shaking Floor discards 1 random card from your hand after you play.
8. The player places the Crawlspace on a Parlor door of their choice as a setup step; it isn't a turn.
9. Reaching 3:00 AM in the MVP goes to a FinalEscape stub that ends the run.
10. Map bounds: -6..6 on both axes (`Config.GridMin/GridMax`).

## Open questions (not in RULES.md, current stopgap)
- Deck empty and hand empty at turn start: the turn passes (and on a last turn that means the run is lost).
- Deck runs out while the Hollow Man is still off the track: the one-time +60 is used up with no effect. (Practically unreachable: the deck runs out long after round 1.)

## Later (after MVP, in RULES.md order)
- Clue cards, Altar, clue signs, Journal (M)
- 8 exit rooms, 3 AM final escape
- Event cards and elimination
- Multiplayer 1–4 with turn rotation
- Lobby, cosmetics, polish
