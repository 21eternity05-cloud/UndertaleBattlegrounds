-- DisbeliefCounter
-- ReplicatedStorage > Assets > Characters > DisbeliefPapyrus > Modules > Moves > DisbeliefCounter

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DisbeliefCounter = {
	DisplayName = "Disbelief Counter",
	AnimationName = nil,

	Cooldown = 14,
	Duration = 1.75,
	LockTime = 1.75,
	MaxLockTime = 2.25,

	Damage = 9,
	Stun = 0.75,

	Radius = 10,
	Offset = CFrame.new(0, -1.4, 0),

	Blockable = true,
	CanBeBlocked = true,
	Unblockable = false,

	Guardbreak = false,
	CanBeCountered = false,
	HitCancelsTarget = true,
	CancelableByHit = false,

	HasIFrames = false,
	HasArmor = false,

	StartupTime = 0.2,
	CounterWindow = 1.15,
	WhiffEndlag = 0.55,

	AttackerTriggerStun = 0.55,

	-- One wall in front of Papyrus.
	WallDistance = 3.75,
	WallHeightOffset = -1.65,
	WallRiseHeight = 4,
	WallRiseTime = 0.18,

	FireDelay = 0.08,
	ProjectileSpeed = 92,
	ProjectileLifetime = 0.55,
	HitboxTickRate = 0.035,
	FadeTime = 0.2,

	-- Strong outward knockback using MovementService.
	KnockbackPreset = "PresetKnockback",
	PresetKnockbackSpeed = 120,
	PresetKnockbackUpward = 30,
	PresetKnockbackDuration = 0.34,
	PresetKnockbackMaxForce = 100000,

	KnockbackSpeed = 120,
	KnockbackUpward = 30,
	KnockbackDuration = 0.34,
	KnockbackMaxForce = 100000,

	CounterUltBonusDamageValue = 15,
}

local COUNTER_ANIMATION_NAMES = {
	"DisbeliefCounter",
	"PapyrusCounter",
	"Counter",
}

local function copyTable(source)
	local copy = {}

	for key, value in pairs(source or {}) do
		copy[key] = value
	end

	return copy
end

local function getOrCreateCounterAttackerValue(character)
	local value = character:FindFirstChild("CounterAttacker")

	if not value then
		value = Instance.new("ObjectValue")
		value.Name = "CounterAttacker"
		value.Parent = character
	end

	return value
end

local function clearCounterAttacker(character)
	local value = character:FindFirstChild("CounterAttacker")

	if value and value:IsA("ObjectValue") then
		value.Value = nil
	end
end

local function getStoredAttacker(character)
	local storedValue = character:FindFirstChild("CounterAttacker")

	if not storedValue or not storedValue:IsA("ObjectValue") then
		return nil
	end

	local attackerCharacter = storedValue.Value

	if attackerCharacter and attackerCharacter:IsA("Model") and attackerCharacter.Parent then
		return attackerCharacter
	end

	return nil
end

local function safeSetCounterInvincible(character, enabled)
	if not character or not character.Parent then return end
	character:SetAttribute("Countering", enabled == true)
end

local function addCounterFrameGlow(character)
	if not character or not character.Parent then
		return
	end

	local existing = character:FindFirstChild("DisbeliefCounterActiveHighlight")
	if existing then
		existing:Destroy()
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "DisbeliefCounterActiveHighlight"
	highlight.FillColor = Color3.fromRGB(255, 145, 0)
	highlight.OutlineColor = Color3.fromRGB(255, 210, 90)
	highlight.FillTransparency = 0.35
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = character

	local pulseValue = Instance.new("NumberValue")
	pulseValue.Name = "DisbeliefCounterGlowPulse"
	pulseValue.Value = 0.35
	pulseValue.Parent = highlight

	local pulseTween = TweenService:Create(
		pulseValue,
		TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Value = 0.1 }
	)

	pulseValue:GetPropertyChangedSignal("Value"):Connect(function()
		if highlight and highlight.Parent then
			highlight.FillTransparency = pulseValue.Value
		end
	end)

	pulseTween:Play()

	highlight.Destroying:Connect(function()
		if pulseTween then
			pulseTween:Cancel()
		end
	end)
end

local function removeCounterFrameGlow(character)
	if not character or not character.Parent then
		return
	end

	local existing = character:FindFirstChild("DisbeliefCounterActiveHighlight")

	if existing then
		existing:Destroy()
	end
end

local function tryCounterServiceStart(ctx, token)
	local service = ctx.CounterService

	if not service then
		return
	end

	local methods = {
		"StartCounter",
		"BeginCounter",
		"RegisterCounter",
		"SetCounter",
	}

	for _, methodName in ipairs(methods) do
		local method = service[methodName]

		if typeof(method) == "function" then
			pcall(function()
				method(service, ctx.Character, {
					Token = token,
					MoveId = ctx.MoveId or "DisbeliefCounter",
					MoveData = ctx.MoveData,
					Context = ctx,
				})
			end)

			return
		end
	end
end

local function tryCounterServiceEnd(ctx, token)
	local service = ctx.CounterService

	if not service then
		return
	end

	local methods = {
		"EndCounter",
		"StopCounter",
		"ClearCounter",
		"UnregisterCounter",
	}

	for _, methodName in ipairs(methods) do
		local method = service[methodName]

		if typeof(method) == "function" then
			pcall(function()
				method(service, ctx.Character, token)
			end)

			return
		end
	end
end

local function getPapyrusVFXFolder(ctx)
	local assets = ReplicatedStorage:WaitForChild(ctx.Config.AssetsFolderName or "Assets")
	local characters = assets:WaitForChild(ctx.Config.CharactersFolderName or "Characters")
	local papyrus = characters:WaitForChild("DisbeliefPapyrus")

	return papyrus:WaitForChild("VFX")
end

local function getBoneWallTemplate(ctx)
	local vfxFolder = getPapyrusVFXFolder(ctx)
	local template = vfxFolder:FindFirstChild("BoneWall")

	if not template then
		warn("[DisbeliefCounter] Missing VFX: DisbeliefPapyrus > VFX > BoneWall")
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

local function fadeAndDestroyObject(object, fadeTime)
	fadeTime = fadeTime or 0.2

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

local function playFirstAnimation(ctx, character, animationNames, fadeTime, speed, looped)
	local animationService = ctx.StateService and ctx.StateService.AnimationService

	if not animationService then
		return nil
	end

	for _, animationName in ipairs(animationNames) do
		local track = animationService:PlayCharacterAnimation(
			character,
			animationName,
			fadeTime or 0.05,
			1,
			speed or 1,
			true
		)

		if track then
			track.Looped = looped == true
			return track
		end
	end

	return nil
end

local function zeroVelocity(root)
	if not root or not root.Parent then return end

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

local function startActionLock(character, humanoid)
	local oldState = {
		WalkSpeed = humanoid.WalkSpeed,
		JumpPower = humanoid.JumpPower,
		JumpHeight = humanoid.JumpHeight,
		AutoRotate = humanoid.AutoRotate,
		JumpEnabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping),

		DashLocked = character:GetAttribute("DashLocked"),
		MovementLocked = character:GetAttribute("MovementLocked"),
		M1Locked = character:GetAttribute("M1Locked"),
		MoveLocked = character:GetAttribute("MoveLocked"),
		BlockLocked = character:GetAttribute("BlockLocked"),
		ActionLocked = character:GetAttribute("ActionLocked"),
	}

	character:SetAttribute("DashLocked", true)
	character:SetAttribute("MovementLocked", true)
	character:SetAttribute("M1Locked", true)
	character:SetAttribute("MoveLocked", true)
	character:SetAttribute("BlockLocked", true)
	character:SetAttribute("ActionLocked", true)

	-- Stops walking without anchoring. AutoRotate stays true so he can turn.
	humanoid.WalkSpeed = 0
	humanoid.AutoRotate = true
	humanoid.Jump = false
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	return oldState
end

local function restoreActionLock(character, humanoid, oldState)
	if character and character.Parent and oldState then
		character:SetAttribute("DashLocked", oldState.DashLocked)
		character:SetAttribute("MovementLocked", oldState.MovementLocked)
		character:SetAttribute("M1Locked", oldState.M1Locked)
		character:SetAttribute("MoveLocked", oldState.MoveLocked)
		character:SetAttribute("BlockLocked", oldState.BlockLocked)
		character:SetAttribute("ActionLocked", oldState.ActionLocked)
	end

	if humanoid and humanoid.Parent and humanoid.Health > 0 and oldState then
		humanoid.WalkSpeed = oldState.WalkSpeed or 16
		humanoid.AutoRotate = oldState.AutoRotate ~= false
		humanoid.JumpPower = oldState.JumpPower or 50
		humanoid.JumpHeight = oldState.JumpHeight or 7.2
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, oldState.JumpEnabled ~= false)
	end
end

local function stunCounterAttacker(ctx, targetCharacter, duration)
	if not targetCharacter or not targetCharacter.Parent then return end

	duration = duration or 0.55

	if ctx.StateService and ctx.StateService.StunCharacter then
		ctx.StateService:StunCharacter(targetCharacter, duration)
	else
		local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
		local root = targetCharacter:FindFirstChild("HumanoidRootPart")

		if humanoid then
			targetCharacter:SetAttribute("Stunned", true)
			targetCharacter:SetAttribute("Blocking", false)
			targetCharacter:SetAttribute("DashLocked", true)
			targetCharacter:SetAttribute("MovementLocked", true)

			local oldWalkSpeed = humanoid.WalkSpeed
			local oldJumpPower = humanoid.JumpPower
			local oldJumpHeight = humanoid.JumpHeight

			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
			humanoid.JumpHeight = 0

			if root then
				zeroVelocity(root)
			end

			task.delay(duration, function()
				if not targetCharacter or not targetCharacter.Parent then return end
				if not humanoid or not humanoid.Parent or humanoid.Health <= 0 then return end

				targetCharacter:SetAttribute("Stunned", false)
				targetCharacter:SetAttribute("DashLocked", false)
				targetCharacter:SetAttribute("MovementLocked", false)

				humanoid.WalkSpeed = oldWalkSpeed
				humanoid.JumpPower = oldJumpPower
				humanoid.JumpHeight = oldJumpHeight
			end)
		end
	end

	local root = targetCharacter:FindFirstChild("HumanoidRootPart")
	if root then
		zeroVelocity(root)
	end
end

local function getFacingDirection(root)
	local direction = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)

	if direction.Magnitude < 0.05 then
		direction = Vector3.new(0, 0, -1)
	else
		direction = direction.Unit
	end

	return direction
end

local function getWallCFrame(position, direction)
	local flatDirection = Vector3.new(direction.X, 0, direction.Z)

	if flatDirection.Magnitude < 0.05 then
		flatDirection = Vector3.new(0, 0, -1)
	end

	flatDirection = flatDirection.Unit

	return CFrame.lookAt(position, position + flatDirection)
end

local function makeWallData(ctx)
	local root = ctx.Root
	local moveData = ctx.MoveData
	local template = getBoneWallTemplate(ctx)

	if not template then
		return nil
	end

	local direction = getFacingDirection(root)
	local basePosition = root.Position + (direction * (moveData.WallDistance or 3.75))
	local baseCFrame = getWallCFrame(basePosition, direction)

	local finalLocalCFrame = CFrame.new(0, moveData.WallHeightOffset or -1.65, 0)
	local startLocalCFrame = finalLocalCFrame * CFrame.new(0, -(moveData.WallRiseHeight or 4), 0)

	local wall = template:Clone()
	wall.Name = "ActiveDisbeliefCounterBoneWall"

	if wall:IsA("Model") and not ensurePrimaryPart(wall) then
		wall:Destroy()
		return nil
	end

	prepareVFXObject(wall)
	setVisiblePartsTransparency(wall, 0)
	wall.Parent = workspace

	pivotObject(wall, baseCFrame * startLocalCFrame)

	Debris:AddItem(
		wall,
		(moveData.CounterWindow or 1.15)
			+ (moveData.ProjectileLifetime or 0.55)
			+ (moveData.FadeTime or 0.2)
			+ 1
	)

	playPapyrusSFX(ctx, "Summon", root, 2)

	return {
		Object = wall,
		Direction = direction,
		BasePosition = basePosition,
		BaseCFrame = baseCFrame,
		StartLocalCFrame = startLocalCFrame,
		FinalLocalCFrame = finalLocalCFrame,
		FirePosition = basePosition,
	}
end

local function updateAttachedWall(ctx, wallData, riseAlpha)
	if not wallData then return end

	local root = ctx.Root
	local moveData = ctx.MoveData
	local wall = wallData.Object

	if not root or not root.Parent then return end
	if not wall or not wall.Parent then return end

	local direction = getFacingDirection(root)
	local basePosition = root.Position + (direction * (moveData.WallDistance or 3.75))
	local baseCFrame = getWallCFrame(basePosition, direction)

	wallData.Direction = direction
	wallData.BasePosition = basePosition
	wallData.BaseCFrame = baseCFrame
	wallData.FirePosition = basePosition

	riseAlpha = math.clamp(riseAlpha, 0, 1)

	local startLocal = wallData.StartLocalCFrame
	local finalLocal = wallData.FinalLocalCFrame
	local currentPosition = startLocal.Position:Lerp(finalLocal.Position, riseAlpha)
	local currentLocalCFrame = CFrame.new(currentPosition) * finalLocal.Rotation

	pivotObject(wall, baseCFrame * currentLocalCFrame)
end

local function updateWallFire(wallData, deltaTime, speed)
	local wall = wallData.Object

	if not wall or not wall.Parent then
		return
	end

	wallData.FirePosition += wallData.Direction * speed * deltaTime
	wallData.BaseCFrame = getWallCFrame(wallData.FirePosition, wallData.Direction)

	pivotObject(wall, wallData.BaseCFrame * wallData.FinalLocalCFrame)
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
	knockbackData.PresetKnockbackSpeed = moveData.PresetKnockbackSpeed or moveData.KnockbackSpeed or 120
	knockbackData.PresetKnockbackUpward = moveData.PresetKnockbackUpward or moveData.KnockbackUpward or 30
	knockbackData.PresetKnockbackDuration = moveData.PresetKnockbackDuration or moveData.KnockbackDuration or 0.34
	knockbackData.PresetKnockbackMaxForce = moveData.PresetKnockbackMaxForce or moveData.KnockbackMaxForce or 100000

	knockbackData.Knockback = knockbackData.PresetKnockbackSpeed
	knockbackData.UpwardKnockback = knockbackData.PresetKnockbackUpward
	knockbackData.KnockbackDuration = knockbackData.PresetKnockbackDuration
	knockbackData.KnockbackMaxForce = knockbackData.PresetKnockbackMaxForce

	return knockbackData
end

local function buildWallHitboxData(moveData)
	return {
		Radius = moveData.Radius or 5.75,
		Offset = moveData.Offset or CFrame.new(0, -1.4, 0),

		Damage = moveData.Damage or 9,
		Stun = moveData.Stun or 0.75,

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

local function applyWallKnockback(ctx, wallDirection, targetRoot, moveData)
	if not targetRoot or not targetRoot.Parent then
		return
	end

	if not ctx.MovementService or not ctx.MovementService.ApplyPresetKnockback then
		warn("[DisbeliefCounter] Missing MovementService:ApplyPresetKnockback")
		return
	end

	local direction = Vector3.new(wallDirection.X, 0, wallDirection.Z)

	if direction.Magnitude < 0.05 then
		direction = Vector3.new(0, 0, -1)
	else
		direction = direction.Unit
	end

	local knockbackOrigin = Instance.new("Part")
	knockbackOrigin.Name = "DisbeliefCounterKnockbackOrigin"
	knockbackOrigin.Anchored = true
	knockbackOrigin.CanCollide = false
	knockbackOrigin.CanTouch = false
	knockbackOrigin.CanQuery = false
	knockbackOrigin.Transparency = 1
	knockbackOrigin.Size = Vector3.new(1, 1, 1)
	knockbackOrigin.CFrame = getWallCFrame(targetRoot.Position - (direction * 6), direction)
	knockbackOrigin.Parent = workspace

	Debris:AddItem(knockbackOrigin, 0.25)

	ctx.MovementService:ApplyPresetKnockback(
		knockbackOrigin,
		targetRoot,
		makeManualKnockbackData(moveData),
		"DisbeliefCounterWall"
	)
end

local function awardNormalDamageUlt(ctx, targetCharacter, targetRoot, damage)
	if typeof(damage) ~= "number" or damage <= 0 then
		return
	end

	if ctx.ReportDamageEvent then
		ctx:ReportDamageEvent(targetCharacter, damage, targetRoot)
		return
	end

	if ctx.UltService and ctx.UltService.AwardDamageEvent then
		ctx.UltService:AwardDamageEvent(ctx.Character, targetCharacter, damage)
	end
end

local function awardCounterBonusUlt(ctx, targetCharacter)
	local moveData = ctx.MoveData
	local bonusValue = moveData.CounterUltBonusDamageValue or 15

	if not ctx.UltService then
		return
	end

	if ctx.UltService.AwardDamageEvent then
		ctx.UltService:AwardDamageEvent(ctx.Character, targetCharacter, bonusValue)
		return
	end

	local methods = {
		"AddUlt",
		"AddUltimate",
		"AwardUlt",
		"GiveUlt",
		"AddMeter",
	}

	for _, methodName in ipairs(methods) do
		local method = ctx.UltService[methodName]

		if typeof(method) == "function" then
			pcall(function()
				method(ctx.UltService, ctx.Character, bonusValue)
			end)

			return
		end
	end
end

local function launchWallAndHit(ctx, wallData)
	local character = ctx.Character
	local moveData = ctx.MoveData
	local hitboxData = buildWallHitboxData(moveData)
	local noKnockbackHitData = makeNoKnockbackHitData(moveData)

	local projectileSpeed = moveData.ProjectileSpeed or 92
	local projectileLifetime = moveData.ProjectileLifetime or 0.55
	local hitboxTickRate = moveData.HitboxTickRate or 0.035
	local fadeTime = moveData.FadeTime or 0.2

	-- One hit total for the launched bone wall.
	local boneAlreadyHit = false
	local hasAwardedBonusUlt = false

	local startTime = os.clock()
	local lastHitboxTime = 0
	local finished = false

	local connection
	connection = RunService.Heartbeat:Connect(function(deltaTime)
		if finished then return end

		if not ctx:IsActive() then
			finished = true

			if connection then
				connection:Disconnect()
			end

			fadeAndDestroyObject(wallData.Object, fadeTime)
			return
		end

		local elapsed = os.clock() - startTime

		if elapsed >= projectileLifetime then
			finished = true

			if connection then
				connection:Disconnect()
			end

			fadeAndDestroyObject(wallData.Object, fadeTime)
			return
		end

		updateWallFire(wallData, deltaTime, projectileSpeed)

		if boneAlreadyHit then
			return
		end

		lastHitboxTime += deltaTime

		if lastHitboxTime >= hitboxTickRate then
			lastHitboxTime = 0

			local wallHitboxCFrame = wallData.BaseCFrame * wallData.FinalLocalCFrame

			ctx.HitboxService:PerformSphereAtCFrame(
				character,
				wallHitboxCFrame,
				hitboxData,
				function(targetCharacter, targetHumanoid, targetRoot)
					if boneAlreadyHit then
						return
					end

					boneAlreadyHit = true

					local result

					if ctx.ApplyStandardHit then
						result = ctx:ApplyStandardHit(
							targetCharacter,
							targetHumanoid,
							targetRoot,
							noKnockbackHitData,
							ctx.MoveId or "DisbeliefCounter"
						)
					else
						result = ctx:DefaultApplyHit(targetCharacter, targetHumanoid, targetRoot)
					end

					if result == "Hit" or result == "ArmoredHit" then
						applyWallKnockback(ctx, wallData.Direction, targetRoot, moveData)

						local damage = moveData.Damage or 9
						awardNormalDamageUlt(ctx, targetCharacter, targetRoot, damage)

						if not hasAwardedBonusUlt then
							hasAwardedBonusUlt = true
							awardCounterBonusUlt(ctx, targetCharacter)
						end

						playPapyrusSFX(ctx, "M1", targetRoot, 2)
					elseif result == "Blocked" then
						playPapyrusSFX(ctx, "Block", targetRoot, 2)
					elseif result == "Guardbreak" then
						playPapyrusSFX(ctx, "BlockBreak", targetRoot, 2)
					end

					print("[DisbeliefCounter] Wall result:", result)
				end
			)
		end
	end)

	task.delay(projectileLifetime + fadeTime + 0.25, function()
		if finished then return end

		finished = true

		if connection then
			connection:Disconnect()
		end

		fadeAndDestroyObject(wallData.Object, fadeTime)
	end)
end

function DisbeliefCounter.Execute(ctx)
	print("[DisbeliefCounter] Execute started")

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
		warn("[DisbeliefCounter] Missing HitboxService:PerformSphereAtCFrame")
		ctx:FinishMove(0)
		return
	end

	local oldActionState = startActionLock(character, humanoid)
	local track = playFirstAnimation(ctx, character, COUNTER_ANIMATION_NAMES, 0.04, 1, true)

	playPapyrusSFX(ctx, "Summon", root, 2)

	task.wait(moveData.StartupTime or 0.2)

	if not ctx:IsActive() or not character.Parent or humanoid.Health <= 0 then
		removeCounterFrameGlow(character)

		if track and track.IsPlaying then
			track:Stop(0.05)
		end

		restoreActionLock(character, humanoid, oldActionState)
		ctx:FinishMove(0)
		return
	end

	if character:GetAttribute("Stunned") or character:GetAttribute("Guardbroken") then
		removeCounterFrameGlow(character)

		if track and track.IsPlaying then
			track:Stop(0.05)
		end

		restoreActionLock(character, humanoid, oldActionState)
		ctx:FinishMove(0)
		return
	end

	local wallData = makeWallData(ctx)

	if not wallData then
		removeCounterFrameGlow(character)

		if track and track.IsPlaying then
			track:Stop(0.05)
		end

		restoreActionLock(character, humanoid, oldActionState)
		ctx:FinishMove(0)
		return
	end

	local counterToken = (character:GetAttribute("CounterToken") or 0) + 1
	local counterAttacker = getOrCreateCounterAttackerValue(character)
	counterAttacker.Value = nil

	character:SetAttribute("Countering", true)
	character:SetAttribute("CounterTriggered", false)
	character:SetAttribute("CounterToken", counterToken)
	character:SetAttribute("CounterMoveId", ctx.MoveId or "DisbeliefCounter")
	character:SetAttribute("CounterAttackName", nil)

	addCounterFrameGlow(character)
	tryCounterServiceStart(ctx, counterToken)

	local finished = false
	local triggered = false
	local counterConnection = nil

	local function cleanupCounterState()
		removeCounterFrameGlow(character)

		if character and character.Parent and character:GetAttribute("CounterToken") == counterToken then
			character:SetAttribute("Countering", false)
			character:SetAttribute("CounterTriggered", false)
			character:SetAttribute("CounterMoveId", nil)
			character:SetAttribute("CounterAttackName", nil)
			clearCounterAttacker(character)
		end

		tryCounterServiceEnd(ctx, counterToken)
	end

	local function disconnect()
		if counterConnection then
			counterConnection:Disconnect()
			counterConnection = nil
		end
	end

	local function finish(delayTime)
		if finished then return end
		finished = true

		disconnect()
		cleanupCounterState()

		if track and track.IsPlaying then
			track:Stop(0.08)
		end

		task.delay(delayTime or 0, function()
			restoreActionLock(character, humanoid, oldActionState)
			ctx:FinishMove(0)
		end)
	end

	local function doCounterTrigger()
		if finished or triggered then
			return
		end

		if not ctx:IsActive() then
			finish(0)
			return
		end

		if character:GetAttribute("CounterToken") ~= counterToken then
			return
		end

		triggered = true

		local attackerCharacter = getStoredAttacker(character)

		print("[DisbeliefCounter] Counter triggered by:", attackerCharacter and attackerCharacter.Name or "unknown")

		removeCounterFrameGlow(character)

		safeSetCounterInvincible(character, false)
		character:SetAttribute("Countering", false)
		character:SetAttribute("CounterTriggered", true)

		-- Keep action lock during the launch.
		character:SetAttribute("DashLocked", true)
		character:SetAttribute("MovementLocked", true)
		character:SetAttribute("M1Locked", true)
		character:SetAttribute("MoveLocked", true)
		character:SetAttribute("BlockLocked", true)
		character:SetAttribute("ActionLocked", true)
		humanoid.WalkSpeed = 0

		playPapyrusSFX(ctx, "Ding", root, 2)

		if attackerCharacter then
			stunCounterAttacker(ctx, attackerCharacter, moveData.AttackerTriggerStun or 0.55)
			awardCounterBonusUlt(ctx, attackerCharacter)
		end

		-- Lock in current direction at trigger.
		wallData.Direction = getFacingDirection(root)
		wallData.BasePosition = root.Position + (wallData.Direction * (moveData.WallDistance or 3.75))
		wallData.FirePosition = wallData.BasePosition
		wallData.BaseCFrame = getWallCFrame(wallData.BasePosition, wallData.Direction)

		task.delay(moveData.FireDelay or 0.08, function()
			if not ctx:IsActive() then
				finish(0)
				return
			end

			launchWallAndHit(ctx, wallData)
			finish((moveData.ProjectileLifetime or 0.55) + (moveData.FadeTime or 0.2) + 0.1)
		end)
	end

	counterConnection = character:GetAttributeChangedSignal("CounterTriggered"):Connect(function()
		if character:GetAttribute("CounterTriggered") == true then
			doCounterTrigger()
		end
	end)

	local startTime = os.clock()
	local riseTime = moveData.WallRiseTime or 0.18

	while ctx:IsActive() and not finished and os.clock() - startTime < (moveData.CounterWindow or 1.15) do
		local elapsed = os.clock() - startTime
		local riseAlpha = 1

		if riseTime > 0 then
			riseAlpha = math.clamp(elapsed / riseTime, 0, 1)
		end

		updateAttachedWall(ctx, wallData, riseAlpha)

		if character:GetAttribute("CounterTriggered") == true then
			doCounterTrigger()
			break
		end

		task.wait()
	end

	if not finished and not triggered then
		print("[DisbeliefCounter] Whiffed")

		removeCounterFrameGlow(character)
		fadeAndDestroyObject(wallData.Object, moveData.FadeTime or 0.2)
		finish(moveData.WhiffEndlag or 0.55)
	end
end

return DisbeliefCounter