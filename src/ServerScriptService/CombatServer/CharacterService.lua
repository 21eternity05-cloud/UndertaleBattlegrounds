local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CharacterData"))

local CharacterService = {}
CharacterService.__index = CharacterService

function CharacterService.new(config, weaponService, progressionService, characterMorphService)
	local self = setmetatable({}, CharacterService)

	self.Config = config
	self.WeaponService = weaponService
	self.ProgressionService = progressionService
	self.CharacterMorphService = characterMorphService
	self.CombatStatusService = nil

	return self
end

function CharacterService:IsPlayerRequestInCombat(player)
	local character = player and player.Character

	if not character then
		return false
	end

	if self.CombatStatusService and self.CombatStatusService.IsInCombat then
		return self.CombatStatusService:IsInCombat(character)
	end

	if os.clock() < (character:GetAttribute("CombatTaggedUntil") or 0) then
		return true
	end

	return character:GetAttribute("Stunned") == true
		or character:GetAttribute("Guardbroken") == true
		or character:GetAttribute("Blocking") == true
		or character:GetAttribute("Attacking") == true
		or character:GetAttribute("UsingMove") == true
		or character:GetAttribute("Grabbed") == true
		or character:GetAttribute("CinematicLocked") == true
end

function CharacterService:IsValidCharacter(characterName)
	if CharacterData[characterName] then
		return true
	end

	return self.Config.ValidCharacters and self.Config.ValidCharacters[characterName] == true
end

function CharacterService:IsCharacterUnlocked(player, characterName)
	if not self:IsValidCharacter(characterName) then
		return false
	end

	if self.ProgressionService and self.ProgressionService.IsCharacterUnlocked then
		return self.ProgressionService:IsCharacterUnlocked(player, characterName)
	end

	local data = CharacterData[characterName]
	return not data or data.Free == true or (data.Cost or 0) <= 0
end

function CharacterService:GetCharacterName(player)
	local characterName = player:GetAttribute("CharacterName")

	if typeof(characterName) == "string" and self:IsValidCharacter(characterName) then
		return characterName
	end

	return self.Config.DefaultCharacterName or "Chara"
end

function CharacterService:GetDefaultSkin(characterName)
	local skinConfig = self:GetSkinConfig(characterName)

	if skinConfig and skinConfig.DefaultSkin then
		return skinConfig.DefaultSkin
	end

	return "Default"
end

function CharacterService:GetSkinConfig(characterName)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local characters = assets and assets:FindFirstChild("Characters")
	local characterFolder = characters and characters:FindFirstChild(characterName)
	local modulesFolder = characterFolder and characterFolder:FindFirstChild("Modules")
	local skinModule = modulesFolder and modulesFolder:FindFirstChild("SkinModule")

	if not skinModule then
		return nil
	end

	local success, skinConfig = pcall(require, skinModule)
	if not success or typeof(skinConfig) ~= "table" then
		warn("[CharacterService] Failed to load SkinModule:", tostring(characterName))
		return nil
	end

	return skinConfig
end

function CharacterService:GetValidSkinName(player, characterName, skinName)
	local skinConfig = self:GetSkinConfig(characterName)
	local defaultSkinName = (skinConfig and skinConfig.DefaultSkin) or "Default"

	if typeof(skinName) == "string" and skinConfig and skinConfig.Skins and skinConfig.Skins[skinName] then
		if not self.ProgressionService or not self.ProgressionService.IsSkinOwned then
			local skinData = skinConfig.Skins[skinName]
			if skinData.Free == true or (skinData.Cost or 0) <= 0 then
				return skinName
			end
		elseif self.ProgressionService:IsSkinOwned(player, characterName, skinName) then
			return skinName
		end
	end

	return defaultSkinName
end

function CharacterService:NormalizeCharacterOptions(player, characterName, options)
	if typeof(options) ~= "table" then
		options = {}
	end

	local skinName = options.SkinName

	if typeof(skinName) ~= "string" or skinName == "" then
		if self.ProgressionService and self.ProgressionService.GetEquippedSkin then
			skinName = self.ProgressionService:GetEquippedSkin(player, characterName)
		else
			skinName = self:GetDefaultSkin(characterName)
		end
	end

	skinName = self:GetValidSkinName(player, characterName, skinName)

	return {
		SkinName = skinName,
		MorphEnabled = options.MorphEnabled == true,
	}
end

function CharacterService:ApplyCharacterAttributes(player, character, characterName, options)
	player:SetAttribute("CharacterName", characterName)
	player:SetAttribute("MorphEnabled", options.MorphEnabled == true)

	if options.SkinName then
		player:SetAttribute("SelectedSkin", options.SkinName)
		player:SetAttribute("EquippedSkin_" .. characterName, options.SkinName)
	end

	if characterName == "Chara" then
		player:SetAttribute("CharaSkin", options.SkinName or "Default")
	end

	if character then
		character:SetAttribute("CharacterName", characterName)
		character:SetAttribute("MorphEnabled", options.MorphEnabled == true)

		if options.SkinName then
			character:SetAttribute("SelectedSkin", options.SkinName)
			character:SetAttribute("EquippedSkin_" .. characterName, options.SkinName)
		end

		if characterName == "Chara" then
			character:SetAttribute("CharaSkin", options.SkinName or "Default")
		end
	end
end

function CharacterService:GetCurrentOptions(player, characterName)
	local skinName = player:GetAttribute("EquippedSkin_" .. characterName)

	if not skinName and self.ProgressionService and self.ProgressionService.GetEquippedSkin then
		skinName = self.ProgressionService:GetEquippedSkin(player, characterName)
	end

	return self:NormalizeCharacterOptions(player, characterName, {
		SkinName = skinName,
		MorphEnabled = player:GetAttribute("MorphEnabled") == true,
	})
end

function CharacterService:SetCharacter(player, characterName, options)
	if typeof(characterName) ~= "string" then return end
	if not self:IsValidCharacter(characterName) then
		warn("Invalid character:", characterName)
		return
	end

	if not self:IsCharacterUnlocked(player, characterName) then
		warn("[CharacterService] Locked character select rejected:", player.Name, characterName)

		if self.ProgressionService and self.ProgressionService.SendSnapshot then
			self.ProgressionService:SendSnapshot(player)
		end

		return
	end

	if self:IsPlayerRequestInCombat(player) then
		warn("[CharacterService] Character switch rejected while in combat:", player.Name, characterName)
		return false
	end

	if options == nil then
		options = self:GetCurrentOptions(player, characterName)
	else
		options = self:NormalizeCharacterOptions(player, characterName, options)

		if self.ProgressionService and self.ProgressionService.EquipSkin then
			self.ProgressionService:EquipSkin(player, characterName, options.SkinName)
		end
	end

	local character = player.Character
	self:ApplyCharacterAttributes(player, character, characterName, options)

	if character then
		if self.CharacterMorphService then
			self.CharacterMorphService:ApplyCharacterMorph(
				player,
				character,
				characterName,
				options.SkinName,
				options.MorphEnabled
			)
		end

		if self.WeaponService then
			self.WeaponService:EquipWeapon(character, characterName)
		end
	end

	print(player.Name .. " changed character to " .. characterName)
	return true
end

function CharacterService:SetupPlayer(player)
	if not player:GetAttribute("CharacterName") then
		player:SetAttribute("CharacterName", self.Config.DefaultCharacterName or "Chara")
	end

	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid", 5)
		task.wait(0.25)

		local characterName = self:GetCharacterName(player)
		local options = self:GetCurrentOptions(player, characterName)

		self:ApplyCharacterAttributes(player, character, characterName, options)

		if self.CharacterMorphService then
			if options.MorphEnabled then
				self.CharacterMorphService:ApplyCharacterMorph(
					player,
					character,
					characterName,
					options.SkinName,
					options.MorphEnabled
				)
			elseif self.CharacterMorphService.ClearMorphItemsOnly then
				self.CharacterMorphService:ClearMorphItemsOnly(character)

				if self.CharacterMorphService.NeedsAvatarRestore
					and self.CharacterMorphService:NeedsAvatarRestore(character)
					and self.CharacterMorphService.RestoreOriginalAppearance
				then
					self.CharacterMorphService:RestoreOriginalAppearance(player, character)
				end
			end
		end

		if self.WeaponService then
			self.WeaponService:EquipWeapon(character, characterName)
		end
	end)
end

function CharacterService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:SetupPlayer(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:SetupPlayer(player)

		if player.Character then
			local characterName = self:GetCharacterName(player)
			local options = self:GetCurrentOptions(player, characterName)

			self:ApplyCharacterAttributes(player, player.Character, characterName, options)

			if self.CharacterMorphService then
				if options.MorphEnabled then
					self.CharacterMorphService:ApplyCharacterMorph(
						player,
						player.Character,
						characterName,
						options.SkinName,
						options.MorphEnabled
					)
				elseif self.CharacterMorphService.ClearMorphItemsOnly then
					self.CharacterMorphService:ClearMorphItemsOnly(player.Character)

					if self.CharacterMorphService.NeedsAvatarRestore
						and self.CharacterMorphService:NeedsAvatarRestore(player.Character)
						and self.CharacterMorphService.RestoreOriginalAppearance
					then
						self.CharacterMorphService:RestoreOriginalAppearance(player, player.Character)
					end
				end
			end

			if self.WeaponService then
				self.WeaponService:EquipWeapon(player.Character, characterName)
			end
		end
	end
end

return CharacterService
