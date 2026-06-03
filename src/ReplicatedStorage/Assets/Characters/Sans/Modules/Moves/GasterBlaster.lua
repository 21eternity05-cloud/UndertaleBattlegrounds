local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GasterBlaster = {
	DisplayName = "Gaster Blaster",
	AnimationName = "GasterBlaster",

	Cooldown = 1, -- testing value; later use 10-14
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

	Damage = 3,
	FinalDamage = 6,
	Stun = 0.25,
	FinalStun = 0.8,

	Knockback = 18,
	FinalKnockback = 95,
	UpwardKnockback = 4,
	FinalUpwardKnockback = 28,

	Blockable = true,
	Guardbreak = true,
	GuardbreakStun = 1.35,

	CanBeCountered = true,
	HitCancelsTarget = true,
	CancelableByHit = true,

	SpawnOffset = CFrame.new(0, 4.5, -5.5),
	SpawnTweenTime = 0.16,

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

local function forcePrimaryInvisible(model)
	local primary = ensurePrimaryPart(model)
	if primary then
		primary.Transparency = 1
		primary.CanCollide = false
		primary.CanTouch = false
		primary.CanQuery = false
	end
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

local function tryCounter(ctx, targetCharacter, hitPosition, data)
	if data.CanBeCountered == false then
		return false
	end

	if ctx.CounterService and ctx.CounterService.TryCounterHit then
		return ctx.CounterService:TryCounterHit({
			AttackerCharacter = ctx.Character,
			TargetCharacter = targetCharacter,
			AttackName = ctx.MoveId or "GasterBlaster",
			AttackData = data,
			HitPosition = hitPosition,
		})
	end

	if ctx.StateService and ctx.StateService.TryTriggerCounter then
		return ctx.StateService:TryTriggerCounter(targetCharacter, ctx.Character)
	end

	return false
end

local function applyBeamHit(ctx, targetCharacter, targetHumanoid, targetRoot, hitPosition, data, isFinalTick)
	if not targetCharacter or not targetCharacter.Parent then return end
	if not targetHumanoid or targetHumanoid.Health <= 0 then return end
	if not targetRoot or not targetRoot.Parent then return end

	if tryCounter(ctx, targetCharacter, hitPosition, data) then
		print("[GasterBlaster] Countered by:", targetCharacter.Name)
		return
	end

	local blockSource = {
		Position = hitPosition,
	}

	if data.Blockable ~= false and ctx.BlockService and ctx.BlockService:CanBlockHit(targetCharacter, blockSource) then
		if isFinalTick and data.Guardbreak then
			ctx.StateService:GuardbreakCharacter(targetCharacter, data.GuardbreakStun or 1.35)

			if ctx.BlockService.PlayBlockBreakVFX then
				ctx.BlockService:PlayBlockBreakVFX(targetRoot)
			end

			print("[GasterBlaster] Final tick guardbreak:", targetCharacter.Name)
			return
		end

		ctx.BlockService:PlayBlockVFX(targetRoot)
		print("[GasterBlaster] Blocked tick:", targetCharacter.Name)
		return
	end

	local damage = isFinalTick and (data.FinalDamage or data.Damage or 3) or (data.Damage or 3)
	local stun = isFinalTick and (data.FinalStun or data.Stun or 0.25) or (data.Stun or 0.25)

	targetHumanoid:TakeDamage(damage)

	if stun and stun > 0 then
		ctx.StateService:StunCharacter(targetCharacter, stun)
	end

	if ctx.VFXService then
		ctx.VFXService:EmitHitVFXOnVictim(targetRoot, ctx.Character)
	end

	local direction = targetRoot.Position - hitPosition
	direction = Vector3.new(direction.X, 0, direction.Z)

	if direction.Magnitude < 0.05 then
		direction = ctx.Root.CFrame.LookVector
		direction = Vector3.new(direction.X, 0, direction.Z)
	end

	if direction.Magnitude < 0.05 then
		direction = Vector3.new(0, 0, -1)
	else
		direction = direction.Unit
	end

	local knockback = isFinalTick and (data.FinalKnockback or data.Knockback or 18) or (data.Knockback or 18)
	local upwardKnockback = isFinalTick and (data.FinalUpwardKnockback or data.UpwardKnockback or 4) or (data.UpwardKnockback or 4)

	targetRoot.AssemblyLinearVelocity =
		(direction * knockback)
		+ Vector3.new(0, upwardKnockback, 0)

	print("[GasterBlaster] Hit:", targetCharacter.Name, "Final:", isFinalTick)
end

local function doBeamTick(ctx, startPosition, direction, data, isFinalTick)
	local length = data.BeamLength or 90
	local step = data.BeamStep or 6
	local radius = data.BeamRadius or 5.5

	local hitThisTick = {}

	for distance = 0, length, step do
		local position = startPosition + (direction.Unit * distance)

		ctx.HitboxService:PerformSphereAtPosition(
			ctx.Character,
			position,
			radius,
			function(targetCharacter, targetHumanoid, targetRoot)
				if hitThisTick[targetCharacter] then return end
				hitThisTick[targetCharacter] = true

				applyBeamHit(
					ctx,
					targetCharacter,
					targetHumanoid,
					targetRoot,
					position,
					data,
					isFinalTick
				)
			end
		)
	end
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
	blaster:PivotTo(finalCFrame)
	forcePrimaryInvisible(blaster)

	playSansSFX(ctx, "EyeFlash", primary, 2)

	Debris:AddItem(blaster, data.BlasterLifetime or 2)

	task.wait(data.Startup or 0.18)

	if not ctx:IsActive() then
		blaster:Destroy()
		ctx:FinishMove(0)
		return
	end

	playSansSFX(ctx, "GasterBlasterCharge", primary, 3)

	openJaws(blaster, data)
	forcePrimaryInvisible(blaster)

	task.wait(data.ChargeTime or 0.45)

	if not ctx:IsActive() then
		blaster:Destroy()
		ctx:FinishMove(0)
		return
	end

	local beamStart = getWorldBeamPosition(blaster)

	playSansSFX(ctx, "GasterBlasterShoot", primary, 3)

	hideRightEye(blaster)
	forcePrimaryInvisible(blaster)

	local activeTime = data.BeamActiveTime or 0.4
	local tickRate = data.BeamTickRate or 0.08
	local totalTicks = math.max(1, math.floor(activeTime / tickRate + 0.5))

	for tickIndex = 1, totalTicks do
		if not ctx:IsActive() then
			break
		end

		local isFinalTick = tickIndex == totalTicks

		createBeamVisual(beamStart, direction, data)
		doBeamTick(ctx, beamStart, direction, data, isFinalTick)

		task.wait(tickRate)
	end

	task.delay(0.2, function()
		if blaster and blaster.Parent then
			blaster:Destroy()
		end
	end)

	ctx:FinishMove(0.12)
end

return GasterBlaster