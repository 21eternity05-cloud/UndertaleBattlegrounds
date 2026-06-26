local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local originalVolumes = setmetatable({}, { __mode = "k" })

local function collectBackgroundSounds()
	local sounds = {}

	for _, name in ipairs({ "BackgroundMusic", "Music" }) do
		local object = SoundService:FindFirstChild(name)
		if object then
			if object:IsA("Sound") then
				table.insert(sounds, object)
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
