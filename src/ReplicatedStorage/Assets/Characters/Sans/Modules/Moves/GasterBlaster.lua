local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local GasterBlaster = {
	DisplayName = "Gaster Blaster",
	AnimationName = "GasterBlaster",

	Cooldown = 10, -- testing value; later use 10-14
	Duration = 1.4,
	LockTime = 1.05,
	MaxLockTime = 1.5,

	RequiresTarget = false,
	RequiresAim = true,

	Startup = 0.24,
	ChargeTime = 0.52,
	BeamActiveTime = 0.4,

	BeamLength = 90,
	BeamRadius = 5.5,
	BeamStep = 6,
	BeamTickRate = 0.08,

	Damage = 1,
	FinalDamage = 5,
	Stun = 0.25,
	FinalStun = 0.35,

	Knockback = 18,
	FinalKnockback = 95,
	UpwardKnockback = 4,
	FinalUpwardKnockback = 28,
	UseAttackerPositionForFinalKnockback = true,
	FinalKnockbackSource = "Attacker",
	FinalKnockbackDuration = 0.28,
	FinalKnockbackMaxForce = 130000,

	Blockable = true,
	CanBeBlocked = true,
	Unblockable = false,

	Guardbreak = true,
	GuardbreakFinalOnly = true,
	GuardbreakStun = 2.45,

	CanBeCountered = true,
	AllowLongRangeCounter = false,

	-- Do not cancel the victim's current move/action.
	HitCancelsTarget = false,
	CancelableByHit = true,

	SpawnOffset = CFrame.new(0, 4.5, -5.5),

	-- Blaster entrance/exit polish.
	-- Positive Z moves it backward relative to the blaster facing direction.
	FadeInOffset = CFrame.new(0, 0, 7),
	FadeOutOffset = CFrame.new(0, 0, 7),
	FadeInTime = 0.16,
	FadeOutTime = 0.16,

	JawOpenTime = 0.18,
	JawOutDistance = 0,
	JawDownDistance = 0,
	JawOpenAngle = 22,

	BeamFadeTime = 0.12,
	BlasterLifetime = 2,

	-- Beam visual polish.
	BeamVisualTransparency = 0.24,
	BeamVisualSizeMultiplier = 1.15,

	FinalBeamVisualTransparency = 0.02,
	FinalBeamVisualSizeMultiplier = 2.25,
	FinalBeamFadeTime = 0.18,
	FinalBeamExtraLength = 8,

	-- Camera polish.
	ChargeAttackerShakeMagnitude = 0.35,
	ChargeAttackerShakeRoughness = 6,
	ChargeAttackerShakeDuration = 0.12,

	FireAttackerShakeMagnitude = 0.75,
	FireAttackerShakeRoughness = 10,
	FireAttackerShakeDuration = 0.18,

	HitVictimShakeMagnitude = 0.65,
	HitVictimShakeRoughness = 9,
	HitVictimShakeDuration = 0.12,

	BlockVictimShakeMagnitude = 0.35,
	BlockVictimShakeRoughness = 7,
	BlockVictimShakeDuration = 0.08,

	FinalBeamAttackerShakeMagnitude = 1.45,
	FinalBeamAttackerShakeRoughness = 14,
	FinalBeamAttackerShakeDuration = 0.28,

	FinalBeamRadiusShakeMagnitude = 1.15,
	FinalBeamRadiusShakeRoughness = 11,
	FinalBeamRadiusShakeDuration = 0.22,
	FinalBeamRadiusShakeRange = 65,

	FinalBeamImpactFrameDuration = 0.055,
}

local MoveHelpers = script.Parent.Parent:WaitForChild("MoveHelpers")
local SansMoveUtil = require(MoveHelpers:WaitForChild("SansMoveUtil"))
local BlasterHelper = require(MoveHelpers:WaitForChild("BlasterHelper"))
local SansImpactHelper = require(MoveHelpers:WaitForChild("SansImpactHelper"))

local function getSansVFXFolder(ctx)
	return SansMoveUtil.GetSansVFXFolder(ctx)
end

local function getGasterBlasterTemplate(ctx)
	local vfxFolder = getSansVFXFolder(ctx)
	return vfxFolder:WaitForChild("GasterBlaster")
end

local function playSansSFX(ctx, soundName, parentPart, lifetime)
	SansMoveUtil.PlaySFX(ctx, soundName, parentPart, lifetime)
end

local function shakeCharacter(ctx, targetCharacter, magnitude, roughness, duration)
	SansImpactHelper.ShakeCharacter(ctx, targetCharacter, magnitude, roughness, duration)
end

local function impactFrame(ctx, targetCharacter, duration)
	SansImpactHelper.ImpactFrame(ctx, targetCharacter, duration)
end

local function playChargePolish(ctx, data)
	shakeCharacter(
		ctx,
		ctx.Character,
		data.ChargeAttackerShakeMagnitude or GasterBlaster.ChargeAttackerShakeMagnitude or 0.35,
		data.ChargeAttackerShakeRoughness or GasterBlaster.ChargeAttackerShakeRoughness or 6,
		data.ChargeAttackerShakeDuration or GasterBlaster.ChargeAttackerShakeDuration or 0.12
	)
end

local function playFirePolish(ctx, data)
	shakeCharacter(
		ctx,
		ctx.Character,
		data.FireAttackerShakeMagnitude or GasterBlaster.FireAttackerShakeMagnitude or 0.75,
		data.FireAttackerShakeRoughness or GasterBlaster.FireAttackerShakeRoughness or 10,
		data.FireAttackerShakeDuration or GasterBlaster.FireAttackerShakeDuration or 0.18
	)
end

local function playBeamHitPolish(ctx, data, targetCharacter, result)
	if result == "Hit" or result == "ArmoredHit" or result == "Guardbreak" then
		shakeCharacter(
			ctx,
			targetCharacter,
			data.HitVictimShakeMagnitude or GasterBlaster.HitVictimShakeMagnitude or 0.65,
			data.HitVictimShakeRoughness or GasterBlaster.HitVictimShakeRoughness or 9,
			data.HitVictimShakeDuration or GasterBlaster.HitVictimShakeDuration or 0.12
		)

		return
	end

	if result == "Blocked" then
		shakeCharacter(
			ctx,
			targetCharacter,
			data.BlockVictimShakeMagnitude or GasterBlaster.BlockVictimShakeMagnitude or 0.35,
			data.BlockVictimShakeRoughness or GasterBlaster.BlockVictimShakeRoughness or 7,
			data.BlockVictimShakeDuration or GasterBlaster.BlockVictimShakeDuration or 0.08
		)
	end
end

local function playFinalBeamPolish(ctx, data, beamStart)
	shakeCharacter(
		ctx,
		ctx.Character,
		data.FinalBeamAttackerShakeMagnitude or GasterBlaster.FinalBeamAttackerShakeMagnitude or 1.45,
		data.FinalBeamAttackerShakeRoughness or GasterBlaster.FinalBeamAttackerShakeRoughness or 14,
		data.FinalBeamAttackerShakeDuration or GasterBlaster.FinalBeamAttackerShakeDuration or 0.28
	)

	impactFrame(
		ctx,
		ctx.Character,
		data.FinalBeamImpactFrameDuration or GasterBlaster.FinalBeamImpactFrameDuration or 0.055
	)

	if ctx.CinematicService and ctx.CinematicService.ShakeRadius then
		SansImpactHelper.ShakeRadius(
			ctx,
			beamStart,
			data.FinalBeamRadiusShakeRange or GasterBlaster.FinalBeamRadiusShakeRange or 65,
			data.FinalBeamRadiusShakeMagnitude or GasterBlaster.FinalBeamRadiusShakeMagnitude or 1.15,
			data.FinalBeamRadiusShakeRoughness or GasterBlaster.FinalBeamRadiusShakeRoughness or 11,
			data.FinalBeamRadiusShakeDuration or GasterBlaster.FinalBeamRadiusShakeDuration or 0.22,
			{
				ExcludeCharacters = {
					ctx.Character,
				},
			}
		)
	end
end

local function ensurePrimaryPart(model)
	return BlasterHelper.EnsurePrimaryPart(model)
end

local function setupBlasterParts(model)
	BlasterHelper.SetupWorldModel(model)
end

local function getVisibleParts(model)
	return BlasterHelper.GetVisibleParts(model, true)
end

local function forcePrimaryInvisible(model)
	BlasterHelper.ForcePrimaryInvisible(model)
end

local function capturePartTransparencies(model)
	local transparencies = {}

	for _, part in ipairs(getVisibleParts(model)) do
		transparencies[part] = part.Transparency
	end

	return transparencies
end

local function setVisiblePartsTransparency(model, transparency)
	for _, part in ipairs(getVisibleParts(model)) do
		part.Transparency = transparency
	end

	forcePrimaryInvisible(model)
end

local function tweenVisibleParts(model, transparencies, tweenInfo, fadeOut)
	for part, originalTransparency in pairs(transparencies) do
		if part and part.Parent then
			local goalTransparency = fadeOut and 1 or originalTransparency

			TweenService:Create(
				part,
				tweenInfo,
				{
					Transparency = goalTransparency,
				}
			):Play()
		end
	end

	forcePrimaryInvisible(model)
end

local function tweenModelPivot(model, startCFrame, endCFrame, tweenInfo)
	if not model or not model.Parent then
		return nil
	end

	local cframeValue = Instance.new("CFrameValue")
	cframeValue.Name = "GasterBlasterTweenCFrame"
	cframeValue.Value = startCFrame

	local connection
	connection = cframeValue:GetPropertyChangedSignal("Value"):Connect(function()
		if model and model.Parent then
			model:PivotTo(cframeValue.Value)
			forcePrimaryInvisible(model)
		end
	end)

	local tween = TweenService:Create(
		cframeValue,
		tweenInfo,
		{
			Value = endCFrame,
		}
	)

	tween.Completed:Connect(function()
		if connection then
			connection:Disconnect()
		end

		if cframeValue then
			cframeValue:Destroy()
		end

		if model and model.Parent then
			model:PivotTo(endCFrame)
			forcePrimaryInvisible(model)
		end
	end)

	tween:Play()

	return tween
end

local function fadeInBlaster(model, finalCFrame, data)
	local offset = data.FadeInOffset or CFrame.new(0, 0, 7)
	local startCFrame = finalCFrame * offset
	local fadeInTime = data.FadeInTime or 0.16

	local transparencies = capturePartTransparencies(model)
	local tweenInfo = TweenInfo.new(
		fadeInTime,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)

	model:PivotTo(startCFrame)
	setVisiblePartsTransparency(model, 1)
	forcePrimaryInvisible(model)

	tweenModelPivot(model, startCFrame, finalCFrame, tweenInfo)
	tweenVisibleParts(model, transparencies, tweenInfo, false)

	return transparencies
end

local function fadeOutBlaster(model, currentCFrame, transparencies, data)
	if not model or not model.Parent then
		return
	end

	local offset = data.FadeOutOffset or CFrame.new(0, 0, 7)
	local endCFrame = currentCFrame * offset
	local fadeOutTime = data.FadeOutTime or 0.16

	local tweenInfo = TweenInfo.new(
		fadeOutTime,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)

	tweenModelPivot(model, currentCFrame, endCFrame, tweenInfo)
	tweenVisibleParts(model, transparencies or capturePartTransparencies(model), tweenInfo, true)

	task.delay(fadeOutTime + 0.03, function()
		if model and model.Parent then
			model:Destroy()
		end
	end)
end

local function getAimDirection(root, aimPosition)
	if typeof(aimPosition) ~= "Vector3" then
		return root.CFrame.LookVector
	end

	local origin = root.Position + Vector3.new(0, 2, 0)
	local direction = aimPosition - origin

	if direction.Magnitude < 1 then
		direction = root.CFrame.LookVector
	end

	return direction.Unit
end

local function makeLookCFrame(position, direction)
	if not direction or direction.Magnitude < 0.05 then
		direction = Vector3.new(0, 0, -1)
	end

	return CFrame.lookAt(position, position + direction.Unit)
end

local function getBeamOrigin(blaster)
	local attachment = blaster:FindFirstChild("BeamOrgin", true)

	if attachment and attachment:IsA("Attachment") then
		return attachment
	end

	attachment = blaster:FindFirstChild("BeamOrigin", true)

	if attachment and attachment:IsA("Attachment") then
		return attachment
	end

	return nil
end

local function getWorldBeamPosition(blaster)
	local attachment = getBeamOrigin(blaster)

	if attachment then
		return attachment.WorldPosition
	end

	local primary = ensurePrimaryPart(blaster)

	if primary then
		return primary.Position
	end

	return blaster:GetPivot().Position
end

local function openJaws(blaster, data)
	local leftJaw = blaster:FindFirstChild("Left Jaw", true)
	local rightJaw = blaster:FindFirstChild("Right Jaw", true)

	local jawOpenTime = data.JawOpenTime or 0.18
	local jawOpenAngle = math.rad(data.JawOpenAngle or 22)

	local tweenInfo = TweenInfo.new(
		jawOpenTime,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.Out
	)

	if leftJaw and leftJaw:IsA("BasePart") then
		local goalCFrame = leftJaw.CFrame * CFrame.Angles(-jawOpenAngle, 0, 0)

		TweenService:Create(leftJaw, tweenInfo, {
			CFrame = goalCFrame,
		}):Play()
	end

	if rightJaw and rightJaw:IsA("BasePart") then
		local goalCFrame = rightJaw.CFrame * CFrame.Angles(-jawOpenAngle, 0, 0)

		TweenService:Create(rightJaw, tweenInfo, {
			CFrame = goalCFrame,
		}):Play()
	end
end

local function hideRightEye(blaster)
	local rightEye = blaster:FindFirstChild("RightEye", true)

	if rightEye and rightEye:IsA("BasePart") then
		rightEye.Transparency = 1
	end
end

local function createBeamVisual(startPosition, direction, data, isFinalTick)
	local baseLength = data.BeamLength or 90
	local length = baseLength

	if isFinalTick then
		length += data.FinalBeamExtraLength or GasterBlaster.FinalBeamExtraLength or 8
	end

	local radius = data.BeamRadius or 5.5
	local sizeMultiplier

	if isFinalTick then
		sizeMultiplier = data.FinalBeamVisualSizeMultiplier or GasterBlaster.FinalBeamVisualSizeMultiplier or 2.25
	else
		sizeMultiplier = data.BeamVisualSizeMultiplier or GasterBlaster.BeamVisualSizeMultiplier or 1.15
	end

	local visualRadius = radius * sizeMultiplier
	local fadeTime

	if isFinalTick then
		fadeTime = data.FinalBeamFadeTime or GasterBlaster.FinalBeamFadeTime or 0.18
	else
		fadeTime = data.BeamFadeTime or GasterBlaster.BeamFadeTime or 0.12
	end

	local beam = Instance.new("Part")
	beam.Name = isFinalTick and "GasterBlasterFinalBeam" or "GasterBlasterBeam"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanTouch = false
	beam.CanQuery = false
	beam.Material = Enum.Material.Neon
	beam.Color = isFinalTick and Color3.fromRGB(210, 245, 255) or Color3.fromRGB(255, 255, 255)
	beam.Transparency = isFinalTick
		and (data.FinalBeamVisualTransparency or GasterBlaster.FinalBeamVisualTransparency or 0.02)
		or (data.BeamVisualTransparency or GasterBlaster.BeamVisualTransparency or 0.24)

	beam.Size = Vector3.new(visualRadius, visualRadius, length)

	local center = startPosition + (direction.Unit * (length / 2))
	beam.CFrame = CFrame.lookAt(center, center + direction.Unit)

	beam.Parent = workspace

	if isFinalTick then
		local core = Instance.new("Part")
		core.Name = "GasterBlasterFinalBeamCore"
		core.Anchored = true
		core.CanCollide = false
		core.CanTouch = false
		core.CanQuery = false
		core.Material = Enum.Material.Neon
		core.Color = Color3.fromRGB(255, 255, 255)
		core.Transparency = 0
		core.Size = Vector3.new(visualRadius * 0.55, visualRadius * 0.55, length + 3)
		core.CFrame = beam.CFrame
		core.Parent = workspace

		TweenService:Create(
			core,
			TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Transparency = 1,
				Size = Vector3.new(visualRadius * 0.1, visualRadius * 0.1, length + 3),
			}
		):Play()

		Debris:AddItem(core, fadeTime + 0.08)
	end

	TweenService:Create(
		beam,
		TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Transparency = 1,
			Size = Vector3.new(visualRadius * 0.18, visualRadius * 0.18, length),
		}
	):Play()

	Debris:AddItem(beam, fadeTime + 0.08)
end

local function getFinalKnockbackDirection(ctx, data, targetRoot, beamDirection)
	local direction = beamDirection

	if data.UseAttackerPositionForFinalKnockback == true or data.FinalKnockbackSource == "Attacker" then
		local root = ctx.Root

		if root and root.Parent and targetRoot and targetRoot.Parent then
			local fromAttacker = targetRoot.Position - root.Position
			local flat = Vector3.new(fromAttacker.X, 0, fromAttacker.Z)

			if flat.Magnitude >= 0.05 then
				direction = flat.Unit
			end
		end
	end

	if not direction or direction.Magnitude < 0.05 then
		direction = Vector3.new(0, 0, -1)
	else
		direction = direction.Unit
	end

	return direction
end

local function applyManualFinalKnockback(ctx, data, targetRoot, beamDirection)
	if not targetRoot or not targetRoot.Parent then return end

	local direction = getFinalKnockbackDirection(ctx, data, targetRoot, beamDirection)
	local speed = data.FinalKnockback or data.Knockback or 95
	local upward = data.FinalUpwardKnockback or data.UpwardKnockback or 28
	local duration = data.FinalKnockbackDuration or data.KnockbackDuration or 0.28
	local maxForce = data.FinalKnockbackMaxForce or data.KnockbackMaxForce or 130000
	local velocity = (direction * speed) + Vector3.new(0, upward, 0)

	if ctx.MovementService and ctx.MovementService.ApplyForceKnockback then
		ctx.MovementService:ApplyForceKnockback(
			targetRoot,
			velocity,
			duration,
			maxForce,
			"GasterBlasterFinal",
			{
				EnableWallComboPrevention = data.WallComboPrevention == true,
				AttackerCharacter = ctx.Character,
			}
		)

		return
	end

	targetRoot.AssemblyLinearVelocity = velocity
end

function GasterBlaster.Execute(ctx)
	local data = ctx.MoveData
	local character = ctx.Character
	local humanoid = ctx.Humanoid
	local root = ctx.Root

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

	if not ctx.ProjectileService then
		warn("[GasterBlaster] Missing ProjectileService")
		ctx:FinishMove(0)
		return
	end

	local aimPosition = ctx.Payload and ctx.Payload.AimPosition
	local direction = getAimDirection(root, aimPosition)

	local template = getGasterBlasterTemplate(ctx)
	local blaster = template:Clone()
	blaster.Name = "ActiveGasterBlaster"

	setupBlasterParts(blaster)

	local primary = ensurePrimaryPart(blaster)

	if not primary then
		warn("[GasterBlaster] Missing PrimaryPart")
		blaster:Destroy()
		ctx:FinishMove(0)
		return
	end

	local spawnCFrame = root.CFrame * (data.SpawnOffset or CFrame.new(0, 4.5, -5.5))
	local finalCFrame = makeLookCFrame(spawnCFrame.Position, direction)

	blaster.Parent = workspace

	local originalTransparencies = fadeInBlaster(blaster, finalCFrame, data)

	playSansSFX(ctx, "EyeFlash", primary, 2)

	Debris:AddItem(blaster, data.BlasterLifetime or 2)

	task.wait(data.Startup or 0.24)

	if not ctx:IsActive() then
		fadeOutBlaster(blaster, blaster:GetPivot(), originalTransparencies, data)
		ctx:FinishMove(0)
		return
	end

	playSansSFX(ctx, "GasterBlasterCharge", primary, 3)
	playChargePolish(ctx, data)

	openJaws(blaster, data)
	forcePrimaryInvisible(blaster)

	task.wait(data.ChargeTime or 0.52)

	if not ctx:IsActive() then
		fadeOutBlaster(blaster, blaster:GetPivot(), originalTransparencies, data)
		ctx:FinishMove(0)
		return
	end

	local beamStart = getWorldBeamPosition(blaster)

	playSansSFX(ctx, "GasterBlasterShoot", primary, 3)
	playFirePolish(ctx, data)

	hideRightEye(blaster)
	forcePrimaryInvisible(blaster)

	local beamTickCount = 0
	local expectedTicks = math.max(
		1,
		math.ceil((data.BeamActiveTime or 0.4) / math.max(data.BeamTickRate or 0.08, 0.01))
	)

	local finalBeamPolishPlayed = false
	local hitPolishLastPlayed = {}

	-- Tracks anyone guardbroken by this beam. If they are guardbroken,
	-- the final tick will NOT launch them, so Sans can combo extend.
	local guardbrokenTargets = {}
	local finalKnockbackApplied = {}
	local currentBeamTickIsFinal = false

	local beamAttackData = {}

	for key, value in pairs(data) do
		beamAttackData[key] = value
	end

	beamAttackData.Guardbreak = data.Guardbreak == true
	beamAttackData.GuardbreakFinalOnly = data.GuardbreakFinalOnly ~= false
	beamAttackData.HitCancelsTarget = false

	-- Important:
	-- ProjectileService normally applies beam knockback inside ApplyProjectileHit.
	-- We zero it here and manually apply final knockback only to targets that were NOT guardbroken.
	beamAttackData.Knockback = 0
	beamAttackData.UpwardKnockback = 0
	beamAttackData.FinalKnockback = 0
	beamAttackData.FinalUpwardKnockback = 0

	ctx.ProjectileService:RunBeam({
		OwnerCharacter = character,
		BeamStartPosition = beamStart,
		Direction = direction,
		BeamDirection = direction,
		KnockbackDirection = direction,

		AttackData = beamAttackData,
		AttackName = ctx.MoveId or "GasterBlaster",

		BeamLength = data.BeamLength or 90,
		BeamRadius = data.BeamRadius or 5.5,
		BeamStep = data.BeamStep or 6,
		BeamActiveTime = data.BeamActiveTime or 0.4,
		BeamTickRate = data.BeamTickRate or 0.08,

		IsActive = function()
			return ctx:IsActive()
		end,

		OnBeamTick = function()
			beamTickCount += 1

			local isFinalTick = beamTickCount >= expectedTicks
			currentBeamTickIsFinal = isFinalTick

			createBeamVisual(beamStart, direction, data, isFinalTick)

			if isFinalTick and not finalBeamPolishPlayed then
				finalBeamPolishPlayed = true
				playFinalBeamPolish(ctx, data, beamStart)
			end
		end,

		OnBeamHit = function(targetCharacter, targetHumanoid, targetRoot, result)
			if result == "Guardbreak" then
				guardbrokenTargets[targetCharacter] = true
			end

			if currentBeamTickIsFinal
				and result == "Hit"
				and not guardbrokenTargets[targetCharacter]
				and not finalKnockbackApplied[targetCharacter]
			then
				finalKnockbackApplied[targetCharacter] = true
				applyManualFinalKnockback(ctx, data, targetRoot, direction)
			end

			local now = os.clock()
			local lastPlayed = hitPolishLastPlayed[targetCharacter] or 0

			if now - lastPlayed >= 0.12 then
				hitPolishLastPlayed[targetCharacter] = now
				playBeamHitPolish(ctx, data, targetCharacter, result)
			end
		end,
	})

	task.delay(0.08, function()
		if blaster and blaster.Parent then
			fadeOutBlaster(blaster, blaster:GetPivot(), originalTransparencies, data)
		end
	end)

	ctx:FinishMove(0.12)
end

return GasterBlaster
