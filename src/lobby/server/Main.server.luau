--!strict
-- Lobby place boot: builds the ranger station and runs the trucks (Config.Lobby.Trucks, each its
-- own lobby). Standing on a truck's pad puts you in its group (1 to Config.MaxPlayers). Each
-- truck has a difficulty (Config.Lobby.TruckDifficulty), shown on the sign by its pad; anyone on
-- the truck (or anyone, while it's empty) can change it there. The truck leaves when it's full,
-- or Config.Lobby.DepartSeconds after the first person gets on: the server reserves a private
-- server of the cabin place and teleports the group there together, with the party's UserIds
-- and the difficulty as teleport data (the cabin waits for all of them; see
-- src/server/Party.luau).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Places = require(Shared:WaitForChild("Places"))

local LobbyShop = require(script.Parent.LobbyShop)
local OldDriver = require(script.Parent.OldDriver)
local Station = require(script.Parent.Station)

type Queue = {
	index: number,
	truck: Station.Truck,
	difficulty: string, -- a key of Config.Difficulty.Levels
	members: { Player },
	departAt: number?, -- os.clock() when it leaves; nil while empty
	leaving: boolean, -- reserving / teleporting; nobody can get on or off
}

local notifyRemote = Instance.new("RemoteEvent")
notifyRemote.Name = "LobbyNotify"
notifyRemote.Parent = ReplicatedStorage

local function notify(player: Player, text: string)
	notifyRemote:FireClient(player, text)
end

-- Blue hour in the pines: a low haze, warm lamps, colour pulled down a little.
Lighting.ClockTime = Config.Lobby.ClockTime
Lighting.Brightness = 1.3
Lighting.Ambient = Color3.fromRGB(54, 52, 62)
Lighting.OutdoorAmbient = Color3.fromRGB(66, 64, 82)
local haze = Instance.new("Atmosphere")
haze.Density = 0.36
haze.Offset = 0.15
haze.Color = Color3.fromRGB(150, 150, 170)
haze.Decay = Color3.fromRGB(70, 74, 96)
haze.Glare = 0
haze.Haze = 1.8
haze.Parent = Lighting
local grade = Instance.new("ColorCorrectionEffect")
grade.Saturation = -0.15
grade.Contrast = 0.08
grade.TintColor = Color3.fromRGB(236, 238, 255)
grade.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.6
bloom.Size = 30
bloom.Threshold = 1.3
bloom.Parent = Lighting

-- An edit-mode preview of the station (see src/server/Preview.luau) is replaced by the real one.
local leftover = workspace:FindFirstChild("RangerStation")
if leftover then
	leftover:Destroy()
end
-- So is what a new place starts with: the grey Baseplate (it would cover the station's own
-- ground and flicker through its floor) and its SpawnLocation (the station has its own).
for _, inst in workspace:GetChildren() do
	if inst.Name == "Baseplate" or inst:IsA("SpawnLocation") then
		inst:Destroy()
	end
end
local built = Station.build()
LobbyShop.init(built)
OldDriver.init(built.driver)

-- Each truck's difficulty to start with (and after every departure).
local function truckDefault(index: number): string
	local id = Config.Lobby.TruckDifficulty[index]
	return if id and Config.Difficulty.Levels[id] then id else Config.Difficulty.Default
end

local queues: { Queue } = {}
for i, truck in built.trucks do
	table.insert(queues, { index = i, truck = truck, difficulty = truckDefault(i), members = {}, departAt = nil, leaving = false })
end

local SIGN_COLOURS: { [string]: Color3 } = {
	normal = Color3.fromRGB(226, 214, 180),
	hard = Color3.fromRGB(240, 160, 70),
	nightmare = Color3.fromRGB(220, 50, 40),
}

local teleporting: { [Player]: boolean } = {}
local retries: { [Player]: number } = {}
local warnedFull: { [Player]: boolean } = {}

-- Which pad (queue index) this player is standing on, if any.
local function padUnder(player: Player): number?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	for i, queue in queues do
		local pad = queue.truck.pad
		local rel = pad.CFrame:PointToObjectSpace(root.Position)
		if math.abs(rel.X) <= pad.Size.X / 2 and math.abs(rel.Z) <= pad.Size.Z / 2 and rel.Y > -2 and rel.Y < 8 then
			return i
		end
	end
	return nil
end

local function setBoard(queue: Queue)
	local n = #queue.members
	local max = Config.MaxPlayers
	local name = Config.Difficulty.Levels[queue.difficulty].name
	local text
	if queue.leaving then
		text = `TRUCK {queue.index} · {name}\nHeading up to the cabin...`
	elseif n == 0 then
		text = `TRUCK {queue.index} · {name}\nStand on the pad to ride · 0/{max}`
	else
		local left = math.max(0, math.ceil((queue.departAt or os.clock()) - os.clock()))
		text = `TRUCK {queue.index} · {name}\n{n}/{max} aboard · leaving in {left}s`
	end
	queue.truck.label.Text = text
end

local function setSign(queue: Queue)
	local level = Config.Difficulty.Levels[queue.difficulty]
	queue.truck.sign.Text = `<b>{string.upper(level.name)}</b>\n<font size="18">{level.blurb}</font>`
	queue.truck.sign.TextColor3 = SIGN_COLOURS[queue.difficulty] or SIGN_COLOURS.normal
end

local function reset(queue: Queue)
	for _, player in queue.members do
		teleporting[player] = nil
	end
	queue.members = {}
	queue.departAt = nil
	queue.leaving = false
	queue.difficulty = truckDefault(queue.index)
	setSign(queue)
	setBoard(queue)
end

-- The sign by the pad: the next difficulty along. Only someone on the truck can change it once
-- anyone is aboard.
for _, queue in queues do
	setSign(queue)
	queue.truck.signPrompt.Triggered:Connect(function(player: Player)
		if queue.leaving then
			return
		end
		if #queue.members > 0 and not table.find(queue.members, player) then
			notify(player, "Only someone on this truck can change how hard the night is.")
			return
		end
		local order = Config.Difficulty.Order
		local at = table.find(order, queue.difficulty) or 0
		queue.difficulty = order[at % #order + 1]
		setSign(queue)
		setBoard(queue)
		local level = Config.Difficulty.Levels[queue.difficulty]
		local told = if #queue.members > 0 then queue.members else { player }
		for _, p in told do
			notify(p, `Truck {queue.index} is now {level.name}. {level.blurb}`)
		end
	end)
end

local function depart(queue: Queue)
	queue.leaving = true
	setBoard(queue)
	local group = table.clone(queue.members)
	for _, player in group do
		teleporting[player] = true
	end

	local problem: string? = nil
	local placeId = 0
	if RunService:IsStudio() then
		problem = "Teleports don't work in Studio. Publish the experience and try it in a live server."
	else
		placeId = Places.cabin()
		if placeId == 0 then
			problem = "Couldn't find the cabin. Publish it as a second place in this experience."
		end
	end
	if problem then
		for _, player in group do
			notify(player, problem)
		end
		task.wait(3)
		reset(queue)
		return
	end

	local ok, codeOrErr = pcall(function()
		return TeleportService:ReserveServer(placeId)
	end)
	if not ok then
		warn(`Hollow Pines lobby: ReserveServer failed: {codeOrErr}`)
		for _, player in group do
			notify(player, "Couldn't reach the cabin. Try again in a moment.")
		end
		reset(queue)
		return
	end

	local party = {}
	local present = {}
	for _, player in group do
		if player.Parent == Players then
			table.insert(party, player.UserId)
			table.insert(present, player)
			retries[player] = 0
		end
	end
	if #present == 0 then
		reset(queue)
		return
	end
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = codeOrErr :: string
	options:SetTeleportData({ party = party, difficulty = queue.difficulty })
	for _, player in present do
		notify(player, "The truck pulls away down the dark road...")
	end
	local sent, err = pcall(function()
		TeleportService:TeleportAsync(placeId, present, options)
	end)
	if not sent then
		warn(`Hollow Pines lobby: TeleportAsync failed: {err}`)
		for _, player in present do
			notify(player, "The truck wouldn't start. Try again in a moment.")
		end
		reset(queue)
		return
	end
	-- Give the teleport time to take everyone, then free the truck for the next group.
	task.wait(15)
	reset(queue)
end

-- A teleport that started but failed for one player: try again, then give up and let them re-queue.
TeleportService.TeleportInitFailed:Connect(function(player: Player, result: Enum.TeleportResult, message: string, placeId: number, options: TeleportOptions?)
	local tries = retries[player] or 0
	if tries < Config.Lobby.TeleportRetries and options then
		retries[player] = tries + 1
		task.wait(2)
		local ok = pcall(function()
			TeleportService:TeleportAsync(placeId, { player }, options)
		end)
		if ok then
			return
		end
	end
	warn(`Hollow Pines lobby: teleport failed for {player.Name}: {result.Name} {message}`)
	teleporting[player] = nil
	notify(player, "You missed the truck. Get on the next one.")
end)

Players.PlayerRemoving:Connect(function(player: Player)
	teleporting[player] = nil
	retries[player] = nil
	warnedFull[player] = nil
end)

-- Keep each truck's group in step with who's standing on its pad.
while true do
	task.wait(0.25)
	local onPad: { [Player]: number } = {}
	for _, player in Players:GetPlayers() do
		if not teleporting[player] then
			local index = padUnder(player)
			if index then
				onPad[player] = index
			else
				warnedFull[player] = nil
			end
		end
	end
	for i, queue in queues do
		if not queue.leaving then
			-- Keep the order people got on in; drop anyone who stepped off or left.
			local members = {}
			for _, player in queue.members do
				if onPad[player] == i and player.Parent == Players then
					table.insert(members, player)
				end
			end
			for player, index in onPad do
				if index == i and not table.find(members, player) then
					if #members < Config.MaxPlayers then
						table.insert(members, player)
						notify(player, "You climb onto the truck. Step off to get down.")
					elseif not warnedFull[player] then
						warnedFull[player] = true
						notify(player, "This truck is full. Try the other one.")
					end
				end
			end
			queue.members = members
			if #members == 0 then
				queue.departAt = nil
			elseif not queue.departAt then
				queue.departAt = os.clock() + Config.Lobby.DepartSeconds
			end
			if #members > 0 and (#members >= Config.MaxPlayers or os.clock() >= (queue.departAt :: number)) then
				task.spawn(depart, queue)
			end
			setBoard(queue)
		end
	end
end
