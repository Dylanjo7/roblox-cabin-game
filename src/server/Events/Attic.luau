--!strict
-- The Attic (a red card; it only goes into the deck once the Bathroom is built). The hatch in the
-- Bathroom ceiling drops open and a folding ladder comes down. Up there: a low, dusty attic of
-- trunks and sheeted furniture, and a ledger. Reading the ledger writes one true clue into the
-- Journal and ends the search. Nobody can be eliminated; when time runs out everyone just goes back
-- to the table.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClueData = require(Shared:WaitForChild("ClueData"))
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))

local Journal = require(script.Parent.Parent.Journal)
local MapGrid = require(script.Parent.Parent.MapGrid)
local Secrets = require(script.Parent.Parent.Secrets)
local EventKit = require(script.Parent.EventKit)

type EventRun = Types.EventRun

local DUST = Color3.fromRGB(70, 60, 50)
local RAFTER = Color3.fromRGB(46, 34, 26)
local SHEET = Color3.fromRGB(190, 184, 170)

local Attic = {
	noPenalty = true,
}

local function hatchOf(): (BasePart?, Model?)
	for _, cell in MapGrid.all() do
		if cell.id == "bathroom" and cell.model then
			local hatch = cell.model:FindFirstChild("Hatch", true)
			if hatch and hatch:IsA("BasePart") then
				return hatch, cell.model
			end
		end
	end
	return nil, nil
end

local function part(folder: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = EventKit.part(name, size, cf, color, folder)
	p.Material = material or Enum.Material.Wood
	return p
end

-- The attic itself, on top of the Bathroom's roof: plank floor, a gabled roof of rafters, one
-- dim bulb, trunks, crates and furniture under sheets, and the ledger on a crate.
local function buildAttic(folder: Instance, centre: Vector3, half: number): BasePart
	part(folder, "AtticFloor", Vector3.new(half * 2, 0.6, half * 2), CFrame.new(centre - Vector3.new(0, 0.3, 0)), DUST, Enum.Material.WoodPlanks)
	local ridge = 9
	local slope = math.sqrt(half * half + ridge * ridge)
	local angle = math.atan2(ridge, half)
	for _, side in { -1, 1 } do
		local cf = CFrame.new(centre + Vector3.new(side * half / 2, ridge / 2, 0)) * CFrame.Angles(0, 0, side * -angle)
		part(folder, "AtticRoof", Vector3.new(slope, 0.6, half * 2), cf, RAFTER, Enum.Material.WoodPlanks)
		for z = -half + 2, half - 2, 4 do
			part(folder, "Rafter", Vector3.new(slope, 0.5, 0.5), cf * CFrame.new(0, -0.5, z), Color3.fromRGB(36, 26, 20))
		end
	end
	-- Gable ends: two wedges each, tall side at the ridge.
	for _, z in { -half, half } do
		for _, side in { -1, 1 } do
			local at = centre + Vector3.new(side * half / 2, ridge / 2, z)
			local gable = Instance.new("WedgePart")
			gable.Name = "Gable"
			gable.Size = Vector3.new(0.6, ridge, half)
			gable.CFrame = CFrame.lookAt(at, at + Vector3.new(-side, 0, 0))
			gable.Color = RAFTER
			gable.Material = Enum.Material.WoodPlanks
			gable.Anchored = true
			gable.Parent = folder
		end
	end
	local bulb = part(folder, "AtticBulb", Vector3.new(0.5, 0.5, 0.5), CFrame.new(centre + Vector3.new(0, ridge - 2.5, 0)), Color3.fromRGB(255, 200, 140), Enum.Material.Neon)
	bulb.Shape = Enum.PartType.Ball
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 190, 130)
	light.Range = 26
	light.Brightness = 0.9
	light.Shadows = true
	light.Parent = bulb

	-- Clutter.
	local rng = Random.new()
	for i = 1, 6 do
		local at = centre + Vector3.new(rng:NextNumber(-half + 2.5, half - 2.5) * (if i % 2 == 0 then 1 else 0.6), 0, rng:NextNumber(-half + 2.5, half - 2.5))
		if (at - centre).Magnitude > 4 then
			local s = rng:NextNumber(1.8, 3)
			part(folder, "Crate", Vector3.new(s, s, s), CFrame.new(at + Vector3.new(0, s / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), Color3.fromRGB(100, 78, 52), Enum.Material.WoodPlanks)
		end
	end
	for _, x in { -half + 3, half - 3 } do
		part(folder, "Sheeted", Vector3.new(3, 4, 4), CFrame.new(centre + Vector3.new(x, 2, half - 4)), SHEET, Enum.Material.Fabric)
	end
	part(folder, "Trunk", Vector3.new(4, 2.2, 2.4), CFrame.new(centre + Vector3.new(-half + 3, 1.1, -half + 3)), Color3.fromRGB(80, 54, 34))

	-- The ledger, open on a crate at the far end.
	local stand = part(folder, "LedgerCrate", Vector3.new(2.6, 2.6, 2.6), CFrame.new(centre + Vector3.new(half - 3.5, 1.3, -half + 3.5)), Color3.fromRGB(100, 78, 52), Enum.Material.WoodPlanks)
	local ledger = part(folder, "Ledger", Vector3.new(1.6, 0.25, 1.2), stand.CFrame * CFrame.new(0, 1.42, 0) * CFrame.Angles(0, 0.4, 0), Color3.fromRGB(70, 24, 22), Enum.Material.Fabric)
	part(folder, "LedgerPages", Vector3.new(1.5, 0.05, 1.1), ledger.CFrame * CFrame.new(0, 0.15, 0), Color3.fromRGB(214, 200, 168), Enum.Material.Fabric)
	local candle = part(folder, "Candle", Vector3.new(0.3, 0.8, 0.3), stand.CFrame * CFrame.new(-0.9, 1.7, 0.8), Color3.fromRGB(220, 210, 190))
	local flame = Instance.new("PointLight")
	flame.Color = Color3.fromRGB(255, 170, 90)
	flame.Range = 8
	flame.Brightness = 0.8
	flame.Parent = candle

	return ledger
end

-- The one true clue the ledger names, at random from the true exit's three.
local function ledgerClue(): string?
	local exit = Secrets.trueExit()
	if not exit then
		return nil
	end
	return exit.clues[EventKit.rng:NextInteger(1, #exit.clues)]
end

function Attic.start(run: EventRun)
	local folder = EventKit.folder(run, "AtticEvent")
	local hatch, bathroom = hatchOf()
	if not hatch or not bathroom then
		EventKit.notifyAll(run, "Nothing up there but dust.")
		run.complete()
		return
	end
	local floorTop = bathroom:GetPivot().Position
	local top = Config.Room.WallHeight
	local under = Vector3.new(hatch.Position.X, floorTop.Y, hatch.Position.Z)

	-- The hatch swings down and a ladder unfolds to the floor.
	hatch.Transparency = 1
	run.data.hatch = hatch
	local flap = part(folder, "HatchFlap", Vector3.new(hatch.Size.X, 0.15, hatch.Size.Z), hatch.CFrame * CFrame.new(0, -hatch.Size.Z / 2, -hatch.Size.Z / 2) * CFrame.Angles(math.rad(90), 0, 0) * CFrame.new(0, hatch.Size.Z / 2, 0), Color3.fromRGB(46, 34, 26), Enum.Material.WoodPlanks)
	flap.CanCollide = false
	EventKit.sound("creak", flap, 0.9)
	local ladderLength = math.sqrt(top * top + 4 * 4)
	local ladderTilt = math.atan2(4, top)
	local ladderCf = CFrame.new(under + Vector3.new(0, top / 2, 2)) * CFrame.Angles(-ladderTilt, 0, 0)
	for _, x in { -1.1, 1.1 } do
		part(folder, "LadderRail", Vector3.new(0.3, ladderLength, 0.3), ladderCf * CFrame.new(x, 0, 0), Color3.fromRGB(110, 86, 58)).CanCollide = false
	end
	for y = -ladderLength / 2 + 1, ladderLength / 2 - 1, 1.4 do
		part(folder, "Rung", Vector3.new(2.2, 0.2, 0.3), ladderCf * CFrame.new(0, y, 0), Color3.fromRGB(110, 86, 58)).CanCollide = false
	end
	local foot = part(folder, "LadderFoot", Vector3.new(2.6, 2, 1), CFrame.new(under + Vector3.new(0, 1, 4)), Color3.new(), Enum.Material.Wood)
	foot.Transparency = 1
	foot.CanCollide = false

	-- The attic sits on the Bathroom's roof.
	local atticCentre = Vector3.new(floorTop.X, floorTop.Y + top + 1.9, floorTop.Z)
	local ledger = buildAttic(folder, atticCentre, 10)
	local hole = part(folder, "AtticHatch", Vector3.new(3, 0.1, 3), CFrame.new(Vector3.new(under.X, atticCentre.Y + 0.02, under.Z)), Color3.fromRGB(10, 8, 6))
	hole.CanCollide = false

	local up = EventKit.prompt(foot, "Climb up", "Attic ladder")
	up.Triggered:Connect(function(player: Player)
		if run.isActive(player) then
			EventKit.teleport(player, CFrame.new(Vector3.new(under.X + 2.5, atticCentre.Y + 3, under.Z)))
		end
	end)
	local down = EventKit.prompt(hole, "Climb down", "Hatch")
	down.Triggered:Connect(function(player: Player)
		if run.isActive(player) then
			EventKit.teleport(player, CFrame.new(under + Vector3.new(0, 3, 6)))
		end
	end)

	local read = EventKit.prompt(ledger, "Read", "Ledger")
	read.Triggered:Connect(function(player: Player)
		if not run.isActive(player) or run.data.read then
			return
		end
		run.data.read = true
		read.Enabled = false
		local result = ledgerClue()
		if result then
			local name = ClueData.Results[result] or result
			Journal.record(player, "ledger", { clue = result, label = `Ledger: {name}`, room = "Attic" })
			EventKit.notifyAll(run, `The last line in the ledger, in fresh ink: "{name}." It's true. It's in the Journal.`)
		end
		task.delay(4, function()
			if not run.over then
				run.complete()
			end
		end)
	end)

	EventKit.notifyAll(run, "A hatch drops open in the Bathroom ceiling. Search the attic. Nothing up there can hurt you... yet.")
end

function Attic.onTimeout(run: EventRun): { Player }
	EventKit.notifyAll(run, "The ladder folds itself back up. Back to the table.")
	return {}
end

function Attic.cleanup(run: EventRun)
	local hatch = run.data.hatch :: BasePart?
	if hatch then
		hatch.Transparency = 0
	end
	EventKit.cleanup(run)
end

return Attic
