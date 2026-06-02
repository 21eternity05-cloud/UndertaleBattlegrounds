local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local ProjectileService = {}
ProjectileService.__index = ProjectileService

function ProjectileService.new(config, hitboxService, blockService, stateService, vfxService, counterService, combatStatusService, movementService)
	local self = setmetatable({}, ProjectileService)

	self.Config = config
	self.HitboxService = hitboxService
	self.BlockService = blockService
	self.StateService = stateService
	self.VFXService = vfxService
	self.CounterService = counterService
	self.CombatStatusService = combatStatusService
	self.MovementService = movementService

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
		end
	end

	if projectile:IsA("BasePart") then
		projectile.Anchored = anchored == true
		projectile.CanCollide = false
		projectile.CanTouch = false
		projectile.CanQuery = false
		projectile.Massless = true
	end
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

function ProjectileService:BuildAttackData(data)
	local attackData = {}

	for key, value in pairs(data or {}) do
		attackData[key] = value
	end

	attackData.CanBeBlocked = data.CanBeBlocked ~= false
	attackData.Unblockable = data.Unblockable == true
	attackData.Guardbreak = data.Guardbreak == true
	attackData.CanBeCountered = data.CanBeCountered ~= false
	attackData.HitCancelsTarget = data.HitCancelsTarget == true

	return attackData
end

function ProjectileService:ApplyProjectileHit(info)
	local ownerCharacter = info.OwnerCharacter
	local projectilePosition = info.ProjectilePosition
	local targetCharacter = info.TargetCharacter
	local targetHumanoid = info.TargetHumanoid
	local targetRoot = info.TargetRoot
	local attackData = self:BuildAttackData(info.AttackData)
	local attackName = info.AttackName or "Projectile"

	if not ownerCharacter or not ownerCharacter.Parent then return "Invalid" end
	if not targetCharacter or not targetCharacter.Parent then return "Invalid" end
	if not targetHumanoid or targetHumanoid.Health <= 0 then return "Invalid" end
	if not targetRoot or not targetRoot.Parent then return "Invalid" end
	if not projectilePosition then return "Invalid" end

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

	if canBlock and self.BlockService and self.BlockService:CanBlockHit(targetCharacter, projectileBlockSource) then
		if attackData.Guardbreak then
			self.StateService:GuardbreakCharacter(targetCharacter, attackData.GuardbreakStun or 1.25)
			self.BlockService:PlayBlockBreakVFX(targetRoot)

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

		if self.UltService then
			self.UltService:AwardDamageEvent(ownerCharacter, targetCharacter, finalDamage)
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

			targetRoot.AssemblyLinearVelocity =
				(direction * attackData.Knockback)
				+ Vector3.new(0, attackData.UpwardKnockback or 0, 0)
		end
	end

	if armorInfo.Active then
		return "ArmoredHit"
	end

	return "Hit"
end

function ProjectileService:CheckWorldHit(info, previousPosition, currentPosition)
	if info.CanHitWorld == false then
		return false
	end

	local projectile = info.Projectile
	local ownerCharacter = info.OwnerCharacter

	local direction = currentPosition - previousPosition
	if direction.Magnitude < 0.05 then return false end

	local excludeList = {
		ownerCharacter,
		projectile,
	}

	if info.ExcludeList then
		for _, item in ipairs(info.ExcludeList) do
			table.insert(excludeList, item)
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excludeList

	local result = workspace:Raycast(previousPosition, direction, params)

	if result then
		if info.OnWorldHit then
			info.OnWorldHit(projectile, result)
		end

		if info.DestroyOnWorldHit ~= false then
			self:FadeOutProjectile(projectile, info.FadeLifetime or 0.2)
		end

		return true
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

			local result = self:ApplyProjectileHit({
				OwnerCharacter = info.OwnerCharacter,
				ProjectilePosition = position,
				TargetCharacter = targetCharacter,
				TargetHumanoid = targetHumanoid,
				TargetRoot = targetRoot,
				AttackData = info.AttackData,
				AttackName = info.AttackName,
				HitSoundCharacter = info.HitSoundCharacter,
				HitSoundName = info.HitSoundName,
			})

			if result == "IFrame" or result == "Invalid" then
				if info.OnPassThrough then
					info.OnPassThrough(targetCharacter, targetHumanoid, targetRoot, result)
				end

				return
			end

			if result == "Hit"
				or result == "ArmoredHit"
				or result == "Blocked"
				or result == "Guardbreak"
				or result == "Countered"
			then
				didHit = true

				if info.OnHit then
					info.OnHit(targetCharacter, targetHumanoid, targetRoot, result)
				end

				if info.DestroyOnCharacterHit ~= false then
					self:FadeOutProjectile(projectile, info.FadeLifetime or 0.2)
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