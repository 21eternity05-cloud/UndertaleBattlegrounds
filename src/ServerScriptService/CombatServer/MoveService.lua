local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MoveService = {}
MoveService.__index = MoveService

local VALID_MOVE_SLOTS = {
	Move1 = true,
	Move2 = true,
	Move3 = true,
	Move4 = true,
	Ultimate = true,
}

function MoveService.new(config, stateService, hitboxService, movementService, blockService, vfxService, counterService, combatStatusService)
	local self = setmetatable({}, MoveService)

	self.Config = config
	self.StateService = stateService
	self.HitboxService = hitboxService
	self.MovementService = movementService
	self.BlockService = blockService
	self.VFXService = vfxService
	self.CounterService = counterService
	self.CombatStatusService = combatStatusService

	self.LoadedMoveModules = {}
	self.Cooldowns = {}

	local assetsFolder = ReplicatedStorage:WaitForChild(config.AssetsFolderName or "Assets")
	self.CharactersFolder = assetsFolder:WaitForChild(config.CharactersFolderName or "Characters")

	return self
end

function MoveService:GetCharacterName(character)
	local characterName = character:GetAttribute("CharacterName")

	if typeof(characterName) == "string" and characterName ~= "" then
		return characterName
	end

	return self.Config.DefaultCharacterName or "Chara"
end

function MoveService:GetMoveModule(characterName)
	if self.LoadedMoveModules[characterName] then
		return self.LoadedMoveModules[characterName]
	end

	local characterFolder = self.CharactersFolder:FindFirstChild(characterName)
	if not characterFolder then
		warn("[MoveService] Missing character folder:", characterName)
		return nil
	end

	local modulesFolder = characterFolder:FindFirstChild("Modules")
	if not modulesFolder then
		warn("[MoveService] Missing Modules folder for:", characterName)
		return nil
	end

	local moduleScript = modulesFolder:FindFirstChild("MoveModule")
	if not moduleScript then
		warn("[MoveService] Missing MoveModule for:", characterName)
		return nil
	end

	local required = require(moduleScript)
	local module

	if typeof(required) == "table" and required.new then
		module = required.new(self.Config)
	else
		module = required
	end

	self.LoadedMoveModules[characterName] = module
	return module
end

function MoveService:GetMoveFromSlot(moveModule, moveSlot)
	if not moveModule then return nil, nil end
	if not moveModule.Slots then return nil, nil end
	if not moveModule.Moves then return nil, nil end

	local moveId = moveModule.Slots[moveSlot]
	if not moveId then return nil, nil end

	local moveData = moveModule.Moves[moveId]
	if not moveData then return nil, nil end

	return moveId, moveData
end

function MoveService:IsOnCooldown(player, moveId)
	local userId = player.UserId
	self.Cooldowns[userId] = self.Cooldowns[userId] or {}

	local readyTime = self.Cooldowns[userId][moveId] or 0
	return os.clock() < readyTime
end

function MoveService:SetCooldown(player, moveId, cooldown)
	local userId = player.UserId
	self.Cooldowns[userId] = self.Cooldowns[userId] or {}
	self.Cooldowns[userId][moveId] = os.clock() + (cooldown or 1)
end

function MoveService:CanUseMove(player, character, humanoid, moveSlot, moveId)
	if not VALID_MOVE_SLOTS[moveSlot] then return false end
	if not character then return false end
	if not humanoid or humanoid.Health <= 0 then return false end

	if character:GetAttribute("UsingMove") then return false end
	if character:GetAttribute("Stunned") then return false end
	if character:GetAttribute("Blocking") then return false end
	if character:GetAttribute("Guardbroken") then return false end

	if self:IsOnCooldown(player, moveId) then
		return false
	end

	return true
end

function MoveService:CancelM1IntoMove(character)
	if not character or not character.Parent then return end

	character:SetAttribute("Attacking", false)
	character:SetAttribute("ComboCount", 0)
	character:SetAttribute("LastM1Time", 0)
	character:SetAttribute("AirComboReady", false)
	character:SetAttribute("UsedUptiltInCombo", false)

	if self.StateService.AnimationService then
		self.StateService.AnimationService:StopCharacterAnimationByName(character, "M1", 0.04)
		self.StateService.AnimationService:StopCharacterAnimationByName(character, "M2", 0.04)
		self.StateService.AnimationService:StopCharacterAnimationByName(character, "M3", 0.04)
		self.StateService.AnimationService:StopCharacterAnimationByName(character, "M4", 0.04)
		self.StateService.AnimationService:StopCharacterAnimationByName(character, "M5", 0.04)
		self.StateService.AnimationService:StopCharacterAnimationByName(character, "Uptilt", 0.04)
		self.StateService.AnimationService:StopCharacterAnimationByName(character, "Downslam", 0.04)
	end
end

function MoveService:PlayMoveAnimation(character, moveData)
	if not self.StateService.AnimationService then return nil end
	if not moveData.AnimationName then return nil end

	return self.StateService.AnimationService:PlayCharacterAnimation(
		character,
		moveData.AnimationName,
		moveData.FadeTime or 0.05,
		1,
		moveData.AnimationSpeed or 1,
		true
	)
end

function MoveService:RestoreMoveMovement(character)
	if not character or not character.Parent then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	if character:GetAttribute("Stunned") then return end
	if character:GetAttribute("Guardbroken") then return end
	if character:GetAttribute("Blocking") then return end
	if character:GetAttribute("UsingMove") then return end

	humanoid.WalkSpeed = self.Config.DefaultWalkSpeed
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	humanoid.JumpPower = self.Config.DefaultJumpPower
	humanoid.JumpHeight = self.Config.DefaultJumpHeight
end

function MoveService:EndMove(character, moveToken)
	if not character or not character.Parent then return end
	if character:GetAttribute("MoveToken") ~= moveToken then return end

	character:SetAttribute("UsingMove", false)

	if self.CombatStatusService then
		self.CombatStatusService:EndMove(character, moveToken)
	end

	self:RestoreMoveMovement(character)
end

function MoveService:BuildAttackData(baseData, extraData)
	local data = {}

	for key, value in pairs(baseData or {}) do
		data[key] = value
	end

	for key, value in pairs(extraData or {}) do
		data[key] = value
	end

	if self.CombatStatusService and self.CombatStatusService.NormalizeAttackData then
		return self.CombatStatusService:NormalizeAttackData(data)
	end

	if data.Blockable == nil then
		data.Blockable = true
	end

	if data.CanBeBlocked == nil then
		data.CanBeBlocked = data.Blockable ~= false
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

	if data.PlayMoveHitVFX == nil then
		data.PlayMoveHitVFX = true
	end

	return data
end

function MoveService:ApplyStandardHit(attackerCharacter, attackerRoot, targetCharacter, targetHumanoid, targetRoot, attackData, attackName)
	local data = self:BuildAttackData(attackData)

	if not attackerCharacter or not attackerCharacter.Parent then return "Invalid" end
	if not attackerRoot or not attackerRoot.Parent then return "Invalid" end
	if not targetCharacter or not targetCharacter.Parent then return "Invalid" end
	if not targetHumanoid or targetHumanoid.Health <= 0 then return "Invalid" end
	if not targetRoot or not targetRoot.Parent then return "Invalid" end

	local status = self.CombatStatusService

	if status and status:HasIFrames(targetCharacter, data) then
		print("[MoveService] Hit ignored by iframe:", targetCharacter.Name, attackName or "Attack")
		return "IFrame"
	end

	if status and status:CanAttackBeCountered(data) then
		if self.CounterService and self.CounterService.TryCounterHit then
			local countered = self.CounterService:TryCounterHit({
				AttackerCharacter = attackerCharacter,
				TargetCharacter = targetCharacter,
				AttackName = attackName or "Move",
				AttackData = data,
				HitPosition = targetRoot.Position,
			})

			if countered then
				return "Countered"
			end
		end
	end

	local canBlock = true

	if status then
		canBlock = status:CanAttackBeBlocked(data)
	else
		canBlock = data.Blockable ~= false
			and data.CanBeBlocked ~= false
			and data.Unblockable ~= true
	end

	if canBlock and self.BlockService:CanBlockHit(targetCharacter, attackerRoot) then
		if data.Guardbreak == true then
			self.StateService:GuardbreakCharacter(targetCharacter, data.GuardbreakStun or 1.25)
			self.BlockService:PlayBlockBreakVFX(targetRoot)

			if self.UltService then
				self.UltService:AwardGuardbreak(attackerCharacter, targetCharacter)
			end

			return "Guardbreak"
		end

		self.BlockService:PlayBlockVFX(targetRoot)
		return "Blocked"
	end

	local armorInfo

	if status then
		armorInfo = status:GetArmorInfo(targetCharacter, data)
	else
		armorInfo = {
			Active = false,
			DamageReduction = 0,
			PreventsStun = false,
			PreventsKnockback = false,
			PreventsHitCancel = false,
		}
	end

	if status then
		status:TryHitCancelTarget(targetCharacter, data)
	end

	local rawDamage = data.Damage or 5
	local finalDamage = rawDamage

	if armorInfo.Active then
		finalDamage = rawDamage * (1 - (armorInfo.DamageReduction or 0))
	end

	if finalDamage > 0 then
		targetHumanoid:TakeDamage(finalDamage)

		if self.DamageNumberService then
			self.DamageNumberService:ShowDamage(targetRoot, finalDamage)
		end

		if self.UltService and data.AwardsUlt ~= false then
			self.UltService:AwardDamageEvent(attackerCharacter, targetCharacter, finalDamage)
		end
	end

	if data.Stun and data.Stun > 0 then
		if not armorInfo.Active or not armorInfo.PreventsStun then
			self.StateService:StunCharacter(targetCharacter, data.Stun)
		else
			print("[MoveService] Armor prevented stun:", targetCharacter.Name)
		end
	end

	if self.VFXService then
		self.VFXService:EmitHitVFXOnVictim(targetRoot, attackerCharacter)

		if data.PlayMoveHitVFX ~= false and self.VFXService.PlayCharacterMoveVFX then
			self.VFXService:PlayCharacterMoveVFX(attackerCharacter, attackName, targetCharacter, targetRoot)
		end
	end

	if data.Knockback and data.Knockback > 0 then
		if not armorInfo.Active or not armorInfo.PreventsKnockback then
			if self.MovementService and self.MovementService.ApplyDirectionalKnockback then
				self.MovementService:ApplyDirectionalKnockback(attackerRoot, targetRoot, data)
			else
				local direction = self.MovementService:GetDirectionBetween(attackerRoot, targetRoot)

				targetRoot.AssemblyLinearVelocity =
					(direction * data.Knockback)
					+ Vector3.new(0, data.UpwardKnockback or 0, 0)
			end
		else
			print("[MoveService] Armor prevented knockback:", targetCharacter.Name)
		end
	end

	if armorInfo.Active then
		return "ArmoredHit"
	end

	return "Hit"
end

function MoveService:BuildContext(player, character, humanoid, root, characterName, moveSlot, moveId, moveData, moveToken, payload)
	local finished = false
	local moveService = self

	local targetCharacter = payload and payload.TargetCharacter
	local targetHumanoid = nil
	local targetRoot = nil

	if targetCharacter and targetCharacter:IsA("Model") then
		targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
		targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")
	end

	local context = {
		Player = player,
		Character = character,
		Humanoid = humanoid,
		Root = root,

		TargetCharacter = targetCharacter,
		TargetHumanoid = targetHumanoid,
		TargetRoot = targetRoot,

		Config = self.Config,
		StateService = self.StateService,
		HitboxService = self.HitboxService,
		MovementService = self.MovementService,
		BlockService = self.BlockService,
		VFXService = self.VFXService,
		CounterService = self.CounterService,
		CombatStatusService = self.CombatStatusService,
		ProjectileService = self.ProjectileService,
		UltService = self.UltService,
		CinematicService = self.CinematicService,

		CharacterName = characterName,
		MoveSlot = moveSlot,
		MoveId = moveId,
		MoveData = moveData,
		MoveToken = moveToken,

		Payload = payload,
	}

	function context:IsActive()
		if finished then return false end
		if not character or not character.Parent then return false end
		if not humanoid or humanoid.Health <= 0 then return false end
		if character:GetAttribute("MoveToken") ~= moveToken then return false end
		if not character:GetAttribute("UsingMove") then return false end

		return true
	end

	function context:GetValidTarget()
		if not targetCharacter or not targetCharacter.Parent then
			return nil
		end

		local currentHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
		local currentRoot = targetCharacter:FindFirstChild("HumanoidRootPart")

		if not currentHumanoid or not currentRoot or currentHumanoid.Health <= 0 then
			return nil
		end

		if targetCharacter == character then
			return nil
		end

		return targetCharacter, currentHumanoid, currentRoot
	end

	function context:FinishMove(delayTime)
		if finished then return end
		finished = true

		task.delay(delayTime or 0, function()
			moveService:EndMove(character, moveToken)
		end)
	end

	function context:DefaultApplyHit(targetCharacter2, targetHumanoid2, targetRoot2)
		return moveService:ApplyStandardHit(
			character,
			root,
			targetCharacter2,
			targetHumanoid2,
			targetRoot2,
			moveData,
			moveId
		)
	end

	function context:ApplyStandardHit(targetCharacter2, targetHumanoid2, targetRoot2, customAttackData, customAttackName)
		return moveService:ApplyStandardHit(
			character,
			root,
			targetCharacter2,
			targetHumanoid2,
			targetRoot2,
			customAttackData or moveData,
			customAttackName or moveId
		)
	end

	return context
end

function MoveService:PerformDefaultMove(context)
	local character = context.Character
	local root = context.Root
	local moveData = context.MoveData
	local attackData = self:BuildAttackData(moveData)

	task.delay(moveData.HitDelay or 0.1, function()
		if not context:IsActive() then return end

		self.HitboxService:PerformSphereHitbox(character, root, moveData, function(targetCharacter, targetHumanoid, targetRoot)
			context:ApplyStandardHit(targetCharacter, targetHumanoid, targetRoot, attackData, context.MoveId)
		end)
	end)

	context:FinishMove(moveData.LockTime or moveData.Duration or 0.5)
end

function MoveService:PerformMove(player, moveRequest)
	local moveSlot = moveRequest
	local payload = nil

	if typeof(moveRequest) == "table" then
		moveSlot = moveRequest.MoveSlot
		payload = moveRequest
	end

	if typeof(moveSlot) ~= "string" then return end
	if not VALID_MOVE_SLOTS[moveSlot] then return end

	local character, humanoid, root = self.StateService:GetCharacterInfo(player)
	if not character then return end

	local characterName = self:GetCharacterName(character)
	local moveModule = self:GetMoveModule(characterName)
	local moveId, moveData = self:GetMoveFromSlot(moveModule, moveSlot)

	if not moveId or not moveData then
		warn("[MoveService] Missing move for slot:", characterName, moveSlot)
		return
	end
	
	if moveSlot == "Ultimate" then
		if not self.UltService or not self.UltService:CanUseUltimate(player) then
			warn("[MoveService] Ultimate is not ready")
			return
		end
	end

	if moveData.RequiresTarget then
		local targetCharacter = payload and payload.TargetCharacter
		local validTarget = false

		if targetCharacter and targetCharacter:IsA("Model") and targetCharacter ~= character then
			local targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
			local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")

			if targetHumanoid and targetRoot and targetHumanoid.Health > 0 then
				validTarget = true
			end
		end

		if not validTarget then
			warn("[MoveService] Move requires valid target:", moveId)
			return
		end
	end

	if moveData.RequiresAim then
		local aimPosition = payload and payload.AimPosition

		if typeof(aimPosition) ~= "Vector3" then
			warn("[MoveService] Move requires valid aim position:", moveId)
			return
		end
	end

	if not self:CanUseMove(player, character, humanoid, moveSlot, moveId) then
		return
	end
	
	if moveSlot == "Ultimate" then
		self.UltService:SpendUlt(player)
	end

	self:SetCooldown(player, moveId, moveData.Cooldown or 1)

	local moveToken = (character:GetAttribute("MoveToken") or 0) + 1
	character:SetAttribute("MoveToken", moveToken)

	self:CancelM1IntoMove(character)

	character:SetAttribute("UsingMove", true)

	if self.CombatStatusService then
		self.CombatStatusService:BeginMove(character, moveData, moveToken, moveId)
	end

	self.StateService:LockJump(character, moveData.MaxLockTime or moveData.LockTime or moveData.Duration or 0.5)

	self:PlayMoveAnimation(character, moveData)

	if self.VFXService and self.VFXService.PlayCharacterMoveVFX then
		self.VFXService:PlayCharacterMoveVFX(character, moveId)
	end

	print(player.Name .. " used " .. (moveData.DisplayName or moveId))

	local context = self:BuildContext(
		player,
		character,
		humanoid,
		root,
		characterName,
		moveSlot,
		moveId,
		moveData,
		moveToken,
		payload
	)

	if moveData.Execute then
		task.spawn(function()
			local success, err = pcall(function()
				moveData.Execute(context)
			end)

			if not success then
				warn("[MoveService] Move error:", err)

				if context:IsActive() then
					context:FinishMove(0)
				end
			end
		end)
	else
		self:PerformDefaultMove(context)
	end
end

function MoveService:ReportDamageEvent(attackerCharacter, targetCharacter, damageAmount)
	if not attackerCharacter or not targetCharacter then
		return
	end

	if not damageAmount or damageAmount <= 0 then
		return
	end

	if self.UltService and self.UltService.AwardDamageEvent then
		self.UltService:AwardDamageEvent(attackerCharacter, targetCharacter, damageAmount)
		return
	end

	if self.ProgressionService and self.ProgressionService.AwardKill then
		local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")

		if humanoid and humanoid.Health <= 0 then
			self.ProgressionService:AwardKill(attackerCharacter, targetCharacter)
		end
	end
end

return MoveService
