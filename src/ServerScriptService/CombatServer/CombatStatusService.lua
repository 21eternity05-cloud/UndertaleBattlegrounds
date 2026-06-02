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
	if not character or not character.Parent then return false end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end

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

function CombatStatusService:IsAttackUnblockable(attackData)
	if not attackData then return false end
	if attackData.Unblockable == true then return true end
	if attackData.CanBeBlocked == false then return true end
	if attackData.Blockable == false then return true end

	return false
end

function CombatStatusService:CanAttackBeBlocked(attackData)
	return not self:IsAttackUnblockable(attackData)
end

function CombatStatusService:CanAttackBeCountered(attackData)
	if attackData and attackData.CanBeCountered == false then
		return false
	end

	return true
end

function CombatStatusService:CanAttackHitCancel(attackData)
	if attackData and attackData.HitCancelsTarget == false then
		return false
	end

	return true
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

	if endTime <= startTime then
		return
	end

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

	character:SetAttribute("CurrentMoveId", moveId)
	character:SetAttribute("MoveCancelableByHit", moveData.CancelableByHit ~= false)
	character:SetAttribute("MoveHitCancelsTarget", moveData.HitCancelsTarget ~= false)

	self:ClearCombatWindows(character)

	if moveData.HasIFrames == true then
		local startTime = moveData.IFrameStart or 0
		local endTime = moveData.IFrameEnd or moveData.MaxLockTime or moveData.LockTime or moveData.Duration or 0

		self:StartTimedBoolWindow(character, moveToken, "IFrameActive", startTime, endTime)
	end

	if moveData.HasArmor == true then
		local startTime = moveData.ArmorStart or 0
		local endTime = moveData.ArmorEnd or moveData.MaxLockTime or moveData.LockTime or moveData.Duration or 0

		self:StartTimedBoolWindow(
			character,
			moveToken,
			"ArmorActive",
			startTime,
			endTime,
			function()
				character:SetAttribute("ArmorDamageReduction", moveData.ArmorDamageReduction or 0)
				character:SetAttribute("ArmorPreventsStun", moveData.ArmorPreventsStun ~= false)
				character:SetAttribute("ArmorPreventsKnockback", moveData.ArmorPreventsKnockback ~= false)
				character:SetAttribute("ArmorPreventsHitCancel", moveData.ArmorPreventsHitCancel ~= false)
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
	if not character or not character.Parent then return false end
	if attackData and attackData.IgnoresIFrames == true then return false end

	return character:GetAttribute("IFrameActive") == true
end

function CombatStatusService:GetArmorInfo(character, attackData)
	if not character or not character.Parent then
		return {
			Active = false,
			DamageReduction = 0,
			PreventsStun = false,
			PreventsKnockback = false,
			PreventsHitCancel = false,
		}
	end

	if attackData and attackData.IgnoresArmor == true then
		return {
			Active = false,
			DamageReduction = 0,
			PreventsStun = false,
			PreventsKnockback = false,
			PreventsHitCancel = false,
		}
	end

	local active = character:GetAttribute("ArmorActive") == true

	if not active then
		return {
			Active = false,
			DamageReduction = 0,
			PreventsStun = false,
			PreventsKnockback = false,
			PreventsHitCancel = false,
		}
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
	if not targetCharacter or not targetCharacter.Parent then return false end

	if not self:CanAttackHitCancel(attackData) then
		return false
	end

	if not targetCharacter:GetAttribute("UsingMove") then
		return false
	end

	if targetCharacter:GetAttribute("MoveCancelableByHit") == false then
		return false
	end

	local armorInfo = self:GetArmorInfo(targetCharacter, attackData)

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

return CombatStatusService