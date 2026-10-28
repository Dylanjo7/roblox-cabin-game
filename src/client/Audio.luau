--!strict
-- Plays the sounds named in Config.Sounds: one-shots (optionally positioned in the world) and
-- looping beds whose volume fades between dread levels.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Audio = {}

local loops: { [string]: Sound } = {}

local function make(name: string, volume: number, parent: Instance): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = Config.Sounds[name] or ""
	sound.Volume = volume
	sound.Parent = parent
	return sound
end

-- Play once. With `at`, the sound comes from that part in the world.
function Audio.play(name: string, volume: number?, at: BasePart?, speed: number?): Sound
	local sound = make(name, volume or 0.5, at or SoundService)
	sound.PlaybackSpeed = speed or 1
	if at then
		sound.RollOffMaxDistance = 120
	end
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
	return sound
end

-- Fade a looping sound to this volume (it starts silent the first time it's used).
function Audio.loopVolume(name: string, volume: number, fadeSeconds: number?)
	local sound = loops[name]
	if not sound then
		sound = make(name, 0, SoundService)
		sound.Looped = true
		sound:Play()
		loops[name] = sound
	end
	TweenService:Create(sound, TweenInfo.new(fadeSeconds or 2), { Volume = volume }):Play()
end

return Audio
