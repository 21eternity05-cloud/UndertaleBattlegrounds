local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponModule = {}

local CHARACTER_NAME = "GlitchtaleFrisk"

local SWORD_NAME = "GT Frisk Sword"
local SWORD_MOTOR_TEMPLATE_NAME = "GT Frisk SwordMotorTemplate"

local SHIELD_NAME = "GT Frisk Sheild"
local SHIELD_MOTOR_TEMPLATE_NAME = "GT Frisk SheildMotorTemplate"

local EQUIPPED_FOLDER_NAME = "EquippedWeapons"

function WeaponModule.new(config)
	local self = {
		Config = config,
	}

	self.Equip = function(a, b)
		local character = b or a
		return WeaponModule.Equip(character)
	end

	self.Remove = function(a, b)
		local character = b or a
		return WeaponModule.Remove(character)
	end

	return self
end

local function getCharacterAssetsFolder()
	local assets = ReplicatedStorage:WaitForChild("Assets")
	local characters = assets:WaitForChild("Characters")
	return characters:WaitForChild(CHARACTER_NAME)
end

local function getWeaponsFolder()
	local characterFolder = getCharacterAssetsFolder()
	return characterFolder:WaitForChild("Weapons")
end

local function findLimb(character, preferredNames)
	for _, name in ipairs(preferredNames) do
		local limb = character:FindFirstChild(name)
		if limb and limb:IsA("BasePart") then
			return limb
		end
	end

	return nil
end

local function getWeaponPart(weapon)
	if weapon:IsA("BasePart") then
		return weapon
	end

	if weapon:IsA("Model") then
		if weapon.PrimaryPart then
			return weapon.PrimaryPart
		end

		local primary = weapon:FindFirstChild("PrimaryPart", true)
		if primary and primary:IsA("BasePart") then
			weapon.PrimaryPart = primary
			return primary
		end

		local handle = weapon:FindFirstChild("Handle", true)
		if handle and handle:IsA("BasePart") then
			weapon.PrimaryPart = handle
			return handle
		end

		local firstPart = weapon:FindFirstChildWhichIsA("BasePart", true)
		if firstPart then
			weapon.PrimaryPart = firstPart
			return firstPart
		end
	end

	return nil
end

local function setupWeaponPhysics(weapon)
	if weapon:IsA("BasePart") then
		weapon.Anchored = false
		weapon.CanCollide = false
		weapon.CanTouch = false
		weapon.CanQuery = false
		weapon.Massless = true
	end

	for _, descendant in ipairs(weapon:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end
end

local function getOrCreateEquippedFolder(character)
	local folder = character:FindFirstChild(EQUIPPED_FOLDER_NAME)

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = EQUIPPED_FOLDER_NAME
		folder.Parent = character
	end

	return folder
end

local function removeByName(character, name)
	local found = character:FindFirstChild(name, true)

	if found then
		found:Destroy()
	end
end

local function equipWeapon(character, equippedFolder, weaponName, motorTemplateName, limbNames)
	local weaponsFolder = getWeaponsFolder()

	local weaponTemplate = weaponsFolder:FindFirstChild(weaponName)
	local motorTemplate = weaponsFolder:FindFirstChild(motorTemplateName)

	if not weaponTemplate then
		warn("[GlitchtaleFrisk WeaponModule] Missing weapon:", weaponName)
		return
	end

	if not motorTemplate then
		warn("[GlitchtaleFrisk WeaponModule] Missing motor template:", motorTemplateName)
		return
	end

	local limb = findLimb(character, limbNames)

	if not limb then
		warn("[GlitchtaleFrisk WeaponModule] Missing limb for:", weaponName)
		return
	end

	local weapon = weaponTemplate:Clone()
	weapon.Name = weaponName
	weapon.Parent = equippedFolder

	setupWeaponPhysics(weapon)

	local weaponPart = getWeaponPart(weapon)

	if not weaponPart then
		warn("[GlitchtaleFrisk WeaponModule] Weapon has no BasePart:", weaponName)
		weapon:Destroy()
		return
	end

	local motor = motorTemplate:Clone()
	motor.Name = motorTemplateName
	motor.Part0 = limb
	motor.Part1 = weaponPart
	motor.Parent = limb
end

function WeaponModule.Remove(character)
	if not character then
		return
	end

	local folder = character:FindFirstChild(EQUIPPED_FOLDER_NAME)
	if folder then
		folder:Destroy()
	end

	removeByName(character, SWORD_NAME)
	removeByName(character, SWORD_MOTOR_TEMPLATE_NAME)

	removeByName(character, SHIELD_NAME)
	removeByName(character, SHIELD_MOTOR_TEMPLATE_NAME)
end

function WeaponModule.Equip(character)
	if not character then
		return
	end

	WeaponModule.Remove(character)

	local equippedFolder = getOrCreateEquippedFolder(character)

	equipWeapon(character, equippedFolder, SWORD_NAME, SWORD_MOTOR_TEMPLATE_NAME, {
		"Right Arm",
		"RightHand",
		"RightLowerArm",
		"RightUpperArm",
	})

	equipWeapon(character, equippedFolder, SHIELD_NAME, SHIELD_MOTOR_TEMPLATE_NAME, {
		"Left Arm",
		"LeftHand",
		"LeftLowerArm",
		"LeftUpperArm",
	})
end

return WeaponModule