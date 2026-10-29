--!strict
-- The public clue tables from RULES.md: the 7 clue results and the 8 exit rooms with their
-- unique three-clue combinations (shown in the Journal). Which exit is the true one is a server
-- secret (server/Secrets) and is never sent to clients.

export type Exit = {
	id: string,
	name: string,
	doors: number,
	clues: { string }, -- clue result ids
}

local ClueData = {}

-- The 7 possible clue results (Tally Marks splits into Odd and Even).
ClueData.Results = {
	music_box = "Music Box",
	wet_footprints = "Wet Footprints",
	rocking_chair = "Rocking Chair",
	frost = "Frost",
	odd_tally = "Odd Tally",
	even_tally = "Even Tally",
	the_doll = "The Doll",
} :: { [string]: string }

ClueData.Exits = {
	{ id = "boathouse", name = "Boathouse", doors = 1, clues = { "music_box", "frost", "odd_tally" } },
	-- (RULES.md's "Attic"; renamed because the Attic is now the Bathroom's secret space.)
	{ id = "root_cellar", name = "Root Cellar", doors = 1, clues = { "wet_footprints", "rocking_chair", "the_doll" } },
	{ id = "greenhouse", name = "Greenhouse", doors = 2, clues = { "frost", "wet_footprints", "even_tally" } },
	{ id = "study", name = "Study", doors = 2, clues = { "music_box", "rocking_chair", "even_tally" } },
	{ id = "chapel", name = "Chapel", doors = 2, clues = { "the_doll", "frost", "music_box" } },
	{ id = "workshop", name = "Workshop", doors = 2, clues = { "wet_footprints", "odd_tally", "rocking_chair" } },
	{ id = "nursery", name = "Nursery", doors = 3, clues = { "the_doll", "even_tally", "wet_footprints" } },
	{ id = "mudroom", name = "Mudroom", doors = 3, clues = { "music_box", "rocking_chair", "frost" } },
} :: { Exit }

-- The clue results a Clue card can stand for (Tally Marks is Odd or Even).
function ClueData.resultsFor(cardId: string): { string }
	if cardId == "tally_marks" then
		return { "odd_tally", "even_tally" }
	end
	return { cardId }
end

return ClueData
