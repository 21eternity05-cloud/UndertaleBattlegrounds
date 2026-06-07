local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterMorphService = {}
CharacterMorphService.__index = CharacterMorphService

function CharacterMorphService.new(config)
	local self = setmetatable({}, CharacterMorphService)

	self.Config = config
	self.OriginalDescriptions = {}

	local assetsFolder = ReplicatedStorage:WaitForChild(config.AssetsFolderName or "Assets")
	self.CharactersFolder = assetsFolder:WaitForChild(config.CharactersFolderName or "Characters")

	return self
end

function CharacterMorphService:GetSkinData(characterName, skinName)
	local characterFolder = self.CharactersFolder:FindFirstChild(characterName)
	local modulesFolder = characterFolder and characterFolder:FindFirstChild("Modules")
	local skinModule = modulesFolder and modulesFolder:FindFirstChild("SkinModule")

	if not skinModule then
		return nil, nil
	end

	local skinConfig = require(skinModule)
	local defaultSkinName = skinConfig.DefaultSkin or "Default"
	local resolvedSkinName = skinName or defaultSkinName
	local skinData = skinConfig.Skins and skinConfig.Skins[resolvedSkinName]

	if not skinData then
		resolvedSkinName = defaultSkinName
		skinData = skinConfig.Skins and skinConfig.Skins[resolvedSkinName]
	end

	return skinData, resolvedSkinName
end

function CharacterMorphService:GetMorphModel(characterName, skinName)
	local skinData, resolvedSkinName = self:GetSkinData(characterName, skinName)
	local characterFolder = self.CharactersFolder:FindFirstChild(characterName)
	local modelFolder = characterFolder and characterFolder:FindFirstChild("CharacterModel")

	if not skinData or not modelFolder then
		return nil, resolvedSkinName
	end

	local modelName = skinData.CharacterModelName or "Default"
	local model = modelFolder:FindFirstChild(modelName)

	if model and model:IsA("Model") then
		return model, resolvedSkinName
	end

	return nil, resolvedSkinName
end

function CharacterMorphService:CacheOriginalDescription(player)
	if not player then
		return nil
	end

	if self.OriginalDescriptions[player] then
		return self.OriginalDescriptions[player]
	end

	local success, descriptionOrError = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(player.UserId)
	end)

	if not success then
		warn("[CharacterMorphService] Failed to cache original avatar description:", player.Name, descriptionOrError)
		return nil
	end

	self.OriginalDescriptions[player] = descriptionOrError
	return descriptionOrError
end

function CharacterMorphService:RefreshOriginalDescription(player, character)
	if not player or player:GetAttribute("MorphEnabled") == true then
		return
	end

	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local success, descriptionOrError = pcall(function()
		return humanoid:GetAppliedDescription()
	end)

	if success and descriptionOrError then
		self.OriginalDescriptions[player] = descriptionOrError
	end
end

function CharacterMorphService:IsMorphItem(instance)
	return instance
		and (
			instance:GetAttribute("CharacterMorphItem") == true
			or instance:GetAttribute("CharaMorphItem") == true
			or instance:GetAttribute("MorphSkinName") ~= nil
			or instance:GetAttribute("MorphCharacterName") ~= nil
		)
end

function CharacterMorphService:IsHeadMeshItem(instance)
	return instance
		and (
			instance:IsA("SpecialMesh")
			or instance:IsA("DataModelMesh")
		)
end

function CharacterMorphService:IsBackupSafeItem(instance)
	return not self:IsMorphItem(instance)
		and instance:GetAttribute("CharacterWeapon") ~= true
end

function CharacterMorphService:GetBackupFolder(player)
	local backup = player:FindFirstChild("OriginalAppearanceBackup")

	if not backup then
		backup = Instance.new("Folder")
		backup.Name = "OriginalAppearanceBackup"
		backup.Parent = player
	end

	return backup
end

function CharacterMorphService:SaveOriginalAppearance(player, character)
	if not player or not character then
		return nil
	end

	local backup = self:GetBackupFolder(player)
	if backup:GetAttribute("Ready") == true then
		return backup
	end

	backup:ClearAllChildren()

	local headDecals = Instance.new("Folder")
	headDecals.Name = "HeadDecals"
	headDecals.Parent = backup

	local headMeshes = Instance.new("Folder")
	headMeshes.Name = "HeadMeshes"
	headMeshes.Parent = backup

	local bodyPartColors = Instance.new("Folder")
	bodyPartColors.Name = "BodyPartColors"
	bodyPartColors.Parent = backup

	for _, child in ipairs(character:GetChildren()) do
		if self:IsBackupSafeItem(child) and self:IsAppearanceItem(child) then
			child:Clone().Parent = backup
		end
	end

	local head = character:FindFirstChild("Head")
	if head then
		for _, child in ipairs(head:GetChildren()) do
			if self:IsBackupSafeItem(child) and (child:IsA("Decal") or child:IsA("Texture")) then
				child:Clone().Parent = headDecals
			elseif self:IsBackupSafeItem(child) and self:IsHeadMeshItem(child) then
				child:Clone().Parent = headMeshes
			end
		end
	end

	for _, bodyPartName in ipairs({
		"Head",
		"Torso",
		"Left Arm",
		"Right Arm",
		"Left Leg",
		"Right Leg",
	}) do
		local bodyPart = character:FindFirstChild(bodyPartName)

		if bodyPart and bodyPart:IsA("BasePart") then
			local colorValue = Instance.new("Color3Value")
			colorValue.Name = bodyPartName
			colorValue.Value = bodyPart.Color
			colorValue.Parent = bodyPartColors
		end
	end

	backup:SetAttribute("Ready", true)
	return backup
end

function CharacterMorphService:ClearFace(character, morphOnly)
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end

	for _, child in ipairs(head:GetChildren()) do
		if child:IsA("Decal") or child:IsA("Texture") then
			if not morphOnly or self:IsMorphItem(child) then
				child:Destroy()
			end
		elseif self:IsMorphItem(child) then
			child:Destroy()
		end
	end
end

function CharacterMorphService:ClearHeadMeshes(character, morphOnly)
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end

	for _, child in ipairs(head:GetChildren()) do
		if self:IsHeadMeshItem(child) then
			if not morphOnly or self:IsMorphItem(child) then
				child:Destroy()
			end
		end
	end
end

function CharacterMorphService:ClearMorphItemsOnly(character)
	if not character then
		return
	end

	self:ClearFace(character, true)
	self:ClearHeadMeshes(character, true)

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("BasePart") and child:GetAttribute("CharacterMorphItem") == true then
			local originalColor = child:GetAttribute("OriginalMorphColor")

			if typeof(originalColor) == "Color3" then
				child.Color = originalColor
			end

			child:SetAttribute("OriginalMorphColor", nil)
			child:SetAttribute("CharacterMorphItem", nil)
			child:SetAttribute("CharaMorphItem", nil)
			child:SetAttribute("MorphSkinName", nil)
			child:SetAttribute("MorphCharacterName", nil)
		elseif self:IsMorphItem(child) then
			child:Destroy()
		end
	end
end

function CharacterMorphService:IsAppearanceItem(instance)
	return instance:IsA("Shirt")
		or instance:IsA("Pants")
		or instance:IsA("ShirtGraphic")
		or instance:IsA("Accessory")
		or instance:IsA("CharacterMesh")
		or instance:IsA("BodyColors")
end

function CharacterMorphService:NeedsAvatarRestore(character)
	if not character then
		return false
	end

	if character:FindFirstChildOfClass("Shirt") then
		return false
	end

	if character:FindFirstChildOfClass("Pants") then
		return false
	end

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory") then
			return false
		end
	end

	return true
end

function CharacterMorphService:ClearAllAppearance(character)
	if not character then
		return
	end

	self:ClearMorphItemsOnly(character)

	for _, child in ipairs(character:GetChildren()) do
		if self:IsAppearanceItem(child) and child:GetAttribute("CharacterWeapon") ~= true then
			child:Destroy()
		end
	end

	self:ClearFace(character, false)
	self:ClearHeadMeshes(character, false)
end

function CharacterMorphService:ClearBaseAppearance(character)
	self:ClearAllAppearance(character)
end

function CharacterMorphService:TagMorphItem(instance, characterName, skinName)
	instance:SetAttribute("CharacterMorphItem", true)
	instance:SetAttribute("MorphSkinName", skinName)
	instance:SetAttribute("MorphCharacterName", characterName)
end

function CharacterMorphService:CopyAppearanceChild(character, sourceChild, characterName, skinName)
	local clone = sourceChild:Clone()
	self:TagMorphItem(clone, characterName, skinName)
	clone.Parent = character
end

function CharacterMorphService:CopyFace(character, sourceModel, characterName, skinName)
	local sourceHead = sourceModel:FindFirstChild("Head")
	local targetHead = character:FindFirstChild("Head")

	if not sourceHead or not targetHead then
		return
	end

	for _, child in ipairs(sourceHead:GetChildren()) do
		if child:IsA("Decal") or child:IsA("Texture") then
			local clone = child:Clone()
			self:TagMorphItem(clone, characterName, skinName)
			clone.Parent = targetHead
		end
	end
end

function CharacterMorphService:CopyHeadMeshes(character, sourceModel, characterName, skinName)
	local sourceHead = sourceModel:FindFirstChild("Head")
	local targetHead = character:FindFirstChild("Head")

	if not sourceHead or not targetHead then
		return
	end

	for _, child in ipairs(sourceHead:GetChildren()) do
		if self:IsHeadMeshItem(child) then
			local clone = child:Clone()
			self:TagMorphItem(clone, characterName, skinName)
			clone.Parent = targetHead
		end
	end
end

function CharacterMorphService:CopyBodyPartColors(character, sourceModel, characterName, skinName)
	for _, sourcePart in ipairs(sourceModel:GetChildren()) do
		if sourcePart:IsA("BasePart") and sourcePart.Name ~= "HumanoidRootPart" then
			local targetPart = character:FindFirstChild(sourcePart.Name)

			if targetPart and targetPart:IsA("BasePart") then
				if targetPart:GetAttribute("OriginalMorphColor") == nil then
					targetPart:SetAttribute("OriginalMorphColor", targetPart.Color)
				end

				targetPart.Color = sourcePart.Color
				targetPart:SetAttribute("CharacterMorphItem", true)
				targetPart:SetAttribute("MorphSkinName", skinName)
				targetPart:SetAttribute("MorphCharacterName", characterName)
			end
		end
	end
end

function CharacterMorphService:RestoreWithHumanoidDescription(player, character)
	if not player or not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local cachedDescription = self:CacheOriginalDescription(player)
	if not cachedDescription then
		return
	end

	warn("[CharacterMorphService] OriginalAppearanceBackup missing; using HumanoidDescription fallback for", player.Name)

	local description = cachedDescription:Clone()
	local applySuccess, applyError = pcall(function()
		humanoid:ApplyDescription(description)
	end)

	if not applySuccess then
		warn("[CharacterMorphService] ApplyDescription failed:", applyError)
		return
	end

	self:ClearMorphItemsOnly(character)
end

function CharacterMorphService:RestoreOriginalAppearance(player, character)
	if not player or not character then
		return
	end

	local backup = player:FindFirstChild("OriginalAppearanceBackup")

	if not backup or backup:GetAttribute("Ready") ~= true then
		self:RestoreWithHumanoidDescription(player, character)
		return
	end

	self:ClearAllAppearance(character)

	local restoredVisibleItem = false

	for _, child in ipairs(backup:GetChildren()) do
		if child.Name ~= "HeadDecals" and child.Name ~= "BodyPartColors" then
			child:Clone().Parent = character

			if self:IsAppearanceItem(child) then
				restoredVisibleItem = true
			end
		end
	end

	local head = character:FindFirstChild("Head")
	local headDecals = backup:FindFirstChild("HeadDecals")
	local headMeshes = backup:FindFirstChild("HeadMeshes")

	if head and headMeshes then
		for _, child in ipairs(headMeshes:GetChildren()) do
			if self:IsHeadMeshItem(child) then
				child:Clone().Parent = head
				restoredVisibleItem = true
			end
		end
	end

	if head and headDecals then
		for _, child in ipairs(headDecals:GetChildren()) do
			if child:IsA("Decal") or child:IsA("Texture") then
				child:Clone().Parent = head
				restoredVisibleItem = true
			end
		end
	end

	local bodyPartColors = backup:FindFirstChild("BodyPartColors")
	if bodyPartColors then
		for _, colorValue in ipairs(bodyPartColors:GetChildren()) do
			if colorValue:IsA("Color3Value") then
				local bodyPart = character:FindFirstChild(colorValue.Name)

				if bodyPart and bodyPart:IsA("BasePart") then
					bodyPart.Color = colorValue.Value
					restoredVisibleItem = true
				end
			end
		end
	end

	if not restoredVisibleItem then
		warn("[CharacterMorphService] OriginalAppearanceBackup had no visible appearance items for", player.Name)
	end
end

function CharacterMorphService:ApplyMorph(player, character, characterName, skinName)
	if not character or not character.Parent then
		return
	end

	local skinData, resolvedSkinName = self:GetSkinData(characterName, skinName)
	if not skinData then
		warn("[CharacterMorphService] Missing SkinModule data for", tostring(characterName), tostring(skinName))
		self:ClearMorphItemsOnly(character)
		return
	end

	local sourceModel = self:GetMorphModel(characterName, resolvedSkinName)
	if not sourceModel then
		warn("[CharacterMorphService] Missing CharacterModel for skin", tostring(characterName), tostring(resolvedSkinName))
		self:ClearMorphItemsOnly(character)
		return
	end

	self:SaveOriginalAppearance(player, character)
	self:ClearAllAppearance(character)

	local copiedBodyColors = false

	for _, child in ipairs(sourceModel:GetChildren()) do
		if child:IsA("Shirt")
			or child:IsA("Pants")
			or child:IsA("ShirtGraphic")
			or child:IsA("Accessory")
			or child:IsA("CharacterMesh")
		then
			self:CopyAppearanceChild(character, child, characterName, resolvedSkinName)
		elseif child:IsA("BodyColors") then
			copiedBodyColors = true
			self:CopyAppearanceChild(character, child, characterName, resolvedSkinName)
		end
	end

	if not copiedBodyColors then
		self:CopyBodyPartColors(character, sourceModel, characterName, resolvedSkinName)
	end

	self:CopyFace(character, sourceModel, characterName, resolvedSkinName)
	self:CopyHeadMeshes(character, sourceModel, characterName, resolvedSkinName)
end

function CharacterMorphService:ApplyCharacterMorph(player, character, characterName, skinName, morphEnabled)
	self:CacheOriginalDescription(player)

	if morphEnabled == true then
		self:ApplyMorph(player, character, characterName, skinName)
	else
		self:RestoreOriginalAppearance(player, character)
	end
end

function CharacterMorphService:SetupPlayer(player)
	self:CacheOriginalDescription(player)

	player.CharacterAppearanceLoaded:Connect(function(character)
		self:RefreshOriginalDescription(player, character)
	end)
end

function CharacterMorphService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:SetupPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.OriginalDescriptions[player] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:SetupPlayer(player)
	end
end

return CharacterMorphService
