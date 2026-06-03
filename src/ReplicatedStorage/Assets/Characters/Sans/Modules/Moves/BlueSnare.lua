local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local BlueSnare = {
	DisplayName = "Blue Snare",
	AnimationName = "BlueSnare",

	Cooldown = 1, -- testing value; later maybe 7-9
	Duration = 1.45,
	LockTime = 1.35,
	MaxLockTime = 1.7,

	RequiresTarget = false,
	RequiresAim = false,

	Startup = 0.22,
	HoldTime = 0.85,
	Endlag = 0.18,
	WhiffEndlag = 0.28,

	Radius = 7,
	Offset = CFrame.new(0, 0, -5),

	Damage = 5,
	FinalDamage = 6,

	Stun = 1.15,

	Knockback = 135,
	UpwardKnockback = 38,

	HoldHeight = 7.5,
	HoldForwardOffset = 5.25,
	HoldResponsiveness = 45,
	HoldMaxForce = 120000,
	HoldMaxVelocity = 70,

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

local function makeAttackData(moveData)
	local attackData = {}

	for key, value in pairs(moveData) do
		attackData[key] = value
	end

	attackData.AttackType = "Move"
	attackData.Damage = moveData.Damage or 5
	attackData.Stun = moveData.Stun or 1.15
	attackData.Knockback = 0
	attackData.UpwardKnockback = 0
	attackData.Guardbreak = false
	attackData.PlayMoveHitVFX = false

	attackData.CanBeBlocked = true
	attackData.Blockable = true
	attackData.Unblockable = false
	attackData.CanBeCountered = true
	attackData.HitCancelsTarget = true

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
	alignPosition.Responsiveness = moveData.HoldResponsiveness or 45
	alignPosition.MaxForce = moveData.HoldMaxForce or 120000
	alignPosition.MaxVelocity = moveData.HoldMaxVelocity or 70
	alignPosition.Parent = targetRoot

	Debris:AddItem(alignPosition, (moveData.HoldTime or 0.85) + 0.35)
	Debris:AddItem(attachment, (moveData.HoldTime or 0.85) + 0.35)

	return alignPosition, attachment
end

local function cleanupHold(alignPosition, attachment)
	if alignPosition then
		alignPosition:Destroy()
	end

	if attachment then
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
		+ (forward * (moveData.HoldForwardOffset or 5.25))
		+ Vector3.new(0, moveData.HoldHeight or 7.5, 0)
end

local function getKnockbackDirection(root, targetRoot)
	local direction = targetRoot.Position - root.Position
	direction = Vector3.new(direction.X, 0, direction.Z)

	if direction.Magnitude < 0.05 then
		direction = root.CFrame.LookVector
		direction = Vector3.new(direction.X, 0, direction.Z)
	end

	if direction.Magnitude < 0.05 then
		return Vector3.new(0, 0, -1)
	end

	return direction.Unit
end

local function applyFinalHit(ctx, targetCharacter, targetHumanoid, targetRoot)
	local moveData = ctx.MoveData

	if not targetCharacter or not targetCharacter.Parent then return end
	if not targetHumanoid or targetHumanoid.Health <= 0 then return end
	if not targetRoot or not targetRoot.Parent then return end

	local damage = moveData.FinalDamage or 6

	targetHumanoid:TakeDamage(damage)

	if ctx.UltService then
		ctx.UltService:AwardDamageEvent(ctx.Character, targetCharacter, damage)
	end

	if ctx.VFXService then
		ctx.VFXService:EmitHitVFXOnVictim(targetRoot, ctx.Character)
	end

	local direction = getKnockbackDirection(ctx.Root, targetRoot)

	targetRoot.AssemblyLinearVelocity =
		(direction * (moveData.Knockback or 135))
		+ Vector3.new(0, moveData.UpwardKnockback or 38, 0)
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
			elseif result == "Countered" then
				print("[BlueSnare] Countered")
			end
		end
	)

	if not confirmed or not victimCharacter or not victimHumanoid or not victimRoot then
		print("[BlueSnare] Whiffed")
		ctx:FinishMove(moveData.WhiffEndlag or 0.28)
		return
	end

	print("[BlueSnare] Hit:", victimCharacter.Name)

	playSansSFX(ctx, "Ding", victimRoot, 2)
	playSansMoveVFX(ctx, "BlueHeart", victimCharacter, victimRoot)

	if ctx.MovementService then
		ctx.MovementService:StopCarryController(root)
		ctx.MovementService:StopCarryController(victimRoot)
		ctx.MovementService:StopYHoldController(root)
		ctx.MovementService:StopYHoldController(victimRoot)
	end

	victimRoot.AssemblyLinearVelocity = Vector3.zero

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

		if not victimHumanoid or victimHumanoid.Health <= 0 then
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

	if victimCharacter and victimCharacter.Parent and victimHumanoid and victimHumanoid.Health > 0 and victimRoot and victimRoot.Parent then
		applyFinalHit(ctx, victimCharacter, victimHumanoid, victimRoot)
	end

	ctx:FinishMove(moveData.Endlag or 0.18)
end

return BlueSnare