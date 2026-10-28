--!strict
-- The supplies panel at the ranger station's front desk (opened by the desk's prompt): the
-- Lantern Colours pass and lighting a memorial candle (Config.Shop). Purchases are Roblox's own
-- prompts; the server grants them.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local INK = Color3.fromRGB(232, 220, 192)
local FADED = Color3.fromRGB(150, 136, 112)
local BRASS = Color3.fromRGB(176, 140, 72)
local WOOD = Color3.fromRGB(46, 32, 22)

local ShopUI = {}

local localPlayer = Players.LocalPlayer
local panel: Frame
local passButton: TextButton
local candleButton: TextButton
local prices: { [string]: number } = {}

local function text(parent: Instance, value: string, size: number, font: Enum.Font, color: Color3, y: number, height: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Position = UDim2.fromOffset(18, y)
	l.Size = UDim2.new(1, -36, 0, height)
	l.BackgroundTransparency = 1
	l.Text = value
	l.TextSize = size
	l.Font = font
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.6
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.RichText = true
	l.Parent = parent
	return l
end

local function button(parent: Instance, label: string, y: number, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 0)
	b.Position = UDim2.new(1, -18, 0, y)
	b.Size = UDim2.fromOffset(150, 32)
	b.BackgroundColor3 = WOOD
	b.TextColor3 = INK
	b.Font = Enum.Font.Fondamento
	b.TextSize = 17
	b.Text = label
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 3)
	corner.Parent = b
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = BRASS
	edge.Transparency = 0.45
	edge.Parent = b
	b.Activated:Connect(onClick)
	b.Parent = parent
	return b
end

local function refresh()
	local shop = Config.Shop
	if shop.LanternColoursPass == 0 then
		passButton.Text = "Not set up yet"
	elseif localPlayer:GetAttribute("OwnsLanternColours") == true then
		passButton.Text = "Owned"
	else
		passButton.Text = if prices.pass then `Buy  ·  R$ {prices.pass}` else "Buy"
	end
	if shop.OfferingProduct == 0 then
		candleButton.Text = "Not set up yet"
	else
		candleButton.Text = if prices.candle then `Light  ·  R$ {prices.candle}` else "Light"
	end
end

function ShopUI.init(screen: ScreenGui)
	local shop = Config.Shop
	panel = Instance.new("Frame")
	panel.Name = "Supplies"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(520, 300)
	panel.BackgroundColor3 = Color3.fromRGB(14, 11, 9)
	panel.BackgroundTransparency = 0.12
	panel.Visible = false
	panel.Parent = screen
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = panel
	local edge = Instance.new("UIStroke")
	edge.Color = BRASS
	edge.Transparency = 0.6
	edge.Parent = panel

	text(panel, "<b>Supplies</b>", 28, Enum.Font.Fondamento, INK, 12, 34)
	text(panel, "<i>The ranger keeps a few things behind the desk. None of them will get you out.</i>", 14, Enum.Font.Fondamento, FADED, 46, 22)

	text(panel, "<b>Lantern Colours</b>", 19, Enum.Font.Fondamento, INK, 84, 24)
	text(panel, "Up at the cabin, your lantern can burn Witchfire green, Cold Light blue or Blood Moon red. (Game pass)", 14, Enum.Font.Fondamento, FADED, 108, 40)
	passButton = button(panel, "Buy", 92, function()
		if shop.LanternColoursPass ~= 0 and localPlayer:GetAttribute("OwnsLanternColours") ~= true then
			MarketplaceService:PromptGamePassPurchase(localPlayer, shop.LanternColoursPass)
		end
	end)

	text(panel, "<b>Light a Candle</b>", 19, Enum.Font.Fondamento, INK, 160, 24)
	text(panel, "A candle on the memorial shelf, with your name beside it, for everyone in the station to see.", 14, Enum.Font.Fondamento, FADED, 184, 40)
	candleButton = button(panel, "Light", 168, function()
		if shop.OfferingProduct ~= 0 then
			MarketplaceService:PromptProductPurchase(localPlayer, shop.OfferingProduct)
		end
	end)

	local close = button(panel, "Leave", 252, function()
		panel.Visible = false
	end)
	close.Size = UDim2.fromOffset(110, 32)

	-- Keep the descriptions clear of the buttons.
	for _, child in panel:GetChildren() do
		if child:IsA("TextLabel") and child.Position.Y.Offset >= 84 then
			child.Size = UDim2.new(1, -200, 0, child.Size.Y.Offset)
		end
	end

	task.spawn(function()
		local remote = ReplicatedStorage:WaitForChild("LobbyShopOpen") :: RemoteEvent
		remote.OnClientEvent:Connect(function()
			refresh()
			panel.Visible = true
		end)
	end)
	localPlayer:GetAttributeChangedSignal("OwnsLanternColours"):Connect(refresh)

	task.spawn(function()
		local function price(key: string, id: number, kind: Enum.InfoType)
			if id == 0 then
				return
			end
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(id, kind)
			end)
			if ok and typeof(info) == "table" and typeof(info.PriceInRobux) == "number" then
				prices[key] = info.PriceInRobux
			end
		end
		price("pass", shop.LanternColoursPass, Enum.InfoType.GamePass)
		price("candle", shop.OfferingProduct, Enum.InfoType.Product)
		refresh()
	end)
	refresh()
end

return ShopUI
