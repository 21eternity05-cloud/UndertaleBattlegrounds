-- BoneWall
-- ReplicatedStorage > Assets > Characters > DisbeliefPapyrus > Modules > Moves > BoneWall

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoneWall = {
	DisplayName = "Bone Wall",
	AnimationName = "BoneWall",

	Cooldown = 9,
	Duration = 1.25,
	LockTime = 0.95,
	MaxLockTime = 1.35,

	Damage = 7,
	Stun = 0.65,

	-- HitboxService uses this.
	-- Low Y offset helps make it jumpable.
	Radius = 5.25,
	Offset = CFrame.new(0, -1.85, 0),

	Blockable = true,
	CanBeBlocked = true,
	Unblockable = false,

	Guardbreak = false,
	CanBeCountered = true,
	HitCancelsTarget = true,
	CancelableByHit = true,

	HasIFrames = false,
	HasArmor = false,

	Startup = 0.24,

	-- One single PapyrusBone VFX object.
	SpawnForwardOffset = 6.5,
	WallHeightOffset = -2.25,

	-- Rises first, waits, then fires.
	RiseHeight = 4.4,
	RiseTime = 0.18,
	FireDelay = 0.18,

	ProjectileSpeed = 72,
	ProjectileLifetime = 0.65,
	HitboxTickRate = 0.035,

	FadeTime = 0.18,

	-- MovementService preset knockback, like Red Slash.
	KnockbackPreset = "PresetKnockback",
	PresetKnockbackSpeed = 78,
	PresetKnockbackUpward = 18,
	PresetKnockbackDuration = 0.25,
	PresetKnockbackMaxForce = 85000,

	-- Backward compatibility.
	KnockbackSpeed = 78,
	KnockbackUpward = 18,
	KnockbackDuration = 0.25,
	KnockbackMaxForce = 85000,
}

local function getPapyrusBoneTemplate(ctx)
	local assets = ReplicatedStorage:WaitForChild(ctx.Config.AssetsFolderName or "Assets")
	local characters = assets:WaitForChild(ctx.Config.CharactersFolderName or "Characters")
	local papyrus = characters:WaitForChild("DisbeliefPapyrus")
	local vfxFolder = papyrus:WaitForChild("VFX")

	local template = vfxFolder:FindFirstChild("PapyrusBone")

	if not template then
		warn("[BoneWall] Missing VFX: Assets > Characters > DisbeliefPapyrus > VFX > PapyrusBone")
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
		end
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

local function setVisiblePartsTransparency(object, transparency)
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

local function getWallCFrame(position, direction)
	local flatDirection = Vector3.new(direction.X, 0, direction.Z)

	if flatDirection.Magnitude < 0.05 then
		flatDirection = Vector3.new(0, 0, -1)
	end

	flatDirection = flatDirection.Unit

	return CFrame.lookAt(position, position + flatDirection)
end

local function copyTable(source)
	local copy = {}

	for key, value in pairs(source or {}) do
		copy[key] = value
	end

	return copy
end

local function makeNoKnockbackHitData(moveData)
	local hitData = copyTable(moveData)

	-- Let ApplyStandardHit/DefaultApplyHit handle damage, block, counter, armor, stun.
	-- Then this move manually applies MovementService knockback after a real hit.
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

	knockbackData.PresetKnockbackSpeed = moveData.PresetKnockbackSpeed or moveData.KnockbackSpeed or 78
	knockbackData.PresetKnockbackUpward = moveData.PresetKnockbackUpward or moveData.KnockbackUpward or 18
	knockbackData.PresetKnockbackDuration = moveData.PresetKnockbackDuration or moveData.KnockbackDuration or 0.25
	knockbackData.PresetKnockbackMaxForce = moveData.PresetKnockbackMaxForce or moveData.KnockbackMaxForce or 85000

	knockbackData.Knockback = knockbackData.PresetKnockbackSpeed
	knockbackData.UpwardKnockback = knockbackData.PresetKnockbackUpward
	knockbackData.KnockbackDuration = knockbackData.PresetKnockbackDuration
	knockbackData.KnockbackMaxForce = knockbackData.PresetKnockbackMaxForce

	return knockbackData
end

local function applyBoneWallKnockback(ctx, targetRoot, moveData)
	if not targetRoot then return end
	if not ctx.MovementService then return end
	if not ctx.MovementService.ApplyPresetKnockback then return end

	ctx.MovementService:ApplyPresetKnockback(
		ctx.Root,
		targetRoot,
		makeManualKnockbackData(moveData),
		"BoneWallPreset"
	)
end

local function buildHitboxData(moveData)
	return {
		Radius = moveData.Radius or 5.25,
		Offset = moveData.Offset or CFrame.new(0, -1.85, 0),

		Damage = moveData.Damage or 7,
		Stun = moveData.Stun or 0.65,

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

local function spawnBoneWallVFX(ctx, startWallCFrame)
	local moveData = ctx.MoveData
	local root = ctx.Root

	local template = getPapyrusBoneTemplate(ctx)
	if not template then
		return nil
	end

	local wall = template:Clone()
	wall.Name = "ActiveBoneWall"

	if wall:IsA("Model") and not ensurePrimaryPart(wall) then
		warn("[BoneWall] PapyrusBone model has no PrimaryPart/BasePart")
		wall:Destroy()
		return nil
	end

	prepareVFXObject(wall)
	setVisiblePartsTransparency(wall, 0)

	wall.Parent = workspace

	local finalLocalCFrame = CFrame.new(0, moveData.WallHeightOffset or -2.25, 0)
	local startLocalCFrame = finalLocalCFrame * CFrame.new(0, -(moveData.RiseHeight or 4.4), 0)

	pivotObject(wall, startWallCFrame * startLocalCFrame)

	playPapyrusSFX(ctx, "Summon", root, 2)

	Debris:AddItem(
		wall,
		(moveData.RiseTime or 0.18)
			+ (moveData.FireDelay or 0.18)
			+ (moveData.ProjectileLifetime or 0.65)
			+ (moveData.FadeTime or 0.18)
			+ 0.5
	)

	return {
		Object = wall,
		StartLocalCFrame = startLocalCFrame,
		FinalLocalCFrame = finalLocalCFrame,
	}
end

local function updateBoneWallVFX(vfxData, wallCFrame, riseAlpha)
	if not vfxData then return end

	local object = vfxData.Object
	if not object or not object.Parent then return end

	riseAlpha = math.clamp(riseAlpha, 0, 1)

	local startLocal = vfxData.StartLocalCFrame
	local finalLocal = vfxData.FinalLocalCFrame

	local currentPosition = startLocal.Position:Lerp(finalLocal.Position, riseAlpha)
	local currentLocalCFrame = CFrame.new(currentPosition) * finalLocal.Rotation

	pivotObject(object, wallCFrame * currentLocalCFrame)
	forcePrimaryPartInvisible(object)
end

function BoneWall.Execute(ctx)
	print("[BoneWall] Execute started")

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
		warn("[BoneWall] Missing HitboxService:PerformSphereAtCFrame")
		ctx:FinishMove(0)
		return
	end


	task.wait(moveData.Startup or 0.24)

	if isMoveInterrupted(ctx) then
		ctx:FinishMove(0)
		return
	end

	local fireDirection = getAimDirection(ctx)

	local spawnPosition =
		root.Position
		+ (fireDirection * (moveData.SpawnForwardOffset or 6.5))

	local wallCFrame = getWallCFrame(spawnPosition, fireDirection)
	local vfxData = spawnBoneWallVFX(ctx, wallCFrame)

	if not vfxData then
		ctx:FinishMove(0)
		return
	end

	local alreadyHit = {}
	local hitboxData = buildHitboxData(moveData)
	local noKnockbackHitData = makeNoKnockbackHitData(moveData)

	local riseTime = moveData.RiseTime or 0.18
	local fireDelay = moveData.FireDelay or 0.18
	local projectileLifetime = moveData.ProjectileLifetime or 0.65
	local projectileSpeed = moveData.ProjectileSpeed or 72
	local hitboxTickRate = moveData.HitboxTickRate or 0.035

	local startTime = os.clock()
	local fireStartTime = nil
	local lastHitboxTime = 0
	local hasPlayedFireSFX = false
	local finished = false

	local connection
	connection = RunService.Heartbeat:Connect(function(deltaTime)
		if finished then return end

		if not ctx:IsActive() or isMoveInterrupted(ctx) then
			finished = true

			if connection then
				connection:Disconnect()
			end

			fadeAndDestroyVFX(vfxData.Object, moveData.FadeTime or 0.18)
			ctx:FinishMove(0)
			return
		end

		local elapsed = os.clock() - startTime

		local riseAlpha = 1
		if riseTime > 0 then
			riseAlpha = math.clamp(elapsed / riseTime, 0, 1)
		end

		local canFire = elapsed >= riseTime + fireDelay

		if canFire and not fireStartTime then
			fireStartTime = os.clock()

			if not hasPlayedFireSFX then
				hasPlayedFireSFX = true
				playPapyrusSFX(ctx, "Ding", root, 2)
			end
		end

		if fireStartTime then
			local fireElapsed = os.clock() - fireStartTime

			if fireElapsed >= projectileLifetime then
				finished = true

				if connection then
					connection:Disconnect()
				end

				fadeAndDestroyVFX(vfxData.Object, moveData.FadeTime or 0.18)
				ctx:FinishMove(0)
				return
			end

			spawnPosition += fireDirection * projectileSpeed * deltaTime
			wallCFrame = getWallCFrame(spawnPosition, fireDirection)
		end

		updateBoneWallVFX(vfxData, wallCFrame, riseAlpha)

		-- Damage starts only after the wall fires.
		if fireStartTime then
			lastHitboxTime += deltaTime

			if lastHitboxTime >= hitboxTickRate then
				lastHitboxTime = 0

				ctx.HitboxService:PerformSphereAtCFrame(
					character,
					wallCFrame,
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
								ctx.MoveId or "BoneWall"
							)
						else
							result = ctx:DefaultApplyHit(targetCharacter, targetHumanoid, targetRoot)
						end

						if result == "Hit" or result == "ArmoredHit" then
							applyBoneWallKnockback(ctx, targetRoot, moveData)
							playPapyrusSFX(ctx, "M1", targetRoot, 2)
						elseif result == "Blocked" then
							playPapyrusSFX(ctx, "Block", targetRoot, 2)
						elseif result == "Guardbreak" then
							playPapyrusSFX(ctx, "BlockBreak", targetRoot, 2)
						end

						print("[BoneWall] Result:", result)
					end
				)
			end
		end
	end)

	task.delay((moveData.MaxLockTime or 1.35) + 0.35, function()
		if finished then
			return
		end

		finished = true

		if connection then
			connection:Disconnect()
		end

		fadeAndDestroyVFX(vfxData.Object, moveData.FadeTime or 0.18)
		ctx:FinishMove(0)
	end)
end

return BoneWall