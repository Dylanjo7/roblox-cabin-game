--!strict
-- Draws the Hollow Man wherever he is. The server only moves invisible markers (tagged
-- HollowManModel.Tag); this builds an animated figure on each one, eased so it glides between
-- network updates. It also spawns client-only figures (glimpses, him watching from the door)
-- and knows where he really is, so Atmosphere can react only when he's close.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HollowManModel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HollowManModel"))

local HollowManRig = require(script.Parent.HollowManRig)

type Figure = {
	rig: HollowManRig.Rig,
	marker: BasePart?, -- following a server marker, or nil for a local figure
	pivot: CFrame,
	speed: number,
	watch: boolean, -- head follows the local player
	real: boolean, -- counts as him being here (not just a glimpse)
}

export type Handle = {
	destroy: () -> (),
	setWatch: (watch: boolean) -> (), -- start or stop his head following you
	position: () -> Vector3,
	setPivot: (cf: CFrame, speed: number?) -> (), -- move him (speed: how fast he's going, for his gait)
}

local HollowManView = {}

local figures: { Figure } = {}
local byMarker: { [Instance]: Figure } = {}
local localPlayer = Players.LocalPlayer

local function remove(figure: Figure)
	local i = table.find(figures, figure)
	if i then
		table.remove(figures, i)
	end
	figure.rig.model:Destroy()
end

local function add(rig: HollowManRig.Rig, pivot: CFrame, marker: BasePart?, watch: boolean, real: boolean): Figure
	local figure: Figure = { rig = rig, marker = marker, pivot = pivot, speed = 0, watch = watch, real = real }
	rig.model.Parent = workspace
	table.insert(figures, figure)
	HollowManRig.pose(rig, pivot, 0, 0, false, nil)
	return figure
end

local function onMarker(inst: Instance)
	if not inst:IsA("BasePart") or byMarker[inst] then
		return
	end
	byMarker[inst] = add(HollowManRig.new(), inst.CFrame, inst, false, true)
end

local function onMarkerGone(inst: Instance)
	local figure = byMarker[inst]
	if figure then
		byMarker[inst] = nil
		remove(figure)
	end
end

-- A figure only this client sees, standing at `cf` (his feet, facing -Z). watch: his head
-- follows you. real: he counts as being here (lights flicker near him).
function HollowManView.spawnLocal(cf: CFrame, watch: boolean, real: boolean): Handle
	local figure = add(HollowManRig.new(), cf, nil, watch, real)
	return {
		destroy = function()
			remove(figure)
		end,
		setWatch = function(watch: boolean)
			figure.watch = watch
		end,
		position = function(): Vector3
			return figure.pivot.Position
		end,
		setPivot = function(cf: CFrame, speed: number?)
			figure.pivot = cf
			figure.speed = speed or 0
		end,
	}
end

-- Where he really is right now (server figures and real local ones), feet positions.
function HollowManView.positions(): { Vector3 }
	local out = {}
	for _, figure in figures do
		if figure.real then
			table.insert(out, figure.pivot.Position)
		end
	end
	return out
end

-- How far he has to stoop to fit under whatever is over him, or just ahead of him: a door
-- frame's head, a low beam. (He's about TALL studs tall; doorways are 9.)
local TALL = 10.5
local overhead = RaycastParams.new()
overhead.FilterType = Enum.RaycastFilterType.Exclude
local function stoop(figure: Figure): number
	local ignore: { Instance } = { figure.rig.model }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	if figure.marker then
		table.insert(ignore, figure.marker)
	end
	overhead.FilterDescendantsInstances = ignore
	local lowest = math.huge
	for _, ahead in { 0, 2.5 } do
		local from = (figure.pivot * CFrame.new(0, 4, -ahead)).Position
		local hit = workspace:Raycast(from, Vector3.new(0, TALL - 4 + 0.5, 0), overhead)
		if hit then
			lowest = math.min(lowest, hit.Position.Y - figure.pivot.Position.Y)
		end
	end
	return if lowest == math.huge then 0 else math.clamp((TALL + 0.3 - lowest) / 3, 0, 1)
end

local function headPosition(): Vector3?
	local character = localPlayer.Character
	local head = character and character:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head.Position else nil
end

function HollowManView.init()
	for _, inst in CollectionService:GetTagged(HollowManModel.Tag) do
		onMarker(inst)
	end
	CollectionService:GetInstanceAddedSignal(HollowManModel.Tag):Connect(onMarker)
	CollectionService:GetInstanceRemovedSignal(HollowManModel.Tag):Connect(onMarkerGone)

	RunService.RenderStepped:Connect(function(dt: number)
		local head = headPosition()
		for _, figure in table.clone(figures) do
			local marker = figure.marker
			local chasing = false
			local killing = false
			local watch = figure.watch
			if marker then
				if not marker.Parent then
					onMarkerGone(marker)
					continue
				end
				-- Glide towards the marker; estimate how fast he's walking for the gait.
				local before = figure.pivot.Position
				figure.pivot = figure.pivot:Lerp(marker.CFrame, math.min(1, dt * 10))
				local moved = (figure.pivot.Position - before) * Vector3.new(1, 0, 1)
				local speed = if dt > 0 then moved.Magnitude / dt else 0
				figure.speed += (speed - figure.speed) * math.min(1, dt * 8)
				chasing = marker:GetAttribute("Chasing") == true
				killing = marker:GetAttribute("Killing") == true
				watch = marker:GetAttribute("Watch") == true and not killing
			end
			HollowManRig.pose(figure.rig, figure.pivot, dt, figure.speed, chasing, if watch then head else nil, killing, stoop(figure))
		end
	end)
end

return HollowManView
