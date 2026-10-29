--!strict
-- The public clue tables from RULES.md: the 6 clue results and the 8 exit rooms with their
-- unique three-clue combinations (shown in the Journal). Which exit is the true one is a server
-- secret (server/Secrets) and is never sent to clients.

export type Exit = {
	id: string,
	name: string,
	doors: number,
	clues: { string }, -- clue result ids
}

local ClueData = {}

-- The 6 possible clue results, one per Clue card. (Tally Marks used to split into Odd and Even
-- by adding up scratches across rooms; nobody could follow it, so now it's there or it isn't,
-- like the rest. Every exit still has its own three.)
ClueData.Results = {
	music_box = "Music Box",
	wet_footprints = "Wet Footprints",
	rocking_chair = "Rocking Chair",
	frost = "Frost",
	tally_marks = "Tally Marks",
	the_doll = "The Doll",
} :: { [string]: string }

ClueData.Exits = {
	{ id = "boathouse", name = "Boathouse", doors = 1, clues = { "music_box", "frost", "tally_marks" } },
	-- (RULES.md's "Attic"; renamed because the Attic is now the Bathroom's secret space.)
	{ id = "root_cellar", name = "Root Cellar", doors = 1, clues = { "wet_footprints", "rocking_chair", "the_doll" } },
	{ id = "greenhouse", name = "Greenhouse", doors = 2, clues = { "frost", "wet_footprints", "tally_marks" } },
	{ id = "study", name = "Study", doors = 2, clues = { "music_box", "rocking_chair", "tally_marks" } },
	{ id = "chapel", name = "Chapel", doors = 2, clues = { "the_doll", "frost", "music_box" } },
	{ id = "workshop", name = "Workshop", doors = 2, clues = { "wet_footprints", "tally_marks", "rocking_chair" } },
	{ id = "nursery", name = "Nursery", doors = 3, clues = { "the_doll", "tally_marks", "wet_footprints" } },
	{ id = "mudroom", name = "Mudroom", doors = 3, clues = { "music_box", "rocking_chair", "frost" } },
} :: { Exit }

-- The clue results a Clue card can stand for (each card is its own result).
function ClueData.resultsFor(cardId: string): { string }
	return { cardId }
end

return ClueData
