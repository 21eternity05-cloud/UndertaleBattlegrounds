local SkinModule = require(script.Parent:WaitForChild("SkinModule"))

local PapyrusWeapon = {}
PapyrusWeapon.__index = PapyrusWeapon

function PapyrusWeapon.new(config, characterFolder)
	local self = setmetatable({}, PapyrusWeapon)

	self.Config = config
	self.CharacterFolder = characterFolder

	return self
end

function PapyrusWeapon:GetWeaponsFolder()
	return self.CharacterFolder:FindFirstChild("Weapons")
end

function PapyrusWeapon:PrepareWeaponModel(model)
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

function PapyrusWeapon:WeldWeaponPartsToHandle(weaponModel, handle)
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

function PapyrusWeapon:FindHandle(weaponModel, preferredNames)
	for _, name in ipairs(preferredNames or {}) do
		local found = weaponModel:FindFirstChild(name, true)

		if found and found:IsA("BasePart") then
			return found
		end
	end

	local handle = weaponModel:FindFirstChild("Handle", true)
	if handle and handle:IsA("BasePart") then
		return handle
	end

	return weaponModel:FindFirstChildWhichIsA("BasePart", true)
end

function PapyrusWeapon:Remove(character)
	if not character or not character.Parent then
		return
	end

	local equippedWeapon = character:FindFirstChild("EquippedWeapon")
	if equippedWeapon then
		equippedWeapon:Destroy()
	end

	local equippedWeapons = character:FindFirstChild("EquippedWeapons")
	if equippedWeapons then
		equippedWeapons:Destroy()
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Motor6D") then
			if descendant.Name == "BoneStaff"
				or descendant.Name == "LeftBoneMotor"
				or descendant.Name == "RightBoneMotor"
				or descendant.Name == "WeaponMotor"
				or descendant:GetAttribute("CharacterWeaponMotor") == true
			then
				descendant:Destroy()
			end
		end
	end
end

function PapyrusWeapon:GetSkinWeaponData(character)
	local skinName =
		character:GetAttribute("SelectedSkin")
		or character:GetAttribute("EquippedSkin_DisbeliefPapyrus")
		or SkinModule.DefaultSkin

	if typeof(skinName) ~= "string" or not SkinModule.Skins[skinName] then
		skinName = SkinModule.DefaultSkin
	end

	return skinName, SkinModule.Skins[skinName] or SkinModule.Skins[SkinModule.DefaultSkin]
end

function PapyrusWeapon:AttachWithMotor(character, weaponModel, handle, limb, motorTemplate, motorName, originalWeaponName)
	if not character or not character.Parent then return end
	if not weaponModel or not handle or not limb or not motorTemplate then return end

	self:PrepareWeaponModel(weaponModel)
	self:WeldWeaponPartsToHandle(weaponModel, handle)

	local motor = motorTemplate:Clone()
	motor.Name = motorName
	motor.Part0 = limb
	motor.Part1 = handle
	motor:SetAttribute("CharacterWeaponMotor", true)
	motor:SetAttribute("CharacterWeaponOwner", "DisbeliefPapyrus")
	motor:SetAttribute("OriginalWeaponName", originalWeaponName)
	motor.Parent = limb
end

function PapyrusWeapon:EquipPhase1(character)
	if not character or not character.Parent then return end

	self:Remove(character)

	local rightArm = character:FindFirstChild("Right Arm")
	if not rightArm then
		warn("[DisbeliefPapyrus WeaponModule] Missing Right Arm")
		return
	end

	local weaponsFolder = self:GetWeaponsFolder()
	if not weaponsFolder then
		warn("[DisbeliefPapyrus WeaponModule] Missing Weapons folder")
		return
	end

	local skinName, skinData = self:GetSkinWeaponData(character)

	local weaponName = skinData and skinData.WeaponName or "BoneStaff"
	local motorTemplateName = skinData and skinData.MotorTemplateName or "BoneStaffMotorTemplate"

	local weaponTemplate = weaponsFolder:FindFirstChild(weaponName) or weaponsFolder:FindFirstChild("BoneStaff")
	local motorTemplate = weaponsFolder:FindFirstChild(motorTemplateName) or weaponsFolder:FindFirstChild("BoneStaffMotorTemplate")

	if not weaponTemplate then
		warn("[DisbeliefPapyrus WeaponModule] Missing BoneStaff weapon")
		return
	end

	if not motorTemplate or not motorTemplate:IsA("Motor6D") then
		warn("[DisbeliefPapyrus WeaponModule] Missing BoneStaffMotorTemplate")
		return
	end

	local weapon = weaponTemplate:Clone()
	weapon.Name = "EquippedWeapon"
	weapon:SetAttribute("CharacterWeapon", true)
	weapon:SetAttribute("CharacterWeaponOwner", "DisbeliefPapyrus")
	weapon:SetAttribute("SelectedSkin", skinName)
	weapon:SetAttribute("OriginalWeaponName", weaponName)
	weapon.Parent = character

	local handle = self:FindHandle(weapon, {
		"Handle",
		"HandleStaff",
		"BoneStaffHandle",
	})

	if not handle then
		weapon:Destroy()
		warn("[DisbeliefPapyrus WeaponModule] BoneStaff has no handle")
		return
	end

	self:AttachWithMotor(character, weapon, handle, rightArm, motorTemplate, "BoneStaff", weaponName)
end

function PapyrusWeapon:EquipPhase2(character)
	if not character or not character.Parent then return end

	self:Remove(character)

	local leftArm = character:FindFirstChild("Left Arm")
	local rightArm = character:FindFirstChild("Right Arm")

	if not leftArm then
		warn("[DisbeliefPapyrus WeaponModule] Missing Left Arm")
		return
	end

	if not rightArm then
		warn("[DisbeliefPapyrus WeaponModule] Missing Right Arm")
		return
	end

	local weaponsFolder = self:GetWeaponsFolder()
	if not weaponsFolder then
		warn("[DisbeliefPapyrus WeaponModule] Missing Weapons folder")
		return
	end

	local leftBoneTemplate = weaponsFolder:FindFirstChild("LeftBone")
	local rightBoneTemplate = weaponsFolder:FindFirstChild("RightBone")

	if not leftBoneTemplate then
		warn("[DisbeliefPapyrus WeaponModule] Missing Weapons > LeftBone")
		return
	end

	if not rightBoneTemplate then
		warn("[DisbeliefPapyrus WeaponModule] Missing Weapons > RightBone")
		return
	end

	local leftMotorTemplate =
		weaponsFolder:FindFirstChild("LeftBoneMotorTemplate")
		or weaponsFolder:FindFirstChild("BoneStaffMotorTemplate")

	local rightMotorTemplate =
		weaponsFolder:FindFirstChild("RightBoneMotorTemplate")
		or weaponsFolder:FindFirstChild("BoneStaffMotorTemplate")

	if not leftMotorTemplate or not leftMotorTemplate:IsA("Motor6D") then
		warn("[DisbeliefPapyrus WeaponModule] Missing LeftBoneMotorTemplate")
		return
	end

	if not rightMotorTemplate or not rightMotorTemplate:IsA("Motor6D") then
		warn("[DisbeliefPapyrus WeaponModule] Missing RightBoneMotorTemplate")
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "EquippedWeapons"
	folder:SetAttribute("CharacterWeapon", true)
	folder:SetAttribute("CharacterWeaponOwner", "DisbeliefPapyrus")
	folder:SetAttribute("CombatMode", "Phase2")
	folder.Parent = character

	local leftBone = leftBoneTemplate:Clone()
	leftBone.Name = "LeftBone"
	leftBone:SetAttribute("CharacterWeapon", true)
	leftBone:SetAttribute("CharacterWeaponOwner", "DisbeliefPapyrus")
	leftBone:SetAttribute("OriginalWeaponName", "LeftBone")
	leftBone.Parent = folder

	local rightBone = rightBoneTemplate:Clone()
	rightBone.Name = "RightBone"
	rightBone:SetAttribute("CharacterWeapon", true)
	rightBone:SetAttribute("CharacterWeaponOwner", "DisbeliefPapyrus")
	rightBone:SetAttribute("OriginalWeaponName", "RightBone")
	rightBone.Parent = folder

	local leftHandle = self:FindHandle(leftBone, {
		"LeftBoneHandle",
		"HandleLeft",
		"Handle",
	})

	local rightHandle = self:FindHandle(rightBone, {
		"RightBoneHandle",
		"HandleRight",
		"Handle",
	})

	if not leftHandle then
		folder:Destroy()
		warn("[DisbeliefPapyrus WeaponModule] LeftBone has no handle")
		return
	end

	if not rightHandle then
		folder:Destroy()
		warn("[DisbeliefPapyrus WeaponModule] RightBone has no handle")
		return
	end

	self:AttachWithMotor(character, leftBone, leftHandle, leftArm, leftMotorTemplate, "LeftBoneMotor", "LeftBone")
	self:AttachWithMotor(character, rightBone, rightHandle, rightArm, rightMotorTemplate, "RightBoneMotor", "RightBone")
end

function PapyrusWeapon:Equip(character)
	if not character or not character.Parent then return end

	local combatMode = character:GetAttribute("CombatMode")
	local papyrusMode = character:GetAttribute("PapyrusMode")
	local disbeliefPhase = character:GetAttribute("DisbeliefPhase")
	local phase2Active = character:GetAttribute("Phase2Active")

	if combatMode == "Phase2"
		or papyrusMode == "Phase2"
		or disbeliefPhase == 2
		or phase2Active == true
	then
		self:EquipPhase2(character)
	else
		self:EquipPhase1(character)
	end
end

return PapyrusWeapon