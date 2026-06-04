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
}

local STARTUP_ANIMATIONS = { "SpecialHellGrab", "UltGrab" }
local ATTACKER_ANIMATIONS = { "SpecialHellAttacker", "UltGrabAttacker" }
local VICTIM_ANIMATIONS = { "SpecialHellVictim", "UltGrabVictim" }

local GRAB_MARKER = "Grab"
local HELL_MARKER = "Hell"

local function playFirstAnimation(ctx, character, names, fadeTime, speed, looped)
	if not ctx.StateService or not ctx.StateService.AnimationService then return nil, nil end

	for _, animationName in ipairs(names) do
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
	end

	return nil, nil
end

local function stopAnimation(ctx, character, animationNames, fadeTime)
	if not ctx.StateService or not ctx.StateService.AnimationService then return end
	if not ctx.StateService.AnimationService.StopCharacterAnimationByName then return end

	for _, animationName in ipairs(animationNames) do
		ctx.StateService.AnimationService:StopCharacterAnimationByName(character, animationName, fadeTime or 0.08)
	end
end

local function getGroundPosition(character, targetRoot)
	local rayOrigin = targetRoot.Position + Vector3.new(0, 5, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, targetRoot.Parent }

	local result = workspace:Raycast(rayOrigin, Vector3.new(0, -40, 0), params)
	if result then
		return result.Position + Vector3.new(0, 0.08, 0)
	end

	return targetRoot.Position - Vector3.new(0, 2.7, 0)
end

local function playSpecialHellVFX(ctx, victimRoot)
	if not victimRoot or not victimRoot.Parent then return end

	local groundPosition = getGroundPosition(ctx.Character, victimRoot)

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

	TweenService:Create(
		warning,
		TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{
			Size = Vector3.new(18, 0.18, 18),
			Transparency = 0.18,
		}
	):Play()

	task.delay(0.3, function()
		if not warning or not warning.Parent then return end

		local beam = Instance.new("Part")
		beam.Name = "SpecialHellBeam"
		beam.Anchored = true
		beam.CanCollide = false
		beam.CanTouch = false
		beam.CanQuery = false
		beam.Material = Enum.Material.Neon
		beam.Color = Color3.fromRGB(255, 0, 0)
		beam.Transparency = 0.08
		beam.Size = Vector3.new(4, 1, 4)
		beam.CFrame = CFrame.new(groundPosition + Vector3.new(0, 0.5, 0))
		beam.Parent = workspace

		local growTween = TweenService:Create(
			beam,
			TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{
				Size = Vector3.new(13, 90, 13),
				CFrame = CFrame.new(groundPosition + Vector3.new(0, 45, 0)),
			}
		)

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
				TweenService:Create(
					beam,
					TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Transparency = 1, Size = Vector3.new(3, 90, 3) }
				):Play()
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
		if finished then return end
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
			victimCharacter:SetAttribute("Grabbed", false)
			victimCharacter:SetAttribute("CinematicLocked", false)
			cinematicService:ClearTemporaryCombatStatus(victimCharacter)
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
		if hellResolved then return end
		if not victimCharacter or not victimHumanoid or not victimRoot then return end
		if not victimCharacter.Parent or victimHumanoid.Health <= 0 then return end

		hellResolved = true

		print("[SpecialHell] Hell marker")

		playSpecialHellVFX(ctx, victimRoot)

		cinematicService:ShakeOnce(character, 2.4, 10, 0.35)
		cinematicService:ShakeOnce(victimCharacter, 2.4, 10, 0.35)
		cinematicService:ImpactFrame(character, "RedBlack", nil, nil, nil, 0.08)
		cinematicService:ImpactFrame(victimCharacter, "RedBlack", nil, nil, nil, 0.08)

		victimHumanoid:TakeDamage(moveData.Damage or 999)
	end

	local function playConfirmedCinematic()
		confirmed = true

		if driftCleanup then
			driftCleanup()
			driftCleanup = nil
		end

		stopAnimation(ctx, character, STARTUP_ANIMATIONS, 0.04)

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
		if finished or confirmed then return end
		if not ctx:IsActive() then
			finish(0)
			return
		end

		grabMarkerReached = true

		local hitOnce = false
		local startTime = os.clock()

		while ctx:IsActive()
			and not finished
			and not confirmed
			and os.clock() - startTime < (moveData.GrabActiveTime or 0.15)
		do
			ctx.HitboxService:PerformSphereAtCFrame(
				character,
				root.CFrame,
				{
					Radius = moveData.Radius or 7,
					Offset = moveData.Offset or CFrame.new(0, 0, -5),
				},
				function(targetCharacter, targetHumanoid, targetRoot)
					if hitOnce then return end
					hitOnce = tryConfirmGrab(targetCharacter, targetHumanoid, targetRoot)
				end
			)

			task.wait(moveData.GrabTickRate or 0.03)
		end

		if not confirmed and not finished then
			print("[SpecialHell] Whiffed")
			finish(moveData.WhiffEndlag or 0.22)
		end
	end))

	addConnection(startupTrack.Ended:Connect(function()
		if finished or confirmed then return end
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
