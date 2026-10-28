--!strict
-- The cabin map in the centre of the Parlor table: a tile for every built room, kept in step with
-- MapGrid and zoomed to fit the cabin (MapView). Everyone sees it; it only shows public information.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapTiles = require(Shared:WaitForChild("MapTiles"))
local MapView = require(Shared:WaitForChild("MapView"))

local MapGrid = require(script.Parent.MapGrid)

local TableMap = {}

local folder: Folder

local function rebuild()
	folder:ClearAllChildren()
	local cells = MapGrid.all()
	local view = MapView.compute(cells)
	for _, cell in cells do
		MapTiles.make(view, cell.id, cell.x, cell.z, cell.rotation, folder)
	end
end

function TableMap.init()
	folder = Instance.new("Folder")
	folder.Name = "CabinMap"
	folder.Parent = workspace
	MapGrid.Changed:Connect(rebuild)
	rebuild()
end

return TableMap
