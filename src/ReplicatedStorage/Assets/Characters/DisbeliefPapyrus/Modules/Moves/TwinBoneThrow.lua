-- TwinBoneThrow
-- Safe working version.
-- Awakened Papyrus Move 3.
-- Throws two bone spear projectiles forward.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TwinBoneThrow = {
	DisplayName = "Twin Bone Throw",
	AnimationName = "TwinBoneThrow",

	Cooldown = 12,
	Duration = 1.1,
	LockTime = 0.75,
	MaxLockTime = 1.4,

	Startup = 0.18,
	Endlag = 0.2,
	WhiffEndlag = 0.2,

	ProjectileSpeed = 165,
	ProjectileLifetime = 1.1,
	ProjectileFadeTime = 0.12,

	ThrowDelayBetweenBones = 0.08,

	SpawnForwardOffset = 3,
	SpawnHeightOffset = 1.7,
	SpawnSideOffset = 1.7,

	Damage = 5,
	Stun = 0.35,
	Radius = 4,
	Offset = CFrame.new(),

	KnockbackPreset = "PresetKnockback",
	PresetKnockbackSpeed = 48,
	PresetKnockbackUpward = 5,
	PresetKnockbackDuration = 0.16,
	PresetKnockbackMaxForce = 85000,

	Knockback = 48,
	UpwardKnockback = 5,
	KnockbackDuration = 0.16,
	KnockbackMaxForce = 85000,

	Blockable = true,
	CanBeBlocked = true,
	Unblockable = false,
	Guardbreak = false,

	CanBeCountered = true,
	HitCancelsTarget = false,
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

local function getPapyrusVFX(ctx, vfxName)
	local vfxFolder = getPapyrusVFXFolder(ctx)

	if not vfxFolder then
		return nil
	end

	return vfxFolder:FindFirstChild(vfxName)
end

local function playPapyrusSFX(ctx, soundName, part, lifetime)
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

local function getRightVector(direction)
	local flatDirection = getFlatDirection(direction)
	local right = flatDirection:Cross(Vector3.yAxis)

	if right.Magnitude < 0.05 then
		return Vector3.xAxis
	end

	return right.Unit
end

local function getLookCFrame(position, direction)
	if not direction or direction.Magnitude < 0.05 then
		direction = Vector3.new(0, 0, -1)
	end

	return CFrame.lookAt(position, position + direction.Unit)
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
	end

	return nil
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

local function prepProjectileVFX(object)
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
			descendant.Enabled = true

			local emitCount = descendant:GetAttribute("EmitCount")
			if typeof(emitCount) == "number" then
				descendant:Emit(emitCount)
			end
		elseif descendant:IsA("Trail") then
			descendant.Enabled = true
		elseif descendant:IsA("Beam") then
			descendant.Enabled = true
		end
	end
end

local function fadeAndDestroy(object, fadeTime)
	fadeTime = fadeTime or 0.12

	if not object or not object.Parent then
		return
	end

	for _, part in ipairs(getAllParts(object)) do
		if part.Name ~= "PrimaryPart" then
			TweenService:Create(
				part,
				TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					Transparency = 1,
				}
			):Play()
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

	Debris:AddItem(object, fadeTime + 0.08)
end

local function makeHitData(moveData)
	local hitData = copyTable(moveData)

	hitData.AttackType = "Move"
	hitData.Damage = moveData.Damage or 5
	hitData.Stun = moveData.Stun or 0.35
	hitData.Radius = moveData.Radius or 4
	hitData.Offset = CFrame.new()

	hitData.Blockable = true
	hitData.CanBeBlocked = true
	hitData.Unblockable = false
	hitData.Guardbreak = false

	hitData.CanBeCountered = true
	hitData.HitCancelsTarget = false
	hitData.CancelableByHit = true

	hitData.KnockbackPreset = moveData.KnockbackPreset
	hitData.PresetKnockbackSpeed = moveData.PresetKnockbackSpeed
	hitData.PresetKnockbackUpward = moveData.PresetKnockbackUpward
	hitData.PresetKnockbackDuration = moveData.PresetKnockbackDuration
	hitData.PresetKnockbackMaxForce = moveData.PresetKnockbackMaxForce

	hitData.Knockback = moveData.Knockback or 48
	hitData.UpwardKnockback = moveData.UpwardKnockback or 5
	hitData.KnockbackDuration = moveData.KnockbackDuration or 0.16
	hitData.KnockbackMaxForce = moveData.KnockbackMaxForce or 85000

	return hitData
end

local function makeHitboxData(moveData)
	return {
		Radius = moveData.Radius or 4,
		Offset = CFrame.new(),

		Damage = moveData.Damage or 5,
		Stun = moveData.Stun or 0.35,

		Blockable = true,
		CanBeBlocked = true,
		Unblockable = false,
		Guardbreak = false,

		CanBeCountered = true,
		HitCancelsTarget = false,
		CancelableByHit = true,

		HasIFrames = false,
		HasArmor = false,

		KnockbackPreset = moveData.KnockbackPreset,
		PresetKnockbackSpeed = moveData.PresetKnockbackSpeed,
		PresetKnockbackUpward = moveData.PresetKnockbackUpward,
		PresetKnockbackDuration = moveData.PresetKnockbackDuration,
		PresetKnockbackMaxForce = moveData.PresetKnockbackMaxForce,

		Knockback = moveData.Knockback or 48,
		UpwardKnockback = moveData.UpwardKnockback or 5,
		KnockbackDuration = moveData.KnockbackDuration or 0.16,
		KnockbackMaxForce = moveData.KnockbackMaxForce or 85000,
	}
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

local function isMoveInterrupted(ctx)
	local character = ctx.Character

	if not ctx:IsActive() then
		return true
	end

	if not character or not character.Parent then
		return true
	end

	if character:GetAttribute("Stunned") == true then
		return true
	end

	if character:GetAttribute("Guardbroken") == true then
		return true
	end

	return false
end

local function getProjectileTemplate(ctx, preferredName)
	local preferred = getPapyrusVFX(ctx, preferredName)

	if preferred then
		return preferred
	end

	local spikeBone = getPapyrusVFX(ctx, "SpikeBone")

	if spikeBone then
		return spikeBone
	end

	warn("[TwinBoneThrow] Missing VFX. Need DisbeliefPapyrus > VFX > SpikeBone or " .. preferredName)
	return nil
end

local function spawnThrownBone(ctx, preferredName, cframe)
	local template = getProjectileTemplate(ctx, preferredName)

	if not template then
		return nil
	end

	local projectile = template:Clone()
	projectile.Name = "TwinBoneThrow_" .. preferredName

	if projectile:IsA("Model") and not ensurePrimaryPart(projectile) then
		warn("[TwinBoneThrow] Projectile has no BasePart or PrimaryPart:", preferredName)
		projectile:Destroy()
		return nil
	end

	prepProjectileVFX(projectile)

	projectile.Parent = workspace
	pivotObject(projectile, cframe)

	return projectile
end

local function launchBone(ctx, boneName, spawnPosition, direction, projectileIndex)
	local moveData = ctx.MoveData
	local hitboxData = makeHitboxData(moveData)
	local hitData = makeHitData(moveData)

	if not direction or direction.Magnitude < 0.05 then
		direction = getRootDirection(ctx.Root)
	end

	direction = direction.Unit

	local projectile = spawnThrownBone(
		ctx,
		boneName,
		getLookCFrame(spawnPosition, direction)
	)

	if not projectile then
		return
	end

	local alive = true
	local hitSomething = false
	local position = spawnPosition
	local startTime = os.clock()
	local speed = moveData.ProjectileSpeed or 165
	local lifetime = moveData.ProjectileLifetime or 1.1

	local connection
	connection = RunService.Heartbeat:Connect(function(deltaTime)
		if not alive then
			if connection then
				connection:Disconnect()
			end
			return
		end

		if not ctx:IsActive() then
			alive = false
			fadeAndDestroy(projectile, moveData.ProjectileFadeTime or 0.12)

			if connection then
				connection:Disconnect()
			end
			return
		end

		if os.clock() - startTime >= lifetime then
			alive = false
			fadeAndDestroy(projectile, moveData.ProjectileFadeTime or 0.12)

			if connection then
				connection:Disconnect()
			end
			return
		end

		position += direction * speed * deltaTime

		local projectileCFrame = getLookCFrame(position, direction)
		pivotObject(projectile, projectileCFrame)

		ctx.HitboxService:PerformSphereAtCFrame(
			ctx.Character,
			projectileCFrame,
			hitboxData,
			function(targetCharacter, targetHumanoid, targetRoot)
				if hitSomething then
					return
				end

				hitSomething = true
				alive = false

				local result = applyStandardHit(
					ctx,
					targetCharacter,
					targetHumanoid,
					targetRoot,
					hitData,
					(ctx.MoveId or "TwinBoneThrow") .. "_" .. tostring(projectileIndex)
				)

				if result == "Hit" or result == "ArmoredHit" then
					playPapyrusSFX(ctx, "BoneHit", targetRoot, 2)
				elseif result == "Blocked" then
					playPapyrusSFX(ctx, "Block", targetRoot, 2)
				elseif result == "Guardbreak" then
					playPapyrusSFX(ctx, "BlockBreak", targetRoot, 2)
				end

				print("[TwinBoneThrow] Bone", projectileIndex, "result:", result)

				fadeAndDestroy(projectile, moveData.ProjectileFadeTime or 0.12)

				if connection then
					connection:Disconnect()
				end
			end
		)
	end)

	Debris:AddItem(projectile, lifetime + 0.5)
end

function TwinBoneThrow.Execute(ctx)
	print("[TwinBoneThrow] Execute started")

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
		warn("[TwinBoneThrow] Missing HitboxService:PerformSphereAtCFrame")
		ctx:FinishMove(0)
		return
	end

	task.wait(moveData.Startup or 0.18)

	if isMoveInterrupted(ctx) then
		ctx:FinishMove(0)
		return
	end

	local forward = getRootDirection(root)
	local right = getRightVector(forward)

	playPapyrusSFX(ctx, "BoneThrow", root, 2)

	local throws = {
		{
			Name = "LeftBone",
			Side = -1,
		},
		{
			Name = "RightBone",
			Side = 1,
		},
	}

	for index, info in ipairs(throws) do
		if isMoveInterrupted(ctx) then
			break
		end

		local sideOffset = info.Side * (moveData.SpawnSideOffset or 1.7)

		local spawnPosition =
			root.Position
			+ (forward * (moveData.SpawnForwardOffset or 3))
			+ (right * sideOffset)
			+ Vector3.new(0, moveData.SpawnHeightOffset or 1.7, 0)

		-- Slight inward angle, but still mostly forward.
		local inward = -right * info.Side * 0.18
		local direction = (forward + inward).Unit

		launchBone(ctx, info.Name, spawnPosition, direction, index)

		task.wait(moveData.ThrowDelayBetweenBones or 0.08)
	end

	task.delay(0.25, function()
		playPapyrusSFX(ctx, "BoneReturn", root, 2)
	end)

	ctx:FinishMove(moveData.Endlag or 0.2)
end

return TwinBoneThrow