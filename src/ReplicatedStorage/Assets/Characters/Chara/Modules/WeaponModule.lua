local Players = game:GetService("Players")

local SkinModule = require(script.Parent:WaitForChild("SkinModule"))

local CharaWeapon = {}
CharaWeapon.__index = CharaWeapon

function CharaWeapon.new(config, characterFolder)
	local self = setmetatable({}, CharaWeapon)
	self.Config = config
	self.CharacterFolder = characterFolder
	return self
end

function CharaWeapon:ApplyWeaponPartSettings(instance)
	instance:SetAttribute("WeaponVisual", true)
	instance:SetAttribute("EquippedWeapon", true)
	instance:SetAttribute("CharacterWeapon", true)
	instance:SetAttribute("CharacterWeaponOwner", "Chara")

	if instance:IsA("BasePart") then
		instance.Anchored = false
		instance.CanCollide = false
		instance.CanTouch = false
		instance.CanQuery = false
		instance.Massless = true
	end
end

function CharaWeapon:PrepareWeaponModel(model)
	self:ApplyWeaponPartSettings(model)

	for _, descendant in ipairs(model:GetDescendants()) do
		self:ApplyWeaponPartSettings(descendant)
	end
end

function CharaWeapon:WatchWeaponDescendants(weapon)
	if not weapon then
		return
	end

	weapon.DescendantAdded:Connect(function(descendant)
		self:ApplyWeaponPartSettings(descendant)
	end)
end

function CharaWeapon:WeldWeaponPartsToHandle(weaponModel, handle)
	for _, part in ipairs(weaponModel:GetDescendants()) do
		if part:IsA("BasePart") and part ~= handle then
			local alreadyConnected = false

			for _, child in ipairs(part:GetChildren()) do
				if child:IsA("WeldConstraint") or child:IsA("Weld") or child:IsA("Motor6D") then
					alreadyConnected = true
					break
				end
			end

			if not alreadyConnected then
				local weld = Instance.new("WeldConstraint")
				weld.Name = "AutoWeaponWeld"
				weld.Part0 = handle
				weld.Part1 = part
				weld.Parent = handle
			end
		end
	end
end

function CharaWeapon:GetSelectedSkinName(character)
	local player = Players:GetPlayerFromCharacter(character)
	local skinName = character:GetAttribute("SelectedSkin")
		or character:GetAttribute("CharaSkin")
		or (player and player:GetAttribute("CharaSkin"))
		or (player and player:GetAttribute("SelectedSkin"))
		or SkinModule.DefaultSkin

	if typeof(skinName) ~= "string" or not SkinModule.Skins[skinName] then
		return SkinModule.DefaultSkin
	end

	return skinName
end

function CharaWeapon:GetSkinWeaponData(character)
	local skinName = self:GetSelectedSkinName(character)
	local skinData = SkinModule.Skins[skinName] or SkinModule.Skins[SkinModule.DefaultSkin]

	return skinName, skinData
end

function CharaWeapon:Equip(character)
	if not character or not character.Parent then return end

	local rightArm = character:FindFirstChild("Right Arm")
	if not rightArm then return end

	local weaponsFolder = self.CharacterFolder:FindFirstChild("Weapons")
	if not weaponsFolder then return end

	local skinName, skinData = self:GetSkinWeaponData(character)
	local weaponName = skinData and skinData.WeaponName or "RealKnife"
	local motorTemplateName = skinData and skinData.MotorTemplateName or "KnifeMotorTemplate"
	local knifeTemplate = weaponsFolder:FindFirstChild(weaponName) or weaponsFolder:FindFirstChild("RealKnife")
	local motorTemplate = weaponsFolder:FindFirstChild(motorTemplateName) or weaponsFolder:FindFirstChild("KnifeMotorTemplate")

	if not knifeTemplate then return end
	if not motorTemplate or not motorTemplate:IsA("Motor6D") then return end

	local knife = knifeTemplate:Clone()
	knife.Name = "EquippedWeapon"
	knife:SetAttribute("CharacterWeapon", true)
	knife:SetAttribute("WeaponVisual", true)
	knife:SetAttribute("EquippedWeapon", true)
	knife:SetAttribute("CharacterWeaponOwner", "Chara")
	knife:SetAttribute("SelectedSkin", skinName)
	knife:SetAttribute("OriginalWeaponName", weaponName)
	self:PrepareWeaponModel(knife)
	self:WatchWeaponDescendants(knife)
	knife.Parent = character

	local handle = knife:FindFirstChild("HandleKnife", true)
	if not handle or not handle:IsA("BasePart") then
		knife:Destroy()
		return
	end

	self:WeldWeaponPartsToHandle(knife, handle)

	local oldMotor = rightArm:FindFirstChild("HandleKnife")
	if oldMotor then
		oldMotor:Destroy()
	end

	local motor = motorTemplate:Clone()
	motor.Name = "HandleKnife"
	motor.Part0 = rightArm
	motor.Part1 = handle
	motor:SetAttribute("CharacterWeaponMotor", true)
	motor.Parent = rightArm
end

return CharaWeapon
