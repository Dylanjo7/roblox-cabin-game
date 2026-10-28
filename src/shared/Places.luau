--!strict
-- The experience's two places: the lobby (the start place, the ranger station) and the cabin.
-- Config.Places wins when it's filled in; otherwise each one finds the other by asking Roblox
-- which places this experience has (the other place is whichever isn't this one). So publishing
-- the cabin as the experience's second place is enough. Server only.

local AssetService = game:GetService("AssetService")

local Config = require(script.Parent.Config)

local Places = {}

local other: number? = nil

-- The experience's other place (the cabin from the lobby, the lobby from the cabin), or 0 if
-- there isn't one (not published yet, or Studio).
function Places.other(): number
	if other then
		return other
	end
	local ok, pages = pcall(function()
		return AssetService:GetGamePlacesAsync()
	end)
	if not ok or not pages then
		return 0
	end
	while true do
		for _, place in pages:GetCurrentPage() do
			if place.PlaceId ~= game.PlaceId then
				other = place.PlaceId
				return place.PlaceId
			end
		end
		if pages.IsFinished then
			return 0
		end
		local more = pcall(function()
			pages:AdvanceToNextPageAsync()
		end)
		if not more then
			return 0
		end
	end
end

-- Where the lobby's trucks go.
function Places.cabin(): number
	return if Config.Places.GamePlaceId ~= 0 then Config.Places.GamePlaceId else Places.other()
end

-- Where players go back to after a run.
function Places.lobby(): number
	return if Config.Places.LobbyPlaceId ~= 0 then Config.Places.LobbyPlaceId else Places.other()
end

return Places
