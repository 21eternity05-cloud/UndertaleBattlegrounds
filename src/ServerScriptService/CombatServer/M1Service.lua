local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local M1Service = {}
M1Service.__index = M1Service

function M1Service.new(
	config,
	stateService,
	hitboxService,
	movementService,
	blockService,
	vfxService,
	counterService,
	combatStatusService
)
	local self = setmetatable({}, M1Service)

	self.Config = config
	self.StateService = stateService
	self.HitboxService = hitboxService
	self.MovementService = movementService
	self.BlockService = blockService
	self.VFXService = vfxService
	self.CounterService = counterService
	self.CombatStatusService = combatStatusService

	self.M1Data = config.M1Data
	self.FinalM1 = config.FinalM1

	return self
end

function M1Service:GetCharacterName(character)
	local characterName = character:GetAttribute("CharacterName")

	if typeof(characterName) == "string" and characterName ~= "" then
		return characterName
	end

	return self.Config.DefaultCharacterName or "Chara"
end

function M1Service:BuildAttackData(baseData, extraData)
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

function M1Service:GetArmorInfo(targetCharacter, attackData)
	if self.CombatStatusService then
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

function M1Service:CanAttackBeBlocked(attackData)
	if self.CombatStatusService then
		return self.CombatStatusService:CanAttackBeBlocked(attackData)
	end

	if attackData.Unblockable == true then
		return false
	end
	if attackData.CanBeBlocked == false then
		return false
	end
	if attackData.Blockable == false then
		return false
	end

	return true
end

function M1Service:CanAttackBeCountered(attackData)
	if self.CombatStatusService then
		return self.CombatStatusService:CanAttackBeCountered(attackData)
	end

	return attackData.CanBeCountered ~= false
end

function M1Service:TryTriggerCounter(targetCharacter, attackerCharacter, attackName, attackData, onCountered)
	if not self:CanAttackBeCountered(attackData or {}) then
		return false
	end

	if self.CounterService and self.CounterService.TryCounterHit then
		return self.CounterService:TryCounterHit({
			AttackerCharacter = attackerCharacter,
			TargetCharacter = targetCharacter,
			AttackName = attackName or "M1",
			AttackData = attackData,
			OnCountered = onCountered,
		})
	end

	if self.StateService and self.StateService.TryTriggerCounter then
		return self.StateService:TryTriggerCounter(
			targetCharacter,
			attackerCharacter,
			attackName,
			attackData,
			onCountered
		)
	end

	return false
end

function M1Service:TryHitCancelTarget(targetCharacter, attackData)
	if self.CombatStatusService then
		return self.CombatStatusService:TryHitCancelTarget(targetCharacter, attackData)
	end

	return false
end

function M1Service:CanAttackContinue(character, attackData)
	if self.CombatStatusService and self.CombatStatusService.CanAttackContinue then
		return self.CombatStatusService:CanAttackContinue(character, attackData)
	end

	if not character or not character.Parent then
		return false
	end
	if character:GetAttribute("Guardbroken") then
		return false
	end
	if character:GetAttribute("Stunned")
		and character:GetAttribute("IFrameActive") ~= true
		and character:GetAttribute("ArmorActive") ~= true
		and not (attackData and attackData.CancelableByHit == false)
		and not (attackData and attackData.ArmorPreventsHitCancel == true)
	then
		return false
	end

	return true
end

function M1Service:CheckStandardHitStart(
	attackerCharacter,
	attackerRoot,
	targetCharacter,
	targetHumanoid,
	targetRoot,
	attackData,
	attackName,
	options
)
	options = options or {}

	if not attackerCharacter or not attackerCharacter.Parent then
		return "Invalid"
	end
	if not attackerRoot or not attackerRoot.Parent then
		return "Invalid"
	end
	if not targetCharacter or not targetCharacter.Parent then
		return "Invalid"
	end
	if not targetHumanoid or targetHumanoid.Health <= 0 then
		return "Invalid"
	end
	if not targetRoot or not targetRoot.Parent then
		return "Invalid"
	end

	if self.CombatStatusService
		and self.CombatStatusService:IsDamageLockedFromAttacker(targetCharacter, attackerCharacter)
	then
		print("[M1Service] Hit ignored by damage lock:", targetCharacter.Name, attackName or "M1")
		return "DamageLocked"
	end

	if self.CombatStatusService and self.CombatStatusService:HasIFrames(targetCharacter, attackData) then
		print("[M1Service] Hit ignored by iframe:", targetCharacter.Name, attackName or "M1")
		return "IFrame"
	end

	if self:TryTriggerCounter(targetCharacter, attackerCharacter, attackName, attackData, options.OnCountered) then
		return "Countered"
	end

	if options.RespectM1Immunity and self.StateService:IsM1Immune(targetCharacter) then
		print("[M1Service] Target is briefly M1 immune:", targetCharacter.Name)
		return "M1Immune"
	end

	local canBlock = self:CanAttackBeBlocked(attackData)

	if canBlock and options.BlockMode == "Normal" then
		if self.BlockService:CanBlockHit(targetCharacter, attackerRoot, attackData) then
			self.BlockService:PlayBlockVFX(targetRoot)
			return "Blocked"
		end
	elseif canBlock and options.BlockMode == "GuardbreakBlocking" then
		if targetCharacter:GetAttribute("Blocking") then
			self.StateService:GuardbreakCharacter(targetCharacter, attackData.GuardbreakStun or 1.4)
			self.StateService:ApplyM1Immunity(targetCharacter, self.Config.PostM5M1Immunity or 1)
			self.BlockService:PlayBlockBreakVFX(targetRoot)
			return "Guardbreak"
		end
	end

	return "CanHit"
end

function M1Service:ApplyDamageAndStun(
	attackerCharacter,
	targetCharacter,
	targetHumanoid,
	targetRoot,
	attackData,
	stunDuration,
	stunAnimationKey
)
	local armorInfo = self:GetArmorInfo(targetCharacter, attackData)

	self:TryHitCancelTarget(targetCharacter, attackData)

	local rawDamage = attackData.Damage or 0
	local finalDamage = rawDamage

	if armorInfo.Active then
		finalDamage = rawDamage * (1 - (armorInfo.DamageReduction or 0))
	end

	if finalDamage > 0 then
		targetHumanoid:TakeDamage(finalDamage)

		if self.DamageNumberService then
			self.DamageNumberService:ShowDamage(targetRoot, finalDamage)
		end

		if self.UltService and attackData.AwardsUlt ~= false then
			self.UltService:AwardDamageEvent(attackerCharacter, targetCharacter, finalDamage)
		end
	end

	local shouldStun = stunDuration and stunDuration > 0

	if shouldStun then
		if not armorInfo.Active or not armorInfo.PreventsStun then
			self.StateService:StunCharacter(targetCharacter, stunDuration, stunAnimationKey)
		else
			print("[M1Service] Armor prevented stun:", targetCharacter.Name)
		end
	end

	if self.VFXService then
		self.VFXService:EmitHitVFXOnVictim(targetRoot, attackerCharacter)
	end

	return armorInfo
end

function M1Service:PlayCharacterActionSFX(character, root, actionName, fallbackSoundName)
	if not self.VFXService then
		return
	end
	if not self.VFXService.PlayCharacterSFXAtPart then
		return
	end

	local characterName = self:GetCharacterName(character)

	local played = self.VFXService:PlayCharacterSFXAtPart(characterName, actionName, root, 2)

	if not played and fallbackSoundName then
		self.VFXService:PlayCharacterSFXAtPart(characterName, fallbackSoundName, root, 2)
	end
end

function M1Service:PlayM1StartFX(character, root, combo)
	if self.StateService.AnimationService then
		self.StateService.AnimationService:PlayM1Animation(character, combo)
	end

	local soundName = "M" .. tostring(combo)

	if self.VFXService and self.VFXService.PlayCharacterSFXAtPart then
		local characterName = self:GetCharacterName(character)

		local played = self.VFXService:PlayCharacterSFXAtPart(characterName, soundName, root, 2)

		if not played and combo ~= 1 then
			self.VFXService:PlayCharacterSFXAtPart(characterName, "M1", root, 2)
		end
	end
end

function M1Service:PlayM1Visual(character, combo, targetCharacter, targetRoot, didConnect)
	if self.VFXService and self.VFXService.PlayCharacterM1VFX then
		self.VFXService:PlayCharacterM1VFX(character, combo, targetCharacter, targetRoot, didConnect)
	end
end

function M1Service:PlayM1ActionVisual(character, actionName, targetCharacter, targetRoot)
	if self.VFXService and self.VFXService.PlayCharacterMoveVFX then
		self.VFXService:PlayCharacterMoveVFX(character, actionName, targetCharacter, targetRoot)
	end
end

function M1Service:CreateGroundSplatPart(position, data)
	local part = Instance.new("Part")
	part.Name = "GroundSlamSplatPlaceholder"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 0, 0)
	part.Transparency = 0.35
	part.Size = data.SplatPartSize or Vector3.new(8, 0.25, 8)
	part.CFrame = CFrame.new(position)
	part.Parent = workspace

	Debris:AddItem(part, data.SplatPartLifetime or 0.35)
end

function M1Service:GetGroundBelow(root, excludeList)
	if not root or not root.Parent then
		return nil
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excludeList or {}

	return workspace:Raycast(root.Position, Vector3.new(0, -5, 0), params)
end

function M1Service:MonitorDownslamGroundSplat(targetCharacter, targetRoot, data, linearVelocity, attachment)
	if not targetCharacter or not targetCharacter.Parent then
		return
	end
	if not targetRoot or not targetRoot.Parent then
		return
	end

	local startTime = os.clock()
	local maxAirStun = data.AirStunMax or 1.5
	local splatDone = false

	local function cleanupVelocity()
		if linearVelocity then
			linearVelocity:Destroy()
			linearVelocity = nil
		end

		if attachment then
			attachment:Destroy()
			attachment = nil
		end

		if targetRoot and targetRoot.Parent then
			local character = targetRoot:FindFirstAncestorOfClass("Model")
			local player = character and Players:GetPlayerFromCharacter(character)

			if player then
				pcall(function()
					targetRoot:SetNetworkOwner(player)
				end)
			end
		end
	end

	local connection

	connection = RunService.Heartbeat:Connect(function()
		if splatDone then
			connection:Disconnect()
			cleanupVelocity()
			return
		end

		if not targetCharacter.Parent or not targetRoot.Parent then
			connection:Disconnect()
			cleanupVelocity()
			return
		end

		local elapsed = os.clock() - startTime

		if elapsed >= maxAirStun then
			connection:Disconnect()
			cleanupVelocity()
			return
		end

		local groundResult = self:GetGroundBelow(targetRoot, { targetCharacter })

		if groundResult then
			splatDone = true
			connection:Disconnect()
			cleanupVelocity()

			targetRoot.AssemblyLinearVelocity = Vector3.zero

			self:CreateGroundSplatPart(groundResult.Position + Vector3.new(0, 0.08, 0), data)

			self.VFXService:EmitAttachmentAtWorldPosition(
				"GroundSplatCrack",
				groundResult.Position + Vector3.new(0, 0.12, 0),
				1.25,
				true
			)

			self.VFXService:PlaySFXAtPart("GroundSplat", targetRoot, 3)

			self.StateService:StunCharacter(targetCharacter, data.GroundSplatStun or 0.65, "DownslamSplat")
			self.StateService:ApplyM1Immunity(targetCharacter, self.Config.PostM5M1Immunity or 1)

			print("DOWNSLAM GROUND SPLAT")
		end
	end)
end

function M1Service:GetNextCombo(character)
	self.StateService:RefreshComboTimeout(character)

	local combo = character:GetAttribute("ComboCount") or 0
	combo += 1

	if combo > self.FinalM1 then
		combo = 1
	end

	character:SetAttribute("ComboCount", combo)
	character:SetAttribute("LastM1Time", os.clock())

	return combo
end

function M1Service:CanUseUptilt(character)
	self.StateService:RefreshComboTimeout(character)

	if character:GetAttribute("AirComboReady") then
		return false
	end
	if character:GetAttribute("UsedUptiltInCombo") then
		return false
	end

	local currentCombo = character:GetAttribute("ComboCount") or 0

	if currentCombo >= self.FinalM1 - 1 then
		return false
	end

	local cooldownUntil = character:GetAttribute("UptiltCooldownUntil") or 0
	if os.clock() < cooldownUntil then
		return false
	end

	return true
end

function M1Service:DoUptilt(player)
	local character, humanoid, root = self.StateService:GetCharacterInfo(player)
	if not character then
		return
	end
	if not self.StateService:CanAttack(character) then
		return
	end
	if not self:CanUseUptilt(character) then
		return
	end

	local rawData = self.M1Data.Uptilt
	local hasSuccessfulM1 = character:GetAttribute("SuccessfulM1InCombo") == true
	local hitboxData = {}

	for key, value in pairs(rawData) do
		hitboxData[key] = value
	end

	if hasSuccessfulM1 then
		hitboxData.Radius = rawData.ComboRadius or rawData.Radius
		hitboxData.Offset = rawData.ComboOffset or rawData.Offset
	else
		hitboxData.Radius = rawData.RawRadius or rawData.Radius
		hitboxData.Offset = rawData.RawOffset or rawData.Offset
	end

	local attackData = self:BuildAttackData(hitboxData, {
		AttackType = "Uptilt",
		CanBeBlocked = true,
		CanBeCountered = true,
		HitCancelsTarget = true,
	})

	character:SetAttribute("Attacking", true)
	character:SetAttribute("LastM1Time", os.clock())
	character:SetAttribute("UptiltCooldownUntil", os.clock() + rawData.MoveCooldown)

	if self.StateService.AnimationService then
		self.StateService.AnimationService:PlayUptiltAnimation(character)
		self:PlayCharacterActionSFX(character, root, "Uptilt")
	end

	humanoid.Jump = false
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0

	self.StateService:LockJump(character, self.Config.JumpLockAfterM1)

	print(player.Name .. " used UPTILT", hasSuccessfulM1 and "COMBO" or "RAW")

	task.delay(rawData.HitDelay, function()
		if not character.Parent then
			return
		end
		if humanoid.Health <= 0 then
			return
		end
		if character:GetAttribute("UsingMove") then
			return
		end
		if not self:CanAttackContinue(character, attackData) then
			character:SetAttribute("Attacking", false)
			return
		end

		local hitSomething = false

		self.HitboxService:PerformSphereHitbox(
			character,
			root,
			hitboxData,
			function(targetCharacter, targetHumanoid, targetRoot)
				local result = self:CheckStandardHitStart(
					character,
					root,
					targetCharacter,
					targetHumanoid,
					targetRoot,
					attackData,
					"Uptilt",
					{
						RespectM1Immunity = true,
						BlockMode = "Normal",
					}
				)

				if result == "Countered" then
					hitSomething = true
					print("UPTILT COUNTERED")
					return
				end

				if result == "IFrame" or result == "M1Immune" or result == "DamageLocked" or result == "Invalid" then
					return
				end

				if result == "Blocked" then
					hitSomething = true
					print("UPTILT BLOCKED")
					return
				end

				hitSomething = true

				local currentCombo = character:GetAttribute("ComboCount") or 0

				character:SetAttribute("UsedUptiltInCombo", true)
				character:SetAttribute("AirComboReady", true)
				character:SetAttribute("ComboCount", math.clamp(currentCombo + 1, 1, self.FinalM1 - 1))
				character:SetAttribute("LastM1Time", os.clock())

				local armorInfo = self:ApplyDamageAndStun(
					character,
					targetCharacter,
					targetHumanoid,
					targetRoot,
					attackData,
					rawData.Stun
				)

				self:PlayM1ActionVisual(character, "UptiltHit", targetCharacter, targetRoot)

				if not armorInfo.Active or not armorInfo.PreventsKnockback then
					self.MovementService:StartUptiltCarry(root, targetRoot, rawData)
				else
					print("[M1Service] Armor prevented uptilt lift:", targetCharacter.Name)
				end

				task.delay(self.Config.AirComboTime, function()
					if character and character.Parent then
						character:SetAttribute("AirComboReady", false)
					end
				end)

				print("UPTILT HIT - AIR COMBO STARTED")
			end
		)

		if not hitSomething then
			task.delay(self.Config.M1ResetTime, function()
				if character and character.Parent then
					self.StateService:RefreshComboTimeout(character)
				end
			end)
		end
	end)

	task.delay(rawData.Cooldown, function()
		if character and character.Parent then
			character:SetAttribute("Attacking", false)
		end
	end)
end

function M1Service:DoDownslam(player)
	local character, humanoid, root = self.StateService:GetCharacterInfo(player)
	if not character then
		return
	end
	if not self.StateService:CanAttack(character) then
		return
	end

	local rawData = self.M1Data.Downslam
	local attackData = self:BuildAttackData(rawData, {
		AttackType = "Downslam",
		CanBeBlocked = false,
		Unblockable = true,
		CanBeCountered = true,
		HitCancelsTarget = true,
		Damage = rawData.Damage,
		Stun = rawData.AirStunMax or rawData.Stun or 1.5,
	})

	character:SetAttribute("Attacking", true)
	character:SetAttribute("AirComboReady", false)

	print("PLAYING DOWNSLAM ANIMATION")

	if self.StateService.AnimationService then
		self.StateService.AnimationService:PlayDownslamAnimation(character)
		self:PlayCharacterActionSFX(character, root, "Downslam")
	end

	self.StateService:LockJump(character, self.Config.JumpLockAfterM1)

	print(player.Name .. " used AIR M5 DOWNSLAM")

	task.delay(rawData.HitDelay, function()
		if not character.Parent then
			return
		end
		if humanoid.Health <= 0 then
			return
		end
		if character:GetAttribute("UsingMove") then
			return
		end
		if not self:CanAttackContinue(character, attackData) then
			character:SetAttribute("Attacking", false)
			return
		end

		self.HitboxService:PerformSphereHitbox(
			character,
			root,
			rawData,
			function(targetCharacter, targetHumanoid, targetRoot)
				local result = self:CheckStandardHitStart(
					character,
					root,
					targetCharacter,
					targetHumanoid,
					targetRoot,
					attackData,
					"Downslam",
					{
						RespectM1Immunity = false,
						BlockMode = "None",
					}
				)

				if result == "Countered" then
					print("DOWNSLAM COUNTERED")
					return
				end

				if result == "IFrame" or result == "DamageLocked" or result == "Invalid" then
					return
				end

				local armorInfo = self:ApplyDamageAndStun(
					character,
					targetCharacter,
					targetHumanoid,
					targetRoot,
					attackData,
					rawData.AirStunMax or 1.5,
					"DownslamAir"
				)

				self:PlayM1ActionVisual(character, "DownslamHit", targetCharacter, targetRoot)

				self.VFXService:PlaySFXAtPart("DownslamHit", targetRoot, 3)

				if armorInfo.Active and armorInfo.PreventsKnockback then
					print("[M1Service] Armor prevented downslam knockback:", targetCharacter.Name)
					return
				end

				local forward = root.CFrame.LookVector

				self.MovementService:ClearCombatMovementControllers(root)
				self.MovementService:ClearCombatMovementControllers(targetRoot)

				local linearVelocity, attachment =
					self.MovementService:ApplyDownslamKnockback(root, targetRoot, rawData, "Downslam")

				root.AssemblyLinearVelocity = (forward * 12) + Vector3.new(0, -24, 0)

				self:MonitorDownslamGroundSplat(targetCharacter, targetRoot, rawData, linearVelocity, attachment)

				print("AIR M5 DOWNSLAM HIT")
			end
		)
	end)

	task.delay(rawData.Cooldown, function()
		if character and character.Parent then
			character:SetAttribute("Attacking", false)
			self.StateService:ResetCombo(character)
		end
	end)
end

function M1Service:DoNormalM1(player)
	local character, humanoid, root = self.StateService:GetCharacterInfo(player)
	if not character then
		return
	end
	if not self.StateService:CanAttack(character) then
		return
	end

	local combo = self:GetNextCombo(character)

	if combo == self.FinalM1 and self.StateService:IsAirborne(humanoid) then
		character:SetAttribute("ComboCount", self.FinalM1)
		self:DoDownslam(player)
		return
	end

	local rawData = self.M1Data[combo]
	local isFinal = combo == self.FinalM1

	local attackData = self:BuildAttackData(rawData, {
		AttackType = "M1",
		Combo = combo,
		CanBeBlocked = true,
		CanBeCountered = true,
		HitCancelsTarget = true,
		Guardbreak = isFinal and rawData.Guardbreak == true,
		GuardbreakStun = rawData.GuardbreakStun,
	})

	character:SetAttribute("Attacking", true)
	self.StateService:LockJump(character, self.Config.JumpLockAfterM1)

	self:PlayM1StartFX(character, root, combo)

	print(player.Name .. " used M" .. combo)

	task.delay(rawData.HitDelay, function()
		if not character.Parent then
			return
		end
		if humanoid.Health <= 0 then
			return
		end
		if character:GetAttribute("UsingMove") then
			return
		end
		if not self:CanAttackContinue(character, attackData) then
			character:SetAttribute("Attacking", false)
			return
		end

		local hitSomething = false

		self.HitboxService:PerformSphereHitbox(
			character,
			root,
			rawData,
			function(targetCharacter, targetHumanoid, targetRoot)
				local blockMode = isFinal and "GuardbreakBlocking" or "Normal"

				local result = self:CheckStandardHitStart(
					character,
					root,
					targetCharacter,
					targetHumanoid,
					targetRoot,
					attackData,
					"M" .. tostring(combo),
					{
						RespectM1Immunity = not isFinal,
						BlockMode = blockMode,
					}
				)

				if result == "Countered" then
					hitSomething = true
					self:PlayM1Visual(character, combo, targetCharacter, targetRoot, true)
					print("M" .. combo .. " COUNTERED")
					return
				end

				if result == "IFrame" or result == "M1Immune" or result == "DamageLocked" or result == "Invalid" then
					return
				end

				if result == "Blocked" then
					hitSomething = true
					self:PlayM1Visual(character, combo, targetCharacter, targetRoot, true)
					print("M" .. combo .. " BLOCKED")
					return
				end

				if result == "Guardbreak" then
					hitSomething = true

					self.MovementService:StopCarryController(root)
					self.MovementService:StopCarryController(targetRoot)
					self.MovementService:StopYHoldController(root)
					self.MovementService:StopYHoldController(targetRoot)

					if self.UltService then
						self.UltService:AwardGuardbreak(character, targetCharacter)
					end

					self:PlayM1Visual(character, combo, targetCharacter, targetRoot, true)

					print("M5 GUARDBREAK")
					return
				end

				hitSomething = true
				character:SetAttribute("SuccessfulM1InCombo", true)

				self:PlayM1Visual(character, combo, targetCharacter, targetRoot, true)

				local armorInfo = self:ApplyDamageAndStun(
					character,
					targetCharacter,
					targetHumanoid,
					targetRoot,
					attackData,
					rawData.Stun
				)

				if combo < self.FinalM1 then
					if not armorInfo.Active or not armorInfo.PreventsKnockback then
						self.MovementService:StartM1Carry(root, targetRoot, rawData)
						self.MovementService:StartYHold(root, rawData.YHoldDuration or 0.4)
						self.MovementService:StartYHold(targetRoot, rawData.YHoldDuration or 0.4)
					else
						print("[M1Service] Armor prevented M1 carry:", targetCharacter.Name)
					end

					print("M" .. combo .. " HIT")
				else
					self.MovementService:StopCarryController(root)
					self.MovementService:StopCarryController(targetRoot)
					self.MovementService:StopYHoldController(root)
					self.MovementService:StopYHoldController(targetRoot)

					if not armorInfo.Active or not armorInfo.PreventsKnockback then
						if self.MovementService and self.MovementService.ApplyPresetKnockback then
							self.MovementService:ApplyPresetKnockback(root, targetRoot, rawData, "M5Preset")
						elseif self.MovementService and self.MovementService.ApplyDirectionalKnockback then
							self.MovementService:ApplyDirectionalKnockback(root, targetRoot, rawData, "M5Directional")
						else
							local direction = self.MovementService:GetDirectionBetween(root, targetRoot)
							targetRoot.AssemblyLinearVelocity = (direction * 45) + Vector3.new(0, 28, 0)
						end
					else
						print("[M1Service] Armor prevented M5 knockback:", targetCharacter.Name)
					end

					self.StateService:ApplyM1Immunity(targetCharacter, self.Config.PostM5M1Immunity or 1)
					self.VFXService:PlaySFXAtPart("GroundM5", targetRoot, 3)

					if self.UltService then
						self.UltService:AwardComboEnder(character, targetCharacter)
					end

					print("GROUND M5 KNOCKBACK HIT")
				end
			end
		)

		if not hitSomething then
			self:PlayM1Visual(character, combo, nil, nil, false)
		end
	end)

	task.delay(rawData.Cooldown, function()
		if character and character.Parent then
			character:SetAttribute("Attacking", false)

			if combo == self.FinalM1 then
				self.StateService:ResetCombo(character)
			end
		end
	end)
end

function M1Service:PerformM1(player, payload)
	local character, humanoid, root = self.StateService:GetCharacterInfo(player)
	if not character then
		return
	end
	if not self.StateService:CanAttack(character) then
		return
	end

	self.StateService:RefreshComboTimeout(character)

	local wantUptilt = payload and payload.wantUptilt

	if wantUptilt and self:CanUseUptilt(character) then
		self:DoUptilt(player)
		return
	end

	self:DoNormalM1(player)
end

return M1Service
