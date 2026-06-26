local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

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

local function makeFallbackDebugDummyController(reason)
	warn("[DummyFactory] DebugDummyController unavailable:", reason)

	local fallback = {}
	fallback.__index = fallback

	function fallback.new(services)
		return setmetatable({
			Services = services or {},
		}, fallback)
	end

	function fallback:Start(dummy)
		warn("[DummyFactory] Starting debug dummy without behavior controller:", dummy and dummy.Name or "nil")
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

local DummyFactory = {}
DummyFactory.__index = DummyFactory

function DummyFactory.new(options)
	options = options or {}

	return setmetatable({
		DummyController = nil,
		GetServices = options.GetServices,
	}, DummyFactory)
end

function DummyFactory:GetDevServices()
	if typeof(self.GetServices) == "function" then
		return self.GetServices() or {}
	end

	return _G.UTBGDevServices or {}
end

function DummyFactory:GetDummyController()
	local services = self:GetDevServices()
	local currentServices = self.DummyController and self.DummyController.Services or {}

	if not self.DummyController
		or (not currentServices.BlockService and services.BlockService)
	then
		self.DummyController = DebugDummyControllerModule.new(services)
	end

	return self.DummyController
end

function DummyFactory:GetDebugDummiesFolder()
	local folder = Workspace:FindFirstChild("DebugDummies")

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "DebugDummies"
		folder.Parent = Workspace
	end

	return folder
end

function DummyFactory:GetUsableCharacterModel(characterModelAsset, modelName)
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

function DummyFactory:GetSkinConfig(characterFolder)
	local modulesFolder = characterFolder and characterFolder:FindFirstChild("Modules")
	local skinModule = modulesFolder and modulesFolder:FindFirstChild("SkinModule")

	if not skinModule then
		return nil
	end

	local success, skinConfig = pcall(require, skinModule)
	if not success or typeof(skinConfig) ~= "table" then
		warn("[DummyFactory] Failed to load SkinModule for:", characterFolder.Name)
		return nil
	end

	return skinConfig
end

function DummyFactory:GetValidCharacterModels()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local characters = assets and assets:FindFirstChild("Characters")
	local models = {}

	if not characters then
		warn("[DummyFactory] Missing ReplicatedStorage > Assets > Characters")
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
				warn("[DummyFactory] No usable CharacterModel found for:", characterFolder.Name)
			end
		end
	end

	if #models == 0 then
		warn("[DummyFactory] No valid CharacterModel assets found under:", characters:GetFullName())
	end

	return models
end

function DummyFactory:ValidateDummyFeatures(features)
	local count = 0

	for tagName in pairs(EXCLUSIVE_DUMMY_TAGS) do
		if features[tagName] == true then
			count += 1
		end
	end

	return count <= 1
end

function DummyFactory:GetDummyName(features)
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

function DummyFactory:GetModelRoot(model)
	return model:FindFirstChild("HumanoidRootPart")
		or model:FindFirstChild("Torso")
		or model:FindFirstChild("UpperTorso")
		or model.PrimaryPart
end

function DummyFactory:GetDummyFeatures(dummyType)
	if typeof(dummyType) ~= "string" then
		return nil
	end

	return DUMMY_TYPES[dummyType]
end

function DummyFactory:ApplyDummyAttributes(dummy, features, sourceCharacterName, sourceSkinName, options)
	options = options or {}

	local isDebugDummy = options.DebugDummy ~= false

	dummy:SetAttribute("DebugDummy", isDebugDummy)
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

	if isDebugDummy then
		CollectionService:AddTag(dummy, "DebugDummy")
	else
		CollectionService:RemoveTag(dummy, "DebugDummy")
	end

	CollectionService:AddTag(dummy, "TargetableCharacter")
end

function DummyFactory:SpawnConfiguredDummy(dummyType, spawnCFrame, options)
	options = options or {}

	local features = self:GetDummyFeatures(dummyType)
	if not features then
		return nil, "Unknown dummy type."
	end

	if not self:ValidateDummyFeatures(features) then
		return nil, "Invalid dummy tag overlap."
	end

	local models = self:GetValidCharacterModels()
	if #models == 0 then
		return nil, "No valid CharacterModel assets found under ReplicatedStorage/Assets/Characters."
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
		return nil, "Selected CharacterModel is missing Humanoid/root."
	end

	dummy.Name = options.Name or self:GetDummyName(features)
	self:ApplyDummyAttributes(dummy, features, picked.CharacterName, picked.SkinName, {
		DebugDummy = options.DebugDummy,
	})

	if typeof(options.Attributes) == "table" then
		for attributeName, value in pairs(options.Attributes) do
			dummy:SetAttribute(attributeName, value)
		end
	end

	if typeof(options.Tags) == "table" then
		for _, tagName in ipairs(options.Tags) do
			CollectionService:AddTag(dummy, tagName)
		end
	end

	local folder = options.Parent or self:GetDebugDummiesFolder()
	dummy.Parent = folder

	dummy:PivotTo(spawnCFrame or CFrame.new())

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero

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

	local startBehavior = options.StartBehavior ~= false
	local started = false
	local behaviorMessage = nil

	if startBehavior then
		started, behaviorMessage = self:GetDummyController():Start(dummy, features, {
			CharacterName = picked.CharacterName,
			SkinName = picked.SkinName,
		})

		if not started then
			warn("[DummyFactory] Dummy behavior failed:", behaviorMessage)
		end
	end

	return {
		Dummy = dummy,
		Features = features,
		CharacterName = picked.CharacterName,
		SkinName = picked.SkinName or "Default",
		BehaviorStarted = started == true,
		BehaviorMessage = behaviorMessage,
	}, nil
end

return DummyFactory
