-- WeakBoneShot
-- ReplicatedStorage > Assets > Characters > DisbeliefPapyrus > Modules > Moves > WeakBoneShot

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local WeakBoneShot = {
	DisplayName = "Weak Bone Shot",
	AnimationName = "WeakBoneShot",

	Cooldown = 8,
	MaxLockTime = 0.45,

	RequiresTarget = true,

	Startup = 0.2,

	-- Papyrus version: only 3 bones.
	Shots = 3,

	FormationTime = 0.18,
	FormationDelay = 0.035,
	ShotInterval = 0.13,

	ProjectileSpeed = 145,
	ProjectileLifetime = 3,

	Damage = 1.5,
	Stun = 0.45,

	HitRadius = 4.2,

	CanBeBlocked = true,
	Unblockable = false,
	Guardbreak = false,
	CanBeCountered = true,
	HitCancelsTarget = false,
	CancelableByHit = true,

	HasIFrames = false,
	HasArmor = false,

	SpawnHeight = 6.75,
	SpawnBehind = 3.25,

	BoneHeight = 6,
	BoneBehind = 2.25,
	BoneSpread = 6,

	SpawnScale = 0.2,
	AutoAimLead = 1,
}

local function getBoneTemplate(ctx)
	local assets = ReplicatedStorage:WaitForChild(ctx.Config.AssetsFolderName or "Assets")
	local characters = assets:WaitForChild(ctx.Config.CharactersFolderName or "Characters")

	-- First try DisbeliefPapyrus VFX.
	local papyrus = characters:FindFirstChild("DisbeliefPapyrus")
	if papyrus then
		local papyrusVFX = papyrus:FindFirstChild("VFX")

		if papyrusVFX then
			local papyrusBones = papyrusVFX:FindFirstChild("PapyrusBones")
				or papyrusVFX:FindFirstChild("Bone")
				or papyrusVFX:FindFirstChild("M1Bone")

			if papyrusBones then
				return papyrusBones
			end
		end
	end

	-- Fallback to Sans bone so this works immediately even before Papyrus has custom VFX.
	local sans = characters:WaitForChild("Sans")
	local sansVFX = sans:WaitForChild("VFX")

	return sansVFX:WaitForChild("M1Bone")
end

local function ensurePrimaryPart(model)
	if not model:IsA("Model") then
		return nil
	end

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
		if not ensurePrimaryPart(object) then
			return
		end

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

local function playPapyrusSFX(ctx, soundName, parentPart, lifetime)
	if not ctx.VFXService then return end
	if not ctx.VFXService.PlayCharacterSFXAtPart then return end
	if not parentPart or not parentPart.Parent then return end

	local played = ctx.VFXService:PlayCharacterSFXAtPart("DisbeliefPapyrus", soundName, parentPart, lifetime or 2)

	-- Fallback to Sans sounds while Papyrus SFX are not made yet.
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

local function getSpawnCFrame(root, data)
	local position = (
		root.CFrame
		* CFrame.new(0, data.SpawnHeight or 6.75, data.SpawnBehind or 3.25)
	).Position

	local aimPosition = root.Position + root.CFrame.LookVector * 8 + Vector3.new(0, 2, 0)

	return makeLookCFrame(position, aimPosition)
end

local function getFormationCFrame(root, index, total, data)
	local middle = (total + 1) / 2
	local offsetIndex = index - middle

	local sideOffset = offsetIndex * ((data.BoneSpread or 6) / math.max(total - 1, 1))
	local archHeight = (data.BoneHeight or 6) + math.abs(offsetIndex) * 0.65

	local position = (
		root.CFrame
		* CFrame.new(sideOffset, archHeight, data.BoneBehind or 2.25)
	).Position

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
		{
			Value = endCFrame,
		}
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
	projectile:SetAttribute("IsProjectile", true)
	projectile:SetAttribute("ProjectileOwner", "WeakBoneShot")

	for _, descendant in ipairs(projectile:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			descendant:SetAttribute("IsProjectile", true)
			descendant:SetAttribute("ProjectileOwner", "WeakBoneShot")
		end
	end

	if projectile:IsA("BasePart") then
		projectile.Anchored = true
		projectile.CanCollide = false
		projectile.CanTouch = false
		projectile.CanQuery = false
		projectile.Massless = true
		projectile:SetAttribute("IsProjectile", true)
		projectile:SetAttribute("ProjectileOwner", "WeakBoneShot")
	end

	forcePrimaryInvisible(projectile)
end

local function buildProjectileIgnoreList(ctx, launchedBone, allBones)
	local ignore = {}

	if ctx.Character then
		table.insert(ignore, ctx.Character)
	end

	if allBones then
		for _, boneData in ipairs(allBones) do
			if boneData.Bone then
				table.insert(ignore, boneData.Bone)
			end
		end
	end

	if launchedBone then
		table.insert(ignore, launchedBone)
	end

	return ignore
end

function WeakBoneShot.Execute(ctx)
	local data = ctx.MoveData
	local root = ctx.Root

	if not ctx.ProjectileService then
		warn("[WeakBoneShot] Missing ProjectileService in move context")
		ctx:FinishMove(0)
		return
	end

	local targetCharacter, targetHumanoid, targetRoot = ctx:GetValidTarget()

	if not targetCharacter or not targetHumanoid or not targetRoot then
		ctx:FinishMove(0)
		return
	end

	task.wait(data.Startup or 0.2)

	if isMoveInterrupted(ctx) then
		ctx:FinishMove(0)
		return
	end

	local boneTemplate = getBoneTemplate(ctx)
	local bones = {}

	local totalShots = data.Shots or 3
	local spawnCFrame = getSpawnCFrame(root, data)

	for i = 1, totalShots do
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
		bone.Name = "WeakBoneShotProjectile"

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
			playPapyrusSFX(ctx, "Summon", part, 2)
		end

		local formationCFrame = getFormationCFrame(root, i, totalShots, data)

		task.delay((i - 1) * (data.FormationDelay or 0.035), function()
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

	task.wait((data.FormationTime or 0.18) + (totalShots * (data.FormationDelay or 0.035)))

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

				Speed = data.ProjectileSpeed or 145,
				Lifetime = data.ProjectileLifetime or 3,
				HitRadius = data.HitRadius or 4.2,
				AutoAimLead = data.AutoAimLead or 1,

				AttackData = data,
				AttackName = ctx.MoveId or "WeakBoneShot",

				CanHitWorld = true,
				DestroyOnWorldHit = true,
				DestroyOnCharacterHit = true,
				DestroyOnExpire = true,
				FadeLifetime = 0.2,

				IgnoreInstances = ignoreList,

				HitSoundCharacter = "DisbeliefPapyrus",
				HitSoundName = "M1",

				OnLaunch = function(projectile)
					local part = getProjectilePart(projectile)

					if part then
						playPapyrusSFX(ctx, "Ding", part, 2)
					end
				end,

				OnHit = function(hitInfo)
				end,

				OnWorldHit = function(hitInfo)
				end,

				OnExpire = function(projectile)
				end,
			})
		else
			ctx.ProjectileService:FadeOutProjectile(bone, 0.2)
		end

		task.wait(data.ShotInterval or 0.13)
	end

	ctx:FinishMove(0)
end

return WeakBoneShot
