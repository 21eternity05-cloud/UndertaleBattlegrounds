-- DeterminationSlash
-- ReplicatedStorage > Assets > Characters > GlitchtaleFrisk > Modules > Moves > DeterminationSlash

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DeterminationSlash = {
	DisplayName = "Determination Slash",
	AnimationName = "DeterminationSlash",

	Cooldown = 6,
	Duration = 0.85,
	LockTime = 0.65,
	MaxLockTime = 1,

	Damage = 7,
	Stun = 0.85,

	-- Short projectile hitbox.
	Radius = 4.5,
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

	Startup = 0.18,

	SpawnForwardOffset = 4.5,
	SpawnHeightOffset = 1.2,

	-- Short range.
	ProjectileSpeed = 70,
	ProjectileLifetime = 0.38,
	HitboxTickRate = 0.035,

	FadeTime = 0.15,

	-- Tiny knockback only, so this combo-extends instead of launching away.
	KnockbackPreset = "PresetKnockback",
	PresetKnockbackSpeed = 18,
	PresetKnockbackUpward = 4,
	PresetKnockbackDuration = 0.12,
	PresetKnockbackMaxForce = 45000,

	Knockback = 18,
	UpwardKnockback = 4,
	KnockbackDuration = 0.12,
	KnockbackMaxForce = 45000,
}

local function copyTable(source)
	local copy = {}

	for key, value in pairs(source or {}) do
		copy[key] = value
	end

	return copy
end

local function getFriskVFXFolder(ctx)
	local assets = ReplicatedStorage:WaitForChild(ctx.Config.AssetsFolderName or "Assets")
	local characters = assets:WaitForChild(ctx.Config.CharactersFolderName or "Characters")
	local frisk = characters:WaitForChild("GlitchtaleFrisk")

	return frisk:WaitForChild("VFX")
end

local function getDeterminationSlashTemplate(ctx)
	local vfxFolder = getFriskVFXFolder(ctx)
	local template = vfxFolder:FindFirstChild("DeterminationSlash")

	if not template then
		warn("[DeterminationSlash] Missing VFX: GlitchtaleFrisk > VFX > DeterminationSlash")
		return nil
	end

	return template
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

local function emitParticles(object)
	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			local emitCount = descendant:GetAttribute("EmitCount")

			if typeof(emitCount) ~= "number" then
				emitCount = 1
			end

			descendant.Enabled = false
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

local function playFriskSFX(ctx, soundName, parentPart, lifetime)
	if not ctx.VFXService then return end
	if not ctx.VFXService.PlayCharacterSFXAtPart then return end
	if not parentPart or not parentPart.Parent then return end

	ctx.VFXService:PlayCharacterSFXAtPart(
		"GlitchtaleFrisk",
		soundName,
		parentPart,
		lifetime or 2
	)
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

local function getProjectileCFrame(position, direction)
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

local function makeNoKnockbackHitData(moveData)
	local hitData = copyTable(moveData)

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

local function makeManualKnockbackData(moveData)
	local knockbackData = copyTable(moveData)

	knockbackData.KnockbackPreset = "PresetKnockback"

	knockbackData.PresetKnockbackSpeed = moveData.PresetKnockbackSpeed or moveData.Knockback or 18
	knockbackData.PresetKnockbackUpward = moveData.PresetKnockbackUpward or moveData.UpwardKnockback or 4
	knockbackData.PresetKnockbackDuration = moveData.PresetKnockbackDuration or moveData.KnockbackDuration or 0.12
	knockbackData.PresetKnockbackMaxForce = moveData.PresetKnockbackMaxForce or moveData.KnockbackMaxForce or 45000

	knockbackData.Knockback = knockbackData.PresetKnockbackSpeed
	knockbackData.UpwardKnockback = knockbackData.PresetKnockbackUpward
	knockbackData.KnockbackDuration = knockbackData.PresetKnockbackDuration
	knockbackData.KnockbackMaxForce = knockbackData.PresetKnockbackMaxForce

	return knockbackData
end

local function applyTinyComboKnockback(ctx, targetRoot, moveData)
	if not targetRoot then return end
	if not ctx.MovementService then return end
	if not ctx.MovementService.ApplyPresetKnockback then return end

	ctx.MovementService:ApplyPresetKnockback(
		ctx.Root,
		targetRoot,
		makeManualKnockbackData(moveData),
		"GlitchtaleFriskDeterminationSlash"
	)
end

local function buildHitboxData(moveData)
	return {
		Radius = moveData.Radius or 4.5,
		Offset = moveData.Offset or CFrame.new(0, 0, 0),

		Damage = moveData.Damage or 7,
		Stun = moveData.Stun or 0.85,

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

local function spawnProjectileVFX(ctx, projectileCFrame)
	local template = getDeterminationSlashTemplate(ctx)

	if not template then
		return nil
	end

	local slash = template:Clone()
	slash.Name = "ActiveGlitchtaleFriskDeterminationSlash"

	if slash:IsA("Model") and not ensurePrimaryPart(slash) then
		warn("[DeterminationSlash] DeterminationSlash model has no PrimaryPart/BasePart")
		slash:Destroy()
		return nil
	end

	prepareVFXObject(slash)
	setVisibleTransparency(slash, 0)

	slash.Parent = workspace
	pivotObject(slash, projectileCFrame)

	return slash
end

function DeterminationSlash.Execute(ctx)
	print("[DeterminationSlash] Execute started")

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
		warn("[DeterminationSlash] Missing HitboxService:PerformSphereAtCFrame")
		ctx:FinishMove(0)
		return
	end

	task.wait(moveData.Startup or 0.18)

	if isMoveInterrupted(ctx) then
		ctx:FinishMove(0)
		return
	end

	local direction = getAimDirection(ctx)

	local projectilePosition =
		root.Position
		+ Vector3.new(0, moveData.SpawnHeightOffset or 1.2, 0)
		+ (direction * (moveData.SpawnForwardOffset or 4.5))

	local projectileCFrame = getProjectileCFrame(projectilePosition, direction)
	local slashVFX = spawnProjectileVFX(ctx, projectileCFrame)

	if not slashVFX then
		ctx:FinishMove(0)
		return
	end

	playFriskSFX(ctx, "DeterminationSlash", root, 2)

	local alreadyHit = {}
	local hitboxData = buildHitboxData(moveData)
	local noKnockbackHitData = makeNoKnockbackHitData(moveData)

	local projectileSpeed = moveData.ProjectileSpeed or 70
	local projectileLifetime = moveData.ProjectileLifetime or 0.38
	local hitboxTickRate = moveData.HitboxTickRate or 0.035
	local fadeTime = moveData.FadeTime or 0.15

	local startTime = os.clock()
	local lastHitboxTime = hitboxTickRate
	local finished = false

	local connection
	connection = RunService.Heartbeat:Connect(function(deltaTime)
		if finished then return end

		if not ctx:IsActive() or isMoveInterrupted(ctx) then
			finished = true

			if connection then
				connection:Disconnect()
			end

			fadeAndDestroyVFX(slashVFX, fadeTime)
			ctx:FinishMove(0)
			return
		end

		local elapsed = os.clock() - startTime

		if elapsed >= projectileLifetime then
			finished = true

			if connection then
				connection:Disconnect()
			end

			fadeAndDestroyVFX(slashVFX, fadeTime)
			ctx:FinishMove(0)
			return
		end

		projectilePosition += direction * projectileSpeed * deltaTime
		projectileCFrame = getProjectileCFrame(projectilePosition, direction)

		pivotObject(slashVFX, projectileCFrame)

		lastHitboxTime += deltaTime

		if lastHitboxTime >= hitboxTickRate then
			lastHitboxTime = 0

			ctx.HitboxService:PerformSphereAtCFrame(
				character,
				projectileCFrame,
				hitboxData,
				function(targetCharacter, targetHumanoid, targetRoot)
					if alreadyHit[targetCharacter] then
						return
					end

					alreadyHit[targetCharacter] = true

					local result

					if ctx.ApplyStandardHit then
						result = ctx:ApplyStandardHit(
							targetCharacter,
							targetHumanoid,
							targetRoot,
							noKnockbackHitData,
							ctx.MoveId or "DeterminationSlash"
						)
					else
						result = ctx:DefaultApplyHit(targetCharacter, targetHumanoid, targetRoot)
					end

					if result == "Hit" or result == "ArmoredHit" then
						applyTinyComboKnockback(ctx, targetRoot, moveData)
						playFriskSFX(ctx, "DeterminationSlashHit", targetRoot, 2)
					elseif result == "Blocked" then
						playFriskSFX(ctx, "Block", targetRoot, 2)
					elseif result == "Guardbreak" then
						playFriskSFX(ctx, "BlockBreak", targetRoot, 2)
					end

					print("[DeterminationSlash] Result:", result)

					finished = true

					if connection then
						connection:Disconnect()
					end

					fadeAndDestroyVFX(slashVFX, fadeTime)
					ctx:FinishMove(0)
				end
			)
		end
	end)

	task.delay((moveData.MaxLockTime or 1) + 0.25, function()
		if finished then
			return
		end

		finished = true

		if connection then
			connection:Disconnect()
		end

		fadeAndDestroyVFX(slashVFX, fadeTime)
		ctx:FinishMove(0)
	end)
end

return DeterminationSlash