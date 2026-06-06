local GTFriskWeapon = {}
GTFriskWeapon.__index = GTFriskWeapon

function GTFriskWeapon.new(config, characterFolder)
	local self = setmetatable({}, GTFriskWeapon)
	self.Config = config
	self.CharacterFolder = characterFolder
	return self
end

function GTFriskWeapon:PrepareWeaponModel(model)
	if model:IsA("BasePart") then
		model.Anchored = false
		model.CanCollide = false
		model.CanTouch = false
		model.CanQuery = false
		model.Massless = true
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end
end

function GTFriskWeapon:WeldWeaponPartsToHandle(weaponModel, handle)
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

function GTFriskWeapon:FindHandle(weaponModel, preferredNames)
	for _, name in ipairs(preferredNames) do
		local handle = weaponModel:FindFirstChild(name, true)

		if handle and handle:IsA("BasePart") then
			return handle
		end
	end

	if weaponModel:IsA("BasePart") then
		return weaponModel
	end

	return weaponModel:FindFirstChildWhichIsA("BasePart", true)
end

function GTFriskWeapon:Remove(character)
	if not character or not character.Parent then
		return
	end

	for _, child in ipairs(character:GetChildren()) do
		if child:GetAttribute("CharacterWeapon") == true
			or child.Name == "EquippedSword"
			or child.Name == "EquippedShield"
		then
			child:Destroy()
		end
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Motor6D")
			and (
				descendant:GetAttribute("CharacterWeaponMotor") == true
				or descendant.Name == "GTFriskSword"
				or descendant.Name == "GTFriskShield"
			)
		then
			descendant:Destroy()
		end
	end
end

function GTFriskWeapon:EquipSingleWeapon(options)
	local character = options.Character
	local weaponsFolder = options.WeaponsFolder
	local limbName = options.LimbName
	local weaponName = options.WeaponName
	local motorTemplateName = options.MotorTemplateName
	local equippedName = options.EquippedName
	local motorName = options.MotorName
	local handleNames = options.HandleNames or { "Handle" }

	if not character or not character.Parent then return end
	if not weaponsFolder then return end

	local limb = character:FindFirstChild(limbName)
	if not limb or not limb:IsA("BasePart") then
		warn("[GlitchtaleFrisk WeaponModule] Missing limb:", limbName)
		return
	end

	local weaponTemplate = weaponsFolder:FindFirstChild(weaponName)
	local motorTemplate = weaponsFolder:FindFirstChild(motorTemplateName)

	if not weaponTemplate then
		warn("[GlitchtaleFrisk WeaponModule] Missing weapon:", weaponName)
		return
	end

	if not motorTemplate or not motorTemplate:IsA("Motor6D") then
		warn("[GlitchtaleFrisk WeaponModule] Missing Motor6D template:", motorTemplateName)
		return
	end

	local weapon = weaponTemplate:Clone()
	weapon.Name = equippedName
	weapon:SetAttribute("CharacterWeapon", true)
	weapon:SetAttribute("CharacterWeaponOwner", "GlitchtaleFrisk")
	weapon:SetAttribute("OriginalWeaponName", weaponName)
	weapon.Parent = character

	local handle = self:FindHandle(weapon, handleNames)

	if not handle or not handle:IsA("BasePart") then
		weapon:Destroy()
		warn("[GlitchtaleFrisk WeaponModule] Weapon has no handle/basepart:", weaponName)
		return
	end

	self:PrepareWeaponModel(weapon)
	self:WeldWeaponPartsToHandle(weapon, handle)

	local oldMotor = limb:FindFirstChild(motorName)
	if oldMotor then
		oldMotor:Destroy()
	end

	local motor = motorTemplate:Clone()
	motor.Name = motorName
	motor.Part0 = limb
	motor.Part1 = handle
	motor:SetAttribute("CharacterWeaponMotor", true)
	motor:SetAttribute("CharacterWeaponOwner", "GlitchtaleFrisk")
	motor:SetAttribute("OriginalWeaponName", weaponName)
	motor.Parent = limb
end

function GTFriskWeapon:Equip(character)
	if not character or not character.Parent then
		return
	end

	self:Remove(character)

	local weaponsFolder = self.CharacterFolder:FindFirstChild("Weapons")
	if not weaponsFolder then
		warn("[GlitchtaleFrisk WeaponModule] Missing Weapons folder")
		return
	end

	self:EquipSingleWeapon({
		Character = character,
		WeaponsFolder = weaponsFolder,
		LimbName = "Right Arm",
		WeaponName = "GT Frisk Sword",
		MotorTemplateName = "GT Frisk SwordMotorTemplate",
		EquippedName = "EquippedSword",
		MotorName = "GTFriskSword",
		HandleNames = {
			"Handle",
			"HandleSword",
			"SwordHandle",
			"GT Frisk SwordHandle",
		},
	})

	self:EquipSingleWeapon({
		Character = character,
		WeaponsFolder = weaponsFolder,
		LimbName = "Left Arm",
		WeaponName = "GT Frisk Shield",
		MotorTemplateName = "GT Frisk ShieldMotorTemplate",
		EquippedName = "EquippedShield",
		MotorName = "GTFriskShield",
		HandleNames = {
			"Handle",
			"HandleShield",
			"ShieldHandle",
			"GT Frisk ShieldHandle",
		},
	})
end

return GTFriskWeapon