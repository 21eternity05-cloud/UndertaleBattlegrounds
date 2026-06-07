local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local NPCM1 = {}
NPCM1.__index = NPCM1

local DEFAULT_WALKSPEED = 16
local DEFAULT_JUMPPOWER = 50
local DEFAULT_JUMPHEIGHT = 7.2

local FALLBACK_FINAL_M1 = 5

local FALLBACK_M1_DATA = {
	[1] = {
		Damage = 2,
		Stun = 0.65,
		Cooldown = 0.3,
		HitDelay = 0.08,
		Radius = 7.5,
		Offset = CFrame.new(0, 0, -6.4),
		Knockback = 0,
		UpwardKnockback = 0,
		CarryDuration = 0.25,
	},

	[2] = {
		Damage = 2,
		Stun = 0.7,
		Cooldown = 0.3,
		HitDelay = 0.08,
		Radius = 7.5,
		Offset = CFrame.new(0, 0, -6.4),
		Knockback = 0,
		UpwardKnockback = 0,
		CarryDuration = 0.25,
	},

	[3] = {
		Damage = 2,
		Stun = 0.75,
		Cooldown = 0.32,
		HitDelay = 0.08,
		Radius = 7.5,
		Offset = CFrame.new(0, 0, -6.5),
		Knockback = 0,
		UpwardKnockback = 0,
		CarryDuration = 0.28,
	},

	[4] = {
		Damage = 2,
		Stun = 0.8,
		Cooldown = 0.32,
		HitDelay = 0.08,
		Radius = 7.5,
		Offset = CFrame.new(0, 0, -6.5),
		Knockback = 0,
		UpwardKnockback = 0,
		CarryDuration = 0.28,
	},

	[5] = {
		Damage = 3,
		Stun = 0.95,
		Cooldown = 0.65,
		HitDelay = 0.1,
		Radius = 7.5,
		Offset = CFrame.new(0, 0, -6.6),
		Knockback = 110,
		UpwardKnockback = 55,
		KnockbackDuration = 0.28,
		KnockbackMaxForce = 120000,
	},
}

local FALLBACK_UPTILT_DATA = {
	Damage = 2,
	Stun = 1.2,
	Cooldown = 0.45,
	HitDelay = 0.09,
	Radius = 7.5,
	Offset = CFrame.new(0, 1.5, -6.4),

	LiftHeight = 16,
	LiftDuration = 0.7,
	MinHorizontalSpacing = 4,

	Responsiveness = 35,
	MaxForce = 100000,
	MaxVelocity = 55,
}

local FALLBACK_DOWNSLAM_DATA = {
	Damage = 3,
	Stun = 1.0,
	Cooldown = 0.75,
	HitDelay = 0.08,
	Radius = 7.5,
	Offset = CFrame.new(0, -1.1, -6.5),

	DownForwardSpeed = 70,
	DownSpeed = -85,
	AirStunMax = 1.3,
	GroundSplatStun = 0.55,

	KnockbackDuration = 0.22,
	KnockbackMaxForce = 140000,
}

local function copyData(data)
	local copy = {}

	for key, value in pairs(data or {}) do
		copy[key] = value
	end

	return copy
end

function NPCM1.new(config, services)
	local self = setmetatable({}, NPCM1)

	self.Config = config or {}
	services = services or {}

	self.ActiveCarries = {}
	self.ActiveYHolds = {}

	self.CombatVFXFolder = ReplicatedStorage:FindFirstChild("CombatVFX")
	self.CombatSFXFolder = ReplicatedStorage:FindFirstChild("CombatSFX")

	self.MovementService = services.MovementService
	self.BlockService = services.BlockService
	self.StateService = services.StateService
	self.VFXService = services.VFXService
	self.CounterService = services.CounterService
	self.CombatStatusService = services.CombatStatusService

	local combatServer = ServerScriptService:FindFirstChild("CombatServer")
	local movementServiceModule = combatServer and combatServer:FindFirstChild("MovementService")

	if not self.MovementService and movementServiceModule then
		local success, movementService = pcall(function()
			return require(movementServiceModule).new(self.Config)
		end)

		if success then
			self.MovementService = movementService
		else
			warn("[NPCM1] Failed to create MovementService:", movementService)
		end
	end

	return self
end

function NPCM1:BuildAttackData(baseData, extraData)
	local data = {}

	for key, value in pairs(baseData or {}) do
		data[key] = value
	end

	for key, value in pairs(extraData or {}) do
		data[key] = value
	end

	if data.CanBeBlocked == nil and data.Blockable ~= nil then
		data.CanBeBlocked = data.Blockable ~= false
	end
	if data.CanBeBlocked == nil then
		data.CanBeBlocked = true
	end
	if data.Unblockable == nil then
		data.Unblockable = false
	end
	if data.CanBeCountered == nil then
		data.CanBeCountered = true
	end
	if data.HitCancelsTarget == nil then
		data.HitCancelsTarget = true
	end
	if data.CancelableByHit == nil then
		data.CancelableByHit = true
	end
	if data.IgnoresIFrames == nil then
		data.IgnoresIFrames = false
	end
	if data.IgnoresArmor == nil then
		data.IgnoresArmor = false
	end

	return data
end

function NPCM1:CanAttackBeBlocked(attackData)
	if self.CombatStatusService and self.CombatStatusService.CanAttackBeBlocked then
		return self.CombatStatusService:CanAttackBeBlocked(attackData)
	end

	if attackData.Unblockable == true then return false end
	if attackData.CanBeBlocked == false then return false end
	if attackData.Blockable == false then return false end

	return true
end

function NPCM1:GetArmorInfo(targetCharacter, attackData)
	if self.CombatStatusService and self.CombatStatusService.GetArmorInfo then
		return self.CombatStatusService:GetArmorInfo(targetCharacter, attackData)
	end

	return {
		Active = false,
		DamageReduction = 0,
		PreventsStun = false,
		PreventsKnockback = false,
		PreventsHitCancel = false,
	}
end

function NPCM1:TryHitCancelTarget(targetCharacter, attackData)
	if self.CombatStatusService and self.CombatStatusService.TryHitCancelTarget then
		return self.CombatStatusService:TryHitCancelTarget(targetCharacter, attackData)
	end

	return false
end

function NPCM1:HasIFrames(targetCharacter, attackData)
	if self.CombatStatusService and self.CombatStatusService.HasIFrames then
		return self.CombatStatusService:HasIFrames(targetCharacter, attackData)
	end

	return targetCharacter:GetAttribute("IFrameActive") == true
end

function NPCM1:IsDamageLocked(targetCharacter, attackerCharacter)
	if self.CombatStatusService and self.CombatStatusService.IsDamageLockedFromAttacker then
		return self.CombatStatusService:IsDamageLockedFromAttacker(targetCharacter, attackerCharacter)
	end

	return false
end

function NPCM1:IsM1Immune(targetCharacter)
	if self.StateService and self.StateService.IsM1Immune then
		return self.StateService:IsM1Immune(targetCharacter)
	end

	return os.clock() < (targetCharacter:GetAttribute("M1ImmuneUntil") or 0)
end

function NPCM1:ApplyM1Immunity(targetCharacter, duration)
	if self.StateService and self.StateService.ApplyM1Immunity then
		self.StateService:ApplyM1Immunity(targetCharacter, duration)
		return
	end

	targetCharacter:SetAttribute("M1ImmuneUntil", os.clock() + duration)
end

function NPCM1:TryStandardHitStart(npc, npcRoot, target, targetHumanoid, targetRoot, attackData, attackName, options)
	options = options or {}

	if not target or not target.Parent then return "Invalid" end
	if not targetHumanoid or targetHumanoid.Health <= 0 then return "Invalid" end
	if not targetRoot or not targetRoot.Parent then return "Invalid" end

	if self:IsDamageLocked(target, npc) then
		return "DamageLocked"
	end

	if self:HasIFrames(target, attackData) then
		return "IFrame"
	end

	if self:TryTriggerCounter(target, npc, attackName, attackData) then
		return "Countered"
	end

	if options.RespectM1Immunity and self:IsM1Immune(target) then
		return "M1Immune"
	end

	local canBlock = self:CanAttackBeBlocked(attackData)

	if canBlock and options.BlockMode == "Normal" then
		if self.BlockService and self.BlockService.CanBlockHit and self.BlockService:CanBlockHit(target, npcRoot, attackData) then
			if self.BlockService.PlayBlockVFX then
				self.BlockService:PlayBlockVFX(targetRoot)
			end

			return "Blocked"
		end
	elseif canBlock and options.BlockMode == "GuardbreakBlocking" then
		if target:GetAttribute("Blocking") then
			if self.StateService and self.StateService.GuardbreakCharacter then
				self.StateService:GuardbreakCharacter(target, attackData.GuardbreakStun or 1.4)
			end

			self:ApplyM1Immunity(target, self.Config.PostM5M1Immunity or 1)

			if self.BlockService and self.BlockService.PlayBlockBreakVFX then
				self.BlockService:PlayBlockBreakVFX(targetRoot)
			end

			return "Guardbreak"
		end
	end

	return "CanHit"
end

function NPCM1:ApplyDamageAndStun(npc, target, targetHumanoid, targetRoot, attackData, stunDuration, stunAnimationKey)
	local armorInfo = self:GetArmorInfo(target, attackData)

	self:TryHitCancelTarget(target, attackData)

	local rawDamage = attackData.Damage or 0
	local finalDamage = rawDamage

	if armorInfo.Active then
		finalDamage = rawDamage * (1 - (armorInfo.DamageReduction or 0))
	end

	if finalDamage > 0 then
		targetHumanoid:TakeDamage(finalDamage)

		if self.CombatStatusService and self.CombatStatusService.TagCombatPair then
			self.CombatStatusService:TagCombatPair(npc, target)
		end
	end

	if stunDuration and stunDuration > 0 then
		if not armorInfo.Active or not armorInfo.PreventsStun then
			if self.StateService and self.StateService.StunCharacter then
				self.StateService:StunCharacter(target, stunDuration, stunAnimationKey)
			else
				self:StunTarget(target, stunDuration)
			end
		end
	end

	if self.VFXService and self.VFXService.EmitHitVFXOnVictim then
		self.VFXService:EmitHitVFXOnVictim(targetRoot, npc)
	else
		self:EmitHitVFX(targetRoot)
	end

	return armorInfo
end

function NPCM1:GetFinalM1()
	return self.Config.FinalM1 or FALLBACK_FINAL_M1
end

function NPCM1:GetComboResetTime()
	return self.Config.ComboResetTime or self.Config.M1ComboResetTime or 1.3
end

function NPCM1:GetM1Data(combo)
	local m1Data = self.Config.M1Data

	if typeof(m1Data) == "table" then
		local data = m1Data[combo]

		if typeof(data) == "table" then
			return copyData(data)
		end

		data = m1Data["M" .. tostring(combo)]

		if typeof(data) == "table" then
			return copyData(data)
		end
	end

	return copyData(FALLBACK_M1_DATA[combo] or FALLBACK_M1_DATA[1])
end

function NPCM1:GetUptiltData()
	local m1Data = self.Config.M1Data

	if typeof(m1Data) == "table" then
		local data = m1Data.Uptilt or m1Data.UPTILT or m1Data.UpTilt

		if typeof(data) == "table" then
			return copyData(data)
		end
	end

	if typeof(self.Config.UptiltData) == "table" then
		return copyData(self.Config.UptiltData)
	end

	return copyData(FALLBACK_UPTILT_DATA)
end

function NPCM1:GetDownslamData()
	local m1Data = self.Config.M1Data

	if typeof(m1Data) == "table" then
		local data = m1Data.Downslam or m1Data.DOWNSLAM or m1Data.DownSlam

		if typeof(data) == "table" then
			return copyData(data)
		end
	end

	if typeof(self.Config.DownslamData) == "table" then
		return copyData(self.Config.DownslamData)
	end

	return copyData(FALLBACK_DOWNSLAM_DATA)
end

function NPCM1:SetupNPC(npc)
	npc:SetAttribute("NPCComboCount", 0)
	npc:SetAttribute("NPCLastM1Time", 0)
	npc:SetAttribute("NPCAttacking", false)
	npc:SetAttribute("NPCUsedUptilt", false)
	npc:SetAttribute("NPCAirComboReady", false)
end

function NPCM1:GetHumanoidAndRoot(model)
	if not model then return nil, nil end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")

	return humanoid, root
end

function NPCM1:GetOrCreateCounterAttackerValue(character)
	if not character or not character.Parent then return nil end

	local value = character:FindFirstChild("CounterAttacker")

	if not value then
		value = Instance.new("ObjectValue")
		value.Name = "CounterAttacker"
		value.Parent = character
	end

	return value
end

function NPCM1:TryTriggerCounter(targetCharacter, attackerCharacter, attackName, attackData)
	if not targetCharacter or not targetCharacter.Parent then return false end
	if not attackerCharacter or not attackerCharacter.Parent then return false end
	if targetCharacter == attackerCharacter then return false end

	if self.CounterService and self.CounterService.TryCounterHit then
		return self.CounterService:TryCounterHit({
			AttackerCharacter = attackerCharacter,
			TargetCharacter = targetCharacter,
			AttackName = attackName or "DummyM1",
			AttackData = attackData,
			OnCountered = function()
				local attackerRoot = attackerCharacter:FindFirstChild("HumanoidRootPart")
				local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")
				self:StopAllMovementControllers(attackerRoot, targetRoot)
			end,
		})
	end

	local targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
	if not targetHumanoid or targetHumanoid.Health <= 0 then return false end

	local isCountering = targetCharacter:GetAttribute("Countering") == true
	local alreadyTriggered = targetCharacter:GetAttribute("CounterTriggered") == true

	if not isCountering and not alreadyTriggered then
		return false
	end

	local attackerValue = self:GetOrCreateCounterAttackerValue(targetCharacter)
	if attackerValue then
		attackerValue.Value = attackerCharacter
	end

	targetCharacter:SetAttribute("CounterTriggered", true)
	targetCharacter:SetAttribute("Countering", false)
	targetCharacter:SetAttribute("CounterAttackName", attackName or "DummyM1")

	local attackerRoot = attackerCharacter:FindFirstChild("HumanoidRootPart")
	local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")

	self:StopAllMovementControllers(attackerRoot, targetRoot)

	print("[NPCM1] Counter triggered by dummy:", attackerCharacter.Name, "->", targetCharacter.Name)

	return true
end

function NPCM1:StopAllMovementControllers(npcRoot, targetRoot)
	self:StopCarry(npcRoot)
	self:StopCarry(targetRoot)
	self:StopYHold(npcRoot)
	self:StopYHold(targetRoot)

	if self.MovementService and self.MovementService.ClearCombatMovementControllers then
		self.MovementService:ClearCombatMovementControllers(npcRoot)
		self.MovementService:ClearCombatMovementControllers(targetRoot)
	end

	if npcRoot and npcRoot.Parent then
		npcRoot.AssemblyLinearVelocity = Vector3.zero
		npcRoot.AssemblyAngularVelocity = Vector3.zero
	end

	if targetRoot and targetRoot.Parent then
		targetRoot.AssemblyLinearVelocity = Vector3.zero
		targetRoot.AssemblyAngularVelocity = Vector3.zero
	end
end

function NPCM1:CanAttack(npc)
	local humanoid, root = self:GetHumanoidAndRoot(npc)

	if not humanoid or not root then return false end
	if humanoid.Health <= 0 then return false end
	if npc:GetAttribute("NPCAttacking") then return false end
	if npc:GetAttribute("Stunned") then return false end
	if npc:GetAttribute("Guardbroken") then return false end

	return true
end

function NPCM1:IsAirborne(humanoid)
	local state = humanoid:GetState()

	return state == Enum.HumanoidStateType.Jumping
		or state == Enum.HumanoidStateType.Freefall
end

function NPCM1:ResetCombo(npc)
	npc:SetAttribute("NPCComboCount", 0)
	npc:SetAttribute("NPCLastM1Time", 0)
	npc:SetAttribute("NPCUsedUptilt", false)
	npc:SetAttribute("NPCAirComboReady", false)
end

function NPCM1:RefreshCombo(npc)
	local last = npc:GetAttribute("NPCLastM1Time") or 0
	local resetTime = self:GetComboResetTime()

	if last > 0 and os.clock() - last > resetTime then
		self:ResetCombo(npc)
	end
end

function NPCM1:GetNextCombo(npc)
	self:RefreshCombo(npc)

	local finalM1 = self:GetFinalM1()
	local combo = npc:GetAttribute("NPCComboCount") or 0
	combo += 1

	if combo > finalM1 then
		combo = 1
	end

	npc:SetAttribute("NPCComboCount", combo)
	npc:SetAttribute("NPCLastM1Time", os.clock())

	return combo
end

function NPCM1:StunTarget(character, duration)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local stunId = (character:GetAttribute("StunId") or 0) + 1
	character:SetAttribute("StunId", stunId)

	character:SetAttribute("Stunned", true)
	character:SetAttribute("Blocking", false)

	humanoid.WalkSpeed = 0
	humanoid.Jump = false
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	task.delay(duration, function()
		if not character or not character.Parent then return end
		if character:GetAttribute("StunId") ~= stunId then return end

		local currentHumanoid = character:FindFirstChildOfClass("Humanoid")
		if not currentHumanoid or currentHumanoid.Health <= 0 then return end

		character:SetAttribute("Stunned", false)

		currentHumanoid.WalkSpeed = DEFAULT_WALKSPEED
		currentHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		currentHumanoid.JumpPower = DEFAULT_JUMPPOWER
		currentHumanoid.JumpHeight = DEFAULT_JUMPHEIGHT
	end)
end

function NPCM1:EmitHitVFX(root)
	if not root or not root.Parent then return end
	if not self.CombatVFXFolder then return end

	local template = self.CombatVFXFolder:FindFirstChild("Hit")
	if not template or not template:IsA("Attachment") then return end

	local attachment = template:Clone()
	attachment.Parent = root

	for _, descendant in ipairs(attachment:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false

			local emitCount = descendant:GetAttribute("EmitCount")
			if typeof(emitCount) ~= "number" then
				emitCount = 20
			end

			descendant:Emit(emitCount)
		end
	end

	Debris:AddItem(attachment, 2)
end

function NPCM1:PlaySFX(name, root)
	if not root or not root.Parent then return end
	if not self.CombatSFXFolder then return end

	local template = self.CombatSFXFolder:FindFirstChild(name)
	if not template or not template:IsA("Sound") then return end

	local sound = template:Clone()
	sound.Parent = root
	sound:Play()

	Debris:AddItem(sound, 3)
end

function NPCM1:ShowDebugSphere(position, radius)
	if not workspace:GetAttribute("DebugHitboxes") then
		return
	end

	local sphere = Instance.new("Part")
	sphere.Name = "NPCDebugHitbox"
	sphere.Shape = Enum.PartType.Ball
	sphere.Anchored = true
	sphere.CanCollide = false
	sphere.CanTouch = false
	sphere.CanQuery = false
	sphere.Material = Enum.Material.Neon
	sphere.Color = Color3.fromRGB(255, 125, 0)
	sphere.Transparency = 0.55
	sphere.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
	sphere.Position = position
	sphere.Parent = workspace

	Debris:AddItem(sphere, 0.12)
end

function NPCM1:GetTargetsInSphere(npc, position, radius)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { npc }

	local parts = workspace:GetPartBoundsInRadius(position, radius, params)

	local targets = {}
	local found = {}

	for _, part in ipairs(parts) do
		local model = part:FindFirstAncestorOfClass("Model")

		if model and model ~= npc and not found[model] then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local root = model:FindFirstChild("HumanoidRootPart")

			if humanoid and root and humanoid.Health > 0 then
				found[model] = true
				table.insert(targets, model)
			end
		end
	end

	return targets
end

function NPCM1:PerformHitbox(npc, npcRoot, data, onHit)
	local hitboxCFrame = npcRoot.CFrame * (data.Offset or CFrame.new(0, 0, -5))
	local position = hitboxCFrame.Position
	local radius = data.Radius or 7

	self:ShowDebugSphere(position, radius)

	local targets = self:GetTargetsInSphere(npc, position, radius)

	for _, target in ipairs(targets) do
		local humanoid = target:FindFirstChildOfClass("Humanoid")
		local root = target:FindFirstChild("HumanoidRootPart")

		if humanoid and root then
			onHit(target, humanoid, root)
		end
	end
end

function NPCM1:GetDirectionBetween(aRoot, bRoot)
	local direction = bRoot.Position - aRoot.Position

	if direction.Magnitude < 0.1 then
		return aRoot.CFrame.LookVector
	end

	return direction.Unit
end

function NPCM1:StopCarry(root)
	if not root then return end

	if self.ActiveCarries[root] then
		self.ActiveCarries[root]:Disconnect()
		self.ActiveCarries[root] = nil
	end
end

function NPCM1:StopYHold(root)
	if not root then return end

	if self.ActiveYHolds[root] then
		self.ActiveYHolds[root]:Disconnect()
		self.ActiveYHolds[root] = nil
	end
end

function NPCM1:StartYHold(root, duration)
	if not root or not root.Parent then return end

	self:StopYHold(root)

	local startTime = os.clock()

	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not root.Parent then
			connection:Disconnect()
			self.ActiveYHolds[root] = nil
			return
		end

		if os.clock() - startTime >= duration then
			connection:Disconnect()
			self.ActiveYHolds[root] = nil
			return
		end

		local velocity = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	end)

	self.ActiveYHolds[root] = connection
end

function NPCM1:StartCarry(npcRoot, targetRoot, data)
	if not npcRoot or not targetRoot then return end

	self:StopCarry(npcRoot)
	self:StopCarry(targetRoot)

	local startTime = os.clock()
	local duration = data.CarryDuration or 0.25

	local direction = self:GetDirectionBetween(npcRoot, targetRoot)
	direction = Vector3.new(direction.X, 0, direction.Z)

	if direction.Magnitude < 0.05 then
		direction = npcRoot.CFrame.LookVector
		direction = Vector3.new(direction.X, 0, direction.Z)
	end

	if direction.Magnitude < 0.05 then
		direction = Vector3.new(0, 0, -1)
	else
		direction = direction.Unit
	end

	local carrySpeed = data.CarrySpeed or 18
	local chaseSpeed = data.AttackerCarrySpeed or 20

	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not npcRoot.Parent or not targetRoot.Parent then
			connection:Disconnect()
			self.ActiveCarries[npcRoot] = nil
			self.ActiveCarries[targetRoot] = nil
			return
		end

		if os.clock() - startTime >= duration then
			connection:Disconnect()
			self.ActiveCarries[npcRoot] = nil
			self.ActiveCarries[targetRoot] = nil
			return
		end

		local toTarget = targetRoot.Position - npcRoot.Position
		local chaseDirection = Vector3.new(toTarget.X, 0, toTarget.Z)

		if chaseDirection.Magnitude < 0.05 then
			chaseDirection = direction
		else
			chaseDirection = chaseDirection.Unit
		end

		npcRoot.AssemblyLinearVelocity = Vector3.new(
			chaseDirection.X * chaseSpeed,
			0,
			chaseDirection.Z * chaseSpeed
		)

		targetRoot.AssemblyLinearVelocity = Vector3.new(
			direction.X * carrySpeed,
			0,
			direction.Z * carrySpeed
		)
	end)

	self.ActiveCarries[npcRoot] = connection
	self.ActiveCarries[targetRoot] = connection
end

function NPCM1:StartUptilt(npcRoot, targetRoot)
	local data = self:GetUptiltData()

	self:StopCarry(npcRoot)
	self:StopCarry(targetRoot)
	self:StopYHold(npcRoot)
	self:StopYHold(targetRoot)

	if self.MovementService and self.MovementService.ClearCombatMovementControllers then
		self.MovementService:ClearCombatMovementControllers(npcRoot)
		self.MovementService:ClearCombatMovementControllers(targetRoot)
	end

	npcRoot.AssemblyLinearVelocity = Vector3.zero
	targetRoot.AssemblyLinearVelocity = Vector3.zero

	local duration = data.LiftDuration or 0.7
	local startPos = npcRoot.Position
	local targetY = startPos.Y + (data.LiftHeight or 16)

	local offset = targetRoot.Position - npcRoot.Position
	local horizontalOffset = Vector3.new(offset.X, 0, offset.Z)

	if horizontalOffset.Magnitude < (data.MinHorizontalSpacing or 4) then
		horizontalOffset = npcRoot.CFrame.LookVector * (data.MinHorizontalSpacing or 4)
	end

	local npcGoal = Vector3.new(startPos.X, targetY, startPos.Z)
	local targetGoal = npcGoal + horizontalOffset

	local function makeAlign(root, goal)
		local attachment = Instance.new("Attachment")
		attachment.Name = "DummyUptiltAttachment"
		attachment.Parent = root

		local align = Instance.new("AlignPosition")
		align.Name = "DummyUptiltAlign"
		align.Attachment0 = attachment
		align.Mode = Enum.PositionAlignmentMode.OneAttachment
		align.Position = goal
		align.RigidityEnabled = false
		align.ReactionForceEnabled = false
		align.ApplyAtCenterOfMass = true
		align.Responsiveness = data.Responsiveness or 35
		align.MaxForce = data.MaxForce or 100000
		align.MaxVelocity = data.MaxVelocity or 55
		align.Parent = root

		Debris:AddItem(align, duration)
		Debris:AddItem(attachment, duration)

		return align
	end

	local npcAlign = makeAlign(npcRoot, npcGoal)
	local targetAlign = makeAlign(targetRoot, targetGoal)

	task.delay(duration, function()
		if npcAlign then npcAlign:Destroy() end
		if targetAlign then targetAlign:Destroy() end

		if npcRoot and npcRoot.Parent then
			npcRoot.AssemblyLinearVelocity = Vector3.zero
			self:StartYHold(npcRoot, 0.35)
		end

		if targetRoot and targetRoot.Parent then
			targetRoot.AssemblyLinearVelocity = Vector3.zero
			self:StartYHold(targetRoot, 0.35)
		end
	end)
end

function NPCM1:ApplyDownslamVelocity(targetRoot, velocity, data)
	if self.MovementService and self.MovementService.ApplyForceKnockback then
		return self.MovementService:ApplyForceKnockback(
			targetRoot,
			velocity,
			data.KnockbackDuration or 0.22,
			data.KnockbackMaxForce or 140000,
			"DummyDownslam"
		)
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "DummyDownslamVelocityAttachment"
	attachment.Parent = targetRoot

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "DummyDownslamLinearVelocity"
	linearVelocity.Attachment0 = attachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.VectorVelocity = velocity
	linearVelocity.MaxForce = data.KnockbackMaxForce or 100000
	linearVelocity.Parent = targetRoot

	Debris:AddItem(linearVelocity, (data.KnockbackDuration or 0.22) + 0.1)
	Debris:AddItem(attachment, (data.KnockbackDuration or 0.22) + 0.1)

	return linearVelocity, attachment
end

function NPCM1:GetGroundBelow(root, exclude)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude or {}

	return workspace:Raycast(root.Position, Vector3.new(0, -5, 0), params)
end

function NPCM1:MonitorGroundSplat(target, targetRoot, linearVelocity, attachment)
	local data = self:GetDownslamData()
	local startTime = os.clock()
	local maxTime = data.AirStunMax or 1.3

	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not target.Parent or not targetRoot.Parent then
			connection:Disconnect()
			if linearVelocity then linearVelocity:Destroy() end
			if attachment then attachment:Destroy() end
			return
		end

		if os.clock() - startTime > maxTime then
			connection:Disconnect()
			if linearVelocity then linearVelocity:Destroy() end
			if attachment then attachment:Destroy() end
			return
		end

		local result = self:GetGroundBelow(targetRoot, { target })

		if result then
			connection:Disconnect()

			if linearVelocity then linearVelocity:Destroy() end
			if attachment then attachment:Destroy() end

			targetRoot.AssemblyLinearVelocity = Vector3.zero

			if self.StateService and self.StateService.StunCharacter then
				self.StateService:StunCharacter(target, data.GroundSplatStun or 0.55, "DownslamSplat")
			else
				self:StunTarget(target, data.GroundSplatStun or 0.55)
			end

			if self.VFXService and self.VFXService.PlaySFXAtPart then
				self.VFXService:PlaySFXAtPart("GroundSplat", targetRoot, 3)
			else
				self:PlaySFX("GroundSplat", targetRoot)
			end
		end
	end)
end

function NPCM1:DoDownslam(npc)
	local humanoid, root = self:GetHumanoidAndRoot(npc)
	if not humanoid or not root then return end
	if not self:CanAttack(npc) then return end

	local data = self:GetDownslamData()
	local attackData = self:BuildAttackData(data, {
		AttackType = "Downslam",
		CanBeBlocked = false,
		Unblockable = true,
		CanBeCountered = true,
		HitCancelsTarget = true,
		Damage = data.Damage,
		Stun = data.AirStunMax or data.Stun or 1.3,
	})

	npc:SetAttribute("NPCAttacking", true)
	npc:SetAttribute("NPCAirComboReady", false)

	task.delay(data.HitDelay or 0.08, function()
		if not npc.Parent or humanoid.Health <= 0 then return end

		self:PerformHitbox(npc, root, data, function(target, targetHumanoid, targetRoot)
			local result = self:TryStandardHitStart(
				npc,
				root,
				target,
				targetHumanoid,
				targetRoot,
				attackData,
				"DummyDownslam",
				{
					RespectM1Immunity = false,
					BlockMode = "None",
				}
			)

			if result == "Countered" then
				self:StopAllMovementControllers(root, targetRoot)
				print("[NPCM1] Downslam countered")
				return
			end

			if result == "IFrame" or result == "DamageLocked" or result == "Invalid" then
				return
			end

			local forward = root.CFrame.LookVector

			self:StopAllMovementControllers(root, targetRoot)

			local armorInfo = self:ApplyDamageAndStun(
				npc,
				target,
				targetHumanoid,
				targetRoot,
				attackData,
				data.AirStunMax or 1.3,
				"DownslamAir"
			)

			if self.VFXService and self.VFXService.PlaySFXAtPart then
				self.VFXService:PlaySFXAtPart("DownslamHit", targetRoot, 3)
			else
				self:PlaySFX("DownslamHit", targetRoot)
			end

			if armorInfo.Active and armorInfo.PreventsKnockback then
				return
			end

			local velocity =
				forward * (data.DownForwardSpeed or 70)
				+ Vector3.new(0, data.DownSpeed or -85, 0)

			local linearVelocity, attachment = self:ApplyDownslamVelocity(targetRoot, velocity, data)

			root.AssemblyLinearVelocity = forward * 15 + Vector3.new(0, -25, 0)

			self:MonitorGroundSplat(target, targetRoot, linearVelocity, attachment)
		end)
	end)

	task.delay(data.Cooldown or 0.75, function()
		if npc and npc.Parent then
			npc:SetAttribute("NPCAttacking", false)
			self:ResetCombo(npc)
		end
	end)
end

function NPCM1:DoUptilt(npc)
	local humanoid, root = self:GetHumanoidAndRoot(npc)
	if not humanoid or not root then return end
	if not self:CanAttack(npc) then return end
	if npc:GetAttribute("NPCUsedUptilt") then return end

	local data = self:GetUptiltData()
	local attackData = self:BuildAttackData(data, {
		AttackType = "Uptilt",
		CanBeBlocked = true,
		CanBeCountered = true,
		HitCancelsTarget = true,
		Damage = data.Damage,
		Stun = data.Stun,
	})

	npc:SetAttribute("NPCAttacking", true)
	npc:SetAttribute("NPCUsedUptilt", true)
	npc:SetAttribute("NPCAirComboReady", true)

	task.delay(data.HitDelay or 0.09, function()
		if not npc.Parent or humanoid.Health <= 0 then return end

		self:PerformHitbox(npc, root, data, function(target, targetHumanoid, targetRoot)
			local result = self:TryStandardHitStart(
				npc,
				root,
				target,
				targetHumanoid,
				targetRoot,
				attackData,
				"DummyUptilt",
				{
					RespectM1Immunity = true,
					BlockMode = "Normal",
				}
			)

			if result == "Countered" then
				self:StopAllMovementControllers(root, targetRoot)
				print("[NPCM1] Uptilt countered")
				return
			end

			if result == "IFrame" or result == "M1Immune" or result == "DamageLocked" or result == "Invalid" then
				return
			end

			if result == "Blocked" then
				print("[NPCM1] Uptilt blocked")
				return
			end

			local currentCombo = npc:GetAttribute("NPCComboCount") or 0
			npc:SetAttribute("NPCComboCount", math.clamp(currentCombo + 1, 1, self:GetFinalM1() - 1))
			npc:SetAttribute("NPCLastM1Time", os.clock())

			local armorInfo = self:ApplyDamageAndStun(
				npc,
				target,
				targetHumanoid,
				targetRoot,
				attackData,
				data.Stun or 1.2
			)

			if not armorInfo.Active or not armorInfo.PreventsKnockback then
				self:StartUptilt(root, targetRoot)
			end
		end)
	end)

	task.delay(data.Cooldown or 0.45, function()
		if npc and npc.Parent then
			npc:SetAttribute("NPCAttacking", false)
		end
	end)
end

function NPCM1:ApplyM5Knockback(root, targetRoot, data)
	local direction = self:GetDirectionBetween(root, targetRoot)

	if self.MovementService and self.MovementService.ApplyDirectionalKnockback then
		self.MovementService:ApplyDirectionalKnockback(
			root,
			targetRoot,
			data,
			"DummyM5"
		)
	else
		targetRoot.AssemblyLinearVelocity =
			direction * (data.Knockback or 110)
			+ Vector3.new(0, data.UpwardKnockback or 55, 0)
	end
end

function NPCM1:PerformM1(npc, options)
	if not npc or not npc.Parent then return end
	if not self:CanAttack(npc) then return end

	options = options or {}

	if options.wantUptilt then
		self:DoUptilt(npc)
		return
	end

	local humanoid, root = self:GetHumanoidAndRoot(npc)
	if not humanoid or not root then return end

	local finalM1 = self:GetFinalM1()
	local combo = self:GetNextCombo(npc)

	if combo == finalM1 and self:IsAirborne(humanoid) then
		self:DoDownslam(npc)
		return
	end

	local data = self:GetM1Data(combo)
	local isFinal = combo == finalM1
	local attackData = self:BuildAttackData(data, {
		AttackType = "M1",
		Combo = combo,
		CanBeBlocked = true,
		CanBeCountered = true,
		HitCancelsTarget = true,
		Guardbreak = isFinal and data.Guardbreak == true,
		GuardbreakStun = data.GuardbreakStun,
		Damage = data.Damage,
		Stun = data.Stun,
	})

	npc:SetAttribute("NPCAttacking", true)

	task.delay(data.HitDelay or 0.08, function()
		if not npc.Parent or humanoid.Health <= 0 then return end

		self:PerformHitbox(npc, root, data, function(target, targetHumanoid, targetRoot)
			local blockMode = isFinal and "GuardbreakBlocking" or "Normal"

			local result = self:TryStandardHitStart(
				npc,
				root,
				target,
				targetHumanoid,
				targetRoot,
				attackData,
				"DummyM" .. tostring(combo),
				{
					RespectM1Immunity = not isFinal,
					BlockMode = blockMode,
				}
			)

			if result == "Countered" then
				self:StopAllMovementControllers(root, targetRoot)
				print("[NPCM1] M" .. combo .. " countered")
				return
			end

			if result == "IFrame" or result == "M1Immune" or result == "DamageLocked" or result == "Invalid" then
				return
			end

			if result == "Blocked" then
				print("[NPCM1] M" .. combo .. " blocked")
				return
			end

			if result == "Guardbreak" then
				self:StopAllMovementControllers(root, targetRoot)
				print("[NPCM1] M" .. combo .. " guardbreak")
				return
			end

			local armorInfo = self:ApplyDamageAndStun(
				npc,
				target,
				targetHumanoid,
				targetRoot,
				attackData,
				data.Stun or 0.65
			)

			if combo < finalM1 then
				if not armorInfo.Active or not armorInfo.PreventsKnockback then
					self:StartCarry(root, targetRoot, data)
					self:StartYHold(root, data.YHoldDuration or 0.35)
					self:StartYHold(targetRoot, data.YHoldDuration or 0.35)
				end
			else
				self:StopAllMovementControllers(root, targetRoot)

				if not armorInfo.Active or not armorInfo.PreventsKnockback then
					self:ApplyM5Knockback(root, targetRoot, data)
				end

				self:ApplyM1Immunity(target, self.Config.PostM5M1Immunity or 1)

				if self.VFXService and self.VFXService.PlaySFXAtPart then
					self.VFXService:PlaySFXAtPart("GroundM5", targetRoot, 3)
				else
					self:PlaySFX("GroundM5", targetRoot)
				end
			end
		end)
	end)

	task.delay(data.Cooldown or 0.3, function()
		if npc and npc.Parent then
			npc:SetAttribute("NPCAttacking", false)

			if combo == finalM1 then
				self:ResetCombo(npc)
			end
		end
	end)
end

return NPCM1
