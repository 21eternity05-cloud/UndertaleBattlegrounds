local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AwakeningMusicService = {}
AwakeningMusicService.__index = AwakeningMusicService

function AwakeningMusicService.new(config)
	local self = setmetatable({}, AwakeningMusicService)

	self.Config = config or {}
	self.ActivePlayers = {}
	self.Connections = {}
	self.Remote = nil

	return self
end

function AwakeningMusicService:GetRemote()
	if self.Remote then
		return self.Remote
	end

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	local remote = remotes:FindFirstChild("AwakeningMusicRemote")
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "AwakeningMusicRemote"
		remote.Parent = remotes
	end

	self.Remote = remote
	return remote
end

function AwakeningMusicService:GetCharacterName(player, character)
	if character then
		local characterName = character:GetAttribute("CharacterName")
		if typeof(characterName) == "string" and characterName ~= "" then
			return characterName
		end
	end

	if player then
		local characterName = player:GetAttribute("CharacterName")
		if typeof(characterName) == "string" and characterName ~= "" then
			return characterName
		end
	end

	return self.Config.DefaultCharacterName or "Chara"
end

function AwakeningMusicService:GetAwakeningTheme(characterName)
	local assets = ReplicatedStorage:FindFirstChild(self.Config.AssetsFolderName or "Assets")
	local characters = assets and assets:FindFirstChild(self.Config.CharactersFolderName or "Characters")
	local characterFolder = characters and characters:FindFirstChild(characterName)
	local sfxFolder = characterFolder and characterFolder:FindFirstChild("SFX")
	local sound = sfxFolder and sfxFolder:FindFirstChild("AwakeningTheme")

	if not sound or not sound:IsA("Sound") then
		warn("[AwakeningMusicService] Missing Sound: ReplicatedStorage > Assets > Characters > "
			.. tostring(characterName)
			.. " > SFX > AwakeningTheme")
		return nil
	end

	return sound
end

function AwakeningMusicService:DisconnectPlayer(player)
	local connections = self.Connections[player]
	if not connections then
		return
	end

	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end

	self.Connections[player] = nil
end

function AwakeningMusicService:TrackPlayerCharacter(player, character)
	self:DisconnectPlayer(player)
	self.Connections[player] = {}

	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		table.insert(self.Connections[player], humanoid.Died:Connect(function()
			self:StopForPlayer(player)
		end))
	end

	if character then
		table.insert(self.Connections[player], character:GetAttributeChangedSignal("CombatMode"):Connect(function()
			if character:GetAttribute("CombatMode") == "Base" then
				self:StopForPlayer(player)
			end
		end))
	end
end

function AwakeningMusicService:StartForPlayer(player, character, config)
	if not player or not player.Parent then
		return false
	end
	if not character or not character.Parent then
		return false
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		warn("[AwakeningMusicService] Cannot start awakening music without HumanoidRootPart:", player.Name)
		return false
	end

	local characterName = self:GetCharacterName(player, character)
	local sourceSound = self:GetAwakeningTheme(characterName)
	if not sourceSound then
		return false
	end

	config = config or {}

	self.ActivePlayers[player] = true
	self:TrackPlayerCharacter(player, character)

	self:GetRemote():FireAllClients({
		Action = "Start",
		Player = player,
		Character = character,
		CharacterName = characterName,
		SoundName = "AwakeningTheme",
		Volume = config.Volume or sourceSound.Volume or 0.55,
		FadeInTime = config.FadeInTime or 1.2,
		FadeOutTime = config.FadeOutTime or 0.8,
		RollOffMaxDistance = config.RollOffMaxDistance or 140,
		RollOffMinDistance = config.RollOffMinDistance or 12,
	})

	return true
end

function AwakeningMusicService:StopForPlayer(player, config)
	if not player then
		return
	end

	config = config or {}

	if self.ActivePlayers[player] then
		self:GetRemote():FireAllClients({
			Action = "Stop",
			Player = player,
			FadeOutTime = config.FadeOutTime or 0.8,
		})
	end

	self.ActivePlayers[player] = nil
	self:DisconnectPlayer(player)
end

function AwakeningMusicService:Start()
	self:GetRemote()

	Players.PlayerRemoving:Connect(function(player)
		self:StopForPlayer(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			self:StopForPlayer(player)
		end)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		player.CharacterAdded:Connect(function()
			self:StopForPlayer(player)
		end)
	end
end

return AwakeningMusicService
