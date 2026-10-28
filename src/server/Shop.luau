--!strict
-- Robux items in the cabin (Config.Shop), bought from the Journal's last page. All cosmetic or
-- pranks:
--   Lantern Colours (game pass): pick your lantern's flame (player attribute LanternColour;
--     whether you own it is the attribute OwnsLanternColours).
--   Scare a Friend (developer product): pick someone in the server; once the purchase goes
--     through, the Hollow Man's face fills their screen, and a moment later they're told who.
--   Light a Candle (developer product): bought at the ranger station; if its receipt ends up
--     here instead, it's simply thanked for.
-- This module is the place's only MarketplaceService.ProcessReceipt.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local shop = Config.Shop
local Shop = {}

local scareTargets: { [Player]: Player } = {} -- who each buyer picked
local granted: { [string]: boolean } = {} -- purchase ids already handled this session

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

local function onSetLanternColour(player: Player, colourId: any)
	if typeof(colourId) ~= "string" then
		return
	end
	for _, option in shop.LanternColours do
		if option.id == colourId then
			if option.free or player:GetAttribute("OwnsLanternColours") == true then
				player:SetAttribute("LanternColour", colourId)
			else
				Remotes.notify(player, "That flame needs the Lantern Colours pass.")
			end
			return
		end
	end
end

local function onRequestScare(player: Player, userId: any)
	if typeof(userId) ~= "number" or userId == player.UserId then
		return
	end
	local target = Players:GetPlayerByUserId(userId)
	if not target then
		Remotes.notify(player, "They're not here any more.")
		return
	end
	if shop.ScareProduct == 0 then
		Remotes.notify(player, "Scares aren't set up yet (Config.Shop.ScareProduct).")
		return
	end
	scareTargets[player] = target
	MarketplaceService:PromptProductPurchase(player, shop.ScareProduct)
end

-- Someone to scare for this buyer: who they picked if they're still here, else anyone else.
local function scareTargetFor(buyer: Player): Player?
	local picked = scareTargets[buyer]
	if picked and picked.Parent == Players then
		return picked
	end
	for _, p in Players:GetPlayers() do
		if p ~= buyer then
			return p
		end
	end
	return nil
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local purchaseId = tostring(receipt.PurchaseId)
	if granted[purchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local buyer = Players:GetPlayerByUserId(receipt.PlayerId)
	if not buyer then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- they left; Roblox tries again when they're back
	end

	if receipt.ProductId == shop.ScareProduct and shop.ScareProduct ~= 0 then
		local target = scareTargetFor(buyer)
		if not target then
			-- Nobody to scare right now. Keep it for the next server they're in with someone.
			Remotes.notify(buyer, "There's nobody here to scare. It'll happen the next time you're with someone.")
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		scareTargets[buyer] = nil
		Remotes.event("Scare"):FireClient(target, "face", buyer.DisplayName)
		Remotes.notify(buyer, `Done. {target.DisplayName} won't forget that.`)
	elseif receipt.ProductId == shop.OfferingProduct and shop.OfferingProduct ~= 0 then
		Remotes.notify(buyer, "Thank you. A candle burns for you at the ranger station.")
	else
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	granted[purchaseId] = true
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function Shop.init()
	for _, player in Players:GetPlayers() do
		task.spawn(checkPass, player)
	end
	Players.PlayerAdded:Connect(checkPass)
	Players.PlayerRemoving:Connect(function(player: Player)
		scareTargets[player] = nil
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		if purchased and passId == shop.LanternColoursPass then
			player:SetAttribute("OwnsLanternColours", true)
			Remotes.notify(player, "Your lantern can burn in other colours now. Pick one in the back of the Journal.")
		end
	end)
	MarketplaceService.ProcessReceipt = processReceipt
	Remotes.event("SetLanternColour").OnServerEvent:Connect(onSetLanternColour)
	Remotes.event("RequestScare").OnServerEvent:Connect(onRequestScare)
end

return Shop
