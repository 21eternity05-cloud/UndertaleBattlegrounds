local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GasterBlaster = {
	DisplayName = "Gaster Blaster",
	AnimationName = "GasterBlaster",

	Cooldown = 10, -- testing value; later use 10-14
	Duration = 1.25,
	LockTime = 0.9,
	MaxLockTime = 1.35,

	RequiresTarget = false,
	RequiresAim = true,

	Startup = 0.18,
	ChargeTime = 0.45,
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

	Blockable = true,
	CanBeBlocked = true,
	Unblockable = false,

	Guardbreak = true,
	GuardbreakFinalOnly = true,
	GuardbreakStun = 1.35,

	CanBeCountered = true,
	AllowLongRangeCounter = false,
	HitCancelsTarget = true,
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
}

local function getSansVFXFolder(ctx)
	local assets = ReplicatedStorage:WaitForChild(ctx.Config.AssetsFolderName or "Assets")
	local characters = assets:WaitForChild(ctx.Config.CharactersFolderName or "Characters")
	local sans = characters:WaitForChild("Sans")

	return sans:WaitForChild("VFX")
end

local function getGasterBlasterTemplate(ctx)
	local vfxFolder = getSansVFXFolder(ctx)
	return vfxFolder:WaitForChild("GasterBlaster")
end

local function playSansSFX(ctx, soundName, parentPart, lifetime)
	if not ctx.VFXService then return end
	if not ctx.VFXService.PlayCharacterSFXAtPart then return end
	if not parentPart or not parentPart.Parent then return end

	ctx.VFXService:PlayCharacterSFXAtPart("Sans", soundName, parentPart, lifetime or 3)
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

local function setupBlasterParts(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end

	local primary = ensurePrimaryPart(model)

	if primary then
		primary.Transparency = 1
	end
end

local function getVisibleParts(model)
	local primary = ensurePrimaryPart(model)
	local parts = {}

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= primary then
			table.insert(parts, descendant)
		end
	end

	return parts
end

local function forcePrimaryInvisible(model)
	local primary = ensurePrimaryPart(model)

	if primary then
		primary.Transparency = 1
		primary.CanCollide = false
		primary.CanTouch = false
		primary.CanQuery = false
	end
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

local function createBeamVisual(startPosition, direction, data)
	local length = data.BeamLength or 90
	local radius = data.BeamRadius or 5.5

	local beam = Instance.new("Part")
	beam.Name = "GasterBlasterBeam"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanTouch = false
	beam.CanQuery = false
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(255, 255, 255)
	beam.Transparency = 0.2
	beam.Size = Vector3.new(radius * 1.2, radius * 1.2, length)

	local center = startPosition + (direction.Unit * (length / 2))
	beam.CFrame = CFrame.lookAt(center, center + direction.Unit)

	beam.Parent = workspace

	TweenService:Create(
		beam,
		TweenInfo.new(data.BeamFadeTime or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Transparency = 1,
			Size = Vector3.new(radius * 0.25, radius * 0.25, length),
		}
	):Play()

	Debris:AddItem(beam, (data.BeamFadeTime or 0.12) + 0.08)
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

	task.wait(data.Startup or 0.18)

	if not ctx:IsActive() then
		fadeOutBlaster(blaster, blaster:GetPivot(), originalTransparencies, data)
		ctx:FinishMove(0)
		return
	end

	playSansSFX(ctx, "GasterBlasterCharge", primary, 3)

	openJaws(blaster, data)
	forcePrimaryInvisible(blaster)

	task.wait(data.ChargeTime or 0.45)

	if not ctx:IsActive() then
		fadeOutBlaster(blaster, blaster:GetPivot(), originalTransparencies, data)
		ctx:FinishMove(0)
		return
	end

	local beamStart = getWorldBeamPosition(blaster)

	playSansSFX(ctx, "GasterBlasterShoot", primary, 3)

	hideRightEye(blaster)
	forcePrimaryInvisible(blaster)

	ctx.ProjectileService:RunBeam({
		OwnerCharacter = character,
		BeamStartPosition = beamStart,
		Direction = direction,
		BeamDirection = direction,
		KnockbackDirection = direction,

		AttackData = data,
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
			createBeamVisual(beamStart, direction, data)
		end,

		OnBeamHit = function(targetCharacter, targetHumanoid, targetRoot, result)
			if result == "Hit" or result == "ArmoredHit" then
				print("[GasterBlaster] Hit:", targetCharacter.Name)
			elseif result == "Guardbreak" then
				print("[GasterBlaster] Guardbreak:", targetCharacter.Name)
			elseif result == "Blocked" then
				print("[GasterBlaster] Blocked:", targetCharacter.Name)
			elseif result == "Countered" then
				print("[GasterBlaster] Countered:", targetCharacter.Name)
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
