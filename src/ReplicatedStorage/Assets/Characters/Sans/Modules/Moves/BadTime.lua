local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BadTime = {
	DisplayName = "Bad Time",
	AnimationName = "BadTime",

	Cooldown = 1, -- TESTING. Set back to 35 later.
	Duration = 14,
	LockTime = 14,
	MaxLockTime = 14.5,

	RequiresTarget = true,
	RequiresAim = false,

	WarningTime = 1,
	ConfirmRange = 80,

	SequenceTime = 11.5,

	Blockable = true,
	CanBeBlocked = true,
	Unblockable = false,
	Guardbreak = false,
	CanBeCountered = true,
	HitCancelsTarget = true,
	CancelableByHit = false,

	HasIFrames = true,
	IFrameStart = 0,
	IFrameEnd = 16,

	HasArmor = true,
	ArmorStart = 0,
	ArmorEnd = 16,
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
	BlasterSpawnRadius = 36, -- farther normal blaster ring

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
	GiantBlasterSpawnRadius = 36, -- farther normal blaster ring

	GravitySpamTotalDamage = 10,
	FinalSlamDamage = 35,
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

local function playSansSFX(ctx, soundName, parentPart, lifetime)
	if not ctx.VFXService then return end
	if not ctx.VFXService.PlayCharacterSFXAtPart then return end
	if not parentPart or not parentPart.Parent then return end

	ctx.VFXService:PlayCharacterSFXAtPart("Sans", soundName, parentPart, lifetime or 3)
end

local function playSansMoveVFX(ctx, moveName, targetCharacter, targetRoot)
	if not ctx.VFXService then return end
	if not ctx.VFXService.PlayCharacterMoveVFX then return end

	ctx.VFXService:PlayCharacterMoveVFX(ctx.Character, moveName, targetCharacter, targetRoot)
end

local function setupWorldObject(object)
	if not object then return end

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
	if not model or not model:IsA("Model") then return nil end

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
	if not model or not model:IsA("Model") then return end

	local primary = ensurePrimaryPart(model)

	if primary then
		primary.Transparency = 1
		primary.CanCollide = false
		primary.CanTouch = false
		primary.CanQuery = false
	end
end

local function pivotObject(object, cframe)
	if not object then return end

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
	if not object or not object.Parent then return end

	fadeTime = fadeTime or 0.15

	for _, part in ipairs(getVisualParts(object)) do
		TweenService:Create(
			part,
			TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Transparency = 1,
			}
		):Play()
	end

	if object:IsA("Model") then
		forcePrimaryInvisible(object)
	end

	Debris:AddItem(object, fadeTime + 0.08)
end

local function emitAttachmentToPart(template, part, lifetime, name, keepEnabled)
	if not template or not part or not part.Parent then return nil end

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
	if not template then return nil end

	local head = character and character:FindFirstChild("Head")
	if not head then
		warn("[BadTime] Missing Head for:", templateName)
		return nil
	end

	return emitAttachmentToPart(template, head, lifetime, "Active" .. templateName, keepEnabled)
end

local function getVictim(ctx)
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
	attackData.Unblockable = false
	attackData.Guardbreak = false
	attackData.CanBeCountered = true
	attackData.HitCancelsTarget = true
	attackData.PlayMoveHitVFX = false
	attackData.AwardsUlt = false

	return attackData
end

local function wouldBlockFromPosition(ctx, targetCharacter, targetRoot, sourcePosition)
	if not targetCharacter or not targetRoot then return false end
	if not ctx.BlockService then return false end
	if not ctx.BlockService.CanBlockHit then return false end

	local blockSource = {
		Position = sourcePosition,
	}

	if ctx.BlockService:CanBlockHit(targetCharacter, blockSource) then
		if ctx.BlockService.PlayBlockVFX then
			ctx.BlockService:PlayBlockVFX(targetRoot)
		end

		return true
	end

	return false
end

local function nonlethalDamage(targetCharacter, targetHumanoid, damage)
	if not targetCharacter or not targetCharacter.Parent then return end
	if not targetHumanoid or targetHumanoid.Health <= 0 then return end

	targetHumanoid.Health = math.max(1, targetHumanoid.Health - (damage or 0))
end

local function reportDamage(ctx, targetCharacter, damage)
	if not ctx or not targetCharacter then return end
	if typeof(damage) ~= "number" or damage <= 0 then return end

	local moveData = ctx.MoveData
	local awardsUlt = true

	if moveData and moveData.AwardsUlt == false then
		awardsUlt = false
	end

	if awardsUlt then
		if ctx.ReportDamageEvent then
			ctx:ReportDamageEvent(targetCharacter, damage)
		elseif ctx.UltService and ctx.UltService.AwardDamageEvent then
			ctx.UltService:AwardDamageEvent(ctx.Character, targetCharacter, damage)
		end

		return
	end

	-- Ultimate / no-ult-gain path:
	-- Do NOT call AwardDamageEvent, because that gives ult from damage.
	-- Only award kill/Dust/banner if the target died.
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

local function canDamageTarget(ctx, targetCharacter)
	if not ctx or not targetCharacter then
		return false
	end

	if ctx.CombatStatusService
		and ctx.CombatStatusService:IsDamageLockedFromAttacker(targetCharacter, ctx.Character)
	then
		return false
	end

	return true
end

local function lethalDamage(ctx, targetCharacter, targetHumanoid, damage)
	if not targetCharacter or not targetCharacter.Parent then return end
	if not targetHumanoid or targetHumanoid.Health <= 0 then return end
	if not canDamageTarget(ctx, targetCharacter) then return end

	damage = damage or 999
	targetHumanoid:TakeDamage(damage)
	reportDamage(ctx, targetCharacter, damage)
end

local function blockableSequenceDamage(ctx, targetCharacter, targetHumanoid, targetRoot, sourcePosition, damage)
	if not canDamageTarget(ctx, targetCharacter) then
		return false
	end

	if wouldBlockFromPosition(ctx, targetCharacter, targetRoot, sourcePosition) then
		return false
	end

	nonlethalDamage(targetCharacter, targetHumanoid, damage)

	if ctx.VFXService then
		ctx.VFXService:EmitHitVFXOnVictim(targetRoot, ctx.Character)
	end

	return true
end

local function teleportVictimToSpot(ctx, targetRoot, victimSpotCFrame)
	if not targetRoot or not targetRoot.Parent then return end

	targetRoot.AssemblyLinearVelocity = Vector3.zero
	targetRoot.AssemblyAngularVelocity = Vector3.zero
	targetRoot.CFrame = victimSpotCFrame

	playSansSFX(ctx, "Teleport", targetRoot, 2)
end

local function cloneM1Bone(ctx)
	local template = getVFXTemplate(ctx, "M1Bone")
	if not template then return nil end

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
	local targetCharacter, targetHumanoid, targetRoot = getVictim(ctx)
	if not targetCharacter then return end

	local bone = cloneM1Bone(ctx)
	if not bone then return end

	local angle = math.rad((360 / math.max(count, 1)) * index + math.random(-12, 12))
	local radius = math.random(data.BoneShotSpawnMinRadius or 38, data.BoneShotSpawnMaxRadius or 52)
	local height = math.random(9, 14)

	local targetPosition = targetRoot.Position + Vector3.new(0, 1.4, 0)
	local startPosition = targetRoot.Position + Vector3.new(
		math.cos(angle) * radius,
		height,
		math.sin(angle) * radius
	)

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

		local hitOnce = false

		ctx.HitboxService:PerformSphereAtPosition(
			ctx.Character,
			targetPosition,
			data.BoneShotRadius or 7.5,
			function(hitCharacter, hitHumanoid, hitRoot)
				if hitOnce then return end
				hitOnce = true

				blockableSequenceDamage(
					ctx,
					hitCharacter,
					hitHumanoid,
					hitRoot,
					startPosition,
					data.BoneShotDamage or 3
				)
			end
		)

		playSansSFX(ctx, "M1", targetRoot, 2)
		fadeOutObject(bone, 0.08)
	end)
end

local function spawnBoneZoneAtVictim(ctx, data)
	local targetCharacter, targetHumanoid, targetRoot = getVictim(ctx)
	if not targetCharacter then return end

	local template = getVFXTemplate(ctx, "BoneZone")
	if not template then return end

	local zoneModel = template:Clone()
	zoneModel.Name = "BadTimeBoneZone"

	setupWorldObject(zoneModel)

	local position = targetRoot.Position - Vector3.new(0, 2.7, 0)
	local cframe = CFrame.new(position)

	zoneModel.Parent = workspace
	pivotObject(zoneModel, cframe)

	playSansSFX(ctx, "BoneZoneWarning", targetRoot, 2)

	task.wait(0.34)

	if not zoneModel.Parent then return end

	playSansSFX(ctx, "BoneUp", targetRoot, 2)

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

		local tween = TweenService:Create(
			cframeValue,
			TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
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
		end)
	end

	local hitOnce = false

	ctx.HitboxService:PerformSphereAtPosition(
		ctx.Character,
		position,
		10,
		function(hitCharacter, hitHumanoid, hitRoot)
			if hitOnce then return end
			hitOnce = true

			blockableSequenceDamage(
				ctx,
				hitCharacter,
				hitHumanoid,
				hitRoot,
				position,
				data.BoneZoneDamage or 6
			)
		end
	)

	task.delay(0.5, function()
		fadeOutObject(zoneModel, 0.16)
	end)

	Debris:AddItem(zoneModel, 1.2)
end

local function spawnTrackingBoneWall(ctx, data, sideIndex)
	local template = getVFXTemplate(ctx, "BoneWall")
	if not template then return end

	local targetCharacter, targetHumanoid, targetRoot = getVictim(ctx)
	if not targetCharacter then return end

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
		local alpha = math.clamp((os.clock() - startTime) / duration, 0, 1)
		local easedAlpha = 1 - ((1 - alpha) * (1 - alpha))
		local wallCFrame = getWallCFrame(easedAlpha)

		pivotObject(wall, wallCFrame)

		if wall:IsA("Model") then
			forcePrimaryInvisible(wall)
		end

		if not hitDone then
			ctx.HitboxService:PerformSphereAtPosition(
				ctx.Character,
				wallCFrame.Position,
				8,
				function(hitCharacter, hitHumanoid, hitRoot)
					if hitDone then return end
					hitDone = true

					blockableSequenceDamage(
						ctx,
						hitCharacter,
						hitHumanoid,
						hitRoot,
						wallCFrame.Position,
						data.BoneWallDamage or 6
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

local function createBeamVisual(startPosition, direction, length, radius, fadeTime)
	local beam = Instance.new("Part")
	beam.Name = "BadTimeGasterBeam"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanTouch = false
	beam.CanQuery = false
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(255, 255, 255)
	beam.Transparency = 0.12
	beam.Size = Vector3.new(radius * 1.35, radius * 1.35, length)

	local center = startPosition + direction.Unit * (length / 2)
	beam.CFrame = CFrame.lookAt(center, center + direction.Unit)
	beam.Parent = workspace

	TweenService:Create(
		beam,
		TweenInfo.new(fadeTime or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Transparency = 1,
			Size = Vector3.new(radius * 0.25, radius * 0.25, length),
		}
	):Play()

	Debris:AddItem(beam, (fadeTime or 0.18) + 0.08)
end

local function hitVictimWithBeam(ctx, data, startPosition, direction, length, radius, damage, blockable)
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
			if hitOnce then return end
			hitOnce = true

			if blockable ~= false then
				blockableSequenceDamage(
					ctx,
					hitCharacter,
					hitHumanoid,
					hitRoot,
					hitPosition,
					damage
				)
			else
				if not canDamageTarget(ctx, hitCharacter) then
					return
				end

				nonlethalDamage(hitCharacter, hitHumanoid, damage)

				if ctx.VFXService then
					ctx.VFXService:EmitHitVFXOnVictim(hitRoot, ctx.Character)
				end
			end
		end
	)
end

local function tweenBlasterIn(blaster, startCFrame, finalCFrame, tweenTime)
	if not blaster or not blaster.Parent then return nil, nil end

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
		TweenService:Create(
			part,
			TweenInfo.new(tweenTime or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Transparency = 0,
			}
		):Play()
	end

	moveTween:Play()

	return cframeValue, connection
end

local function tweenBlasterOut(blaster, currentCFrame, moveDirection, distance, fadeTime)
	if not blaster or not blaster.Parent then return end

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

	TweenService:Create(
		cframeValue,
		TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{
			Value = endCFrame,
		}
	):Play()

	for _, part in ipairs(getVisualParts(blaster)) do
		TweenService:Create(
			part,
			TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Transparency = 1,
			}
		):Play()
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

local function spawnGasterBlasterAtVictim(ctx, data, angle, scale, damage, chargeTime, beamLength, beamRadius, beamStep, giant)
	local template = getVFXTemplate(ctx, "GasterBlaster")
	if not template then return end

	local targetCharacter, targetHumanoid, targetRoot = getVictim(ctx)
	if not targetCharacter then return end

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

	if tweenConnection then
		tweenConnection:Disconnect()
	end

	if cframeValue then
		cframeValue:Destroy()
	end

	if not blaster.Parent then return end

	pivotObject(blaster, finalCFrame)

	if blaster:IsA("Model") then
		forcePrimaryInvisible(blaster)
	end

	playSansSFX(ctx, "GasterBlasterCharge", primary, 3)
	openBlasterJaws(blaster)

	task.wait(chargeTime or 0.75)

	if not blaster.Parent then return end

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

	createBeamVisual(
		beamStart,
		beamDirection,
		beamLength or 78,
		beamRadius or 5.5,
		giant and 0.24 or 0.18
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
		true
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
		if not ctx:IsActive() then return end

		spawnBoneShotAtVictim(ctx, data, index, data.BoneShotCount or 18)

		task.wait(0.075)
	end

	task.wait(0.35)
end

local function runBoneZones(ctx, data)
	for _ = 1, data.BoneZoneCount or 4 do
		if not ctx:IsActive() then return end

		spawnBoneZoneAtVictim(ctx, data)

		task.wait(0.2)
	end

	task.wait(0.35)
end

local function runBoneWalls(ctx, data)
	for index = 1, data.BoneWallCount or 2 do
		if not ctx:IsActive() then return end

		task.spawn(function()
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
		if not ctx:IsActive() then return end

		for index = 1, count do
			if not ctx:IsActive() then return end

			local angleOffset = (round - 1) * (math.pi / count)
			local angle = math.rad((360 / count) * index) + angleOffset

			task.spawn(function()
				spawnGasterBlasterAtVictim(
					ctx,
					data,
					angle,
					data.BlasterScale or 1,
					data.BlasterDamage or 7,
					data.BlasterChargeTime or 0.52,
					data.BlasterBeamLength or 78,
					data.BlasterBeamRadius or 5.2,
					data.BlasterBeamStep or 6,
					false
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
		if not ctx:IsActive() then return end

		task.spawn(function()
			spawnGasterBlasterAtVictim(
				ctx,
				data,
				angle,
				data.GiantBlasterScale or 2.2,
				data.GiantBlasterDamage or 12,
				data.GiantBlasterChargeTime or 0.72,
				data.GiantBlasterBeamLength or 120,
				data.GiantBlasterBeamRadius or 9,
				data.GiantBlasterBeamStep or 7,
				true
			)
		end)

		task.wait(0.28)
	end

	task.wait(1.35)
end

local function runBlueGravityFinale(ctx, data)
	local targetCharacter, targetHumanoid, targetRoot = getVictim(ctx)

	if not targetCharacter then return end

	local totalDamage = data.GravitySpamTotalDamage or 20
	local perHit = totalDamage / 4

	local velocities = {
		Vector3.new(80, 80, 0),
		Vector3.new(-90, 60, 25),
		Vector3.new(40, 95, -85),
		Vector3.new(-35, 75, 95),
	}

	for _, velocity in ipairs(velocities) do
		if not ctx:IsActive() then return end

		targetCharacter, targetHumanoid, targetRoot = getVictim(ctx)

		if not targetCharacter then return end

		targetRoot.AssemblyLinearVelocity = velocity

		if canDamageTarget(ctx, targetCharacter) then
			nonlethalDamage(targetCharacter, targetHumanoid, perHit)
		end

		playSansMoveVFX(ctx, "BlueHeart", targetCharacter, targetRoot)
		playSansSFX(ctx, "Teleport", targetRoot, 2)

		task.wait(0.3)
	end
end

local function finalSlam(ctx, data)
	local targetCharacter, targetHumanoid, targetRoot = getVictim(ctx)

	if not targetCharacter then return end

	local slamData = {}
	for key, value in pairs(data or {}) do
		slamData[key] = value
	end

	slamData.DownForwardSpeed = data.FinalSlamForwardSpeed or 12
	slamData.DownSpeed = data.FinalSlamDownSpeed or -95
	slamData.DownLaunchMaxForce = data.FinalSlamMaxForce or 95000
	slamData.AirStunMax = data.FinalSlamAirStunMax or 1.1
	slamData.GroundSplatStun = data.FinalSlamGroundSplatStun or 0.45

	if ctx.MovementService and ctx.MovementService.ApplyDownslamKnockback then
		ctx.MovementService:ApplyDownslamKnockback(
			ctx.Root,
			targetRoot,
			slamData,
			"BadTimeFinalSlam"
		)
	else
		targetRoot.AssemblyLinearVelocity = Vector3.new(0, slamData.DownSpeed, 0)
	end

	task.wait(0.22)

	lethalDamage(ctx, targetCharacter, targetHumanoid, data.FinalSlamDamage or 35)

	if ctx.VFXService then
		ctx.VFXService:EmitHitVFXOnVictim(targetRoot, ctx.Character)
	end

	if ctx.CinematicService then
		ctx.CinematicService:ShakeOnce(ctx.Character, 2, 10, 0.3)
		ctx.CinematicService:ShakeOnce(targetCharacter, 2, 10, 0.3)
	end
end

local function applyBadTimeVictimLock(targetCharacter, targetHumanoid, duration)
	if not targetCharacter or not targetCharacter.Parent then return end
	if not targetHumanoid or not targetHumanoid.Parent then return end

	targetCharacter:SetAttribute("BadTimeVictim", true)
	targetCharacter:SetAttribute("CinematicLocked", true)
	targetCharacter:SetAttribute("Grabbed", true)
	targetCharacter:SetAttribute("Stunned", true)
	targetCharacter:SetAttribute("Blocking", false)
	targetCharacter:SetAttribute("Attacking", false)
	targetCharacter:SetAttribute("UsingMove", true)
	targetCharacter:SetAttribute("MovementLocked", true)
	targetCharacter:SetAttribute("DashLocked", true)
	targetCharacter:SetAttribute("JumpLockedUntil", os.clock() + (duration or 12))

	targetHumanoid.WalkSpeed = 0
	targetHumanoid.Jump = false
	targetHumanoid.JumpPower = 0
	targetHumanoid.JumpHeight = 0
	targetHumanoid.AutoRotate = true
	targetHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
end

local function clearBadTimeVictimLock(targetCharacter, targetHumanoid, oldWalkSpeed, oldJumpPower, oldJumpHeight, oldAutoRotate)
	if targetCharacter and targetCharacter.Parent then
		targetCharacter:SetAttribute("BadTimeVictim", false)
		targetCharacter:SetAttribute("CinematicLocked", false)
		targetCharacter:SetAttribute("Grabbed", false)
		targetCharacter:SetAttribute("Stunned", false)
		targetCharacter:SetAttribute("UsingMove", false)
		targetCharacter:SetAttribute("MovementLocked", false)
		targetCharacter:SetAttribute("DashLocked", false)
	end

	if targetHumanoid and targetHumanoid.Parent and targetHumanoid.Health > 0 then
		targetHumanoid.WalkSpeed = oldWalkSpeed
		targetHumanoid.JumpPower = oldJumpPower
		targetHumanoid.JumpHeight = oldJumpHeight
		targetHumanoid.AutoRotate = oldAutoRotate
		targetHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	end
end

function BadTime.Execute(ctx)
	print("[BadTime] Execute started")

	local character = ctx.Character
	local humanoid = ctx.Humanoid
	local root = ctx.Root
	local data = ctx.MoveData

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
	local cinematicService = ctx.CinematicService

	local oldTargetWalkSpeed = targetHumanoid.WalkSpeed
	local oldTargetJumpPower = targetHumanoid.JumpPower
	local oldTargetJumpHeight = targetHumanoid.JumpHeight
	local oldTargetAutoRotate = targetHumanoid.AutoRotate

	local function cleanup()
		if finished then return end
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

		if ctx.CombatStatusService then
			ctx.CombatStatusService:ClearDamageLock(targetCharacter, character)
		end

		clearBadTimeVictimLock(
			targetCharacter,
			targetHumanoid,
			oldTargetWalkSpeed,
			oldTargetJumpPower,
			oldTargetJumpHeight,
			oldTargetAutoRotate
		)

		if targetRoot and targetRoot.Parent then
			targetRoot.AssemblyLinearVelocity = Vector3.zero
			targetRoot.AssemblyAngularVelocity = Vector3.zero
		end

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

	local confirmResult = ctx:ApplyStandardHit(
		targetCharacter,
		targetHumanoid,
		targetRoot,
		makeConfirmAttackData(data),
		"BadTime"
	)

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

	if confirmResult ~= "Hit" and confirmResult ~= "ArmoredHit" then
		print("[BadTime] Failed confirm:", confirmResult)
		cleanup()
		ctx:FinishMove(0.3)
		return
	end

	print("[BadTime] Confirmed:", targetCharacter.Name)

	if ctx.CombatStatusService then
		ctx.CombatStatusService:SetDamageLock(targetCharacter, character, data.SequenceTime or 11.5)
	end

	if cinematicService then
		sansLockState = cinematicService:LockCharacter(character, {
			AnchorRoot = true,
			DisableCollision = true,
			IsGrabber = false,
		})
	end

	applyBadTimeVictimLock(targetCharacter, targetHumanoid, data.SequenceTime or 11.5)

	if ctx.StateService and ctx.StateService.LockJump then
		ctx.StateService:LockJump(targetCharacter, data.SequenceTime or 8.75)
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
		teleportVictimToSpot(ctx, targetRoot, victimSpotCFrame)
		runBlueGravityFinale(ctx, data)
	end

	finalSlam(ctx, data)

	cleanup()
	ctx:FinishMove(0)
end

return BadTime
