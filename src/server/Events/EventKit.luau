--!strict
-- Shared helpers for event modules: placeholder parts, prompts, picking rooms and spots in them,
-- and working out which room a player is standing in.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local RoomShapes = require(Shared:WaitForChild("RoomShapes"))
local Types = require(Shared:WaitForChild("Types"))

local MapGrid = require(script.Parent.Parent.MapGrid)
local Spots = require(script.Parent.Parent.Spots)
local StateSync = require(script.Parent.Parent.StateSync)

type Cell = MapGrid.Cell
type EventRun = Types.EventRun

local EventKit = {}

EventKit.rng = Random.new()

function EventKit.part(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function EventKit.prompt(parent: BasePart, action: string, object: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = Config.Events.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

-- A label that floats above a part and shows through walls, so marked spots can be found.
function EventKit.marker(adornee: BasePart, text: string, color: Color3): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Adornee = adornee
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(140, 28)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.MaxDistance = 400
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(18, 20, 18)
	label.BackgroundTransparency = 0.3
	label.TextColor3 = color
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.Text = text
	label.Parent = gui
	gui.Parent = adornee
	return label
end

-- A workspace folder for this event's parts; cleanup() destroys it.
function EventKit.folder(run: EventRun, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = workspace
	run.data.folder = folder
	return folder
end

function EventKit.cleanup(run: EventRun)
	if run.data.folder then
		run.data.folder:Destroy()
		run.data.folder = nil
	end
end

-- Built rooms, leaving out any card ids in `exclude`.
function EventKit.rooms(exclude: { [string]: boolean }): { Cell }
	local list = {}
	for _, cell in MapGrid.all() do
		if not exclude[cell.id] then
			table.insert(list, cell)
		end
	end
	return list
end

-- Up to n different items from the list, in random order.
function EventKit.pick<T>(list: { T }, n: number): { T }
	local pool = table.clone(list)
	local out = {}
	for _ = 1, math.min(n, #pool) do
		table.insert(out, table.remove(pool, EventKit.rng:NextInteger(1, #pool)))
	end
	return out
end

-- A clear point on the floor of a room, for an item or a person: nothing over it (no table,
-- bed or shelf) and nothing beside it at standing height (see Spots).
function EventKit.clearSpot(cell: Cell, clearance: number?): Vector3
	return Spots.clear(cell, EventKit.rng, clearance)
end

-- A random point on the floor of a room, away from the walls (furniture may be there: fine for
-- someone walking through, not for something to find; use clearSpot for that).
function EventKit.spotIn(cell: Cell): Vector3
	local spread = Config.Events.ItemSpread
	local hx, hz = MapGrid.halfSize(cell)
	local sx, sz = math.min(spread, hx - 3), math.min(spread, hz - 3)
	local rng = EventKit.rng
	return RoomShapes.cellPosition(cell.x, cell.z) + Vector3.new(rng:NextNumber(-sx, sx), 0, rng:NextNumber(-sz, sz))
end

-- The map cell the player is standing in, or nil if they have no character.
function EventKit.cellOf(player: Player): (number?, number?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil, nil
	end
	return RoomShapes.cellAt(root.Position)
end

function EventKit.root(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Move a player's character so its root sits at this CFrame.
function EventKit.teleport(player: Player, cf: CFrame)
	local character = player.Character
	if character then
		character:PivotTo(cf)
	end
end

-- Play a Config.Sounds sound from a part, heard by everyone nearby.
function EventKit.sound(name: string, at: BasePart, volume: number?)
	local sound = Instance.new("Sound")
	sound.SoundId = Config.Sounds[name] or ""
	sound.Volume = volume or 0.6
	sound.RollOffMaxDistance = 160
	sound.Parent = at
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

-- Just inside the cabin's front door (Parlor south wall), floor level, facing into the Parlor.
function EventKit.frontDoor(): CFrame
	return RoomShapes.frontDoorInside()
end

-- A room model's doorway parts (named N/E/S/W in the model's own frame).
function EventKit.doorways(room: Model): { BasePart }
	local out = {}
	for _, child in room:GetChildren() do
		if child:IsA("BasePart") and #child.Name == 1 and string.find("NESW", child.Name, 1, true) then
			table.insert(out, child)
		end
	end
	return out
end

-- A line of live status on the event banner, under the countdown ("1/3 mirrors covered");
-- alert shows it big in red. Sent to everyone straight away.
function EventKit.setDetail(run: EventRun, text: string?, alert: boolean?)
	run.data.detail = text
	run.data.alert = alert == true
	StateSync.broadcast()
end

function EventKit.notifyAll(run: EventRun, text: string)
	for _, player in run.players do
		Remotes.notify(player, text)
	end
end

-- Group tasks: everyone still in play fails.
function EventKit.everyoneActive(run: EventRun): { Player }
	local out = {}
	for _, player in run.players do
		if run.isActive(player) then
			table.insert(out, player)
		end
	end
	return out
end

return EventKit
