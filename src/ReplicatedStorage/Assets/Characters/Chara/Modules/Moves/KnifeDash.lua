local KnifeDash = {
	DisplayName = "Knife Dash",
	AnimationName = "KnifeDash",

	Cooldown = 6,
	MaxLockTime = 1.6,

	Windup = 0.32,

	DashDistance = 55,
	DashSpeed = 115,
	CheckInterval = 0.05,

	Damage = 7,
	Stun = 0.95,

	WhiffEndlag = 0.42,
	HitEndlag = 0.08,
	BlockEndlag = 0.14,

	AnimationCancelAfterHit = 0.25,

	CanBeBlocked = true,
	Unblockable = false,
	Guardbreak = false,
	CanBeCountered = true,

	HitCancelsTarget = true,
	CancelableByHit = true,

	HasIFrames = false,
	HasArmor = false,

	Hitbox = {
		Radius = 6,
		StartOffset = -7.5,
		EndOffset = -22,
	},
}

function KnifeDash.Execute(ctx)
	local moveData = ctx.MoveData
	local character = ctx.Character
	local humanoid = ctx.Humanoid
	local root = ctx.Root

	local RunService = game:GetService("RunService")
	local Debris = game:GetService("Debris")

	local originalWalkSpeed = humanoid.WalkSpeed

	local function playCharaSFX(soundName, parentPart, lifetime)
		if ctx.VFXService and ctx.VFXService.PlayCharacterSFXAtPart then
			ctx.VFXService:PlayCharacterSFXAtPart("Chara", soundName, parentPart or root, lifetime or 2)
		end
	end

	local function playCharaM1HitSFX(targetRoot)
		if not targetRoot then return end

		if ctx.VFXService and ctx.VFXService.PlayCharacterSFXAtPart then
			ctx.VFXService:PlayCharacterSFXAtPart("Chara", "M1", targetRoot, 2)
		end
	end

	local function playCharaMoveVFX(vfxName, targetCharacter, targetRoot)
		if ctx.VFXService and ctx.VFXService.PlayCharacterMoveVFX then
			ctx.VFXService:PlayCharacterMoveVFX(character, vfxName, targetCharacter, targetRoot)
		end
	end

	local function stopKnifeDashAnimation(delayTime)
		task.delay(delayTime or 0, function()
			if not character or not character.Parent then return end

			if ctx.StateService.AnimationService then
				ctx.StateService.AnimationService:StopCharacterAnimationByName(
					character,
					moveData.AnimationName or "KnifeDash",
					0.05
				)
			end
		end)
	end

	local function restoreStartupMovement()
		if humanoid and humanoid.Parent then
			humanoid.WalkSpeed = originalWalkSpeed
		end
	end

	local function cancelDuringStartup(reason)
		print("[Chara] Knife Dash canceled during startup:", reason or "unknown")

		restoreStartupMovement()
		playCharaMoveVFX("KnifeDashTrailStop")
		stopKnifeDashAnimation(0)

		ctx:FinishMove(0)
	end

	playCharaSFX("KnifeCharge", root, 2)
	playCharaMoveVFX("KnifeDashStart")

	humanoid.WalkSpeed = 0
	humanoid.Jump = false
	root.AssemblyLinearVelocity = Vector3.zero

	local windup = moveData.Windup or 0.32
	local startupStart = os.clock()

	while os.clock() - startupStart < windup do
		if not character or not character.Parent then
			restoreStartupMovement()
			return
		end

		if not humanoid or not humanoid.Parent or humanoid.Health <= 0 then
			restoreStartupMovement()
			return
		end

		if character:GetAttribute("Stunned") then
			cancelDuringStartup("Stunned")
			return
		end

		if character:GetAttribute("Guardbroken") then
			cancelDuringStartup("Guardbroken")
			return
		end

		if not ctx:IsActive() then
			cancelDuringStartup("Move inactive")
			return
		end

		root.AssemblyLinearVelocity = Vector3.zero
		task.wait()
	end

	if not ctx:IsActive() then
		restoreStartupMovement()
		playCharaMoveVFX("KnifeDashTrailStop")
		return
	end

	playCharaSFX("KnifeChargeEnd", root, 2)
	playCharaMoveVFX("KnifeDashTrailStart")

	humanoid.WalkSpeed = ctx.Config.DefaultWalkSpeed

	local dashDistance = moveData.DashDistance or 55
	local dashSpeed = moveData.DashSpeed or 115
	local checkInterval = moveData.CheckInterval or 0.05

	local traveled = 0
	local lastPosition = root.Position
	local lastCheckTime = checkInterval
	local finished = false

	local lockedForward = root.CFrame.LookVector
	lockedForward = Vector3.new(lockedForward.X, 0, lockedForward.Z)

	if lockedForward.Magnitude < 0.05 then
		lockedForward = Vector3.new(0, 0, -1)
	else
		lockedForward = lockedForward.Unit
	end

	local currentHitboxDirection = lockedForward

	local attachment = Instance.new("Attachment")
	attachment.Name = "KnifeDashVelocityAttachment"
	attachment.Parent = root

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "KnifeDashLinearVelocity"
	linearVelocity.Attachment0 = attachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.MaxForce = 100000
	linearVelocity.Parent = root

	Debris:AddItem(linearVelocity, 1.4)
	Debris:AddItem(attachment, 1.4)

	local function getSteeredDirection()
		local moveDirection = humanoid.MoveDirection
		local steerDirection = nil

		if moveDirection.Magnitude > 0.1 then
			local flatMove = Vector3.new(moveDirection.X, 0, moveDirection.Z)

			if flatMove.Magnitude > 0.05 then
				steerDirection = flatMove.Unit
			end
		end

		if not steerDirection then
			return lockedForward
		end

		local blended = (lockedForward * 0.55) + (steerDirection * 0.45)

		if blended.Magnitude < 0.05 then
			return lockedForward
		end

		return blended.Unit
	end

	local function cleanupDash()
		if linearVelocity then
			linearVelocity:Destroy()
			linearVelocity = nil
		end

		if attachment then
			attachment:Destroy()
			attachment = nil
		end

		playCharaMoveVFX("KnifeDashTrailStop")

		if root and root.Parent then
			local currentVelocity = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(0, currentVelocity.Y, 0)
		end
	end

	local function getDynamicOffset()
		local alpha = 0

		if dashDistance > 0 then
			alpha = math.clamp(traveled / dashDistance, 0, 1)
		end

		local startOffset = moveData.Hitbox.StartOffset or -7.5
		local endOffset = moveData.Hitbox.EndOffset or -22

		local zOffset = startOffset + ((endOffset - startOffset) * alpha)

		return CFrame.new(0, 0, zOffset)
	end

	local function stopDashAfterContact(result, targetRoot)
		finished = true

		if result == "Hit" or result == "ArmoredHit" then
			playCharaM1HitSFX(targetRoot)
		end

		cleanupDash()
		stopKnifeDashAnimation(moveData.AnimationCancelAfterHit or 0.25)

		if result == "Blocked" then
			print("[Chara] Knife Dash blocked")
			ctx:FinishMove(moveData.BlockEndlag or 0.14)
		elseif result == "Countered" then
			print("[Chara] Knife Dash countered")
			ctx:FinishMove(moveData.HitEndlag or 0.08)
		elseif result == "Guardbreak" then
			print("[Chara] Knife Dash guardbreak")
			ctx:FinishMove(moveData.HitEndlag or 0.08)
		else
			print("[Chara] Knife Dash hit")
			ctx:FinishMove(moveData.HitEndlag or 0.08)
		end
	end

	local function applyKnifeDashHit(targetCharacter, targetHumanoid, targetRoot)
		local result

		if ctx.ApplyStandardHit then
			result = ctx:ApplyStandardHit(
				targetCharacter,
				targetHumanoid,
				targetRoot,
				moveData,
				ctx.MoveId or "KnifeDash"
			)
		else
			result = ctx:DefaultApplyHit(targetCharacter, targetHumanoid, targetRoot)
		end

		if result == "IFrame" or result == "Invalid" then
			return false
		end

		if result == "Hit"
			or result == "ArmoredHit"
			or result == "Blocked"
			or result == "Guardbreak"
			or result == "Countered"
		then
			stopDashAfterContact(result, targetRoot)
			return true
		end

		return false
	end

	local function checkHitbox(dashDirection)
		if finished then return true end

		if not dashDirection or dashDirection.Magnitude < 0.05 then
			dashDirection = lockedForward
		else
			dashDirection = Vector3.new(dashDirection.X, 0, dashDirection.Z)

			if dashDirection.Magnitude < 0.05 then
				dashDirection = lockedForward
			else
				dashDirection = dashDirection.Unit
			end
		end

		local smoothed = (currentHitboxDirection * 0.55) + (dashDirection * 0.45)

		if smoothed.Magnitude > 0.05 then
			currentHitboxDirection = smoothed.Unit
		else
			currentHitboxDirection = dashDirection
		end

		local hitboxData = {
			Radius = moveData.Hitbox.Radius,
			Offset = getDynamicOffset(),
		}

		local didConnect = false

		local baseCFrame = CFrame.lookAt(
			root.Position,
			root.Position + currentHitboxDirection
		)

		ctx.HitboxService:PerformSphereAtCFrame(
			character,
			baseCFrame,
			hitboxData,
			function(targetCharacter, targetHumanoid, targetRoot)
				if didConnect then return end

				didConnect = applyKnifeDashHit(targetCharacter, targetHumanoid, targetRoot)
			end
		)

		return didConnect
	end

	checkHitbox(lockedForward)

	local connection
	connection = RunService.Heartbeat:Connect(function(deltaTime)
		if not ctx:IsActive() then
			if connection then
				connection:Disconnect()
			end

			cleanupDash()
			stopKnifeDashAnimation()
			return
		end

		if character:GetAttribute("Stunned") or character:GetAttribute("Guardbroken") then
			finished = true

			if connection then
				connection:Disconnect()
			end

			cleanupDash()
			stopKnifeDashAnimation()

			print("[Chara] Knife Dash interrupted during dash")

			ctx:FinishMove(0)
			return
		end

		if finished then
			if connection then
				connection:Disconnect()
			end

			cleanupDash()
			return
		end

		local direction = getSteeredDirection()

		if linearVelocity then
			linearVelocity.VectorVelocity = Vector3.new(
				direction.X * dashSpeed,
				0,
				direction.Z * dashSpeed
			)
		end

		local currentPosition = root.Position
		local flatDelta = Vector3.new(
			currentPosition.X - lastPosition.X,
			0,
			currentPosition.Z - lastPosition.Z
		)

		traveled += flatDelta.Magnitude
		lastPosition = currentPosition

		lastCheckTime += deltaTime

		if lastCheckTime >= checkInterval then
			lastCheckTime = 0

			if checkHitbox(direction) then
				return
			end
		end

		if traveled >= dashDistance then
			finished = true

			if connection then
				connection:Disconnect()
			end

			cleanupDash()
			stopKnifeDashAnimation()

			print("[Chara] Knife Dash whiffed")

			ctx:FinishMove(moveData.WhiffEndlag or 0.42)
		end
	end)

	task.delay(1.25, function()
		if finished then return end
		if not ctx:IsActive() then return end

		finished = true

		if connection then
			connection:Disconnect()
		end

		cleanupDash()
		stopKnifeDashAnimation()

		print("[Chara] Knife Dash timeout whiff")

		ctx:FinishMove(moveData.WhiffEndlag or 0.42)
	end)
end

return KnifeDash