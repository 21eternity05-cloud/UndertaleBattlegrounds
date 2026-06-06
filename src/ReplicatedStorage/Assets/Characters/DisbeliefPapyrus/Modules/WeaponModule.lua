local PapyrusWeapon = {}
PapyrusWeapon.__index = PapyrusWeapon

function PapyrusWeapon.new(config, characterFolder)
	local self = setmetatable({}, PapyrusWeapon)
	self.Config = config
	self.CharacterFolder = characterFolder
	return self
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

function PapyrusWeapon:Remove(character)
	if not character or not character.Parent then return end

	local oldWeapon = character:FindFirstChild("EquippedWeapon")
	if oldWeapon then
		oldWeapon:Destroy()
	end

	local rightArm = character:FindFirstChild("Right Arm")
	if rightArm then
		local oldMotor = rightArm:FindFirstChild("BoneStaff")
		if oldMotor then
			oldMotor:Destroy()
		end
	end
end

function PapyrusWeapon:Equip(character)
	if not character or not character.Parent then return end

	self:Remove(character)

	local rightArm = character:FindFirstChild("Right Arm")
	if not rightArm then return end

	local weaponsFolder = self.CharacterFolder:FindFirstChild("Weapons")
	if not weaponsFolder then return end

	local staffTemplate = weaponsFolder:FindFirstChild("BoneStaff")
	local motorTemplate = weaponsFolder:FindFirstChild("BoneStaffMotorTemplate")

	if not staffTemplate then return end
	if not motorTemplate or not motorTemplate:IsA("Motor6D") then return end

	local staff = staffTemplate:Clone()
	staff.Name = "EquippedWeapon"
	staff.Parent = character

	local handle = staff:FindFirstChild("Handle", true)
		or staff:FindFirstChild("HandleStaff", true)
		or staff:FindFirstChild("BoneStaffHandle", true)

	if not handle or not handle:IsA("BasePart") then
		handle = staff:FindFirstChildWhichIsA("BasePart", true)
	end

	if not handle or not handle:IsA("BasePart") then
		staff:Destroy()
		warn("[DisbeliefPapyrus WeaponModule] BoneStaff has no handle/basepart")
		return
	end

	self:PrepareWeaponModel(staff)
	self:WeldWeaponPartsToHandle(staff, handle)

	local oldMotor = rightArm:FindFirstChild("BoneStaff")
	if oldMotor then
		oldMotor:Destroy()
	end

	local motor = motorTemplate:Clone()
	motor.Name = "BoneStaff"
	motor.Part0 = rightArm
	motor.Part1 = handle
	motor:SetAttribute("CharacterWeaponMotor", true)
	motor.Parent = rightArm
end

return PapyrusWeapon