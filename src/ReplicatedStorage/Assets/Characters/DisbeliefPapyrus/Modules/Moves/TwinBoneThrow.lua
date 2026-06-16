-- TwinBoneThrow
-- ReplicatedStorage > Assets > Characters > DisbeliefPapyrus > Modules > Moves > TwinBoneThrow
-- Awakened Papyrus Move 3.
-- Triple Judgement-style version:
-- LeftBone shot -> RightBone shot -> final center judgment bone.
-- All shots go straight forward and use reliable line hitboxes.

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TwinBoneThrow = {
	DisplayName = "Twin Bone Throw",
	AnimationName = "TwinBoneThrow",

	Cooldown = 12,
	Duration = 1.45,
	LockTime = 1.05,
	MaxLockTime = 1.65,

	Startup = 0.16,
	Endlag = 0.22,
	WhiffEndlag = 0.2,

	-- Triple sequence timing.
	FirstShotDelay = 0,
	SecondShotDelay = 0.24,
	ThirdShotDelay = 0.24,

	-- Shot layout.
	Range = 28,
	Step = 4,
	Radius = 4.4,

	SpawnForwardOffset = 3,
	SpawnHeightOffset = 1.7,
	SpawnSideOffset = 1.65,

	-- Damage.
	Damage = 4,
	Stun = 0.28,

	FinalDamage = 7,
	FinalStun = 0.45,
	FinalRadius = 5.2,

	-- Knockback.
	KnockbackPreset = "PresetKnockback",
	PresetKnockbackSpeed = 42,
	PresetKnockbackUpward = 5,
	PresetKnockbackDuration = 0.14,
	PresetKnockbackMaxForce = 85000,

	FinalKnockbackPreset = "PresetKnockback",
	FinalPresetKnockbackSpeed = 78,
	FinalPresetKnockbackUpward = 12,
	FinalPresetKnockbackDuration = 0.22,
	FinalPresetKnockbackMaxForce = 100000,

	Blockable = true,
	CanBeBlocked = true,
	Unblockable = false,
	Guardbreak = false,

	FinalGuardbreak = false,

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

local function prepVFXObject(object)
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

	Debris:AddItem(object, fadeTime + 0.1)
end

local function getShotTemplate(ctx, preferredName)
	local preferred = getPapyrusVFX(ctx, preferredName)

	if preferred then
		return preferred
	end

	local spikeBone = getPapyrusVFX(ctx, "SpikeBone")

	if spikeBone then
		return spikeBone
	end

	warn("[TwinBoneThrow] Missing VFX. Need DisbeliefPapyrus > VFX > " .. preferredName .. " or SpikeBone")
	return nil
end

local function spawnShotVFX(ctx, preferredName, cframe, lifetime)
	local template = getShotTemplate(ctx, preferredName)

	if not template then
		return nil
	end

	local object = template:Clone()
	object.Name = "TwinBoneThrow_" .. preferredName

	if object:IsA("Model") and not ensurePrimaryPart(object) then
		warn("[TwinBoneThrow] VFX has no BasePart or PrimaryPart:", preferredName)
		object:Destroy()
		return nil
	end

	prepVFXObject(object)

	object.Parent = workspace
	pivotObject(object, cframe)

	task.delay(lifetime or 0.22, function()
		fadeAndDestroy(object, 0.12)
	end)

	Debris:AddItem(object, (lifetime or 0.22) + 0.35)

	return object
end

local function makeHitboxData(moveData, isFinal)
	return {
		Radius = isFinal and (moveData.FinalRadius or 5.2) or (moveData.Radius or 4.4),
		Offset = CFrame.new(),

		Damage = isFinal and (moveData.FinalDamage or 7) or (moveData.Damage or 4),
		Stun = isFinal and (moveData.FinalStun or 0.45) or (moveData.Stun or 0.28),

		Blockable = true,
		CanBeBlocked = true,
		Unblockable = false,
		Guardbreak = isFinal and moveData.FinalGuardbreak == true or false,

		CanBeCountered = true,
		HitCancelsTarget = false,
		CancelableByHit = true,

		HasIFrames = false,
		HasArmor = false,
	}
end

local function makeHitData(moveData, isFinal)
	local data = copyTable(moveData)

	data.AttackType = "Move"

	data.Damage = isFinal and (moveData.FinalDamage or 7) or (moveData.Damage or 4)
	data.Stun = isFinal and (moveData.FinalStun or 0.45) or (moveData.Stun or 0.28)
	data.Radius = isFinal and (moveData.FinalRadius or 5.2) or (moveData.Radius or 4.4)
	data.Offset = CFrame.new()

	data.Blockable = true
	data.CanBeBlocked = true
	data.Unblockable = false
	data.Guardbreak = isFinal and moveData.FinalGuardbreak == true or false

	data.CanBeCountered = true
	data.HitCancelsTarget = false
	data.CancelableByHit = true

	if isFinal then
		data.KnockbackPreset = moveData.FinalKnockbackPreset or "PresetKnockback"
		data.PresetKnockbackSpeed = moveData.FinalPresetKnockbackSpeed or 78
		data.PresetKnockbackUpward = moveData.FinalPresetKnockbackUpward or 12
		data.PresetKnockbackDuration = moveData.FinalPresetKnockbackDuration or 0.22
		data.PresetKnockbackMaxForce = moveData.FinalPresetKnockbackMaxForce or 100000

		data.Knockback = data.PresetKnockbackSpeed
		data.UpwardKnockback = data.PresetKnockbackUpward
		data.KnockbackDuration = data.PresetKnockbackDuration
		data.KnockbackMaxForce = data.PresetKnockbackMaxForce
	else
		data.KnockbackPreset = moveData.KnockbackPreset or "PresetKnockback"
		data.PresetKnockbackSpeed = moveData.PresetKnockbackSpeed or 42
		data.PresetKnockbackUpward = moveData.PresetKnockbackUpward or 5
		data.PresetKnockbackDuration = moveData.PresetKnockbackDuration or 0.14
		data.PresetKnockbackMaxForce = moveData.PresetKnockbackMaxForce or 85000

		data.Knockback = data.PresetKnockbackSpeed
		data.UpwardKnockback = data.PresetKnockbackUpward
		data.KnockbackDuration = data.PresetKnockbackDuration
		data.KnockbackMaxForce = data.PresetKnockbackMaxForce
	end

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

local function performJudgementShot(ctx, shotInfo)
	local character = ctx.Character
	local root = ctx.Root
	local moveData = ctx.MoveData

	local direction = getRootDirection(root)
	local right = getRightVector(direction)

	local sideOffset = shotInfo.Side * (moveData.SpawnSideOffset or 1.65)

	local startPosition =
		root.Position
		+ (direction * (moveData.SpawnForwardOffset or 3))
		+ (right * sideOffset)
		+ Vector3.new(0, moveData.SpawnHeightOffset or 1.7, 0)

	local shotCFrame = getLookCFrame(startPosition, direction)

	spawnShotVFX(ctx, shotInfo.VFXName, shotCFrame, shotInfo.IsFinal and 0.32 or 0.22)
	playPapyrusSFX(ctx, shotInfo.SFXName or "BoneThrow", root, 2)

	local hitboxData = makeHitboxData(moveData, shotInfo.IsFinal)
	local hitData = makeHitData(moveData, shotInfo.IsFinal)
	local alreadyHit = {}

	local distance = 0

	while distance <= (moveData.Range or 28) do
		local position = startPosition + (direction * distance)
		local cframe = getLookCFrame(position, direction)

		ctx.HitboxService:PerformSphereAtCFrame(
			character,
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
					(ctx.MoveId or "TwinBoneThrow") .. "_" .. tostring(shotInfo.Index)
				)

				if result == "Hit" or result == "ArmoredHit" then
					playPapyrusSFX(ctx, "BoneHit", targetRoot, 2)
				elseif result == "Blocked" then
					playPapyrusSFX(ctx, "Block", targetRoot, 2)
				elseif result == "Guardbreak" then
					playPapyrusSFX(ctx, "BlockBreak", targetRoot, 2)
				end

				print("[TwinBoneThrow] Judgement shot", shotInfo.Index, "result:", result)
			end
		)

		distance += moveData.Step or 4
	end
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

	task.wait(moveData.Startup or 0.16)

	if isMoveInterrupted(ctx) then
		ctx:FinishMove(0)
		return
	end

	local shots = {
		{
			Index = 1,
			VFXName = "LeftBone",
			Side = -1,
			IsFinal = false,
			SFXName = "BoneThrow",
			Delay = moveData.FirstShotDelay or 0,
		},
		{
			Index = 2,
			VFXName = "RightBone",
			Side = 1,
			IsFinal = false,
			SFXName = "BoneThrow",
			Delay = moveData.SecondShotDelay or 0.24,
		},
		{
			Index = 3,
			VFXName = "SpikeBone",
			Side = 0,
			IsFinal = true,
			SFXName = "BoneReturn",
			Delay = moveData.ThirdShotDelay or 0.24,
		},
	}

	for _, shotInfo in ipairs(shots) do
		if isMoveInterrupted(ctx) then
			ctx:FinishMove(0)
			return
		end

		task.wait(shotInfo.Delay or 0)

		if isMoveInterrupted(ctx) then
			ctx:FinishMove(0)
			return
		end

		performJudgementShot(ctx, shotInfo)
	end

	ctx:FinishMove(moveData.Endlag or 0.22)
end

return TwinBoneThrow