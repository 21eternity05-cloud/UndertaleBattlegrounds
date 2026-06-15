local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

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

function DevAdminService.new()
	return setmetatable({
		DummyController = nil,
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

function DevAdminService:GetPermissionStatus(player)
	local role = self:GetRole(player)
	local canUseDevMenu = role ~= "None"

	return {
		CanUseDevMenu = canUseDevMenu,
		Role = role,
		CanUseCombatDebug = canUseDevMenu,
		CanUseDataManager = self:CanUseDataManager(player),
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
