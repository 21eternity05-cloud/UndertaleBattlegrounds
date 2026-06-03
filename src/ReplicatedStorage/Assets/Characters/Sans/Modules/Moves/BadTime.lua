local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BadTime = {
	DisplayName = "Bad Time",
	AnimationName = "BadTime",

	Cooldown = 1, -- TESTING. Later set this back to 35.
	Duration = 11,
	LockTime = 11,
	MaxLockTime = 11.5,

	RequiresTarget = true,
	RequiresAim = false,

	WarningTime = 1,
	ConfirmRange = 80,

	SequenceTime = 8.75,

	Blockable = true,
	CanBeBlocked = true,
	Unblockable = false,
	Guardbreak = false,
	CanBeCountered = true,
	HitCancelsTarget = true,
	CancelableByHit = false,

	HasIFrames = true,
	IFrameStart = 0,
	IFrameEnd = 11,

	HasArmor = true,
	ArmorStart = 0,
	ArmorEnd = 11,
	ArmorDamageReduction = 1,
	ArmorPreventsStun = true,
	ArmorPreventsKnockback = true,
	ArmorPreventsHitCancel = true,

	BoneShotCount = 18,
	BoneShotDamage = 3,

	BoneZoneCount = 4,
	BoneZoneDamage = 6,

	BoneWallCount = 4,
	BoneWallDamage = 6,

	BlasterRingCount = 8,
	BlasterDamage = 7,
	BlasterScale = 1,
	BlasterChargeTime = 0.55,
	BlasterShotInterval = 0.18,

	GiantBlasterDamage = 12,
	GiantBlasterScale = 2.2,
	GiantBlasterChargeTime = 0.7,
	GiantBlasterBeamRadius = 12,
	GiantBlasterBeamLength = 115,

	GravitySpamTotalDamage = 20,
	FinalSlamDamage = 999,
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

local function emitAttachmentToPart(template, part, lifetime, name)
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
			descendant.Enabled = false

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

local function startHeadAttachment(ctx, character, templateName, lifetime)
	local template = getVFXTemplate(ctx, templateName)
	if not template then return nil end

	local head = character and character:FindFirstChild("Head")
	if not head then
		warn("[BadTime] Missing Head for:", templateName)
		return nil
	end

	return emitAttachmentToPart(template, head, lifetime, "Active" .. templateName)
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

local function getFlatDirection(fromPosition, toPosition)
	local direction = toPosition - fromPosition
	direction = Vector3.new(direction.X, 0, direction.Z)

	if direction.Magnitude < 0.05 then
		return Vector3.new(0, 0, -1)
	end

	return direction.Unit
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

local function nonlethalDamage(ctx, targetCharacter, targetHumanoid, damage)
	if not targetCharacter or not targetCharacter.Parent then return end
	if not targetHumanoid or targetHumanoid.Health <= 0 then return end

	targetHumanoid.Health = math.max(1, targetHumanoid.Health - (damage or 0))

	-- Important: do NOT award ult meter during an ultimate.
end

local function lethalDamage(targetHumanoid, damage)
	if not targetHumanoid or targetHumanoid.Health <= 0 then return end
	targetHumanoid:TakeDamage(damage or 999)
end

local function blockableSequenceDamage(ctx, targetCharacter, targetHumanoid, targetRoot, sourcePosition, damage)
	if wouldBlockFromPosition(ctx, targetCharacter, targetRoot, sourcePosition) then
		return false
	end

	nonlethalDamage(ctx, targetCharacter, targetHumanoid, damage)

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

local function spawnBoneShotAtVictim(ctx, damage, index, count)
	local targetCharacter, targetHumanoid, targetRoot = getVictim(ctx)
	if not targetCharacter then return end

	local bone = cloneM1Bone(ctx)
	if not bone then return end

	local angle = math.rad((360 / math.max(count, 1)) * index + math.random(-12, 12))
	local radius = math.random(13, 19)
	local height = math.random(5, 9)

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
		TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Value = endCFrame,
		}
	)

	tween:Play()

	tween.Completed:Connect(function()
		if connection then connection:Disconnect() end
		cframeValue:Destroy()

		local currentCharacter, currentHumanoid, currentRoot = getVictim(ctx)
		if currentCharacter and (currentRoot.Position - targetPosition).Magnitude <= 5.5 then
			blockableSequenceDamage(ctx, currentCharacter, currentHumanoid, currentRoot, startPosition, damage)
		end

		playSansSFX(ctx, "M1", targetRoot, 2)
		fadeOutObject(bone, 0.08)
	end)
end

local function spawnBoneZoneAtVictim(ctx, damage)
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
			if connection then connection:Disconnect() end
			cframeValue:Destroy()
		end)
	end

	local currentCharacter, currentHumanoid, currentRoot = getVictim(ctx)
	if currentCharacter and (currentRoot.Position - position).Magnitude <= 10 then
		blockableSequenceDamage(ctx, currentCharacter, currentHumanoid, currentRoot, position, damage)
	end

	task.delay(0.5, function()
		fadeOutObject(zoneModel, 0.16)
	end)

	Debris:AddItem(zoneModel, 1.2)
end

local function spawnTrackingBoneWall(ctx, damage)
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

	local startTime = os.clock()
	local duration = 0.52
	local hitDone = false

	local function getWallCFrame(alpha)
		local _, _, currentRoot = getVictim(ctx)

		if not currentRoot then
			return wall:GetPivot()
		end

		local rootCFrame = currentRoot.CFrame
		local base = rootCFrame * CFrame.new(0, 0, -6)

		local startCFrame = base * CFrame.new(0, -4.8, 5)
		local peakCFrame = base * CFrame.new(0, 3.5, -2.5)
		local endCFrame = base * CFrame.new(0, -5.2, -9.5)

		local first = startCFrame:Lerp(peakCFrame, alpha)
		local second = peakCFrame:Lerp(endCFrame, alpha)

		return first:Lerp(second, alpha)
	end

	while os.clock() - startTime < duration do
		local alpha = math.clamp((os.clock() - startTime) / duration, 0, 1)
		local easedAlpha = 1 - ((1 - alpha) * (1 - alpha))
		local wallCFrame = getWallCFrame(easedAlpha)

		pivotObject(wall, wallCFrame)

		if wall:IsA("Model") then
			forcePrimaryInvisible(wall)
		end

		local currentCharacter, currentHumanoid, currentRoot = getVictim(ctx)
		if currentCharacter and not hitDone then
			if (currentRoot.Position - wallCFrame.Position).Magnitude <= 9 then
				hitDone = true
				blockableSequenceDamage(ctx, currentCharacter, currentHumanoid, currentRoot, wallCFrame.Position, damage)
			end
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

local function hitVictimWithBeam(ctx, startPosition, direction, length, radius, damage, blockable)
	local targetCharacter, targetHumanoid, targetRoot = getVictim(ctx)
	if not targetCharacter then return end

	local toTarget = targetRoot.Position - startPosition
	local projected = toTarget:Dot(direction.Unit)

	if projected < 0 or projected > length then return end

	local closest = startPosition + direction.Unit * projected
	local distance = (targetRoot.Position - closest).Magnitude

	if distance > radius then return end

	if blockable ~= false then
		blockableSequenceDamage(ctx, targetCharacter, targetHumanoid, targetRoot, startPosition, damage)
	else
		nonlethalDamage(ctx, targetCharacter, targetHumanoid, damage)

		if ctx.VFXService then
			ctx.VFXService:EmitHitVFXOnVictim(targetRoot, ctx.Character)
		end
	end
end

local function spawnGasterBlasterAtVictim(ctx, victimSpotCFrame, angle, scale, damage, chargeTime, beamLength, beamRadius, giant)
	local template = getVFXTemplate(ctx, "GasterBlaster")
	if not template then return end

	local targetCharacter, targetHumanoid, targetRoot = getVictim(ctx)
	if not targetCharacter then return end

	local blaster = template:Clone()
	blaster.Name = giant and "BadTimeGiantGasterBlaster" or "BadTimeGasterBlaster"

	setupGasterBlasterModel(blaster, scale)

	local center = targetRoot.Position
	local directionToCenter = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local spawnRadius = giant and 36 or 24
	local height = giant and 8.5 or 5.25
	local spawnPosition = center + directionToCenter * spawnRadius + Vector3.new(0, height, 0)
	local lookTarget = center + Vector3.new(0, 2, 0)

	local blasterCFrame = CFrame.lookAt(spawnPosition, lookTarget)

	blaster.Parent = workspace
	pivotObject(blaster, blasterCFrame)

	if blaster:IsA("Model") then
		forcePrimaryInvisible(blaster)
	end

	local primary = blaster:IsA("Model") and ensurePrimaryPart(blaster) or blaster

	playSansSFX(ctx, "GasterBlasterCharge", primary, 3)
	openBlasterJaws(blaster)

	task.wait(chargeTime or 0.55)

	if not blaster.Parent then return end

	targetCharacter, targetHumanoid, targetRoot = getVictim(ctx)
	if not targetCharacter then
		fadeOutObject(blaster, 0.15)
		return
	end

	local beamStart = getBeamStart(blaster)
	local beamDirection = (targetRoot.Position + Vector3.new(0, 2, 0)) - beamStart

	if beamDirection.Magnitude < 0.05 then
		beamDirection = blasterCFrame.LookVector
	else
		beamDirection = beamDirection.Unit
	end

	playSansSFX(ctx, "GasterBlasterShoot", primary, 3)
	hideBlasterRightEye(blaster)

	createBeamVisual(
		beamStart,
		beamDirection,
		beamLength or 75,
		beamRadius or 5,
		giant and 0.24 or 0.18
	)

	hitVictimWithBeam(
		ctx,
		beamStart,
		beamDirection,
		beamLength or 75,
		(beamRadius or 5) + 2,
		damage,
		true
	)

	task.delay(0.3, function()
		fadeOutObject(blaster, 0.15)
	end)

	Debris:AddItem(blaster, 1.8)
end

local function runBoneShotSpam(ctx, data)
	for index = 1, data.BoneShotCount or 18 do
		if not ctx:IsActive() then return end

		spawnBoneShotAtVictim(ctx, data.BoneShotDamage or 3, index, data.BoneShotCount or 18)

		task.wait(0.055)
	end

	task.wait(0.35)
end

local function runBoneZones(ctx, data)
	for _ = 1, data.BoneZoneCount or 4 do
		if not ctx:IsActive() then return end

		spawnBoneZoneAtVictim(ctx, data.BoneZoneDamage or 6)

		task.wait(0.2)
	end

	task.wait(0.35)
end

local function runBoneWalls(ctx, data)
	for _ = 1, data.BoneWallCount or 4 do
		if not ctx:IsActive() then return end

		spawnTrackingBoneWall(ctx, data.BoneWallDamage or 6)

		task.wait(0.32)
	end

	task.wait(0.35)
end

local function runBlasterRing(ctx, victimSpotCFrame, data)
	local count = data.BlasterRingCount or 8

	for index = 1, count do
		if not ctx:IsActive() then return end

		local angle = math.rad((360 / count) * index)

		task.spawn(function()
			spawnGasterBlasterAtVictim(
				ctx,
				victimSpotCFrame,
				angle,
				data.BlasterScale or 1,
				data.BlasterDamage or 7,
				data.BlasterChargeTime or 0.55,
				78,
				5.2,
				false
			)
		end)

		task.wait(data.BlasterShotInterval or 0.18)
	end

	task.wait(1.25)
end

local function runGiantBlasters(ctx, victimSpotCFrame, data)
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
				victimSpotCFrame,
				angle,
				data.GiantBlasterScale or 2.2,
				data.GiantBlasterDamage or 12,
				data.GiantBlasterChargeTime or 0.7,
				data.GiantBlasterBeamLength or 115,
				data.GiantBlasterBeamRadius or 12,
				true
			)
		end)

		task.wait(0.34)
	end

	task.wait(1.5)
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
		nonlethalDamage(ctx, targetCharacter, targetHumanoid, perHit)
		playSansMoveVFX(ctx, "BlueHeart", targetCharacter, targetRoot)
		playSansSFX(ctx, "Teleport", targetRoot, 2)

		task.wait(0.3)
	end
end

local function finalSlam(ctx, data)
	local targetCharacter, targetHumanoid, targetRoot = getVictim(ctx)
	if not targetCharacter then return end

	targetRoot.AssemblyLinearVelocity = Vector3.new(0, -170, 0)

	task.wait(0.18)

	lethalDamage(targetHumanoid, data.FinalSlamDamage or 999)

	if ctx.VFXService then
		ctx.VFXService:EmitHitVFXOnVictim(targetRoot, ctx.Character)
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

		if targetCharacter and targetCharacter.Parent then
			targetCharacter:SetAttribute("BadTimeVictim", false)
			targetCharacter:SetAttribute("CinematicLocked", false)
		end

		if targetHumanoid and targetHumanoid.Parent and targetHumanoid.Health > 0 then
			targetHumanoid.WalkSpeed = oldTargetWalkSpeed
			targetHumanoid.JumpPower = oldTargetJumpPower
			targetHumanoid.JumpHeight = oldTargetJumpHeight
			targetHumanoid.AutoRotate = oldTargetAutoRotate
			targetHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		end

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
	eyeGlowAttachment = startHeadAttachment(ctx, character, "EyeGlow", nil)

	startHeadAttachment(ctx, targetCharacter, "RedWarningHead", data.WarningTime or 1)

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

	if cinematicService then
		sansLockState = cinematicService:LockCharacter(character, {
			AnchorRoot = true,
			DisableCollision = true,
			IsGrabber = false,
		})
	end

	targetCharacter:SetAttribute("BadTimeVictim", true)

	targetHumanoid.WalkSpeed = math.max(oldTargetWalkSpeed, 20)
	targetHumanoid.Jump = false
	targetHumanoid.JumpPower = 0
	targetHumanoid.JumpHeight = 0
	targetHumanoid.AutoRotate = true
	targetHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	if ctx.StateService and ctx.StateService.LockJump then
		ctx.StateService:LockJump(targetCharacter, data.SequenceTime or 8.75)
	end

	playSansMoveVFX(ctx, "BlueHeart", targetCharacter, targetRoot)
	playSansSFX(ctx, "Ding", targetRoot, 2)

	local victimSpotCFrame = targetRoot.CFrame

	teleportVictimToSpot(ctx, targetRoot, victimSpotCFrame)
	runBoneShotSpam(ctx, data)

	targetCharacter, targetHumanoid, targetRoot = getVictim(ctx)
	if not targetCharacter then cleanup() ctx:FinishMove(0) return end

	teleportVictimToSpot(ctx, targetRoot, victimSpotCFrame)
	runBoneZones(ctx, data)

	targetCharacter, targetHumanoid, targetRoot = getVictim(ctx)
	if not targetCharacter then cleanup() ctx:FinishMove(0) return end

	teleportVictimToSpot(ctx, targetRoot, victimSpotCFrame)
	runBoneWalls(ctx, data)

	targetCharacter, targetHumanoid, targetRoot = getVictim(ctx)
	if not targetCharacter then cleanup() ctx:FinishMove(0) return end

	teleportVictimToSpot(ctx, targetRoot, victimSpotCFrame)
	runBlasterRing(ctx, victimSpotCFrame, data)

	targetCharacter, targetHumanoid, targetRoot = getVictim(ctx)
	if not targetCharacter then cleanup() ctx:FinishMove(0) return end

	teleportVictimToSpot(ctx, targetRoot, victimSpotCFrame)
	runGiantBlasters(ctx, victimSpotCFrame, data)

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