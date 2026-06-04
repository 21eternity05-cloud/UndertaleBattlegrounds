local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CharacterData"))

local CharacterService = {}
CharacterService.__index = CharacterService

function CharacterService.new(config, weaponService, progressionService)
	local self = setmetatable({}, CharacterService)

	self.Config = config
	self.WeaponService = weaponService
	self.ProgressionService = progressionService

	return self
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

function CharacterService:SetCharacter(player, characterName)
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

	player:SetAttribute("CharacterName", characterName)

	local character = player.Character
	if character then
		character:SetAttribute("CharacterName", characterName)

		if self.WeaponService then
			self.WeaponService:EquipWeapon(character, characterName)
		end
	end

	print(player.Name .. " changed character to " .. characterName)
end

function CharacterService:SetupPlayer(player)
	if not player:GetAttribute("CharacterName") then
		player:SetAttribute("CharacterName", self.Config.DefaultCharacterName or "Chara")
	end

	player.CharacterAdded:Connect(function(character)
		task.wait(0.25)

		local characterName = self:GetCharacterName(player)
		character:SetAttribute("CharacterName", characterName)

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
			player.Character:SetAttribute("CharacterName", characterName)

			if self.WeaponService then
				self.WeaponService:EquipWeapon(player.Character, characterName)
			end
		end
	end
end

return CharacterService
