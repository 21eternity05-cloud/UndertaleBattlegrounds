local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local SpecialHell = {
	DisplayName = "Special Hell",
	AnimationName = nil,

	Cooldown = 1,
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

	ForwardDriftSpeed = 8,
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

	HellWarningSize = Vector3.new(23, 0.18, 23),
	HellBeamStartSize = Vector3.new(9, 1, 9),
	HellBeamFinalSize = Vector3.new(18, 95, 18),
	HellBeamHeight = 47.5,
}

local STARTUP_ANIMATIONS = { "SpecialHellGrab", "UltGrab" }
local ATTACKER_ANIMATIONS = { "SpecialHellAttacker", "UltGrabAttacker" }
local VICTIM_ANIMATIONS = { "SpecialHellVictim", "UltGrabVictim" }

local GRAB_MARKER = "Grab"
local HELL_MARKER = "Hell"

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
		elseif ctx.UltService and ctx.UltService.ProgressionService and ctx.UltService.ProgressionService.AwardKill then
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

	local handle = character:FindFirstChild("Handle", true)
	if handle and handle:IsA("BasePart") then
		return handle
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

	if victimHumanoid and victimHumanoid.Parent and victimHumanoid.Health > 0 then
		victimHumanoid.WalkSpeed = oldVictimState.WalkSpeed
		victimHumanoid.JumpPower = oldVictimState.JumpPower
		victimHumanoid.JumpHeight = oldVictimState.JumpHeight
		victimHumanoid.AutoRotate = oldVictimState.AutoRotate
		victimHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
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
		Size = moveData.HellWarningSize or Vector3.new(23, 0.18, 23),
		Transparency = 0.18,
	}):Play()

	task.delay(0.3, function()
		if not warning or not warning.Parent then
			return
		end

		local beamFinalSize = moveData.HellBeamFinalSize or Vector3.new(18, 95, 18)
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
		beam.Size = moveData.HellBeamStartSize or Vector3.new(9, 1, 9)
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
					Size = Vector3.new(4, beamFinalSize.Y, 4),
				}):Play()
			end
		end)

		Debris:AddItem(beam, 0.9)
	end)

	Debris:AddItem(warning, 0.95)
end

function SpecialHell.Execute(ctx)
	print("[SpecialHell] Execute started")

	local cinematicService = ctx.CinematicService
	if not cinematicService then
		warn("[SpecialHell] Missing CinematicService")
		ctx:FinishMove(0)
		return
	end

	local character = ctx.Character
	local humanoid = ctx.Humanoid
	local root = ctx.Root
	local moveData = ctx.MoveData

	if not character or not character.Parent or not humanoid or humanoid.Health <= 0 or not root then
		ctx:FinishMove(0)
		return
	end

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
	local attackerLockState = nil
	local victimLockState = nil
	local driftCleanup = nil
	local attackerTrack = nil
	local victimTrack = nil
	local victimCharacter = nil
	local victimHumanoid = nil
	local victimRoot = nil
	local oldVictimState = nil

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

		if attackerLockState then
			cinematicService:UnlockCharacter(attackerLockState)
			attackerLockState = nil
		end

		if victimLockState then
			cinematicService:UnlockCharacter(victimLockState)
			victimLockState = nil
		end

		if character and character.Parent then
			character:SetAttribute("Grabbing", false)
			character:SetAttribute("CinematicLocked", false)
			cinematicService:ClearTemporaryCombatStatus(character)
		end

		if victimCharacter and victimCharacter.Parent then
			if ctx.CombatStatusService then
				ctx.CombatStatusService:ClearDamageLock(victimCharacter, character)
			end

			victimCharacter:SetAttribute("Grabbed", false)
			victimCharacter:SetAttribute("CinematicLocked", false)
			cinematicService:ClearTemporaryCombatStatus(victimCharacter)
		end

		if oldVictimState and ctx.GrabService and ctx.GrabService.UnlockCharacter then
			ctx.GrabService:UnlockCharacter(oldVictimState)
		elseif victimCharacter and victimHumanoid and oldVictimState then
			unlockGrabVictim(victimCharacter, victimHumanoid, oldVictimState)
		end

		cinematicService:ResetCamera(character)

		if victimCharacter then
			cinematicService:ResetCamera(victimCharacter)
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

		playSpecialHellVFX(ctx, victimCharacter, victimRoot)

		cinematicService:ShakeOnce(character, 2.4, 10, 0.35)
		cinematicService:ShakeOnce(victimCharacter, 2.4, 10, 0.35)
		cinematicService:ImpactFrame(character, "RedBlack", nil, nil, nil, 0.08)
		cinematicService:ImpactFrame(victimCharacter, "RedBlack", nil, nil, nil, 0.08)

		local damage = moveData.Damage or 999

		if not ctx.CombatStatusService
			or not ctx.CombatStatusService:IsDamageLockedFromAttacker(victimCharacter, character)
		then
			victimHumanoid:TakeDamage(damage)
			reportDamage(ctx, victimCharacter, victimRoot, damage)
		end
	end

	local function playConfirmedCinematic()
		confirmed = true

		if driftCleanup then
			driftCleanup()
			driftCleanup = nil
		end

		stopAnimation(ctx, character, STARTUP_ANIMATIONS, 0.04)

		if ctx.GrabService and ctx.GrabService.LockCharacter then
			oldVictimState = ctx.GrabService:LockCharacter(victimCharacter, {
				Duration = moveData.Duration or 8.5,
				AttackerCharacter = character,
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

		lockGrabVictim(ctx, victimCharacter, victimHumanoid, moveData.Duration or 8.5)

		attackerLockState = cinematicService:LockCharacter(character, {
			AnchorRoot = true,
			DisableCollision = true,
			IsGrabber = true,
		})

		victimLockState = cinematicService:LockCharacter(victimCharacter, {
			AnchorRoot = true,
			DisableCollision = true,
			IsVictim = true,
		})

		cinematicService:SetTemporaryCombatStatus(character, {
			IFrameActive = true,
			ArmorActive = true,
			ArmorDamageReduction = 1,
			ArmorPreventsStun = true,
			ArmorPreventsKnockback = true,
			ArmorPreventsHitCancel = true,
		})

		cinematicService:SetTemporaryCombatStatus(victimCharacter, {
			IFrameActive = true,
			ArmorActive = true,
			ArmorDamageReduction = 1,
			ArmorPreventsStun = true,
			ArmorPreventsKnockback = true,
			ArmorPreventsHitCancel = true,
		})

		cinematicService:PositionVictimInFront(root, victimRoot, moveData.CinematicDistance or 4.926)

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

		if not cinematicService:IsValidGrabTarget(ctx, targetCharacter, targetHumanoid, targetRoot, moveData) then
			return false
		end

		if ctx.CombatStatusService
			and ctx.CombatStatusService:IsDamageLockedFromAttacker(targetCharacter, character)
		then
			return false
		end

		if ctx.CombatStatusService then
			ctx.CombatStatusService:TryHitCancelTarget(targetCharacter, moveData)
		end

		victimCharacter = targetCharacter
		victimHumanoid = targetHumanoid
		victimRoot = targetRoot

		if ctx.CombatStatusService then
			ctx.CombatStatusService:SetDamageLock(victimCharacter, character, moveData.Duration or 8.5)
		end

		print("[SpecialHell] Grab confirmed:", targetCharacter.Name)
		playConfirmedCinematic()

		return true
	end

	cinematicService:SetTemporaryCombatStatus(character, {
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
		cinematicService:ClearTemporaryCombatStatus(character)
		ctx:FinishMove(0)
		return
	end

	driftCleanup = cinematicService:StartForwardDrift(
		root,
		moveData.ForwardDriftSpeed or 8,
		moveData.ForwardDriftMaxForce or 65000
	)

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
