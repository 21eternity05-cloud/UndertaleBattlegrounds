local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterData = require(Shared:WaitForChild("CharacterData"))
local TitleData = require(Shared:WaitForChild("TitleData"))
local EmoteData = require(Shared:WaitForChild("EmoteData"))
local LoreFragmentData = require(Shared:WaitForChild("Interactables"):WaitForChild("LoreFragmentData"))

local function makeFallbackDebugDummyController(reason)
	warn("[DevAdminService] DebugDummyController unavailable:", reason)

	local fallback = {}
	fallback.__index = fallback

	function fallback.new(services)
		return setmetatable({
			Services = services or {},
		}, fallback)
	end

	function fallback:Start(dummy)
		warn("[DevAdminService] Starting debug dummy without behavior controller:", dummy and dummy.Name or "nil")
		return false, "DebugDummyController missing."
	end

	function fallback:Cleanup()
	end

	return fallback
end

local function loadDebugDummyController()
	local moduleScript = script.Parent:FindFirstChild("DebugDummyController")

	if not moduleScript then
		moduleScript = script.Parent:WaitForChild("DebugDummyController", 5)
	end

	if not moduleScript then
		return makeFallbackDebugDummyController("missing child ServerScriptService/TestTools/DebugDummyController")
	end

	if not moduleScript:IsA("ModuleScript") then
		return makeFallbackDebugDummyController("DebugDummyController is not a ModuleScript")
	end

	local success, moduleOrError = pcall(require, moduleScript)
	if not success then
		return makeFallbackDebugDummyController(moduleOrError)
	end

	if typeof(moduleOrError) ~= "table" or typeof(moduleOrError.new) ~= "function" then
		return makeFallbackDebugDummyController("module did not return a constructor table")
	end

	return moduleOrError
end

local DebugDummyControllerModule = loadDebugDummyController()

local DevAdminService = {}
DevAdminService.__index = DevAdminService

local GROUP_ID = 33686072 -- TODO: set real Roblox group id.
local MIN_DEVELOPER_RANK = 200
local OWNER_RANK = 255
local DEVELOPERS_CAN_USE_DATA_MANAGER = false
local DEVELOPERS_CAN_USE_ABUSE = false
local PLACE_OWNER_CAN_USE_DEV_MENU = true

local OWNER_USER_IDS = {
	-- [123456789] = true,
	[78551444] = true,
}

local DEVELOPER_USER_IDS = {
	-- [123456789] = true,
	[78551444] = true,
}

local DUMMY_TYPES = {
	Basic = {},
	Blocking = { Block = true },
	Moving = { Moving = true },
	Combo = { Combo = true, M1NPC = true },
	AirCombo = { Aircombo = true, M1NPC = true, AirComboNPC = true },
	Aircombo = { Aircombo = true, M1NPC = true, AirComboNPC = true },
	SOULBURST = { SOULBURST = true },
	SUPER = { Super = true, Immortal = true },
	TRUE = { TRUE = true },
}

local EXCLUSIVE_DUMMY_TAGS = {
	Aircombo = true,
	Combo = true,
	Block = true,
}

local MAX_DATA_VALUE = 999999999
local NONE_TITLE_ID = "None"
local MAX_EMOTE_SLOTS = 8

function DevAdminService.new()
	return setmetatable({
		DummyController = nil,
		NukeRunning = false,
	}, DevAdminService)
end

function DevAdminService:GetGroupRank(player)
	if GROUP_ID <= 0 then
		return 0
	end

	local success, rank = pcall(function()
		return player:GetRankInGroup(GROUP_ID)
	end)

	if not success or typeof(rank) ~= "number" then
		return 0
	end

	return rank
end

function DevAdminService:IsPlaceOwner(player)
	if not PLACE_OWNER_CAN_USE_DEV_MENU then
		return false
	end

	if game.CreatorType ~= Enum.CreatorType.User then
		return false
	end

	return player.UserId == game.CreatorId
end

function DevAdminService:GetRole(player)
	if not player then
		return "None"
	end

	if OWNER_USER_IDS[player.UserId] == true or self:IsPlaceOwner(player) then
		return "Owner"
	end

	local rank = self:GetGroupRank(player)

	if rank >= OWNER_RANK then
		return "Owner"
	end

	if DEVELOPER_USER_IDS[player.UserId] == true or rank >= MIN_DEVELOPER_RANK then
		return "Developer"
	end

	return "None"
end

function DevAdminService:CanUseDevMenu(player)
	return self:GetRole(player) ~= "None"
end

function DevAdminService:CanUseCombatDebug(player)
	return self:CanUseDevMenu(player)
end

function DevAdminService:CanUseDataManager(player)
	local role = self:GetRole(player)

	if role == "Owner" then
		return true
	end

	return role == "Developer" and DEVELOPERS_CAN_USE_DATA_MANAGER == true
end

function DevAdminService:CanUseAbuseTools(player)
	local role = self:GetRole(player)

	if role == "Owner" then
		return true
	end

	return role == "Developer" and DEVELOPERS_CAN_USE_ABUSE == true
end

function DevAdminService:GetPermissionStatus(player)
	local role = self:GetRole(player)
	local canUseDevMenu = role ~= "None"

	return {
		CanUseDevMenu = canUseDevMenu,
		Role = role,
		CanUseCombatDebug = canUseDevMenu,
		CanUseDataManager = self:CanUseDataManager(player),
		CanUseAbuseTools = self:CanUseAbuseTools(player),
	}
end

function DevAdminService:Result(success, message, extra)
	local result = extra or {}
	result.Success = success == true
	result.Message = message or (success and "OK" or "Failed")
	return result
end

function DevAdminService:GetDevServices()
	return _G.UTBGDevServices or {}
end

function DevAdminService:GetDummyController()
	local services = self:GetDevServices()

	local currentServices = self.DummyController and self.DummyController.Services or {}

	if not self.DummyController
		or (not currentServices.BlockService and services.BlockService)
	then
		self.DummyController = DebugDummyControllerModule.new(services)
	end

	return self.DummyController
end

function DevAdminService:GetPlayerCharacter(player)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if not character or not humanoid or humanoid.Health <= 0 or not root then
		return nil, nil, nil
	end

	return character, humanoid, root
end

function DevAdminService:LogAction(player, actionName, detail)
	print("[DevAdmin]", player and player.Name or "Unknown", actionName, detail or "")
end

function DevAdminService:HandleCombatDebugAction(player, payload)
	if not self:CanUseCombatDebug(player) then
		return self:Result(false, "Not allowed.")
	end

	if typeof(payload) ~= "table" then
		return self:Result(false, "Invalid payload.")
	end

	local actionName = payload.Action
	if typeof(actionName) ~= "string" then
		return self:Result(false, "Missing action.")
	end

	local services = self:GetDevServices()
	local character, humanoid = self:GetPlayerCharacter(player)

	if actionName == "HealSelf" then
		if not character then
			return self:Result(false, "No live character.")
		end

		if services.DebugService and services.DebugService.HealCharacter then
			services.DebugService:HealCharacter(character)
		else
			character:SetAttribute("AllowCombatHealUntil", os.clock() + 0.2)
			humanoid.Health = humanoid.MaxHealth
		end

		self:LogAction(player, actionName, "self")
		return self:Result(true, "Healed self.")
	end

	if actionName == "HealAll" then
		if services.DebugService and services.DebugService.HealAllPlayersAndDummies then
			services.DebugService:HealAllPlayersAndDummies()
		end

		for _, otherPlayer in ipairs(Players:GetPlayers()) do
			local otherCharacter = otherPlayer.Character
			local otherHumanoid = otherCharacter and otherCharacter:FindFirstChildOfClass("Humanoid")
			if otherCharacter and otherHumanoid and otherHumanoid.Health > 0 then
				otherCharacter:SetAttribute("AllowCombatHealUntil", os.clock() + 0.2)
				otherHumanoid.Health = otherHumanoid.MaxHealth
			end
		end

		local folder = Workspace:FindFirstChild("DebugDummies")
		if folder then
			for _, descendant in ipairs(folder:GetDescendants()) do
				if descendant:IsA("Humanoid") and descendant.Health > 0 then
					descendant.Health = descendant.MaxHealth
				end
			end
		end

		self:LogAction(player, actionName, "all")
		return self:Result(true, "Healed players and debug dummies.")
	end

	if actionName == "FillSoulBurst" then
		if not services.SoulBurstService or not services.SoulBurstService.SetSoulBurst then
			return self:Result(false, "SoulBurstService unavailable.")
		end

		services.SoulBurstService:SetSoulBurst(player, services.SoulBurstService:GetMax(), "DevAdmin")
		self:LogAction(player, actionName, "self")
		return self:Result(true, "SoulBurst filled.")
	end

	if actionName == "FillUlt" then
		if not services.UltService or not services.UltService.SetUlt then
			return self:Result(false, "UltService unavailable.")
		end

		services.UltService:SetUlt(player, services.UltService:GetUltMax(), "DevAdmin")
		self:LogAction(player, actionName, "self")
		return self:Result(true, "Ultimate filled.")
	end

	if actionName == "ToggleCooldowns" then
		if services.DebugService and services.DebugService.ToggleCooldowns then
			services.DebugService:ToggleCooldowns()
		else
			local enabled = Workspace:GetAttribute("DebugCooldownsEnabled") == true
			Workspace:SetAttribute("DebugCooldownsEnabled", not enabled)
			Workspace:SetAttribute("DebugCooldownOverride", not enabled and 1 or nil)
		end

		local enabled = Workspace:GetAttribute("DebugCooldownsEnabled") == true
		self:LogAction(player, actionName, tostring(enabled))
		return self:Result(true, enabled and "Cooldown debug enabled." or "Cooldown debug disabled.", {
			Enabled = enabled,
		})
	end

	if actionName == "ToggleDebug" then
		if services.DebugService and services.DebugService.Toggle then
			services.DebugService:Toggle()
		else
			Workspace:SetAttribute("DebugEnabled", Workspace:GetAttribute("DebugEnabled") ~= true)
		end

		local enabled = Workspace:GetAttribute("DebugEnabled") == true
		player:SetAttribute("DevDebugEnabled", enabled)
		self:LogAction(player, actionName, tostring(enabled))
		return self:Result(true, enabled and "Debug visualization enabled." or "Debug visualization disabled.", {
			Enabled = enabled,
		})
	end

	return self:Result(false, "Unknown combat action.")
end

function DevAdminService:GetProgressionService()
	local services = self:GetDevServices()
	return services.ProgressionService or _G.UTBGProgressionService
end

function DevAdminService:GetOnlinePlayerList()
	local list = {}

	for _, target in ipairs(Players:GetPlayers()) do
		table.insert(list, {
			UserId = target.UserId,
			Name = target.Name,
			DisplayName = target.DisplayName,
			Label = string.format("%s (@%s)", target.DisplayName, target.Name),
		})
	end

	table.sort(list, function(a, b)
		return string.lower(a.Name) < string.lower(b.Name)
	end)

	return list
end

function DevAdminService:GetTargetPlayerFromPayload(payload)
	if typeof(payload) ~= "table" then
		return nil, "Invalid payload."
	end

	local userId = tonumber(payload.TargetUserId or payload.UserId)
	if not userId then
		return nil, "Missing target player."
	end

	userId = math.floor(userId)
	local target = Players:GetPlayerByUserId(userId)
	if not target then
		return nil, "Target player is not online."
	end

	return target, nil
end

function DevAdminService:GetLoadedProfile(progressionService, target)
	if not progressionService then
		return nil, "ProgressionService unavailable."
	end

	if progressionService.ProfileLoaded and progressionService.ProfileLoaded[target] ~= true then
		return nil, "Target profile is not safely loaded."
	end

	local profile = progressionService.Profiles and progressionService.Profiles[target]
	if not profile and progressionService.GetProfile then
		profile = progressionService:GetProfile(target)
	end

	if not profile then
		return nil, "Target has no loaded profile."
	end

	if progressionService.ProfileLoaded and progressionService.ProfileLoaded[target] ~= true then
		return nil, "Target profile is not safely loaded."
	end

	return profile, nil
end

function DevAdminService:ToSafeInteger(value)
	local number = tonumber(value)
	if not number or number ~= number or number == math.huge or number == -math.huge then
		return nil
	end

	return math.clamp(math.floor(number), 0, MAX_DATA_VALUE)
end

function DevAdminService:ToDeltaInteger(value)
	local number = tonumber(value)
	if not number or number ~= number or number == math.huge or number == -math.huge then
		return nil
	end

	return math.clamp(math.floor(number), -MAX_DATA_VALUE, MAX_DATA_VALUE)
end

function DevAdminService:GetAllSkinIds()
	local result = {}

	for characterName in pairs(CharacterData) do
		local skinConfig = self:GetSkinConfigForName(characterName)
		result[characterName] = {}

		if skinConfig and typeof(skinConfig.Skins) == "table" then
			for skinName in pairs(skinConfig.Skins) do
				table.insert(result[characterName], skinName)
			end
		else
			table.insert(result[characterName], "Default")
		end

		table.sort(result[characterName])
	end

	return result
end

function DevAdminService:GetSkinConfigForName(characterName)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local characters = assets and assets:FindFirstChild("Characters")
	local characterFolder = characters and characters:FindFirstChild(characterName)
	return self:GetSkinConfig(characterFolder)
end

function DevAdminService:GetDataDefinitions()
	local characterIds = {}
	for characterName in pairs(CharacterData) do
		table.insert(characterIds, characterName)
	end
	table.sort(characterIds)

	local titleIds = {}
	for titleId in pairs(TitleData) do
		table.insert(titleIds, titleId)
	end
	table.sort(titleIds)

	local emoteIds = {}
	for emoteId in pairs(EmoteData) do
		table.insert(emoteIds, emoteId)
	end
	table.sort(emoteIds)

	local loreIds = {}
	for loreId in pairs(LoreFragmentData) do
		table.insert(loreIds, loreId)
	end
	table.sort(loreIds)

	return {
		Characters = characterIds,
		Skins = self:GetAllSkinIds(),
		Titles = titleIds,
		Emotes = emoteIds,
		Lore = loreIds,
	}
end

function DevAdminService:BuildDataSnapshot(target, progressionService, profile)
	local snapshot = progressionService.BuildSnapshot and progressionService:BuildSnapshot(target) or {}
	snapshot = snapshot or {}

	return {
		Target = {
			UserId = target.UserId,
			Name = target.Name,
			DisplayName = target.DisplayName,
			Label = string.format("%s (@%s)", target.DisplayName, target.Name),
		},
		Profile = snapshot,
		EquippedCharacter = target:GetAttribute("CharacterName"),
		Definitions = self:GetDataDefinitions(),
		Raw = {
			Dust = profile.Dust or 0,
			Kills = profile.Kills or 0,
			OwnedCharacters = table.clone(profile.OwnedCharacters or {}),
			OwnedSkins = table.clone(profile.OwnedSkins or {}),
			EquippedSkins = table.clone(profile.EquippedSkins or {}),
			OwnedTitles = table.clone(profile.OwnedTitles or {}),
			EquippedTitle = profile.EquippedTitle or NONE_TITLE_ID,
			OwnedEmotes = table.clone(profile.OwnedEmotes or {}),
			EquippedEmotes = table.clone(profile.EquippedEmotes or {}),
			Lore = table.clone(profile.Lore or {}),
			Settings = table.clone(profile.Settings or {}),
		},
	}
end

function DevAdminService:FinalizeDataEdit(admin, target, progressionService, actionName, detail)
	if progressionService.SyncPlayerAttributes then
		progressionService:SyncPlayerAttributes(target)
	end
	if progressionService.EnsureLeaderstats then
		progressionService:EnsureLeaderstats(target)
	end
	if progressionService.SendSnapshot then
		progressionService:SendSnapshot(target)
	end

	if progressionService.SaveProfile and (not progressionService.CanSaveProfile or progressionService:CanSaveProfile(target)) then
		task.defer(function()
			progressionService:SaveProfile(target)
		end)
	end

	print("[DevAdminData]", admin.Name, actionName, target.Name, detail or "")
end

function DevAdminService:GetDataManagerSnapshot(admin, payload)
	if not self:CanUseDataManager(admin) then
		return self:Result(false, "Not allowed.", {
			Data = {
				OnlinePlayers = self:GetOnlinePlayerList(),
			},
		})
	end

	local progressionService = self:GetProgressionService()
	if not progressionService then
		return self:Result(false, "ProgressionService unavailable.", {
			Data = {
				OnlinePlayers = self:GetOnlinePlayerList(),
			},
		})
	end

	local data = {
		OnlinePlayers = self:GetOnlinePlayerList(),
		Definitions = self:GetDataDefinitions(),
	}

	if typeof(payload) == "table" and (payload.TargetUserId or payload.UserId) then
		local target, targetError = self:GetTargetPlayerFromPayload(payload)
		if not target then
			return self:Result(false, targetError, { Data = data })
		end

		local profile, profileError = self:GetLoadedProfile(progressionService, target)
		if not profile then
			return self:Result(false, profileError, { Data = data })
		end

		data.TargetData = self:BuildDataSnapshot(target, progressionService, profile)
	end

	return self:Result(true, "Data Manager snapshot loaded.", {
		Data = data,
	})
end

function DevAdminService:ValidateCharacter(characterName)
	return typeof(characterName) == "string" and CharacterData[characterName] ~= nil
end

function DevAdminService:ValidateSkin(characterName, skinName)
	if not self:ValidateCharacter(characterName) or typeof(skinName) ~= "string" then
		return false
	end

	local skinConfig = self:GetSkinConfigForName(characterName)
	if skinConfig and skinConfig.Skins then
		return skinConfig.Skins[skinName] ~= nil
	end

	return skinName == "Default"
end

function DevAdminService:ApplyDataManagerAction(admin, payload)
	if not self:CanUseDataManager(admin) then
		return self:Result(false, "Not allowed.")
	end

	if typeof(payload) ~= "table" then
		return self:Result(false, "Invalid payload.")
	end

	local actionName = payload.Action
	if typeof(actionName) ~= "string" then
		return self:Result(false, "Missing data action.")
	end

	local target, targetError = self:GetTargetPlayerFromPayload(payload)
	if not target then
		return self:Result(false, targetError)
	end

	local progressionService = self:GetProgressionService()
	local profile, profileError = self:GetLoadedProfile(progressionService, target)
	if not profile then
		return self:Result(false, profileError)
	end

	profile.OwnedCharacters = profile.OwnedCharacters or {}
	profile.OwnedSkins = profile.OwnedSkins or {}
	profile.EquippedSkins = profile.EquippedSkins or {}
	profile.OwnedTitles = profile.OwnedTitles or {}
	profile.OwnedEmotes = profile.OwnedEmotes or {}
	profile.EquippedEmotes = profile.EquippedEmotes or {}
	profile.Lore = profile.Lore or {}
	profile.Equipped = profile.Equipped or {}

	local message = nil
	local detail = nil

	if actionName == "SetDust" or actionName == "AddDust" or actionName == "SetKills" or actionName == "AddKills" then
		local value = (actionName == "AddDust" or actionName == "AddKills") and self:ToDeltaInteger(payload.Amount) or self:ToSafeInteger(payload.Amount)
		if value == nil then
			return self:Result(false, "Invalid amount.")
		end

		if actionName == "SetDust" then
			profile.Dust = value
			message = string.format("Set Dust for %s to %d.", target.Name, value)
		elseif actionName == "AddDust" then
			profile.Dust = math.clamp(math.floor((profile.Dust or 0) + value), 0, MAX_DATA_VALUE)
			message = string.format("Added %d Dust to %s.", value, target.Name)
		elseif actionName == "SetKills" then
			profile.Kills = value
			message = string.format("Set Kills for %s to %d.", target.Name, value)
		elseif actionName == "AddKills" then
			profile.Kills = math.clamp(math.floor((profile.Kills or 0) + value), 0, MAX_DATA_VALUE)
			message = string.format("Added %d Kills to %s.", value, target.Name)
		end
		detail = tostring(value)
	elseif actionName == "UnlockCharacter" or actionName == "RelockCharacter" or actionName == "EquipCharacter" then
		local characterName = payload.CharacterName
		if not self:ValidateCharacter(characterName) then
			return self:Result(false, "Unknown character.")
		end

		if actionName == "UnlockCharacter" then
			profile.OwnedCharacters[characterName] = true
			message = "Unlocked character " .. characterName .. "."
		elseif actionName == "RelockCharacter" then
			local data = CharacterData[characterName]
			if data.Free == true or (data.Cost or 0) <= 0 then
				return self:Result(false, "Cannot relock a default/free character.")
			end
			profile.OwnedCharacters[characterName] = nil
			if target:GetAttribute("CharacterName") == characterName then
				target:SetAttribute("CharacterName", "Chara")
			end
			message = "Relocked character " .. characterName .. "."
		else
			profile.OwnedCharacters[characterName] = true
			local characterService = self:GetDevServices().CharacterService
			if characterService and characterService.SetCharacter then
				characterService:SetCharacter(target, characterName, {
					SkinName = profile.EquippedSkins[characterName],
					MorphEnabled = target:GetAttribute("MorphEnabled") == true,
				})
			else
				target:SetAttribute("CharacterName", characterName)
			end
			message = "Equipped character " .. characterName .. "."
		end
		detail = characterName
	elseif actionName == "UnlockAllCharacters" or actionName == "RelockAllNonDefaultCharacters" then
		for characterName, data in pairs(CharacterData) do
			if actionName == "UnlockAllCharacters" then
				profile.OwnedCharacters[characterName] = true
			elseif not (data.Free == true or (data.Cost or 0) <= 0) then
				profile.OwnedCharacters[characterName] = nil
			end
		end
		message = actionName == "UnlockAllCharacters" and "Unlocked all characters." or "Relocked all non-default characters."
	elseif actionName == "UnlockSkin" or actionName == "RelockSkin" or actionName == "EquipSkin" then
		local characterName = payload.CharacterName
		local skinName = payload.SkinName
		if not self:ValidateSkin(characterName, skinName) then
			return self:Result(false, "Unknown skin.")
		end

		profile.OwnedSkins[characterName] = profile.OwnedSkins[characterName] or {}

		if actionName == "UnlockSkin" then
			profile.OwnedSkins[characterName][skinName] = true
			message = "Unlocked skin " .. characterName .. " / " .. skinName .. "."
		elseif actionName == "RelockSkin" then
			local defaultSkin = progressionService.GetDefaultSkinName and progressionService:GetDefaultSkinName(characterName) or "Default"
			if skinName == defaultSkin then
				return self:Result(false, "Cannot relock the default skin.")
			end
			profile.OwnedSkins[characterName][skinName] = nil
			if profile.EquippedSkins[characterName] == skinName then
				profile.EquippedSkins[characterName] = defaultSkin
			end
			message = "Relocked skin " .. characterName .. " / " .. skinName .. "."
		else
			profile.OwnedSkins[characterName][skinName] = true
			profile.EquippedSkins[characterName] = skinName
			target:SetAttribute("EquippedSkin_" .. characterName, skinName)
			message = "Equipped skin " .. characterName .. " / " .. skinName .. "."
		end
		detail = characterName .. "/" .. skinName
	elseif actionName == "UnlockAllSkinsForCharacter" or actionName == "UnlockAllSkinsGlobal" or actionName == "RelockAllSkins" then
		local function unlockSkinsFor(characterName)
			local skinConfig = self:GetSkinConfigForName(characterName)
			profile.OwnedSkins[characterName] = profile.OwnedSkins[characterName] or {}
			if skinConfig and skinConfig.Skins then
				for skinName in pairs(skinConfig.Skins) do
					profile.OwnedSkins[characterName][skinName] = true
				end
			else
				profile.OwnedSkins[characterName].Default = true
			end
		end

		local function relockSkinsFor(characterName)
			local defaultSkin = progressionService.GetDefaultSkinName and progressionService:GetDefaultSkinName(characterName) or "Default"
			local ownedSkins = profile.OwnedSkins[characterName]
			if typeof(ownedSkins) ~= "table" then
				ownedSkins = {}
				profile.OwnedSkins[characterName] = ownedSkins
			end

			for skinName in pairs(ownedSkins) do
				if skinName ~= defaultSkin then
					ownedSkins[skinName] = nil
				end
			end

			ownedSkins[defaultSkin] = true

			if profile.EquippedSkins[characterName] ~= defaultSkin then
				profile.EquippedSkins[characterName] = defaultSkin
				target:SetAttribute("EquippedSkin_" .. characterName, defaultSkin)
			end
		end

		if actionName == "UnlockAllSkinsForCharacter" then
			local characterName = payload.CharacterName
			if not self:ValidateCharacter(characterName) then
				return self:Result(false, "Unknown character.")
			end
			unlockSkinsFor(characterName)
			message = "Unlocked all skins for " .. characterName .. "."
		else
			for characterName in pairs(CharacterData) do
				if actionName == "RelockAllSkins" then
					relockSkinsFor(characterName)
				else
					unlockSkinsFor(characterName)
				end
			end
			message = actionName == "RelockAllSkins"
				and "Relocked all non-default skins for " .. target.Name .. "."
				or "Unlocked all skins globally."
			detail = actionName == "RelockAllSkins" and target.Name or nil
		end
	elseif actionName == "UnlockTitle" or actionName == "RelockTitle" or actionName == "EquipTitle" then
		local titleId = payload.TitleId
		if typeof(titleId) ~= "string" or not TitleData[titleId] then
			return self:Result(false, "Unknown title.")
		end
		if actionName == "UnlockTitle" then
			profile.OwnedTitles[titleId] = true
			message = "Unlocked title " .. titleId .. "."
		elseif actionName == "RelockTitle" then
			if titleId == NONE_TITLE_ID then
				return self:Result(false, "Cannot relock None.")
			end
			profile.OwnedTitles[titleId] = nil
			if profile.EquippedTitle == titleId then
				profile.EquippedTitle = NONE_TITLE_ID
				profile.Equipped.Title = NONE_TITLE_ID
			end
			message = "Relocked title " .. titleId .. "."
		else
			profile.OwnedTitles[titleId] = true
			profile.EquippedTitle = titleId
			profile.Equipped.Title = titleId
			if progressionService.ApplyEquippedTitleToCharacter then
				progressionService:ApplyEquippedTitleToCharacter(target, target.Character, true)
			end
			message = "Equipped title " .. titleId .. "."
		end
		detail = titleId
	elseif actionName == "UnlockAllTitles" then
		for titleId in pairs(TitleData) do
			profile.OwnedTitles[titleId] = true
		end
		message = "Unlocked all titles."
	elseif actionName == "UnlockEmote" or actionName == "RelockEmote" or actionName == "EquipEmoteSlot" then
		local emoteId = payload.EmoteId
		if typeof(emoteId) ~= "string" or not EmoteData[emoteId] then
			return self:Result(false, "Unknown emote.")
		end
		if actionName == "UnlockEmote" then
			profile.OwnedEmotes[emoteId] = true
			message = "Unlocked emote " .. emoteId .. "."
		elseif actionName == "RelockEmote" then
			local data = EmoteData[emoteId]
			if data.Starter == true or data.Free == true or (data.Cost or 0) <= 0 then
				return self:Result(false, "Cannot relock a default/free emote.")
			end
			profile.OwnedEmotes[emoteId] = nil
			for slot, equippedId in pairs(profile.EquippedEmotes) do
				if equippedId == emoteId then
					profile.EquippedEmotes[slot] = nil
				end
			end
			message = "Relocked emote " .. emoteId .. "."
		else
			local slot = math.floor(tonumber(payload.Slot) or 0)
			if slot < 1 or slot > MAX_EMOTE_SLOTS then
				return self:Result(false, "Invalid emote slot.")
			end
			profile.OwnedEmotes[emoteId] = true
			profile.EquippedEmotes[slot] = emoteId
			message = string.format("Assigned emote %s to slot %d.", emoteId, slot)
		end
		detail = emoteId
	elseif actionName == "UnlockAllEmotes" then
		for emoteId in pairs(EmoteData) do
			profile.OwnedEmotes[emoteId] = true
		end
		message = "Unlocked all emotes."
	elseif actionName == "UnlockLore" or actionName == "LockLore" then
		local loreId = payload.LoreId
		if typeof(loreId) ~= "string" or not LoreFragmentData[loreId] then
			return self:Result(false, "Unknown lore fragment.")
		end
		profile.Lore[loreId] = actionName == "UnlockLore" or nil
		message = (actionName == "UnlockLore" and "Unlocked/read lore " or "Locked/unread lore ") .. loreId .. "."
		detail = loreId
	elseif actionName == "UnlockAllLore" or actionName == "ResetLore" then
		if actionName == "UnlockAllLore" then
			for loreId in pairs(LoreFragmentData) do
				profile.Lore[loreId] = true
			end
			message = "Unlocked/read all lore fragments."
		else
			profile.Lore = {}
			message = "Reset lore fragments."
		end
	else
		return self:Result(false, "Unknown data action.")
	end

	self:FinalizeDataEdit(admin, target, progressionService, actionName, detail)

	return self:Result(true, message or "Data updated.", {
		Data = {
			OnlinePlayers = self:GetOnlinePlayerList(),
			Definitions = self:GetDataDefinitions(),
			TargetData = self:BuildDataSnapshot(target, progressionService, profile),
		},
	})
end

local NUKE_ASCENT_HEIGHT = 420
local NUKE_FORWARD_DISTANCE = 70
local NUKE_BLAST_RADIUS = 620
local NUKE_BLAST_DURATION = 10
local NUKE_MAX_NEONIZED_PARTS = 8000
local NUKE_PART_FORCE = 1000

function DevAdminService:GetCinematicRemote()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	return remotes and remotes:FindFirstChild("CinematicRemote") or nil
end

function DevAdminService:FireNukeShake(intensity, roughness, duration)
	local remote = self:GetCinematicRemote()
	if not remote or not remote:IsA("RemoteEvent") then
		return
	end

	remote:FireAllClients({
		Action = "CameraShakeOnce",
		Intensity = intensity,
		Roughness = roughness,
		Duration = duration,
	})
end

function DevAdminService:FireNukeImpactFrame(mode, duration, intensity)
	local remote = self:GetCinematicRemote()
	if not remote or not remote:IsA("RemoteEvent") then
		return
	end

	remote:FireAllClients({
		Action = "ImpactFrame",
		Mode = mode or "Invert",
		Duration = duration or 0.18,

		-- extra values are harmless if the client ignores them,
		-- but useful if your cinematic client supports stronger frames.
		Intensity = intensity or 1,
		Color = Color3.fromRGB(255, 255, 255),
		Contrast = 4.5,
		Saturation = -1,
		Brightness = 0.25,
	})
end

function DevAdminService:GetNukeRoot(admin)
	local character = admin and admin.Character
	if not character or not character:IsA("Model") then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
		or character:FindFirstChild("Torso")
		or character:FindFirstChild("UpperTorso")
		or character.PrimaryPart

	if root and root:IsA("BasePart") then
		return root
	end

	return nil
end

function DevAdminService:GetNukeOrigin(admin)
	local root = self:GetNukeRoot(admin)

	if root then
		return root.Position + Vector3.new(0, 5, 0)
	end

	return Vector3.new(0, 20, 0)
end

function DevAdminService:GetNukeForward(admin)
	local root = self:GetNukeRoot(admin)

	if root then
		local look = root.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)

		if flat.Magnitude > 0.05 then
			return flat.Unit
		end
	end

	return Vector3.new(0, 0, -1)
end

function DevAdminService:FindNukeTemplate()
	local exact = script.Parent:FindFirstChild("Nuke")
	if exact and exact:IsA("Model") then
		return exact
	end

	local alternate = script.Parent:FindFirstChild("NukeModel")
	if alternate and alternate:IsA("Model") then
		return alternate
	end

	for _, child in ipairs(script.Parent:GetChildren()) do
		if child:IsA("Model") and string.find(string.lower(child.Name), "nuke") then
			return child
		end
	end

	return nil
end

function DevAdminService:FindBoomSound()
	local exact = script.Parent:FindFirstChild("Boom")
	if exact and exact:IsA("Sound") then
		return exact
	end

	for _, child in ipairs(script.Parent:GetDescendants()) do
		if child:IsA("Sound") and child.Name == "Boom" then
			return child
		end
	end

	return nil
end

function DevAdminService:SetModelRuntimeSafe(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
end

function DevAdminService:FindNukeMissile(model)
	if not model then
		return nil
	end

	if model:IsA("Model") and model.PrimaryPart then
		return model
	end

	local childMissile = model:FindFirstChild("Missle", true)
		or model:FindFirstChild("Missile", true)
		or model:FindFirstChild("Rocket", true)

	if childMissile then
		return childMissile
	end

	if model:IsA("Model") then
		local root = model:FindFirstChild("Base", true)
			or model:FindFirstChild("HumanoidRootPart", true)
			or model:FindFirstChildWhichIsA("BasePart", true)

		if root and root:IsA("BasePart") then
			model.PrimaryPart = root
			return model
		end
	end

	return nil
end

function DevAdminService:SetNukeEmittersEnabled(instance, enabled)
	if not instance then
		return
	end

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("ParticleEmitter")
			or descendant:IsA("Smoke")
			or descendant:IsA("Fire")
			or descendant:IsA("Trail")
		then
			descendant.Enabled = enabled == true
		end
	end
end

function DevAdminService:PlayNukeSound(soundTemplate, parent, position)
	if not soundTemplate then
		return
	end

	local soundPart = Instance.new("Part")
	soundPart.Name = "DevAdminNukeSound"
	soundPart.Anchored = true
	soundPart.CanCollide = false
	soundPart.CanTouch = false
	soundPart.CanQuery = false
	soundPart.Transparency = 1
	soundPart.Size = Vector3.new(1, 1, 1)
	soundPart.Position = position
	soundPart.Parent = parent or Workspace

	local sound = soundTemplate:Clone()
	sound.Parent = soundPart
	sound:Play()

	Debris:AddItem(soundPart, math.max(sound.TimeLength, 5) + 2)
end

function DevAdminService:StartNukeLightFlash(model, state)
	if not model then
		return
	end

	task.spawn(function()
		local lights = {}

		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("PointLight") or descendant:IsA("SpotLight") or descendant:IsA("SurfaceLight") then
				table.insert(lights, descendant)
			end
		end

		while state.Active == true and model.Parent do
			for _, light in ipairs(lights) do
				if light.Parent then
					light.Enabled = not light.Enabled
				end
			end

			task.wait(0.12)
		end

		for _, light in ipairs(lights) do
			if light.Parent then
				light.Enabled = false
			end
		end
	end)
end

function DevAdminService:TweenNukeInstance(instance, targetCFrame, duration, easingStyle, easingDirection)
	if not instance or not instance.Parent then
		return
	end

	local startCFrame

	if instance:IsA("Model") then
		startCFrame = instance:GetPivot()
	elseif instance:IsA("BasePart") then
		startCFrame = instance.CFrame
	else
		return
	end

	local value = Instance.new("CFrameValue")
	value.Value = startCFrame

	local connection = value:GetPropertyChangedSignal("Value"):Connect(function()
		if not instance.Parent then
			return
		end

		if instance:IsA("Model") then
			instance:PivotTo(value.Value)
		elseif instance:IsA("BasePart") then
			instance.CFrame = value.Value
		end
	end)

	local tween = TweenService:Create(
		value,
		TweenInfo.new(
			duration,
			easingStyle or Enum.EasingStyle.Quad,
			easingDirection or Enum.EasingDirection.InOut
		),
		{ Value = targetCFrame }
	)

	tween:Play()
	tween.Completed:Wait()

	if connection then
		connection:Disconnect()
	end

	value:Destroy()
end

function DevAdminService:CreateFallbackMissile(position)
	local missile = Instance.new("Part")
	missile.Name = "DevAdminFallbackMissile"
	missile.Anchored = true
	missile.CanCollide = false
	missile.CanTouch = false
	missile.CanQuery = false
	missile.Material = Enum.Material.Neon
	missile.Color = Color3.fromRGB(255, 245, 210)
	missile.Size = Vector3.new(3, 12, 3)
	missile.CFrame = CFrame.new(position)
	missile.Parent = Workspace

	local fire = Instance.new("Fire")
	fire.Name = "Fire"
	fire.Heat = 20
	fire.Size = 12
	fire.Enabled = false
	fire.Parent = missile

	local smoke = Instance.new("Smoke")
	smoke.Name = "Smoke"
	smoke.Opacity = 0.45
	smoke.RiseVelocity = 10
	smoke.Size = 12
	smoke.Enabled = false
	smoke.Parent = missile

	Debris:AddItem(missile, 24)
	return missile
end

function DevAdminService:IsNukeTransformablePart(part, nukeModel)
	if not part or not part:IsA("BasePart") then
		return false
	end

	if nukeModel and part:IsDescendantOf(nukeModel) then
		return false
	end

	if part:IsDescendantOf(script.Parent) then
		return false
	end

	if part.Name == "Terrain" then
		return false
	end

	-- Avoid turning entire giant baseplates/maps into physics bombs.
	if part.Size.Magnitude > 180 then
		return false
	end

	return true
end

function DevAdminService:NeonizeNukePart(part, origin, forceScale)
	if not part or not part.Parent then
		return
	end

	local direction = part.Position - origin
	if direction.Magnitude < 0.05 then
		direction = Vector3.new(
			math.random(-100, 100) / 100,
			1,
			math.random(-100, 100) / 100
		)
	end

	direction = direction.Unit

	pcall(function()
		part.Material = Enum.Material.Neon

		if math.random(1, 2) == 1 then
			part.Color = Color3.fromRGB(95, 255, 70)
		else
			part.Color = Color3.fromRGB(255, 238, 80)
		end

		part.Anchored = false
		part.CanCollide = true
		part.CanTouch = true
		part.CanQuery = true

		local mass = math.max(part.AssemblyMass, 1)
		local impulse = (direction * forceScale + Vector3.new(0, forceScale * 0.75, 0)) * mass
		part:ApplyImpulse(impulse)
		part.AssemblyAngularVelocity = Vector3.new(
			math.random(-18, 18),
			math.random(-18, 18),
			math.random(-18, 18)
		)
	end)
end

function DevAdminService:ApplyNukeTouchEffect(origin, radius, nukeModel, alreadyTouched)
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = nukeModel and { nukeModel } or {}

	local parts = Workspace:GetPartBoundsInRadius(origin, radius, overlapParams)
	local transformed = 0

	for _, part in ipairs(parts) do
		if transformed >= 28 then
			break
		end

		if not alreadyTouched[part] and self:IsNukeTransformablePart(part, nukeModel) then
			alreadyTouched[part] = true
			transformed += 1

			local distance = (part.Position - origin).Magnitude
			local falloff = 1 - math.clamp(distance / math.max(radius, 1), 0, 0.9)
			self:NeonizeNukePart(part, origin, NUKE_PART_FORCE * (0.55 + falloff))
		end
	end
end

function DevAdminService:CreateNukeBlast(position, nukeModel)
	local touchedParts = {}
	local blast = Instance.new("Part")
	blast.Name = "DevAdminNukeBlast"
	blast.Shape = Enum.PartType.Ball
	blast.Anchored = true
	blast.CanCollide = false
	blast.CanTouch = false
	blast.CanQuery = false
	blast.Material = Enum.Material.Neon
	blast.Color = Color3.fromRGB(255, 245, 210)
	blast.Transparency = 0.08
	blast.Size = Vector3.new(8, 8, 8)
	blast.CFrame = CFrame.new(position)
	blast.Parent = Workspace

	local inner = Instance.new("Part")
	inner.Name = "DevAdminNukeGreenCore"
	inner.Shape = Enum.PartType.Ball
	inner.Anchored = true
	inner.CanCollide = false
	inner.CanTouch = false
	inner.CanQuery = false
	inner.Material = Enum.Material.Neon
	inner.Color = Color3.fromRGB(115, 255, 55)
	inner.Transparency = 0.35
	inner.Size = Vector3.new(5, 5, 5)
	inner.CFrame = CFrame.new(position)
	inner.Parent = Workspace

	local blastTween = TweenService:Create(
		blast,
		TweenInfo.new(NUKE_BLAST_DURATION, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{
			Size = Vector3.new(NUKE_BLAST_RADIUS, NUKE_BLAST_RADIUS, NUKE_BLAST_RADIUS),
			Transparency = 1,
		}
	)

	local innerTween = TweenService:Create(
		inner,
		TweenInfo.new(NUKE_BLAST_DURATION * 0.82, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{
			Size = Vector3.new(NUKE_BLAST_RADIUS * 0.72, NUKE_BLAST_RADIUS * 0.72, NUKE_BLAST_RADIUS * 0.72),
			Transparency = 1,
		}
	)

	blastTween:Play()
	innerTween:Play()

	task.spawn(function()
		local startTime = os.clock()
		local lastPulse = 0

		while os.clock() - startTime < NUKE_BLAST_DURATION do
			local alpha = math.clamp((os.clock() - startTime) / NUKE_BLAST_DURATION, 0, 1)
			local currentRadius = math.max(24, (NUKE_BLAST_RADIUS * 0.5) * alpha)

			if os.clock() - lastPulse > 0.22 then
				lastPulse = os.clock()

				if table.getn(touchedParts) >= NUKE_MAX_NEONIZED_PARTS then
					break
				end

				self:ApplyNukeTouchEffect(position, currentRadius, nukeModel, touchedParts)
			end

			task.wait(0.05)
		end
	end)

	Debris:AddItem(blast, NUKE_BLAST_DURATION + 1)
	Debris:AddItem(inner, NUKE_BLAST_DURATION + 1)
end

function DevAdminService:KickEveryoneForNuke()
	for _, target in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			target:Kick("The server was nuked.")
		end)
	end
end

function DevAdminService:RunNukeSequence(admin, origin)
	local nukeTemplate = self:FindNukeTemplate()
	local boomTemplate = self:FindBoomSound()
	local forward = self:GetNukeForward(admin)
	local nukeModel = nil
	local lightState = {
		Active = true,
	}

	local launchOrigin = origin
	local highPoint = launchOrigin + Vector3.new(0, NUKE_ASCENT_HEIGHT, 0) + forward * 35
	local impactPoint = launchOrigin + forward * NUKE_FORWARD_DISTANCE
	impactPoint = Vector3.new(impactPoint.X, launchOrigin.Y, impactPoint.Z)

	if not nukeTemplate then
		warn("[DevAdminABUSE] Nuke model missing under ServerScriptService/TestTools; using fallback visual.")
	else
		nukeModel = nukeTemplate:Clone()
		nukeModel.Name = "DevAdminRuntimeNuke"
		nukeModel.Parent = Workspace
		self:SetModelRuntimeSafe(nukeModel)
		nukeModel:PivotTo(CFrame.lookAt(launchOrigin, highPoint))
		Debris:AddItem(nukeModel, 34)
	end

	if not boomTemplate then
		warn("[DevAdminABUSE] Boom sound missing under ServerScriptService/TestTools.")
	end

	print("[DevAdminABUSE]", admin.Name, "launched server nuke.")

	self:FireNukeShake(2.2, 18, 3.5)
	self:FireNukeImpactFrame("RedBlack", 0.1, 1.8)

	local siren = nukeModel and (nukeModel:FindFirstChild("Siren", true) or nukeModel:FindFirstChild("Alarm", true))
	if siren and siren:IsA("Sound") then
		siren.Looped = true
		siren:Play()
	end

	self:StartNukeLightFlash(nukeModel, lightState)
	task.wait(1.5)

	local missile = self:FindNukeMissile(nukeModel)
	if not missile then
		missile = self:CreateFallbackMissile(launchOrigin)
	end

	self:SetNukeEmittersEnabled(missile or nukeModel, true)
	self:FireNukeShake(3.5, 24, 4.2)

	local missileStart = missile:IsA("Model") and missile:GetPivot() or missile.CFrame
	local upCFrame = CFrame.lookAt(highPoint, highPoint + Vector3.new(0, 1, 0)) * CFrame.Angles(math.rad(-12), 0, 0)

	self:TweenNukeInstance(
		missile,
		upCFrame,
		4.8,
		Enum.EasingStyle.Quart,
		Enum.EasingDirection.Out
	)

	self:FireNukeShake(4.2, 28, 1.8)
	self:FireNukeImpactFrame("RedBlack", 0.08, 2.5)

	local fallStart = missile:IsA("Model") and missile:GetPivot() or missile.CFrame
	local fallTarget = CFrame.lookAt(
		impactPoint + Vector3.new(0, 4, 0),
		impactPoint - Vector3.new(0, 80, 0) + forward
	)

	self:TweenNukeInstance(
		missile,
		fallTarget,
		3.4,
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.In
	)

	lightState.Active = false

	if siren and siren.Parent then
		siren:Stop()
	end

	if missile and missile.Parent then
		self:SetNukeEmittersEnabled(missile, false)
	end

	self:PlayNukeSound(boomTemplate, Workspace, impactPoint)

	-- Impact frame: intentionally insane.
	self:FireNukeImpactFrame("Invert", 0.48, 7.5)
	self:FireNukeShake(16, 55, 1.4)
	task.wait(0.1)
	self:FireNukeImpactFrame("White", 0.32, 8.5)
	self:FireNukeShake(20, 70, 1.1)

	self:CreateNukeBlast(impactPoint, nukeModel)

	task.wait(0.45)

	for _ = 1, 10 do
		self:FireNukeShake(11, 45, 0.9)
		task.wait(0.55)
	end

	self:FireNukeShake(6, 25, 3.2)
	task.wait(NUKE_BLAST_DURATION * 0.55)

	if missile and missile.Parent and missile.Name == "DevAdminFallbackMissile" then
		missile:Destroy()
	end

	if nukeModel and nukeModel.Parent then
		nukeModel:Destroy()
	end
end

function DevAdminService:StartNukeServer(admin)
	if self.NukeRunning then
		return self:Result(false, "Nuke already launched.")
	end

	self.NukeRunning = true

	local origin = self:GetNukeOrigin(admin)

	task.spawn(function()
		local ok, err = pcall(function()
			self:RunNukeSequence(admin, origin)
		end)

		if not ok then
			warn("[DevAdminABUSE] Nuke sequence error:", err)
			self:CreateNukeBlast(origin, nil)
			self:FireNukeImpactFrame("Invert", 0.45, 7)
			self:FireNukeShake(16, 55, 2.2)
			task.wait(3)
		end

		self:KickEveryoneForNuke()
	end)

	return self:Result(true, "Nuke launched.")
end

function DevAdminService:HandleAbuseAction(player, payload)
	if not self:CanUseAbuseTools(player) then
		return self:Result(false, "Not allowed.")
	end

	if typeof(payload) ~= "table" then
		return self:Result(false, "Invalid payload.")
	end

	if payload.Action == "NukeServer" then
		return self:StartNukeServer(player)
	end

	return self:Result(false, "Unknown abuse action.")
end

function DevAdminService:GetDebugDummiesFolder()
	local folder = Workspace:FindFirstChild("DebugDummies")

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "DebugDummies"
		folder.Parent = Workspace
	end

	return folder
end

function DevAdminService:GetUsableCharacterModel(characterModelAsset, modelName)
	if not characterModelAsset then
		return nil
	end

	if characterModelAsset:IsA("Model") then
		if typeof(modelName) == "string" and modelName ~= "" and characterModelAsset.Name ~= modelName then
			return nil
		end

		return characterModelAsset
	end

	if characterModelAsset:IsA("Folder") then
		if typeof(modelName) == "string" and modelName ~= "" then
			local namedModel = characterModelAsset:FindFirstChild(modelName)
			if namedModel and namedModel:IsA("Model") then
				return namedModel
			end
		end

		local defaultModel = characterModelAsset:FindFirstChild("Default")
		if defaultModel and defaultModel:IsA("Model") then
			return defaultModel
		end

		local directModel = characterModelAsset:FindFirstChildWhichIsA("Model")

		if directModel then
			return directModel
		end

		return characterModelAsset:FindFirstChildWhichIsA("Model", true)
	end

	return characterModelAsset:FindFirstChildWhichIsA("Model", true)
end

function DevAdminService:GetSkinConfig(characterFolder)
	local modulesFolder = characterFolder and characterFolder:FindFirstChild("Modules")
	local skinModule = modulesFolder and modulesFolder:FindFirstChild("SkinModule")

	if not skinModule then
		return nil
	end

	local success, skinConfig = pcall(require, skinModule)
	if not success or typeof(skinConfig) ~= "table" then
		warn("[DevAdminService] Failed to load SkinModule for:", characterFolder.Name)
		return nil
	end

	return skinConfig
end

function DevAdminService:GetValidCharacterModels()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local characters = assets and assets:FindFirstChild("Characters")
	local models = {}

	if not characters then
		warn("[DevAdminService] Missing ReplicatedStorage > Assets > Characters")
		return models
	end

	for _, characterFolder in ipairs(characters:GetChildren()) do
		if not characterFolder:IsA("Folder") then
			continue
		end

		local characterModelAsset = characterFolder:FindFirstChild("CharacterModel")
		local skinConfig = self:GetSkinConfig(characterFolder)
		local foundSkinModel = false

		if skinConfig and typeof(skinConfig.Skins) == "table" then
			for skinName, skinData in pairs(skinConfig.Skins) do
				local modelName = typeof(skinData) == "table" and skinData.CharacterModelName or nil
				local model = self:GetUsableCharacterModel(characterModelAsset, modelName)

				if model and model:IsA("Model") then
					foundSkinModel = true
					table.insert(models, {
						CharacterName = characterFolder.Name,
						SkinName = skinName,
						Model = model,
					})
				end
			end
		end

		if not foundSkinModel then
			local model = self:GetUsableCharacterModel(characterModelAsset)

			if model and model:IsA("Model") then
				table.insert(models, {
					CharacterName = characterFolder.Name,
					SkinName = (skinConfig and skinConfig.DefaultSkin) or "Default",
					Model = model,
				})
			else
				warn("[DevAdminService] No usable CharacterModel found for:", characterFolder.Name)
			end
		end
	end

	if #models == 0 then
		warn("[DevAdminService] No valid CharacterModel assets found under:", characters:GetFullName())
	end

	return models
end

function DevAdminService:ValidateDummyFeatures(features)
	local count = 0

	for tagName in pairs(EXCLUSIVE_DUMMY_TAGS) do
		if features[tagName] == true then
			count += 1
		end
	end

	return count <= 1
end

function DevAdminService:GetDummyName(features)
	local parts = {}

	if features.Moving then
		table.insert(parts, "Moving")
	end
	if features.Block then
		table.insert(parts, "Blocking")
	end
	if features.Combo then
		table.insert(parts, "Combo")
	end
	if features.Aircombo then
		table.insert(parts, "AirCombo")
	end
	if features.SOULBURST then
		table.insert(parts, "SOULBURST")
	end
	if features.Super then
		table.insert(parts, "SUPER")
	end
	if features.TRUE then
		table.insert(parts, "TRUE")
	end
	if features.Respawn then
		table.insert(parts, "Respawn")
	end

	if #parts == 0 then
		return "BasicDebugDummy"
	end

	return table.concat(parts, "") .. "Dummy"
end

function DevAdminService:GetModelRoot(model)
	return model:FindFirstChild("HumanoidRootPart")
		or model:FindFirstChild("Torso")
		or model:FindFirstChild("UpperTorso")
		or model.PrimaryPart
end

function DevAdminService:ApplyDummyAttributes(dummy, features, sourceCharacterName, sourceSkinName)
	dummy:SetAttribute("DebugDummy", true)
	dummy:SetAttribute("CharacterName", sourceCharacterName)
	dummy:SetAttribute("SourceCharacterName", sourceCharacterName)
	dummy:SetAttribute("SkinName", sourceSkinName or "Default")
	dummy:SetAttribute("SourceSkinName", sourceSkinName or "Default")
	dummy:SetAttribute("SelectedSkin", sourceSkinName or "Default")
	dummy:SetAttribute("EquippedSkin_" .. tostring(sourceCharacterName), sourceSkinName or "Default")
	dummy:SetAttribute("DummyType", self:GetDummyName(features))
	dummy:SetAttribute("MovingDummy", features.Moving == true)
	dummy:SetAttribute("BlockingDummy", features.Block == true)
	dummy:SetAttribute("BlockDummy", features.Block == true)
	dummy:SetAttribute("ComboDummy", features.Combo == true)
	dummy:SetAttribute("AirComboDummy", features.Aircombo == true)
	dummy:SetAttribute("AircomboDummy", features.Aircombo == true)
	dummy:SetAttribute("SoulBurstDummy", features.SOULBURST == true)
	dummy:SetAttribute("CanSoulBurst", features.SOULBURST == true)
	dummy:SetAttribute("SuperDummy", features.Super == true)
	dummy:SetAttribute("ImmortalDummy", features.Immortal == true or features.Super == true)
	dummy:SetAttribute("TRUEDummy", features.TRUE == true)
	dummy:SetAttribute("TrueDummy", features.TRUE == true)
	dummy:SetAttribute("RespawnDummy", features.Respawn == true)
	dummy:SetAttribute("MorphEnabled", true)
	dummy:SetAttribute("CombatMode", "Base")
	dummy:SetAttribute("AwakeningActive", false)
	dummy:SetAttribute("AwakeningEndsAt", 0)

	if sourceCharacterName == "Chara" then
		dummy:SetAttribute("CharaSkin", sourceSkinName or "Default")
	end

	if features.Block then
		dummy:SetAttribute("BlockHeld", true)
	end

	CollectionService:AddTag(dummy, "DebugDummy")
	CollectionService:AddTag(dummy, "TargetableCharacter")
end

function DevAdminService:SpawnDummy(player, payload)
	if not self:CanUseCombatDebug(player) then
		return self:Result(false, "Not allowed.")
	end

	if typeof(payload) ~= "table" then
		return self:Result(false, "Invalid payload.")
	end

	local dummyType = payload.DummyType
	if typeof(dummyType) ~= "string" then
		return self:Result(false, "Missing dummy type.")
	end

	local features = DUMMY_TYPES[dummyType]
	if not features then
		return self:Result(false, "Unknown dummy type.")
	end

	if not self:ValidateDummyFeatures(features) then
		return self:Result(false, "Invalid dummy tag overlap.")
	end

	local _, _, developerRoot = self:GetPlayerCharacter(player)
	if not developerRoot then
		return self:Result(false, "No live developer character.")
	end

	local models = self:GetValidCharacterModels()
	if #models == 0 then
		return self:Result(false, "No valid CharacterModel assets found under ReplicatedStorage/Assets/Characters.")
	end

	local picked = models[math.random(1, #models)]
	local dummy = picked.Model:Clone()
	local humanoid = dummy:FindFirstChildOfClass("Humanoid")
	local root = self:GetModelRoot(dummy)

	if root and not dummy.PrimaryPart then
		dummy.PrimaryPart = root
	end

	if not humanoid or not root then
		dummy:Destroy()
		return self:Result(false, "Selected CharacterModel is missing Humanoid/root.")
	end

	dummy.Name = self:GetDummyName(features)
	self:ApplyDummyAttributes(dummy, features, picked.CharacterName, picked.SkinName)

	local folder = self:GetDebugDummiesFolder()
	dummy.Parent = folder

	local forward = developerRoot.CFrame.LookVector
	local flatForward = Vector3.new(forward.X, 0, forward.Z)
	if flatForward.Magnitude < 0.05 then
		flatForward = Vector3.new(0, 0, -1)
	else
		flatForward = flatForward.Unit
	end

	local spawnPosition = developerRoot.Position + flatForward * math.random(8, 12)
	local cframe = CFrame.lookAt(spawnPosition, developerRoot.Position)
	dummy:PivotTo(cframe)

	local services = self:GetDevServices()
	if services.WeaponService and services.WeaponService.EquipWeapon then
		services.WeaponService:EquipWeapon(dummy, picked.CharacterName)
	end

	if services.WeaponService and services.WeaponService.SanitizeEquippedWeapons then
		services.WeaponService:SanitizeEquippedWeapons(dummy)
	end

	if services.CharacterMorphService and services.CharacterMorphService.ApplyCharacterCollisionRules then
		services.CharacterMorphService:ApplyCharacterCollisionRules(dummy)
	end

	if features.SOULBURST then
		dummy:SetAttribute("Soul", 0)
		dummy:SetAttribute("SoulBurst", 0)
	end

	local started, behaviorMessage = self:GetDummyController():Start(dummy, features, {
		CharacterName = picked.CharacterName,
		SkinName = picked.SkinName,
	})
	if not started then
		warn("[DevAdminService] Debug dummy behavior failed:", behaviorMessage)
	end

	local message = string.format(
		"Spawned %s as %s / %s.",
		dummy.Name,
		picked.CharacterName,
		picked.SkinName or "Default"
	)

	self:LogAction(player, "SpawnDummy", dummy.Name .. " " .. picked.CharacterName .. "/" .. tostring(picked.SkinName or "Default"))
	return self:Result(true, message, {
		DummyName = dummy.Name,
		SourceCharacterName = picked.CharacterName,
		SourceSkinName = picked.SkinName or "Default",
	})
end

function DevAdminService:ClearDebugDummies(player)
	if not self:CanUseCombatDebug(player) then
		return self:Result(false, "Not allowed.")
	end

	local folder = Workspace:FindFirstChild("DebugDummies")
	local count = 0

	if folder then
		for _, child in ipairs(folder:GetChildren()) do
			if child:GetAttribute("DebugDummy") == true or CollectionService:HasTag(child, "DebugDummy") then
				count += 1
				self:GetDummyController():Cleanup(child)
				child:Destroy()
			end
		end
	end

	self:LogAction(player, "ClearDebugDummies", tostring(count))
	return self:Result(true, "Cleared " .. tostring(count) .. " debug dummies.")
end

return DevAdminService
