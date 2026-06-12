-- YoureBlueNow
-- ReplicatedStorage > Assets > Characters > DisbeliefPapyrus > Modules > Moves > YoureBlueNow
-- Display name: "You're Blue Now!"
-- Awakened Papyrus move 2.
-- Uses project MovementService knockback instead of custom velocity knockback.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local YoureBlueNow = {
	DisplayName = "You're Blue Now!",
	AnimationName = "YoureBlueNow",

	Cooldown = 13,
	Duration = 2.25,
	LockTime = 1.85,
	MaxLockTime = 2.75,

	Startup = 0.22,
	Endlag = 0.2,
	WhiffEndlag = 0.3,

	-- Initial grab hitbox.
	Radius = 7,
	Offset = CFrame.new(0, 0, -5),
	Damage = 3,
	Stun = 0.18,

	-- Lift.
	HoldTime = 0.85,
	HoldHeight = 17,
	HoldForwardOffset = 8,
	HoldResponsiveness = 45,
	HoldMaxForce = 140000,
	HoldMaxVelocity = 85,

	-- Blaster.
	BlasterSpawnDistance = 13,
	BlasterHeightOffset = 2.5,
	BlasterEnterDistance = 8,
	BlasterEnterHeight = 3.5,
	BlasterEnterTime = 0.22,
	BlasterFireDelay = 0.22,

	-- Beam.
	BeamDamage = 15,
	BeamStun = 0.35,
	BeamRadius = 6.25,
	BeamRange = 34,
	BeamStep = 5,
	BeamDuration = 0.18,
	BeamTickRate = 0.04,

	-- Beam knockback through MovementService.
	KnockbackPreset = "PresetKnockback",
	PresetKnockbackSpeed = 165,
	PresetKnockbackUpward = 0,
	PresetKnockbackDuration = 0.3,
	PresetKnockbackMaxForce = 130000,

	Knockback = 165,
	UpwardKnockback = 0,
	KnockbackDuration = 0.3,
	KnockbackMaxForce = 130000,

	Blockable = true,
	CanBeBlocked = true,
	Unblockable = false,
	Guardbreak = false,

	CanBeCountered = true,
	HitCancelsTarget = true,
	CancelableByHit = true,

	HasIFrames = false,
	HasArmor = false,
	PlayMoveHitVFX = false,
}

local function copyTable(source)
	local copy = {}

	for key, value in pairs(source or {}) do
		copy[key] = value
	end

	return copy
end

local function getAssetsFolder(ctx)
	return ReplicatedStorage:FindFirstChild(ctx.Config.AssetsFolderName or "Assets")
end

local function getCharactersFolder(ctx)
	local assets = getAssetsFolder(ctx)
	if not assets then
		return nil
	end

	return assets:FindFirstChild(ctx.Config.CharactersFolderName or "Characters")
end

local function getPapyrusFolder(ctx)
	local characters = getCharactersFolder(ctx)
	if not characters then
		return nil
	end

	return characters:FindFirstChild("DisbeliefPapyrus")
end

local function getPapyrusVFXFolder(ctx)
	local papyrus = getPapyrusFolder(ctx)
	if not papyrus then
		return nil
	end

	return papyrus:FindFirstChild("VFX")
end

local function getPapyrusVFX(ctx, name)
	local vfxFolder = getPapyrusVFXFolder(ctx)
	if not vfxFolder then
		return nil
	end

	return vfxFolder:FindFirstChild(name)
end

local function playPapyrusSFX(ctx, soundName, part, lifetime)
	if not ctx then
		return
	end

	if not ctx.VFXService then
		return
	end

	if not ctx.VFXService.PlayCharacterSFXAtPart then
		return
	end

	if not part or not part.Parent then
		return
	end

	pcall(function()
		ctx.VFXService:PlayCharacterSFXAtPart(
			"DisbeliefPapyrus",
			soundName,
			part,
			lifetime or 2
		)
	end)
end

local function getFlatDirection(vector)
	local direction = Vector3.new(vector.X, 0, vector.Z)

	if direction.Magnitude < 0.05 then
		return Vector3.new(0, 0, -1)
	end

	return direction.Unit
end

local function getRootDirection(root)
	if not root then
		return Vector3.new(0, 0, -1)
	end

	return getFlatDirection(root.CFrame.LookVector)
end

local function lookAtFlat(position, direction)
	local flatDirection = getFlatDirection(direction)
	return CFrame.lookAt(position, position + flatDirection)
end

local function ensurePrimaryPart(object)
	if not object then
		return nil
	end

	if object:IsA("BasePart") then
		return object
	end

	if object:IsA("Model") then
		if object.PrimaryPart then
			return object.PrimaryPart
		end

		local primary = object:FindFirstChild("PrimaryPart", true)
		if primary and primary:IsA("BasePart") then
			object.PrimaryPart = primary
			return primary
		end

		local firstPart = object:FindFirstChildWhichIsA("BasePart", true)
		if firstPart then
			object.PrimaryPart = firstPart
			return firstPart
		end
	end

	return nil
end

local function pivotObject(object, cframe)
	if not object then
		return
	end

	if object:IsA("Model") then
		local primary = ensurePrimaryPart(object)
		if primary then
			object:PivotTo(cframe)
		end
	elseif object:IsA("BasePart") then
		object.CFrame = cframe
	end
end

local function getAllParts(object)
	local parts = {}

	if not object then
		return parts
	end

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

local function prepWorldVFX(object)
	if not object then
		return
	end

	for _, part in ipairs(getAllParts(object)) do
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true

		if part.Name == "PrimaryPart" then
			part.Transparency = 1
		end
	end

	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			local emitCount = descendant:GetAttribute("EmitCount")
			if typeof(emitCount) ~= "number" then
				emitCount = 1
			end

			descendant:Emit(emitCount)
		elseif descendant:IsA("Beam") then
			descendant.Enabled = true
		elseif descendant:IsA("Trail") then
			descendant.Enabled = true
		end
	end
end

local function prepAttachedVFX(object)
	if not object then
		return
	end

	for _, part in ipairs(getAllParts(object)) do
		part.Anchored = false
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
	end

	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			-- Emit once only when the victim gets hit.
			descendant.Enabled = false

			local emitCount = descendant:GetAttribute("EmitCount")
			if typeof(emitCount) ~= "number" then
				emitCount = 8
			end

			descendant:Emit(emitCount)
		elseif descendant:IsA("Beam") then
			descendant.Enabled = false
		elseif descendant:IsA("Trail") then
			descendant.Enabled = false
		end
	end
end

local function fadeAndDestroy(object, fadeTime)
	fadeTime = fadeTime or 0.15

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
		end
	end

	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false
		elseif descendant:IsA("Beam") then
			descendant.Enabled = false
		elseif descendant:IsA("Trail") then
			descendant.Enabled = false
		end
	end

	Debris:AddItem(object, fadeTime + 0.1)
end

local function spawnBlueHeart(ctx, victimRoot, lifetime)
	lifetime = lifetime or 1.3

	if not victimRoot or not victimRoot.Parent then
		return nil
	end

	local template = getPapyrusVFX(ctx, "BlueHeart")
	if not template then
		warn("[YoureBlueNow] Missing DisbeliefPapyrus > VFX > BlueHeart")
		return nil
	end

	local heart = template:Clone()
	heart.Name = "YoureBlueNowBlueHeart"

	local primary = ensurePrimaryPart(heart)
	if heart:IsA("Model") and not primary then
		warn("[YoureBlueNow] BlueHeart has no BasePart or PrimaryPart.")
		heart:Destroy()
		return nil
	end

	prepAttachedVFX(heart)

	heart.Parent = victimRoot

	local heartCFrame = victimRoot.CFrame * CFrame.new(0, 0, -1.25)
	pivotObject(heart, heartCFrame)

	primary = ensurePrimaryPart(heart)

	if primary then
		local weld = Instance.new("WeldConstraint")
		weld.Name = "BlueHeartWeld"
		weld.Part0 = primary
		weld.Part1 = victimRoot
		weld.Parent = primary
	elseif heart:IsA("BasePart") then
		local weld = Instance.new("WeldConstraint")
		weld.Name = "BlueHeartWeld"
		weld.Part0 = heart
		weld.Part1 = victimRoot
		weld.Parent = heart
	end

	task.delay(lifetime - 0.15, function()
		fadeAndDestroy(heart, 0.15)
	end)

	Debris:AddItem(heart, lifetime)

	return heart
end

local function spawnBlaster(ctx, cframe)
	local template = getPapyrusVFX(ctx, "BrokenBlaster")

	if not template then
		warn("[YoureBlueNow] Missing DisbeliefPapyrus > VFX > BrokenBlaster")
		return nil
	end

	local blaster = template:Clone()
	blaster.Name = "YoureBlueNowBlaster"

	if blaster:IsA("Model") and not ensurePrimaryPart(blaster) then
		warn("[YoureBlueNow] BrokenBlaster has no BasePart or PrimaryPart.")
		blaster:Destroy()
		return nil
	end

	prepWorldVFX(blaster)
	blaster.Parent = workspace
	pivotObject(blaster, cframe)

	return blaster
end

local function spawnBeamVisual(ctx, startPosition, direction, range, lifetime)
	lifetime = lifetime or 0.25

	local template = getPapyrusVFX(ctx, "BrokenBlasterBeam")

	if template then
		local beam = template:Clone()
		beam.Name = "YoureBlueNowBeam"

		if beam:IsA("Model") and not ensurePrimaryPart(beam) then
			beam:Destroy()
			return nil
		end

		prepWorldVFX(beam)

		local center = startPosition + (direction * (range * 0.5))
		beam.Parent = workspace
		pivotObject(beam, lookAtFlat(center, direction))

		task.delay(lifetime, function()
			fadeAndDestroy(beam, 0.12)
		end)

		Debris:AddItem(beam, lifetime + 0.3)

		return beam
	end

	local length = range or 34
	local part = Instance.new("Part")
	part.Name = "YoureBlueNowGeneratedBeam"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 255, 255)
	part.Transparency = 0.18
	part.Size = Vector3.new(7, 7, length)

	local center = startPosition + (direction * (length * 0.5))
	part.CFrame = CFrame.lookAt(center, center + direction)
	part.Parent = workspace

	TweenService:Create(
		part,
		TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Transparency = 1,
			Size = Vector3.new(2, 2, length),
		}
	):Play()

	Debris:AddItem(part, 0.22)

	return part
end

local function makeGrabAttackData(moveData)
	local data = copyTable(moveData)

	data.AttackType = "Move"
	data.Damage = moveData.Damage or 3
	data.Stun = moveData.Stun or 0.18

	data.KnockbackPreset = nil
	data.Knockback = 0
	data.UpwardKnockback = 0
	data.KnockbackDuration = 0
	data.KnockbackMaxForce = 0

	data.Guardbreak = false
	data.PlayMoveHitVFX = false

	data.CanBeBlocked = true
	data.Blockable = true
	data.Unblockable = false
	data.CanBeCountered = true
	data.HitCancelsTarget = true
	data.CancelableByHit = true

	return data
end

local function makeBeamHitboxData(moveData)
	return {
		Radius = moveData.BeamRadius or 6.25,
		Offset = CFrame.new(),

		Damage = moveData.BeamDamage or 15,
		Stun = moveData.BeamStun or 0.35,

		Blockable = false,
		CanBeBlocked = false,
		Unblockable = true,
		Guardbreak = false,

		CanBeCountered = false,
		HitCancelsTarget = true,
		CancelableByHit = false,

		HasIFrames = false,
		HasArmor = false,

		Knockback = 0,
		UpwardKnockback = 0,
		KnockbackDuration = 0,
		KnockbackMaxForce = 0,
	}
end

local function makeBeamHitData(moveData)
	local data = copyTable(moveData)

	data.AttackType = "Move"
	data.Damage = moveData.BeamDamage or 15
	data.Stun = moveData.BeamStun or 0.35
	data.Radius = moveData.BeamRadius or 6.25
	data.Offset = CFrame.new()

	-- Damage hit itself applies no knockback.
	-- Knockback is applied after successful hit through MovementService.
	data.KnockbackPreset = nil
	data.Knockback = 0
	data.UpwardKnockback = 0
	data.KnockbackDuration = 0
	data.KnockbackMaxForce = 0

	data.Blockable = false
	data.CanBeBlocked = false
	data.Unblockable = true
	data.Guardbreak = false

	data.CanBeCountered = false
	data.HitCancelsTarget = true
	data.CancelableByHit = false

	return data
end

local function makeBeamKnockbackData(moveData)
	local data = copyTable(moveData)

	data.KnockbackPreset = "PresetKnockback"

	data.PresetKnockbackSpeed = moveData.PresetKnockbackSpeed or moveData.Knockback or 165
	data.PresetKnockbackUpward = moveData.PresetKnockbackUpward or moveData.UpwardKnockback or 0
	data.PresetKnockbackDuration = moveData.PresetKnockbackDuration or moveData.KnockbackDuration or 0.3
	data.PresetKnockbackMaxForce = moveData.PresetKnockbackMaxForce or moveData.KnockbackMaxForce or 130000

	data.Knockback = data.PresetKnockbackSpeed
	data.UpwardKnockback = data.PresetKnockbackUpward
	data.KnockbackDuration = data.PresetKnockbackDuration
	data.KnockbackMaxForce = data.PresetKnockbackMaxForce

	return data
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

	if ctx.DefaultApplyHit then
		return ctx:DefaultApplyHit(targetCharacter, targetHumanoid, targetRoot)
	end

	return "Hit"
end

local function stopCombatMovement(ctx, root)
	if not root then
		return
	end

	if not ctx.MovementService then
		return
	end

	if ctx.MovementService.ClearCombatMovementControllers then
		ctx.MovementService:ClearCombatMovementControllers(root)
		return
	end

	if ctx.MovementService.StopCarryController then
		ctx.MovementService:StopCarryController(root)
	end

	if ctx.MovementService.StopYHoldController then
		ctx.MovementService:StopYHoldController(root)
	end
end

local function beginVictimLock(victimCharacter, victimHumanoid)
	if not victimCharacter or not victimCharacter.Parent then
		return nil
	end

	local state = {
		Stunned = victimCharacter:GetAttribute("Stunned"),
		MovementLocked = victimCharacter:GetAttribute("MovementLocked"),
		DashLocked = victimCharacter:GetAttribute("DashLocked"),
		M1Locked = victimCharacter:GetAttribute("M1Locked"),
		MoveLocked = victimCharacter:GetAttribute("MoveLocked"),
		BlockLocked = victimCharacter:GetAttribute("BlockLocked"),
		ActionLocked = victimCharacter:GetAttribute("ActionLocked"),

		WalkSpeed = victimHumanoid and victimHumanoid.WalkSpeed or nil,
		JumpPower = victimHumanoid and victimHumanoid.JumpPower or nil,
		JumpHeight = victimHumanoid and victimHumanoid.JumpHeight or nil,
		AutoRotate = victimHumanoid and victimHumanoid.AutoRotate or nil,
	}

	victimCharacter:SetAttribute("Stunned", true)
	victimCharacter:SetAttribute("MovementLocked", true)
	victimCharacter:SetAttribute("DashLocked", true)
	victimCharacter:SetAttribute("M1Locked", true)
	victimCharacter:SetAttribute("MoveLocked", true)
	victimCharacter:SetAttribute("BlockLocked", true)
	victimCharacter:SetAttribute("ActionLocked", true)

	if victimHumanoid then
		victimHumanoid.WalkSpeed = 0
		victimHumanoid.JumpPower = 0
		victimHumanoid.JumpHeight = 0
		victimHumanoid.AutoRotate = false
		victimHumanoid.Jump = false
	end

	return state
end

local function enforceVictimLock(victimCharacter, victimHumanoid, victimRoot)
	if not victimCharacter or not victimCharacter.Parent then
		return
	end

	if not victimHumanoid or victimHumanoid.Health <= 0 then
		return
	end

	if not victimRoot or not victimRoot.Parent then
		return
	end

	victimCharacter:SetAttribute("Stunned", true)
	victimCharacter:SetAttribute("MovementLocked", true)
	victimCharacter:SetAttribute("DashLocked", true)
	victimCharacter:SetAttribute("M1Locked", true)
	victimCharacter:SetAttribute("MoveLocked", true)
	victimCharacter:SetAttribute("BlockLocked", true)
	victimCharacter:SetAttribute("ActionLocked", true)

	victimHumanoid.WalkSpeed = 0
	victimHumanoid.JumpPower = 0
	victimHumanoid.JumpHeight = 0
	victimHumanoid.AutoRotate = false
	victimHumanoid.Jump = false

	victimRoot.AssemblyLinearVelocity = Vector3.zero
	victimRoot.AssemblyAngularVelocity = Vector3.zero
end

local function restoreVictimLock(victimCharacter, victimHumanoid, state)
	if not victimCharacter or not victimCharacter.Parent then
		return
	end

	if victimHumanoid and victimHumanoid.Parent then
		victimHumanoid.WalkSpeed = state and state.WalkSpeed or 16
		victimHumanoid.JumpPower = state and state.JumpPower or 50
		victimHumanoid.JumpHeight = state and state.JumpHeight or 7.2
		victimHumanoid.AutoRotate = state and state.AutoRotate ~= false
	end

	if state then
		victimCharacter:SetAttribute("Stunned", state.Stunned)
		victimCharacter:SetAttribute("MovementLocked", state.MovementLocked)
		victimCharacter:SetAttribute("DashLocked", state.DashLocked)
		victimCharacter:SetAttribute("M1Locked", state.M1Locked)
		victimCharacter:SetAttribute("MoveLocked", state.MoveLocked)
		victimCharacter:SetAttribute("BlockLocked", state.BlockLocked)
		victimCharacter:SetAttribute("ActionLocked", state.ActionLocked)
	else
		victimCharacter:SetAttribute("Stunned", false)
		victimCharacter:SetAttribute("MovementLocked", false)
		victimCharacter:SetAttribute("DashLocked", false)
		victimCharacter:SetAttribute("M1Locked", false)
		victimCharacter:SetAttribute("MoveLocked", false)
		victimCharacter:SetAttribute("BlockLocked", false)
		victimCharacter:SetAttribute("ActionLocked", false)
	end
end

local function createHoldAlign(victimRoot, holdPosition, moveData)
	local attachment = Instance.new("Attachment")
	attachment.Name = "YoureBlueNowHoldAttachment"
	attachment.Parent = victimRoot

	local alignPosition = Instance.new("AlignPosition")
	alignPosition.Name = "YoureBlueNowHoldAlign"
	alignPosition.Attachment0 = attachment
	alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
	alignPosition.Position = holdPosition
	alignPosition.RigidityEnabled = false
	alignPosition.ReactionForceEnabled = false
	alignPosition.ApplyAtCenterOfMass = true
	alignPosition.Responsiveness = moveData.HoldResponsiveness or 45
	alignPosition.MaxForce = moveData.HoldMaxForce or 140000
	alignPosition.MaxVelocity = moveData.HoldMaxVelocity or 85
	alignPosition.Parent = victimRoot

	Debris:AddItem(alignPosition, (moveData.HoldTime or 0.85) + 1)
	Debris:AddItem(attachment, (moveData.HoldTime or 0.85) + 1)

	return alignPosition, attachment
end

local function cleanupHold(alignPosition, attachment)
	if alignPosition and alignPosition.Parent then
		alignPosition:Destroy()
	end

	if attachment and attachment.Parent then
		attachment:Destroy()
	end
end

local function applyBeamKnockback(ctx, attackerRoot, targetRoot, moveData)
	if not targetRoot or not targetRoot.Parent then
		return
	end

	stopCombatMovement(ctx, targetRoot)

	targetRoot.AssemblyLinearVelocity = Vector3.zero
	targetRoot.AssemblyAngularVelocity = Vector3.zero

	if ctx.MovementService and ctx.MovementService.ApplyPresetKnockback then
		ctx.MovementService:ApplyPresetKnockback(
			attackerRoot,
			targetRoot,
			makeBeamKnockbackData(moveData),
			"YoureBlueNowBeam"
		)
		return
	end

	-- Fallback only if MovementService does not have ApplyPresetKnockback.
	local direction = getRootDirection(attackerRoot)
	targetRoot.AssemblyLinearVelocity = direction * (moveData.PresetKnockbackSpeed or 165)
end

local function fireBeam(ctx, blaster, startPosition, direction)
	local moveData = ctx.MoveData
	local beamRange = moveData.BeamRange or 34
	local beamStep = moveData.BeamStep or 5
	local beamDuration = moveData.BeamDuration or 0.18
	local beamTickRate = moveData.BeamTickRate or 0.04

	local hitboxData = makeBeamHitboxData(moveData)
	local hitData = makeBeamHitData(moveData)
	local alreadyHit = {}

	local blasterPart = blaster and ensurePrimaryPart(blaster) or ctx.Root

	playPapyrusSFX(ctx, "BrokenBlasterFire", blasterPart, 2)
	spawnBeamVisual(ctx, startPosition, direction, beamRange, beamDuration + 0.15)

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

		if os.clock() - startTime >= beamDuration then
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
			local position = startPosition + (direction * distance)
			local cframe = lookAtFlat(position, direction)

			ctx.HitboxService:PerformSphereAtCFrame(
				ctx.Character,
				cframe,
				hitboxData,
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
						hitData,
						ctx.MoveId or "YoureBlueNowBeam"
					)

					if result == "Hit" or result == "ArmoredHit" then
						applyBeamKnockback(ctx, ctx.Root, targetRoot, moveData)
						playPapyrusSFX(ctx, "BrokenBlasterHit", targetRoot, 2)
					elseif result == "Blocked" then
						playPapyrusSFX(ctx, "Block", targetRoot, 2)
					end

					print("[YoureBlueNow] Beam result:", result)
				end
			)

			distance += beamStep
		end
	end)

	task.delay(beamDuration + 0.2, function()
		if connection then
			connection:Disconnect()
		end

		if blaster and blaster.Parent then
			fadeAndDestroy(blaster, 0.18)
		end
	end)
end

local function doConfirmedSequence(ctx, victimCharacter, victimHumanoid, victimRoot)
	local root = ctx.Root
	local moveData = ctx.MoveData
	local direction = getRootDirection(root)

	playPapyrusSFX(ctx, "BlueSnareGrab", victimRoot, 2)

	stopCombatMovement(ctx, victimRoot)

	if victimRoot and victimRoot.Parent then
		victimRoot.AssemblyLinearVelocity = Vector3.zero
		victimRoot.AssemblyAngularVelocity = Vector3.zero
	end

	local holdPosition =
		root.Position
		+ (direction * (moveData.HoldForwardOffset or 8))
		+ Vector3.new(0, moveData.HoldHeight or 17, 0)

	local alignPosition, attachment = createHoldAlign(victimRoot, holdPosition, moveData)
	local lockState = beginVictimLock(victimCharacter, victimHumanoid)

	spawnBlueHeart(ctx, victimRoot, (moveData.HoldTime or 0.85) + 0.45)
	playPapyrusSFX(ctx, "BlueSnareHold", victimRoot, 2)

	local holdStart = os.clock()
	local holdConnection

	holdConnection = RunService.Heartbeat:Connect(function()
		if not ctx:IsActive() then
			if holdConnection then
				holdConnection:Disconnect()
			end
			cleanupHold(alignPosition, attachment)
			restoreVictimLock(victimCharacter, victimHumanoid, lockState)
			return
		end

		if not victimCharacter or not victimCharacter.Parent then
			if holdConnection then
				holdConnection:Disconnect()
			end
			cleanupHold(alignPosition, attachment)
			return
		end

		if not victimHumanoid or victimHumanoid.Health <= 0 then
			if holdConnection then
				holdConnection:Disconnect()
			end
			cleanupHold(alignPosition, attachment)
			restoreVictimLock(victimCharacter, victimHumanoid, lockState)
			return
		end

		if not victimRoot or not victimRoot.Parent then
			if holdConnection then
				holdConnection:Disconnect()
			end
			cleanupHold(alignPosition, attachment)
			restoreVictimLock(victimCharacter, victimHumanoid, lockState)
			return
		end

		if ctx.Character:GetAttribute("Stunned") or ctx.Character:GetAttribute("Guardbroken") then
			if holdConnection then
				holdConnection:Disconnect()
			end
			cleanupHold(alignPosition, attachment)
			restoreVictimLock(victimCharacter, victimHumanoid, lockState)
			ctx:FinishMove(0)
			return
		end

		enforceVictimLock(victimCharacter, victimHumanoid, victimRoot)

		if os.clock() - holdStart >= (moveData.HoldTime or 0.85) then
			if holdConnection then
				holdConnection:Disconnect()
				holdConnection = nil
			end
		end
	end)

	local blasterEndPosition =
		holdPosition
		- (direction * (moveData.BlasterSpawnDistance or 13))
		+ Vector3.new(0, moveData.BlasterHeightOffset or 3, 0)

	local blasterStartPosition =
		blasterEndPosition
		- (direction * (moveData.BlasterEnterDistance or 8))
		+ Vector3.new(0, moveData.BlasterEnterHeight or 3.5, 0)

	local blasterStartCFrame = lookAtFlat(blasterStartPosition, direction)
	local blasterEndCFrame = lookAtFlat(blasterEndPosition, direction)

	local blaster = spawnBlaster(ctx, blasterStartCFrame)

	if blaster then
		playPapyrusSFX(ctx, "BrokenBlasterSummon", ensurePrimaryPart(blaster) or root, 2)

		local cframeValue = Instance.new("CFrameValue")
		cframeValue.Value = blasterStartCFrame

		local moveConnection
		moveConnection = cframeValue:GetPropertyChangedSignal("Value"):Connect(function()
			if blaster and blaster.Parent then
				pivotObject(blaster, cframeValue.Value)
			end
		end)

		local tween = TweenService:Create(
			cframeValue,
			TweenInfo.new(moveData.BlasterEnterTime or 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Value = blasterEndCFrame }
		)

		tween:Play()

		tween.Completed:Connect(function()
			if moveConnection then
				moveConnection:Disconnect()
			end

			cframeValue:Destroy()

			if blaster and blaster.Parent then
				pivotObject(blaster, blasterEndCFrame)
			end
		end)
	end

	task.wait(moveData.BlasterEnterTime or 0.22)
	task.wait(moveData.BlasterFireDelay or 0.22)

	if not ctx:IsActive() then
		if holdConnection then
			holdConnection:Disconnect()
		end
		cleanupHold(alignPosition, attachment)
		restoreVictimLock(victimCharacter, victimHumanoid, lockState)

		if blaster then
			fadeAndDestroy(blaster, 0.18)
		end

		return
	end

	-- Release before beam so MovementService knockback can work.
	if holdConnection then
		holdConnection:Disconnect()
		holdConnection = nil
	end

	cleanupHold(alignPosition, attachment)
	restoreVictimLock(victimCharacter, victimHumanoid, lockState)

	if victimRoot and victimRoot.Parent then
		stopCombatMovement(ctx, victimRoot)
		victimRoot.AssemblyLinearVelocity = Vector3.zero
		victimRoot.AssemblyAngularVelocity = Vector3.zero
	end

	task.wait(0.03)

	local beamStartPosition = blasterEndPosition + (direction * 3.5)

	fireBeam(
		ctx,
		blaster,
		beamStartPosition,
		direction
	)

	task.wait((moveData.BeamDuration or 0.18) + 0.08)
end

function YoureBlueNow.Execute(ctx)
	print("[YoureBlueNow] Execute started")

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

	if not ctx.HitboxService or not ctx.HitboxService.PerformSphereHitbox then
		warn("[YoureBlueNow] Missing HitboxService:PerformSphereHitbox")
		ctx:FinishMove(0)
		return
	end

	task.wait(moveData.Startup or 0.22)

	if not ctx:IsActive() then
		ctx:FinishMove(0)
		return
	end

	if character:GetAttribute("Stunned") or character:GetAttribute("Guardbroken") then
		ctx:FinishMove(0)
		return
	end

	local confirmed = false
	local victimCharacter = nil
	local victimHumanoid = nil
	local victimRoot = nil

	local grabAttackData = makeGrabAttackData(moveData)

	ctx.HitboxService:PerformSphereHitbox(
		character,
		root,
		moveData,
		function(targetCharacter, targetHumanoid, targetRoot)
			if confirmed then
				return
			end

			local result = applyStandardHit(
				ctx,
				targetCharacter,
				targetHumanoid,
				targetRoot,
				grabAttackData,
				ctx.MoveId or "YoureBlueNowGrab"
			)

			print("[YoureBlueNow] Grab result:", result)

			if result == "Hit" or result == "ArmoredHit" then
				confirmed = true
				victimCharacter = targetCharacter
				victimHumanoid = targetHumanoid
				victimRoot = targetRoot
			elseif result == "Blocked" then
				playPapyrusSFX(ctx, "Block", targetRoot, 2)
			end
		end
	)

	if not confirmed or not victimCharacter or not victimHumanoid or not victimRoot then
		print("[YoureBlueNow] Whiffed")
		ctx:FinishMove(moveData.WhiffEndlag or 0.3)
		return
	end

	doConfirmedSequence(
		ctx,
		victimCharacter,
		victimHumanoid,
		victimRoot
	)

	ctx:FinishMove(moveData.Endlag or 0.2)
end

return YoureBlueNow