-- ShortBoneWall
-- ReplicatedStorage > Assets > Characters > DisbeliefPapyrus > Modules > Moves > ShortBoneWall

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShortBoneWall = {
	DisplayName = "Short Bone Wall",
	AnimationName = "ShortBoneWall",

	Cooldown = 9,
	Duration = 1.25,
	LockTime = 0.95,
	MaxLockTime = 1.35,

	Damage = 7,
	Stun = 0.65,

	-- Box hitbox instead of sphere.
	-- X = wall width, Y = height, Z = forward length.
	-- Shorter Y makes it easier to jump over.
	-- Slightly longer Z makes it more forgiving forward/backward.
	HitboxSize = Vector3.new(13.5, 2.6, 6.75),
	HitboxOffset = CFrame.new(0, -1.8, 0),

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

	WallCount = 5,
	WallSpacing = 2.35,

	SpawnForwardOffset = 6.5,
	WallHeightOffset = -2.25,

	RiseHeight = 4.4,
	RiseTime = 0.16,

	FireDelay = 0.16,

	ProjectileSpeed = 72,
	ProjectileLifetime = 0.65,

	HitboxTickRate = 0.035,

	FadeTime = 0.18,

	KnockbackPreset = "PresetKnockback",
	PresetKnockbackSpeed = 78,
	PresetKnockbackUpward = 18,
	PresetKnockbackDuration = 0.25,
	PresetKnockbackMaxForce = 85000,

	KnockbackSpeed = 78,
	KnockbackUpward = 18,
	KnockbackDuration = 0.25,
	KnockbackMaxForce = 85000,
}

local function getBoneTemplate(ctx)
	local assets = ReplicatedStorage:WaitForChild(ctx.Config.AssetsFolderName or "Assets")
	local characters = assets:WaitForChild(ctx.Config.CharactersFolderName or "Characters")

	local papyrus = characters:FindFirstChild("DisbeliefPapyrus")
	if papyrus then
		local papyrusVFX = papyrus:FindFirstChild("VFX")

		if papyrusVFX then
			local bone =
				papyrusVFX:FindFirstChild("PapyrusBone")
				or papyrusVFX:FindFirstChild("Bone")
				or papyrusVFX:FindFirstChild("M1Bone")

			if bone then
				return bone
			end
		end
	end

	local sans = characters:FindFirstChild("Sans")
	if sans then
		local sansVFX = sans:FindFirstChild("VFX")

		if sansVFX then
			local bone = sansVFX:FindFirstChild("M1Bone")

			if bone then
				return bone
			end
		end
	end

	return nil
end

local function ensurePrimaryPart(object)
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

local function prepareBoneObject(object)
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

local function setTransparency(object, transparency)
	for _, part in ipairs(getAllParts(object)) do
		if part.Name == "PrimaryPart" then
			part.Transparency = 1
		else
			part.Transparency = transparency
		end
	end

	forcePrimaryPartInvisible(object)
end

local function fadeAndDestroyBones(bones, fadeTime)
	fadeTime = fadeTime or 0.18

	for _, boneData in ipairs(bones) do
		local bone = boneData.Bone

		if bone and bone.Parent then
			for _, part in ipairs(getAllParts(bone)) do
				if part.Name ~= "PrimaryPart" then
					TweenService:Create(
						part,
						TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{
							Transparency = 1,
						}
					):Play()
				else
					part.Transparency = 1
				end
			end

			forcePrimaryPartInvisible(bone)
			Debris:AddItem(bone, fadeTime + 0.1)
		end
	end
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

local function isGrounded(character, humanoid, root)
	if not character or not humanoid or not root then
		return false
	end

	local state = humanoid:GetState()

	if state == Enum.HumanoidStateType.Jumping
		or state == Enum.HumanoidStateType.Freefall
		or state == Enum.HumanoidStateType.FallingDown
		or state == Enum.HumanoidStateType.Flying
	then
		return false
	end

	if humanoid.FloorMaterial ~= Enum.Material.Air then
		return true
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local result = workspace:Raycast(root.Position, Vector3.new(0, -4.25, 0), params)

	return result ~= nil
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

local function getCameraAimDirection(ctx)
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

	local flat = Vector3.new(aimDirection.X, 0, aimDirection.Z)

	if flat.Magnitude < 0.05 then
		if root then
			flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		end

		if flat.Magnitude < 0.05 then
			flat = Vector3.new(0, 0, -1)
		end
	end

	return flat.Unit
end

local function getWallCFrame(position, direction)
	local flatDirection = Vector3.new(direction.X, 0, direction.Z)

	if flatDirection.Magnitude < 0.05 then
		flatDirection = Vector3.new(0, 0, -1)
	end

	flatDirection = flatDirection.Unit

	return CFrame.lookAt(position, position + flatDirection)
end

local function applyPresetKnockbackLikeRedSlash(ctx, targetRoot, moveData)
	local root = ctx.Root
	if not root or not targetRoot then return end

	local knockbackData = {}

	for key, value in pairs(moveData) do
		knockbackData[key] = value
	end

	knockbackData.KnockbackPreset = "PresetKnockback"
	knockbackData.PresetKnockbackSpeed = moveData.PresetKnockbackSpeed or moveData.KnockbackSpeed or 78
	knockbackData.PresetKnockbackUpward = moveData.PresetKnockbackUpward or moveData.KnockbackUpward or 18
	knockbackData.PresetKnockbackDuration = moveData.PresetKnockbackDuration or moveData.KnockbackDuration or 0.25
	knockbackData.PresetKnockbackMaxForce = moveData.PresetKnockbackMaxForce or moveData.KnockbackMaxForce or 85000

	knockbackData.Knockback = knockbackData.PresetKnockbackSpeed
	knockbackData.UpwardKnockback = knockbackData.PresetKnockbackUpward
	knockbackData.KnockbackDuration = knockbackData.PresetKnockbackDuration
	knockbackData.KnockbackMaxForce = knockbackData.PresetKnockbackMaxForce

	if ctx.MovementService and ctx.MovementService.ApplyPresetKnockback then
		ctx.MovementService:ApplyPresetKnockback(
			root,
			targetRoot,
			knockbackData,
			"ShortBoneWallPreset"
		)
		return
	end

	if ctx.MovementService and ctx.MovementService.ApplyLinearVelocityUntilStopped then
		local direction = targetRoot.Position - root.Position
		direction = Vector3.new(direction.X, 0, direction.Z)

		if direction.Magnitude < 0.05 then
			direction = root.CFrame.LookVector
		else
			direction = direction.Unit
		end

		ctx.MovementService:ApplyLinearVelocityUntilStopped(
			targetRoot,
			(direction * knockbackData.PresetKnockbackSpeed)
				+ Vector3.new(0, knockbackData.PresetKnockbackUpward, 0),
			knockbackData.PresetKnockbackMaxForce,
			knockbackData.PresetKnockbackDuration
		)

		return
	end

	local direction = targetRoot.Position - root.Position
	direction = Vector3.new(direction.X, 0, direction.Z)

	if direction.Magnitude < 0.05 then
		direction = root.CFrame.LookVector
	else
		direction = direction.Unit
	end

	targetRoot.AssemblyLinearVelocity =
		(direction * knockbackData.PresetKnockbackSpeed)
		+ Vector3.new(0, knockbackData.PresetKnockbackUpward, 0)
end

local function makeNoKnockbackHitData(moveData)
	local hitData = {}

	for key, value in pairs(moveData) do
		hitData[key] = value
	end

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

local function spawnRisingBoneWall(ctx, startWallCFrame)
	local root = ctx.Root
	local moveData = ctx.MoveData

	if not root then return nil end

	local boneTemplate = getBoneTemplate(ctx)

	if not boneTemplate then
		warn("[ShortBoneWall] Missing PapyrusBone/Bone/M1Bone VFX")
		return nil
	end

	local bones = {}
	local count = moveData.WallCount or 5
	local spacing = moveData.WallSpacing or 2.35
	local middle = (count + 1) / 2

	for i = 1, count do
		local offsetIndex = i - middle
		local sideOffset = offsetIndex * spacing

		local finalLocalCFrame = CFrame.new(sideOffset, moveData.WallHeightOffset or -2.25, 0)
		local startLocalCFrame = finalLocalCFrame * CFrame.new(0, -(moveData.RiseHeight or 4.4), 0)

		local bone = boneTemplate:Clone()
		bone.Name = "ShortBoneWallBone"

		if bone:IsA("Model") and not ensurePrimaryPart(bone) then
			bone:Destroy()
			continue
		end

		prepareBoneObject(bone)
		setTransparency(bone, 0)
		forcePrimaryPartInvisible(bone)

		bone.Parent = workspace

		pivotObject(bone, startWallCFrame * startLocalCFrame)

		table.insert(bones, {
			Bone = bone,
			StartLocalCFrame = startLocalCFrame,
			FinalLocalCFrame = finalLocalCFrame,
		})

		Debris:AddItem(
			bone,
			(moveData.RiseTime or 0.16)
				+ (moveData.FireDelay or 0.16)
				+ (moveData.ProjectileLifetime or 0.65)
				+ (moveData.FadeTime or 0.18)
				+ 0.5
		)
	end

	playPapyrusSFX(ctx, "Summon", root, 2)

	return bones
end

local function updateBoneWallVisuals(bones, wallCFrame, riseAlpha)
	riseAlpha = math.clamp(riseAlpha, 0, 1)

	for _, boneData in ipairs(bones) do
		local bone = boneData.Bone

		if bone and bone.Parent then
			local startLocal = boneData.StartLocalCFrame
			local finalLocal = boneData.FinalLocalCFrame

			local startPosition = startLocal.Position
			local finalPosition = finalLocal.Position
			local currentPosition = startPosition:Lerp(finalPosition, riseAlpha)

			local currentLocalCFrame = CFrame.new(currentPosition) * finalLocal.Rotation

			pivotObject(bone, wallCFrame * currentLocalCFrame)
			forcePrimaryPartInvisible(bone)
		end
	end
end

local function buildMovingHitData(moveData)
	return {
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

local function performMovingBoxHitbox(ctx, boxCFrame, boxSize, hitData, alreadyHit, onHit)
	local character = ctx.Character

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local parts = workspace:GetPartBoundsInBox(boxCFrame, boxSize, params)

	for _, part in ipairs(parts) do
		local targetCharacter = part:FindFirstAncestorOfClass("Model")

		if targetCharacter
			and targetCharacter ~= character
			and not alreadyHit[targetCharacter]
		then
			local targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
			local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")

			if targetHumanoid and targetRoot and targetHumanoid.Health > 0 then
				alreadyHit[targetCharacter] = true
				onHit(targetCharacter, targetHumanoid, targetRoot)
			end
		end
	end
end

function ShortBoneWall.Execute(ctx)
	print("[ShortBoneWall] Execute started")

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

	if not isGrounded(character, humanoid, root) then
		print("[ShortBoneWall] Cannot cast while airborne")
		ctx:FinishMove(0)
		return
	end

	task.wait(moveData.Startup or 0.24)

	if isMoveInterrupted(ctx) then
		ctx:FinishMove(0)
		return
	end

	if not isGrounded(character, humanoid, root) then
		print("[ShortBoneWall] Canceled because caster left the ground")
		ctx:FinishMove(0)
		return
	end

	local fireDirection = getCameraAimDirection(ctx)

	local spawnPosition =
		root.Position
		+ (fireDirection * (moveData.SpawnForwardOffset or 6.5))

	local wallCFrame = getWallCFrame(spawnPosition, fireDirection)
	local bones = spawnRisingBoneWall(ctx, wallCFrame)

	if not bones then
		ctx:FinishMove(0)
		return
	end

	local alreadyHit = {}
	local hitData = buildMovingHitData(moveData)
	local noKnockbackData = makeNoKnockbackHitData(hitData)

	local riseTime = moveData.RiseTime or 0.16
	local fireDelay = moveData.FireDelay or 0.16
	local projectileLifetime = moveData.ProjectileLifetime or 0.65
	local projectileSpeed = moveData.ProjectileSpeed or 72
	local hitboxTickRate = moveData.HitboxTickRate or 0.035
	local hitboxSize = moveData.HitboxSize or Vector3.new(13.5, 2.6, 6.75)
	local hitboxOffset = moveData.HitboxOffset or CFrame.new(0, -1.8, 0)

	local startTime = os.clock()
	local fireStartTime = nil
	local hasPlayedFireSFX = false
	local lastHitboxTime = 0
	local finished = false

	local connection
	connection = RunService.Heartbeat:Connect(function(deltaTime)
		if finished then return end

		if not ctx:IsActive() or isMoveInterrupted(ctx) then
			finished = true

			if connection then
				connection:Disconnect()
			end

			fadeAndDestroyBones(bones, moveData.FadeTime or 0.18)
			ctx:FinishMove(0)
			return
		end

		local elapsed = os.clock() - startTime

		local riseAlpha = 1
		if riseTime > 0 then
			riseAlpha = math.clamp(elapsed / riseTime, 0, 1)
		end

		local shouldFire = elapsed >= riseTime + fireDelay

		if shouldFire and not fireStartTime then
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

				fadeAndDestroyBones(bones, moveData.FadeTime or 0.18)
				ctx:FinishMove(0)
				return
			end

			spawnPosition += fireDirection * projectileSpeed * deltaTime
			wallCFrame = getWallCFrame(spawnPosition, fireDirection)
		end

		updateBoneWallVisuals(bones, wallCFrame, riseAlpha)

		if fireStartTime then
			lastHitboxTime += deltaTime

			if lastHitboxTime >= hitboxTickRate then
				lastHitboxTime = 0

				local currentHitboxCFrame = wallCFrame * hitboxOffset

				performMovingBoxHitbox(
					ctx,
					currentHitboxCFrame,
					hitboxSize,
					hitData,
					alreadyHit,
					function(targetCharacter, targetHumanoid, targetRoot)
						local result

						if ctx.ApplyStandardHit then
							result = ctx:ApplyStandardHit(
								targetCharacter,
								targetHumanoid,
								targetRoot,
								noKnockbackData,
								ctx.MoveId or "ShortBoneWall"
							)
						else
							result = ctx:DefaultApplyHit(targetCharacter, targetHumanoid, targetRoot)
						end

						if result == "Hit" or result == "ArmoredHit" then
							applyPresetKnockbackLikeRedSlash(ctx, targetRoot, moveData)
							playPapyrusSFX(ctx, "M1", targetRoot, 2)
						elseif result == "Blocked" then
							playPapyrusSFX(ctx, "Block", targetRoot, 2)
						elseif result == "Guardbreak" then
							playPapyrusSFX(ctx, "BlockBreak", targetRoot, 2)
						end

						print("[ShortBoneWall] Result:", result)
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

		fadeAndDestroyBones(bones, moveData.FadeTime or 0.18)
		ctx:FinishMove(0)
	end)
end

return ShortBoneWall