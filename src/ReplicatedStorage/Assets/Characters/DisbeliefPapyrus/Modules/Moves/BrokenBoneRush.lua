-- BrokenBoneRush
-- ReplicatedStorage > Assets > Characters > DisbeliefPapyrus > Modules > Moves > BrokenBoneRush

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local BrokenBoneRush = {
	DisplayName = "Broken Bone Rush",
	AnimationName = "BrokenBoneRush",

	Cooldown = 8.5,
	MaxLockTime = 0.75,

	RequiresTarget = true,
	Startup = 0.18,

	-- Stronger than Sans BoneShot / Papyrus WeakBoneShot.
	Shots = 6,
	FormationTime = 0.16,
	FormationDelay = 0.025,
	ShotInterval = 0.075,

	ProjectileSpeed = 160,
	ProjectileLifetime = 3,

	Damage = 2.75,
	Stun = 0.55,
	HitRadius = 4.8,

	CanBeBlocked = true,
	Blockable = true,
	Unblockable = false,
	Guardbreak = false,

	CanBeCountered = true,
	HitCancelsTarget = false,
	CancelableByHit = true,

	HasIFrames = false,
	HasArmor = false,

	SpawnHeight = 6.9,
	SpawnBehind = 3.25,

	BoneHeight = 6.25,
	BoneBehind = 2.15,
	BoneSpread = 8.5,

	SpawnScale = 0.18,
	FinalScale = 1.15,

	AutoAimLead = 1.15,
}

local function getCharactersFolder(ctx)
	local assets = ReplicatedStorage:WaitForChild(ctx.Config.AssetsFolderName or "Assets")
	return assets:WaitForChild(ctx.Config.CharactersFolderName or "Characters")
end

local function getSpikeBoneTemplate(ctx)
	local characters = getCharactersFolder(ctx)

	local papyrus = characters:FindFirstChild("DisbeliefPapyrus")
	local papyrusVFX = papyrus and papyrus:FindFirstChild("VFX")

	if papyrusVFX then
		local spikeBone = papyrusVFX:FindFirstChild("SpikeBone")

		if spikeBone then
			return spikeBone
		end

		local fallbackPapyrusBone =
			papyrusVFX:FindFirstChild("PapyrusBones")
			or papyrusVFX:FindFirstChild("Bone")
			or papyrusVFX:FindFirstChild("M1Bone")

		if fallbackPapyrusBone then
			warn("[BrokenBoneRush] Missing SpikeBone. Using Papyrus fallback bone:", fallbackPapyrusBone.Name)
			return fallbackPapyrusBone
		end
	end

	local sans = characters:WaitForChild("Sans")
	local sansVFX = sans:WaitForChild("VFX")

	warn("[BrokenBoneRush] Missing DisbeliefPapyrus VFX > SpikeBone. Falling back to Sans M1Bone.")
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

local function setProjectileSpawnProperties(projectile)
	if projectile:IsA("BasePart") then
		projectile.Anchored = true
		projectile.CanCollide = false
		projectile.CanTouch = false
		projectile.CanQuery = false
		projectile.Massless = true
	end

	for _, descendant in ipairs(projectile:GetDescendants()) do
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
		elseif descendant:IsA("ParticleEmitter") then
			local emitCount = descendant:GetAttribute("EmitCount")

			if typeof(emitCount) ~= "number" then
				emitCount = 1
			end

			descendant:Emit(emitCount)
		end
	end

	forcePrimaryInvisible(projectile)
end

local function weldModelToPrimary(model)
	local primary = ensurePrimaryPart(model)

	if not primary then
		return
	end

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
			TweenInfo.new(data.FormationTime or 0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{
				Size = originalSize * (data.FinalScale or 1.15),
				Transparency = originalTransparency,
			}
		):Play()
	end

	local cframeTween = TweenService:Create(
		cframeValue,
		TweenInfo.new(data.FormationTime or 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
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

local function playPapyrusSFX(ctx, soundName, parentPart, lifetime)
	if not ctx.VFXService then
		return
	end

	if not ctx.VFXService.PlayCharacterSFXAtPart then
		return
	end

	if not parentPart or not parentPart.Parent then
		return
	end

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

local function getSpawnCFrame(root, data)
	local position = (
		root.CFrame
		* CFrame.new(0, data.SpawnHeight or 6.9, data.SpawnBehind or 3.25)
	).Position

	local aimPosition = root.Position + root.CFrame.LookVector * 8 + Vector3.new(0, 2, 0)

	return makeLookCFrame(position, aimPosition)
end

local function getFormationCFrame(root, index, total, data)
	local middle = (total + 1) / 2
	local offsetIndex = index - middle
	local sideOffset = offsetIndex * ((data.BoneSpread or 8.5) / math.max(total - 1, 1))
	local archHeight = (data.BoneHeight or 6.25) + math.abs(offsetIndex) * 0.75

	local position = (
		root.CFrame
		* CFrame.new(sideOffset, archHeight, data.BoneBehind or 2.15)
	).Position

	local aimPosition = root.Position + root.CFrame.LookVector * 13 + Vector3.new(0, 2, 0)

	return makeLookCFrame(position, aimPosition)
end

local function fadeOutProjectile(ctx, projectile)
	if not projectile or not projectile.Parent then
		return
	end

	if ctx.ProjectileService and ctx.ProjectileService.FadeOutProjectile then
		ctx.ProjectileService:FadeOutProjectile(projectile, 0.18)
		return
	end

	for _, part in ipairs(getVisualParts(projectile)) do
		TweenService:Create(
			part,
			TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Transparency = 1,
			}
		):Play()
	end

	Debris:AddItem(projectile, 0.22)
end

function BrokenBoneRush.Execute(ctx)
	local data = ctx.MoveData
	local root = ctx.Root

	if not ctx.ProjectileService then
		warn("[BrokenBoneRush] Missing ProjectileService in move context")
		ctx:FinishMove(0)
		return
	end

	local targetCharacter, targetHumanoid, targetRoot = ctx:GetValidTarget()

	if not targetCharacter or not targetHumanoid or not targetRoot then
		ctx:FinishMove(0)
		return
	end

	task.wait(data.Startup or 0.18)

	if isMoveInterrupted(ctx) then
		ctx:FinishMove(0)
		return
	end

	local boneTemplate = getSpikeBoneTemplate(ctx)
	local bones = {}
	local totalShots = data.Shots or 6
	local spawnCFrame = getSpawnCFrame(root, data)

	for i = 1, totalShots do
		if isMoveInterrupted(ctx) then
			for _, boneData in ipairs(bones) do
				fadeOutProjectile(ctx, boneData.Bone)
			end

			ctx:FinishMove(0)
			return
		end

		local bone = boneTemplate:Clone()
		bone.Name = "BrokenBoneRushSpikeBone"

		if bone:IsA("Model") then
			if not ensurePrimaryPart(bone) then
				warn("[BrokenBoneRush] SpikeBone model has no BasePart/PrimaryPart")
				bone:Destroy()
				continue
			end

			weldModelToPrimary(bone)
		end

		setProjectileSpawnProperties(bone)
		storeOriginalVisualData(bone)
		setVisualScale(bone, data.SpawnScale or 0.18)
		setVisualTransparency(bone, 1)

		bone.Parent = workspace
		pivotObject(bone, spawnCFrame)
		forcePrimaryInvisible(bone)

		local part = getProjectilePart(bone)

		if part then
			playPapyrusSFX(ctx, "Summon", part, 2)
		end

		local formationCFrame = getFormationCFrame(root, i, totalShots, data)

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

	task.wait((data.FormationTime or 0.16) + (totalShots * (data.FormationDelay or 0.025)))

	if isMoveInterrupted(ctx) then
		for _, boneData in ipairs(bones) do
			fadeOutProjectile(ctx, boneData.Bone)
		end

		ctx:FinishMove(0)
		return
	end

	for _, boneData in ipairs(bones) do
		if isMoveInterrupted(ctx) then
			fadeOutProjectile(ctx, boneData.Bone)
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
			ctx.ProjectileService:LaunchProjectile({
				OwnerCharacter = ctx.Character,
				Projectile = bone,
				TargetRoot = currentTargetRoot,

				Speed = data.ProjectileSpeed or 185,
				Lifetime = data.ProjectileLifetime or 3,
				HitRadius = data.HitRadius or 4.8,
				AutoAimLead = data.AutoAimLead or 1.15,

				AttackData = data,
				AttackName = ctx.MoveId or "BrokenBoneRush",

				CanHitWorld = true,
				DestroyOnWorldHit = true,
				DestroyOnCharacterHit = true,
				DestroyOnExpire = true,
				FadeLifetime = 0.18,

				HitSoundCharacter = "DisbeliefPapyrus",
				HitSoundName = "M1",

				OnLaunch = function(projectile)
					local projectilePart = getProjectilePart(projectile)

					if projectilePart then
						playPapyrusSFX(ctx, "Ding", projectilePart, 2)
					end
				end,

				OnHit = function(targetCharacter2, targetHumanoid2, targetRoot2, result)
					print("[BrokenBoneRush] Projectile result:", result)

					if targetRoot2 then
						if result == "Hit" or result == "ArmoredHit" then
							playPapyrusSFX(ctx, "M1", targetRoot2, 2)
						elseif result == "Blocked" then
							playPapyrusSFX(ctx, "Block", targetRoot2, 2)
						elseif result == "Guardbreak" then
							playPapyrusSFX(ctx, "BlockBreak", targetRoot2, 2)
						end
					end
				end,

				OnWorldHit = function()
					print("[BrokenBoneRush] Projectile hit world")
				end,

				OnExpire = function()
					print("[BrokenBoneRush] Projectile expired")
				end,
			})
		else
			fadeOutProjectile(ctx, bone)
		end

		task.wait(data.ShotInterval or 0.075)
	end

	ctx:FinishMove(0)
end

return BrokenBoneRush