local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterData = require(Shared:WaitForChild("CharacterData"))
local TitleData = require(Shared:WaitForChild("TitleData"))
local CustomizationData = require(Shared:WaitForChild("CustomizationData"))

local ProgressionService = {}
ProgressionService.__index = ProgressionService

function ProgressionService.new(config)
	local self = setmetatable({}, ProgressionService)

	self.Config = config
	self.Profiles = {}
	self.Remote = nil

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

function ProgressionService:MakeDefaultProfile()
	local ownedCharacters = {}

	for characterName, data in pairs(CharacterData) do
		if data.Free == true or (data.Cost or 0) <= 0 then
			ownedCharacters[characterName] = true
		end
	end

	local ownedTitles = {}

	for titleId, data in pairs(TitleData) do
		if data.Starter == true then
			ownedTitles[titleId] = true
		end
	end

	return {
		Dust = self.Config.StartingDust or 0,
		Kills = 0,
		OwnedCharacters = ownedCharacters,
		OwnedTitles = ownedTitles,
		EquippedTitle = CustomizationData.DefaultEquipped.Title,
		Equipped = table.clone(CustomizationData.DefaultEquipped),
		Lore = {},
	}
end

function ProgressionService:GetProfile(player)
	if not player then return nil end

	if not self.Profiles[player] then
		-- TODO: Replace this in-memory profile with DataStore/ProfileService persistence.
		self.Profiles[player] = self:MakeDefaultProfile()
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

function ProgressionService:SetDust(player, amount)
	local profile = self:GetProfile(player)
	if not profile then return end

	profile.Dust = math.max(0, math.floor(amount or 0))
	player:SetAttribute("Dust", profile.Dust)
	self:EnsureLeaderstats(player)
	self:SendSnapshot(player)
end

function ProgressionService:AddDust(player, amount)
	local profile = self:GetProfile(player)
	if not profile then return end

	self:SetDust(player, (profile.Dust or 0) + (amount or 0))
end

function ProgressionService:IsCharacterUnlocked(player, characterName)
	local data = CharacterData[characterName]
	if not data then return false end

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

	self:EnsureLeaderstats(player)
	self:SendSnapshot(player)

	return true, "Purchased"
end

function ProgressionService:EquipTitle(player, titleId)
	local profile = self:GetProfile(player)
	if not profile then return false, "NoProfile" end
	if not TitleData[titleId] then return false, "UnknownTitle" end
	if profile.OwnedTitles[titleId] ~= true then return false, "LockedTitle" end

	profile.EquippedTitle = titleId
	profile.Equipped.Title = titleId
	player:SetAttribute("EquippedTitle", titleId)

	self:SendSnapshot(player)

	return true, "Equipped"
end

function ProgressionService:UnlockLore(player, loreId)
	local profile = self:GetProfile(player)
	if not profile then return false end

	profile.Lore[loreId] = true
	self:SendSnapshot(player)

	return true
end

function ProgressionService:BuildSnapshot(player)
	local profile = self:GetProfile(player)
	if not profile then return nil end

	return {
		Dust = profile.Dust or 0,
		Kills = profile.Kills or 0,
		OwnedCharacters = table.clone(profile.OwnedCharacters),
		OwnedTitles = table.clone(profile.OwnedTitles),
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
	if not snapshot then return end

	self:GetRemote():FireClient(player, {
		Action = "Snapshot",
		Profile = snapshot,
	})
end

function ProgressionService:HandleRemote(player, payload)
	if typeof(payload) ~= "table" then return end

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
	elseif payload.Action == "RequestSnapshot" then
		self:SendSnapshot(player)
	end
end

function ProgressionService:SetupPlayer(player)
	self:GetProfile(player)
	self:EnsureLeaderstats(player)

	local profile = self:GetProfile(player)
	player:SetAttribute("Dust", profile.Dust or 0)
	player:SetAttribute("EquippedTitle", profile.EquippedTitle)

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
		self.Profiles[player] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:SetupPlayer(player)
	end
end

return ProgressionService
