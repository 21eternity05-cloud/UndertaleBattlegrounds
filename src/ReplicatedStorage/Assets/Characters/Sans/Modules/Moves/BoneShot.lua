local BoneShot = {
	DisplayName = "Bone Shot",
	AnimationName = "BoneShot",

	Cooldown = 9.2,
	MaxLockTime = 0.45,

	RequiresTarget = true,

	Startup = 0.2,
	Shots = 5,

	FormationTime = 0.18,
	FormationDelay = 0.025,

	ShotInterval = 0.12,
	ProjectileSpeed = 165,
	ProjectileLifetime = 3,

	Damage = 1,
	Stun = 0.5,

	HitRadius = 4.5,

	CanBeBlocked = true,
	Unblockable = false,
	Guardbreak = false,
	CanBeCountered = true,

	HitCancelsTarget = false,
	CancelableByHit = true,

	HasIFrames = false,
	HasArmor = false,

	SpawnHeight = 7.25,
	SpawnBehind = 3.5,

	BoneHeight = 6.5,
	BoneBehind = 2.5,
	BoneSpread = 7,

	SpawnScale = 0.2,
	AutoAimLead = 1.2,

	-- Light Bone Shot polish.
	-- No FOV, no impact frames. This is a frequent Sans poke/projectile.
	HitVictimShakeMagnitude = 0.65,
	HitVictimShakeRoughness = 9,
	HitVictimShakeDuration = 0.13,

	BlockVictimShakeMagnitude = 0.35,
	BlockVictimShakeRoughness = 7,
	BlockVictimShakeDuration = 0.09,

	HitAttackerShakeMagnitude = 0.25,
	HitAttackerShakeRoughness = 6,
	HitAttackerShakeDuration = 0.07,
}

local function getBoneTemplate(ctx)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local assets = ReplicatedStorage:WaitForChild(ctx.Config.AssetsFolderName or "Assets")
	local characters = assets:WaitForChild(ctx.Config.CharactersFolderName or "Characters")
	local sans = characters:WaitForChild("Sans")
	local vfx = sans:WaitForChild("VFX")

	return vfx:WaitForChild("M1Bone")
end

local function ensurePrimaryPart(model)
	if not model:IsA("Model") then return nil end

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

local function getProjectilePart(projectile)
	if projectile:IsA("BasePart") then
		return projectile
	end

	if projectile:IsA("Model") then
		return ensurePrimaryPart(projectile)
	end

	return nil
end

local function pivotObject(object, cframe)
	if object:IsA("Model") then
		if not ensurePrimaryPart(object) then return end
		object:PivotTo(cframe)
	elseif object:IsA("BasePart") then
		object.CFrame = cframe
	end
end

local function makeLookCFrame(position, lookAtPosition)
	local direction = lookAtPosition - position

	if direction.Magnitude < 0.1 then
		direction = Vector3.new(0, 0, -1)
	end

	return CFrame.lookAt(position, position + direction.Unit)
end

local function playSansSFX(ctx, soundName, parentPart, lifetime)
	if not ctx.VFXService then return end
	if not ctx.VFXService.PlayCharacterSFXAtPart then return end
	if not parentPart or not parentPart.Parent then return end

	ctx.VFXService:PlayCharacterSFXAtPart("Sans", soundName, parentPart, lifetime or 2)
end

local function shakeCharacter(ctx, targetCharacter, magnitude, roughness, duration)
	if not targetCharacter or not targetCharacter.Parent then return end
	if not ctx.CinematicService then return end
	if not ctx.CinematicService.ShakeOnce then return end

	pcall(function()
		ctx.CinematicService:ShakeOnce(targetCharacter, magnitude, roughness, duration)
	end)
end

local function playProjectileHitPolish(ctx, data, targetCharacter, result)
	if result == "Hit" or result == "ArmoredHit" or result == "Guardbreak" then
		shakeCharacter(
			ctx,
			targetCharacter,
			data.HitVictimShakeMagnitude or BoneShot.HitVictimShakeMagnitude or 0.65,
			data.HitVictimShakeRoughness or BoneShot.HitVictimShakeRoughness or 9,
			data.HitVictimShakeDuration or BoneShot.HitVictimShakeDuration or 0.13
		)

		shakeCharacter(
			ctx,
			ctx.Character,
			data.HitAttackerShakeMagnitude or BoneShot.HitAttackerShakeMagnitude or 0.25,
			data.HitAttackerShakeRoughness or BoneShot.HitAttackerShakeRoughness or 6,
			data.HitAttackerShakeDuration or BoneShot.HitAttackerShakeDuration or 0.07
		)

		return
	end

	if result == "Blocked" then
		shakeCharacter(
			ctx,
			targetCharacter,
			data.BlockVictimShakeMagnitude or BoneShot.BlockVictimShakeMagnitude or 0.35,
			data.BlockVictimShakeRoughness or BoneShot.BlockVictimShakeRoughness or 7,
			data.BlockVictimShakeDuration or BoneShot.BlockVictimShakeDuration or 0.09
		)
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

	return character:GetAttribute("Stunned") == true or character:GetAttribute("Guardbroken") == true
end

local function getSpawnCFrame(root, data)
	local position = (root.CFrame * CFrame.new(0, data.SpawnHeight or 7.25, data.SpawnBehind or 3.5)).Position
	local aimPosition = root.Position + root.CFrame.LookVector * 8 + Vector3.new(0, 2, 0)

	return makeLookCFrame(position, aimPosition)
end

local function getFormationCFrame(root, index, total, data)
	local middle = (total + 1) / 2
	local offsetIndex = index - middle

	local sideOffset = offsetIndex * ((data.BoneSpread or 7) / math.max(total - 1, 1))
	local archHeight = (data.BoneHeight or 6.5) + math.abs(offsetIndex) * 0.8

	local position = (root.CFrame * CFrame.new(sideOffset, archHeight, data.BoneBehind or 2.5)).Position
	local aimPosition = root.Position + root.CFrame.LookVector * 12 + Vector3.new(0, 2, 0)

	return makeLookCFrame(position, aimPosition)
end

local function weldModelToPrimary(model)
	local primary = ensurePrimaryPart(model)
	if not primary then return end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= primary then
			local alreadyWelded = false

			for _, child in ipairs(descendant:GetChildren()) do
				if child:IsA("WeldConstraint") then
					alreadyWelded = true
					break
				end
			end

			if not alreadyWelded then
				local weld = Instance.new("WeldConstraint")
				weld.Name = "ProjectileVisualWeld"
				weld.Part0 = primary
				weld.Part1 = descendant
				weld.Parent = primary
			end
		end
	end
end

local function getVisualParts(projectile)
	local parts = {}

	if projectile:IsA("BasePart") then
		table.insert(parts, projectile)
		return parts
	end

	for _, descendant in ipairs(projectile:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name ~= "PrimaryPart" then
			table.insert(parts, descendant)
		end
	end

	return parts
end

local function forcePrimaryInvisible(projectile)
	if projectile:IsA("Model") then
		local primary = ensurePrimaryPart(projectile)

		if primary then
			primary.Transparency = 1
			primary.CanCollide = false
			primary.CanTouch = false
			primary.CanQuery = false
			primary.Massless = true
		end
	end
end

local function storeOriginalVisualData(projectile)
	for _, part in ipairs(getVisualParts(projectile)) do
		part:SetAttribute("OriginalSize", part.Size)
		part:SetAttribute("OriginalTransparency", part.Transparency)
	end
end

local function setVisualScale(projectile, scale)
	for _, part in ipairs(getVisualParts(projectile)) do
		local originalSize = part:GetAttribute("OriginalSize")

		if typeof(originalSize) ~= "Vector3" then
			originalSize = part.Size
		end

		part.Size = originalSize * scale
	end

	forcePrimaryInvisible(projectile)
end

local function setVisualTransparency(projectile, transparency)
	for _, part in ipairs(getVisualParts(projectile)) do
		part.Transparency = transparency
	end

	forcePrimaryInvisible(projectile)
end

local function tweenBoneIntoFormation(projectile, startCFrame, endCFrame, data)
	local TweenService = game:GetService("TweenService")

	local cframeValue = Instance.new("CFrameValue")
	cframeValue.Value = startCFrame

	local connection
	connection = cframeValue:GetPropertyChangedSignal("Value"):Connect(function()
		if projectile and projectile.Parent then
			pivotObject(projectile, cframeValue.Value)
			forcePrimaryInvisible(projectile)
		end
	end)

	for _, part in ipairs(getVisualParts(projectile)) do
		local originalSize = part:GetAttribute("OriginalSize")
		local originalTransparency = part:GetAttribute("OriginalTransparency")

		if typeof(originalSize) ~= "Vector3" then
			originalSize = part.Size
		end

		if typeof(originalTransparency) ~= "number" then
			originalTransparency = 0
		end

		TweenService:Create(
			part,
			TweenInfo.new(data.FormationTime or 0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{
				Size = originalSize,
				Transparency = originalTransparency,
			}
		):Play()
	end

	local cframeTween = TweenService:Create(
		cframeValue,
		TweenInfo.new(data.FormationTime or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Value = endCFrame }
	)

	cframeTween:Play()

	cframeTween.Completed:Connect(function()
		if connection then
			connection:Disconnect()
		end

		if projectile and projectile.Parent then
			pivotObject(projectile, endCFrame)
			forcePrimaryInvisible(projectile)
		end

		cframeValue:Destroy()
	end)
end

local function setProjectileSpawnProperties(projectile)
	if projectile:IsA("BasePart") then
		projectile.Anchored = true
		projectile.CanCollide = false
		projectile.CanTouch = false
		projectile.CanQuery = false
		projectile.Massless = true
		projectile:SetAttribute("IsProjectile", true)
		projectile:SetAttribute("ProjectileOwner", "SansBoneShot")
	end

	for _, descendant in ipairs(projectile:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			descendant:SetAttribute("IsProjectile", true)
			descendant:SetAttribute("ProjectileOwner", "SansBoneShot")
		end
	end

	if projectile:IsA("Model") then
		projectile:SetAttribute("IsProjectile", true)
		projectile:SetAttribute("ProjectileOwner", "SansBoneShot")
	end

	forcePrimaryInvisible(projectile)
end

local function buildProjectileIgnoreList(ctx, launchedBone, allBones)
	local ignore = {}

	if ctx.Character then
		table.insert(ignore, ctx.Character)
	end

	for _, boneData in ipairs(allBones) do
		local bone = boneData.Bone

		if bone and bone.Parent then
			table.insert(ignore, bone)
		end
	end

	if launchedBone and launchedBone.Parent then
		table.insert(ignore, launchedBone)
	end

	return ignore
end

function BoneShot.Execute(ctx)
	local data = ctx.MoveData
	local root = ctx.Root

	local Debris = game:GetService("Debris")

	if not ctx.ProjectileService then
		warn("[BoneShot] Missing ProjectileService in move context")
		ctx:FinishMove(0)
		return
	end

	local targetCharacter, targetHumanoid, targetRoot = ctx:GetValidTarget()
	if not targetCharacter then
		ctx:FinishMove(0)
		return
	end

	task.wait(data.Startup or 0.18)

	if isMoveInterrupted(ctx) then
		ctx:FinishMove(0)
		return
	end

	local boneTemplate = getBoneTemplate(ctx)
	local bones = {}

	local spawnCFrame = getSpawnCFrame(root, data)

	for i = 1, data.Shots or 5 do
		if isMoveInterrupted(ctx) then
			for _, boneData in ipairs(bones) do
				if boneData.Bone and boneData.Bone.Parent then
					ctx.ProjectileService:FadeOutProjectile(boneData.Bone, 0.2)
				end
			end

			ctx:FinishMove(0)
			return
		end

		local bone = boneTemplate:Clone()
		bone.Name = "SansBoneShotProjectile"
		bone:SetAttribute("IsProjectile", true)
		bone:SetAttribute("ProjectileOwner", "SansBoneShot")

		if bone:IsA("Model") then
			if not ensurePrimaryPart(bone) then
				bone:Destroy()
				continue
			end

			weldModelToPrimary(bone)
		end

		setProjectileSpawnProperties(bone)
		storeOriginalVisualData(bone)
		setVisualScale(bone, data.SpawnScale or 0.2)
		setVisualTransparency(bone, 1)

		bone.Parent = workspace
		pivotObject(bone, spawnCFrame)
		forcePrimaryInvisible(bone)

		local part = getProjectilePart(bone)
		if part then
			playSansSFX(ctx, "Summon", part, 2)
		end

		local formationCFrame = getFormationCFrame(root, i, data.Shots or 5, data)

		task.delay((i - 1) * (data.FormationDelay or 0.025), function()
			if isMoveInterrupted(ctx) then
				return
			end

			if bone and bone.Parent then
				tweenBoneIntoFormation(bone, spawnCFrame, formationCFrame, data)
			end
		end)

		table.insert(bones, {
			Bone = bone,
			FormationCFrame = formationCFrame,
		})

		Debris:AddItem(bone, 5)
	end

	task.wait((data.FormationTime or 0.18) + ((data.Shots or 5) * (data.FormationDelay or 0.025)))

	if isMoveInterrupted(ctx) then
		for _, boneData in ipairs(bones) do
			if boneData.Bone and boneData.Bone.Parent then
				ctx.ProjectileService:FadeOutProjectile(boneData.Bone, 0.2)
			end
		end

		ctx:FinishMove(0)
		return
	end

	for _, boneData in ipairs(bones) do
		if isMoveInterrupted(ctx) then
			if boneData.Bone and boneData.Bone.Parent then
				ctx.ProjectileService:FadeOutProjectile(boneData.Bone, 0.2)
			end

			ctx:FinishMove(0)
			return
		end

		local bone = boneData.Bone

		if not bone or not bone.Parent then
			continue
		end

		if boneData.FormationCFrame then
			pivotObject(bone, boneData.FormationCFrame)
			forcePrimaryInvisible(bone)
		end

		local _, _, currentTargetRoot = ctx:GetValidTarget()

		if currentTargetRoot then
			local ignoreList = buildProjectileIgnoreList(ctx, bone, bones)

			ctx.ProjectileService:LaunchProjectile({
				OwnerCharacter = ctx.Character,
				Projectile = bone,
				CollisionProfile = "BoneProjectile",

				TargetRoot = currentTargetRoot,
				Speed = data.ProjectileSpeed or 165,
				Lifetime = data.ProjectileLifetime or 3,
				HitRadius = data.HitRadius or 4.5,
				AutoAimLead = data.AutoAimLead or 0.5,

				AttackData = data,
				AttackName = ctx.MoveId or "BoneShot",

				-- Bone Shot should only world-hit the actual map.
				CanHitWorld = true,
				DestroyOnWorldHit = true,

				-- Bone Shot should only character-hit real player characters.
				DestroyOnCharacterHit = true,
				DestroyOnExpire = true,
				FadeLifetime = 0.2,

				HitSoundCharacter = "Sans",
				HitSoundName = "M1",

				IgnoreInstances = ignoreList,

				OnLaunch = function(projectile)
					local part = getProjectilePart(projectile)
					if part then
						playSansSFX(ctx, "Ding", part, 2)
					end
				end,

				OnHit = function(hitInfo)
					playProjectileHitPolish(ctx, data, hitInfo.TargetCharacter, hitInfo.Result)
				end,

				OnWorldHit = function(hitInfo)
				end,

				OnExpire = function(projectile)
				end,
			})
		else
			ctx.ProjectileService:FadeOutProjectile(bone, 0.2)
		end

		task.wait(data.ShotInterval or 0.12)
	end

	ctx:FinishMove(0)
end

return BoneShot
