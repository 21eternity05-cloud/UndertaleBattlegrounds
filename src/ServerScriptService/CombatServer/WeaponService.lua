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

function WeaponService:IsWeaponContainer(instance)
	if not instance then
		return false
	end

	if instance:GetAttribute("CharacterWeapon") == true then
		return true
	end

	if instance.Name == "EquippedWeapon"
		or instance.Name == "EquippedSword"
		or instance.Name == "EquippedShield"
		or instance.Name == "EquippedStaff"
	then
		return true
	end

	return false
end

function WeaponService:IsWeaponMotor(instance)
	if not instance or not instance:IsA("Motor6D") then
		return false
	end

	if instance:GetAttribute("CharacterWeaponMotor") == true then
		return true
	end

	if instance.Name == "WeaponMotor"
		or instance.Name == "HandleKnife"
		or instance.Name == "BoneStaff"
		or instance.Name == "GTFriskSword"
		or instance.Name == "GTFriskShield"
	then
		return true
	end

	return false
end

function WeaponService:RemoveCurrentWeapon(character)
	if not character or not character.Parent then return end

	-- Destroy direct weapon containers first.
	-- This removes the whole model, not just a handle/primary part.
	for _, child in ipairs(character:GetChildren()) do
		if self:IsWeaponContainer(child) then
			child:Destroy()
		end
	end

	-- Safety cleanup: remove old equipped weapon folders too, if any older modules used them.
	local equippedWeaponsFolder = character:FindFirstChild("EquippedWeapons")
	if equippedWeaponsFolder then
		equippedWeaponsFolder:Destroy()
	end

	-- Remove all character weapon motors.
	for _, descendant in ipairs(character:GetDescendants()) do
		if self:IsWeaponMotor(descendant) then
			descendant:Destroy()
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