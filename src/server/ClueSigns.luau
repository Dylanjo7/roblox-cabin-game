--!strict
-- Clue signs follow the Altar. Only the top card is the active clue: if it's one of the three
-- true clues, its sign appears in the cabin; if not, nothing appears (that's information too),
-- except The Doll, which always appears (a fake one is a decoy that frowns once the third
-- different true clue has been revealed).
--   - A sign goes in a random built room (never the Crawlspace) or an empty spot just past an
--     open doorway; there it waits and appears when a room is built.
--   - It shows only while its card is the active clue; covered, it hides; uncovered again, it
--     comes back in the same place. Once the card leaves the Altar it's gone for good. A second
--     copy of the same clue picks a new spot.
--   - Tally Marks: scratches in up to 3 different rooms whose total is odd or even to match.
-- Every sign has a "Record in Journal" prompt (see Journal).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CardData = require(Shared:WaitForChild("CardData"))
local Config = require(Shared:WaitForChild("Config"))
local RoomShapes = require(Shared:WaitForChild("RoomShapes"))
local Types = require(Shared:WaitForChild("Types"))

local Altar = require(script.Parent.Altar)
local Journal = require(script.Parent.Journal)
local MapGrid = require(script.Parent.MapGrid)
local Spots = require(script.Parent.Spots)
local Secrets = require(script.Parent.Secrets)
local SignModels = require(script.Parent.SignModels)

type Card = Types.Card

type Spot = {
	x: number,
	z: number,
	count: number?, -- Tally Marks: scratches at this spot
	seed: number, -- so the sign looks the same each time it reappears
	model: Model?,
	thaw: (() -> ())?,
}

type Sign = {
	card: Card,
	result: string?, -- the true result it reveals, or nil
	decoy: boolean, -- a fake Doll
	spots: { Spot },
}

local ClueSigns = {}

local folder: Folder
local signs: { [number]: Sign } = {}
local revealed: { [string]: boolean } = {} -- distinct true clues revealed so far
local rng = Random.new()

local function revealedCount(): number
	local n = 0
	for _ in revealed do
		n += 1
	end
	return n
end

-- Built rooms a sign can go in, plus empty cells just past open doorways.
local function candidateCells(includeEmpty: boolean): { { x: number, z: number } }
	local out = {}
	local seen: { [string]: boolean } = {}
	for _, cell in MapGrid.all() do
		if cell.id ~= "crawlspace" then
			table.insert(out, { x = cell.x, z = cell.z })
		end
		if includeEmpty and cell.buildable then
			for dir in cell.doors do
				local dx, dz = RoomShapes.offset(dir :: RoomShapes.Dir)
				local x, z = cell.x + dx, cell.z + dz
				local k = MapGrid.key(x, z)
				if not MapGrid.get(x, z) and MapGrid.inBounds(x, z) and not seen[k] then
					seen[k] = true
					table.insert(out, { x = x, z = z })
				end
			end
		end
	end
	return out
end

local function newSign(card: Card): Sign
	local result = Secrets.trueResultFor(card.id)
	local sign: Sign = { card = card, result = result, decoy = card.id == "the_doll" and result == nil, spots = {} }
	if result == nil and not sign.decoy then
		return sign -- not a true clue: nothing appears
	end
	if card.id == "tally_marks" then
		local rooms = candidateCells(false)
		local picked = {}
		for _ = 1, math.min(3, #rooms) do
			table.insert(picked, table.remove(rooms, rng:NextInteger(1, #rooms)))
		end
		local total = 0
		for _, cell in picked do
			local count = rng:NextInteger(Config.Events.TallyMin, Config.Events.TallyMax)
			total += count
			table.insert(sign.spots, { x = cell.x, z = cell.z, count = count, seed = rng:NextInteger(1, 1e6) })
		end
		-- Make the total odd or even to match the true tally.
		local wantOdd = result == "odd_tally"
		local last = sign.spots[#sign.spots]
		if last and last.count and (total % 2 == 1) ~= wantOdd then
			last.count = if last.count < Config.Events.TallyMax then last.count + 1 else last.count - 1
		end
	else
		local cells = candidateCells(true)
		local cell = cells[rng:NextInteger(1, #cells)]
		table.insert(sign.spots, { x = cell.x, z = cell.z, seed = rng:NextInteger(1, 1e6) })
	end
	return sign
end

local function recordPrompt(sign: Sign, spot: Spot, anchor: BasePart, roomName: string)
	local name = CardData.get(sign.card.id).name
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Record in Journal"
	prompt.ObjectText = name
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = Config.Events.SignPromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player: Player)
		local clue = if sign.card.id == "tally_marks" then "tally" else sign.card.id
		local label = if spot.count then `{name}: {spot.count}` else name
		Journal.record(player, `{sign.card.uid}:{spot.x},{spot.z}`, { clue = clue, label = label, room = roomName, count = spot.count })
	end)
end

local function buildSpot(sign: Sign, spot: Spot)
	local cell = MapGrid.get(spot.x, spot.z)
	if not cell or not cell.model or spot.model then
		return -- not built yet (it'll appear when it is), or already showing
	end
	local room = cell.model
	local roomName = CardData.get(cell.id).name
	local centre = RoomShapes.cellPosition(cell.x, cell.z)
	local hx, hz = MapGrid.halfSize(cell)
	local half = Vector2.new(hx, hz)
	local signRng = Random.new(spot.seed)
	local id = sign.card.id
	local m: Model
	-- A spot on a wall with nothing in front of it (no wardrobe or shelf hiding the sign).
	local function clearWall(height: number, need: Vector3): CFrame
		for _ = 1, 15 do
			local cf = SignModels.wallSpot(centre, half, signRng, height)
			if Spots.wallClear(cf, need) then
				return cf
			end
		end
		return SignModels.wallSpot(centre, half, signRng, height)
	end
	if id == "music_box" then
		-- On open floor: never inside or under the furniture.
		local at = CFrame.new(Spots.clear(cell, signRng, 1.2)) * CFrame.Angles(0, signRng:NextNumber(0, 6), 0)
		m = SignModels.musicBox(folder, at)
	elseif id == "wet_footprints" then
		-- From one of the room's doorways (or a wall if it has none open) to the middle.
		local dirs = {}
		for dir in cell.doors do
			table.insert(dirs, dir)
		end
		local dir = dirs[signRng:NextInteger(1, #dirs)] :: RoomShapes.Dir
		local dx, dz = RoomShapes.offset(dir)
		local from = centre + Vector3.new(dx, 0, dz) * (Config.TileSize / 2 - 1.5)
		-- They stop somewhere you can see, near the middle (not under the table).
		local to = Spots.clear(cell, signRng, 1.2, 7)
		m = SignModels.footprints(folder, from, to)
	elseif id == "wrong_reflection" then
		-- Something from this room's furniture that the mirror won't show.
		local props = room:FindFirstChild("Props")
		local options = {}
		for _, child in if props then props:GetChildren() else {} do
			if child:IsA("Model") and child.Name ~= "Rug" then
				table.insert(options, child.Name)
			end
		end
		local missing = if #options > 0 then options[signRng:NextInteger(1, #options)] else ""
		m = SignModels.mirror(folder, clearWall(6.5, Vector3.new(3.8, 5.8, 1.5)), room.Name, missing)
	elseif id == "frost" then
		local thaw
		m, thaw = SignModels.frost(folder, room, centre, half, signRng)
		spot.thaw = thaw
	elseif id == "tally_marks" then
		m = SignModels.tally(folder, clearWall(5, Vector3.new(3, 2.4, 1.2)), spot.count or 1)
	else -- the_doll
		-- In a corner with nothing in it (the next clear one along if a wardrobe's in the way).
		local at, corner = Spots.corner(cell, signRng, 0.8)
		m = SignModels.doll(folder, at, corner, sign.decoy and revealedCount() >= 3)
	end
	spot.model = m
	local anchor = m:FindFirstChild("PromptAnchor", true)
	if anchor and anchor:IsA("BasePart") then
		recordPrompt(sign, spot, anchor, roomName)
	end
	-- A true clue counts as revealed once its sign is actually in the cabin.
	local result = sign.result
	if result and not revealed[result] then
		revealed[result] = true
		if revealedCount() >= 3 then
			-- Every decoy Doll now showing gives itself away.
			for _, other in signs do
				if other.decoy then
					for _, s in other.spots do
						if s.model then
							SignModels.setFrown(s.model)
						end
					end
				end
			end
		end
	end
end

local function hide(sign: Sign)
	for _, spot in sign.spots do
		if spot.thaw then
			spot.thaw()
			spot.thaw = nil
		end
		if spot.model then
			spot.model:Destroy()
			spot.model = nil
		end
	end
end

local function refresh()
	local top = Altar.top()
	local onAltar: { [number]: boolean } = {}
	for _, card in Altar.cards() do
		onAltar[card.uid] = true
	end
	for uid, sign in signs do
		if not onAltar[uid] then
			hide(sign) -- gone for good
			signs[uid] = nil
		elseif not top or uid ~= top.uid then
			hide(sign) -- covered: hidden until it's on top again
		end
	end
	if top then
		local sign = signs[top.uid]
		if not sign then
			sign = newSign(top)
			signs[top.uid] = sign
		end
		for _, spot in sign.spots do
			buildSpot(sign, spot)
		end
	end
end

function ClueSigns.reset()
	for _, sign in signs do
		hide(sign)
	end
	signs = {}
	revealed = {}
end

function ClueSigns.init()
	folder = Instance.new("Folder")
	folder.Name = "ClueSigns"
	folder.Parent = workspace
	Altar.Changed:Connect(refresh)
	MapGrid.Changed:Connect(refresh) -- a sign waiting for an unbuilt spot appears when it's built
end

return ClueSigns
