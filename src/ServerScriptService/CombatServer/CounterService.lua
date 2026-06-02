local CounterService = {}
CounterService.__index = CounterService

function CounterService.new(config, stateService, movementService, vfxService)
	local self = setmetatable({}, CounterService)

	self.Config = config
	self.StateService = stateService
	self.MovementService = movementService
	self.VFXService = vfxService

	return self
end

function CounterService:GetOrCreateCounterAttackerValue(character)
	if not character or not character.Parent then return nil end

	local value = character:FindFirstChild("CounterAttacker")

	if not value then
		value = Instance.new("ObjectValue")
		value.Name = "CounterAttacker"
		value.Parent = character
	end

	return value
end

function CounterService:ClearCounterState(character)
	if not character or not character.Parent then return end

	character:SetAttribute("Countering", false)
	character:SetAttribute("CounterTriggered", false)
	character:SetAttribute("CounterMoveId", nil)
	character:SetAttribute("CounterAttackName", nil)

	local value = character:FindFirstChild("CounterAttacker")
	if value and value:IsA("ObjectValue") then
		value.Value = nil
	end
end

function CounterService:IsCounterActive(character)
	if not character or not character.Parent then return false end
	if character:GetAttribute("Countering") == true then return true end
	if character:GetAttribute("CounterTriggered") == true then return true end

	return false
end

function CounterService:TryCounterHit(info)
	if typeof(info) ~= "table" then return false end

	local attackerCharacter = info.AttackerCharacter
	local targetCharacter = info.TargetCharacter
	local attackName = info.AttackName or "UnknownAttack"

	if not targetCharacter or not targetCharacter.Parent then return false end
	if not attackerCharacter or not attackerCharacter.Parent then return false end
	if attackerCharacter == targetCharacter then return false end

	local targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
	if not targetHumanoid or targetHumanoid.Health <= 0 then return false end

	-- Do not require attacker humanoid.
	-- NPCs/dummies/projectile owners may not always pass through like normal players.
	local attackerHumanoid = attackerCharacter:FindFirstChildOfClass("Humanoid")
	if attackerHumanoid and attackerHumanoid.Health <= 0 then
		return false
	end

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
	targetCharacter:SetAttribute("CounterAttackName", attackName)
	
	if self.UltService then
		self.UltService:AwardCounter(targetCharacter, attackerCharacter)
	end

	if self.MovementService then
		local attackerRoot = attackerCharacter:FindFirstChild("HumanoidRootPart")
		local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")

		if attackerRoot then
			self.MovementService:StopCarryController(attackerRoot)
			self.MovementService:StopYHoldController(attackerRoot)
			attackerRoot.AssemblyLinearVelocity = Vector3.zero
			attackerRoot.AssemblyAngularVelocity = Vector3.zero
		end

		if targetRoot then
			self.MovementService:StopCarryController(targetRoot)
			self.MovementService:StopYHoldController(targetRoot)
			targetRoot.AssemblyLinearVelocity = Vector3.zero
			targetRoot.AssemblyAngularVelocity = Vector3.zero
		end
	end

	if info.OnCountered then
		task.spawn(function()
			info.OnCountered()
		end)
	end

	print(
		"[CounterService] Counter triggered:",
		targetCharacter.Name,
		"countered",
		attackerCharacter.Name,
		"attack:",
		attackName,
		"stored attacker:",
		attackerValue and attackerValue.Value and attackerValue.Value.Name or "nil"
	)

	return true
end

return CounterService