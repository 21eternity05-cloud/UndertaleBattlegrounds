local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local BoneZone = {
	DisplayName = "Bone Zone",
	AnimationName = "BoneZone",

	Cooldown = 11,
	MaxLockTime = 1,

	RequiresTarget = true,
	TargetRange = 40,

	WarningTime = 0.5,
	ZoneLifetime = 1.4,

	Radius = 9,

	Damage = 8,
	Stun = 0.75,

	Knockback = 120,
	UpwardKnockback = 0,
	UseAttackerAsKnockbackSource = true,
	WallComboPrevention = true,

	CanBeBlocked = true,
	IgnoreBlockDirection = true,
	Unblockable = false,
	Guardbreak = false,
	CanBeCountered = true,

	HitCancelsTarget = false,
	CancelableByHit = false,

	HasIFrames = false,
	HasArmor = false,

	BonesStartOffset = Vector3.new(0, -8, 0),
	BonesTweenTime = 0.28,
	BonesHoldTime = 0.22,
	BonesFadeTime = 0.18,

	WarningTransparency = 0.35,

	-- Bone Zone polish.
	-- Keep this readable. It is area denial, not an ultimate.
	EruptionAttackerShakeMagnitude = 0.55,
	EruptionAttackerShakeRoughness = 8,
	EruptionAttackerShakeDuration = 0.12,

	EruptionRadiusShakeMagnitude = 0.9,
	EruptionRadiusShakeRoughness = 9,
	EruptionRadiusShakeDuration = 0.16,
	EruptionRadiusShakeRange = 45,

	HitVictimShakeMagnitude = 1.15,
	HitVictimShakeRoughness = 12,
	HitVictimShakeDuration = 0.2,

	HitAttackerShakeMagnitude = 0.35,
	HitAttackerShakeRoughness = 7,
	HitAttackerShakeDuration = 0.08,

	BlockVictimShakeMagnitude = 0.45,
	BlockVictimShakeRoughness = 7,
	BlockVictimShakeDuration = 0.1,

	HitImpactFrameDuration = 0.045,
}

local MoveHelpers = script.Parent.Parent:WaitForChild("MoveHelpers")
local SansMoveUtil = require(MoveHelpers:WaitForChild("SansMoveUtil"))
local SansImpactHelper = require(MoveHelpers:WaitForChild("SansImpactHelper"))

local function getSansVFXFolder(ctx)
	return SansMoveUtil.GetSansVFXFolder(ctx)
end

local function getBoneZoneTemplate(ctx)
	return getSansVFXFolder(ctx):WaitForChild("BoneZone")
end

local function playSansSFX(ctx, soundName, parentPart, lifetime)
	SansMoveUtil.PlaySFX(ctx, soundName, parentPart, lifetime or 2)
end

local function showDamageNumber(ctx, targetRoot, amount)
	if not ctx then return end
	if not ctx.DamageNumberService then return end
	if not ctx.DamageNumberService.ShowDamage then return end
	if not targetRoot or not targetRoot.Parent then return end
	if typeof(amount) ~= "number" or amount <= 0 then return end

	pcall(function()
		ctx.DamageNumberService:ShowDamage(targetRoot, amount)
	end)
end

local function shakeCharacter(ctx, targetCharacter, magnitude, roughness, duration)
	SansImpactHelper.ShakeCharacter(ctx, targetCharacter, magnitude, roughness, duration)
end

local function impactFrame(ctx, targetCharacter, duration)
	SansImpactHelper.ImpactFrame(ctx, targetCharacter, duration)
end

local function playEruptionPolish(ctx, hitPosition, data)
	if not ctx.CinematicService then
		return
	end

	shakeCharacter(
		ctx,
		ctx.Character,
		data.EruptionAttackerShakeMagnitude or BoneZone.EruptionAttackerShakeMagnitude or 0.55,
		data.EruptionAttackerShakeRoughness or BoneZone.EruptionAttackerShakeRoughness or 8,
		data.EruptionAttackerShakeDuration or BoneZone.EruptionAttackerShakeDuration or 0.12
	)

	if ctx.CinematicService.ShakeRadius then
		SansImpactHelper.ShakeRadius(
			ctx,
			hitPosition,
			data.EruptionRadiusShakeRange or BoneZone.EruptionRadiusShakeRange or 45,
			data.EruptionRadiusShakeMagnitude or BoneZone.EruptionRadiusShakeMagnitude or 0.9,
			data.EruptionRadiusShakeRoughness or BoneZone.EruptionRadiusShakeRoughness or 9,
			data.EruptionRadiusShakeDuration or BoneZone.EruptionRadiusShakeDuration or 0.16,
			{
				ExcludeCharacters = {
					ctx.Character,
				},
			}
		)
	end
end

local function playHitPolish(ctx, data, targetCharacter, result)
	if result == "Hit" or result == "ArmoredHit" or result == "Guardbreak" then
		shakeCharacter(
			ctx,
			targetCharacter,
			data.HitVictimShakeMagnitude or BoneZone.HitVictimShakeMagnitude or 1.15,
			data.HitVictimShakeRoughness or BoneZone.HitVictimShakeRoughness or 12,
			data.HitVictimShakeDuration or BoneZone.HitVictimShakeDuration or 0.2
		)

		shakeCharacter(
			ctx,
			ctx.Character,
			data.HitAttackerShakeMagnitude or BoneZone.HitAttackerShakeMagnitude or 0.35,
			data.HitAttackerShakeRoughness or BoneZone.HitAttackerShakeRoughness or 7,
			data.HitAttackerShakeDuration or BoneZone.HitAttackerShakeDuration or 0.08
		)

		impactFrame(
			ctx,
			targetCharacter,
			data.HitImpactFrameDuration or BoneZone.HitImpactFrameDuration or 0.045
		)

		return
	end

	if result == "Blocked" then
		shakeCharacter(
			ctx,
			targetCharacter,
			data.BlockVictimShakeMagnitude or BoneZone.BlockVictimShakeMagnitude or 0.45,
			data.BlockVictimShakeRoughness or BoneZone.BlockVictimShakeRoughness or 7,
			data.BlockVictimShakeDuration or BoneZone.BlockVictimShakeDuration or 0.1
		)
	end
end

local function isMoveInterrupted(ctx)
	local character = ctx.Character

	if not ctx:IsActive() then
		return true
	end

	if ctx.CombatStatusService and ctx.CombatStatusService.CanAttackContinue then
		return not ctx.CombatStatusService:CanAttackContinue(character, ctx.MoveData)
	end

	return not ctx:IsActive()
end

local function setupVFXParts(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end
end

local function ensurePrimaryPart(model)
	if not model or not model:IsA("Model") then return nil end
	if model.PrimaryPart then return model.PrimaryPart end

	local primary = model:FindFirstChild("PrimaryPart", true)
	if primary and primary:IsA("BasePart") then
		model.PrimaryPart = primary
		return primary
	end

	local zone = model:FindFirstChild("Zone", true)
	if zone and zone:IsA("BasePart") then
		model.PrimaryPart = zone
		return zone
	end

	local firstPart = model:FindFirstChildWhichIsA("BasePart", true)
	if firstPart then
		model.PrimaryPart = firstPart
		return firstPart
	end

	return nil
end

local function pivotModel(model, cframe)
	if not model then return end
	ensurePrimaryPart(model)
	model:PivotTo(cframe)
end

local function isPrimaryPartOfAnyModel(part)
	local parent = part.Parent

	while parent do
		if parent:IsA("Model") and parent.PrimaryPart == part then
			return true
		end

		parent = parent.Parent
	end

	return false
end

local function forceImportantPrimaryPartsInvisible(zoneModel, bonesModel)
	if zoneModel then
		ensurePrimaryPart(zoneModel)
		if zoneModel.PrimaryPart then
			zoneModel.PrimaryPart.Transparency = 1
			zoneModel.PrimaryPart.CanCollide = false
			zoneModel.PrimaryPart.CanTouch = false
			zoneModel.PrimaryPart.CanQuery = false
		end
	end

	if bonesModel then
		ensurePrimaryPart(bonesModel)
		if bonesModel.PrimaryPart then
			bonesModel.PrimaryPart.Transparency = 1
			bonesModel.PrimaryPart.CanCollide = false
			bonesModel.PrimaryPart.CanTouch = false
			bonesModel.PrimaryPart.CanQuery = false
		end
	end
end

local function setZoneWarningVisible(zoneModel, zonePart, bonesModel, transparency)
	for _, descendant in ipairs(zoneModel:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false

			if descendant == zonePart or isPrimaryPartOfAnyModel(descendant) then
				descendant.Transparency = 1
			elseif bonesModel and descendant:IsDescendantOf(bonesModel) then
				-- handled separately
			else
				descendant.Transparency = transparency or 0.35
			end
		end
	end

	forceImportantPrimaryPartsInvisible(zoneModel, bonesModel)
end

local function setBonesVisible(zoneModel, bonesModel, visible)
	ensurePrimaryPart(bonesModel)
	local primaryPart = bonesModel.PrimaryPart

	for _, descendant in ipairs(bonesModel:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false

			if descendant == primaryPart or isPrimaryPartOfAnyModel(descendant) then
				descendant.Transparency = 1
			else
				descendant.Transparency = visible and 0 or 1
			end
		end
	end

	forceImportantPrimaryPartsInvisible(zoneModel, bonesModel)
end

local function getGroundCFrameAtTarget(ctx, targetRoot)
	local rayOrigin = targetRoot.Position + Vector3.new(0, 4, 0)
	local rayDirection = Vector3.new(0, -30, 0)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {
		ctx.Character,
		targetRoot.Parent,
	}

	local result = workspace:Raycast(rayOrigin, rayDirection, params)

	local groundPosition
	if result then
		groundPosition = result.Position + Vector3.new(0, 0.06, 0)
	else
		groundPosition = targetRoot.Position - Vector3.new(0, 2.8, 0)
	end

	local flatLook = Vector3.new(ctx.Root.CFrame.LookVector.X, 0, ctx.Root.CFrame.LookVector.Z)

	if flatLook.Magnitude < 0.05 then
		flatLook = Vector3.new(0, 0, -1)
	else
		flatLook = flatLook.Unit
	end

	return CFrame.lookAt(groundPosition, groundPosition + flatLook)
end

local function tweenBonesUp(zoneModel, bonesModel, startCFrame, endCFrame, data)
	local cframeValue = Instance.new("CFrameValue")
	cframeValue.Value = startCFrame

	local connection
	connection = cframeValue:GetPropertyChangedSignal("Value"):Connect(function()
		if bonesModel and bonesModel.Parent then
			pivotModel(bonesModel, cframeValue.Value)
			forceImportantPrimaryPartsInvisible(zoneModel, bonesModel)
		end
	end)

	local tween = TweenService:Create(
		cframeValue,
		TweenInfo.new(
			data.BonesTweenTime or 0.28,
			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out
		),
		{ Value = endCFrame }
	)

	tween:Play()

	tween.Completed:Connect(function()
		if connection then connection:Disconnect() end

		if bonesModel and bonesModel.Parent then
			pivotModel(bonesModel, endCFrame)
			forceImportantPrimaryPartsInvisible(zoneModel, bonesModel)
		end

		cframeValue:Destroy()
	end)
end

local function fadeOutModel(model, fadeTime)
	if not model then return end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			TweenService:Create(
				descendant,
				TweenInfo.new(fadeTime or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Transparency = 1 }
			):Play()
		end
	end
end

local function applyBoneZoneHit(ctx, hitPosition, targetCharacter, targetHumanoid, targetRoot, data)
	local attackData = {}

	for key, value in pairs(data) do
		attackData[key] = value
	end

	attackData.CanBeBlocked = data.CanBeBlocked ~= false
	attackData.Unblockable = data.Unblockable == true
	attackData.CanBeCountered = data.CanBeCountered ~= false
	attackData.HitCancelsTarget = false

	if ctx.CombatStatusService and ctx.CombatStatusService:HasIFrames(targetCharacter, attackData) then
		return "IFrame"
	end

	if ctx.CombatStatusService and ctx.CombatStatusService:CanAttackBeCountered(attackData) then
		if ctx.CounterService and ctx.CounterService.TryCounterHit then
			local countered = ctx.CounterService:TryCounterHit({
				AttackerCharacter = ctx.Character,
				TargetCharacter = targetCharacter,
				AttackName = ctx.MoveId or "BoneZone",
				AttackData = attackData,
				HitPosition = hitPosition,
			})

			if countered then
				return "Countered"
			end
		end
	end

	local canBlock = true
	if ctx.CombatStatusService then
		canBlock = ctx.CombatStatusService:CanAttackBeBlocked(attackData)
	else
		canBlock = attackData.CanBeBlocked ~= false and attackData.Unblockable ~= true
	end

	local projectileBlockSource = {
		Position = hitPosition,
	}

	if canBlock and ctx.BlockService:CanBlockHit(targetCharacter, projectileBlockSource, attackData) then
		if attackData.Guardbreak then
			ctx.StateService:GuardbreakCharacter(targetCharacter, attackData.GuardbreakStun or 1.25)
			ctx.BlockService:PlayBlockBreakVFX(targetRoot)
			return "Guardbreak"
		end

		ctx.BlockService:PlayBlockVFX(targetRoot)
		return "Blocked"
	end

	local armorInfo = nil
	if ctx.CombatStatusService then
		armorInfo = ctx.CombatStatusService:GetArmorInfo(targetCharacter, attackData)
	else
		armorInfo = {
			Active = false,
			DamageReduction = 0,
			PreventsStun = false,
			PreventsKnockback = false,
		}
	end

	local rawDamage = attackData.Damage or 13
	local finalDamage = rawDamage

	if armorInfo.Active then
		finalDamage = rawDamage * (1 - (armorInfo.DamageReduction or 0))
	end

	if finalDamage > 0 then
		targetHumanoid:TakeDamage(finalDamage)

		showDamageNumber(ctx, targetRoot, finalDamage)

		if ctx.CombatStatusService and ctx.CombatStatusService.TagCombatPair then
			ctx.CombatStatusService:TagCombatPair(ctx.Character, targetCharacter)
		end

		if ctx.UltService and attackData.AwardsUlt ~= false then
			ctx.UltService:AwardDamageEvent(ctx.Character, targetCharacter, finalDamage)
		end
	end

	if attackData.Stun and attackData.Stun > 0 then
		if not armorInfo.Active or not armorInfo.PreventsStun then
			ctx.StateService:StunCharacter(targetCharacter, attackData.Stun)
		end
	end

	if ctx.VFXService then
		ctx.VFXService:EmitHitVFXOnVictim(targetRoot, ctx.Character)
	end

	if not armorInfo.Active or not armorInfo.PreventsKnockback then
		local knockbackSourcePosition = hitPosition

		if attackData.UseAttackerAsKnockbackSource == true and ctx.Root then
			knockbackSourcePosition = ctx.Root.Position
		end

		local direction = targetRoot.Position - knockbackSourcePosition
		direction = Vector3.new(direction.X, 0, direction.Z)

		if direction.Magnitude < 0.05 and ctx.Root then
			direction = Vector3.new(ctx.Root.CFrame.LookVector.X, 0, ctx.Root.CFrame.LookVector.Z)
		end

		if direction.Magnitude < 0.05 then
			direction = Vector3.new(0, 0, -1)
		else
			direction = direction.Unit
		end

		if ctx.MovementService and ctx.MovementService.ApplyForceKnockback then
			local velocity = (direction * (attackData.Knockback or 120))
				+ Vector3.new(0, attackData.UpwardKnockback or 85, 0)

			ctx.MovementService:ApplyForceKnockback(
				targetRoot,
				velocity,
				attackData.KnockbackDuration or 0.28,
				attackData.KnockbackMaxForce or 130000,
				"BoneZone",
				{
					EnableWallComboPrevention = attackData.WallComboPrevention == true,
					AttackerCharacter = ctx.Character,
				}
			)
		else
			targetRoot.AssemblyLinearVelocity =
				(direction * (attackData.Knockback or 120))
				+ Vector3.new(0, attackData.UpwardKnockback or 85, 0)
		end
	end

	if armorInfo.Active then
		return "ArmoredHit"
	end

	return "Hit"
end

local function doBoneZoneHitbox(ctx, hitPosition, data)
	local hitOnce = {}

	ctx.HitboxService:PerformSphereAtPosition(
		ctx.Character,
		hitPosition,
		data.Radius or 9,
		function(targetCharacter, targetHumanoid, targetRoot)
			if hitOnce[targetCharacter] then return end
			hitOnce[targetCharacter] = true

			local result = applyBoneZoneHit(ctx, hitPosition, targetCharacter, targetHumanoid, targetRoot, data)

			if data.DebugHitResults == true then
				print("[BoneZone] Hit result:", result)
			end

			playHitPolish(ctx, data, targetCharacter, result)
		end
	)
end

function BoneZone.Execute(ctx)
	local data = ctx.MoveData

	local targetCharacter, targetHumanoid, targetRoot = ctx:GetValidTarget()
	if not targetCharacter or isMoveInterrupted(ctx) then
		ctx:FinishMove(0)
		return
	end

	local zoneCFrame = getGroundCFrameAtTarget(ctx, targetRoot)
	local hitPosition = zoneCFrame.Position

	local template = getBoneZoneTemplate(ctx)
	local zoneModel = template:Clone()
	zoneModel.Name = "SansBoneZoneVFX"

	setupVFXParts(zoneModel)

	local zonePart = zoneModel:FindFirstChild("Zone", true)
	local bonesModel = zoneModel:FindFirstChild("Bones", true)

	if not zonePart or not zonePart:IsA("BasePart") then
		warn("[BoneZone] Missing Zone part in Sans VFX > BoneZone")
		zoneModel:Destroy()
		ctx:FinishMove(0)
		return
	end

	if not bonesModel or not bonesModel:IsA("Model") then
		warn("[BoneZone] Missing Bones model in Sans VFX > BoneZone")
		zoneModel:Destroy()
		ctx:FinishMove(0)
		return
	end

	ensurePrimaryPart(zoneModel)
	ensurePrimaryPart(bonesModel)

	zoneModel.Parent = workspace
	pivotModel(zoneModel, zoneCFrame)

	local bonesEndCFrame = zoneCFrame
	local bonesStartCFrame = zoneCFrame + (data.BonesStartOffset or Vector3.new(0, -8, 0))

	pivotModel(bonesModel, bonesStartCFrame)

	forceImportantPrimaryPartsInvisible(zoneModel, bonesModel)
	setZoneWarningVisible(zoneModel, zonePart, bonesModel, data.WarningTransparency or 0.35)
	setBonesVisible(zoneModel, bonesModel, false)

	playSansSFX(ctx, "BoneZoneWarning", zonePart, 2)

	Debris:AddItem(zoneModel, data.ZoneLifetime or 1.4)

	task.wait(data.WarningTime or 0.5)

	if isMoveInterrupted(ctx) then
		if zoneModel and zoneModel.Parent then
			fadeOutModel(zoneModel, data.BonesFadeTime or 0.18)
			Debris:AddItem(zoneModel, (data.BonesFadeTime or 0.18) + 0.1)
		end

		ctx:FinishMove(0)
		return
	end

	if not zoneModel or not zoneModel.Parent then
		ctx:FinishMove(0)
		return
	end

	playSansSFX(ctx, "BoneUp", zonePart, 2)

	setBonesVisible(zoneModel, bonesModel, true)
	forceImportantPrimaryPartsInvisible(zoneModel, bonesModel)

	tweenBonesUp(zoneModel, bonesModel, bonesStartCFrame, bonesEndCFrame, data)

	playEruptionPolish(ctx, hitPosition, data)

	if isMoveInterrupted(ctx) then
		if zoneModel and zoneModel.Parent then
			fadeOutModel(zoneModel, data.BonesFadeTime or 0.18)
			Debris:AddItem(zoneModel, (data.BonesFadeTime or 0.18) + 0.1)
		end

		ctx:FinishMove(0)
		return
	end

	doBoneZoneHitbox(ctx, hitPosition, data)

	ctx:FinishMove(0.4)

	task.delay((data.BonesTweenTime or 0.28) + (data.BonesHoldTime or 0.22), function()
		if zoneModel and zoneModel.Parent then
			forceImportantPrimaryPartsInvisible(zoneModel, bonesModel)
			fadeOutModel(zoneModel, data.BonesFadeTime or 0.18)
			Debris:AddItem(zoneModel, (data.BonesFadeTime or 0.18) + 0.1)
		end
	end)
end

return BoneZone
