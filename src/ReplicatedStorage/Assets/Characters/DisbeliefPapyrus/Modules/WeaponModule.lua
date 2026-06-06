local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponModule = {}

local CHARACTER_NAME = "DisbeliefPapyrus"
local WEAPON_NAME = "BoneStaff"
local MOTOR_TEMPLATE_NAME = "BoneStaffMotorTemplate"

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

function WeaponModule.Remove(character)
	if not character then
		return
	end

	local folder = character:FindFirstChild(EQUIPPED_FOLDER_NAME)
	if folder then
		folder:Destroy()
	end

	removeByName(character, WEAPON_NAME)
	removeByName(character, MOTOR_TEMPLATE_NAME)
end

function WeaponModule.Equip(character)
	if not character then
		return
	end

	WeaponModule.Remove(character)

	local weaponsFolder = getWeaponsFolder()

	local weaponTemplate = weaponsFolder:FindFirstChild(WEAPON_NAME)
	local motorTemplate = weaponsFolder:FindFirstChild(MOTOR_TEMPLATE_NAME)

	if not weaponTemplate then
		warn("[DisbeliefPapyrus WeaponModule] Missing weapon:", WEAPON_NAME)
		return
	end

	if not motorTemplate then
		warn("[DisbeliefPapyrus WeaponModule] Missing motor template:", MOTOR_TEMPLATE_NAME)
		return
	end

	local rightArm = findLimb(character, {
		"Right Arm",
		"RightHand",
		"RightLowerArm",
		"RightUpperArm",
	})

	if not rightArm then
		warn("[DisbeliefPapyrus WeaponModule] Missing right arm/hand")
		return
	end

	local equippedFolder = getOrCreateEquippedFolder(character)

	local weapon = weaponTemplate:Clone()
	weapon.Name = WEAPON_NAME
	weapon.Parent = equippedFolder

	setupWeaponPhysics(weapon)

	local weaponPart = getWeaponPart(weapon)

	if not weaponPart then
		warn("[DisbeliefPapyrus WeaponModule] Weapon has no BasePart:", WEAPON_NAME)
		weapon:Destroy()
		return
	end

	local motor = motorTemplate:Clone()
	motor.Name = MOTOR_TEMPLATE_NAME
	motor.Part0 = rightArm
	motor.Part1 = weaponPart
	motor.Parent = rightArm
end

return WeaponModule