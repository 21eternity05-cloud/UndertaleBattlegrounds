local GrabService = {}
GrabService.__index = GrabService

function GrabService.new(config, stateService, movementService, combatStatusService, damageNumberService, progressionService)
	local self = setmetatable({}, GrabService)

	self.Config = config
	self.StateService = stateService
	self.MovementService = movementService
	self.CombatStatusService = combatStatusService
	self.DamageNumberService = damageNumberService
	self.ProgressionService = progressionService

	return self
end

function GrabService:CaptureHumanoidState(humanoid)
	if not humanoid then
		return nil
	end

	return {
		WalkSpeed = humanoid.WalkSpeed,
		JumpPower = humanoid.JumpPower,
		JumpHeight = humanoid.JumpHeight,
		AutoRotate = humanoid.AutoRotate,
		JumpEnabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping),
	}
end

function GrabService:LockCharacter(character, options)
	if not character or not character.Parent then
		return nil
	end

	options = options or {}

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or humanoid.Health <= 0 then
		return nil
	end

	local oldState = self:CaptureHumanoidState(humanoid)

	character:SetAttribute("Grabbed", true)
	character:SetAttribute("CinematicLocked", true)
	character:SetAttribute("Stunned", true)
	character:SetAttribute("Blocking", false)
	character:SetAttribute("Attacking", false)
	character:SetAttribute("UsingMove", true)
	character:SetAttribute("MovementLocked", true)
	character:SetAttribute("DashLocked", true)

	if options.LockJump ~= false then
		character:SetAttribute("JumpLockedUntil", os.clock() + (options.Duration or 3))
	end

	if self.CombatStatusService and options.AttackerCharacter then
		self.CombatStatusService:SetDamageLock(character, options.AttackerCharacter, options.Duration or 3)
	end

	if options.ClearCombatMovement ~= false and self.MovementService and self.MovementService.ClearCombatMovementControllers and root then
		self.MovementService:ClearCombatMovementControllers(root)
	end

	if options.CancelCurrentMove ~= false then
		local moveToken = (character:GetAttribute("MoveToken") or 0) + 1
		character:SetAttribute("MoveToken", moveToken)
	end

	humanoid.WalkSpeed = 0
	humanoid.Jump = false
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoRotate = options.AutoRotate == true
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	if self.StateService and self.StateService.StunCharacter then
		self.StateService:StunCharacter(character, options.Duration or 3)
	end

	if self.CombatStatusService and self.CombatStatusService.SetTemporaryCombatStatus then
		self.CombatStatusService:SetTemporaryCombatStatus(character, {
			IFrameActive = options.IFrameActive == true,
			ArmorActive = options.ArmorActive == true,
			ArmorDamageReduction = options.ArmorDamageReduction or 1,
			ArmorPreventsStun = true,
			ArmorPreventsKnockback = true,
			ArmorPreventsHitCancel = true,
		})
	end

	return {
		Character = character,
		Humanoid = humanoid,
		Root = root,
		OldState = oldState,
		AttackerCharacter = options.AttackerCharacter,
	}
end

function GrabService:UnlockCharacter(lockState)
	if not lockState then
		return
	end

	local character = lockState.Character
	local humanoid = lockState.Humanoid
	local oldState = lockState.OldState

	if character and character.Parent then
		if self.CombatStatusService then
			self.CombatStatusService:ClearDamageLock(character, lockState.AttackerCharacter)
		end

		character:SetAttribute("Grabbed", false)
		character:SetAttribute("CinematicLocked", false)
		character:SetAttribute("Stunned", false)
		character:SetAttribute("UsingMove", false)
		character:SetAttribute("MovementLocked", false)
		character:SetAttribute("DashLocked", false)

		if self.CombatStatusService and self.CombatStatusService.ClearTemporaryCombatStatus then
			self.CombatStatusService:ClearTemporaryCombatStatus(character)
		end
	end

	if humanoid and humanoid.Parent and humanoid.Health > 0 and oldState then
		humanoid.WalkSpeed = oldState.WalkSpeed or self.Config.DefaultWalkSpeed or 16
		humanoid.JumpPower = oldState.JumpPower or self.Config.DefaultJumpPower or 50
		humanoid.JumpHeight = oldState.JumpHeight or self.Config.DefaultJumpHeight or 7.2
		humanoid.AutoRotate = oldState.AutoRotate ~= false
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, oldState.JumpEnabled ~= false)
	end
end

function GrabService:ShowDamageNumber(targetRoot, damage, options)
	if not self.DamageNumberService then
		return
	end

	if not targetRoot or not targetRoot.Parent then
		return
	end

	if typeof(damage) ~= "number" or damage <= 0 then
		return
	end

	self.DamageNumberService:ShowDamage(targetRoot, damage, options)
end

function GrabService:ReportNoUltDamage(attackerCharacter, targetCharacter, targetRoot, damage)
	if not attackerCharacter or not targetCharacter then
		return
	end

	if typeof(damage) ~= "number" or damage <= 0 then
		return
	end

	self:ShowDamageNumber(targetRoot, damage, {
		TextSize = 56,
	})

	local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")

	if humanoid and humanoid.Health <= 0 then
		if self.ProgressionService and self.ProgressionService.AwardKill then
			self.ProgressionService:AwardKill(attackerCharacter, targetCharacter)
		end
	end
end

return GrabService
