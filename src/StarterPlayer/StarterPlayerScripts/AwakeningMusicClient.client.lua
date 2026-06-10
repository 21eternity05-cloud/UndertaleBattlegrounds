local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local awakeningMusicRemote = remotes:WaitForChild("AwakeningMusicRemote")

local assets = ReplicatedStorage:WaitForChild("Assets")
local charactersFolder = assets:WaitForChild("Characters")

local activeMusic = {}

local function getSourceSound(characterName, soundName)
	local characterFolder = charactersFolder:FindFirstChild(characterName)
	local sfxFolder = characterFolder and characterFolder:FindFirstChild("SFX")
	local sound = sfxFolder and sfxFolder:FindFirstChild(soundName or "AwakeningTheme")

	if not sound or not sound:IsA("Sound") then
		warn("[AwakeningMusicClient] Missing Sound: ReplicatedStorage > Assets > Characters > "
			.. tostring(characterName)
			.. " > SFX > "
			.. tostring(soundName or "AwakeningTheme"))
		return nil
	end

	return sound
end

local function cleanupPlayerMusic(player, fadeOutTime)
	local active = activeMusic[player]
	if not active then
		return
	end

	activeMusic[player] = nil

	if active.Tween then
		active.Tween:Cancel()
	end

	local sound = active.Sound
	if not sound or not sound.Parent then
		return
	end

	local tween = TweenService:Create(
		sound,
		TweenInfo.new(fadeOutTime or 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Volume = 0 }
	)

	tween.Completed:Connect(function()
		if sound and sound.Parent then
			sound:Destroy()
		end
	end)

	tween:Play()
end

local function startPlayerMusic(payload)
	local player = payload.Player
	if not player or not player:IsA("Player") then
		return
	end

	cleanupPlayerMusic(player, payload.FadeOutTime or 0.2)

	local character = payload.Character
	if not character or not character.Parent then
		character = player.Character
	end

	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local sourceSound = getSourceSound(payload.CharacterName, payload.SoundName)
	if not sourceSound then
		return
	end

	local sound = sourceSound:Clone()
	sound.Name = "LocalAwakeningMusic"
	sound.Looped = true
	sound.Volume = 0
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMaxDistance = payload.RollOffMaxDistance or 140
	sound.RollOffMinDistance = payload.RollOffMinDistance or 12
	sound.Parent = root

	sound:Play()

	local tween = TweenService:Create(
		sound,
		TweenInfo.new(payload.FadeInTime or 1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Volume = payload.Volume or sourceSound.Volume or 0.55 }
	)

	activeMusic[player] = {
		Sound = sound,
		Tween = tween,
		Character = character,
	}

	tween:Play()

	sound.AncestryChanged:Connect(function(_, parent)
		if parent == nil and activeMusic[player] and activeMusic[player].Sound == sound then
			activeMusic[player] = nil
		end
	end)
end

awakeningMusicRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	if payload.Action == "Start" then
		startPlayerMusic(payload)
	elseif payload.Action == "Stop" then
		cleanupPlayerMusic(payload.Player, payload.FadeOutTime or 0.8)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	cleanupPlayerMusic(player, 0)
end)

Players.LocalPlayer.CharacterRemoving:Connect(function()
	cleanupPlayerMusic(Players.LocalPlayer, 0.2)
end)
