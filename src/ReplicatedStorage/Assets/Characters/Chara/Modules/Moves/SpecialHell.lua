local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local SpecialHell = {
	DisplayName = "Special Hell",
	AnimationName = nil,

	Cooldown = 3,
	Duration = 8.5,
	LockTime = 8.5,
	MaxLockTime = 9,

	RequiresTarget = false,

	Damage = 999,
	AwardsUlt = false,
	Stun = 0,

	Radius = 7,
	Offset = CFrame.new(0, 0, -5),

	GrabActiveTime = 0.15,
	GrabTickRate = 0.03,
	WhiffEndlag = 0.22,

	ForwardDriftSpeed = 0,
	ForwardDriftMaxForce = 65000,

	CinematicDistance = 4.926,
	UseCinematicCamera = false,

	Blockable = false,
	CanBeBlocked = false,
	Unblockable = true,
	Guardbreak = true,
	CanBeCountered = false,

	CanGrabBlocking = true,
	CanGrabArmored = false,
	CanGrabIFrame = false,

	HitCancelsTarget = true,
	CancelableByHit = false,

	HasIFrames = true,
	IFrameStart = 0,
	IFrameEnd = 8.5,

	HasArmor = true,
	ArmorStart = 0,
	ArmorEnd = 8.5,
	ArmorDamageReduction = 1,
	ArmorPreventsStun = true,
	ArmorPreventsKnockback = true,
	ArmorPreventsHitCancel = true,

	-- Bigger Special Hell pillar polish.
	HellWarningSize = Vector3.new(30, 0.18, 30),
	HellBeamStartSize = Vector3.new(13, 1, 13),
	HellBeamFinalSize = Vector3.new(27, 120, 27),
	HellBeamHeight = 60,

	-- Impact polish.
	HellAttackerShakeMagnitude = 4.2,
	HellAttackerShakeRoughness = 20,
	HellAttackerShakeDuration = 0.65,

	HellVictimShakeMagnitude = 5.2,
	HellVictimShakeRoughness = 24,
	HellVictimShakeDuration = 0.75,

	HellRadiusShakeMagnitude = 2.8,
	HellRadiusShakeRoughness = 16,
	HellRadiusShakeDuration = 0.55,
	HellRadiusShakeRange = 95,

	HellImpactFrameDuration = 0.12,
}

local STARTUP_ANIMATIONS = { "SpecialHellGrab", "UltGrab" }
local ATTACKER_ANIMATIONS = { "SpecialHellAttacker", "UltGrabAttacker" }
local VICTIM_ANIMATIONS = { "SpecialHellVictim", "UltGrabVictim" }

local GRAB_MARKER = "Grab"
local HELL_MARKER = "Hell"

local function setUltimateDashLock(character, enabled)
	if not character or not character.Parent then
		return
	end

	character:SetAttribute("DashLocked", enabled == true)
	character:SetAttribute("UltimateLocked", enabled == true)
end

local function reportDamage(ctx, targetCharacter, targetRoot, damage)
	if not ctx or not targetCharacter then
		return
	end

	if typeof(damage) ~= "number" or damage <= 0 then
		return
	end

	local moveData = ctx.MoveData
	local awardsUlt = true

	if moveData and moveData.AwardsUlt == false then
		awardsUlt = false
	end

	if awardsUlt then
		if ctx.ReportDamageEvent then
			ctx:ReportDamageEvent(targetCharacter, damage, targetRoot)
		elseif ctx.UltService and ctx.UltService.AwardDamageEvent then
			ctx.UltService:AwardDamageEvent(ctx.Character, targetCharacter, damage)
		end

		return
	end

	if ctx.ReportNoUltDamage then
		ctx:ReportNoUltDamage(targetCharacter, targetRoot, damage)
		return
	end

	if ctx.GrabService and ctx.GrabService.ReportNoUltDamage then
		ctx.GrabService:ReportNoUltDamage(ctx.Character, targetCharacter, targetRoot, damage)
		return
	end

	if ctx.DamageNumberService and targetRoot then
		ctx.DamageNumberService:ShowDamage(targetRoot, damage, {
			TextSize = 56,
		})
	end

	local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")

	if humanoid and humanoid.Health <= 0 then
		if ctx.ProgressionService and ctx.ProgressionService.AwardKill then
			ctx.ProgressionService:AwardKill(ctx.Character, targetCharacter)
		elseif ctx.UltService
			and ctx.UltService.ProgressionService
			and ctx.UltService.ProgressionService.AwardKill
		then
			ctx.UltService.ProgressionService:AwardKill(ctx.Character, targetCharacter)
		end
	end
end

local function getFirstUsableAnimationName(ctx, character, names)
	if not ctx.StateService or not ctx.StateService.AnimationService then
		return nil
	end

	local animationService = ctx.StateService.AnimationService
	local characterName = animationService:GetCharacterNameFromCharacter(character)
	local defaultCharacterName = animationService.Config.DefaultCharacterName or "Chara"

	for _, animationName in ipairs(names) do
		local animation = animationService:GetCharacterAnimation(characterName, animationName)

		if animation and animationService:IsAnimationUsable(animation) then
			return animationName
		end

		if not animation and characterName ~= defaultCharacterName then
			local fallbackAnimation = animationService:GetCharacterAnimation(defaultCharacterName, animationName)

			if fallbackAnimation and animationService:IsAnimationUsable(fallbackAnimation) then
				return animationName
			end
		end
	end

	return nil
end

local function playFirstAnimation(ctx, character, names, fadeTime, speed, looped)
	if not ctx.StateService or not ctx.StateService.AnimationService then
		return nil, nil
	end

	local animationName = getFirstUsableAnimationName(ctx, character, names)

	if not animationName then
		return nil, nil
	end

	local track = ctx.StateService.AnimationService:PlayCharacterAnimation(
		character,
		animationName,
		fadeTime or 0.05,
		1,
		speed or 1,
		true
	)

	if track then
		track.Looped = looped == true
		return track, animationName
	end

	return nil, nil
end

local function stopAnimation(ctx, character, animationNames, fadeTime)
	if not ctx.StateService or not ctx.StateService.AnimationService then
		return
	end

	if not ctx.StateService.AnimationService.StopCharacterAnimationByName then
		return
	end

	for _, animationName in ipairs(animationNames) do
		ctx.StateService.AnimationService:StopCharacterAnimationByName(character, animationName, fadeTime or 0.08)
	end
end

local function getKnifePart(character)
	if not character then
		return nil
	end

	local equippedWeapons = character:FindFirstChild("EquippedWeapons")

	if equippedWeapons then
		local equippedKnife = equippedWeapons:FindFirstChild("RealKnife", true)

		if equippedKnife then
			if equippedKnife:IsA("BasePart") then
				return equippedKnife
			end

			if equippedKnife:IsA("Model") then
				if equippedKnife.PrimaryPart then
					return equippedKnife.PrimaryPart
				end

				local handle = equippedKnife:FindFirstChild("Handle", true)
				if handle and handle:IsA("BasePart") then
					return handle
				end

				return equippedKnife:FindFirstChildWhichIsA("BasePart", true)
			end
		end
	end

	local realKnife = character:FindFirstChild("RealKnife", true)

	if realKnife then
		if realKnife:IsA("BasePart") then
			return realKnife
		end

		if realKnife:IsA("Model") then
			if realKnife.PrimaryPart then
				return realKnife.PrimaryPart
			end

			local primary = realKnife:FindFirstChild("PrimaryPart", true)
			if primary and primary:IsA("BasePart") then
				return primary
			end

			local handle = realKnife:FindFirstChild("Handle", true)
			if handle and handle:IsA("BasePart") then
				return handle
			end

			return realKnife:FindFirstChildWhichIsA("BasePart", true)
		end
	end

	local knife = character:FindFirstChild("Knife", true)

	if knife then
		if knife:IsA("BasePart") then
			return knife
		end

		if knife:IsA("Model") then
			if knife.PrimaryPart then
				return knife.PrimaryPart
			end

			return knife:FindFirstChildWhichIsA("BasePart", true)
		end
	end

	return nil
end

local function setKnifeCollision(character, enabled)
	if not character then
		return
	end

	local function applyToObject(object)
		if not object then
			return
		end

		if object:IsA("BasePart") then
			object.Anchored = false
			object.CanCollide = enabled == true
			object.CanTouch = false
			object.CanQuery = false
			object.Massless = true
			return
		end

		for _, descendant in ipairs(object:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Anchored = false
				descendant.CanCollide = enabled == true
				descendant.CanTouch = false
				descendant.CanQuery = false
				descendant.Massless = true
			end
		end
	end

	applyToObject(character:FindFirstChild("EquippedWeapons"))
	applyToObject(character:FindFirstChild("RealKnife", true))
	applyToObject(character:FindFirstChild("Knife", true))
end

local function forceKnifeCollisionOffForAWhile(character, duration)
	duration = duration or 1

	setKnifeCollision(character, false)

	task.spawn(function()
		local startTime = os.clock()

		while character and character.Parent and os.clock() - startTime < duration do
			setKnifeCollision(character, false)
			task.wait(0.1)
		end
	end)
end

local function getSpecialHellOriginCFrame(character, fallbackRoot)
	local knifePart = getKnifePart(character)

	if knifePart then
		return knifePart.CFrame
	end

	if fallbackRoot then
		return fallbackRoot.CFrame
	end

	return CFrame.new()
end

local function getGroundPositionFromOrigin(character, victimCharacter, originCFrame)
	local originPosition = originCFrame.Position
	local rayOrigin = originPosition + Vector3.new(0, 6, 0)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	local excludeList = {}

	if character then
		table.insert(excludeList, character)
	end

	if victimCharacter then
		table.insert(excludeList, victimCharacter)
	end

	params.FilterDescendantsInstances = excludeList

	local result = workspace:Raycast(rayOrigin, Vector3.new(0, -70, 0), params)

	if result then
		return result.Position + Vector3.new(0, 0.08, 0)
	end

	return originPosition - Vector3.new(0, 2.7, 0)
end

local function positionVictimForGrab(attackerRoot, victimRoot, distance)
	if not attackerRoot or not victimRoot then
		return
	end

	distance = distance or 4.926

	local attackerPosition = attackerRoot.Position
	local forward = attackerRoot.CFrame.LookVector
	local victimPosition = attackerPosition + (forward * distance)

	victimRoot.AssemblyLinearVelocity = Vector3.zero
	victimRoot.AssemblyAngularVelocity = Vector3.zero

	victimRoot.CFrame = CFrame.lookAt(
		victimPosition,
		Vector3.new(attackerPosition.X, victimPosition.Y, attackerPosition.Z)
	)
end

local function lockGrabAttacker(character, humanoid, root, duration)
	if not character or not character.Parent then
		return nil
	end

	if not humanoid or not humanoid.Parent then
		return nil
	end

	local oldState = {
		WalkSpeed = humanoid.WalkSpeed,
		JumpPower = humanoid.JumpPower,
		JumpHeight = humanoid.JumpHeight,
		AutoRotate = humanoid.AutoRotate,
		JumpEnabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping),
		RootAnchored = root and root.Anchored or false,
	}

	character:SetAttribute("Grabbing", true)
	character:SetAttribute("CinematicLocked", true)
	character:SetAttribute("MovementLocked", true)
	character:SetAttribute("DashLocked", true)
	character:SetAttribute("UltimateLocked", true)
	character:SetAttribute("Attacking", true)
	character:SetAttribute("UsingMove", true)
	character:SetAttribute("JumpLockedUntil", os.clock() + (duration or 8.5))

	humanoid.WalkSpeed = 0
	humanoid.Jump = false
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoRotate = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.Anchored = true
	end

	return oldState
end

local function unlockGrabAttacker(character, humanoid, root, oldState)
	if not oldState then
		return
	end

	if character and character.Parent then
		character:SetAttribute("Grabbing", false)
		character:SetAttribute("CinematicLocked", false)
		character:SetAttribute("MovementLocked", false)
		character:SetAttribute("DashLocked", false)
		character:SetAttribute("UltimateLocked", false)
		character:SetAttribute("Attacking", false)
		character:SetAttribute("UsingMove", false)
	end

	if root and root.Parent then
		root.Anchored = oldState.RootAnchored == true
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end

	if humanoid and humanoid.Parent and humanoid.Health > 0 then
		humanoid.WalkSpeed = oldState.WalkSpeed or 16
		humanoid.JumpPower = oldState.JumpPower or 50
		humanoid.JumpHeight = oldState.JumpHeight or 7.2
		humanoid.AutoRotate = oldState.AutoRotate ~= false
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, oldState.JumpEnabled ~= false)
	end
end

local function lockGrabVictim(ctx, victimCharacter, victimHumanoid, duration)
	if not victimCharacter or not victimCharacter.Parent then
		return
	end

	if not victimHumanoid or not victimHumanoid.Parent then
		return
	end

	victimCharacter:SetAttribute("Grabbed", true)
	victimCharacter:SetAttribute("CinematicLocked", true)
	victimCharacter:SetAttribute("Stunned", true)
	victimCharacter:SetAttribute("Blocking", false)
	victimCharacter:SetAttribute("Attacking", false)
	victimCharacter:SetAttribute("UsingMove", true)
	victimCharacter:SetAttribute("MovementLocked", true)
	victimCharacter:SetAttribute("DashLocked", true)
	victimCharacter:SetAttribute("JumpLockedUntil", os.clock() + (duration or 8.5))

	victimHumanoid.WalkSpeed = 0
	victimHumanoid.Jump = false
	victimHumanoid.JumpPower = 0
	victimHumanoid.JumpHeight = 0
	victimHumanoid.AutoRotate = false
	victimHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	if ctx.StateService and ctx.StateService.StunCharacter then
		ctx.StateService:StunCharacter(victimCharacter, duration or 8.5)
	end
end

local function unlockGrabVictim(victimCharacter, victimHumanoid, oldVictimState)
	if victimCharacter and victimCharacter.Parent then
		victimCharacter:SetAttribute("Grabbed", false)
		victimCharacter:SetAttribute("CinematicLocked", false)
		victimCharacter:SetAttribute("Stunned", false)
		victimCharacter:SetAttribute("UsingMove", false)
		victimCharacter:SetAttribute("MovementLocked", false)
		victimCharacter:SetAttribute("DashLocked", false)
	end

	if victimHumanoid and victimHumanoid.Parent and victimHumanoid.Health > 0 and oldVictimState then
		victimHumanoid.WalkSpeed = oldVictimState.WalkSpeed
		victimHumanoid.JumpPower = oldVictimState.JumpPower
		victimHumanoid.JumpHeight = oldVictimState.JumpHeight
		victimHumanoid.AutoRotate = oldVictimState.AutoRotate
		victimHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	end
end

local function playImpactFrame(ctx, targetCharacter, duration)
	if not ctx.CinematicService then
		return
	end
	if not targetCharacter or not targetCharacter.Parent then
		return
	end
	if not ctx.CinematicService.ImpactFrame then
		return
	end

	local success = pcall(function()
		ctx.CinematicService:ImpactFrame(targetCharacter, "RedBlack", nil, nil, nil, duration)
	end)

	if success then
		return
	end

	pcall(function()
		ctx.CinematicService:ImpactFrame(targetCharacter, duration)
	end)
end

local function playHellScreenShake(ctx, victimCharacter, groundPosition)
	local character = ctx.Character
	local moveData = ctx.MoveData

	if not ctx.CinematicService then
		return
	end

	if ctx.CinematicService.ShakeOnce then
		if character and character.Parent then
			pcall(function()
				ctx.CinematicService:ShakeOnce(
					character,
					moveData.HellAttackerShakeMagnitude or 4.2,
					moveData.HellAttackerShakeRoughness or 20,
					moveData.HellAttackerShakeDuration or 0.65
				)
			end)
		end

		if victimCharacter and victimCharacter.Parent then
			pcall(function()
				ctx.CinematicService:ShakeOnce(
					victimCharacter,
					moveData.HellVictimShakeMagnitude or 5.2,
					moveData.HellVictimShakeRoughness or 24,
					moveData.HellVictimShakeDuration or 0.75
				)
			end)
		end
	end

	if ctx.CinematicService.ShakeRadius and typeof(groundPosition) == "Vector3" then
		pcall(function()
			ctx.CinematicService:ShakeRadius(
				groundPosition,
				moveData.HellRadiusShakeRange or 95,
				moveData.HellRadiusShakeMagnitude or 2.8,
				moveData.HellRadiusShakeRoughness or 16,
				moveData.HellRadiusShakeDuration or 0.55,
				{
					ExcludeCharacters = {
						character,
						victimCharacter,
					},
				}
			)
		end)
	end
end

local function playSpecialHellVFX(ctx, victimCharacter, victimRoot)
	local character = ctx.Character
	local root = ctx.Root
	local moveData = ctx.MoveData

	local originCFrame = getSpecialHellOriginCFrame(character, root)
	local groundPosition = getGroundPositionFromOrigin(character, victimCharacter, originCFrame)

	local warning = Instance.new("Part")
	warning.Name = "SpecialHellWarning"
	warning.Anchored = true
	warning.CanCollide = false
	warning.CanTouch = false
	warning.CanQuery = false
	warning.Material = Enum.Material.Neon
	warning.Color = Color3.fromRGB(255, 0, 0)
	warning.Transparency = 0.32
	warning.Size = Vector3.new(2, 0.18, 2)
	warning.CFrame = CFrame.new(groundPosition)
	warning.Parent = workspace

	TweenService:Create(warning, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = moveData.HellWarningSize or Vector3.new(30, 0.18, 30),
		Transparency = 0.18,
	}):Play()

	task.delay(0.3, function()
		if not warning or not warning.Parent then
			return
		end

		local beamFinalSize = moveData.HellBeamFinalSize or Vector3.new(27, 120, 27)
		local beamHeight = moveData.HellBeamHeight or (beamFinalSize.Y / 2)

		local beam = Instance.new("Part")
		beam.Name = "SpecialHellBeam"
		beam.Anchored = true
		beam.CanCollide = false
		beam.CanTouch = false
		beam.CanQuery = false
		beam.Material = Enum.Material.Neon
		beam.Color = Color3.fromRGB(255, 0, 0)
		beam.Transparency = 0.08
		beam.Size = moveData.HellBeamStartSize or Vector3.new(13, 1, 13)
		beam.CFrame = CFrame.new(groundPosition + Vector3.new(0, 0.5, 0))
		beam.Parent = workspace

		local growTween =
			TweenService:Create(beam, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Size = beamFinalSize,
				CFrame = CFrame.new(groundPosition + Vector3.new(0, beamHeight, 0)),
			})

		growTween:Play()

		task.spawn(function()
			local startTime = os.clock()

			while beam and beam.Parent and os.clock() - startTime < 0.55 do
				beam.CFrame *= CFrame.Angles(0, math.rad(18), 0)
				task.wait()
			end
		end)

		task.delay(0.55, function()
			if beam and beam.Parent then
				TweenService:Create(beam, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Transparency = 1,
					Size = Vector3.new(5, beamFinalSize.Y, 5),
				}):Play()
			end
		end)

		Debris:AddItem(beam, 0.9)
	end)

	Debris:AddItem(warning, 0.95)

	return groundPosition
end

function SpecialHell.Execute(ctx)
	print("[SpecialHell] Execute started")

	local character = ctx.Character
	local humanoid = ctx.Humanoid
	local root = ctx.Root
	local moveData = ctx.MoveData

	if not character or not character.Parent or not humanoid or humanoid.Health <= 0 or not root then
		ctx:FinishMove(0)
		return
	end

	-- Dash lock starts immediately, even before the grab confirms.
	setUltimateDashLock(character, true)

	forceKnifeCollisionOffForAWhile(character, 0.5)

	if ctx.VFXService and ctx.VFXService.PlayCharacterSFXAtPart then
		ctx.VFXService:PlayCharacterSFXAtPart("Chara", "CharaScare", root, 3)
	end

	if ctx.VFXService and ctx.VFXService.PlayCharacterMoveVFX then
		ctx.VFXService:PlayCharacterMoveVFX(character, "SpecialHellStart")
	end

	local finished = false
	local confirmed = false
	local hellResolved = false
	local markerConnections = {}
	local driftCleanup = nil
	local attackerTrack = nil
	local victimTrack = nil
	local victimCharacter = nil
	local victimHumanoid = nil
	local victimRoot = nil
	local oldVictimState = nil
	local attackerGrabState = nil

	local function addConnection(connection)
		if connection then
			table.insert(markerConnections, connection)
		end
	end

	local function disconnectAll()
		for _, connection in ipairs(markerConnections) do
			connection:Disconnect()
		end

		markerConnections = {}
	end

	local function clearTempStatus(targetCharacter)
		if not targetCharacter then
			return
		end

		if ctx.CombatStatusService and ctx.CombatStatusService.ClearTemporaryCombatStatus then
			ctx.CombatStatusService:ClearTemporaryCombatStatus(targetCharacter)
		elseif ctx.CinematicService and ctx.CinematicService.ClearTemporaryCombatStatus then
			ctx.CinematicService:ClearTemporaryCombatStatus(targetCharacter)
		end
	end

	local function cleanup()
		if finished then
			return
		end

		finished = true

		disconnectAll()

		if driftCleanup then
			driftCleanup()
			driftCleanup = nil
		end

		stopAnimation(ctx, character, STARTUP_ANIMATIONS, 0.05)

		if attackerTrack and attackerTrack.IsPlaying then
			attackerTrack:Stop(0.08)
		end

		if victimTrack and victimTrack.IsPlaying then
			victimTrack:Stop(0.08)
		end

		if attackerGrabState then
			unlockGrabAttacker(character, humanoid, root, attackerGrabState)
			attackerGrabState = nil
		else
			-- If the grab never confirmed, unlock the startup dash lock here.
			setUltimateDashLock(character, false)
		end

		if character and character.Parent then
			clearTempStatus(character)
			forceKnifeCollisionOffForAWhile(character, 1.5)
		end

		if victimCharacter and victimCharacter.Parent then
			if ctx.CombatStatusService and ctx.CombatStatusService.ClearDamageLock then
				ctx.CombatStatusService:ClearDamageLock(victimCharacter, character)
			end

			victimCharacter:SetAttribute("Grabbed", false)
			victimCharacter:SetAttribute("CinematicLocked", false)

			clearTempStatus(victimCharacter)
		end

		if oldVictimState and ctx.GrabService and ctx.GrabService.UnlockCharacter then
			ctx.GrabService:UnlockCharacter(oldVictimState)
		elseif victimCharacter and victimHumanoid and oldVictimState then
			unlockGrabVictim(victimCharacter, victimHumanoid, oldVictimState)
		end
	end

	local function finish(delayTime)
		cleanup()
		ctx:FinishMove(delayTime or 0)
	end

	local function doHell()
		if hellResolved then
			return
		end

		if not victimCharacter or not victimHumanoid or not victimRoot then
			return
		end

		if not victimCharacter.Parent or victimHumanoid.Health <= 0 then
			return
		end

		hellResolved = true

		print("[SpecialHell] Hell marker")

		local groundPosition = playSpecialHellVFX(ctx, victimCharacter, victimRoot)

		playHellScreenShake(ctx, victimCharacter, groundPosition)

		if ctx.CinematicService then
			local impactDuration = moveData.HellImpactFrameDuration or 0.12

			playImpactFrame(ctx, character, impactDuration)
			playImpactFrame(ctx, victimCharacter, impactDuration)
		end

		local damage = moveData.Damage or 999

		if not ctx.CombatStatusService
			or not ctx.CombatStatusService:IsDamageLockedFromAttacker(victimCharacter, character)
		then
			victimHumanoid:TakeDamage(damage)
			reportDamage(ctx, victimCharacter, victimRoot, damage)
		end
	end

	local function setTempStatus(targetCharacter, statusData)
		if ctx.CombatStatusService and ctx.CombatStatusService.SetTemporaryCombatStatus then
			ctx.CombatStatusService:SetTemporaryCombatStatus(targetCharacter, statusData)
		elseif ctx.CinematicService and ctx.CinematicService.SetTemporaryCombatStatus then
			ctx.CinematicService:SetTemporaryCombatStatus(targetCharacter, statusData)
		end
	end

	local function playConfirmedCinematic()
		confirmed = true

		forceKnifeCollisionOffForAWhile(character, moveData.Duration or 8.5)

		if driftCleanup then
			driftCleanup()
			driftCleanup = nil
		end

		stopAnimation(ctx, character, STARTUP_ANIMATIONS, 0.04)

		attackerGrabState = lockGrabAttacker(character, humanoid, root, moveData.Duration or 8.5)

		if ctx.GrabService and ctx.GrabService.LockCharacter then
			oldVictimState = ctx.GrabService:LockCharacter(victimCharacter, {
				Duration = moveData.Duration or 8.5,
				AttackerCharacter = character,
				DamageLock = true,
				IFrameActive = true,
				ArmorActive = true,
				ArmorDamageReduction = 1,
				CancelCurrentMove = true,
				ClearCombatMovement = true,
			})
		else
			oldVictimState = {
				WalkSpeed = victimHumanoid.WalkSpeed,
				JumpPower = victimHumanoid.JumpPower,
				JumpHeight = victimHumanoid.JumpHeight,
				AutoRotate = victimHumanoid.AutoRotate,
			}

			lockGrabVictim(ctx, victimCharacter, victimHumanoid, moveData.Duration or 8.5)
		end

		setTempStatus(character, {
			IFrameActive = true,
			ArmorActive = true,
			ArmorDamageReduction = 1,
			ArmorPreventsStun = true,
			ArmorPreventsKnockback = true,
			ArmorPreventsHitCancel = true,
		})

		setTempStatus(victimCharacter, {
			IFrameActive = true,
			ArmorActive = true,
			ArmorDamageReduction = 1,
			ArmorPreventsStun = true,
			ArmorPreventsKnockback = true,
			ArmorPreventsHitCancel = true,
		})

		positionVictimForGrab(root, victimRoot, moveData.CinematicDistance or 4.926)

		attackerTrack = select(1, playFirstAnimation(ctx, character, ATTACKER_ANIMATIONS, 0.03, 1, false))
		victimTrack = select(1, playFirstAnimation(ctx, victimCharacter, VICTIM_ANIMATIONS, 0.03, 1, false))

		if attackerTrack then
			addConnection(attackerTrack:GetMarkerReachedSignal(HELL_MARKER):Connect(doHell))

			addConnection(attackerTrack.Ended:Connect(function()
				if not hellResolved then
					doHell()
				end

				finish(0)
			end))

			addConnection(attackerTrack.Stopped:Connect(function()
				if not finished then
					if not hellResolved then
						doHell()
					end

					finish(0)
				end
			end))
		else
			warn("[SpecialHell] Missing attacker animation")

			task.delay(1.2, function()
				if not finished then
					doHell()
					finish(0.2)
				end
			end)
		end
	end

	local function tryConfirmGrab(targetCharacter, targetHumanoid, targetRoot)
		if confirmed or finished then
			return false
		end

		if ctx.CinematicService
			and ctx.CinematicService.IsValidGrabTarget
			and not ctx.CinematicService:IsValidGrabTarget(ctx, targetCharacter, targetHumanoid, targetRoot, moveData)
		then
			return false
		end

		if ctx.CombatStatusService
			and ctx.CombatStatusService:IsDamageLockedFromAttacker(targetCharacter, character)
		then
			return false
		end

		if ctx.CombatStatusService and ctx.CombatStatusService.TryHitCancelTarget then
			ctx.CombatStatusService:TryHitCancelTarget(targetCharacter, moveData)
		end

		victimCharacter = targetCharacter
		victimHumanoid = targetHumanoid
		victimRoot = targetRoot

		if ctx.CombatStatusService and ctx.CombatStatusService.SetDamageLock then
			ctx.CombatStatusService:SetDamageLock(victimCharacter, character, moveData.Duration or 8.5)
		end

		print("[SpecialHell] Grab confirmed:", targetCharacter.Name)

		playConfirmedCinematic()

		return true
	end

	setTempStatus(character, {
		IFrameActive = true,
		ArmorActive = true,
		ArmorDamageReduction = moveData.ArmorDamageReduction or 1,
		ArmorPreventsStun = true,
		ArmorPreventsKnockback = true,
		ArmorPreventsHitCancel = true,
	})

	local startupTrack = select(1, playFirstAnimation(ctx, character, STARTUP_ANIMATIONS, 0.04, 1, false))

	if not startupTrack then
		warn("[SpecialHell] Missing startup animation")
		clearTempStatus(character)
		setUltimateDashLock(character, false)
		ctx:FinishMove(0)
		return
	end

	if ctx.CinematicService and ctx.CinematicService.StartForwardDrift then
		driftCleanup = ctx.CinematicService:StartForwardDrift(
			root,
			moveData.ForwardDriftSpeed or 8,
			moveData.ForwardDriftMaxForce or 65000
		)
	end

	local grabMarkerReached = false

	addConnection(startupTrack:GetMarkerReachedSignal(GRAB_MARKER):Connect(function()
		if finished or confirmed then
			return
		end

		if not ctx:IsActive() then
			finish(0)
			return
		end

		grabMarkerReached = true

		local hitOnce = false
		local startTime = os.clock()

		while
			ctx:IsActive()
			and not finished
			and not confirmed
			and os.clock() - startTime < (moveData.GrabActiveTime or 0.15)
		do
			ctx.HitboxService:PerformSphereAtCFrame(character, root.CFrame, {
				Radius = moveData.Radius or 7,
				Offset = moveData.Offset or CFrame.new(0, 0, -5),
			}, function(targetCharacter, targetHumanoid, targetRoot)
				if hitOnce then
					return
				end

				hitOnce = tryConfirmGrab(targetCharacter, targetHumanoid, targetRoot)
			end)

			task.wait(moveData.GrabTickRate or 0.03)
		end

		if not confirmed and not finished then
			print("[SpecialHell] Whiffed")
			finish(moveData.WhiffEndlag or 0.22)
		end
	end))

	addConnection(startupTrack.Ended:Connect(function()
		if finished or confirmed then
			return
		end

		if not grabMarkerReached then
			warn("[SpecialHell] Startup ended before Grab marker")
		end

		finish(moveData.WhiffEndlag or 0.22)
	end))

	task.delay(moveData.MaxLockTime or 9, function()
		if not finished then
			warn("[SpecialHell] Failsafe cleanup")
			finish(0)
		end
	end)
end

return SpecialHell