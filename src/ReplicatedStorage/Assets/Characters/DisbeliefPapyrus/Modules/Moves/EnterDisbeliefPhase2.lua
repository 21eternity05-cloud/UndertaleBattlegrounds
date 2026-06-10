-- EnterDisbeliefPhase2
-- ReplicatedStorage > Assets > Characters > DisbeliefPapyrus > Modules > Moves > EnterDisbeliefPhase2

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local EnterDisbeliefPhase2 = {
	DisplayName = "Enter Disbelief",
	AnimationName = nil,

	Cooldown = 1,
	Duration = 7,
	LockTime = 7,
	MaxLockTime = 8,

	Damage = 0,
	Stun = 0,
	Radius = 0,
	Offset = CFrame.new(),

	Blockable = false,
	Guardbreak = false,

	CounterWindow = 1.45,
	WhiffEndlag = 0.35,
	StartupTime = 0.05,

	CounterAnimationName = "EnterDisbeliefPhase2Counter",
	TransformAnimationName = "EnterDisbeliefPhase2Transform",

	TransformFallbackTime = 7,
	AwakeningEndsAt = 0,

	BlackScreenMarkerName = "BlackScreen",
	WeaponChangeMarkerName = "WeaponChange",
	GasterBlasterMarkerName = "GasterBlaster",
	BlackScreenEndMarkerName = "BlackScreenEnd",

	BlasterDamage = 18,
	BlasterStun = 1.15,
	BlasterRadius = 7,
	BlasterHeight = 3,
	BlasterSideOffset = 8,
	BlasterBackwardOffset = 4,
	BlasterChargeTime = 0.65,
	BlasterLifetime = 1.8,
}

local function contextIsActive(ctx)
	if not ctx then return false end

	if ctx.IsActive and typeof(ctx.IsActive) == "function" then
		local success, result = pcall(function()
			return ctx:IsActive()
		end)

		return success and result == true
	end

	return true
end

local function finishContext(ctx)
	if ctx and ctx.FinishMove and typeof(ctx.FinishMove) == "function" then
		ctx:FinishMove()
	end
end

local function getScreenEffectRemote()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")

	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	local remote = remotes:FindFirstChild("ScreenEffectRemote")

	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "ScreenEffectRemote"
		remote.Parent = remotes
	end

	return remote
end

local function getPlayerFromCharacter(character)
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character == character then
			return player
		end
	end

	return nil
end

local function fireScreenEffect(character, effectName)
	local player = getPlayerFromCharacter(character)
	if not player then return end

	getScreenEffectRemote():FireClient(player, effectName)
end

local function zeroVelocity(root)
	if not root or not root.Parent then return end

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
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
	local value = character:FindFirstChild("CounterAttacker")

	if not value or not value:IsA("ObjectValue") then
		return nil
	end

	if value.Value and value.Value:IsA("Model") and value.Value.Parent then
		return value.Value
	end

	return nil
end

local function playPapyrusSFX(ctx, soundName, parentPart, lifetime)
	if not ctx or not ctx.VFXService then return end
	if not ctx.VFXService.PlayCharacterSFXAtPart then return end
	if not parentPart or not parentPart.Parent then return end

	local success, played = pcall(function()
		return ctx.VFXService:PlayCharacterSFXAtPart("DisbeliefPapyrus", soundName, parentPart, lifetime or 2)
	end)

	if not success or not played then
		pcall(function()
			ctx.VFXService:PlayCharacterSFXAtPart("Sans", soundName, parentPart, lifetime or 2)
		end)
	end
end

local function playCharacterAnimation(ctx, animationName, looped)
	if not ctx or not ctx.Character then return nil end

	local animationService = ctx.StateService and ctx.StateService.AnimationService

	if not animationService or not animationService.PlayCharacterAnimation then
		warn("[EnterDisbeliefPhase2] Missing AnimationService")
		return nil
	end

	local success, track = pcall(function()
		return animationService:PlayCharacterAnimation(ctx.Character, animationName, 0.05, 1, 1, true)
	end)

	if not success or not track then
		warn("[EnterDisbeliefPhase2] Failed to play animation:", animationName)
		return nil
	end

	track.Looped = looped == true
	return track
end

local function beginPapyrusIFrames(character)
	if not character or not character.Parent then return nil end

	local oldState = {
		IFrameActive = character:GetAttribute("IFrameActive"),
		ArmorActive = character:GetAttribute("ArmorActive"),
		ArmorDamageReduction = character:GetAttribute("ArmorDamageReduction"),
		ArmorPreventsStun = character:GetAttribute("ArmorPreventsStun"),
		ArmorPreventsKnockback = character:GetAttribute("ArmorPreventsKnockback"),
		ArmorPreventsHitCancel = character:GetAttribute("ArmorPreventsHitCancel"),
	}

	character:SetAttribute("IFrameActive", true)
	character:SetAttribute("ArmorActive", true)
	character:SetAttribute("ArmorDamageReduction", 1)
	character:SetAttribute("ArmorPreventsStun", true)
	character:SetAttribute("ArmorPreventsKnockback", true)
	character:SetAttribute("ArmorPreventsHitCancel", true)

	return oldState
end

local function restorePapyrusIFrames(character, oldState)
	if not oldState then return end
	if not character or not character.Parent then return end

	character:SetAttribute("IFrameActive", oldState.IFrameActive)
	character:SetAttribute("ArmorActive", oldState.ArmorActive)
	character:SetAttribute("ArmorDamageReduction", oldState.ArmorDamageReduction)
	character:SetAttribute("ArmorPreventsStun", oldState.ArmorPreventsStun)
	character:SetAttribute("ArmorPreventsKnockback", oldState.ArmorPreventsKnockback)
	character:SetAttribute("ArmorPreventsHitCancel", oldState.ArmorPreventsHitCancel)
end

local function beginCinematicLock(character, lockToken)
	if not character or not character.Parent then return nil end

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if not humanoid then
		return nil
	end

	local oldState = {
		Character = character,

		WalkSpeed = humanoid.WalkSpeed,
		JumpPower = humanoid.JumpPower,
		JumpHeight = humanoid.JumpHeight,
		AutoRotate = humanoid.AutoRotate,
		JumpEnabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping),

		Stunned = character:GetAttribute("Stunned"),
		Blocking = character:GetAttribute("Blocking"),
		DashLocked = character:GetAttribute("DashLocked"),
		MovementLocked = character:GetAttribute("MovementLocked"),
		M1Locked = character:GetAttribute("M1Locked"),
		MoveLocked = character:GetAttribute("MoveLocked"),
		BlockLocked = character:GetAttribute("BlockLocked"),
		ActionLocked = character:GetAttribute("ActionLocked"),
		CinematicLocked = character:GetAttribute("CinematicLocked"),
		CinematicLockToken = character:GetAttribute("CinematicLockToken"),
	}

	character:SetAttribute("CinematicLocked", true)
	character:SetAttribute("CinematicLockToken", lockToken)

	return oldState
end

local function enforceCinematicLock(character, lockToken)
	if not character or not character.Parent then return end

	if character:GetAttribute("CinematicLockToken") ~= lockToken then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or humanoid.Health <= 0 then
		return
	end

	character:SetAttribute("CinematicLocked", true)
	character:SetAttribute("CinematicLockToken", lockToken)

	character:SetAttribute("Stunned", true)
	character:SetAttribute("Blocking", false)
	character:SetAttribute("DashLocked", true)
	character:SetAttribute("MovementLocked", true)
	character:SetAttribute("M1Locked", true)
	character:SetAttribute("MoveLocked", true)
	character:SetAttribute("BlockLocked", true)
	character:SetAttribute("ActionLocked", true)

	humanoid.WalkSpeed = 0
	humanoid.AutoRotate = true
	humanoid.Jump = false
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	if root then
		zeroVelocity(root)
	end
end

local function restoreCinematicLock(oldState, lockToken)
	if not oldState then return end

	local character = oldState.Character
	if not character or not character.Parent then return end

	if character:GetAttribute("CinematicLockToken") ~= lockToken then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	character:SetAttribute("Stunned", oldState.Stunned)
	character:SetAttribute("Blocking", oldState.Blocking)
	character:SetAttribute("DashLocked", oldState.DashLocked)
	character:SetAttribute("MovementLocked", oldState.MovementLocked)
	character:SetAttribute("M1Locked", oldState.M1Locked)
	character:SetAttribute("MoveLocked", oldState.MoveLocked)
	character:SetAttribute("BlockLocked", oldState.BlockLocked)
	character:SetAttribute("ActionLocked", oldState.ActionLocked)
	character:SetAttribute("CinematicLocked", oldState.CinematicLocked)
	character:SetAttribute("CinematicLockToken", oldState.CinematicLockToken)

	if humanoid and humanoid.Parent and humanoid.Health > 0 then
		humanoid.WalkSpeed = oldState.WalkSpeed or 16
		humanoid.AutoRotate = oldState.AutoRotate ~= false
		humanoid.JumpPower = oldState.JumpPower or 50
		humanoid.JumpHeight = oldState.JumpHeight or 7.2
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, oldState.JumpEnabled ~= false)
	end
end

local function softDamageStun(ctx, targetCharacter, duration)
	if not targetCharacter or not targetCharacter.Parent then return end

	if ctx.StateService and ctx.StateService.StunCharacter then
		pcall(function()
			ctx.StateService:StunCharacter(targetCharacter, duration or 1)
		end)
	end
end

local function tryCounterServiceStart(ctx, token)
	local service = ctx.CounterService
	if not service then return end

	local methods = {
		"StartCounter",
		"BeginCounter",
		"RegisterCounter",
		"SetCounter",
	}

	for _, methodName in ipairs(methods) do
		if service[methodName] and typeof(service[methodName]) == "function" then
			pcall(function()
				service[methodName](service, ctx.Character, {
					Token = token,
					MoveId = ctx.MoveId or "EnterDisbeliefPhase2",
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
	if not service then return end

	local methods = {
		"EndCounter",
		"StopCounter",
		"ClearCounter",
		"UnregisterCounter",
	}

	for _, methodName in ipairs(methods) do
		if service[methodName] and typeof(service[methodName]) == "function" then
			pcall(function()
				service[methodName](service, ctx.Character, token)
			end)

			return
		end
	end
end

local function enterPhase2Attributes(ctx)
	local character = ctx.Character
	local moveData = ctx.MoveData

	if not character or not character.Parent then return end

	character:SetAttribute("CombatMode", "Phase2")
	character:SetAttribute("AwakeningActive", true)
	character:SetAttribute("AwakeningEndsAt", moveData.AwakeningEndsAt or 0)

	character:SetAttribute("PapyrusMode", "Phase2")
	character:SetAttribute("DisbeliefPhase", 2)
	character:SetAttribute("Phase2Active", true)
end

local function equipPhase2Weapons(ctx)
	local character = ctx.Character
	if not character or not character.Parent then return end

	if ctx.WeaponService and ctx.WeaponService.EquipWeapon then
		local success = pcall(function()
			ctx.WeaponService:EquipWeapon(character, "DisbeliefPapyrus")
		end)

		if success then
			return
		end
	end

	local assets = ReplicatedStorage:WaitForChild("Assets")
	local charactersFolder = assets:WaitForChild("Characters")
	local papyrusFolder = charactersFolder:WaitForChild("DisbeliefPapyrus")
	local weaponModuleScript = papyrusFolder:WaitForChild("Modules"):WaitForChild("WeaponModule")

	local weaponModule = require(weaponModuleScript).new(ctx.Config or {}, papyrusFolder)
	weaponModule:Equip(character)
end

local function findBlasterTemplate()
	local assets = ReplicatedStorage:WaitForChild("Assets")
	local charactersFolder = assets:WaitForChild("Characters")

	local papyrus = charactersFolder:FindFirstChild("DisbeliefPapyrus")
	if papyrus and papyrus:FindFirstChild("VFX") then
		return papyrus.VFX:FindFirstChild("GasterBlaster")
			or papyrus.VFX:FindFirstChild("BrokenBlaster")
			or papyrus.VFX:FindFirstChild("Blaster")
	end

	local sans = charactersFolder:FindFirstChild("Sans")
	if sans and sans:FindFirstChild("VFX") then
		return sans.VFX:FindFirstChild("GasterBlaster")
			or sans.VFX:FindFirstChild("Blaster")
	end

	return nil
end

local function prepareVFXObject(object)
	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end

	if object:IsA("BasePart") then
		object.Anchored = true
		object.CanCollide = false
		object.CanTouch = false
		object.CanQuery = false
		object.Massless = true
	end
end

local function getPrimaryPart(object)
	if object:IsA("BasePart") then
		return object
	end

	if object:IsA("Model") then
		if object.PrimaryPart then
			return object.PrimaryPart
		end

		local part = object:FindFirstChildWhichIsA("BasePart", true)
		if part then
			object.PrimaryPart = part
			return part
		end
	end

	return nil
end

local function pivotObject(object, cframe)
	if object:IsA("Model") then
		if getPrimaryPart(object) then
			object:PivotTo(cframe)
		end
	elseif object:IsA("BasePart") then
		object.CFrame = cframe
	end
end

local function emitParticles(object, wantedNames, fallbackAll)
	if not object then return end

	local matched = false
	local wanted = {}

	for _, name in ipairs(wantedNames or {}) do
		wanted[name] = true
	end

	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			if wanted[descendant.Name] or wanted[descendant.Parent.Name] then
				matched = true

				local emitCount = descendant:GetAttribute("EmitCount")
				if typeof(emitCount) ~= "number" then
					emitCount = 10
				end

				descendant:Emit(emitCount)
			end
		elseif descendant:IsA("Beam") or descendant:IsA("Trail") then
			if wanted[descendant.Name] or wanted[descendant.Parent.Name] then
				matched = true
				descendant.Enabled = true
			end
		end
	end

	if matched or not fallbackAll then
		return
	end

	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			local emitCount = descendant:GetAttribute("EmitCount")
			if typeof(emitCount) ~= "number" then
				emitCount = 10
			end

			descendant:Emit(emitCount)
		end
	end
end

local function setBeamState(object, enabled)
	if not object then return end

	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("Beam") or descendant:IsA("Trail") then
			descendant.Enabled = enabled
		end
	end
end

local function getBlasterSidePositions(ctx, targetRoot)
	local moveData = ctx.MoveData
	local casterRoot = ctx.Root

	local forward

	if casterRoot and casterRoot.Parent then
		forward = targetRoot.Position - casterRoot.Position
	else
		forward = targetRoot.CFrame.LookVector
	end

	forward = Vector3.new(forward.X, 0, forward.Z)

	if forward.Magnitude < 0.05 then
		forward = Vector3.new(targetRoot.CFrame.LookVector.X, 0, targetRoot.CFrame.LookVector.Z)
	end

	if forward.Magnitude < 0.05 then
		forward = Vector3.new(0, 0, -1)
	else
		forward = forward.Unit
	end

	local right = forward:Cross(Vector3.new(0, 1, 0))

	if right.Magnitude < 0.05 then
		right = Vector3.new(targetRoot.CFrame.RightVector.X, 0, targetRoot.CFrame.RightVector.Z)
	end

	if right.Magnitude < 0.05 then
		right = Vector3.new(1, 0, 0)
	else
		right = right.Unit
	end

	local center = targetRoot.Position + Vector3.new(0, moveData.BlasterHeight or 3, 0)
	local sideOffset = moveData.BlasterSideOffset or 8
	local backwardOffset = moveData.BlasterBackwardOffset or 4

	local leftPosition = center - (right * sideOffset) - (forward * backwardOffset)
	local rightPosition = center + (right * sideOffset) - (forward * backwardOffset)

	return {
		{
			Name = "LeftGasterBlaster",
			Position = leftPosition,
			Direction = (targetRoot.Position + Vector3.new(0, 2, 0) - leftPosition).Unit,
		},
		{
			Name = "RightGasterBlaster",
			Position = rightPosition,
			Direction = (targetRoot.Position + Vector3.new(0, 2, 0) - rightPosition).Unit,
		},
	}
end

local function spawnGasterBlasters(ctx, targetRoot)
	if not targetRoot or not targetRoot.Parent then return {} end

	local template = findBlasterTemplate()
	if not template then
		warn("[EnterDisbeliefPhase2] Missing GasterBlaster / BrokenBlaster VFX")
		return {}
	end

	local spawned = {}
	local positions = getBlasterSidePositions(ctx, targetRoot)

	for _, info in ipairs(positions) do
		local blaster = template:Clone()
		blaster.Name = "EnterDisbeliefPhase2_" .. info.Name
		prepareVFXObject(blaster)
		blaster.Parent = workspace

		pivotObject(blaster, CFrame.lookAt(info.Position, targetRoot.Position + Vector3.new(0, 2, 0)))

		setBeamState(blaster, false)
		emitParticles(blaster, { "Charge" }, true)

		table.insert(spawned, blaster)
	end

	return spawned
end

local function fireSpawnedBlasters(ctx, blasters)
	for _, blaster in ipairs(blasters or {}) do
		if blaster and blaster.Parent then
			setBeamState(blaster, true)
			emitParticles(blaster, { "Fire", "Shoot" }, true)
			Debris:AddItem(blaster, ctx.MoveData.BlasterLifetime or 1.8)
		end
	end
end

local function makeBlasterHitData(moveData)
	return {
		Radius = moveData.BlasterRadius or 7,
		Offset = CFrame.new(),

		Damage = moveData.BlasterDamage or 18,
		Stun = moveData.BlasterStun or 1.15,

		Blockable = false,
		CanBeBlocked = false,
		Unblockable = true,

		Guardbreak = false,
		CanBeCountered = false,

		Knockback = 0,
		UpwardKnockback = 0,
	}
end

local function applyBlasterHit(ctx, targetCharacter, targetHumanoid, targetRoot)
	if not targetCharacter or not targetHumanoid or targetHumanoid.Health <= 0 then return end

	local hitData = makeBlasterHitData(ctx.MoveData)

	if ctx.ApplyStandardHit and typeof(ctx.ApplyStandardHit) == "function" then
		local success = pcall(function()
			ctx:ApplyStandardHit(
				targetCharacter,
				targetHumanoid,
				targetRoot,
				hitData,
				ctx.MoveId or "EnterDisbeliefPhase2GasterBlaster"
			)
		end)

		if success then return end
	end

	targetHumanoid:TakeDamage(hitData.Damage or 18)
	softDamageStun(ctx, targetCharacter, hitData.Stun or 1.15)
end

local function chargeThenFireGasterBlasters(ctx, attackerCharacter, lockToken)
	if not attackerCharacter or not attackerCharacter.Parent then
		warn("[EnterDisbeliefPhase2] GasterBlaster marker reached but attacker was missing")
		return
	end

	local attackerHumanoid = attackerCharacter:FindFirstChildOfClass("Humanoid")
	local attackerRoot = attackerCharacter:FindFirstChild("HumanoidRootPart")

	if not attackerHumanoid or attackerHumanoid.Health <= 0 or not attackerRoot then
		return
	end

	local moveData = ctx.MoveData
	local chargeTime = moveData.BlasterChargeTime or 0.65

	enforceCinematicLock(attackerCharacter, lockToken)
	zeroVelocity(attackerRoot)

	local blasters = spawnGasterBlasters(ctx, attackerRoot)
	playPapyrusSFX(ctx, "Ding", attackerRoot, 2)

	task.delay(chargeTime, function()
		if not attackerCharacter or not attackerCharacter.Parent then return end
		if not attackerHumanoid or not attackerHumanoid.Parent or attackerHumanoid.Health <= 0 then return end
		if not attackerRoot or not attackerRoot.Parent then return end

		enforceCinematicLock(attackerCharacter, lockToken)
		fireSpawnedBlasters(ctx, blasters)
		playPapyrusSFX(ctx, "M1", attackerRoot, 2)

		applyBlasterHit(ctx, attackerCharacter, attackerHumanoid, attackerRoot)

		task.defer(function()
			enforceCinematicLock(attackerCharacter, lockToken)
		end)
	end)
end

function EnterDisbeliefPhase2.Execute(context)
	local ctx = context
	local character = ctx and ctx.Character
	local humanoid = ctx and ctx.Humanoid
	local root = ctx and ctx.Root
	local moveData = ctx and ctx.MoveData or EnterDisbeliefPhase2

	if not ctx or not character or not character.Parent then
		finishContext(ctx)
		return
	end

	ctx.MoveData = moveData

	if not humanoid or humanoid.Health <= 0 or not root then
		finishContext(ctx)
		return
	end

	if character:GetAttribute("CombatMode") == "Phase2" or character:GetAttribute("AwakeningActive") == true then
		finishContext(ctx)
		return
	end

	local lockToken = tostring(os.clock()) .. "_" .. tostring(math.random(100000, 999999))

	local casterOldState = beginCinematicLock(character, lockToken)
	local papyrusIFrameState = nil

	local attackerCharacter = nil
	local attackerOldState = nil

	local lockConnection
	lockConnection = RunService.Heartbeat:Connect(function()
		if character and character.Parent then
			enforceCinematicLock(character, lockToken)
		end

		if attackerCharacter and attackerCharacter.Parent then
			enforceCinematicLock(attackerCharacter, lockToken)
		end
	end)

	local counterTrack = playCharacterAnimation(ctx, moveData.CounterAnimationName or "EnterDisbeliefPhase2Counter", true)
	playPapyrusSFX(ctx, "Summon", root, 2)

	task.wait(moveData.StartupTime or 0.05)

	if not contextIsActive(ctx) or not character.Parent or humanoid.Health <= 0 then
		if lockConnection then lockConnection:Disconnect() end
		if counterTrack and counterTrack.IsPlaying then counterTrack:Stop(0.05) end

		restorePapyrusIFrames(character, papyrusIFrameState)
		restoreCinematicLock(casterOldState, lockToken)
		finishContext(ctx)
		return
	end

	local counterToken = (character:GetAttribute("CounterToken") or 0) + 1
	local attackerValue = getOrCreateCounterAttackerValue(character)
	attackerValue.Value = nil

	character:SetAttribute("Countering", true)
	character:SetAttribute("CounterTriggered", false)
	character:SetAttribute("CounterToken", counterToken)
	character:SetAttribute("CounterMoveId", ctx.MoveId or "EnterDisbeliefPhase2")
	character:SetAttribute("CounterAttackName", nil)

	tryCounterServiceStart(ctx, counterToken)

	local finished = false
	local triggered = false
	local counterConnection

	local function cleanupCounterState()
		if character and character.Parent and character:GetAttribute("CounterToken") == counterToken then
			character:SetAttribute("Countering", false)
			character:SetAttribute("CounterTriggered", false)
			character:SetAttribute("CounterMoveId", nil)
			character:SetAttribute("CounterAttackName", nil)
			clearCounterAttacker(character)
		end

		tryCounterServiceEnd(ctx, counterToken)
	end

	local function finish(delayTime)
		if finished then return end
		finished = true

		if counterConnection then
			counterConnection:Disconnect()
			counterConnection = nil
		end

		cleanupCounterState()

		task.delay(delayTime or 0, function()
			if lockConnection then
				lockConnection:Disconnect()
				lockConnection = nil
			end

			restorePapyrusIFrames(character, papyrusIFrameState)
			restoreCinematicLock(attackerOldState, lockToken)
			restoreCinematicLock(casterOldState, lockToken)

			finishContext(ctx)
		end)
	end

	local function triggerUltimate()
		if finished or triggered then return end
		if character:GetAttribute("CounterToken") ~= counterToken then return end

		triggered = true

		attackerCharacter = getStoredAttacker(character)

		if attackerCharacter then
			attackerOldState = beginCinematicLock(attackerCharacter, lockToken)
		end

		character:SetAttribute("Countering", false)
		character:SetAttribute("CounterTriggered", true)

		enforceCinematicLock(character, lockToken)

		if attackerCharacter then
			enforceCinematicLock(attackerCharacter, lockToken)
		end

		playPapyrusSFX(ctx, "Ding", root, 2)

		if counterTrack and counterTrack.IsPlaying then
			counterTrack:Stop(0.05)
		end

		task.wait(0.05)

		papyrusIFrameState = beginPapyrusIFrames(character)

		local transformTrack = playCharacterAnimation(ctx, moveData.TransformAnimationName or "EnterDisbeliefPhase2Transform", false)

		local blackScreenStarted = false
		local blackScreenEnded = false
		local phase2AttributesSet = false
		local weaponChanged = false
		local blasterFired = false

		local function setPhase2AttributesOnce()
			if phase2AttributesSet then return end
			phase2AttributesSet = true
			enterPhase2Attributes(ctx)
		end

		local function weaponChangeOnce()
			if weaponChanged then return end
			weaponChanged = true

			setPhase2AttributesOnce()
			equipPhase2Weapons(ctx)
		end

		local function gasterBlasterOnce()
			if blasterFired then return end
			blasterFired = true

			if attackerCharacter then
				chargeThenFireGasterBlasters(ctx, attackerCharacter, lockToken)
			end
		end

		local function endBlackScreenIfNeeded()
			if blackScreenStarted and not blackScreenEnded then
				blackScreenEnded = true
				fireScreenEffect(character, "BlackScreenEnd")
			end
		end

		if transformTrack then
			transformTrack.Looped = false

			transformTrack:GetMarkerReachedSignal(moveData.BlackScreenMarkerName or "BlackScreen"):Connect(function()
				blackScreenStarted = true
				fireScreenEffect(character, "BlackScreen")
			end)

			transformTrack:GetMarkerReachedSignal(moveData.WeaponChangeMarkerName or "WeaponChange"):Connect(function()
				weaponChangeOnce()
			end)

			transformTrack:GetMarkerReachedSignal(moveData.GasterBlasterMarkerName or "GasterBlaster"):Connect(function()
				gasterBlasterOnce()
			end)

			transformTrack:GetMarkerReachedSignal(moveData.BlackScreenEndMarkerName or "BlackScreenEnd"):Connect(function()
				blackScreenEnded = true
				fireScreenEffect(character, "BlackScreenEnd")
				setPhase2AttributesOnce()
			end)

			transformTrack.Stopped:Connect(function()
				setPhase2AttributesOnce()

				if not weaponChanged then
					weaponChangeOnce()
				end

				endBlackScreenIfNeeded()
				finish(0)
			end)

			pcall(function()
				if transformTrack.IsPlaying then
					transformTrack:Stop(0)
				end

				transformTrack.TimePosition = 0
				transformTrack:Play(0.05, 1, 1)
			end)
		else
			task.delay(moveData.TransformFallbackTime or 7, function()
				setPhase2AttributesOnce()

				if not weaponChanged then
					weaponChangeOnce()
				end

				endBlackScreenIfNeeded()
				finish(0)
			end)
		end

		task.delay(moveData.TransformFallbackTime or 7, function()
			if finished then return end

			setPhase2AttributesOnce()

			if not weaponChanged then
				weaponChangeOnce()
			end

			endBlackScreenIfNeeded()
			finish(0)
		end)
	end

	counterConnection = character:GetAttributeChangedSignal("CounterTriggered"):Connect(function()
		if character:GetAttribute("CounterTriggered") == true then
			triggerUltimate()
		end
	end)

	local startTime = os.clock()
	local counterWindow = moveData.CounterWindow or 1.45

	while contextIsActive(ctx) and not finished and os.clock() - startTime < counterWindow do
		enforceCinematicLock(character, lockToken)

		if character:GetAttribute("CounterTriggered") == true then
			triggerUltimate()
			break
		end

		task.wait()
	end

	if not finished and not triggered then
		if counterTrack and counterTrack.IsPlaying then
			counterTrack:Stop(0.08)
		end

		finish(moveData.WhiffEndlag or 0.35)
	end
end

return EnterDisbeliefPhase2