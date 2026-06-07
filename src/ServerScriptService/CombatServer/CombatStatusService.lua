local CombatStatusService = {}
CombatStatusService.__index = CombatStatusService

function CombatStatusService.new(config)
	local self = setmetatable({}, CombatStatusService)

	self.Config = config

	return self
end

function CombatStatusService:GetNow()
	return os.clock()
end

function CombatStatusService:IsAliveCharacter(character)
	if not character or not character.Parent then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	return true
end

function CombatStatusService:GetBool(data, key, defaultValue)
	if data and data[key] ~= nil then
		return data[key] == true
	end

	return defaultValue == true
end

function CombatStatusService:GetNumber(data, key, defaultValue)
	if data and typeof(data[key]) == "number" then
		return data[key]
	end

	return defaultValue
end

function CombatStatusService:NormalizeAttackData(attackData)
	local normalized = {}

	for key, value in pairs(attackData or {}) do
		normalized[key] = value
	end

	-- Default rule:
	-- Almost every attack is blockable unless it explicitly says otherwise.
	if normalized.Blockable == nil then
		normalized.Blockable = true
	end

	if normalized.CanBeBlocked == nil then
		normalized.CanBeBlocked = normalized.Blockable ~= false
	end

	if normalized.Unblockable == nil then
		normalized.Unblockable = false
	end

	-- Default rule:
	-- Almost every attack can be countered unless it explicitly says otherwise.
	if normalized.CanBeCountered == nil then
		normalized.CanBeCountered = true
	end

	-- Default rule:
	-- A successful attack cancels the target's current move unless disabled.
	if normalized.HitCancelsTarget == nil then
		normalized.HitCancelsTarget = true
	end

	-- Default rule:
	-- The attacker's move can be hit-canceled unless disabled.
	if normalized.CancelableByHit == nil then
		normalized.CancelableByHit = true
	end

	if normalized.IgnoresIFrames == nil then
		normalized.IgnoresIFrames = false
	end

	if normalized.IgnoresArmor == nil then
		normalized.IgnoresArmor = false
	end

	if normalized.PlayMoveHitVFX == nil then
		normalized.PlayMoveHitVFX = true
	end

	return normalized
end

function CombatStatusService:NormalizeMoveData(moveData)
	return self:NormalizeAttackData(moveData)
end

function CombatStatusService:IsAttackUnblockable(attackData)
	local data = self:NormalizeAttackData(attackData)

	if data.Unblockable == true then
		return true
	end

	if data.CanBeBlocked == false then
		return true
	end

	if data.Blockable == false then
		return true
	end

	return false
end

function CombatStatusService:CanAttackBeBlocked(attackData)
	return not self:IsAttackUnblockable(attackData)
end

function CombatStatusService:CanAttackBeCountered(attackData)
	local data = self:NormalizeAttackData(attackData)

	return data.CanBeCountered ~= false
end

function CombatStatusService:CanAttackHitCancel(attackData)
	local data = self:NormalizeAttackData(attackData)

	return data.HitCancelsTarget ~= false
end

function CombatStatusService:CanAttackContinue(character, moveData)
	if not character or not character.Parent then
		return false
	end

	if character:GetAttribute("Guardbroken") then
		return false
	end

	if not character:GetAttribute("Stunned") then
		return true
	end

	if character:GetAttribute("IFrameActive") == true then
		return true
	end
	if character:GetAttribute("ArmorActive") == true then
		return true
	end

	local data = self:NormalizeAttackData(moveData)

	if data.CancelableByHit == false then
		return true
	end
	if data.ArmorPreventsHitCancel == true then
		return true
	end

	return false
end

function CombatStatusService:ClearCombatWindows(character)
	if not character or not character.Parent then return end

	character:SetAttribute("IFrameActive", false)
	character:SetAttribute("ArmorActive", false)
	character:SetAttribute("ArmorDamageReduction", 0)
	character:SetAttribute("ArmorPreventsStun", false)
	character:SetAttribute("ArmorPreventsKnockback", false)
	character:SetAttribute("ArmorPreventsHitCancel", false)
end

function CombatStatusService:ClearMoveStatus(character)
	if not character or not character.Parent then return end

	character:SetAttribute("CurrentMoveId", nil)
	character:SetAttribute("MoveCancelableByHit", true)
	character:SetAttribute("MoveHitCancelsTarget", true)

	self:ClearCombatWindows(character)
end

function CombatStatusService:StartTimedBoolWindow(character, moveToken, attributeName, startTime, endTime, onStart, onEnd)
	if not character or not character.Parent then return end
	if not attributeName then return end

	startTime = startTime or 0
	endTime = endTime or 0

	if endTime <= startTime then return end

	task.delay(startTime, function()
		if not character or not character.Parent then return end
		if character:GetAttribute("MoveToken") ~= moveToken then return end
		if not character:GetAttribute("UsingMove") then return end

		character:SetAttribute(attributeName, true)

		if onStart then
			onStart()
		end
	end)

	task.delay(endTime, function()
		if not character or not character.Parent then return end
		if character:GetAttribute("MoveToken") ~= moveToken then return end

		character:SetAttribute(attributeName, false)

		if onEnd then
			onEnd()
		end
	end)
end

function CombatStatusService:BeginMove(character, moveData, moveToken, moveId)
	if not character or not character.Parent then return end

	local normalized = self:NormalizeMoveData(moveData)

	character:SetAttribute("CurrentMoveId", moveId)
	character:SetAttribute("MoveCancelableByHit", normalized.CancelableByHit ~= false)
	character:SetAttribute("MoveHitCancelsTarget", normalized.HitCancelsTarget ~= false)

	self:ClearCombatWindows(character)

	if normalized.HasIFrames == true then
		local startTime = normalized.IFrameStart or 0
		local endTime = normalized.IFrameEnd
			or normalized.MaxLockTime
			or normalized.LockTime
			or normalized.Duration
			or 0

		self:StartTimedBoolWindow(character, moveToken, "IFrameActive", startTime, endTime)
	end

	if normalized.HasArmor == true then
		local startTime = normalized.ArmorStart or 0
		local endTime = normalized.ArmorEnd
			or normalized.MaxLockTime
			or normalized.LockTime
			or normalized.Duration
			or 0

		self:StartTimedBoolWindow(
			character,
			moveToken,
			"ArmorActive",
			startTime,
			endTime,
			function()
				character:SetAttribute("ArmorDamageReduction", normalized.ArmorDamageReduction or 0)
				character:SetAttribute("ArmorPreventsStun", normalized.ArmorPreventsStun == true)
				character:SetAttribute("ArmorPreventsKnockback", normalized.ArmorPreventsKnockback == true)
				character:SetAttribute("ArmorPreventsHitCancel", normalized.ArmorPreventsHitCancel == true)
			end,
			function()
				character:SetAttribute("ArmorDamageReduction", 0)
				character:SetAttribute("ArmorPreventsStun", false)
				character:SetAttribute("ArmorPreventsKnockback", false)
				character:SetAttribute("ArmorPreventsHitCancel", false)
			end
		)
	end
end

function CombatStatusService:EndMove(character, moveToken)
	if not character or not character.Parent then return end

	if moveToken ~= nil and character:GetAttribute("MoveToken") ~= moveToken then
		return
	end

	self:ClearMoveStatus(character)
end

function CombatStatusService:HasIFrames(character, attackData)
	if not character or not character.Parent then
		return false
	end

	local data = self:NormalizeAttackData(attackData)

	if data.IgnoresIFrames == true then
		return false
	end

	return character:GetAttribute("IFrameActive") == true
end

function CombatStatusService:GetArmorInfo(character, attackData)
	local defaultInfo = {
		Active = false,
		DamageReduction = 0,
		PreventsStun = false,
		PreventsKnockback = false,
		PreventsHitCancel = false,
	}

	if not character or not character.Parent then
		return defaultInfo
	end

	local data = self:NormalizeAttackData(attackData)

	if data.IgnoresArmor == true then
		return defaultInfo
	end

	local active = character:GetAttribute("ArmorActive") == true

	if not active then
		return defaultInfo
	end

	local damageReduction = character:GetAttribute("ArmorDamageReduction") or 0
	damageReduction = math.clamp(damageReduction, 0, 1)

	return {
		Active = true,
		DamageReduction = damageReduction,
		PreventsStun = character:GetAttribute("ArmorPreventsStun") == true,
		PreventsKnockback = character:GetAttribute("ArmorPreventsKnockback") == true,
		PreventsHitCancel = character:GetAttribute("ArmorPreventsHitCancel") == true,
	}
end

function CombatStatusService:TryHitCancelTarget(targetCharacter, attackData)
	if not targetCharacter or not targetCharacter.Parent then
		return false
	end

	local data = self:NormalizeAttackData(attackData)

	if data.HitCancelsTarget == false then
		return false
	end

	if not targetCharacter:GetAttribute("UsingMove") then
		return false
	end

	if targetCharacter:GetAttribute("MoveCancelableByHit") == false then
		return false
	end

	local armorInfo = self:GetArmorInfo(targetCharacter, data)

	if armorInfo.Active and armorInfo.PreventsHitCancel then
		return false
	end

	local currentToken = targetCharacter:GetAttribute("MoveToken") or 0

	targetCharacter:SetAttribute("MoveToken", currentToken + 1)
	targetCharacter:SetAttribute("UsingMove", false)
	targetCharacter:SetAttribute("Attacking", false)

	self:ClearMoveStatus(targetCharacter)

	print("[CombatStatusService] Hit-canceled move on:", targetCharacter.Name)

	return true
end

function CombatStatusService:GetOrCreateDamageOwnerValue(character)
	if not character then
		return nil
	end

	local value = character:FindFirstChild("DamageOwner")

	if not value then
		value = Instance.new("ObjectValue")
		value.Name = "DamageOwner"
		value.Parent = character
	end

	return value
end

function CombatStatusService:SetDamageLock(targetCharacter, attackerCharacter, duration)
	if not targetCharacter or not targetCharacter.Parent then
		return nil
	end

	if not attackerCharacter or not attackerCharacter.Parent then
		return nil
	end

	duration = duration or 3

	local ownerValue = self:GetOrCreateDamageOwnerValue(targetCharacter)

	if ownerValue then
		ownerValue.Value = attackerCharacter
	end

	targetCharacter:SetAttribute("DamageLocked", true)
	targetCharacter:SetAttribute("DamageLockExpiresAt", os.clock() + duration)

	return ownerValue
end

function CombatStatusService:ClearDamageLock(targetCharacter, attackerCharacter)
	if not targetCharacter or not targetCharacter.Parent then
		return
	end

	local ownerValue = targetCharacter:FindFirstChild("DamageOwner")

	if attackerCharacter and ownerValue and ownerValue.Value ~= attackerCharacter then
		return
	end

	if ownerValue then
		ownerValue.Value = nil
	end

	targetCharacter:SetAttribute("DamageLocked", false)
	targetCharacter:SetAttribute("DamageLockExpiresAt", 0)
end

function CombatStatusService:TagCombat(character, duration)
	if not character or not character.Parent then
		return
	end

	duration = duration or self.Config.CombatTagDuration or 8
	local taggedUntil = os.clock() + duration
	local currentUntil = character:GetAttribute("CombatTaggedUntil") or 0

	if taggedUntil > currentUntil then
		character:SetAttribute("CombatTaggedUntil", taggedUntil)
	end
end

function CombatStatusService:TagCombatPair(attackerCharacter, targetCharacter, duration)
	self:TagCombat(attackerCharacter, duration)
	self:TagCombat(targetCharacter, duration)
end

function CombatStatusService:IsInCombat(character)
	if not character or not character.Parent then
		return false
	end

	if os.clock() < (character:GetAttribute("CombatTaggedUntil") or 0) then
		return true
	end

	for _, attributeName in ipairs({
		"Stunned",
		"Guardbroken",
		"Blocking",
		"Attacking",
		"UsingMove",
		"Grabbed",
		"GrabLocked",
		"CinematicLocked",
		"DamageLocked",
		"ReservedVictim",
	}) do
		if character:GetAttribute(attributeName) == true then
			return true
		end
	end

	return false
end

function CombatStatusService:IsDamageLockedFromAttacker(targetCharacter, attackerCharacter)
	if not targetCharacter or not targetCharacter.Parent then
		return false
	end

	if targetCharacter:GetAttribute("DamageLocked") ~= true then
		return false
	end

	local expiresAt = targetCharacter:GetAttribute("DamageLockExpiresAt") or 0

	if expiresAt > 0 and os.clock() > expiresAt then
		self:ClearDamageLock(targetCharacter)
		return false
	end

	local ownerValue = targetCharacter:FindFirstChild("DamageOwner")

	if not ownerValue or not ownerValue.Value then
		self:ClearDamageLock(targetCharacter)
		return false
	end

	if ownerValue.Value == attackerCharacter then
		return false
	end

	return true
end

return CombatStatusService
