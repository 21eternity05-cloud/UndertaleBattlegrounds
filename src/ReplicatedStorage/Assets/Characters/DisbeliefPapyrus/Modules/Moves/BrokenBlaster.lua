-- BrokenBlaster
-- ReplicatedStorage > Assets > Characters > DisbeliefPapyrus > Modules > Moves > BrokenBlaster

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrokenBlaster = {
	DisplayName = "Broken Blaster",
	AnimationName = "BrokenBlaster",

	Cooldown = 14,
	Duration = 1.45,
	LockTime = 1.15,
	MaxLockTime = 1.75,

	-- Ram hit: weak hit that confirms the blast.
	-- It can stun, but it does NOT guardbreak.
	RamDamage = 4,
	RamStun = 0.45,
	RamRadius = 4.75,
	RamGuardbreak = false,

	-- Blast hit: main damage and launch.
	-- This is the part that guardbreaks.
	BlastDamage = 12,
	BlastStun = 0.65,
	BlastRadius = 5.75,
	BlastGuardbreak = true,

	-- These are here for compatibility with your move system.
	Damage = 12,
	Stun = 0.65,
	Radius = 5.75,
	Offset = CFrame.new(0, 0, 0),

	Blockable = true,
	CanBeBlocked = true,
	Unblockable = false,

	Guardbreak = false,
	CanBeCountered = true,
	HitCancelsTarget = true,
	CancelableByHit = true,

	HasIFrames = false,
	HasArmor = false,

	Startup = 0.28,

	-- Blaster starts close, then rams forward.
	SpawnForwardOffset = 3.2,
	SpawnHeightOffset = 2.2,
	SpawnSideOffset = 1.6,

	RamSpeed = 88,
	RamLifetime = 0.36,
	RamHitboxTickRate = 0.035,

	-- After ram confirms, fire point blank.
	ConfirmFreezeTime = 0.7,
	FireDelayAfterRam = 0.45,

	-- Short beam, not Sans sniper range.
	BeamRange = 26,
	BeamStep = 5,
	BeamDuration = 0.16,
	BeamTickRate = 0.04,

	FadeTime = 0.18,

	-- Strong MovementService knockback on normal blast hits only.
	KnockbackPreset = "PresetKnockback",
	PresetKnockbackSpeed = 105,
	PresetKnockbackUpward = 26,
	PresetKnockbackDuration = 0.32,
	PresetKnockbackMaxForce = 100000,

	-- Backward compatibility.
	Knockback = 105,
	UpwardKnockback = 26,
	KnockbackDuration = 0.32,
	KnockbackMaxForce = 100000,
}

local function copyTable(source)
	local copy = {}

	for key, value in pairs(source or {}) do
		copy[key] = value
	end

	return copy
end

local function getPapyrusVFXFolder(ctx)
	local assets = ReplicatedStorage:WaitForChild(ctx.Config.AssetsFolderName or "Assets")
	local characters = assets:WaitForChild(ctx.Config.CharactersFolderName or "Characters")
	local papyrus = characters:WaitForChild("DisbeliefPapyrus")

	return papyrus:WaitForChild("VFX")
end

local function getVFXTemplate(ctx, name)
	local vfxFolder = getPapyrusVFXFolder(ctx)
	local template = vfxFolder:FindFirstChild(name)

	if not template then
		return nil
	end

	return template
end

local function getBrokenBlasterTemplate(ctx)
	local template = getVFXTemplate(ctx, "BrokenBlaster")

	if not template then
		warn("[BrokenBlaster] Missing VFX: DisbeliefPapyrus > VFX > BrokenBlaster")
	end

	return template
end

local function getBrokenBlasterBeamTemplate(ctx)
	return getVFXTemplate(ctx, "BrokenBlasterBeam")
end

local function ensurePrimaryPart(object)
	if object:IsA("Model") then
		if object.PrimaryPart then
			return object.PrimaryPart
		end

		local namedPrimary = object:FindFirstChild("PrimaryPart", true)

		if namedPrimary and namedPrimary:IsA("BasePart") then
			object.PrimaryPart = namedPrimary
			return namedPrimary
		end

		local firstPart = object:FindFirstChildWhichIsA("BasePart", true)

		if firstPart then
			object.PrimaryPart = firstPart
			return firstPart
		end

		return nil
	end

	if object:IsA("BasePart") then
		return object
	end

	return nil
end

local function forcePrimaryPartInvisible(object)
	if not object then return end

	if object:IsA("Model") then
		local primary = ensurePrimaryPart(object)

		if primary then
			primary.Transparency = 1
			primary.CanCollide = false
			primary.CanTouch = false
			primary.CanQuery = false
			primary.Massless = true
		end

		local namedPrimary = object:FindFirstChild("PrimaryPart", true)

		if namedPrimary and namedPrimary:IsA("BasePart") then
			namedPrimary.Transparency = 1
			namedPrimary.CanCollide = false
			namedPrimary.CanTouch = false
			namedPrimary.CanQuery = false
			namedPrimary.Massless = true
		end
	elseif object:IsA("BasePart") and object.Name == "PrimaryPart" then
		object.Transparency = 1
		object.CanCollide = false
		object.CanTouch = false
		object.CanQuery = false
		object.Massless = true
	end
end

local function pivotObject(object, cframe)
	if object:IsA("Model") then
		if not ensurePrimaryPart(object) then return end
		object:PivotTo(cframe)
	elseif object:IsA("BasePart") then
		object.CFrame = cframe
	end

	forcePrimaryPartInvisible(object)
end

local function getAllParts(object)
	local parts = {}

	if object:IsA("BasePart") then
		table.insert(parts, object)
	end

	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	return parts
end

local function emitParticles(object)
	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			local emitCount = descendant:GetAttribute("EmitCount")

			if typeof(emitCount) ~= "number" then
				emitCount = 1
			end

			descendant:Emit(emitCount)
		elseif descendant:IsA("Trail") then
			descendant.Enabled = true
		elseif descendant:IsA("Beam") then
			descendant.Enabled = true
		end
	end
end

local function prepareVFXObject(object)
	if object:IsA("BasePart") then
		object.Anchored = true
		object.CanCollide = false
		object.CanTouch = false
		object.CanQuery = false
		object.Massless = true
	end

	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		elseif descendant:IsA("Trail") then
			descendant.Enabled = true
		elseif descendant:IsA("Beam") then
			descendant.Enabled = true
		end
	end

	forcePrimaryPartInvisible(object)
	emitParticles(object)
end

local function setVisibleTransparency(object, transparency)
	for _, part in ipairs(getAllParts(object)) do
		if part.Name == "PrimaryPart" then
			part.Transparency = 1
		else
			part.Transparency = transparency
		end
	end

	forcePrimaryPartInvisible(object)
end

local function fadeAndDestroyVFX(object, fadeTime)
	fadeTime = fadeTime or 0.18

	if not object or not object.Parent then
		return
	end

	for _, part in ipairs(getAllParts(object)) do
		if part.Name ~= "PrimaryPart" then
			TweenService:Create(
				part,
				TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Transparency = 1 }
			):Play()
		else
			part.Transparency = 1
		end
	end

	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false
		elseif descendant:IsA("Trail") then
			descendant.Enabled = false
		elseif descendant:IsA("Beam") then
			descendant.Enabled = false
		end
	end

	forcePrimaryPartInvisible(object)
	Debris:AddItem(object, fadeTime + 0.1)
end

local function playPapyrusSFX(ctx, soundName, parentPart, lifetime)
	if not ctx.VFXService then return end
	if not ctx.VFXService.PlayCharacterSFXAtPart then return end
	if not parentPart or not parentPart.Parent then return end

	local played = ctx.VFXService:PlayCharacterSFXAtPart(
		"DisbeliefPapyrus",
		soundName,
		parentPart,
		lifetime or 2
	)

	if not played then
		ctx.VFXService:PlayCharacterSFXAtPart("Sans", soundName, parentPart, lifetime or 2)
	end
end

local function getPayload(ctx)
	return ctx.Payload
		or ctx.Input
		or ctx.MovePayload
		or ctx.Data
		or {}
end

local function toVector3(value)
	if typeof(value) == "Vector3" then
		return value
	end

	if typeof(value) == "CFrame" then
		return value.LookVector
	end

	if typeof(value) == "table" then
		local x = value.X or value.x or value[1]
		local y = value.Y or value.y or value[2]
		local z = value.Z or value.z or value[3]

		if typeof(x) == "number" and typeof(y) == "number" and typeof(z) == "number" then
			return Vector3.new(x, y, z)
		end
	end

	return nil
end

local function getAimDirection(ctx)
	local root = ctx.Root
	local payload = getPayload(ctx)

	local aimDirection =
		toVector3(payload.AimDirection)
		or toVector3(payload.CameraLookVector)
		or toVector3(payload.LookVector)
		or toVector3(payload.CameraCFrame)
		or toVector3(payload.AimCFrame)

	if not aimDirection and ctx.AimDirection then
		aimDirection = toVector3(ctx.AimDirection)
	end

	if not aimDirection and ctx.CameraLookVector then
		aimDirection = toVector3(ctx.CameraLookVector)
	end

	if not aimDirection and root then
		aimDirection = root.CFrame.LookVector
	end

	if not aimDirection or aimDirection.Magnitude < 0.05 then
		aimDirection = Vector3.new(0, 0, -1)
	end

	local flatDirection = Vector3.new(aimDirection.X, 0, aimDirection.Z)

	if flatDirection.Magnitude < 0.05 then
		if root then
			flatDirection = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		end

		if flatDirection.Magnitude < 0.05 then
			flatDirection = Vector3.new(0, 0, -1)
		end
	end

	return flatDirection.Unit
end

local function getLookCFrame(position, direction)
	local flatDirection = Vector3.new(direction.X, 0, direction.Z)

	if flatDirection.Magnitude < 0.05 then
		flatDirection = Vector3.new(0, 0, -1)
	end

	flatDirection = flatDirection.Unit

	return CFrame.lookAt(position, position + flatDirection)
end

local function isMoveInterrupted(ctx)
	local character = ctx.Character

	if not ctx:IsActive() then
		return true
	end

	if ctx.CombatStatusService and ctx.CombatStatusService.CanAttackContinue then
		return not ctx.CombatStatusService:CanAttackContinue(character, ctx.MoveData)
	end

	return character:GetAttribute("Stunned") == true
		or character:GetAttribute("Guardbroken") == true
end

local function makeHitData(moveData, damage, stun, radius)
	local hitData = copyTable(moveData)

	hitData.Damage = damage
	hitData.Stun = stun
	hitData.Radius = radius
	hitData.Offset = CFrame.new(0, 0, 0)

	return hitData
end

local function makeNoKnockbackHitData(moveData, damage, stun, radius)
	local hitData = makeHitData(moveData, damage, stun, radius)

	hitData.KnockbackPreset = nil

	hitData.PresetKnockbackSpeed = nil
	hitData.PresetKnockbackUpward = nil
	hitData.PresetKnockbackDuration = nil
	hitData.PresetKnockbackMaxForce = nil

	hitData.DirectionalSpeed = nil
	hitData.DirectionalDuration = nil
	hitData.DirectionalMaxForce = nil
	hitData.DirectionalYHoldDuration = nil

	hitData.DownForwardSpeed = nil
	hitData.DownSpeed = nil
	hitData.DownLaunchMaxForce = nil

	hitData.Knockback = 0
	hitData.UpwardKnockback = 0
	hitData.KnockbackDuration = 0
	hitData.KnockbackMaxForce = 0

	return hitData
end

local function makeRamConfirmHitData(moveData)
	local hitData = makeNoKnockbackHitData(
		moveData,
		moveData.RamDamage or 4,
		moveData.RamStun or 0.45,
		moveData.RamRadius or 4.75
	)

	hitData.Blockable = true
	hitData.CanBeBlocked = true
	hitData.Unblockable = false

	-- Ram does NOT guardbreak.
	-- It can still stun, damage, and confirm the beam.
	hitData.Guardbreak = false
	hitData.CanBeCountered = moveData.CanBeCountered
	hitData.HitCancelsTarget = true
	hitData.CancelableByHit = false

	return hitData
end

local function makeRamHitboxData(moveData)
	return {
		Radius = moveData.RamRadius or 4.75,
		Offset = CFrame.new(0, 0, 0),

		Damage = moveData.RamDamage or 4,
		Stun = moveData.RamStun or 0.45,

		Blockable = true,
		CanBeBlocked = true,
		Unblockable = false,

		-- Ram does NOT guardbreak.
		Guardbreak = false,
		CanBeCountered = moveData.CanBeCountered,
		HitCancelsTarget = true,

		CancelableByHit = false,
		HasIFrames = moveData.HasIFrames,
		HasArmor = moveData.HasArmor,

		Knockback = 0,
		UpwardKnockback = 0,
		KnockbackDuration = 0,
		KnockbackMaxForce = 0,
	}
end

local function makeManualKnockbackData(moveData)
	local knockbackData = copyTable(moveData)

	knockbackData.KnockbackPreset = "PresetKnockback"
	knockbackData.PresetKnockbackSpeed = moveData.PresetKnockbackSpeed or moveData.Knockback or 105
	knockbackData.PresetKnockbackUpward = moveData.PresetKnockbackUpward or moveData.UpwardKnockback or 26
	knockbackData.PresetKnockbackDuration = moveData.PresetKnockbackDuration or moveData.KnockbackDuration or 0.32
	knockbackData.PresetKnockbackMaxForce = moveData.PresetKnockbackMaxForce or moveData.KnockbackMaxForce or 100000

	knockbackData.Knockback = knockbackData.PresetKnockbackSpeed
	knockbackData.UpwardKnockback = knockbackData.PresetKnockbackUpward
	knockbackData.KnockbackDuration = knockbackData.PresetKnockbackDuration
	knockbackData.KnockbackMaxForce = knockbackData.PresetKnockbackMaxForce

	return knockbackData
end

local function applyBlastKnockback(ctx, blastDirection, targetRoot, moveData)
	if not targetRoot or not targetRoot.Parent then
		return
	end

	if not ctx.MovementService or not ctx.MovementService.ApplyPresetKnockback then
		warn("[BrokenBlaster] Missing MovementService:ApplyPresetKnockback")
		return
	end

	local direction = Vector3.new(blastDirection.X, 0, blastDirection.Z)

	if direction.Magnitude < 0.05 then
		direction = Vector3.new(0, 0, -1)
	else
		direction = direction.Unit
	end

	local knockbackOrigin = Instance.new("Part")
	knockbackOrigin.Name = "BrokenBlasterKnockbackOrigin"
	knockbackOrigin.Anchored = true
	knockbackOrigin.CanCollide = false
	knockbackOrigin.CanTouch = false
	knockbackOrigin.CanQuery = false
	knockbackOrigin.Transparency = 1
	knockbackOrigin.Size = Vector3.new(1, 1, 1)
	knockbackOrigin.CFrame = getLookCFrame(targetRoot.Position - (direction * 6), direction)
	knockbackOrigin.Parent = workspace

	Debris:AddItem(knockbackOrigin, 0.25)

	ctx.MovementService:ApplyPresetKnockback(
		knockbackOrigin,
		targetRoot,
		makeManualKnockbackData(moveData),
		"BrokenBlasterBlast"
	)
end

local function buildSphereHitboxData(moveData, damage, stun, radius)
	return {
		Radius = radius,
		Offset = CFrame.new(0, 0, 0),

		Damage = damage,
		Stun = stun,

		Blockable = moveData.Blockable,
		CanBeBlocked = moveData.CanBeBlocked,
		Unblockable = moveData.Unblockable,

		Guardbreak = moveData.Guardbreak,
		CanBeCountered = moveData.CanBeCountered,
		HitCancelsTarget = moveData.HitCancelsTarget,

		CancelableByHit = moveData.CancelableByHit,
		HasIFrames = moveData.HasIFrames,
		HasArmor = moveData.HasArmor,
	}
end

local function freezeTargetBriefly(ctx, targetCharacter, targetRoot, duration)
	if not targetCharacter or not targetCharacter.Parent then return end

	duration = duration or 0.28

	if duration <= 0 then
		return
	end

	if ctx.StateService and ctx.StateService.StunCharacter then
		ctx.StateService:StunCharacter(targetCharacter, duration)
	else
		targetCharacter:SetAttribute("Stunned", true)
		targetCharacter:SetAttribute("DashLocked", true)
		targetCharacter:SetAttribute("MovementLocked", true)

		task.delay(duration, function()
			if not targetCharacter or not targetCharacter.Parent then return end

			targetCharacter:SetAttribute("Stunned", false)
			targetCharacter:SetAttribute("DashLocked", false)
			targetCharacter:SetAttribute("MovementLocked", false)
		end)
	end

	if targetRoot and targetRoot.Parent then
		targetRoot.AssemblyLinearVelocity = Vector3.zero
		targetRoot.AssemblyAngularVelocity = Vector3.zero
	end
end

local function spawnBlasterVFX(ctx, blasterCFrame)
	local template = getBrokenBlasterTemplate(ctx)

	if not template then
		return nil
	end

	local blaster = template:Clone()
	blaster.Name = "ActiveBrokenBlaster"

	if blaster:IsA("Model") and not ensurePrimaryPart(blaster) then
		warn("[BrokenBlaster] BrokenBlaster model has no PrimaryPart/BasePart")
		blaster:Destroy()
		return nil
	end

	prepareVFXObject(blaster)
	setVisibleTransparency(blaster, 0)

	blaster.Parent = workspace
	pivotObject(blaster, blasterCFrame)

	return blaster
end

local function spawnBeamVFX(ctx, startPosition, direction, range, lifetime)
	local template = getBrokenBlasterBeamTemplate(ctx)

	if not template then
		return nil
	end

	local centerPosition = startPosition + (direction * (range * 0.5))
	local beamCFrame = getLookCFrame(centerPosition, direction)

	local beam = template:Clone()
	beam.Name = "ActiveBrokenBlasterBeam"

	if beam:IsA("Model") and not ensurePrimaryPart(beam) then
		beam:Destroy()
		return nil
	end

	prepareVFXObject(beam)
	setVisibleTransparency(beam, 0)

	beam.Parent = workspace
	pivotObject(beam, beamCFrame)

	Debris:AddItem(beam, lifetime or 0.35)

	task.delay(lifetime or 0.25, function()
		fadeAndDestroyVFX(beam, 0.12)
	end)

	return beam
end

local function applyStandardHit(ctx, targetCharacter, targetHumanoid, targetRoot, hitData, moveId)
	if ctx.ApplyStandardHit then
		return ctx:ApplyStandardHit(
			targetCharacter,
			targetHumanoid,
			targetRoot,
			hitData,
			moveId
		)
	end

	return ctx:DefaultApplyHit(targetCharacter, targetHumanoid, targetRoot)
end

local function firePointBlankBlast(ctx, blaster, startPosition, direction, confirmedTargetCharacter)
	local character = ctx.Character
	local root = ctx.Root
	local moveData = ctx.MoveData

	local beamRange = moveData.BeamRange or 26
	local beamStep = moveData.BeamStep or 5
	local beamDuration = moveData.BeamDuration or 0.16
	local beamTickRate = moveData.BeamTickRate or 0.04

	local blastHitboxData = buildSphereHitboxData(
		moveData,
		moveData.BlastDamage or 12,
		moveData.BlastStun or 0.65,
		moveData.BlastRadius or 5.75
	)

	-- Beam is the guardbreak part.
	blastHitboxData.Guardbreak = moveData.BlastGuardbreak ~= false
	blastHitboxData.Blockable = true
	blastHitboxData.CanBeBlocked = true
	blastHitboxData.Unblockable = false

	local blastHitData = makeNoKnockbackHitData(
		moveData,
		moveData.BlastDamage or 12,
		moveData.BlastStun or 0.65,
		moveData.BlastRadius or 5.75
	)

	-- Beam is the guardbreak part.
	blastHitData.Guardbreak = moveData.BlastGuardbreak ~= false
	blastHitData.Blockable = true
	blastHitData.CanBeBlocked = true
	blastHitData.Unblockable = false

	local alreadyHit = {}

	playPapyrusSFX(ctx, "BrokenBlasterFire", root, 2)
	spawnBeamVFX(ctx, startPosition, direction, beamRange, beamDuration + 0.2)

	local startTime = os.clock()
	local lastTick = beamTickRate

	local connection
	connection = RunService.Heartbeat:Connect(function(deltaTime)
		if not ctx:IsActive() then
			if connection then
				connection:Disconnect()
			end
			return
		end

		local elapsed = os.clock() - startTime

		if elapsed >= beamDuration then
			if connection then
				connection:Disconnect()
			end
			return
		end

		lastTick += deltaTime

		if lastTick < beamTickRate then
			return
		end

		lastTick = 0

		local distance = 0

		while distance <= beamRange do
			local spherePosition = startPosition + (direction * distance)
			local sphereCFrame = getLookCFrame(spherePosition, direction)

			ctx.HitboxService:PerformSphereAtCFrame(
				character,
				sphereCFrame,
				blastHitboxData,
				function(targetCharacter, targetHumanoid, targetRoot)
					if alreadyHit[targetCharacter] then
						return
					end

					alreadyHit[targetCharacter] = true

					local result = applyStandardHit(
						ctx,
						targetCharacter,
						targetHumanoid,
						targetRoot,
						blastHitData,
						ctx.MoveId or "BrokenBlaster"
					)

					if result == "Hit" or result == "ArmoredHit" then
						applyBlastKnockback(ctx, direction, targetRoot, moveData)
						playPapyrusSFX(ctx, "BrokenBlasterHit", targetRoot, 2)
					elseif result == "Blocked" then
						playPapyrusSFX(ctx, "Block", targetRoot, 2)
					elseif result == "Guardbreak" then
						-- Guardbreak should break block/stun in place, not launch.
						playPapyrusSFX(ctx, "BlockBreak", targetRoot, 2)

						if targetRoot and targetRoot.Parent then
							targetRoot.AssemblyLinearVelocity = Vector3.zero
							targetRoot.AssemblyAngularVelocity = Vector3.zero
						end
					end

					print("[BrokenBlaster] Blast result:", result)
				end
			)

			distance += beamStep
		end
	end)

	task.delay(beamDuration + 0.15, function()
		if connection then
			connection:Disconnect()
		end

		if blaster and blaster.Parent then
			fadeAndDestroyVFX(blaster, moveData.FadeTime or 0.18)
		end
	end)
end

local function confirmPointBlankBlast(ctx, blaster, direction, targetCharacter, targetRoot)
	local moveData = ctx.MoveData

	if not targetRoot or not targetRoot.Parent then
		fadeAndDestroyVFX(blaster, moveData.FadeTime or 0.18)

		task.delay(0.25, function()
			ctx:FinishMove(0)
		end)

		return
	end

	local pointBlankPosition =
		targetRoot.Position
		- (direction * 3.2)
		+ Vector3.new(0, moveData.SpawnHeightOffset or 2.2, 0)

	local pointBlankCFrame = getLookCFrame(pointBlankPosition, direction)

	pivotObject(blaster, pointBlankCFrame)

	task.delay(moveData.FireDelayAfterRam or 0.45, function()
		if not ctx:IsActive() then
			fadeAndDestroyVFX(blaster, moveData.FadeTime or 0.18)
			ctx:FinishMove(0)
			return
		end

		local beamStartPosition = pointBlankPosition + (direction * 3.5)

		firePointBlankBlast(
			ctx,
			blaster,
			beamStartPosition,
			direction,
			targetCharacter
		)

		task.delay(
			(moveData.BeamDuration or 0.16)
				+ (moveData.FadeTime or 0.18)
				+ 0.25,
			function()
				ctx:FinishMove(0)
			end
		)
	end)
end

function BrokenBlaster.Execute(ctx)
	print("[BrokenBlaster] Execute started")

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

	if not ctx.HitboxService or not ctx.HitboxService.PerformSphereAtCFrame then
		warn("[BrokenBlaster] Missing HitboxService:PerformSphereAtCFrame")
		ctx:FinishMove(0)
		return
	end

	task.wait(moveData.Startup or 0.28)

	if isMoveInterrupted(ctx) then
		ctx:FinishMove(0)
		return
	end

	local direction = getAimDirection(ctx)
	local right = Vector3.new(root.CFrame.RightVector.X, 0, root.CFrame.RightVector.Z)

	if right.Magnitude < 0.05 then
		right = Vector3.new(1, 0, 0)
	else
		right = right.Unit
	end

	local blasterPosition =
		root.Position
		+ Vector3.new(0, moveData.SpawnHeightOffset or 2.2, 0)
		+ (direction * (moveData.SpawnForwardOffset or 3.2))
		+ (right * (moveData.SpawnSideOffset or 1.6))

	local blasterCFrame = getLookCFrame(blasterPosition, direction)
	local blaster = spawnBlasterVFX(ctx, blasterCFrame)

	if not blaster then
		ctx:FinishMove(0)
		return
	end

	playPapyrusSFX(ctx, "BrokenBlasterSummon", root, 2)
	playPapyrusSFX(ctx, "BrokenBlasterRam", root, 2)

	local ramHitboxData = makeRamHitboxData(moveData)
	local ramHitData = makeRamConfirmHitData(moveData)

	local ramSpeed = moveData.RamSpeed or 88
	local ramLifetime = moveData.RamLifetime or 0.36
	local ramTickRate = moveData.RamHitboxTickRate or 0.035

	local startTime = os.clock()
	local lastHitboxTime = ramTickRate
	local finished = false

	local connection
	connection = RunService.Heartbeat:Connect(function(deltaTime)
		if finished then return end

		if not ctx:IsActive() or isMoveInterrupted(ctx) then
			finished = true

			if connection then
				connection:Disconnect()
			end

			fadeAndDestroyVFX(blaster, moveData.FadeTime or 0.18)
			ctx:FinishMove(0)
			return
		end

		local elapsed = os.clock() - startTime

		if elapsed >= ramLifetime then
			finished = true

			if connection then
				connection:Disconnect()
			end

			fadeAndDestroyVFX(blaster, moveData.FadeTime or 0.18)

			task.delay(moveData.WhiffEndlag or 0.25, function()
				ctx:FinishMove(0)
			end)

			return
		end

		blasterPosition += direction * ramSpeed * deltaTime
		blasterCFrame = getLookCFrame(blasterPosition, direction)
		pivotObject(blaster, blasterCFrame)

		lastHitboxTime += deltaTime

		if lastHitboxTime < ramTickRate then
			return
		end

		lastHitboxTime = 0

		ctx.HitboxService:PerformSphereAtCFrame(
			character,
			blasterCFrame,
			ramHitboxData,
			function(targetCharacter, targetHumanoid, targetRoot)
				if finished then
					return
				end

				finished = true

				if connection then
					connection:Disconnect()
				end

				local result = applyStandardHit(
					ctx,
					targetCharacter,
					targetHumanoid,
					targetRoot,
					ramHitData,
					ctx.MoveId or "BrokenBlasterRam"
				)

				print("[BrokenBlaster] Ram result:", result)

				-- IMPORTANT:
				-- Ram confirms the beam on normal hit, armored hit, block, or guardbreak.
				-- Ram itself does NOT guardbreak.
				if result == "Hit" or result == "ArmoredHit" or result == "Blocked" or result == "Guardbreak" then
					if result == "Blocked" then
						playPapyrusSFX(ctx, "Block", targetRoot, 2)
					elseif result == "Guardbreak" then
						playPapyrusSFX(ctx, "BlockBreak", targetRoot, 2)
					else
						playPapyrusSFX(ctx, "BrokenBlasterHit", targetRoot, 2)
					end

					if result == "Hit" or result == "ArmoredHit" then
						freezeTargetBriefly(ctx, targetCharacter, targetRoot, moveData.ConfirmFreezeTime or 0.28)
					end

					confirmPointBlankBlast(ctx, blaster, direction, targetCharacter, targetRoot)
				else
					fadeAndDestroyVFX(blaster, moveData.FadeTime or 0.18)

					task.delay(0.25, function()
						ctx:FinishMove(0)
					end)
				end
			end
		)
	end)

	task.delay((moveData.MaxLockTime or 1.75) + 0.35, function()
		if finished then
			return
		end

		finished = true

		if connection then
			connection:Disconnect()
		end

		fadeAndDestroyVFX(blaster, moveData.FadeTime or 0.18)
		ctx:FinishMove(0)
	end)
end

return BrokenBlaster