local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponService = {}
WeaponService.__index = WeaponService

function WeaponService.new(config)
	local self = setmetatable({}, WeaponService)

	self.Config = config

	local assetsFolder = ReplicatedStorage:WaitForChild(config.AssetsFolderName or "Assets")
	self.CharactersFolder = assetsFolder:WaitForChild(config.CharactersFolderName or "Characters")

	self.LoadedWeaponModules = {}

	return self
end

function WeaponService:GetCharacterFolder(characterName)
	return self.CharactersFolder:FindFirstChild(characterName)
end

function WeaponService:GetWeaponModule(characterName)
	if self.LoadedWeaponModules[characterName] then
		return self.LoadedWeaponModules[characterName]
	end

	local characterFolder = self:GetCharacterFolder(characterName)
	if not characterFolder then
		warn("Missing character asset folder:", characterName)
		return nil
	end

	local modulesFolder = characterFolder:FindFirstChild("Modules")
	if not modulesFolder then
		warn("Missing Modules folder for:", characterName)
		return nil
	end

	local moduleScript = modulesFolder:FindFirstChild("WeaponModule")
	if not moduleScript then
		warn("Missing WeaponModule for:", characterName)
		return nil
	end

	local module = require(moduleScript).new(self.Config, characterFolder)
	self.LoadedWeaponModules[characterName] = module

	return module
end

function WeaponService:RemoveCurrentWeapon(character)
	if not character or not character.Parent then return end

	local existingWeapon = character:FindFirstChild("EquippedWeapon")
	if existingWeapon then
		existingWeapon:Destroy()
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Motor6D") then
			if descendant:GetAttribute("CharacterWeaponMotor") == true then
				descendant:Destroy()
			end

			if descendant.Name == "WeaponMotor" or descendant.Name == "HandleKnife" then
				descendant:Destroy()
			end
		end
	end
end

function WeaponService:EquipWeapon(character, characterName)
	if not character or not character.Parent then return end

	characterName = characterName or self.Config.DefaultCharacterName or "Chara"

	self:RemoveCurrentWeapon(character)

	local module = self:GetWeaponModule(characterName)
	if not module then return end

	module:Equip(character)
end

return WeaponService