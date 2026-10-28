--!strict
-- The supplies at the ranger station's front desk (Config.Shop): a "Browse supplies" prompt on
-- the desk opens the panel (lobby client ShopUI), where you can buy the Lantern Colours pass
-- (your flame colour in the cabin) or light a candle on the memorial shelf for those who didn't
-- come back, with your name beside it. This module is the lobby's MarketplaceService.ProcessReceipt.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Station = require(script.Parent.Station)

local shop = Config.Shop
local LobbyShop = {}

local candles: { BasePart } = {}
local nextCandle = 1
local granted: { [string]: boolean } = {}

local function notify(player: Player, text: string)
	local remote = ReplicatedStorage:FindFirstChild("LobbyNotify")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireClient(player, text)
	end
end

local function checkPass(player: Player)
	if shop.LanternColoursPass == 0 then
		return
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, shop.LanternColoursPass)
	end)
	if ok and owns then
		player:SetAttribute("OwnsLanternColours", true)
	end
end

-- Light the next candle on the shelf with this name (the oldest is relit once they all burn).
local function lightCandle(name: string)
	local candle = candles[nextCandle]
	if not candle then
		return
	end
	nextCandle = nextCandle % #candles + 1
	local old = candle:FindFirstChild("Lit")
	if old then
		old:Destroy()
	end
	local lit = Instance.new("Folder")
	lit.Name = "Lit"
	lit.Parent = candle
	local flame = Instance.new("Part")
	flame.Name = "Flame"
	flame.Shape = Enum.PartType.Ball
	flame.Size = Vector3.new(0.22, 0.22, 0.22)
	flame.CFrame = candle.CFrame * CFrame.new(0, candle.Size.Y / 2 + 0.15, 0)
	flame.Color = Color3.fromRGB(255, 180, 90)
	flame.Material = Enum.Material.Neon
	flame.Anchored = true
	flame.CanCollide = false
	flame.Parent = lit
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 180, 100)
	glow.Range = 7
	glow.Brightness = 1
	glow.Parent = flame
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(140, 24)
	tag.StudsOffset = Vector3.new(0, 0.8, 0)
	tag.MaxDistance = 24
	tag.Parent = flame
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = `for {name}`
	label.TextColor3 = Color3.fromRGB(230, 214, 180)
	label.TextStrokeTransparency = 0.4
	label.Font = Enum.Font.Fondamento
	label.TextSize = 14
	label.Parent = tag
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local purchaseId = tostring(receipt.PurchaseId)
	if granted[purchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local buyer = Players:GetPlayerByUserId(receipt.PlayerId)
	if not buyer then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if receipt.ProductId == shop.OfferingProduct and shop.OfferingProduct ~= 0 then
		lightCandle(buyer.DisplayName)
		for _, p in Players:GetPlayers() do
			notify(p, `{buyer.DisplayName} lit a candle for those who didn't come back.`)
		end
		granted[purchaseId] = true
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	-- Anything else (a scare) is for the cabin; Roblox hands it to the next server they're in.
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function LobbyShop.init(built: Station.Built)
	candles = built.candles
	local open = Instance.new("RemoteEvent")
	open.Name = "LobbyShopOpen"
	open.Parent = ReplicatedStorage

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Browse supplies"
	prompt.ObjectText = "Front desk"
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player: Player)
		open:FireClient(player)
	end)
	prompt.Parent = built.counter

	for _, player in Players:GetPlayers() do
		task.spawn(checkPass, player)
	end
	Players.PlayerAdded:Connect(checkPass)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		if purchased and passId == shop.LanternColoursPass then
			player:SetAttribute("OwnsLanternColours", true)
			notify(player, "Your lantern will burn in other colours up at the cabin. Pick one in the back of the Journal.")
		end
	end)
	MarketplaceService.ProcessReceipt = processReceipt
end

return LobbyShop
