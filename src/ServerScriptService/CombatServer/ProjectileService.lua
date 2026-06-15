local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local ProjectileService = {}
ProjectileService.__index = ProjectileService

function ProjectileService.new(
	config,
	hitboxService,
	blockService,
	stateService,
	vfxService,
	counterService,
	combatStatusService,
	movementService,
	damageNumberService,
	progressionService
)
	local self = setmetatable({}, ProjectileService)

	self.Config = config
	self.HitboxService = hitboxService
	self.BlockService = blockService
	self.StateService = stateService
	self.VFXService = vfxService
	self.CounterService = counterService
	self.CombatStatusService = combatStatusService
	self.MovementService = movementService
	self.DamageNumberService = damageNumberService
	self.ProgressionService = progressionService

	self.UltService = nil
	self.KillCreditService = nil
	self.SoulBurstService = nil

	return self
end

function ProjectileService:EnsurePrimaryPart(model)
	if not model or not model:IsA("Model") then return nil end

	if model.PrimaryPart then
		return model.PrimaryPart
	end

	local primary = model:FindFirstChild("PrimaryPart", true)

	if primary and primary:IsA("BasePart") then
		model.PrimaryPart = primary
		return primary
	end

	local firstPart = model:FindFirstChildWhichIsA("BasePart", true)

	if firstPart then
		model.PrimaryPart = firstPart
		return firstPart
	end

	return nil
end

function ProjectileService:GetProjectilePart(projectile)
	if not projectile then return nil end

	if projectile:IsA("BasePart") then
		return projectile
	end

	if projectile:IsA("Model") then
		return self:EnsurePrimaryPart(projectile)
	end

	return nil
end

function ProjectileService:GetProjectileCFrame(projectile)
	if not projectile then return nil end

	if projectile:IsA("Model") then
		return projectile:GetPivot()
	elseif projectile:IsA("BasePart") then
		return projectile.CFrame
	end

	return nil
end

function ProjectileService:GetProjectilePosition(projectile)
	local cframe = self:GetProjectileCFrame(projectile)
	return cframe and cframe.Position
end

function ProjectileService:PivotProjectile(projectile, cframe)
	if not projectile or not projectile.Parent then return end

	if projectile:IsA("Model") then
		if not self:EnsurePrimaryPart(projectile) then return end
		projectile:PivotTo(cframe)
	elseif projectile:IsA("BasePart") then
		projectile.CFrame = cframe
	end
end

function ProjectileService:MakeLookCFrame(position, lookAtPosition)
	local direction = lookAtPosition - position

	if direction.Magnitude < 0.1 then
		direction = Vector3.new(0, 0, -1)
	end

	return CFrame.lookAt(position, position + direction.Unit)
end

function ProjectileService:SetProjectilePhysics(projectile, anchored)
	if not projectile then return end

	for _, descendant in ipairs(projectile:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = anchored == true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			descendant:SetAttribute("IsProjectile", true)
		end
	end

	if projectile:IsA("BasePart") then
		projectile.Anchored = anchored == true
		projectile.CanCollide = false
		projectile.CanTouch = false
		projectile.CanQuery = false
		projectile.Massless = true
		projectile:SetAttribute("IsProjectile", true)
	end

	projectile:SetAttribute("IsProjectile", true)
end

function ProjectileService:SetNetworkOwnerServer(projectile)
	local part = self:GetProjectilePart(projectile)
	if not part then return end

	pcall(function()
		part:SetNetworkOwner(nil)
	end)
end

function ProjectileService:FadeOutProjectile(projectile, lifetime)
	if not projectile or not projectile.Parent then return end

	for _, descendant in ipairs(projectile:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name ~= "PrimaryPart" then
			TweenService:Create(
				descendant,
				TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Transparency = 1 }
			):Play()
		end
	end

	if projectile:IsA("BasePart") then
		TweenService:Create(
			projectile,
			TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Transparency = 1 }
		):Play()
	end

	Debris:AddItem(projectile, lifetime or 0.2)
end

function ProjectileService:CreateLinearVelocity(projectile, velocity, maxForce)
	local part = self:GetProjectilePart(projectile)
	if not part then return nil, nil end

	local attachment = Instance.new("Attachment")
	attachment.Name = "ProjectileVelocityAttachment"
	attachment.Parent = part

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "ProjectileLinearVelocity"
	linearVelocity.Attachment0 = attachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	linearVelocity.MaxForce = maxForce or 150000
	linearVelocity.VectorVelocity = velocity
	linearVelocity.Parent = part

	Debris:AddItem(linearVelocity, 5)
	Debris:AddItem(attachment, 5)

	return linearVelocity, attachment
end

function ProjectileService:GetVelocityToTarget(startPosition, targetRoot, speed, lead)
	if not targetRoot or not targetRoot.Parent then
		return Vector3.new(0, 0, -speed)
	end

	local targetPosition = targetRoot.Position + Vector3.new(0, 1.2, 0)
	local targetVelocity = targetRoot.AssemblyLinearVelocity or Vector3.zero

	local distance = (targetPosition - startPosition).Magnitude
	local travelTime = distance / speed

	local predictedPosition = targetPosition + (targetVelocity * travelTime * (lead or 0.5))
	local direction = predictedPosition - startPosition

	if direction.Magnitude < 0.1 then
		direction = targetRoot.CFrame.LookVector
	end

	return direction.Unit * speed
end

function ProjectileService:CopyData(data)
	local copy = {}

	for key, value in pairs(data or {}) do
		copy[key] = value
	end

	return copy
end

function ProjectileService:BuildAttackData(data)
	local attackData = self:CopyData(data)

	if self.CombatStatusService and self.CombatStatusService.NormalizeAttackData then
		return self.CombatStatusService:NormalizeAttackData(attackData)
	end

	if attackData.Blockable == nil then
		attackData.Blockable = true
	end

	if attackData.CanBeBlocked == nil then
		attackData.CanBeBlocked = attackData.Blockable ~= false
	end

	if attackData.Unblockable == nil then
		attackData.Unblockable = false
	end

	if attackData.Guardbreak == nil then
		attackData.Guardbreak = false
	end

	if attackData.CanBeCountered == nil then
		attackData.CanBeCountered = true
	end

	if attackData.HitCancelsTarget == nil then
		attackData.HitCancelsTarget = true
	end

	if attackData.CancelableByHit == nil then
		attackData.CancelableByHit = true
	end

	return attackData
end

function ProjectileService:BuildBeamAttackData(data, isFinalTick)
	local attackData = self:CopyData(data)
	attackData.IsFinalBeamTick = isFinalTick == true

	if isFinalTick then
		attackData.Damage = data.FinalDamage or data.Damage
		attackData.Stun = data.FinalStun or data.Stun
		attackData.Knockback = data.FinalKnockback or data.Knockback
		attackData.UpwardKnockback = data.FinalUpwardKnockback or data.UpwardKnockback
		attackData.KnockbackDuration = data.FinalKnockbackDuration or data.KnockbackDuration
		attackData.KnockbackMaxForce = data.FinalKnockbackMaxForce or data.KnockbackMaxForce
		attackData.FinalKnockbackSource = data.FinalKnockbackSource
		attackData.UseAttackerPositionForFinalKnockback = data.UseAttackerPositionForFinalKnockback == true
	else
		if data.GuardbreakFinalOnly ~= false then
			attackData.Guardbreak = false
		end
	end

	return attackData
end

function ProjectileService:GetBattlegroundsMap()
	return workspace:FindFirstChild("BattlegroundsMap")
end

function ProjectileService:IsMapPart(part, mapFolder)
	if not part or not part:IsA("BasePart") then
		return false
	end

	local map = mapFolder or self:GetBattlegroundsMap()
	return map ~= nil and part:IsDescendantOf(map)
end

function ProjectileService:GetCharacterFromPart(part)
	local current = part

	while current and current ~= workspace do
		if current:IsA("Model") then
			local humanoid = current:FindFirstChildOfClass("Humanoid")
			local root = current:FindFirstChild("HumanoidRootPart")

			if humanoid and root then
				return current, humanoid, root
			end
		end

		current = current.Parent
	end

	return nil, nil, nil
end

function ProjectileService:IsProjectileInstance(instance)
	if not instance then
		return false
	end

	local current = instance

	while current and current ~= workspace do
		if current:GetAttribute("IsProjectile") == true then
			return true
		end

		local owner = current:GetAttribute("ProjectileOwner")
		if typeof(owner) == "string" and owner ~= "" then
			return true
		end

		if current.Name == "SansBoneShotProjectile" or current.Name == "WeakBoneShotProjectile" then
			return true
		end

		current = current.Parent
	end

	return false
end

function ProjectileService:IsValidProjectileCharacterTarget(ownerCharacter, targetCharacter, options)
	if not targetCharacter or not targetCharacter.Parent then
		return false
	end

	if targetCharacter == ownerCharacter then
		return false
	end

	local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
	local root = targetCharacter:FindFirstChild("HumanoidRootPart")

	if not humanoid or not root or humanoid.Health <= 0 then
		return false
	end

	options = options or {}

	local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)
	local ownerPlayer = ownerCharacter and Players:GetPlayerFromCharacter(ownerCharacter)

	if ownerPlayer and targetPlayer and targetPlayer == ownerPlayer then
		return false
	end

	if options.PlayersOnly == true then
		if targetPlayer then
			return true
		end

		return options.AllowDummies == true
	end

	return true
end

function ProjectileService:AddIgnoreInstance(ignoreList, seen, instance)
	if not instance or seen[instance] then
		return
	end

	seen[instance] = true
	table.insert(ignoreList, instance)
end

function ProjectileService:BuildProjectileIgnoreList(ownerCharacter, projectile, extraIgnore)
	local ignore = {}
	local seen = {}

	self:AddIgnoreInstance(ignore, seen, ownerCharacter)
	self:AddIgnoreInstance(ignore, seen, projectile)

	local function addList(list)
		if typeof(list) ~= "table" then
			return
		end

		for _, instance in ipairs(list) do
			self:AddIgnoreInstance(ignore, seen, instance)
		end
	end

	addList(extraIgnore)

	return ignore
end

function ProjectileService:CollectProjectileIgnoreInstances(info)
	local combined = {}

	local function addList(list)
		if typeof(list) ~= "table" then
			return
		end

		for _, instance in ipairs(list) do
			table.insert(combined, instance)
		end
	end

	addList(info.ExcludeList)
	addList(info.IgnoreInstances)
	addList(info.ExtraIgnoreInstances)
	addList(info.RaycastIgnoreInstances)
	addList(info.OverlapIgnoreInstances)

	return combined
end

function ProjectileService:GetCollisionProfileOptions(info)
	if info.CollisionProfile ~= "BoneProjectile" then
		return nil
	end

	return {
		-- Bone projectiles should hit real players and training dummies by default.
		PlayersOnly = info.PlayersOnly ~= false,
		AllowDummies = info.AllowDummies ~= false,
		MapFolder = info.MapFolder or info.WorldFolder or info.WorldHitFolder or self:GetBattlegroundsMap(),
	}
end

function ProjectileService:BuildProjectileRaycastParams(info)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = self:BuildProjectileIgnoreList(
		info.OwnerCharacter,
		info.Projectile,
		self:CollectProjectileIgnoreInstances(info)
	)

	return params
end

function ProjectileService:NormalizeWorldHit(projectile, hit)
	if typeof(hit) == "table" then
		local hitPart = hit.HitPart or hit.Part

		if not hitPart and typeof(hit.RaycastResult) == "RaycastResult" then
			hitPart = hit.RaycastResult.Instance
		end

		return {
			Projectile = hit.Projectile or projectile,
			HitPart = hitPart,
			HitPosition = hit.HitPosition or hit.Position or (hit.RaycastResult and hit.RaycastResult.Position),
			HitNormal = hit.HitNormal or hit.Normal or (hit.RaycastResult and hit.RaycastResult.Normal),
			RaycastResult = hit.RaycastResult,
		}
	end

	if typeof(hit) == "RaycastResult" then
		return {
			Projectile = projectile,
			HitPart = hit.Instance,
			HitPosition = hit.Position,
			HitNormal = hit.Normal,
			RaycastResult = hit,
		}
	end

	if typeof(hit) == "Instance" then
		return {
			Projectile = projectile,
			HitPart = hit:IsA("BasePart") and hit or nil,
		}
	end

	return {
		Projectile = projectile,
	}
end

function ProjectileService:InvokeProjectileHitCallback(callback, hitInfo)
	if not callback then
		return
	end

	local ok, parameterCount = pcall(debug.info, callback, "a")

	if ok and typeof(parameterCount) == "number" and parameterCount > 1 then
		pcall(function()
			callback(
				hitInfo.TargetCharacter,
				hitInfo.TargetHumanoid,
				hitInfo.TargetRoot,
				hitInfo.Result,
				hitInfo
			)
		end)

		return
	end

	pcall(function()
		callback(hitInfo)
	end)
end

function ProjectileService:InvokeProjectileWorldHitCallback(callback, hitInfo)
	if not callback then
		return
	end

	local success = pcall(function()
		callback(hitInfo)
	end)

	if success then
		return
	end

	pcall(function()
		callback(hitInfo.Projectile, hitInfo.HitPart or hitInfo.RaycastResult)
	end)
end

function ProjectileService:ShowDamageNumber(targetRoot, amount, options)
	if not self.DamageNumberService then
		return
	end

	if not targetRoot or not targetRoot.Parent then
		return
	end

	if typeof(amount) ~= "number" or amount <= 0 then
		return
	end

	self.DamageNumberService:ShowDamage(targetRoot, amount, options)
end

function ProjectileService:ReportDamage(ownerCharacter, targetCharacter, targetRoot, damageAmount, attackData)
	if not ownerCharacter or not targetCharacter then
		return
	end

	if typeof(damageAmount) ~= "number" or damageAmount <= 0 then
		return
	end

	if self.KillCreditService then
		local source = "Projectile"

		if attackData and attackData.AttackType == "Beam" then
			source = "Beam"
		elseif attackData and typeof(attackData.AttackName) == "string" then
			source = attackData.AttackName
		end

		self.KillCreditService:RecordDamage(ownerCharacter, targetCharacter, damageAmount, source)
	end

	self:ShowDamageNumber(targetRoot, damageAmount)

	if attackData and attackData.AwardsUlt == false then
		local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")

		if humanoid and humanoid.Health <= 0 then
			if self.KillCreditService then
				self.KillCreditService:AwardKill(ownerCharacter, targetCharacter, "ProjectileNoUlt")
			elseif self.ProgressionService and self.ProgressionService.AwardKill then
				self.ProgressionService:AwardKill(ownerCharacter, targetCharacter)
			elseif self.UltService
				and self.UltService.ProgressionService
				and self.UltService.ProgressionService.AwardKill
			then
				self.UltService.ProgressionService:AwardKill(ownerCharacter, targetCharacter)
			end
		end

		return
	end

	if self.UltService and self.UltService.AwardDamageEvent then
		self.UltService:AwardDamageEvent(ownerCharacter, targetCharacter, damageAmount)
		return
	end

	if self.ProgressionService and self.ProgressionService.AwardKill then
		local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")

		if humanoid and humanoid.Health <= 0 then
			if self.KillCreditService then
				self.KillCreditService:AwardKill(ownerCharacter, targetCharacter, "ProjectileDamageEvent")
			else
				self.ProgressionService:AwardKill(ownerCharacter, targetCharacter)
			end
		end
	end
end

function ProjectileService:ApplyProjectileHit(info)
	local ownerCharacter = info.OwnerCharacter
	local projectilePosition = info.ProjectilePosition
	local targetCharacter = info.TargetCharacter
	local targetHumanoid = info.TargetHumanoid
	local targetRoot = info.TargetRoot
	local attackData = self:BuildAttackData(info.AttackData)
	local attackName = info.AttackName or "Projectile"
	attackData.AttackName = attackName

	if not ownerCharacter or not ownerCharacter.Parent then return "Invalid" end
	if not targetCharacter or not targetCharacter.Parent then return "Invalid" end
	if not targetHumanoid or targetHumanoid.Health <= 0 then return "Invalid" end
	if not targetRoot or not targetRoot.Parent then return "Invalid" end
	if not projectilePosition then return "Invalid" end

	if self.CombatStatusService
		and self.CombatStatusService:IsDamageLockedFromAttacker(targetCharacter, ownerCharacter)
	then
		return "DamageLocked"
	end

	if self.CombatStatusService and self.CombatStatusService:HasIFrames(targetCharacter, attackData) then
		return "IFrame"
	end

	if self.CombatStatusService and self.CombatStatusService:CanAttackBeCountered(attackData) then
		if self.CounterService and self.CounterService.TryCounterHit then
			local countered = self.CounterService:TryCounterHit({
				AttackerCharacter = ownerCharacter,
				TargetCharacter = targetCharacter,
				AttackName = attackName,
				AttackData = attackData,
				HitPosition = projectilePosition,
			})

			if countered then
				return "Countered"
			end
		end
	end

	local canBlock = true

	if self.CombatStatusService then
		canBlock = self.CombatStatusService:CanAttackBeBlocked(attackData)
	else
		canBlock = attackData.CanBeBlocked ~= false and attackData.Unblockable ~= true
	end

	local projectileBlockSource = {
		Position = projectilePosition,
	}

	if canBlock and self.BlockService and self.BlockService:CanBlockHit(targetCharacter, projectileBlockSource, attackData) then
		if attackData.Guardbreak then
			self.StateService:GuardbreakCharacter(targetCharacter, attackData.GuardbreakStun or 1.25)
			self.BlockService:PlayBlockBreakVFX(targetRoot)

			if self.CombatStatusService and self.CombatStatusService.TagCombatPair then
				self.CombatStatusService:TagCombatPair(ownerCharacter, targetCharacter)
			end

			if self.UltService then
				self.UltService:AwardGuardbreak(ownerCharacter, targetCharacter)
			end

			return "Guardbreak"
		end

		self.BlockService:PlayBlockVFX(targetRoot)
		return "Blocked"
	end

	local armorInfo

	if self.CombatStatusService then
		armorInfo = self.CombatStatusService:GetArmorInfo(targetCharacter, attackData)
		self.CombatStatusService:TryHitCancelTarget(targetCharacter, attackData)
	else
		armorInfo = {
			Active = false,
			DamageReduction = 0,
			PreventsStun = false,
			PreventsKnockback = false,
		}
	end

	local rawDamage = attackData.Damage or 0
	local finalDamage = rawDamage

	if armorInfo.Active then
		finalDamage = rawDamage * (1 - (armorInfo.DamageReduction or 0))
	end

	if finalDamage > 0 then
		targetHumanoid:TakeDamage(finalDamage)

		if self.CombatStatusService and self.CombatStatusService.TagCombatPair then
			self.CombatStatusService:TagCombatPair(ownerCharacter, targetCharacter)
		end

		self:ReportDamage(ownerCharacter, targetCharacter, targetRoot, finalDamage, attackData)

		if self.SoulBurstService then
			self.SoulBurstService:AwardForHitTaken(targetCharacter, finalDamage, attackData.Stun, attackData)
		end
	end

	if attackData.Stun and attackData.Stun > 0 then
		if not armorInfo.Active or not armorInfo.PreventsStun then
			self.StateService:StunCharacter(targetCharacter, attackData.Stun)
		end
	end

	if self.VFXService then
		self.VFXService:EmitHitVFXOnVictim(targetRoot, ownerCharacter)

		if info.HitSoundCharacter and info.HitSoundName and self.VFXService.PlayCharacterSFXAtPart then
			self.VFXService:PlayCharacterSFXAtPart(info.HitSoundCharacter, info.HitSoundName, targetRoot, 2)
		end
	end

	if attackData.Knockback and attackData.Knockback > 0 then
		if not armorInfo.Active or not armorInfo.PreventsKnockback then
			local explicitDirection = info.KnockbackDirection or info.BeamDirection
			local useAttackerPosition = attackData.IsFinalBeamTick == true
				and (
					attackData.UseAttackerPositionForFinalKnockback == true
					or attackData.FinalKnockbackSource == "Attacker"
				)

			if useAttackerPosition then
				local ownerRoot = ownerCharacter:FindFirstChild("HumanoidRootPart")

				if ownerRoot then
					local fromAttacker = targetRoot.Position - ownerRoot.Position
					local flatFromAttacker = Vector3.new(fromAttacker.X, 0, fromAttacker.Z)

					if flatFromAttacker.Magnitude < 0.05 then
						flatFromAttacker = Vector3.new(ownerRoot.CFrame.LookVector.X, 0, ownerRoot.CFrame.LookVector.Z)
					end

					if flatFromAttacker.Magnitude >= 0.05 then
						explicitDirection = flatFromAttacker.Unit
					end
				end
			end

			if explicitDirection
				and typeof(explicitDirection) == "Vector3"
				and explicitDirection.Magnitude > 0.05
				and self.MovementService
				and self.MovementService.ApplyForceKnockback
			then
				local direction = explicitDirection.Unit
				local speed = attackData.Knockback
				local upward = attackData.UpwardKnockback or 0
				local duration = attackData.KnockbackDuration
				local maxForce = attackData.KnockbackMaxForce
				local debugLabel = attackName

				if attackData.KnockbackPreset == "PresetKnockback" then
					speed = attackData.PresetKnockbackSpeed or speed
					upward = attackData.PresetKnockbackUpward or upward
					duration = attackData.PresetKnockbackDuration or duration
					maxForce = attackData.PresetKnockbackMaxForce or maxForce
					debugLabel = attackName .. "Preset"
				end

				local velocity = (direction * speed) + Vector3.new(0, upward, 0)
				local wallOptions = nil

				if useAttackerPosition or attackData.WallComboPrevention == true then
					wallOptions = {
						EnableWallComboPrevention = true,
						AttackerCharacter = ownerCharacter,
					}
				end

				self.MovementService:ApplyForceKnockback(
					targetRoot,
					velocity,
					duration,
					maxForce,
					debugLabel,
					wallOptions
				)

				if armorInfo.Active then
					return "ArmoredHit"
				end

				return "Hit"
			end

			local direction = targetRoot.Position - projectilePosition
			direction = Vector3.new(direction.X, 0, direction.Z)

			if direction.Magnitude < 0.05 and self.MovementService then
				local ownerRoot = ownerCharacter:FindFirstChild("HumanoidRootPart")

				if ownerRoot then
					direction = self.MovementService:GetDirectionBetween(ownerRoot, targetRoot)
					direction = Vector3.new(direction.X, 0, direction.Z)
				end
			end

			if direction.Magnitude < 0.05 then
				direction = Vector3.new(0, 0, -1)
			else
				direction = direction.Unit
			end

			if self.MovementService and self.MovementService.ApplyStraightKnockback then
				self.MovementService:ApplyStraightKnockback(
					targetRoot,
					direction,
					attackData.Knockback,
					attackData.UpwardKnockback or 0,
					attackData.KnockbackDuration,
					attackData.KnockbackMaxForce,
					attackName
				)
			else
				targetRoot.AssemblyLinearVelocity =
					(direction * attackData.Knockback)
					+ Vector3.new(0, attackData.UpwardKnockback or 0, 0)
			end
		end
	end

	if armorInfo.Active then
		return "ArmoredHit"
	end

	return "Hit"
end

function ProjectileService:IsSuccessfulProjectileResult(result)
	return result == "Hit"
		or result == "ArmoredHit"
		or result == "Blocked"
		or result == "Guardbreak"
		or result == "Countered"
end

function ProjectileService:TryProjectileCharacterHit(info, targetCharacter, targetHumanoid, targetRoot, hitPosition, hitPart)
	if not targetCharacter or not targetHumanoid or not targetRoot then
		return false, "Invalid"
	end

	if targetCharacter == info.OwnerCharacter then
		return false, "Owner"
	end

	local profileOptions = self:GetCollisionProfileOptions(info)

	if profileOptions and not self:IsValidProjectileCharacterTarget(
		info.OwnerCharacter,
		targetCharacter,
		profileOptions
	) then
		return false, "Filtered"
	end

	if info.ShouldHitCharacter and info.ShouldHitCharacter(targetCharacter) == false then
		return false, "Filtered"
	end

	if info.CharacterFilter and info.CharacterFilter(targetCharacter) == false then
		return false, "Filtered"
	end

	local result = self:ApplyProjectileHit({
		OwnerCharacter = info.OwnerCharacter,
		ProjectilePosition = hitPosition or self:GetProjectilePosition(info.Projectile),
		TargetCharacter = targetCharacter,
		TargetHumanoid = targetHumanoid,
		TargetRoot = targetRoot,
		AttackData = info.AttackData,
		AttackName = info.AttackName,
		HitSoundCharacter = info.HitSoundCharacter,
		HitSoundName = info.HitSoundName,
		KnockbackDirection = info.KnockbackDirection,
		BeamDirection = info.BeamDirection,
	})

	if result == "IFrame" or result == "DamageLocked" or result == "Invalid" then
		if info.OnPassThrough then
			pcall(function()
				info.OnPassThrough(targetCharacter, targetHumanoid, targetRoot, result)
			end)
		end

		return false, result
	end

	if self:IsSuccessfulProjectileResult(result) then
		if info.OnHit then
			self:InvokeProjectileHitCallback(info.OnHit, {
				Projectile = info.Projectile,
				TargetCharacter = targetCharacter,
				TargetHumanoid = targetHumanoid,
				TargetRoot = targetRoot,
				HitPart = hitPart or targetRoot,
				HitPosition = hitPosition or targetRoot.Position,
				Result = result,
			})
		end

		if info.DestroyOnCharacterHit ~= false then
			self:FadeOutProjectile(info.Projectile, info.FadeLifetime or 0.2)
		end

		return true, result
	end

	return false, result
end

function ProjectileService:PerformBeamTick(info)
	local ownerCharacter = info.OwnerCharacter
	local startPosition = info.BeamStartPosition or info.StartPosition
	local direction = info.Direction
	local attackData = self:BuildBeamAttackData(info.AttackData or {}, info.IsFinalTick == true)
	local attackName = info.AttackName or "Beam"

	if not ownerCharacter or not ownerCharacter.Parent then
		return {}
	end

	if typeof(startPosition) ~= "Vector3" then
		return {}
	end

	if typeof(direction) ~= "Vector3" or direction.Magnitude < 0.05 then
		return {}
	end

	direction = direction.Unit

	local length = info.BeamLength or attackData.BeamLength or 80
	local step = info.BeamStep or attackData.BeamStep or 6
	local radius = info.BeamRadius or attackData.BeamRadius or 5

	local hitThisTick = {}
	local results = {}

	for distance = 0, length, step do
		local position = startPosition + (direction * distance)

		self.HitboxService:PerformSphereAtPosition(
			ownerCharacter,
			position,
			radius,
			function(targetCharacter, targetHumanoid, targetRoot)
				if hitThisTick[targetCharacter] then
					return
				end

				hitThisTick[targetCharacter] = true

				local result = self:ApplyProjectileHit({
					OwnerCharacter = ownerCharacter,
					ProjectilePosition = position,
					TargetCharacter = targetCharacter,
					TargetHumanoid = targetHumanoid,
					TargetRoot = targetRoot,
					AttackData = attackData,
					AttackName = attackName,
					BeamDirection = direction,
					KnockbackDirection = info.KnockbackDirection or info.BeamDirection or direction,
					HitSoundCharacter = info.HitSoundCharacter,
					HitSoundName = info.HitSoundName,
				})

				results[targetCharacter] = result

				if info.OnBeamHit then
					info.OnBeamHit(targetCharacter, targetHumanoid, targetRoot, result, position)
				end
			end
		)
	end

	return results
end

function ProjectileService:RunBeam(info)
	local activeTime = info.BeamActiveTime or 0.4
	local tickRate = info.BeamTickRate or 0.08
	local totalTicks = math.max(1, math.floor(activeTime / tickRate + 0.5))

	for tickIndex = 1, totalTicks do
		if info.IsActive and info.IsActive() == false then
			break
		end

		local isFinalTick = tickIndex == totalTicks

		if info.OnBeamTick then
			info.OnBeamTick(tickIndex, isFinalTick)
		end

		self:PerformBeamTick({
			OwnerCharacter = info.OwnerCharacter,
			BeamStartPosition = info.BeamStartPosition or info.StartPosition,
			Direction = info.Direction,
			AttackData = info.AttackData,
			AttackName = info.AttackName,
			BeamLength = info.BeamLength,
			BeamStep = info.BeamStep,
			BeamRadius = info.BeamRadius,
			IsFinalTick = isFinalTick,
			BeamDirection = info.BeamDirection or info.Direction,
			KnockbackDirection = info.KnockbackDirection or info.BeamDirection or info.Direction,
			HitSoundCharacter = info.HitSoundCharacter,
			HitSoundName = info.HitSoundName,
			OnBeamHit = info.OnBeamHit,
		})

		task.wait(tickRate)
	end
end

function ProjectileService:CheckWorldHit(info, previousPosition, currentPosition)
	if info.CanHitWorld == false and info.CollisionProfile ~= "BoneProjectile" then
		return false
	end

	local projectile = info.Projectile

	local direction = currentPosition - previousPosition
	if direction.Magnitude < 0.05 then return false end

	local params = self:BuildProjectileRaycastParams(info)
	local profileOptions = self:GetCollisionProfileOptions(info)
	local raycastOrigin = previousPosition
	local raycastDirection = direction
	local unitDirection = direction.Unit

	for _ = 1, 8 do
		local result = workspace:Raycast(raycastOrigin, raycastDirection, params)

		if not result then
			return false
		end

		local hitPart = result.Instance

		if not hitPart or not hitPart.Parent then
			return false
		end

		if self:IsProjectileInstance(hitPart) then
			-- Skip other bones/projectiles.
		else
			local targetCharacter, targetHumanoid, targetRoot = self:GetCharacterFromPart(hitPart)

			if targetCharacter then
				local didCharacterHit = self:TryProjectileCharacterHit(
					info,
					targetCharacter,
					targetHumanoid,
					targetRoot,
					result.Position,
					hitPart
				)

				if didCharacterHit then
					return true
				end

				-- Invalid/iframe/damage-locked targets are skipped so the projectile can keep moving.
			else
				local shouldHitWorld = true

				if profileOptions then
					shouldHitWorld = self:IsMapPart(hitPart, profileOptions.MapFolder)
				elseif info.ShouldHitPart and info.ShouldHitPart(hitPart) == false then
					shouldHitWorld = false
				elseif info.ShouldHitWorldPart and info.ShouldHitWorldPart(hitPart) == false then
					shouldHitWorld = false
				elseif info.WorldHitFilter and info.WorldHitFilter(hitPart) == false then
					shouldHitWorld = false
				elseif info.PartFilter and info.PartFilter(hitPart) == false then
					shouldHitWorld = false
				end

				if shouldHitWorld then
					local hitInfo = self:NormalizeWorldHit(projectile, result)

					if info.OnWorldHit then
						self:InvokeProjectileWorldHitCallback(info.OnWorldHit, hitInfo)
					end

					if info.DestroyOnWorldHit ~= false then
						self:FadeOutProjectile(projectile, info.FadeLifetime or 0.2)
					end

					return true
				end
			end
		end

		local remaining = (currentPosition - result.Position).Magnitude

		if remaining <= 0.05 then
			return false
		end

		raycastOrigin = result.Position + unitDirection * 0.05
		raycastDirection = unitDirection * remaining
	end

	return false
end

function ProjectileService:CheckCharacterHit(info)
	local projectile = info.Projectile
	local position = self:GetProjectilePosition(projectile)

	if not position then return false end

	local didHit = false

	self.HitboxService:PerformSphereAtPosition(
		info.OwnerCharacter,
		position,
		info.HitRadius or 4,
		function(targetCharacter, targetHumanoid, targetRoot)
			if didHit then return end

			local hit, result = self:TryProjectileCharacterHit(
				info,
				targetCharacter,
				targetHumanoid,
				targetRoot,
				position,
				targetRoot
			)

			if hit then
				didHit = true
			elseif result == "IFrame" or result == "DamageLocked" or result == "Invalid" then
				if info.OnPassThrough then
					pcall(function()
						info.OnPassThrough(targetCharacter, targetHumanoid, targetRoot, result)
					end)
				end
			end
		end
	)

	return didHit
end

function ProjectileService:LaunchProjectile(info)
	local projectile = info.Projectile
	local ownerCharacter = info.OwnerCharacter

	if not projectile or not projectile.Parent then return nil end
	if not ownerCharacter or not ownerCharacter.Parent then return nil end

	local part = self:GetProjectilePart(projectile)

	if not part then
		projectile:Destroy()
		return nil
	end

	local startPosition = self:GetProjectilePosition(projectile)

	if not startPosition then
		projectile:Destroy()
		return nil
	end

	local speed = info.Speed or 120
	local velocity

	if info.Velocity then
		velocity = info.Velocity
	elseif info.TargetRoot then
		velocity = self:GetVelocityToTarget(
			startPosition,
			info.TargetRoot,
			speed,
			info.AutoAimLead or 0.5
		)
	elseif info.Direction then
		velocity = info.Direction.Unit * speed
	else
		velocity = part.CFrame.LookVector * speed
	end

	if velocity.Magnitude < 0.1 then
		velocity = Vector3.new(0, 0, -speed)
	end

	if info.CollisionProfile == "BoneProjectile" then
		projectile:SetAttribute("IsProjectile", true)
		projectile:SetAttribute("ProjectileOwner", info.AttackName or "BoneProjectile")
	end

	self:PivotProjectile(projectile, self:MakeLookCFrame(startPosition, startPosition + velocity))
	self:SetProjectilePhysics(projectile, false)
	self:SetNetworkOwnerServer(projectile)

	local linearVelocity = self:CreateLinearVelocity(projectile, velocity, info.MaxForce or 150000)

	if info.OnLaunch then
		info.OnLaunch(projectile, velocity)
	end

	local previousPosition = startPosition
	local startTime = os.clock()
	local lifetime = info.Lifetime or 3
	local finished = false

	local connection
	connection = RunService.Heartbeat:Connect(function()
		if finished then
			if connection then connection:Disconnect() end
			return
		end

		if not projectile or not projectile.Parent then
			finished = true
			if connection then connection:Disconnect() end
			return
		end

		local currentPosition = self:GetProjectilePosition(projectile)

		if not currentPosition then
			finished = true
			if connection then connection:Disconnect() end
			projectile:Destroy()
			return
		end

		local currentVelocity = linearVelocity and linearVelocity.VectorVelocity or velocity

		if currentVelocity.Magnitude > 0.1 then
			self:PivotProjectile(projectile, self:MakeLookCFrame(currentPosition, currentPosition + currentVelocity))
		end

		if self:CheckWorldHit(info, previousPosition, currentPosition) then
			finished = true
			if connection then connection:Disconnect() end
			return
		end

		if self:CheckCharacterHit(info) then
			finished = true
			if connection then connection:Disconnect() end
			return
		end

		previousPosition = currentPosition

		if os.clock() - startTime >= lifetime then
			finished = true
			if connection then connection:Disconnect() end

			if info.OnExpire then
				info.OnExpire(projectile)
			end

			if info.DestroyOnExpire ~= false then
				self:FadeOutProjectile(projectile, info.FadeLifetime or 0.2)
			end

			return
		end
	end)

	Debris:AddItem(projectile, lifetime + 0.75)

	return {
		Projectile = projectile,
		Connection = connection,
		LinearVelocity = linearVelocity,
		Velocity = velocity,
	}
end

return ProjectileService