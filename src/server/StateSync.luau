--!strict
-- Builds the public state snapshot from registered providers and pushes it to clients.
-- Only public information is registered here (never the deck, other hands, the exit or clues).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local StateSync = {}

local providers: { [string]: () -> any } = {}

function StateSync.register(key: string, provider: () -> any)
	providers[key] = provider
end

function StateSync.snapshot(): { [string]: any }
	local state = {}
	for key, provider in providers do
		state[key] = provider()
	end
	return state
end

function StateSync.broadcast()
	Remotes.event("PublicState"):FireAllClients(StateSync.snapshot())
end

function StateSync.init()
	Remotes.func("GetPublicState").OnServerInvoke = function()
		return StateSync.snapshot()
	end
end

return StateSync
