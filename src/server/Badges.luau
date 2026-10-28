--!strict
-- Hands out the badges in Config.Badges (an id of 0 turns a badge off): FirstNight when you
-- sit down for your first run, Escaped when you get out, AllOut when the whole group does, and
-- Caught when a run ends with him winning.

local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Badges = {}

function Badges.award(player: Player, key: string)
	local id = Config.Badges[key]
	if not id or id == 0 then
		return
	end
	task.spawn(function()
		local ok, has = pcall(function()
			return BadgeService:UserHasBadgeAsync(player.UserId, id)
		end)
		if ok and not has then
			pcall(function()
				BadgeService:AwardBadge(player.UserId, id)
			end)
		end
	end)
end

function Badges.awardAll(players: { Player }, key: string)
	for _, player in players do
		Badges.award(player, key)
	end
end

return Badges
