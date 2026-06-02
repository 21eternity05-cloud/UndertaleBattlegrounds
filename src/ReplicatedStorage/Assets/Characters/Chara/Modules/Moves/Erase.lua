local Erase = {
	DisplayName = "Erased",
	AnimationName = nil,

	Cooldown = 1,
	Duration = 8.5,
	LockTime = 8.5,
	MaxLockTime = 9,

	RequiresTarget = false,

	Damage = 100,
	Stun = 0,

	Radius = 7,
	Offset = CFrame.new(0, 0, -5),

	GrabActiveTime = 0.15,
	GrabTickRate = 0.03,
	WhiffEndlag = 0.22,

	ForwardDriftSpeed = 8,
	ForwardDriftMaxForce = 65000,

	CinematicDistance = 3.8,
	FirstSlashBehindDistance = 3.5,

	-- Toggle this off while testing animations/positioning.
	UseCinematicCamera = false,

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
	ArmorEnd = 1.35,
	ArmorDamageReduction = 0.5,
	ArmorPreventsStun = true,
	ArmorPreventsKnockback = true,
	ArmorPreventsHitCancel = true,
}

local STARTUP_ANIMATION = "UltGrab"
local ATTACKER_ANIMATION = "UltGrabAttacker"
local VICTIM_ANIMATION = "UltGrabVictim"

local GRAB_MARKER = "Grab"
local FIRST_SLASH_MARKER = "FirstSlash"

local function playCharacterAnimation(ctx, character, animationName, fadeTime, speed, looped)
	if not ctx.StateService or not ctx.StateService.AnimationService then return nil end

	return ctx.StateService.AnimationService:PlayCharacterAnimation(
		character,
		animationName,
		fadeTime or 0.05,
		1,
		speed or 1,
		looped == true
	)
end

local function stopCharacterAnimation(ctx, character, animationName, fadeTime)
	if not ctx.StateService or not ctx.StateService.AnimationService then return end
	if not ctx.StateService.AnimationService.StopCharacterAnimationByName then return end

	ctx.StateService.AnimationService:StopCharacterAnimationByName(
		character,
		animationName,
		fadeTime or 0.08
	)
end

function Erase.Execute(ctx)
	print("[Erased] Execute started")

	local cinematicService = ctx.CinematicService

	if not cinematicService then
		warn("[Erased] Missing CinematicService in context")
		ctx:FinishMove(0)
		return
	end

	local character = ctx.Character
	local humanoid = ctx.Humanoid
	local root = ctx.Root
	local moveData = ctx.MoveData

	if not character or not character.Parent then
		ctx:FinishMove(0)
		return
	end

	if not humanoid or humanoid.Health <= 0 then
		ctx:FinishMove(0)
		return
	end

	if not root then
		ctx:FinishMove(0)
		return
	end

	if ctx.VFXService and ctx.VFXService.PlayCharacterSFXAtPart then
		ctx.VFXService:PlayCharacterSFXAtPart("Chara", "CharaScare", root, 3)
	end

	if ctx.VFXService and ctx.VFXService.PlayCharacterMoveVFX then
		ctx.VFXService:PlayCharacterMoveVFX(character, "EraseStart")
	end

	local finished = false
	local confirmed = false
	local victimErased = false

	local startupTrack = nil
	local attackerTrack = nil
	local victimTrack = nil

	local markerConnections = {}

	local attackerLockState = nil
	local victimLockState = nil
	local driftCleanup = nil

	local victimCharacter = nil
	local victimHumanoid = nil
	local victimRoot = nil

	local function shouldUseCamera()
		return moveData.UseCinematicCamera ~= false
	end

	local function setCameraFor(characterToSet, cframe)
		if not shouldUseCamera() then return end
		if not characterToSet then return end

		cinematicService:SetCamera(characterToSet, cframe)
	end

	local function tweenCameraFor(characterToSet, cframe, tweenTime)
		if not shouldUseCamera() then return end
		if not characterToSet then return end

		cinematicService:TweenCamera(characterToSet, cframe, tweenTime)
	end

	local function resetCameraFor(characterToReset)
		if not shouldUseCamera() then return end
		if not characterToReset then return end

		cinematicService:ResetCamera(characterToReset)
	end

	local function addConnection(connection)
		if connection then
			table.insert(markerConnections, connection)
		end
	end

	local function disconnectAll()
		for _, connection in ipairs(markerConnections) do
			if connection then
				connection:Disconnect()
			end
		end

		markerConnections = {}
	end

	local function cleanup()
		if finished then return end
		finished = true

		disconnectAll()

		if driftCleanup then
			driftCleanup()
			driftCleanup = nil
		end

		stopCharacterAnimation(ctx, character, STARTUP_ANIMATION, 0.05)

		if attackerTrack and attackerTrack.IsPlaying then
			attackerTrack:Stop(0.08)
		end

		if victimTrack and victimTrack.IsPlaying and not victimErased then
			victimTrack:Stop(0.08)
		end

		if attackerLockState then
			cinematicService:UnlockCharacter(attackerLockState)
			attackerLockState = nil
		end

		if victimLockState and not victimErased then
			cinematicService:UnlockCharacter(victimLockState)
			victimLockState = nil
		end

		if character and character.Parent then
			character:SetAttribute("Grabbing", false)
			character:SetAttribute("CinematicLocked", false)
			cinematicService:ClearTemporaryCombatStatus(character)
		end

		if victimCharacter and victimCharacter.Parent and not victimErased then
			victimCharacter:SetAttribute("Grabbed", false)
			victimCharacter:SetAttribute("CinematicLocked", false)
		end

		resetCameraFor(character)

		if victimCharacter then
			resetCameraFor(victimCharacter)
		end
	end

	local function finishMove(delayTime)
		cleanup()
		ctx:FinishMove(delayTime or 0)
	end

	local function whiff()
		if confirmed or finished then return end

		print("[Erased] Whiffed")

		if driftCleanup then
			driftCleanup()
			driftCleanup = nil
		end

		stopCharacterAnimation(ctx, character, STARTUP_ANIMATION, 0.08)

		finishMove(moveData.WhiffEndlag or 0.22)
	end

	local function eraseNow()
		if victimErased then return end
		if not victimCharacter or not victimCharacter.Parent then return end

		victimErased = true

		print("[Erase] Victim erased")

		resetCameraFor(victimCharacter)

		if victimTrack and victimTrack.IsPlaying then
			victimTrack:Stop(0.05)
		end

		if victimLockState then
			cinematicService:UnlockCharacter(victimLockState)
			victimLockState = nil
		end

		cinematicService:EraseCharacter(victimCharacter, 2)
	end

	local function playConfirmedCinematic()
		if not victimCharacter or not victimHumanoid or not victimRoot then
			whiff()
			return
		end

		confirmed = true

		if driftCleanup then
			driftCleanup()
			driftCleanup = nil
		end

		stopCharacterAnimation(ctx, character, STARTUP_ANIMATION, 0.04)

		character:SetAttribute("Grabbing", true)
		victimCharacter:SetAttribute("Grabbed", true)

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

		cinematicService:PositionVictimInFront(
			root,
			victimRoot,
			moveData.CinematicDistance or 3.8
		)

		local startCamera = cinematicService:GetStartCameraCFrame(root, victimRoot)

		setCameraFor(character, startCamera)
		setCameraFor(victimCharacter, startCamera)

		attackerTrack = playCharacterAnimation(ctx, character, ATTACKER_ANIMATION, 0.03, 1, false)
		victimTrack = playCharacterAnimation(ctx, victimCharacter, VICTIM_ANIMATION, 0.03, 1, false)

		if not attackerTrack then
			warn("[Erased] Missing attacker animation:", ATTACKER_ANIMATION)
		end

		if not victimTrack then
			warn("[Erased] Missing victim animation:", VICTIM_ANIMATION)
		end

		if attackerTrack then
			addConnection(attackerTrack:GetMarkerReachedSignal(FIRST_SLASH_MARKER):Connect(function()
				if finished or victimErased then return end
				if not victimCharacter or not victimCharacter.Parent then return end
				if not victimRoot or not victimRoot.Parent then return end

				print("[Erased] FirstSlash marker")

				cinematicService:TeleportAttackerBehindVictim(
					root,
					victimRoot,
					moveData.FirstSlashBehindDistance or 3.5
				)

				local slashCamera = cinematicService:GetFirstSlashCameraCFrame(root)

				tweenCameraFor(character, slashCamera, 0.28)
				tweenCameraFor(victimCharacter, slashCamera, 0.28)
			end))

			addConnection(attackerTrack.Ended:Connect(function()
				print("[Erased] Attacker animation ended")
				finishMove(0)
			end))

			addConnection(attackerTrack.Stopped:Connect(function()
				if not finished then
					print("[Erased] Attacker animation stopped")
					finishMove(0)
				end
			end))
		else
			task.delay(5, function()
				if not finished then
					finishMove(0)
				end
			end)
		end

		if victimTrack then
			addConnection(victimTrack.Ended:Connect(eraseNow))
		else
			task.delay(2.5, eraseNow)
		end
	end

	local function tryConfirmGrab(targetCharacter, targetHumanoid, targetRoot)
		if confirmed or finished then return false end

		if not cinematicService:IsValidGrabTarget(ctx, targetCharacter, targetHumanoid, targetRoot, moveData) then
			return false
		end

		if ctx.CombatStatusService then
			ctx.CombatStatusService:TryHitCancelTarget(targetCharacter, moveData)
		end

		victimCharacter = targetCharacter
		victimHumanoid = targetHumanoid
		victimRoot = targetRoot

		print("[Erased] Grab confirmed:", targetCharacter.Name)

		playConfirmedCinematic()

		return true
	end

	cinematicService:SetTemporaryCombatStatus(character, {
		IFrameActive = true,
		ArmorActive = true,
		ArmorDamageReduction = moveData.ArmorDamageReduction or 0.5,
		ArmorPreventsStun = true,
		ArmorPreventsKnockback = true,
		ArmorPreventsHitCancel = true,
	})

	startupTrack = playCharacterAnimation(ctx, character, STARTUP_ANIMATION, 0.04, 1, false)

	if not startupTrack then
		warn("[Erased] Missing startup animation:", STARTUP_ANIMATION)
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
		if finished or confirmed then return end

		if not ctx:IsActive() then
			finishMove(0)
			return
		end

		print("[Erased] Grab marker reached")

		grabMarkerReached = true

		local hitOnce = false
		local startTime = os.clock()

		while ctx:IsActive()
			and not finished
			and not confirmed
			and os.clock() - startTime < (moveData.GrabActiveTime or 0.15)
		do
			local hitboxData = {
				Radius = moveData.Radius or 7,
				Offset = moveData.Offset or CFrame.new(0, 0, -5),
			}

			ctx.HitboxService:PerformSphereAtCFrame(
				character,
				root.CFrame,
				hitboxData,
				function(targetCharacter, targetHumanoid, targetRoot)
					if hitOnce then return end

					hitOnce = tryConfirmGrab(targetCharacter, targetHumanoid, targetRoot)
				end
			)

			task.wait(moveData.GrabTickRate or 0.03)
		end

		if not confirmed and not finished then
			whiff()
		end
	end))

	addConnection(startupTrack.Ended:Connect(function()
		if finished or confirmed then return end

		if not grabMarkerReached then
			warn("[Erased] Startup animation ended before Grab marker")
		end

		whiff()
	end))

	task.delay(moveData.MaxLockTime or 9, function()
		if not finished then
			warn("[Erased] Failsafe cleanup")
			finishMove(0)
		end
	end)
end

return Erase