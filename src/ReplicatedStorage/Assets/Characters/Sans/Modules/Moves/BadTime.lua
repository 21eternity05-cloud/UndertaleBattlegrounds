local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local BLOCK_MODE_NORMAL = "Normal"
local BLOCK_MODE_ALL_ROUND = "AllRound"

local BadTime = {
	DisplayName = "Bad Time",
	AnimationName = "BadTime",

	Cooldown = 1,
	Duration = 25,
	LockTime = 25,
	MaxLockTime = 25,

	RequiresTarget = true,
	RequiresAim = false,

	WarningTime = 0.8,
	ConfirmRange = 80,

	SequenceTime = 25,

	Blockable = true,
	CanBeBlocked = true,
	IgnoreBlockDirection = true,
	Unblockable = false,
	Guardbreak = false,
	CanBeCountered = true,
	HitCancelsTarget = true,
	CancelableByHit = false,

	HasIFrames = true,
	IFrameStart = 0,
	IFrameEnd = 25,

	HasArmor = true,
	ArmorStart = 0,
	ArmorEnd = 25,
	ArmorDamageReduction = 1,
	ArmorPreventsStun = true,
	ArmorPreventsKnockback = true,
	ArmorPreventsHitCancel = true,

	BoneShotCount = 18,
	BoneShotDamage = 1,
	BoneShotRadius = 7.5,
	BoneShotSpawnMinRadius = 38,
	BoneShotSpawnMaxRadius = 52,
	BoneShotTravelTime = 0.34,

	BoneZoneCount = 4,
	BoneZoneDamage = 4,

	BoneWallCount = 8,
	BoneWallDamage = 4,
	BoneWallFireInterval = 0.4,
	BoneWallTravelTime = 0.48,

	BlasterCircleRounds = 6,
	BlasterRingCount = 14,
	BlasterDamage = 2,
	BlasterScale = 1,
	BlasterChargeTime = 0.52,
	BlasterShotInterval = 0.055,
	BlasterBeamRadius = 5.2,
	BlasterBeamStep = 6,
	BlasterBeamLength = 78,
	BlasterSpawnRadius = 36,

	BlasterSpawnTweenTime = 0.12,
	BlasterFadeOutTime = 0.16,
	BlasterMoveInDistance = 6,
	BlasterMoveOutDistance = 7,

	GiantBlasterDamage = 6,
	GiantBlasterScale = 2.2,
	GiantBlasterChargeTime = 0.72,
	GiantBlasterBeamRadius = 9,
	GiantBlasterBeamStep = 7,
	GiantBlasterBeamLength = 120,
	GiantBlasterSpawnTweenTime = 0.18,
	GiantBlasterMoveInDistance = 8,
	GiantBlasterMoveOutDistance = 10,
	GiantBlasterSpawnRadius = 36,

	GravitySpamTotalDamage = 10,
	FinalSlamDamage = 35,

	-- Bad Time transition cut timing.
	-- Undertale-style: instant black, teleport cue, instant unblack, teleport cue.
	TransitionBlackTime = 0.14,

	-- Consistent Sans polish.
	SequenceHitVictimShakeMagnitude = 0.45,
	SequenceHitVictimShakeRoughness = 8,
	SequenceHitVictimShakeDuration = 0.09,

	SequenceBlockVictimShakeMagnitude = 0.3,
	SequenceBlockVictimShakeRoughness = 6,
	SequenceBlockVictimShakeDuration = 0.07,

	BoneZoneEruptionShakeMagnitude = 0.85,
	BoneZoneEruptionShakeRoughness = 9,
	BoneZoneEruptionShakeDuration = 0.14,

	BoneWallHitVictimShakeMagnitude = 0.6,
	BoneWallHitVictimShakeRoughness = 9,
	BoneWallHitVictimShakeDuration = 0.11,

	BlasterChargeAttackerShakeMagnitude = 0.25,
	BlasterChargeAttackerShakeRoughness = 6,
	BlasterChargeAttackerShakeDuration = 0.08,

	BlasterFireVictimShakeMagnitude = 0.55,
	BlasterFireVictimShakeRoughness = 8,
	BlasterFireVictimShakeDuration = 0.1,

	GiantBlasterFireVictimShakeMagnitude = 1.05,
	GiantBlasterFireVictimShakeRoughness = 12,
	GiantBlasterFireVictimShakeDuration = 0.18,

	BeamVisualTransparency = 0.18,
	BeamVisualSizeMultiplier = 1.25,
	BeamFadeTime = 0.18,

	GiantBeamVisualTransparency = 0.06,
	GiantBeamVisualSizeMultiplier = 1.85,
	GiantBeamFadeTime = 0.22,

	FinalRingBeamVisualTransparency = 0.015,
	FinalRingBeamVisualSizeMultiplier = 2.5,
	FinalRingBeamFadeTime = 0.25,
	FinalRingBeamExtraLength = 10,

	FinalRingBeamAttackerShakeMagnitude = 1.35,
	FinalRingBeamAttackerShakeRoughness = 14,
	FinalRingBeamAttackerShakeDuration = 0.24,

	FinalRingBeamVictimShakeMagnitude = 1.8,
	FinalRingBeamVictimShakeRoughness = 16,
	FinalRingBeamVictimShakeDuration = 0.28,

	FinalRingBeamImpactFrameDuration = 0.06,

	GravitySpamShakeMagnitude = 0.7,
	GravitySpamShakeRoughness = 9,
	GravitySpamShakeDuration = 0.12,

	FinalSlamAttackerShakeMagnitude = 2.2,
	FinalSlamAttackerShakeRoughness = 16,
	FinalSlamAttackerShakeDuration = 0.35,

	FinalSlamVictimShakeMagnitude = 3.2,
	FinalSlamVictimShakeRoughness = 20,
	FinalSlamVictimShakeDuration = 0.45,

	FinalSlamImpactFrameDuration = 0.09,

	AwardsUlt = false,
}

local function getSansVFXFolder(ctx)
	local assets = ReplicatedStorage:WaitForChild(ctx.Config.AssetsFolderName or "Assets")
	local characters = assets:WaitForChild(ctx.Config.CharactersFolderName or "Characters")
	local sans = characters:WaitForChild("Sans")

	return sans:WaitForChild("VFX")
end

local function getVFXTemplate(ctx, name)
	local folder = getSansVFXFolder(ctx)
	local template = folder:FindFirstChild(name)

	if not template then
		warn("[BadTime] Missing Sans VFX:", name)
		return nil
	end

	return template
end

local function getScreenEffectRemote()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")

	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	local remote = remotes:FindFirstChild("ScreenEffectRemote")

	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "ScreenEffectRemote"
		remote.Parent = remotes
	end

	return remote
end

local function getPlayerFromCharacter(character)
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character == character then
			return player
		end
	end

	return nil
end

local function fireScreenEffect(character, effectNameOrPayload)
	local player = getPlayerFromCharacter(character)
	if not player then
		return
	end

	getScreenEffectRemote():FireClient(player, effectNameOrPayload)
end

local function playSansSFX(ctx, soundName, parentPart, lifetime)
	if not ctx.VFXService then
		return
	end
	if not ctx.VFXService.PlayCharacterSFXAtPart then
		return
	end
	if not parentPart or not parentPart.Parent then
		return
	end

	ctx.VFXService:PlayCharacterSFXAtPart("Sans", soundName, parentPart, lifetime or 3)
end

local function playSansMoveVFX(ctx, moveName, targetCharacter, targetRoot)
	if not ctx.VFXService then
		return
	end
	if not ctx.VFXService.PlayCharacterMoveVFX then
		return
	end

	ctx.VFXService:PlayCharacterMoveVFX(ctx.Character, moveName, targetCharacter, targetRoot)
end

local function shakeCharacter(ctx, targetCharacter, magnitude, roughness, duration)
	if not targetCharacter or not targetCharacter.Parent then return end
	if not ctx.CinematicService then return end
	if not ctx.CinematicService.ShakeOnce then return end

	pcall(function()
		ctx.CinematicService:ShakeOnce(targetCharacter, magnitude, roughness, duration)
	end)
end

local function impactFrame(ctx, targetCharacter, duration)
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

local function playSequenceDamagePolish(ctx, targetCharacter, blockMode)
	local data = ctx.MoveData or BadTime

	local magnitude = data.SequenceHitVictimShakeMagnitude or BadTime.SequenceHitVictimShakeMagnitude or 0.45
	local roughness = data.SequenceHitVictimShakeRoughness or BadTime.SequenceHitVictimShakeRoughness or 8
	local duration = data.SequenceHitVictimShakeDuration or BadTime.SequenceHitVictimShakeDuration or 0.09

	if blockMode == BLOCK_MODE_ALL_ROUND then
		magnitude *= 1.1
		duration *= 1.1
	end

	shakeCharacter(ctx, targetCharacter, magnitude, roughness, duration)
end

local function playSequenceBlockPolish(ctx, targetCharacter)
	local data = ctx.MoveData or BadTime

	shakeCharacter(
		ctx,
		targetCharacter,
		data.SequenceBlockVictimShakeMagnitude or BadTime.SequenceBlockVictimShakeMagnitude or 0.3,
		data.SequenceBlockVictimShakeRoughness or BadTime.SequenceBlockVictimShakeRoughness or 6,
		data.SequenceBlockVictimShakeDuration or BadTime.SequenceBlockVictimShakeDuration or 0.07
	)
end

local function playBoneZoneEruptionPolish(ctx, targetCharacter)
	local data = ctx.MoveData or BadTime

	shakeCharacter(
		ctx,
		targetCharacter,
		data.BoneZoneEruptionShakeMagnitude or BadTime.BoneZoneEruptionShakeMagnitude or 0.85,
		data.BoneZoneEruptionShakeRoughness or BadTime.BoneZoneEruptionShakeRoughness or 9,
		data.BoneZoneEruptionShakeDuration or BadTime.BoneZoneEruptionShakeDuration or 0.14
	)
end

local function playBlasterChargePolish(ctx, giant)
	local data = ctx.MoveData or BadTime

	local magnitude = data.BlasterChargeAttackerShakeMagnitude or BadTime.BlasterChargeAttackerShakeMagnitude or 0.25
	local roughness = data.BlasterChargeAttackerShakeRoughness or BadTime.BlasterChargeAttackerShakeRoughness or 6
	local duration = data.BlasterChargeAttackerShakeDuration or BadTime.BlasterChargeAttackerShakeDuration or 0.08

	if giant then
		magnitude *= 1.7
		duration *= 1.35
	end

	shakeCharacter(ctx, ctx.Character, magnitude, roughness, duration)
end

local function playBlasterHitPolish(ctx, targetCharacter, giant, finalPulse)
	local data = ctx.MoveData or BadTime

	if finalPulse then
		shakeCharacter(
			ctx,
			ctx.Character,
			data.FinalRingBeamAttackerShakeMagnitude or BadTime.FinalRingBeamAttackerShakeMagnitude or 1.35,
			data.FinalRingBeamAttackerShakeRoughness or BadTime.FinalRingBeamAttackerShakeRoughness or 14,
			data.FinalRingBeamAttackerShakeDuration or BadTime.FinalRingBeamAttackerShakeDuration or 0.24
		)

		shakeCharacter(
			ctx,
			targetCharacter,
			data.FinalRingBeamVictimShakeMagnitude or BadTime.FinalRingBeamVictimShakeMagnitude or 1.8,
			data.FinalRingBeamVictimShakeRoughness or BadTime.FinalRingBeamVictimShakeRoughness or 16,
			data.FinalRingBeamVictimShakeDuration or BadTime.FinalRingBeamVictimShakeDuration or 0.28
		)

		impactFrame(ctx, ctx.Character, data.FinalRingBeamImpactFrameDuration or BadTime.FinalRingBeamImpactFrameDuration or 0.06)
		impactFrame(ctx, targetCharacter, data.FinalRingBeamImpactFrameDuration or BadTime.FinalRingBeamImpactFrameDuration or 0.06)

		return
	end

	if giant then
		shakeCharacter(
			ctx,
			targetCharacter,
			data.GiantBlasterFireVictimShakeMagnitude or BadTime.GiantBlasterFireVictimShakeMagnitude or 1.05,
			data.GiantBlasterFireVictimShakeRoughness or BadTime.GiantBlasterFireVictimShakeRoughness or 12,
			data.GiantBlasterFireVictimShakeDuration or BadTime.GiantBlasterFireVictimShakeDuration or 0.18
		)

		return
	end

	shakeCharacter(
		ctx,
		targetCharacter,
		data.BlasterFireVictimShakeMagnitude or BadTime.BlasterFireVictimShakeMagnitude or 0.55,
		data.BlasterFireVictimShakeRoughness or BadTime.BlasterFireVictimShakeRoughness or 8,
		data.BlasterFireVictimShakeDuration or BadTime.BlasterFireVictimShakeDuration or 0.1
	)
end

local function playGravitySpamPolish(ctx, targetCharacter)
	local data = ctx.MoveData or BadTime

	shakeCharacter(
		ctx,
		targetCharacter,
		data.GravitySpamShakeMagnitude or BadTime.GravitySpamShakeMagnitude or 0.7,
		data.GravitySpamShakeRoughness or BadTime.GravitySpamShakeRoughness or 9,
		data.GravitySpamShakeDuration or BadTime.GravitySpamShakeDuration or 0.12
	)
end

local function playFinalSlamPolish(ctx, targetCharacter)
	local data = ctx.MoveData or BadTime

	shakeCharacter(
		ctx,
		ctx.Character,
		data.FinalSlamAttackerShakeMagnitude or BadTime.FinalSlamAttackerShakeMagnitude or 2.2,
		data.FinalSlamAttackerShakeRoughness or BadTime.FinalSlamAttackerShakeRoughness or 16,
		data.FinalSlamAttackerShakeDuration or BadTime.FinalSlamAttackerShakeDuration or 0.35
	)

	shakeCharacter(
		ctx,
		targetCharacter,
		data.FinalSlamVictimShakeMagnitude or BadTime.FinalSlamVictimShakeMagnitude or 3.2,
		data.FinalSlamVictimShakeRoughness or BadTime.FinalSlamVictimShakeRoughness or 20,
		data.FinalSlamVictimShakeDuration or BadTime.FinalSlamVictimShakeDuration or 0.45
	)

	impactFrame(ctx, ctx.Character, data.FinalSlamImpactFrameDuration or BadTime.FinalSlamImpactFrameDuration or 0.09)
	impactFrame(ctx, targetCharacter, data.FinalSlamImpactFrameDuration or BadTime.FinalSlamImpactFrameDuration or 0.09)
end

local function setReservedVictim(character, victimCharacter)
	if not character then return nil end

	local value = character:FindFirstChild("ReservedVictim")

	if not value then
		value = Instance.new("ObjectValue")
		value.Name = "ReservedVictim"
		value.Parent = character
	end

	value.Value = victimCharacter
	return value
end

local function clearReservedVictim(character, expectedVictim)
	if not character then return end

	local value = character:FindFirstChild("ReservedVictim")
	if not value then return end

	if expectedVictim and value.Value ~= expectedVictim then
		return
	end

	value.Value = nil
end

local function isReservedVictim(ctx, targetCharacter)
	local reservedTarget = ctx and ctx.BadTimeReservedTargetCharacter

	if not reservedTarget then
		if ctx and ctx.BadTimeHadReservedTarget then
			return false
		end

		return true
	end
	if targetCharacter ~= reservedTarget then
		return false
	end

	local value = ctx.Character and ctx.Character:FindFirstChild("ReservedVictim")

	if value and value.Value ~= reservedTarget then
		return false
	end

	return true
end

local function setBeatdownBlockPermission(targetCharacter, token, isAllowed)
	if not targetCharacter or not targetCharacter.Parent then
		return
	end

	targetCharacter:SetAttribute("BadTimeBlockPermissionToken", token)
	targetCharacter:SetAttribute("AllowBlockWhileDamageLocked", isAllowed == true)
end

local function clearBeatdownBlockPermission(targetCharacter, token)
	if not targetCharacter or not targetCharacter.Parent then
		return
	end
	if token and targetCharacter:GetAttribute("BadTimeBlockPermissionToken") ~= token then
		return
	end

	targetCharacter:SetAttribute("AllowBlockWhileDamageLocked", false)
	targetCharacter:SetAttribute("BadTimeBlockPermissionToken", nil)
end

local function forceStopBlocking(ctx, targetCharacter)
	if not targetCharacter or not targetCharacter.Parent then
		return
	end

	local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)

	if targetPlayer and ctx.BlockService and ctx.BlockService.SetBlocking then
		ctx.BlockService:SetBlocking(targetPlayer, false)
		return
	end

	targetCharacter:SetAttribute("BlockHeld", false)
	targetCharacter:SetAttribute("Blocking", false)

	if ctx.StateService and ctx.StateService.StopBlockingVisuals then
		ctx.StateService:StopBlockingVisuals(targetCharacter)
	end
end

local function setupWorldObject(object)
	if not object then
		return
	end

	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end

	if object:IsA("BasePart") then
		object.Anchored = true
		object.CanCollide = false
		object.CanTouch = false
		object.CanQuery = false
		object.Massless = true
	end
end

local function ensurePrimaryPart(model)
	if not model or not model:IsA("Model") then
		return nil
	end

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

local function forcePrimaryInvisible(model)
	if not model or not model:IsA("Model") then
		return
	end

	local primary = ensurePrimaryPart(model)

	if primary then
		primary.Transparency = 1
		primary.CanCollide = false
		primary.CanTouch = false
		primary.CanQuery = false
	end
end

local function pivotObject(object, cframe)
	if not object then
		return
	end

	if object:IsA("Model") then
		ensurePrimaryPart(object)
		object:PivotTo(cframe)
	elseif object:IsA("BasePart") then
		object.CFrame = cframe
	end
end

local function getVisualParts(object)
	local parts = {}

	if object:IsA("BasePart") then
		table.insert(parts, object)
		return parts
	end

	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name ~= "PrimaryPart" then
			table.insert(parts, descendant)
		end
	end

	return parts
end

local function fadeOutObject(object, fadeTime)
	if not object or not object.Parent then
		return
	end

	fadeTime = fadeTime or 0.15

	for _, part in ipairs(getVisualParts(object)) do
		TweenService:Create(part, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 1,
		}):Play()
	end

	if object:IsA("Model") then
		forcePrimaryInvisible(object)
	end

	Debris:AddItem(object, fadeTime + 0.08)
end

local function emitAttachmentToPart(template, part, lifetime, name, keepEnabled)
	if not template or not part or not part.Parent then
		return nil
	end

	if not template:IsA("Attachment") then
		warn("[BadTime] Expected Attachment VFX:", template.Name)
		return nil
	end

	local attachment = template:Clone()
	attachment.Name = name or ("Active" .. template.Name)
	attachment.Parent = part

	for _, descendant in ipairs(attachment:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = keepEnabled == true

			local emitCount = descendant:GetAttribute("EmitCount")
			if typeof(emitCount) ~= "number" then
				emitCount = 1
			end

			descendant:Emit(emitCount)
		end
	end

	if lifetime then
		Debris:AddItem(attachment, lifetime)
	end

	return attachment
end

local function startHeadAttachment(ctx, character, templateName, lifetime, keepEnabled)
	local template = getVFXTemplate(ctx, templateName)
	if not template then
		return nil
	end

	local head = character and character:FindFirstChild("Head")
	if not head then
		warn("[BadTime] Missing Head for:", templateName)
		return nil
	end

	return emitAttachmentToPart(template, head, lifetime, "Active" .. templateName, keepEnabled)
end

local function getVictim(ctx)
	local reservedTarget = ctx and ctx.BadTimeReservedTargetCharacter

	if reservedTarget then
		if not reservedTarget.Parent then
			return nil, nil, nil
		end
		if not isReservedVictim(ctx, reservedTarget) then
			return nil, nil, nil
		end

		local humanoid = reservedTarget:FindFirstChildOfClass("Humanoid")
		local root = reservedTarget:FindFirstChild("HumanoidRootPart")

		if not humanoid or not root or humanoid.Health <= 0 then
			return nil, nil, nil
		end

		return reservedTarget, humanoid, root
	end
	if ctx and ctx.BadTimeHadReservedTarget then
		return nil, nil, nil
	end

	local targetCharacter, targetHumanoid, targetRoot = ctx:GetValidTarget()

	if not targetCharacter or not targetHumanoid or not targetRoot then
		return nil, nil, nil
	end

	if targetHumanoid.Health <= 0 then
		return nil, nil, nil
	end

	return targetCharacter, targetHumanoid, targetRoot
end

local function makeConfirmAttackData(data)
	local attackData = {}

	for key, value in pairs(data) do
		attackData[key] = value
	end

	attackData.AttackType = "UltimateConfirm"
	attackData.Damage = 0
	attackData.Stun = 0
	attackData.Knockback = 0
	attackData.UpwardKnockback = 0

	attackData.Blockable = true
	attackData.CanBeBlocked = true
	attackData.IgnoreBlockDirection = true
	attackData.AllRoundBlock = true
	attackData.Unblockable = false
	attackData.Guardbreak = false
	attackData.CanBeCountered = true
	attackData.HitCancelsTarget = true
	attackData.PlayMoveHitVFX = false
	attackData.AwardsUlt = false

	return attackData
end

local function wouldBlockFromPosition(ctx, targetCharacter, targetRoot, sourcePosition, attackData)
	if not targetCharacter or not targetRoot then
		return false
	end
	if not ctx.BlockService then
		return false
	end
	if not ctx.BlockService.CanBlockHit then
		return false
	end

	local blockSource = {
		Position = sourcePosition,
	}

	if ctx.BlockService:CanBlockHit(targetCharacter, blockSource, attackData) then
		if ctx.BlockService.PlayBlockVFX then
			ctx.BlockService:PlayBlockVFX(targetRoot)
		end

		return true
	end

	return false
end

local function canDamageTarget(ctx, targetCharacter)
	if not ctx or not targetCharacter then
		return false
	end

	if
		ctx.CombatStatusService
		and ctx.CombatStatusService.IsDamageLockedFromAttacker
		and ctx.CombatStatusService:IsDamageLockedFromAttacker(targetCharacter, ctx.Character)
	then
		return false
	end

	return true
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

	if ctx.ReportNoUltDamage and awardsUlt == false then
		ctx:ReportNoUltDamage(targetCharacter, targetRoot, damage)
		return
	end

	if ctx.GrabService and ctx.GrabService.ReportNoUltDamage and awardsUlt == false then
		ctx.GrabService:ReportNoUltDamage(ctx.Character, targetCharacter, targetRoot, damage)
		return
	end

	if ctx.DamageNumberService and targetRoot then
		ctx.DamageNumberService:ShowDamage(targetRoot, damage, {
			TextSize = 46,
		})
	end

	if awardsUlt then
		if ctx.ReportDamageEvent then
			ctx:ReportDamageEvent(targetCharacter, damage, targetRoot)
		elseif ctx.UltService and ctx.UltService.AwardDamageEvent then
			ctx.UltService:AwardDamageEvent(ctx.Character, targetCharacter, damage)
		end

		return
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

local function nonlethalDamage(ctx, targetCharacter, targetHumanoid, targetRoot, damage)
	if not targetCharacter or not targetCharacter.Parent then
		return
	end
	if not isReservedVictim(ctx, targetCharacter) then
		return
	end
	if not targetHumanoid or targetHumanoid.Health <= 0 then
		return
	end
	if not canDamageTarget(ctx, targetCharacter) then
		return
	end

	damage = damage or 0

	if damage <= 0 then
		return
	end

	targetHumanoid.Health = math.max(1, targetHumanoid.Health - damage)

	reportDamage(ctx, targetCharacter, targetRoot, damage)
end

local function lethalDamage(ctx, targetCharacter, targetHumanoid, targetRoot, damage)
	if not targetCharacter or not targetCharacter.Parent then
		return
	end
	if not isReservedVictim(ctx, targetCharacter) then
		return
	end
	if not targetHumanoid or targetHumanoid.Health <= 0 then
		return
	end
	if not canDamageTarget(ctx, targetCharacter) then
		return
	end

	damage = damage or 999

	targetHumanoid:TakeDamage(damage)
	reportDamage(ctx, targetCharacter, targetRoot, damage)
end

local function makeSequenceAttackData(blockMode)
	local isAllRoundBlock = blockMode == BLOCK_MODE_ALL_ROUND

	return {
		Blockable = true,
		CanBeBlocked = true,
		Unblockable = false,

		-- All-round block ignores facing direction. Normal block uses front-block checks.
		IgnoreBlockDirection = isAllRoundBlock,
		AllRoundBlock = isAllRoundBlock,

		Guardbreak = false,
		CanBeCountered = false,
		AwardsUlt = false,
	}
end

local function makeNormalBlockableAttackData()
	return makeSequenceAttackData(BLOCK_MODE_NORMAL)
end

local function makeAllRoundBlockableAttackData()
	return makeSequenceAttackData(BLOCK_MODE_ALL_ROUND)
end

local function blockableSequenceDamage(
	ctx,
	targetCharacter,
	targetHumanoid,
	targetRoot,
	sourcePosition,
	damage,
	blockMode
)
	if not isReservedVictim(ctx, targetCharacter) then
		return false
	end
	if not canDamageTarget(ctx, targetCharacter) then
		return false
	end

	local attackData

	if blockMode == BLOCK_MODE_ALL_ROUND then
		attackData = makeAllRoundBlockableAttackData()
	else
		attackData = makeNormalBlockableAttackData()
	end

	if wouldBlockFromPosition(ctx, targetCharacter, targetRoot, sourcePosition, attackData) then
		playSequenceBlockPolish(ctx, targetCharacter)
		return false
	end

	nonlethalDamage(ctx, targetCharacter, targetHumanoid, targetRoot, damage)

	if ctx.VFXService then
		ctx.VFXService:EmitHitVFXOnVictim(targetRoot, ctx.Character)
	end

	playSequenceDamagePolish(ctx, targetCharacter, blockMode)

	return true
end

local function teleportVictimToSpot(ctx, targetRoot, victimSpotCFrame)
	if not targetRoot or not targetRoot.Parent then
		return
	end

	local targetCharacter = targetRoot.Parent
	local transitionTime = 0.14

	if ctx and ctx.MoveData and typeof(ctx.MoveData.TransitionBlackTime) == "number" then
		transitionTime = math.max(0, ctx.MoveData.TransitionBlackTime)
	end

	-- Bad Time / Undertale-style transition:
	-- instant black screen + Teleport sound,
	-- move victim while black,
	-- instant unblack + same Teleport sound.
	fireScreenEffect(targetCharacter, "BlackScreen")
	playSansSFX(ctx, "Teleport", targetRoot, 2)

	task.wait(transitionTime)

	if not ctx:IsActive() then
		fireScreenEffect(targetCharacter, "BlackScreenEnd")
		playSansSFX(ctx, "Teleport", targetRoot, 2)
		return
	end

	if not targetRoot or not targetRoot.Parent then
		fireScreenEffect(targetCharacter, "BlackScreenEnd")
		return
	end

	targetRoot.AssemblyLinearVelocity = Vector3.zero
	targetRoot.AssemblyAngularVelocity = Vector3.zero
	targetRoot.CFrame = victimSpotCFrame

	fireScreenEffect(targetCharacter, "BlackScreenEnd")
	playSansSFX(ctx, "Teleport", targetRoot, 2)
end

local function cloneM1Bone(ctx)
	local template = getVFXTemplate(ctx, "M1Bone")
	if not template then
		return nil
	end

	local bone = template:Clone()
	bone.Name = "BadTimeBoneShot"

	setupWorldObject(bone)

	if bone:IsA("Model") then
		ensurePrimaryPart(bone)
		forcePrimaryInvisible(bone)
	end

	bone.Parent = workspace
	Debris:AddItem(bone, 2)

	return bone
end

local function spawnBoneShotAtVictim(ctx, data, index, count)
	if not ctx:IsActive() then
		return
	end

	local targetCharacter, targetHumanoid, targetRoot = getVictim(ctx)
	if not targetCharacter then
		return
	end

	local bone = cloneM1Bone(ctx)
	if not bone then
		return
	end

	local angle = math.rad((360 / math.max(count, 1)) * index + math.random(-12, 12))
	local radius = math.random(data.BoneShotSpawnMinRadius or 38, data.BoneShotSpawnMaxRadius or 52)
	local height = math.random(9, 14)

	local targetPosition = targetRoot.Position + Vector3.new(0, 1.4, 0)
	local startPosition = targetRoot.Position + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)

	local startCFrame = CFrame.lookAt(startPosition, targetPosition)
	local endCFrame = CFrame.lookAt(targetPosition, targetPosition + (targetPosition - startPosition).Unit)

	pivotObject(bone, startCFrame)

	playSansSFX(ctx, "Summon", targetRoot, 2)

	local cframeValue = Instance.new("CFrameValue")
	cframeValue.Value = startCFrame

	local connection
	connection = cframeValue:GetPropertyChangedSignal("Value"):Connect(function()
		if bone and bone.Parent then
			pivotObject(bone, cframeValue.Value)

			if bone:IsA("Model") then
				forcePrimaryInvisible(bone)
			end
		end
	end)

	local tween = TweenService:Create(
		cframeValue,
		TweenInfo.new(data.BoneShotTravelTime or 0.34, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Value = endCFrame,
		}
	)

	tween:Play()

	tween.Completed:Connect(function()
		if connection then
			connection:Disconnect()
		end

		cframeValue:Destroy()

		if not ctx:IsActive() then
			fadeOutObject(bone, 0.08)
			return
		end

		local hitOnce = false

		ctx.HitboxService:PerformSphereAtPosition(
			ctx.Character,
			targetPosition,
			data.BoneShotRadius or 7.5,
			function(hitCharacter, hitHumanoid, hitRoot)
				if not ctx:IsActive() then
					return
				end
				if not isReservedVictim(ctx, hitCharacter) then
					return
				end
				if hitOnce then
					return
				end
				hitOnce = true

				blockableSequenceDamage(
					ctx,
					hitCharacter,
					hitHumanoid,
					hitRoot,
					startPosition,
					data.BoneShotDamage or 1,
					BLOCK_MODE_NORMAL
				)
			end
		)

		playSansSFX(ctx, "M1", targetRoot, 2)
		fadeOutObject(bone, 0.08)
	end)
end

local function spawnBoneZoneAtVictim(ctx, data)
	if not ctx:IsActive() then
		return
	end

	local targetCharacter, targetHumanoid, targetRoot = getVictim(ctx)
	if not targetCharacter then
		return
	end

	local template = getVFXTemplate(ctx, "BoneZone")
	if not template then
		return
	end

	local zoneModel = template:Clone()
	zoneModel.Name = "BadTimeBoneZone"

	setupWorldObject(zoneModel)

	local position = targetRoot.Position - Vector3.new(0, 2.7, 0)
	local cframe = CFrame.new(position)

	zoneModel.Parent = workspace
	pivotObject(zoneModel, cframe)

	playSansSFX(ctx, "BoneZoneWarning", targetRoot, 2)

	task.wait(0.34)

	if not ctx:IsActive() then
		fadeOutObject(zoneModel, 0.16)
		return
	end

	if not zoneModel.Parent then
		return
	end

	playSansSFX(ctx, "BoneUp", targetRoot, 2)
	playBoneZoneEruptionPolish(ctx, targetCharacter)

	local bones = zoneModel:FindFirstChild("Bones", true)

	if bones and bones:IsA("Model") then
		ensurePrimaryPart(bones)

		local startCFrame = cframe + Vector3.new(0, -7, 0)
		local endCFrame = cframe

		pivotObject(bones, startCFrame)

		local cframeValue = Instance.new("CFrameValue")
		cframeValue.Value = startCFrame

		local connection
		connection = cframeValue:GetPropertyChangedSignal("Value"):Connect(function()
			if bones and bones.Parent then
				pivotObject(bones, cframeValue.Value)
			end
		end)

		local tween =
			TweenService:Create(cframeValue, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Value = endCFrame,
			})

		tween:Play()

		tween.Completed:Connect(function()
			if connection then
				connection:Disconnect()
			end

			cframeValue:Destroy()
		end)
	end

	local hitOnce = false

	ctx.HitboxService:PerformSphereAtPosition(ctx.Character, position, 10, function(hitCharacter, hitHumanoid, hitRoot)
		if not ctx:IsActive() then
			return
		end
		if not isReservedVictim(ctx, hitCharacter) then
			return
		end
		if hitOnce then
			return
		end
		hitOnce = true

		blockableSequenceDamage(ctx, hitCharacter, hitHumanoid, hitRoot, position, data.BoneZoneDamage or 4, BLOCK_MODE_ALL_ROUND)
	end)

	task.delay(0.5, function()
		fadeOutObject(zoneModel, 0.16)
	end)

	Debris:AddItem(zoneModel, 1.2)
end

local function spawnTrackingBoneWall(ctx, data, sideIndex)
	if not ctx:IsActive() then
		return
	end

	local template = getVFXTemplate(ctx, "BoneWall")
	if not template then
		return
	end

	local targetCharacter, targetHumanoid, targetRoot = getVictim(ctx)
	if not targetCharacter then
		return
	end

	local wall = template:Clone()
	wall.Name = "BadTimeTrackingBoneWall"

	setupWorldObject(wall)

	if wall:IsA("Model") then
		ensurePrimaryPart(wall)
		forcePrimaryInvisible(wall)
	end

	wall.Parent = workspace

	playSansSFX(ctx, "BoneUp", targetRoot, 2)

	local duration = data.BoneWallTravelTime or 0.48
	local startTime = os.clock()
	local hitDone = false

	local baseAngle = math.rad((sideIndex - 1) * 180)
	local angle = baseAngle + math.rad(math.random(-15, 15))
	local sideDirection = Vector3.new(math.cos(angle), 0, math.sin(angle)).Unit

	local function getWallCFrame(alpha)
		local _, _, currentRoot = getVictim(ctx)

		if not currentRoot then
			return wall:GetPivot()
		end

		local center = currentRoot.Position

		local startPosition = center + (sideDirection * 22) + Vector3.new(0, -4.8, 0)
		local peakPosition = center + (sideDirection * 7) + Vector3.new(0, 3.8, 0)
		local endPosition = center - (sideDirection * 10) + Vector3.new(0, -5.2, 0)

		local first = startPosition:Lerp(peakPosition, alpha)
		local second = peakPosition:Lerp(endPosition, alpha)
		local position = first:Lerp(second, alpha)

		return CFrame.lookAt(position, center)
	end

	while os.clock() - startTime < duration do
		if not ctx:IsActive() then
			fadeOutObject(wall, 0.1)
			return
		end

		local alpha = math.clamp((os.clock() - startTime) / duration, 0, 1)
		local easedAlpha = 1 - ((1 - alpha) * (1 - alpha))
		local wallCFrame = getWallCFrame(easedAlpha)

		pivotObject(wall, wallCFrame)

		if wall:IsA("Model") then
			forcePrimaryInvisible(wall)
		end

		if not hitDone and ctx:IsActive() then
			ctx.HitboxService:PerformSphereAtPosition(
				ctx.Character,
				wallCFrame.Position,
				8,
				function(hitCharacter, hitHumanoid, hitRoot)
					if not ctx:IsActive() then
						return
					end
					if not isReservedVictim(ctx, hitCharacter) then
						return
					end
					if hitDone then
						return
					end
					hitDone = true

					blockableSequenceDamage(
						ctx,
						hitCharacter,
						hitHumanoid,
						hitRoot,
						wallCFrame.Position,
						data.BoneWallDamage or 4,
						BLOCK_MODE_NORMAL
					)

					shakeCharacter(
						ctx,
						hitCharacter,
						data.BoneWallHitVictimShakeMagnitude or BadTime.BoneWallHitVictimShakeMagnitude or 0.6,
						data.BoneWallHitVictimShakeRoughness or BadTime.BoneWallHitVictimShakeRoughness or 9,
						data.BoneWallHitVictimShakeDuration or BadTime.BoneWallHitVictimShakeDuration or 0.11
					)
				end
			)
		end

		task.wait()
	end

	fadeOutObject(wall, 0.1)
	Debris:AddItem(wall, 0.3)
end

local function setupGasterBlasterModel(blaster, scale)
	setupWorldObject(blaster)

	if blaster:IsA("Model") then
		ensurePrimaryPart(blaster)

		local attributeScale = blaster:GetAttribute("SCALE")
		local finalScale = scale or attributeScale

		if typeof(finalScale) == "number" and finalScale > 0 then
			pcall(function()
				blaster:ScaleTo(finalScale)
			end)
		end

		forcePrimaryInvisible(blaster)
	end
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

local function getBeamStart(blaster)
	local attachment = getBeamOrigin(blaster)

	if attachment then
		return attachment.WorldPosition
	end

	if blaster:IsA("Model") then
		local primary = ensurePrimaryPart(blaster)

		if primary then
			return primary.Position
		end

		return blaster:GetPivot().Position
	end

	return blaster.Position
end

local function openBlasterJaws(blaster)
	local leftJaw = blaster:FindFirstChild("Left Jaw", true)
	local rightJaw = blaster:FindFirstChild("Right Jaw", true)

	local tweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	if leftJaw and leftJaw:IsA("BasePart") then
		TweenService:Create(leftJaw, tweenInfo, {
			CFrame = leftJaw.CFrame * CFrame.Angles(math.rad(-22), 0, 0),
		}):Play()
	end

	if rightJaw and rightJaw:IsA("BasePart") then
		TweenService:Create(rightJaw, tweenInfo, {
			CFrame = rightJaw.CFrame * CFrame.Angles(math.rad(-22), 0, 0),
		}):Play()
	end
end

local function hideBlasterRightEye(blaster)
	local rightEye = blaster:FindFirstChild("RightEye", true)

	if rightEye and rightEye:IsA("BasePart") then
		rightEye.Transparency = 1
	end
end

local function createBeamVisual(startPosition, direction, length, radius, fadeTime, giant, finalPulse)
	local visualLength = length

	if finalPulse then
		visualLength += BadTime.FinalRingBeamExtraLength or 10
	end

	local sizeMultiplier = BadTime.BeamVisualSizeMultiplier or 1.25
	local transparency = BadTime.BeamVisualTransparency or 0.18
	local finalFadeTime = fadeTime or BadTime.BeamFadeTime or 0.18
	local beamColor = Color3.fromRGB(255, 255, 255)

	if giant then
		sizeMultiplier = BadTime.GiantBeamVisualSizeMultiplier or 1.85
		transparency = BadTime.GiantBeamVisualTransparency or 0.06
		finalFadeTime = fadeTime or BadTime.GiantBeamFadeTime or 0.22
		beamColor = Color3.fromRGB(220, 245, 255)
	end

	if finalPulse then
		sizeMultiplier = BadTime.FinalRingBeamVisualSizeMultiplier or 2.5
		transparency = BadTime.FinalRingBeamVisualTransparency or 0.015
		finalFadeTime = BadTime.FinalRingBeamFadeTime or 0.25
		beamColor = Color3.fromRGB(200, 245, 255)
	end

	local visualRadius = radius * sizeMultiplier

	local beam = Instance.new("Part")
	beam.Name = finalPulse and "BadTimeFinalRingBeam" or (giant and "BadTimeGiantGasterBeam" or "BadTimeGasterBeam")
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanTouch = false
	beam.CanQuery = false
	beam.Material = Enum.Material.Neon
	beam.Color = beamColor
	beam.Transparency = transparency
	beam.Size = Vector3.new(visualRadius, visualRadius, visualLength)

	local center = startPosition + direction.Unit * (visualLength / 2)
	beam.CFrame = CFrame.lookAt(center, center + direction.Unit)
	beam.Parent = workspace

	if finalPulse then
		local core = Instance.new("Part")
		core.Name = "BadTimeFinalRingBeamCore"
		core.Anchored = true
		core.CanCollide = false
		core.CanTouch = false
		core.CanQuery = false
		core.Material = Enum.Material.Neon
		core.Color = Color3.fromRGB(255, 255, 255)
		core.Transparency = 0
		core.Size = Vector3.new(visualRadius * 0.55, visualRadius * 0.55, visualLength + 4)
		core.CFrame = beam.CFrame
		core.Parent = workspace

		TweenService:Create(core, TweenInfo.new(finalFadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 1,
			Size = Vector3.new(visualRadius * 0.08, visualRadius * 0.08, visualLength + 4),
		}):Play()

		Debris:AddItem(core, finalFadeTime + 0.08)
	end

	TweenService:Create(beam, TweenInfo.new(finalFadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(visualRadius * 0.2, visualRadius * 0.2, visualLength),
	}):Play()

	Debris:AddItem(beam, finalFadeTime + 0.08)
end

local function hitVictimWithBeam(ctx, data, startPosition, direction, length, radius, damage, blockable, giant, finalPulse)
	if not ctx:IsActive() then
		return
	end
	if not ctx.HitboxService or not ctx.HitboxService.PerformSphereChain then
		warn("[BadTime] Missing HitboxService:PerformSphereChain")
		return
	end

	local hitOnce = false

	ctx.HitboxService:PerformSphereChain(
		ctx.Character,
		startPosition,
		direction,
		length,
		data.BlasterBeamStep or 6,
		radius,
		function(hitCharacter, hitHumanoid, hitRoot, hitPosition)
			if not ctx:IsActive() then
				return
			end
			if not isReservedVictim(ctx, hitCharacter) then
				return
			end
			if hitOnce then
				return
			end
			hitOnce = true

			if blockable ~= false then
				local didDamage = blockableSequenceDamage(ctx, hitCharacter, hitHumanoid, hitRoot, startPosition, damage, BLOCK_MODE_NORMAL)
				if didDamage then
					playBlasterHitPolish(ctx, hitCharacter, giant == true, finalPulse == true)
				end
			else
				nonlethalDamage(ctx, hitCharacter, hitHumanoid, hitRoot, damage)

				if ctx.VFXService then
					ctx.VFXService:EmitHitVFXOnVictim(hitRoot, ctx.Character)
				end

				playBlasterHitPolish(ctx, hitCharacter, giant == true, finalPulse == true)
			end
		end
	)
end

local function tweenBlasterIn(blaster, startCFrame, finalCFrame, tweenTime)
	if not blaster or not blaster.Parent then
		return nil, nil
	end

	local cframeValue = Instance.new("CFrameValue")
	cframeValue.Value = startCFrame

	local connection
	connection = cframeValue:GetPropertyChangedSignal("Value"):Connect(function()
		if blaster and blaster.Parent then
			pivotObject(blaster, cframeValue.Value)

			if blaster:IsA("Model") then
				forcePrimaryInvisible(blaster)
			end
		end
	end)

	for _, part in ipairs(getVisualParts(blaster)) do
		part.Transparency = 1
	end

	if blaster:IsA("Model") then
		forcePrimaryInvisible(blaster)
	end

	local moveTween = TweenService:Create(
		cframeValue,
		TweenInfo.new(tweenTime or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Value = finalCFrame,
		}
	)

	for _, part in ipairs(getVisualParts(blaster)) do
		TweenService:Create(part, TweenInfo.new(tweenTime or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 0,
		}):Play()
	end

	moveTween:Play()

	return cframeValue, connection
end

local function tweenBlasterOut(blaster, currentCFrame, moveDirection, distance, fadeTime)
	if not blaster or not blaster.Parent then
		return
	end

	fadeTime = fadeTime or 0.16
	distance = distance or 7

	local direction = moveDirection

	if direction.Magnitude < 0.05 then
		direction = currentCFrame.LookVector
	else
		direction = direction.Unit
	end

	local endCFrame = currentCFrame + (direction * distance)

	local cframeValue = Instance.new("CFrameValue")
	cframeValue.Value = currentCFrame

	local connection
	connection = cframeValue:GetPropertyChangedSignal("Value"):Connect(function()
		if blaster and blaster.Parent then
			pivotObject(blaster, cframeValue.Value)

			if blaster:IsA("Model") then
				forcePrimaryInvisible(blaster)
			end
		end
	end)

	TweenService:Create(cframeValue, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Value = endCFrame,
	}):Play()

	for _, part in ipairs(getVisualParts(blaster)) do
		TweenService:Create(part, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 1,
		}):Play()
	end

	task.delay(fadeTime + 0.03, function()
		if connection then
			connection:Disconnect()
		end

		if cframeValue then
			cframeValue:Destroy()
		end

		if blaster and blaster.Parent then
			blaster:Destroy()
		end
	end)
end

local function spawnGasterBlasterAtVictim(
	ctx,
	data,
	angle,
	scale,
	damage,
	chargeTime,
	beamLength,
	beamRadius,
	beamStep,
	giant,
	finalPulse
)
	if not ctx:IsActive() then
		return
	end

	local template = getVFXTemplate(ctx, "GasterBlaster")
	if not template then
		return
	end

	local targetCharacter, targetHumanoid, targetRoot = getVictim(ctx)
	if not targetCharacter then
		return
	end

	local blaster = template:Clone()
	blaster.Name = giant and "BadTimeGiantGasterBlaster" or "BadTimeGasterBlaster"

	setupGasterBlasterModel(blaster, scale)

	local center = targetRoot.Position
	local directionToCenter = Vector3.new(math.cos(angle), 0, math.sin(angle))

	local spawnRadius = giant and (data.GiantBlasterSpawnRadius or 38) or (data.BlasterSpawnRadius or 36)
	local height = giant and 8.5 or 5.25

	local finalPosition = center + directionToCenter * spawnRadius + Vector3.new(0, height, 0)
	local lookTarget = center + Vector3.new(0, 2, 0)

	local finalCFrame = CFrame.lookAt(finalPosition, lookTarget)

	local moveInDistance = giant and (data.GiantBlasterMoveInDistance or 8) or (data.BlasterMoveInDistance or 6)
	local spawnPosition = finalPosition + directionToCenter * moveInDistance
	local spawnCFrame = CFrame.lookAt(spawnPosition, lookTarget)

	local tweenTime = giant and (data.GiantBlasterSpawnTweenTime or 0.18) or (data.BlasterSpawnTweenTime or 0.12)

	blaster.Parent = workspace
	pivotObject(blaster, spawnCFrame)

	if blaster:IsA("Model") then
		forcePrimaryInvisible(blaster)
	end

	local primary = blaster:IsA("Model") and ensurePrimaryPart(blaster) or blaster

	local cframeValue, tweenConnection = tweenBlasterIn(blaster, spawnCFrame, finalCFrame, tweenTime)

	task.wait(tweenTime)

	if not ctx:IsActive() then
		if tweenConnection then
			tweenConnection:Disconnect()
		end

		if cframeValue then
			cframeValue:Destroy()
		end

		fadeOutObject(blaster, data.BlasterFadeOutTime or 0.16)
		return
	end

	if tweenConnection then
		tweenConnection:Disconnect()
	end

	if cframeValue then
		cframeValue:Destroy()
	end

	if not blaster.Parent then
		return
	end

	pivotObject(blaster, finalCFrame)

	if blaster:IsA("Model") then
		forcePrimaryInvisible(blaster)
	end

	playSansSFX(ctx, "GasterBlasterCharge", primary, 3)
	playBlasterChargePolish(ctx, giant == true or finalPulse == true)

	openBlasterJaws(blaster)

	task.wait(chargeTime or 0.75)

	if not ctx:IsActive() then
		tweenBlasterOut(
			blaster,
			finalCFrame,
			directionToCenter,
			giant and (data.GiantBlasterMoveOutDistance or 10) or (data.BlasterMoveOutDistance or 7),
			data.BlasterFadeOutTime or 0.16
		)
		return
	end

	if not blaster.Parent then
		return
	end

	targetCharacter, targetHumanoid, targetRoot = getVictim(ctx)

	if not targetCharacter then
		tweenBlasterOut(
			blaster,
			finalCFrame,
			directionToCenter,
			giant and (data.GiantBlasterMoveOutDistance or 10) or (data.BlasterMoveOutDistance or 7),
			data.BlasterFadeOutTime or 0.16
		)
		return
	end

	local beamStart = getBeamStart(blaster)
	local beamDirection = (targetRoot.Position + Vector3.new(0, 2, 0)) - beamStart

	if beamDirection.Magnitude < 0.05 then
		beamDirection = finalCFrame.LookVector
	else
		beamDirection = beamDirection.Unit
	end

	playSansSFX(ctx, "GasterBlasterShoot", primary, 3)
	hideBlasterRightEye(blaster)

	if not ctx:IsActive() then
		tweenBlasterOut(
			blaster,
			finalCFrame,
			directionToCenter,
			giant and (data.GiantBlasterMoveOutDistance or 10) or (data.BlasterMoveOutDistance or 7),
			data.BlasterFadeOutTime or 0.16
		)
		return
	end

	createBeamVisual(
		beamStart,
		beamDirection,
		beamLength or 78,
		beamRadius or 5.5,
		giant and 0.24 or 0.18,
		giant == true,
		finalPulse == true
	)

	local oldStep = data.BlasterBeamStep
	data.BlasterBeamStep = beamStep or oldStep or 6

	hitVictimWithBeam(
		ctx,
		data,
		beamStart,
		beamDirection,
		beamLength or 78,
		beamRadius or 5.5,
		damage,
		true,
		giant == true,
		finalPulse == true
	)

	data.BlasterBeamStep = oldStep

	tweenBlasterOut(
		blaster,
		finalCFrame,
		directionToCenter,
		giant and (data.GiantBlasterMoveOutDistance or 10) or (data.BlasterMoveOutDistance or 7),
		giant and 0.2 or (data.BlasterFadeOutTime or 0.16)
	)

	Debris:AddItem(blaster, 2)
end

local function runBoneShotSpam(ctx, data)
	for index = 1, data.BoneShotCount or 18 do
		if not ctx:IsActive() then
			return
		end

		spawnBoneShotAtVictim(ctx, data, index, data.BoneShotCount or 18)

		task.wait(0.075)
	end

	task.wait(0.35)
end

local function runBoneZones(ctx, data)
	for _ = 1, data.BoneZoneCount or 4 do
		if not ctx:IsActive() then
			return
		end

		spawnBoneZoneAtVictim(ctx, data)

		task.wait(0.2)
	end

	task.wait(0.35)
end

local function runBoneWalls(ctx, data)
	for index = 1, data.BoneWallCount or 2 do
		if not ctx:IsActive() then
			return
		end

		task.spawn(function()
			if not ctx:IsActive() then
				return
			end

			spawnTrackingBoneWall(ctx, data, index)
		end)

		task.wait(data.BoneWallFireInterval or 0.18)
	end

	task.wait(0.55)
end

local function runBlasterRing(ctx, data)
	local count = data.BlasterRingCount or 14
	local rounds = data.BlasterCircleRounds or 6

	for round = 1, rounds do
		if not ctx:IsActive() then
			return
		end

		for index = 1, count do
			if not ctx:IsActive() then
				return
			end

			local angleOffset = (round - 1) * (math.pi / count)
			local angle = math.rad((360 / count) * index) + angleOffset
			local isFinalPulse = round == rounds and index == count

			task.spawn(function()
				if not ctx:IsActive() then
					return
				end

				spawnGasterBlasterAtVictim(
					ctx,
					data,
					angle,
					data.BlasterScale or 1,
					data.BlasterDamage or 2,
					data.BlasterChargeTime or 0.52,
					data.BlasterBeamLength or 78,
					data.BlasterBeamRadius or 5.2,
					data.BlasterBeamStep or 6,
					false,
					isFinalPulse
				)
			end)

			task.wait(data.BlasterShotInterval or 0.055)
		end

		task.wait(0.12)
	end

	task.wait(0.8)
end

local function runGiantBlasters(ctx, data)
	local angles = {
		0,
		math.pi / 2,
		math.pi,
		(math.pi * 3) / 2,
	}

	for _, angle in ipairs(angles) do
		if not ctx:IsActive() then
			return
		end

		task.spawn(function()
			if not ctx:IsActive() then
				return
			end

			spawnGasterBlasterAtVictim(
				ctx,
				data,
				angle,
				data.GiantBlasterScale or 2.2,
				data.GiantBlasterDamage or 6,
				data.GiantBlasterChargeTime or 0.72,
				data.GiantBlasterBeamLength or 120,
				data.GiantBlasterBeamRadius or 9,
				data.GiantBlasterBeamStep or 7,
				true,
				false
			)
		end)

		task.wait(0.28)
	end

	task.wait(1.35)
end

local function runBlueGravityFinale(ctx, data)
	local targetCharacter, targetHumanoid, targetRoot = getVictim(ctx)

	if not targetCharacter then
		return
	end

	local totalDamage = data.GravitySpamTotalDamage or 10
	local perHit = totalDamage / 4

	local velocities = {
		Vector3.new(80, 80, 0),
		Vector3.new(-90, 60, 25),
		Vector3.new(40, 95, -85),
		Vector3.new(-35, 75, 95),
	}

	for _, velocity in ipairs(velocities) do
		if not ctx:IsActive() then
			return
		end

		targetCharacter, targetHumanoid, targetRoot = getVictim(ctx)

		if not targetCharacter then
			return
		end

		targetRoot.AssemblyLinearVelocity = velocity

		nonlethalDamage(ctx, targetCharacter, targetHumanoid, targetRoot, perHit)
		playGravitySpamPolish(ctx, targetCharacter)

		playSansMoveVFX(ctx, "BlueHeart", targetCharacter, targetRoot)
		playSansSFX(ctx, "Teleport", targetRoot, 2)

		task.wait(0.3)
	end
end

local function finalSlam(ctx, data)
	local targetCharacter, targetHumanoid, targetRoot = getVictim(ctx)

	if not targetCharacter then
		return
	end
	if not targetHumanoid then
		return
	end
	if not targetRoot then
		return
	end

	local slamData = {}

	for key, value in pairs(data or {}) do
		slamData[key] = value
	end

	slamData.KnockbackPreset = "Downslam"
	slamData.DownForwardSpeed = data.FinalSlamForwardSpeed or 12
	slamData.DownSpeed = data.FinalSlamDownSpeed or -95
	slamData.DownLaunchMaxForce = data.FinalSlamMaxForce or 95000
	slamData.AirStunMax = 3
	slamData.GroundSplatStun = 2
	slamData.PostSplatM1Immunity = data.FinalSlamM1Immunity or 0
	slamData.SplatPartLifetime = data.SplatPartLifetime or 0.35
	slamData.SplatPartSize = data.SplatPartSize or Vector3.new(10, 0.25, 10)
	slamData.AirAnimationName = "DownslamAir"
	slamData.SplatAnimationName = "DownslamSplat"

	playFinalSlamPolish(ctx, targetCharacter)

	if ctx.MovementService and ctx.MovementService.ApplyGroundSplatDownslam then
		ctx.MovementService:ApplyGroundSplatDownslam(ctx.Root, targetCharacter, targetHumanoid, targetRoot, slamData, {
			StateService = ctx.StateService,
			VFXService = ctx.VFXService,
			AttackerCharacter = ctx.Character,
		}, "BadTimeFinalSlam")
	elseif ctx.MovementService and ctx.MovementService.ApplyDownslamKnockback then
		ctx.MovementService:ApplyDownslamKnockback(ctx.Root, targetRoot, slamData, "BadTimeFinalSlam")
	else
		targetRoot.AssemblyLinearVelocity = Vector3.new(0, slamData.DownSpeed, 0)
	end

	task.wait(0.08)

	if targetHumanoid.Health > 0 then
		lethalDamage(ctx, targetCharacter, targetHumanoid, targetRoot, data.FinalSlamDamage or 35)
	end
end

function BadTime.Execute(ctx)
	print("[BadTime] Execute started")

	local character = ctx.Character
	local humanoid = ctx.Humanoid
	local root = ctx.Root
	local data = {}
	for key, value in pairs(ctx.MoveData or {}) do
		data[key] = value
	end
	ctx.BadTimeReservedTargetCharacter = nil
	ctx.BadTimeHadReservedTarget = false

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

	local targetCharacter, targetHumanoid, targetRoot = ctx:GetValidTarget()

	if not targetCharacter then
		ctx:FinishMove(0)
		return
	end

	local finished = false
	local eyeGlowAttachment = nil
	local sansLockState = nil
	local confirmedVictim = nil
	local beatdownBlockToken = nil
	local cinematicService = ctx.CinematicService

	local function cleanup()
		if finished then
			return
		end
		finished = true

		if eyeGlowAttachment then
			eyeGlowAttachment:Destroy()
			eyeGlowAttachment = nil
		end

		if cinematicService and sansLockState then
			cinematicService:UnlockCharacter(sansLockState)
			sansLockState = nil
		end

		if cinematicService then
			cinematicService:ClearTemporaryCombatStatus(character)
		end

		if confirmedVictim then
			clearBeatdownBlockPermission(confirmedVictim, beatdownBlockToken)
		end

		if confirmedVictim and ctx.CombatStatusService and ctx.CombatStatusService.ClearDamageLock then
			ctx.CombatStatusService:ClearDamageLock(confirmedVictim, character)
		end

		if confirmedVictim then
			clearReservedVictim(character, confirmedVictim)
		end

		ctx.BadTimeReservedTargetCharacter = nil

		if cinematicService then
			cinematicService:ResetCamera(character)

			if targetCharacter then
				cinematicService:ResetCamera(targetCharacter)
			end
		end
	end

	if cinematicService then
		cinematicService:SetTemporaryCombatStatus(character, {
			IFrameActive = true,
			ArmorActive = true,
			ArmorDamageReduction = 1,
			ArmorPreventsStun = true,
			ArmorPreventsKnockback = true,
			ArmorPreventsHitCancel = true,
		})
	end

	playSansSFX(ctx, "EyeFlash", root, 2)
	eyeGlowAttachment = startHeadAttachment(ctx, character, "EyeGlow", nil, true)

	startHeadAttachment(ctx, targetCharacter, "RedWarningHead", data.WarningTime or 1, false)

	task.wait(data.WarningTime or 1)

	if not ctx:IsActive() then
		cleanup()
		ctx:FinishMove(0)
		return
	end

	targetCharacter, targetHumanoid, targetRoot = ctx:GetValidTarget()

	if not targetCharacter then
		cleanup()
		ctx:FinishMove(0)
		return
	end

	if (targetRoot.Position - root.Position).Magnitude > (data.ConfirmRange or 80) then
		print("[BadTime] Target escaped confirm range")
		cleanup()
		ctx:FinishMove(0.35)
		return
	end

	local confirmResult =
		ctx:ApplyStandardHit(targetCharacter, targetHumanoid, targetRoot, makeConfirmAttackData(data), "BadTime")

	if confirmResult == "Blocked" then
		print("[BadTime] Blocked")
		cleanup()
		ctx:FinishMove(0.45)
		return
	end

	if confirmResult == "Countered" then
		print("[BadTime] Countered")
		cleanup()
		ctx:FinishMove(0)
		return
	end

	if confirmResult == "DamageLocked" then
		print("[BadTime] Target damage locked")
		cleanup()
		ctx:FinishMove(0.3)
		return
	end

	if confirmResult ~= "Hit" and confirmResult ~= "ArmoredHit" then
		print("[BadTime] Failed confirm:", confirmResult)
		cleanup()
		ctx:FinishMove(0.3)
		return
	end

	print("[BadTime] Confirmed:", targetCharacter.Name)
	confirmedVictim = targetCharacter
	ctx.BadTimeReservedTargetCharacter = confirmedVictim
	ctx.BadTimeHadReservedTarget = true
	beatdownBlockToken = (targetCharacter:GetAttribute("BadTimeBlockPermissionToken") or 0) + 1
	setReservedVictim(character, confirmedVictim)

	-- DamageLock only prevents other players from damaging/stealing this victim.
	-- It does NOT stun, grab, movement-lock, dash-lock, or block-lock the victim.
	if ctx.CombatStatusService and ctx.CombatStatusService.SetDamageLock then
		ctx.CombatStatusService:SetDamageLock(targetCharacter, character, data.SequenceTime or 11.5)
	end
	setBeatdownBlockPermission(targetCharacter, beatdownBlockToken, true)

	if cinematicService then
		sansLockState = cinematicService:LockCharacter(character, {
			AnchorRoot = true,
			DisableCollision = true,
			IsGrabber = false,
		})
	end

	playSansMoveVFX(ctx, "BlueHeart", targetCharacter, targetRoot)
	playSansSFX(ctx, "Ding", targetRoot, 2)

	local victimSpotCFrame = targetRoot.CFrame

	teleportVictimToSpot(ctx, targetRoot, victimSpotCFrame)
	runBoneShotSpam(ctx, data)

	targetCharacter, targetHumanoid, targetRoot = getVictim(ctx)
	if not targetCharacter then
		cleanup()
		ctx:FinishMove(0)
		return
	end

	teleportVictimToSpot(ctx, targetRoot, victimSpotCFrame)
	runBoneZones(ctx, data)

	targetCharacter, targetHumanoid, targetRoot = getVictim(ctx)
	if not targetCharacter then
		cleanup()
		ctx:FinishMove(0)
		return
	end

	teleportVictimToSpot(ctx, targetRoot, victimSpotCFrame)
	runBoneWalls(ctx, data)

	targetCharacter, targetHumanoid, targetRoot = getVictim(ctx)
	if not targetCharacter then
		cleanup()
		ctx:FinishMove(0)
		return
	end

	teleportVictimToSpot(ctx, targetRoot, victimSpotCFrame)
	runGiantBlasters(ctx, data)

	targetCharacter, targetHumanoid, targetRoot = getVictim(ctx)
	if not targetCharacter then
		cleanup()
		ctx:FinishMove(0)
		return
	end

	teleportVictimToSpot(ctx, targetRoot, victimSpotCFrame)
	runBlasterRing(ctx, data)

	targetCharacter, targetHumanoid, targetRoot = getVictim(ctx)

	if targetCharacter then
		clearBeatdownBlockPermission(targetCharacter, beatdownBlockToken)
		forceStopBlocking(ctx, targetCharacter)
		teleportVictimToSpot(ctx, targetRoot, victimSpotCFrame)
		runBlueGravityFinale(ctx, data)
	end

	finalSlam(ctx, data)

	cleanup()
	ctx:FinishMove(0)
end

return BadTime
