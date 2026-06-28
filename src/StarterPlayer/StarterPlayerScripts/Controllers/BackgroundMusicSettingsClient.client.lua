local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local originalVolumes = setmetatable({}, { __mode = "k" })
local bgmSound = nil

local function getBGMTemplate()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local bgm = assets and assets:FindFirstChild("BGM")

	if bgm and bgm:IsA("Sound") then
		return bgm
	end

	return nil
end

local function getOrCreateBGM()
	if bgmSound and bgmSound.Parent then
		return bgmSound
	end

	local existing = SoundService:FindFirstChild("BGM")
	if existing and existing:IsA("Sound") then
		bgmSound = existing
		return bgmSound
	end

	local template = getBGMTemplate()
	if not template then
		return nil
	end

	local clone = template:Clone()
	clone.Name = "BGM"
	clone.Looped = true
	clone.Parent = SoundService
	bgmSound = clone

	return bgmSound
end

local function collectBackgroundSounds()
	local sounds = {}
	local bgm = getOrCreateBGM()

	if bgm then
		table.insert(sounds, bgm)
	end

	for _, name in ipairs({ "BackgroundMusic", "Music", "BGM" }) do
		local object = SoundService:FindFirstChild(name)
		if object then
			if object:IsA("Sound") then
				if object ~= bgm then
					table.insert(sounds, object)
				end
			else
				for _, descendant in ipairs(object:GetDescendants()) do
					if descendant:IsA("Sound") then
						table.insert(sounds, descendant)
					end
				end
			end
		end
	end

	return sounds
end

local function applyMusicSetting()
	local musicEnabled = player:GetAttribute("Setting_Music") ~= false

	for _, sound in ipairs(collectBackgroundSounds()) do
		if originalVolumes[sound] == nil then
			local attributeVolume = sound:GetAttribute("OriginalBackgroundVolume")
			if typeof(attributeVolume) == "number" then
				originalVolumes[sound] = attributeVolume
			else
				originalVolumes[sound] = sound.Volume
				sound:SetAttribute("OriginalBackgroundVolume", sound.Volume)
			end
		end

		sound.Volume = musicEnabled and originalVolumes[sound] or 0

		if sound == bgmSound then
			if musicEnabled and sound.SoundId ~= "" and not sound.IsPlaying then
				sound:Play()
			end
		end
	end
end

player:GetAttributeChangedSignal("Setting_Music"):Connect(applyMusicSetting)
SoundService.ChildAdded:Connect(function()
	task.defer(applyMusicSetting)
end)

SoundService.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("Sound") then
		task.defer(applyMusicSetting)
	end
end)

applyMusicSetting()
