--!strict
-- See the cabin in Studio's edit window, and decorate it. Everything in the game is built by
-- scripts when it starts, so in edit mode the world is empty. Run these in the Command Bar
-- (View > Command Bar):
--
--   require(game.ServerScriptService.Server.Preview).build()
--     The Parlor and its table, the porch, path and truck, the pines, and every room card laid
--     out in rows north and south of the Parlor (each labelled). Fly round with the camera.
--
--   require(game.ServerScriptService.Server.Preview).save()
--     Saves your decorations. Rooms are built somewhere different every run, so things you add
--     are saved relative to the room they're in and appear in that room wherever it's built.
--     Put new things in Workspace.Custom (make a Folder called Custom) or in a room's "Decor"
--     folder; anchor them. Each room's saved set is replaced by what's in it when you save.
--     Saved decorations live in ServerStorage.RoomDecor; they show up in the preview too.
--
--   require(game.ServerScriptService.Server.Preview).clear()
--     Removes the preview (save first). It's also removed automatically when the game starts,
--     so saving the place with it showing does no harm.
--
-- Anything else you put straight into Workspace stays where you put it in every run: fine for
-- things outside the cabin's build area, but the rooms are built in different places each run.
-- (The lobby: require(game.ServerScriptService.Lobby.Station).build() in the lobby place; it's
-- replaced by the real one when that starts.)

local ServerStorage = game:GetService("ServerStorage")

local Preview = {}

local ATTRIBUTE = "EditPreview"

local function mark(inst: Instance?)
	if inst then
		inst:SetAttribute(ATTRIBUTE, true)
	end
end

-- Remove the preview (and anything else marked as part of it).
function Preview.clear()
	for _, container in { workspace, ServerStorage } do
		for _, child in (container :: Instance):GetChildren() do
			if child:GetAttribute(ATTRIBUTE) then
				child:Destroy()
			end
		end
	end
end

-- Label a preview room with its name, and remember which room card it is.
local function label(model: Model, id: string, name: string, x: number, z: number)
	model:SetAttribute("RoomId", id)
	model:SetAttribute("CellX", x)
	model:SetAttribute("CellZ", z)
	local anchor = Instance.new("Part")
	anchor.Name = "PreviewLabel"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CFrame = model:GetPivot() * CFrame.new(0, 24, 0)
	anchor.Parent = model
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 40)
	gui.AlwaysOnTop = true
	gui.Parent = anchor
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 0.4
	text.BackgroundColor3 = Color3.new(0, 0, 0)
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextSize = 18
	text.Text = name
	text.Parent = gui
end

-- (Runs inside a fresh copy of the server modules; see build.)
function Preview.buildNow(gallery: boolean)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local CardData = require(Shared:WaitForChild("CardData"))
	local Forest = require(script.Parent.Forest)
	local MapGrid = require(script.Parent.MapGrid)
	local Outside = require(script.Parent.Outside)
	local RoomPlacement = require(script.Parent.RoomPlacement)
	local Table = require(script.Parent.Table)

	Table.build()
	Forest.init()
	MapGrid.clear()
	label(RoomPlacement.place("parlor", 0, 0, 0), "parlor", "Parlor", 0, 0)
	local outside = Outside.build()
	Forest.setClearing({ [MapGrid.key(0, 1)] = true, [MapGrid.key(0, 2)] = true })
	mark(outside)

	if gallery then
		-- Every other cell, so rooms don't open into each other (their doorways stay sealed).
		local spots = {}
		for _, z in { -2, -4, -6, 4, 6 } do
			for x = -6, 6, 2 do
				table.insert(spots, { x, z })
			end
		end
		local i = 0
		for _, def in CardData.all() do
			if def.type == "Room" and def.id ~= "parlor" then
				i += 1
				local spot = spots[i]
				if spot then
					label(RoomPlacement.place(def.id, spot[1], spot[2], 0), def.id, def.name, spot[1], spot[2])
				end
			end
		end
	end

	mark(workspace:FindFirstChild("ParlorTable"))
	mark(workspace:FindFirstChild("Cabin"))
	mark(workspace:FindFirstChild("Forest"))
	mark(ServerStorage:FindFirstChild("RoomTemplates"))
end

-- Build the preview. gallery = false shows just the Parlor and the outside.
function Preview.build(gallery: boolean?)
	Preview.clear()
	-- Build from a fresh copy of the server modules: it always uses the code Rojo last synced,
	-- and nothing is left over from an earlier preview.
	local fresh = (script.Parent :: Instance):Clone()
	fresh.Name = "PreviewModules"
	fresh.Parent = ServerStorage
	local ok, err = pcall(function()
		local module = fresh:FindFirstChild("Preview") :: ModuleScript
		local copy = require(module) :: any
		copy.buildNow(gallery ~= false)
	end)
	fresh:Destroy()
	if not ok then
		error(err, 0)
	end
	print("Hollow Pines preview built. Decorate, then run .save(); .clear() removes it.")
end

-- Which preview room this point is in.
local function roomAt(position: Vector3): Model?
	local cabin = workspace:FindFirstChild("Cabin")
	if not cabin then
		return nil
	end
	local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
	local offset = position - Config.ParlorOrigin
	local x = math.floor(offset.X / Config.TileSize + 0.5)
	local z = math.floor(offset.Z / Config.TileSize + 0.5)
	for _, model in cabin:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("CellX") == x and model:GetAttribute("CellZ") == z then
			return model
		end
	end
	return nil
end

-- Save what's in each preview room as that room's decorations.
function Preview.save()
	local cabin = workspace:FindFirstChild("Cabin")
	if not cabin or not cabin:GetAttribute(ATTRIBUTE) then
		warn("Build the preview first: require(game.ServerScriptService.Server.Preview).build()")
		return
	end
	local store = ServerStorage:FindFirstChild("RoomDecor")
	if not store then
		store = Instance.new("Folder")
		store.Name = "RoomDecor"
		store.Parent = ServerStorage
	end

	-- Things in Workspace.Custom go into the room they're standing in.
	local custom = workspace:FindFirstChild("Custom")
	local outside = 0
	if custom then
		for _, item in custom:GetChildren() do
			if item:IsA("PVInstance") then
				local room = roomAt(item:GetPivot().Position)
				if room then
					local decor = room:FindFirstChild("Decor")
					if not decor then
						decor = Instance.new("Folder")
						decor.Name = "Decor"
						decor.Parent = room
					end
					item.Parent = decor
				else
					outside += 1
				end
			end
		end
	end

	local saved = 0
	for _, model in cabin:GetChildren() do
		local id = model:GetAttribute("RoomId")
		if model:IsA("Model") and typeof(id) == "string" then
			local old = (store :: Instance):FindFirstChild(id)
			if old then
				old:Destroy()
			end
			local decor = model:FindFirstChild("Decor")
			if decor and #decor:GetChildren() > 0 then
				local folder = Instance.new("Folder")
				folder.Name = id
				folder.Parent = store
				local pivot = model:GetPivot()
				for _, item in decor:GetChildren() do
					if item:IsA("PVInstance") then
						local copy = item:Clone() :: PVInstance
						copy:PivotTo(pivot:Inverse() * item:GetPivot()) -- relative to the room
						copy.Parent = folder
						saved += 1
					end
				end
			end
		end
	end
	print(`Saved {saved} decoration(s) into ServerStorage.RoomDecor. They'll be in those rooms every run.`)
	if outside > 0 then
		warn(`{outside} thing(s) in Workspace.Custom aren't inside a room, so they stay where they are.`)
	end
end

return Preview
