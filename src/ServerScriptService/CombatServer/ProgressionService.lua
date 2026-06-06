local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterData = require(Shared:WaitForChild("CharacterData"))
local TitleData = require(Shared:WaitForChild("TitleData"))
local CustomizationData = require(Shared:WaitForChild("CustomizationData"))
local Assets = ReplicatedStorage:WaitForChild("Assets")
local CharactersFolder = Assets:WaitForChild("Characters")

local ProgressionService = {}
ProgressionService.__index = ProgressionService

function ProgressionService.new(config)
	local self = setmetatable({}, ProgressionService)

	self.Config = config
	self.Profiles = {}
	self.ProfileLoaded = {}
	self.Remote = nil
	self.KillAwarded = setmetatable({}, { __mode = "k" })

	self.DataStoreName = config.DataStoreName or "UTBG_PlayerData_v1"
	self.DataStore = DataStoreService:GetDataStore(self.DataStoreName)

	return self
end

function ProgressionService:GetRemotesFolder()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")

	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	return remotes
end

function ProgressionService:GetRemote()
	if self.Remote then
		return self.Remote
	end

	local remotes = self:GetRemotesFolder()
	local remote = remotes:FindFirstChild("ProgressionRemote")

	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "ProgressionRemote"
		remote.Parent = remotes
	end

	self.Remote = remote

	return remote
end

function ProgressionService:GetDataKey(player)
	return "Player_" .. tostring(player.UserId)
end

function ProgressionService:GetSkinConfig(characterName)
	local characterFolder = CharactersFolder:FindFirstChild(characterName)
	local modulesFolder = characterFolder and characterFolder:FindFirstChild("Modules")
	local skinModule = modulesFolder and modulesFolder:FindFirstChild("SkinModule")

	if not skinModule or not skinModule:IsA("ModuleScript") then
		return nil
	end

	local success, skinConfig = pcall(require, skinModule)

	if success and typeof(skinConfig) == "table" then
		return skinConfig
	end

	warn("[ProgressionService] Failed to load SkinModule for", tostring(characterName))
	return nil
end

function ProgressionService:GetDefaultSkinName(characterName)
	local skinConfig = self:GetSkinConfig(characterName)

	return skinConfig and skinConfig.DefaultSkin or "Default"
end

function ProgressionService:MakeDefaultSkinTables()
	local ownedSkins = {}
	local equippedSkins = {}

	for characterName, data in pairs(CharacterData) do
		if typeof(data) == "table" then
			local skinConfig = self:GetSkinConfig(characterName)
			local defaultSkinName = skinConfig and skinConfig.DefaultSkin or "Default"

			ownedSkins[characterName] = {}
			equippedSkins[characterName] = defaultSkinName

			if skinConfig and typeof(skinConfig.Skins) == "table" then
				for skinName, skinData in pairs(skinConfig.Skins) do
					if typeof(skinData) == "table" and (skinData.Free == true or (skinData.Cost or 0) <= 0) then
						ownedSkins[characterName][skinName] = true
					end
				end
			else
				ownedSkins[characterName][defaultSkinName] = true
			end
		end
	end

	return ownedSkins, equippedSkins
end

function ProgressionService:MakeDefaultProfile()
	local ownedCharacters = {}

	for characterName, data in pairs(CharacterData) do
		if typeof(data) == "table" and (data.Free == true or (data.Cost or 0) <= 0) then
			ownedCharacters[characterName] = true
		end
	end

	local ownedTitles = {}

	for titleId, data in pairs(TitleData) do
		if typeof(data) == "table" and data.Starter == true then
			ownedTitles[titleId] = true
		end
	end

	local ownedSkins, equippedSkins = self:MakeDefaultSkinTables()

	return {
		Dust = self.Config.StartingDust or 0,
		Kills = 0,

		OwnedCharacters = ownedCharacters,
		OwnedTitles = ownedTitles,
		OwnedSkins = ownedSkins,
		EquippedSkins = equippedSkins,

		EquippedTitle = CustomizationData.DefaultEquipped.Title,
		Equipped = table.clone(CustomizationData.DefaultEquipped),

		Lore = {},
	}
end

function ProgressionService:MergeProfile(savedProfile)
	local defaultProfile = self:MakeDefaultProfile()

	if typeof(savedProfile) ~= "table" then
		return defaultProfile
	end

	defaultProfile.Dust = tonumber(savedProfile.Dust) or defaultProfile.Dust
	defaultProfile.Kills = tonumber(savedProfile.Kills) or defaultProfile.Kills

	if typeof(savedProfile.OwnedCharacters) == "table" then
		for characterName, owned in pairs(savedProfile.OwnedCharacters) do
			if owned == true then
				defaultProfile.OwnedCharacters[characterName] = true
			end
		end
	end

	if typeof(savedProfile.OwnedTitles) == "table" then
		for titleId, owned in pairs(savedProfile.OwnedTitles) do
			if owned == true then
				defaultProfile.OwnedTitles[titleId] = true
			end
		end
	end

	if typeof(savedProfile.OwnedSkins) == "table" then
		for characterName, skins in pairs(savedProfile.OwnedSkins) do
			if typeof(skins) == "table" then
				defaultProfile.OwnedSkins[characterName] = defaultProfile.OwnedSkins[characterName] or {}

				for skinName, owned in pairs(skins) do
					if owned == true then
						defaultProfile.OwnedSkins[characterName][skinName] = true
					end
				end
			end
		end
	end

	if typeof(savedProfile.EquippedSkins) == "table" then
		for characterName, skinName in pairs(savedProfile.EquippedSkins) do
			if typeof(skinName) == "string" then
				defaultProfile.EquippedSkins[characterName] = skinName
			end
		end
	end

	if typeof(savedProfile.EquippedTitle) == "string" then
		defaultProfile.EquippedTitle = savedProfile.EquippedTitle
	end

	if typeof(savedProfile.Equipped) == "table" then
		for key, value in pairs(savedProfile.Equipped) do
			defaultProfile.Equipped[key] = value
		end
	end

	if typeof(savedProfile.Lore) == "table" then
		for loreId, unlocked in pairs(savedProfile.Lore) do
			if unlocked == true then
				defaultProfile.Lore[loreId] = true
			end
		end
	end

	return defaultProfile
end

function ProgressionService:GetSavePayload(profile)
	return {
		Dust = profile.Dust or 0,
		Kills = profile.Kills or 0,

		OwnedCharacters = profile.OwnedCharacters or {},
		OwnedTitles = profile.OwnedTitles or {},
		OwnedSkins = profile.OwnedSkins or {},
		EquippedSkins = profile.EquippedSkins or {},

		EquippedTitle = profile.EquippedTitle,
		Equipped = profile.Equipped or {},

		Lore = profile.Lore or {},
	}
end

function ProgressionService:LoadProfile(player)
	local key = self:GetDataKey(player)
	local defaultProfile = self:MakeDefaultProfile()

	local success, result = pcall(function()
		return self.DataStore:GetAsync(key)
	end)

	if not success then
		warn("[ProgressionService] Failed to load profile for", player.Name, result)
		self.Profiles[player] = defaultProfile
		self.ProfileLoaded[player] = false
		return defaultProfile
	end

	local profile = self:MergeProfile(result)

	self.Profiles[player] = profile
	self.ProfileLoaded[player] = true

	print("[ProgressionService] Loaded profile:", player.Name, "Dust:", profile.Dust, "Kills:", profile.Kills)

	return profile
end

function ProgressionService:SaveProfile(player)
	local profile = self.Profiles[player]

	if not profile then
		return false
	end

	local key = self:GetDataKey(player)
	local payload = self:GetSavePayload(profile)

	local success, result = pcall(function()
		self.DataStore:UpdateAsync(key, function()
			return payload
		end)
	end)

	if not success then
		warn("[ProgressionService] Failed to save profile for", player.Name, result)
		return false
	end

	print("[ProgressionService] Saved profile:", player.Name, "Dust:", profile.Dust, "Kills:", profile.Kills)

	return true
end

function ProgressionService:GetProfile(player)
	if not player then
		return nil
	end

	if not self.Profiles[player] then
		return self:LoadProfile(player)
	end

	return self.Profiles[player]
end

function ProgressionService:EnsureLeaderstats(player)
	local profile = self:GetProfile(player)
	if not profile then return end

	local leaderstats = player:FindFirstChild("leaderstats")

	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local dust = leaderstats:FindFirstChild("Dust")

	if not dust then
		dust = Instance.new("IntValue")
		dust.Name = "Dust"
		dust.Parent = leaderstats
	end

	dust.Value = profile.Dust or 0

	local kills = leaderstats:FindFirstChild("Kills")

	if not kills then
		kills = Instance.new("IntValue")
		kills.Name = "Kills"
		kills.Parent = leaderstats
	end

	kills.Value = profile.Kills or 0
end

function ProgressionService:SyncPlayerAttributes(player)
	local profile = self:GetProfile(player)
	if not profile then return end

	player:SetAttribute("Dust", profile.Dust or 0)
	player:SetAttribute("EquippedTitle", profile.EquippedTitle)

	for characterName, skinName in pairs(profile.EquippedSkins or {}) do
		if typeof(skinName) == "string" then
			player:SetAttribute("EquippedSkin_" .. characterName, skinName)
		end
	end
end

function ProgressionService:SetDust(player, amount)
	local profile = self:GetProfile(player)
	if not profile then return end

	profile.Dust = math.max(0, math.floor(amount or 0))

	self:SyncPlayerAttributes(player)
	self:EnsureLeaderstats(player)
	self:SendSnapshot(player)
end

function ProgressionService:AddDust(player, amount)
	local profile = self:GetProfile(player)
	if not profile then return end

	self:SetDust(player, (profile.Dust or 0) + (amount or 0))
end

function ProgressionService:AddKill(player, amount)
	local profile = self:GetProfile(player)
	if not profile then return end

	profile.Kills = math.max(0, math.floor((profile.Kills or 0) + (amount or 1)))

	self:EnsureLeaderstats(player)
	self:SendSnapshot(player)
end

function ProgressionService:IsRespawnDummy(character)
	if not character then
		return false
	end

	if character:GetAttribute("RespawnDummy") == true then
		return true
	end

	local loweredName = string.lower(character.Name)

	return string.find(loweredName, "respawn") ~= nil
end

function ProgressionService:GetKillRewardForTarget(targetCharacter)
	if not targetCharacter then
		return 0
	end

	local customReward = targetCharacter:GetAttribute("DustReward")

	if typeof(customReward) == "number" then
		return math.max(0, math.floor(customReward))
	end

	if self:IsRespawnDummy(targetCharacter) then
		return self.Config.RespawnDummyKillDustReward or 1
	end

	return self.Config.KillDustReward or 0
end

function ProgressionService:GetKillVerb()
	local verbs = self.Config.KillBannerVerbs

	if typeof(verbs) == "table" and #verbs > 0 then
		return verbs[math.random(1, #verbs)]
	end

	return "defeated"
end

function ProgressionService:FireKillBanner(attackerPlayer, targetCharacter, dustReward)
	local attackerName = attackerPlayer and attackerPlayer.DisplayName or "Someone"
	local targetName = targetCharacter and targetCharacter.Name or "Someone"

	self:GetRemote():FireAllClients({
		Action = "KillBanner",
		AttackerName = attackerName,
		VictimName = targetName,
		Verb = self:GetKillVerb(),
		DustReward = dustReward or 0,
	})
end

function ProgressionService:AwardKill(attackerCharacter, targetCharacter)
	if not attackerCharacter or not targetCharacter then
		return
	end

	if self.KillAwarded[targetCharacter] == true then
		return
	end

	local attackerPlayer = Players:GetPlayerFromCharacter(attackerCharacter)

	if not attackerPlayer then
		return
	end

	self.KillAwarded[targetCharacter] = true

	local dustReward = self:GetKillRewardForTarget(targetCharacter)

	self:AddKill(attackerPlayer, 1)

	if dustReward > 0 then
		self:AddDust(attackerPlayer, dustReward)
	else
		self:EnsureLeaderstats(attackerPlayer)
		self:SendSnapshot(attackerPlayer)
	end

	self:FireKillBanner(attackerPlayer, targetCharacter, dustReward)

	print(
		"[ProgressionService] Kill awarded:",
		attackerPlayer.Name,
		"target:",
		targetCharacter.Name,
		"dust:",
		dustReward
	)

	task.defer(function()
		self:SaveProfile(attackerPlayer)
	end)
end

function ProgressionService:IsCharacterUnlocked(player, characterName)
	local data = CharacterData[characterName]

	if not data then
		return false
	end

	if data.Free == true or (data.Cost or 0) <= 0 then
		return true
	end

	local profile = self:GetProfile(player)

	return profile and profile.OwnedCharacters[characterName] == true
end

function ProgressionService:PurchaseCharacter(player, characterName)
	local data = CharacterData[characterName]

	if not data then
		return false, "UnknownCharacter"
	end

	if self:IsCharacterUnlocked(player, characterName) then
		return true, "AlreadyOwned"
	end

	local cost = data.Cost or 0
	local profile = self:GetProfile(player)

	if not profile then
		return false, "NoProfile"
	end

	if (profile.Dust or 0) < cost then
		return false, "NotEnoughDust"
	end

	profile.Dust -= cost
	profile.OwnedCharacters[characterName] = true

	self:SyncPlayerAttributes(player)
	self:EnsureLeaderstats(player)
	self:SendSnapshot(player)

	task.defer(function()
		self:SaveProfile(player)
	end)

	return true, "Purchased"
end

function ProgressionService:IsSkinOwned(player, characterName, skinName)
	local skinConfig = self:GetSkinConfig(characterName)
	local skinData = skinConfig and skinConfig.Skins and skinConfig.Skins[skinName]

	if not skinData then
		return false
	end

	if skinData.Free == true or (skinData.Cost or 0) <= 0 then
		return true
	end

	local profile = self:GetProfile(player)

	return profile
		and profile.OwnedSkins
		and profile.OwnedSkins[characterName]
		and profile.OwnedSkins[characterName][skinName] == true
end

function ProgressionService:GetEquippedSkin(player, characterName)
	local profile = self:GetProfile(player)
	local defaultSkinName = self:GetDefaultSkinName(characterName)
	local equippedSkin = profile and profile.EquippedSkins and profile.EquippedSkins[characterName]

	if typeof(equippedSkin) == "string" and self:IsSkinOwned(player, characterName, equippedSkin) then
		return equippedSkin
	end

	return defaultSkinName
end

function ProgressionService:EquipSkin(player, characterName, skinName)
	if not self:IsSkinOwned(player, characterName, skinName) then
		return false, "LockedSkin"
	end

	local profile = self:GetProfile(player)
	if not profile then
		return false, "NoProfile"
	end

	profile.EquippedSkins[characterName] = skinName
	player:SetAttribute("EquippedSkin_" .. characterName, skinName)

	self:SendSnapshot(player)

	return true, "Equipped"
end

function ProgressionService:PurchaseSkin(player, characterName, skinName)
	local skinConfig = self:GetSkinConfig(characterName)
	local skinData = skinConfig and skinConfig.Skins and skinConfig.Skins[skinName]

	if not skinData then
		return false, "UnknownSkin"
	end

	if self:IsSkinOwned(player, characterName, skinName) then
		self:EquipSkin(player, characterName, skinName)
		return true, "AlreadyOwned"
	end

	local profile = self:GetProfile(player)
	if not profile then
		return false, "NoProfile"
	end

	local cost = skinData.Cost or 0

	if (profile.Dust or 0) < cost then
		return false, "NotEnoughDust"
	end

	profile.Dust -= cost
	profile.OwnedSkins[characterName] = profile.OwnedSkins[characterName] or {}
	profile.OwnedSkins[characterName][skinName] = true
	profile.EquippedSkins[characterName] = skinName

	self:SyncPlayerAttributes(player)
	self:EnsureLeaderstats(player)
	self:SendSnapshot(player)

	return true, "Purchased"
end

function ProgressionService:EquipTitle(player, titleId)
	local profile = self:GetProfile(player)

	if not profile then
		return false, "NoProfile"
	end

	if not TitleData[titleId] then
		return false, "UnknownTitle"
	end

	if profile.OwnedTitles[titleId] ~= true then
		return false, "LockedTitle"
	end

	profile.EquippedTitle = titleId
	profile.Equipped.Title = titleId

	player:SetAttribute("EquippedTitle", titleId)

	self:SendSnapshot(player)

	task.defer(function()
		self:SaveProfile(player)
	end)

	return true, "Equipped"
end

function ProgressionService:UnlockLore(player, loreId)
	local profile = self:GetProfile(player)

	if not profile then
		return false
	end

	profile.Lore[loreId] = true
	self:SendSnapshot(player)

	task.defer(function()
		self:SaveProfile(player)
	end)

	return true
end

function ProgressionService:BuildSnapshot(player)
	local profile = self:GetProfile(player)

	if not profile then
		return nil
	end

	return {
		Dust = profile.Dust or 0,
		Kills = profile.Kills or 0,

		OwnedCharacters = table.clone(profile.OwnedCharacters),
		OwnedTitles = table.clone(profile.OwnedTitles),
		OwnedSkins = table.clone(profile.OwnedSkins),
		EquippedSkins = table.clone(profile.EquippedSkins),

		EquippedTitle = profile.EquippedTitle,
		Equipped = table.clone(profile.Equipped),

		Lore = table.clone(profile.Lore),

		Characters = CharacterData,
		Titles = TitleData,
		Customization = CustomizationData,
	}
end

function ProgressionService:SendSnapshot(player)
	local snapshot = self:BuildSnapshot(player)

	if not snapshot then
		return
	end

	self:GetRemote():FireClient(player, {
		Action = "Snapshot",
		Profile = snapshot,
	})
end

function ProgressionService:HandleRemote(player, payload)
	if typeof(payload) ~= "table" then
		return
	end

	if payload.Action == "BuyCharacter" and typeof(payload.CharacterName) == "string" then
		local ok, reason = self:PurchaseCharacter(player, payload.CharacterName)

		self:GetRemote():FireClient(player, {
			Action = "PurchaseResult",
			CharacterName = payload.CharacterName,
			Success = ok,
			Reason = reason,
			Profile = self:BuildSnapshot(player),
		})
	elseif payload.Action == "EquipTitle" and typeof(payload.TitleId) == "string" then
		local ok, reason = self:EquipTitle(player, payload.TitleId)

		self:GetRemote():FireClient(player, {
			Action = "EquipTitleResult",
			TitleId = payload.TitleId,
			Success = ok,
			Reason = reason,
			Profile = self:BuildSnapshot(player),
		})
	elseif payload.Action == "BuySkin"
		and typeof(payload.CharacterName) == "string"
		and typeof(payload.SkinName) == "string"
	then
		local ok, reason = self:PurchaseSkin(player, payload.CharacterName, payload.SkinName)

		self:GetRemote():FireClient(player, {
			Action = "PurchaseSkinResult",
			CharacterName = payload.CharacterName,
			SkinName = payload.SkinName,
			Success = ok,
			Reason = reason,
			Profile = self:BuildSnapshot(player),
		})
	elseif payload.Action == "EquipSkin"
		and typeof(payload.CharacterName) == "string"
		and typeof(payload.SkinName) == "string"
	then
		local ok, reason = self:EquipSkin(player, payload.CharacterName, payload.SkinName)

		self:GetRemote():FireClient(player, {
			Action = "EquipSkinResult",
			CharacterName = payload.CharacterName,
			SkinName = payload.SkinName,
			Success = ok,
			Reason = reason,
			Profile = self:BuildSnapshot(player),
		})
	elseif payload.Action == "RequestSnapshot" then
		self:SendSnapshot(player)
	end
end

function ProgressionService:SetupPlayer(player)
	self:GetProfile(player)
	self:EnsureLeaderstats(player)
	self:SyncPlayerAttributes(player)

	task.defer(function()
		self:SendSnapshot(player)
	end)
end

function ProgressionService:Start()
	local remote = self:GetRemote()

	remote.OnServerEvent:Connect(function(player, payload)
		self:HandleRemote(player, payload)
	end)

	Players.PlayerAdded:Connect(function(player)
		self:SetupPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:SaveProfile(player)
		self.Profiles[player] = nil
		self.ProfileLoaded[player] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:SetupPlayer(player)
	end

	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			self:SaveProfile(player)
		end
	end)
end

return ProgressionService
