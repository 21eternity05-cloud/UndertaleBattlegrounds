local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local BlueSnare = {
	DisplayName = "Blue Snare",

	AnimationName = "BlueSnare",
	HitAnimationName = "BlueSnareHit",

	Cooldown = 13,
	Duration = 1.6,
	LockTime = 1.45,
	MaxLockTime = 1.9,

	RequiresTarget = false,
	RequiresAim = false,

	Startup = 0.22,
	HoldTime = 0.85,
	Endlag = 0.18,
	WhiffEndlag = 0.28,

	Radius = 7,
	Offset = CFrame.new(0, 0, -5),

	Damage = 2,
	FinalDamage = 4,
	Stun = 1.15,

	KnockbackPreset = "Downslam",

	DownForwardSpeed = 10,
	DownSpeed = -95,
	DownLaunchMaxForce = 90000,

	AirStunMax = 1.15,
	GroundSplatStun = 0.55,
	PostSplatM1Immunity = 0,

	SplatPartLifetime = 0.35,
	SplatPartSize = Vector3.new(8, 0.25, 8),

	HoldHeight = 18,
	HoldForwardOffset = 8.5,
	HoldResponsiveness = 55,
	HoldMaxForce = 140000,
	HoldMaxVelocity = 90,

	Blockable = true,
	CanBeBlocked = true,
	Unblockable = false,
	Guardbreak = false,
	CanBeCountered = true,
	HitCancelsTarget = true,
	CancelableByHit = true,

	HasArmor = false,
	HasIFrames = false,

	PlayMoveHitVFX = false,

	-- Blue Snare polish.
	-- Catch should feel magical/control-based, final slam should feel heavier.
	CatchVictimShakeMagnitude = 0.85,
	CatchVictimShakeRoughness = 10,
	CatchVictimShakeDuration = 0.16,

	CatchAttackerShakeMagnitude = 0.25,
	CatchAttackerShakeRoughness = 6,
	CatchAttackerShakeDuration = 0.08,

	BlockVictimShakeMagnitude = 0.4,
	BlockVictimShakeRoughness = 7,
	BlockVictimShakeDuration = 0.09,

	FinalAttackerShakeMagnitude = 1.15,
	FinalAttackerShakeRoughness = 11,
	FinalAttackerShakeDuration = 0.18,

	FinalVictimShakeMagnitude = 2.05,
	FinalVictimShakeRoughness = 16,
	FinalVictimShakeDuration = 0.3,

	FinalImpactFrameDuration = 0.07,
}

local function playSansSFX(ctx, soundName, part, lifetime)
	if not ctx.VFXService then return end
	if not ctx.VFXService.PlayCharacterSFXAtPart then return end
	if not part or not part.Parent then return end

	ctx.VFXService:PlayCharacterSFXAtPart("Sans", soundName, part, lifetime or 2)
end

local function playSansMoveVFX(ctx, moveName, targetCharacter, targetRoot)
	if not ctx.VFXService then return end
	if not ctx.VFXService.PlayCharacterMoveVFX then return end

	ctx.VFXService:PlayCharacterMoveVFX(
		ctx.Character,
		moveName,
		targetCharacter,
		targetRoot
	)
end

local function shakeCharacter(ctx, targetCharacter, magnitude, roughness, duration)
	if not targetCharacter or not targetCharacter.Parent then return end
	if not ctx.CinematicService then return end
	if not ctx.CinematicService.ShakeOnce then return end

	pcall(function()
		ctx.CinematicService:ShakeOnce(targetCharacter, magnitude, roughness, duration)
	end)
end

local function playImpactFrame(ctx, targetCharacter, duration)
	if not targetCharacter or not targetCharacter.Parent then return end
	if not ctx.CinematicService then return end
	if not ctx.CinematicService.ImpactFrame then return end

	local success = pcall(function()
		ctx.CinematicService:ImpactFrame(targetCharacter, duration)
	end)

	if success then
		return
	end

	pcall(function()
		ctx.CinematicService:ImpactFrame(targetCharacter, {
			Duration = duration,
		})
	end)
end

local function playCatchPolish(ctx, targetCharacter)
	local moveData = ctx.MoveData or BlueSnare

	shakeCharacter(
		ctx,
		targetCharacter,
		moveData.CatchVictimShakeMagnitude or BlueSnare.CatchVictimShakeMagnitude or 0.85,
		moveData.CatchVictimShakeRoughness or BlueSnare.CatchVictimShakeRoughness or 10,
		moveData.CatchVictimShakeDuration or BlueSnare.CatchVictimShakeDuration or 0.16
	)

	shakeCharacter(
		ctx,
		ctx.Character,
		moveData.CatchAttackerShakeMagnitude or BlueSnare.CatchAttackerShakeMagnitude or 0.25,
		moveData.CatchAttackerShakeRoughness or BlueSnare.CatchAttackerShakeRoughness or 6,
		moveData.CatchAttackerShakeDuration or BlueSnare.CatchAttackerShakeDuration or 0.08
	)
end

local function playBlockPolish(ctx, targetCharacter)
	local moveData = ctx.MoveData or BlueSnare

	shakeCharacter(
		ctx,
		targetCharacter,
		moveData.BlockVictimShakeMagnitude or BlueSnare.BlockVictimShakeMagnitude or 0.4,
		moveData.BlockVictimShakeRoughness or BlueSnare.BlockVictimShakeRoughness or 7,
		moveData.BlockVictimShakeDuration or BlueSnare.BlockVictimShakeDuration or 0.09
	)
end

local function playFinalSlamPolish(ctx, targetCharacter)
	local moveData = ctx.MoveData or BlueSnare

	shakeCharacter(
		ctx,
		ctx.Character,
		moveData.FinalAttackerShakeMagnitude or BlueSnare.FinalAttackerShakeMagnitude or 1.15,
		moveData.FinalAttackerShakeRoughness or BlueSnare.FinalAttackerShakeRoughness or 11,
		moveData.FinalAttackerShakeDuration or BlueSnare.FinalAttackerShakeDuration or 0.18
	)

	shakeCharacter(
		ctx,
		targetCharacter,
		moveData.FinalVictimShakeMagnitude or BlueSnare.FinalVictimShakeMagnitude or 2.05,
		moveData.FinalVictimShakeRoughness or BlueSnare.FinalVictimShakeRoughness or 16,
		moveData.FinalVictimShakeDuration or BlueSnare.FinalVictimShakeDuration or 0.3
	)

	local impactDuration = moveData.FinalImpactFrameDuration or BlueSnare.FinalImpactFrameDuration or 0.07
	playImpactFrame(ctx, ctx.Character, impactDuration)
	playImpactFrame(ctx, targetCharacter, impactDuration)
end

local function playHitAnimation(ctx)
	local character = ctx.Character
	local moveData = ctx.MoveData

	if not ctx.StateService then return end
	if not ctx.StateService.AnimationService then return end
	if not moveData.HitAnimationName then return end

	local animationService = ctx.StateService.AnimationService

	if moveData.AnimationName and animationService.StopCharacterAnimationByName then
		animationService:StopCharacterAnimationByName(character, moveData.AnimationName, 0.05)
	end

	animationService:PlayCharacterAnimation(
		character,
		moveData.HitAnimationName,
		0.05,
		1,
		1,
		true
	)
end

local function makeAttackData(moveData)
	local attackData = {}

	for key, value in pairs(moveData) do
		attackData[key] = value
	end

	attackData.AttackType = "Move"
	attackData.Damage = moveData.Damage or 4
	attackData.Stun = moveData.Stun or 1.15

	-- Initial hit only catches. No movement yet.
	attackData.KnockbackPreset = nil
	attackData.Knockback = 0
	attackData.UpwardKnockback = 0
	attackData.DownForwardSpeed = nil
	attackData.DownSpeed = nil
	attackData.DownLaunchMaxForce = nil

	attackData.Guardbreak = false
	attackData.PlayMoveHitVFX = false

	attackData.CanBeBlocked = true
	attackData.Blockable = true
	attackData.Unblockable = false
	attackData.CanBeCountered = true
	attackData.HitCancelsTarget = true
	attackData.CancelableByHit = true

	return attackData
end

local function createHoldAlign(targetRoot, holdPosition, moveData)
	local attachment = Instance.new("Attachment")
	attachment.Name = "BlueSnareHoldAttachment"
	attachment.Parent = targetRoot

	local alignPosition = Instance.new("AlignPosition")
	alignPosition.Name = "BlueSnareHoldAlign"
	alignPosition.Attachment0 = attachment
	alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
	alignPosition.Position = holdPosition
	alignPosition.RigidityEnabled = false
	alignPosition.ReactionForceEnabled = false
	alignPosition.ApplyAtCenterOfMass = true
	alignPosition.Responsiveness = moveData.HoldResponsiveness or 55
	alignPosition.MaxForce = moveData.HoldMaxForce or 140000
	alignPosition.MaxVelocity = moveData.HoldMaxVelocity or 90
	alignPosition.Parent = targetRoot

	Debris:AddItem(alignPosition, (moveData.HoldTime or 0.85) + 0.35)
	Debris:AddItem(attachment, (moveData.HoldTime or 0.85) + 0.35)

	return alignPosition, attachment
end

local function cleanupHold(alignPosition, attachment)
	if alignPosition and alignPosition.Parent then
		alignPosition:Destroy()
	end

	if attachment and attachment.Parent then
		attachment:Destroy()
	end
end

local function getHoldPosition(root, moveData)
	local forward = root.CFrame.LookVector
	forward = Vector3.new(forward.X, 0, forward.Z)

	if forward.Magnitude < 0.05 then
		forward = Vector3.new(0, 0, -1)
	else
		forward = forward.Unit
	end

	return root.Position
		+ (forward * (moveData.HoldForwardOffset or 8.5))
		+ Vector3.new(0, moveData.HoldHeight or 13.5, 0)
end

local function stopCombatMovement(ctx, root, victimRoot)
	if not ctx.MovementService then
		return
	end

	if ctx.MovementService.ClearCombatMovementControllers then
		if root then
			ctx.MovementService:ClearCombatMovementControllers(root)
		end

		if victimRoot then
			ctx.MovementService:ClearCombatMovementControllers(victimRoot)
		end

		return
	end

	if ctx.MovementService.StopCarryController then
		if root then
			ctx.MovementService:StopCarryController(root)
		end

		if victimRoot then
			ctx.MovementService:StopCarryController(victimRoot)
		end
	end

	if ctx.MovementService.StopYHoldController then
		if root then
			ctx.MovementService:StopYHoldController(root)
		end

		if victimRoot then
			ctx.MovementService:StopYHoldController(victimRoot)
		end
	end
end

local function reportDamage(ctx, targetCharacter, targetRoot, damage)
	if not ctx or not targetCharacter then
		return
	end

	if typeof(damage) ~= "number" or damage <= 0 then
		return
	end

	if ctx.DamageNumberService and targetRoot then
		ctx.DamageNumberService:ShowDamage(targetRoot, damage, {
			TextSize = 46,
		})
	end

	if ctx.ReportDamageEvent then
		ctx:ReportDamageEvent(targetCharacter, damage, targetRoot)
		return
	end

	if ctx.UltService and ctx.UltService.AwardDamageEvent then
		ctx.UltService:AwardDamageEvent(ctx.Character, targetCharacter, damage)
	end
end

local function makeFinalDownslamData(moveData)
	local slamData = {}

	for key, value in pairs(moveData or {}) do
		slamData[key] = value
	end

	slamData.KnockbackPreset = "Downslam"

	slamData.DownForwardSpeed = moveData.DownForwardSpeed or 10
	slamData.DownSpeed = moveData.DownSpeed or -95
	slamData.DownLaunchMaxForce = moveData.DownLaunchMaxForce or 90000

	slamData.AirStunMax = moveData.AirStunMax or 1.15
	slamData.GroundSplatStun = moveData.GroundSplatStun or 0.55
	slamData.PostSplatM1Immunity = moveData.PostSplatM1Immunity or 1

	slamData.SplatPartLifetime = moveData.SplatPartLifetime or 0.35
	slamData.SplatPartSize = moveData.SplatPartSize or Vector3.new(8, 0.25, 8)

	slamData.AirAnimationName = "DownslamAir"
	slamData.SplatAnimationName = "DownslamSplat"

	return slamData
end

local function applyFinalHit(ctx, targetCharacter, targetHumanoid, targetRoot)
	local moveData = ctx.MoveData

	if not targetCharacter or not targetCharacter.Parent then return end
	if not targetHumanoid then return end
	if not targetRoot or not targetRoot.Parent then return end

	local damage = moveData.FinalDamage or 8
	local slamData = makeFinalDownslamData(moveData)

	stopCombatMovement(ctx, ctx.Root, targetRoot)

	targetRoot.AssemblyLinearVelocity = Vector3.zero
	targetRoot.AssemblyAngularVelocity = Vector3.zero

	playFinalSlamPolish(ctx, targetCharacter)

	-- IMPORTANT:
	-- Start downslam first so ground splat VFX still happens even if the damage kills.
	if ctx.MovementService and ctx.MovementService.ApplyGroundSplatDownslam then
		ctx.MovementService:ApplyGroundSplatDownslam(
			ctx.Root,
			targetCharacter,
			targetHumanoid,
			targetRoot,
			slamData,
			{
				StateService = ctx.StateService,
				VFXService = ctx.VFXService,
				AttackerCharacter = ctx.Character,
			},
			"BlueSnareFinalDownslam"
		)
	elseif ctx.MovementService and ctx.MovementService.ApplyDownslamKnockback then
		ctx.MovementService:ApplyDownslamKnockback(
			ctx.Root,
			targetRoot,
			slamData,
			"BlueSnareFinalDownslam"
		)
	else
		local forward = ctx.Root.CFrame.LookVector
		forward = Vector3.new(forward.X, 0, forward.Z)

		if forward.Magnitude < 0.05 then
			forward = Vector3.new(0, 0, -1)
		else
			forward = forward.Unit
		end

		targetRoot.AssemblyLinearVelocity =
			(forward * (slamData.DownForwardSpeed or 10))
			+ Vector3.new(0, slamData.DownSpeed or -95, 0)
	end

	-- Damage happens after downslam begins.
	if targetHumanoid.Health > 0 then
		targetHumanoid:TakeDamage(damage)
		reportDamage(ctx, targetCharacter, targetRoot, damage)
	end

	playSansSFX(ctx, "M1", targetRoot, 2)
end

function BlueSnare.Execute(ctx)
	print("[BlueSnare] Execute started")

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

	playSansSFX(ctx, "EyeFlash", root, 2)
	playSansMoveVFX(ctx, "EyeGlow", nil, nil)

	local startupStart = os.clock()

	while os.clock() - startupStart < (moveData.Startup or 0.22) do
		if not ctx:IsActive() then
			ctx:FinishMove(0)
			return
		end

		if character:GetAttribute("Stunned") or character:GetAttribute("Guardbroken") then
			ctx:FinishMove(0)
			return
		end

		task.wait()
	end

	if not ctx:IsActive() then
		ctx:FinishMove(0)
		return
	end

	local confirmed = false
	local victimCharacter = nil
	local victimHumanoid = nil
	local victimRoot = nil
	local attackData = makeAttackData(moveData)

	ctx.HitboxService:PerformSphereHitbox(
		character,
		root,
		moveData,
		function(targetCharacter, targetHumanoid, targetRoot)
			if confirmed then return end

			local result = ctx:ApplyStandardHit(
				targetCharacter,
				targetHumanoid,
				targetRoot,
				attackData,
				"BlueSnare"
			)

			if result == "Hit" or result == "ArmoredHit" then
				confirmed = true
				victimCharacter = targetCharacter
				victimHumanoid = targetHumanoid
				victimRoot = targetRoot
			elseif result == "Blocked" then
				print("[BlueSnare] Blocked")
				playBlockPolish(ctx, targetCharacter)
			elseif result == "Countered" then
				print("[BlueSnare] Countered")
			elseif result == "DamageLocked" then
				print("[BlueSnare] Target damage locked")
			end
		end
	)

	if not confirmed or not victimCharacter or not victimHumanoid or not victimRoot then
		print("[BlueSnare] Whiffed")
		ctx:FinishMove(moveData.WhiffEndlag or 0.28)
		return
	end

	print("[BlueSnare] Hit:", victimCharacter.Name)

	playHitAnimation(ctx)

	playSansSFX(ctx, "Ding", victimRoot, 2)
	playSansMoveVFX(ctx, "BlueHeart", victimCharacter, victimRoot)
	playCatchPolish(ctx, victimCharacter)

	stopCombatMovement(ctx, root, victimRoot)

	victimRoot.AssemblyLinearVelocity = Vector3.zero
	victimRoot.AssemblyAngularVelocity = Vector3.zero

	local holdPosition = getHoldPosition(root, moveData)
	local alignPosition, attachment = createHoldAlign(victimRoot, holdPosition, moveData)

	local holdStart = os.clock()
	local holdConnection = nil

	holdConnection = RunService.Heartbeat:Connect(function()
		if not ctx:IsActive() then
			if holdConnection then
				holdConnection:Disconnect()
				holdConnection = nil
			end

			cleanupHold(alignPosition, attachment)
			return
		end

		if not victimCharacter or not victimCharacter.Parent then
			if holdConnection then
				holdConnection:Disconnect()
				holdConnection = nil
			end

			cleanupHold(alignPosition, attachment)
			return
		end

		if not victimHumanoid then
			if holdConnection then
				holdConnection:Disconnect()
				holdConnection = nil
			end

			cleanupHold(alignPosition, attachment)
			return
		end

		if victimHumanoid.Health <= 0 then
			if holdConnection then
				holdConnection:Disconnect()
				holdConnection = nil
			end

			cleanupHold(alignPosition, attachment)
			return
		end

		if character:GetAttribute("Stunned") or character:GetAttribute("Guardbroken") then
			if holdConnection then
				holdConnection:Disconnect()
				holdConnection = nil
			end

			cleanupHold(alignPosition, attachment)
			ctx:FinishMove(0)
			return
		end

		if os.clock() - holdStart >= (moveData.HoldTime or 0.85) then
			if holdConnection then
				holdConnection:Disconnect()
				holdConnection = nil
			end
		end
	end)

	while ctx:IsActive()
		and victimCharacter
		and victimCharacter.Parent
		and victimHumanoid
		and victimHumanoid.Health > 0
		and os.clock() - holdStart < (moveData.HoldTime or 0.85)
	do
		if character:GetAttribute("Stunned") or character:GetAttribute("Guardbroken") then
			cleanupHold(alignPosition, attachment)
			ctx:FinishMove(0)
			return
		end

		task.wait()
	end

	if holdConnection then
		holdConnection:Disconnect()
		holdConnection = nil
	end

	cleanupHold(alignPosition, attachment)

	if not ctx:IsActive() then
		ctx:FinishMove(0)
		return
	end

	if victimCharacter
		and victimCharacter.Parent
		and victimHumanoid
		and victimRoot
		and victimRoot.Parent
	then
		stopCombatMovement(ctx, root, victimRoot)
		applyFinalHit(ctx, victimCharacter, victimHumanoid, victimRoot)
	end

	ctx:FinishMove(moveData.Endlag or 0.18)
end

return BlueSnare