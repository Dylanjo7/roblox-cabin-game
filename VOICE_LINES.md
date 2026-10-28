# Hollow Pines: voice lines

Every line the game can speak. Record whichever you like. A line with no recording still
appears as text. If a recording runs long, the game waits for it before the next line.

## Recording

- Use a quiet room, with the phone or mic about a hand's width from your mouth. Do several takes and keep the best.
- Trim the silence at the start and end. Export as **.mp3** or **.ogg**; mono is fine.
- Name each file after its **key** (e.g. `trip_1.mp3`) so nothing gets mixed up.
- Voices:
  - **Driver:** an old man, gravelly, uneasy, trying to sound calm.
  - **Radio:** any voice. The game makes it sound like a crackly truck radio, so you don't need to.
  - **Narrator:** low, slow and quiet. Lines can be whispered.

## Putting them in the game

1. Upload each file to Roblox: **Creator Hub → Creations → Development Items → Audio → Upload Asset**.
   You can also use Studio's **Asset Manager → Bulk Import**. Uploading is free, within a monthly limit.
   Upload with the same account that owns the game.
2. Copy each clip's ID once it has passed moderation, usually a few minutes.
3. Paste the IDs into `Config.Voice` in `src/shared/Config.luau`, for example `trip_1 = "123456789",`.
   Or send the list (`trip_1 = 123456789` …) to Claude to put in.

## The lines

### The drive up (the 30-second cinematic)

| Key | Who | Line | Aim for |
| --- | --- | --- | --- |
| trip_1 | Driver | Don't get many folks wanting to go up to Hollow Pines. Not after dark. | ~3.5 s |
| trip_2 | Driver | Ranger says the road's shut past the lake. I'll take you as far as the cabin path, no further. | ~4 s |
| trip_3 | Radio | ...unit four... anyone on this channel... do not stop for anyone on the— | ~3 s |
| trip_4 | Driver | ...You see that? Somebody standing out there in the trees. | ~3 s |
| trip_5 | Driver | No, no, no. Come on, girl. Not here. | ~2.5 s |
| trip_6 | Driver | Engine's gone. Cabin's just up the path. Go on. I'll radio for help. | ~3.5 s |

### Getting out of the truck

| Key | Who | Line | Aim for |
| --- | --- | --- | --- |
| arrival_1 | Narrator | The driver's door hangs open. The radio hisses. He's gone. | ~4 s |
| arrival_2 | Narrator | Somebody left the porch light on. | ~2.5 s |

### Inside, when the door slams (the intro cutscene)

| Key | Who | Line | Aim for |
| --- | --- | --- | --- |
| intro_1 | Narrator | Behind you, the front door slams. It won't open again. Every window shows the same black trees. | ~5 s |
| intro_2 | Narrator | A fire is already lit. On the Parlor table: a round board, a deck of cards, and one candle. Carved into the rim: PLAY UNTIL THREE. | ~7 s |
| intro_3 | Narrator | The locals have a name for what lives out there. They call him the Hollow Man. He keeps time by your candle, and he's coming to put it out. | ~8 s |
| intro_4 | Narrator | Build the house. Find the way out. Don't let him catch the light. | ~4 s |

### When he moves on the clock

| Key | Who | Line | Aim for |
| --- | --- | --- | --- |
| beat_enters | Narrator | Nine o'clock. Something steps out of the pines. | ~3.5 s |
| beat_moves | Narrator | Something moves closer in the dark... | ~3 s |
| beat_midnight | Narrator | Midnight. His steps grow longer. | ~3 s |
| beat_caught | Narrator | He's at the door. Move the Candle, or it goes out. | ~3.5 s |
| beat_pushedBack | Narrator | For a moment, the footsteps retreat. | ~3 s |

### Endings

| Key | Who | Line | Aim for |
| --- | --- | --- | --- |
| ending_caught_1 | Narrator | The flame gutters. A cold hand closes around it. | ~4 s |
| ending_caught_2 | Narrator | By morning the cabin is quiet, and the table is set for new players. | ~4 s |
| ending_escaped_1 | Narrator | The door gives. Cold air, real air, and the long grey road. | ~4 s |
| ending_escaped_2 | Narrator | Behind you the cabin's windows go dark, one by one. | ~4 s |
| ending_escaped_3 | Narrator | The truck starts on the first try. Nobody looks back. | ~4 s |
| ending_lost_1 | Narrator | Three o'clock came and went. Nobody found the way out. | ~4 s |
| ending_lost_2 | Narrator | By morning the cabin is quiet, and the table is set for new players. | ~4 s |
| ending_never_built_1 | Narrator | Every door you opened led back inside. | ~3 s |
| ending_never_built_2 | Narrator | The way out was never built. It's still in the deck, waiting. | ~4 s |

Changing a line? Edit its text in `src/shared/Story.luau` too, so the subtitle matches what's said.
