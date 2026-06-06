local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoneZone = {
	DisplayName = "Bone Zone",
	AnimationName = "BoneZone",

	Cooldown = 11,
	MaxLockTime = 0.35,

	RequiresTarget = true,

	WarningTime = 0.5,
	EarlyUnlockTime = 0.2,
	ZoneLifetime = 1.4,

	Radius = 9,

	Damage = 11,
	Stun = 0.75,

	Knockback = 120,
	UpwardKnockback = 85,

	CanBeBlocked = true,
	Unblockable = false,
	Guardbreak = false,
	CanBeCountered = true,

	HitCancelsTarget = true,
	CancelableByHit = true,

	HasIFrames = false,
	HasArmor = false,

	BonesStartOffset = Vector3.new(0, -8, 0),
	BonesTweenTime = 0.28,
	BonesHoldTime = 0.22,
	BonesFadeTime = 0.18,

	WarningTransparency = 0.35,
}

local function getSansVFXFolder(ctx)
	local assets = ReplicatedStorage:WaitForChild(ctx.Config.AssetsFolderName or "Assets")
	local characters = assets:WaitForChild(ctx.Config.CharactersFolderName or "Characters")
	local sans = characters:WaitForChild("Sans")
	return sans:WaitForChild("VFX")
end

local function getBoneZoneTemplate(ctx)
	return getSansVFXFolder(ctx):WaitForChild("BoneZone")
end

local function playSansSFX(ctx, soundName, parentPart, lifetime)
	if not ctx.VFXService then return end
	if not ctx.VFXService.PlayCharacterSFXAtPart then return end
	if not parentPart or not parentPart.Parent then return end

	ctx.VFXService:PlayCharacterSFXAtPart("Sans", soundName, parentPart, lifetime or 2)
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
	attackData.HitCancelsTarget = data.HitCancelsTarget ~= false

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

	if canBlock and ctx.BlockService:CanBlockHit(targetCharacter, projectileBlockSource) then
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
		ctx.CombatStatusService:TryHitCancelTarget(targetCharacter, attackData)
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
		local direction = targetRoot.Position - hitPosition
		direction = Vector3.new(direction.X, 0, direction.Z)

		if direction.Magnitude < 0.05 then
			direction = Vector3.new(ctx.Root.CFrame.LookVector.X, 0, ctx.Root.CFrame.LookVector.Z)
		end

		if direction.Magnitude < 0.05 then
			direction = Vector3.new(0, 0, -1)
		else
			direction = direction.Unit
		end

		if ctx.MovementService and ctx.MovementService.ApplyStraightKnockback then
			ctx.MovementService:ApplyStraightKnockback(
				targetRoot,
				direction,
				attackData.Knockback or 120,
				attackData.UpwardKnockback or 85,
				attackData.KnockbackDuration or 0.28,
				attackData.KnockbackMaxForce or 130000
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
			print("[BoneZone] Hit result:", result)
		end
	)
end

function BoneZone.Execute(ctx)
	local data = ctx.MoveData

	local targetCharacter, targetHumanoid, targetRoot = ctx:GetValidTarget()
	if not targetCharacter then
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

	task.delay(data.EarlyUnlockTime or 0.2, function()
		ctx:FinishMove(0)
	end)

	task.wait(data.WarningTime or 0.5)

	if not zoneModel or not zoneModel.Parent then return end

	playSansSFX(ctx, "BoneUp", zonePart, 2)

	setBonesVisible(zoneModel, bonesModel, true)
	forceImportantPrimaryPartsInvisible(zoneModel, bonesModel)

	tweenBonesUp(zoneModel, bonesModel, bonesStartCFrame, bonesEndCFrame, data)

	doBoneZoneHitbox(ctx, hitPosition, data)

	task.delay((data.BonesTweenTime or 0.28) + (data.BonesHoldTime or 0.22), function()
		if zoneModel and zoneModel.Parent then
			forceImportantPrimaryPartsInvisible(zoneModel, bonesModel)
			fadeOutModel(zoneModel, data.BonesFadeTime or 0.18)
			Debris:AddItem(zoneModel, (data.BonesFadeTime or 0.18) + 0.1)
		end
	end)
end

return BoneZone
