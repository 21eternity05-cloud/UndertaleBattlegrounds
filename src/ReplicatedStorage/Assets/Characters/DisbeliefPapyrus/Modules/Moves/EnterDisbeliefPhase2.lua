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
	CounterGraceTime = 0.15,
	WhiffEndlag = 0.1,
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

	-- This needs to last through the awakening animation, not just the blaster hit.
	AttackerCounterStun = 7.75,
	CounterCinematicLockTime = 7.75,

	-- Iframes stay on during the whole counter cinematic, then linger after movement/camera restore.
	PostCounterIFrameLinger = 2.3,

	-- Camera: in front of Papyrus, looking at him.
	CounterCameraDistance = 8,
	CounterCameraHeight = 2.6,
	CounterCameraLookHeight = 2.2,
	CounterCameraTweenTime = 0.25,

	-- Optional debug prints.
	DebugCounter = false,
}

local function debugPrint(ctx, ...)
	local moveData = ctx and ctx.MoveData or EnterDisbeliefPhase2

	if moveData.DebugCounter == true then
		print("[EnterDisbeliefPhase2]", ...)
	end
end

local function contextIsActive(ctx)
	if not ctx then
		return false
	end

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
	if not player then
		return
	end

	getScreenEffectRemote():FireClient(player, effectName)
end

local function zeroVelocity(root)
	if not root or not root.Parent then
		return
	end

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
	if not ctx or not ctx.VFXService then
		return
	end
	if not ctx.VFXService.PlayCharacterSFXAtPart then
		return
	end
	if not parentPart or not parentPart.Parent then
		return
	end

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
	if not ctx or not ctx.Character then
		return nil
	end

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

local function savePapyrusIFrameState(character)
	if not character or not character.Parent then
		return nil
	end

	return {
		IFrameActive = character:GetAttribute("IFrameActive"),
		ArmorActive = character:GetAttribute("ArmorActive"),
		ArmorDamageReduction = character:GetAttribute("ArmorDamageReduction"),
		ArmorPreventsStun = character:GetAttribute("ArmorPreventsStun"),
		ArmorPreventsKnockback = character:GetAttribute("ArmorPreventsKnockback"),
		ArmorPreventsHitCancel = character:GetAttribute("ArmorPreventsHitCancel"),
	}
end

local function forcePapyrusIFrames(character)
	if not character or not character.Parent then
		return
	end

	character:SetAttribute("IFrameActive", true)
	character:SetAttribute("ArmorActive", true)
	character:SetAttribute("ArmorDamageReduction", 1)
	character:SetAttribute("ArmorPreventsStun", true)
	character:SetAttribute("ArmorPreventsKnockback", true)
	character:SetAttribute("ArmorPreventsHitCancel", true)

	-- Extra move-local flag. This helps debugging and can be used later by shared hit logic if needed.
	character:SetAttribute("CounterCinematicIFrames", true)
end

local function restorePapyrusIFrames(character, oldState)
	if not character or not character.Parent then
		return
	end

	character:SetAttribute("CounterCinematicIFrames", false)

	if not oldState then
		return
	end

	character:SetAttribute("IFrameActive", oldState.IFrameActive)
	character:SetAttribute("ArmorActive", oldState.ArmorActive)
	character:SetAttribute("ArmorDamageReduction", oldState.ArmorDamageReduction)
	character:SetAttribute("ArmorPreventsStun", oldState.ArmorPreventsStun)
	character:SetAttribute("ArmorPreventsKnockback", oldState.ArmorPreventsKnockback)
	character:SetAttribute("ArmorPreventsHitCancel", oldState.ArmorPreventsHitCancel)
end

local function beginCinematicLock(character, lockToken)
	if not character or not character.Parent then
		return nil
	end

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
	if not character or not character.Parent then
		return
	end

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
	if not oldState then
		return
	end

	local character = oldState.Character
	if not character or not character.Parent then
		return
	end

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
	if not targetCharacter or not targetCharacter.Parent then
		return
	end

	if ctx.StateService and ctx.StateService.StunCharacter then
		pcall(function()
			ctx.StateService:StunCharacter(targetCharacter, duration or 1)
		end)
	end
end

local function stunCounterAttacker(ctx, attackerCharacter, duration)
	if not attackerCharacter or not attackerCharacter.Parent then
		return
	end

	duration = duration or 1

	if ctx.StateService and ctx.StateService.StunCharacter then
		pcall(function()
			ctx.StateService:StunCharacter(attackerCharacter, duration)
		end)
	end

	local humanoid = attackerCharacter:FindFirstChildOfClass("Humanoid")
	local root = attackerCharacter:FindFirstChild("HumanoidRootPart")

	attackerCharacter:SetAttribute("Stunned", true)
	attackerCharacter:SetAttribute("Blocking", false)
	attackerCharacter:SetAttribute("DashLocked", true)
	attackerCharacter:SetAttribute("MovementLocked", true)
	attackerCharacter:SetAttribute("M1Locked", true)
	attackerCharacter:SetAttribute("MoveLocked", true)
	attackerCharacter:SetAttribute("BlockLocked", true)
	attackerCharacter:SetAttribute("ActionLocked", true)

	if humanoid and humanoid.Health > 0 then
		humanoid.WalkSpeed = 0
		humanoid.Jump = false
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
	end

	if root then
		zeroVelocity(root)
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

	if not character or not character.Parent then
		return
	end

	character:SetAttribute("CombatMode", "Phase2")
	character:SetAttribute("AwakeningActive", true)
	character:SetAttribute("AwakeningEndsAt", moveData.AwakeningEndsAt or 0)

	character:SetAttribute("PapyrusMode", "Phase2")
	character:SetAttribute("DisbeliefPhase", 2)
	character:SetAttribute("Phase2Active", true)
end

local function startAwakeningTheme(ctx)
	if not ctx then
		return
	end
	if not ctx.AwakeningMusicService then
		return
	end

	local character = ctx.Character
	if not character or not character.Parent then
		return
	end

	local player = ctx.Player

	if not player then
		player = getPlayerFromCharacter(character)
	end

	if not player then
		warn("[EnterDisbeliefPhase2] Could not find player for AwakeningTheme")
		return
	end

	local success, result = pcall(function()
		ctx.AwakeningMusicService:StartForPlayer(player, character, {
			Volume = 0.55,
			FadeInTime = 1.2,
			FadeOutTime = 0.8,
			RollOffMaxDistance = 140,
			RollOffMinDistance = 12,
		})
	end)

	if not success then
		warn("[EnterDisbeliefPhase2] Failed to start AwakeningTheme:", result)
	end
end

local function equipPhase2Weapons(ctx)
	local character = ctx.Character
	if not character or not character.Parent then
		return
	end

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

local function getPapyrusCameraCFrame(ctx)
	local root = ctx.Root
	local moveData = ctx.MoveData or EnterDisbeliefPhase2

	if not root or not root.Parent then
		return nil
	end

	local distance = moveData.CounterCameraDistance or 7
	local height = moveData.CounterCameraHeight or 2.8
	local lookHeight = moveData.CounterCameraLookHeight or 2.1

	local flatLook = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)

	if flatLook.Magnitude < 0.05 then
		flatLook = Vector3.new(0, 0, -1)
	else
		flatLook = flatLook.Unit
	end

	local cameraPosition = root.Position + (flatLook * distance) + Vector3.new(0, height, 0)
	local lookAtPosition = root.Position + Vector3.new(0, lookHeight, 0)

	return CFrame.lookAt(cameraPosition, lookAtPosition)
end

local function startPapyrusCamera(ctx, lockToken)
	if not ctx or not ctx.CinematicService then
		return false
	end

	local character = ctx.Character
	local moveData = ctx.MoveData or EnterDisbeliefPhase2

	if not character or not character.Parent then
		return false
	end

	local cameraCFrame = getPapyrusCameraCFrame(ctx)
	if not cameraCFrame then
		return false
	end

	character:SetAttribute("CinematicCameraToken", lockToken)

	local tweenTime = moveData.CounterCameraTweenTime or 0.25
	local service = ctx.CinematicService
	local success = false

	if service.TweenCamera then
		success = pcall(function()
			service:TweenCamera(character, cameraCFrame, tweenTime)
		end)
	end

	if not success and service.SetCamera then
		success = pcall(function()
			service:SetCamera(character, cameraCFrame)
		end)
	end

	-- Send one hard SetCamera after the tween window. This helps if another local camera update fights the first tween.
	if success and service.SetCamera then
		task.delay(tweenTime + 0.05, function()
			if character and character.Parent and character:GetAttribute("CinematicCameraToken") == lockToken then
				local lockedCFrame = getPapyrusCameraCFrame(ctx)
				if lockedCFrame then
					pcall(function()
						service:SetCamera(character, lockedCFrame)
					end)
				end
			end
		end)
	end

	return success
end

local function maintainPapyrusCamera(ctx, lockToken)
	if not ctx or not ctx.CinematicService then
		return
	end
	if not ctx.CinematicService.SetCamera then
		return
	end

	local character = ctx.Character
	if not character or not character.Parent then
		return
	end
	if character:GetAttribute("CinematicCameraToken") ~= lockToken then
		return
	end

	local cameraCFrame = getPapyrusCameraCFrame(ctx)
	if not cameraCFrame then
		return
	end

	pcall(function()
		ctx.CinematicService:SetCamera(character, cameraCFrame)
	end)
end

local function resetPapyrusCamera(ctx, lockToken)
	if not ctx or not ctx.CinematicService then
		return
	end

	local character = ctx.Character
	if not character or not character.Parent then
		return
	end

	if character:GetAttribute("CinematicCameraToken") ~= lockToken then
		return
	end

	character:SetAttribute("CinematicCameraToken", nil)

	local service = ctx.CinematicService

	if service.ResetCamera then
		pcall(function()
			service:ResetCamera(character)
		end)
	end
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
		return sans.VFX:FindFirstChild("GasterBlaster") or sans.VFX:FindFirstChild("Blaster")
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

local function pivotVFXObject(object, cframe)
	if object:IsA("Model") then
		if getPrimaryPart(object) then
			object:PivotTo(cframe)
		end
	elseif object:IsA("BasePart") then
		object.CFrame = cframe
	end
end

local function emitParticles(object, wantedNames, fallbackAll)
	if not object then
		return
	end

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
	if not object then
		return
	end

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
	if not targetRoot or not targetRoot.Parent then
		return {}
	end

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

		pivotVFXObject(blaster, CFrame.lookAt(info.Position, targetRoot.Position + Vector3.new(0, 2, 0)))

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

		HitCancelsTarget = false,
		AwardsUlt = false,
	}
end

local function applyConfirmedBlasterHit(ctx, targetCharacter, targetHumanoid, targetRoot, hitData)
	if not targetCharacter or not targetHumanoid or targetHumanoid.Health <= 0 then
		return
	end
	if not targetRoot or not targetRoot.Parent then
		return
	end

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

		if success then
			return
		end
	end

	targetHumanoid:TakeDamage(hitData.Damage or 18)
	softDamageStun(ctx, targetCharacter, hitData.Stun or 1.15)
end

local function applyBlasterHit(ctx, targetCharacter, targetHumanoid, targetRoot)
	if not targetCharacter or not targetHumanoid or targetHumanoid.Health <= 0 then
		return
	end
	if not targetRoot or not targetRoot.Parent then
		return
	end

	local hitData = makeBlasterHitData(ctx.MoveData)
	local hitDone = false

	local function tryHit(hitCharacter, hitHumanoid, hitRoot)
		if hitDone then
			return
		end
		if hitCharacter ~= targetCharacter then
			return
		end
		if not hitHumanoid or hitHumanoid.Health <= 0 then
			return
		end
		if not hitRoot or not hitRoot.Parent then
			return
		end

		hitDone = true
		applyConfirmedBlasterHit(ctx, hitCharacter, hitHumanoid, hitRoot, hitData)
	end

	if ctx.HitboxService and ctx.HitboxService.PerformSphereAtCFrame then
		local success = pcall(function()
			ctx.HitboxService:PerformSphereAtCFrame(
				ctx.Character,
				targetRoot.CFrame,
				hitData.Radius or 7,
				function(hitCharacter, hitHumanoid, hitRoot)
					tryHit(hitCharacter, hitHumanoid, hitRoot)
				end
			)
		end)

		if success and hitDone then
			return
		end
	end

	if ctx.HitboxService and ctx.HitboxService.PerformSphereAtPosition then
		local success = pcall(function()
			ctx.HitboxService:PerformSphereAtPosition(
				ctx.Character,
				targetRoot.Position,
				hitData.Radius or 7,
				function(hitCharacter, hitHumanoid, hitRoot)
					tryHit(hitCharacter, hitHumanoid, hitRoot)
				end
			)
		end)

		if success and hitDone then
			return
		end
	end

	applyConfirmedBlasterHit(ctx, targetCharacter, targetHumanoid, targetRoot, hitData)
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
	local lockTime = moveData.CounterCinematicLockTime
		or moveData.AttackerCounterStun
		or math.max(moveData.TransformFallbackTime or 7, chargeTime + 0.75)

	enforceCinematicLock(attackerCharacter, lockToken)
	stunCounterAttacker(ctx, attackerCharacter, lockTime)
	zeroVelocity(attackerRoot)

	local blasters = spawnGasterBlasters(ctx, attackerRoot)
	playPapyrusSFX(ctx, "Ding", attackerRoot, 2)

	task.delay(chargeTime, function()
		if not attackerCharacter or not attackerCharacter.Parent then
			return
		end
		if not attackerHumanoid or not attackerHumanoid.Parent or attackerHumanoid.Health <= 0 then
			return
		end
		if not attackerRoot or not attackerRoot.Parent then
			return
		end

		enforceCinematicLock(attackerCharacter, lockToken)
		stunCounterAttacker(ctx, attackerCharacter, lockTime)

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
	local papyrusIFramesActive = false
	local protectionActive = false

	local attackerCharacter = nil
	local attackerOldState = nil

	local counterSucceeded = false
	local cameraStarted = false
	local lastCameraMaintain = 0

	local finished = false
	local triggered = false
	local counterConnection = nil
	local lockConnection = nil
	local protectionConnection = nil

	lockConnection = RunService.Heartbeat:Connect(function()
		if character and character.Parent then
			enforceCinematicLock(character, lockToken)
		end

		if attackerCharacter and attackerCharacter.Parent then
			enforceCinematicLock(attackerCharacter, lockToken)
		end
	end)

	protectionConnection = RunService.Heartbeat:Connect(function()
		if not protectionActive then
			return
		end

		if character and character.Parent then
			forcePapyrusIFrames(character)
		end

		if cameraStarted then
			local now = os.clock()

			-- Do not spam every frame, but keep the camera locked if another camera script fights it.
			if now - lastCameraMaintain >= 0.35 then
				lastCameraMaintain = now
				maintainPapyrusCamera(ctx, lockToken)
			end
		end
	end)

	local counterTrack =
		playCharacterAnimation(ctx, moveData.CounterAnimationName or "EnterDisbeliefPhase2Counter", false)
	playPapyrusSFX(ctx, "Summon", root, 2)

	task.wait(moveData.StartupTime or 0.05)

	if not contextIsActive(ctx) or not character.Parent or humanoid.Health <= 0 then
		if lockConnection then
			lockConnection:Disconnect()
		end
		if protectionConnection then
			protectionConnection:Disconnect()
		end
		if counterTrack and counterTrack.IsPlaying then
			counterTrack:Stop(0.05)
		end

		restorePapyrusIFrames(character, papyrusIFrameState)
		restoreCinematicLock(casterOldState, lockToken)
		finishContext(ctx)
		return
	end

	local counterToken = (character:GetAttribute("CounterToken") or 0) + 1
	local attackerValue = getOrCreateCounterAttackerValue(character)
	attackerValue.Value = nil

	-- Important:
	-- Do NOT set IFrameActive here.
	-- NPCM1 / player M1 must be allowed to touch Papyrus so CounterService can trigger.
	character:SetAttribute("Countering", true)
	character:SetAttribute("CounterTriggered", false)
	character:SetAttribute("CounterToken", counterToken)
	character:SetAttribute("CounterMoveId", ctx.MoveId or "EnterDisbeliefPhase2")
	character:SetAttribute("CounterAttackName", nil)

	tryCounterServiceStart(ctx, counterToken)

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

	local function disconnectProtectionAfterRestore()
		protectionActive = false

		if protectionConnection then
			protectionConnection:Disconnect()
			protectionConnection = nil
		end
	end

	local function restoreIFramesWithLinger()
		if not papyrusIFrameState then
			disconnectProtectionAfterRestore()
			if character and character.Parent then
				character:SetAttribute("CounterCinematicIFrames", false)
			end
			return
		end

		if counterSucceeded then
			local linger = moveData.PostCounterIFrameLinger or EnterDisbeliefPhase2.PostCounterIFrameLinger or 1.6

			debugPrint(ctx, "Iframe linger started:", linger)

			task.delay(linger, function()
				if character and character.Parent then
					restorePapyrusIFrames(character, papyrusIFrameState)
				end

				disconnectProtectionAfterRestore()
				debugPrint(ctx, "Iframe linger ended")
			end)
		else
			if character and character.Parent then
				restorePapyrusIFrames(character, papyrusIFrameState)
			end

			disconnectProtectionAfterRestore()
		end
	end

	local function finish(delayTime)
		if finished then
			return
		end
		finished = true

		debugPrint(ctx, "Finish called. CounterSucceeded:", counterSucceeded)

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

			if cameraStarted then
				resetPapyrusCamera(ctx, lockToken)
				cameraStarted = false
			end

			restoreCinematicLock(attackerOldState, lockToken)
			restoreCinematicLock(casterOldState, lockToken)

			-- Keep Papyrus protected after the animation ends, then restore.
			restoreIFramesWithLinger()

			finishContext(ctx)
		end)
	end

	local function beginTransformIFramesOnce()
		if papyrusIFramesActive then
			return
		end
		papyrusIFramesActive = true
		papyrusIFrameState = savePapyrusIFrameState(character)
		protectionActive = true
		forcePapyrusIFrames(character)
		debugPrint(ctx, "Transform iframes started")
	end

	local function triggerUltimate()
		if finished or triggered then
			return
		end
		if character:GetAttribute("CounterToken") ~= counterToken then
			return
		end

		triggered = true
		counterSucceeded = true

		debugPrint(ctx, "Counter triggered")

		-- Successful counter confirmed:
		-- Papyrus now gets protected. This protection is re-applied every Heartbeat until after linger.
		beginTransformIFramesOnce()

		cameraStarted = startPapyrusCamera(ctx, lockToken)
		lastCameraMaintain = os.clock()
		debugPrint(ctx, "Camera started:", cameraStarted)

		attackerCharacter = getStoredAttacker(character)

		if attackerCharacter then
			attackerOldState = beginCinematicLock(attackerCharacter, lockToken)

			local lockTime = moveData.CounterCinematicLockTime
				or moveData.AttackerCounterStun
				or (moveData.TransformFallbackTime or 7)

			stunCounterAttacker(ctx, attackerCharacter, lockTime)
			enforceCinematicLock(attackerCharacter, lockToken)
			debugPrint(ctx, "Attacker locked:", attackerCharacter.Name, lockTime)
		end

		character:SetAttribute("Countering", false)
		character:SetAttribute("CounterTriggered", true)

		enforceCinematicLock(character, lockToken)

		playPapyrusSFX(ctx, "Ding", root, 2)

		if counterTrack and counterTrack.IsPlaying then
			counterTrack:Stop(0.05)
		end

		task.wait(0.05)

		local transformTrack =
			playCharacterAnimation(ctx, moveData.TransformAnimationName or "EnterDisbeliefPhase2Transform", false)

		local blackScreenStarted = false
		local blackScreenEnded = false
		local phase2AttributesSet = false
		local weaponChanged = false
		local blasterFired = false

		local function setPhase2AttributesOnce()
			if phase2AttributesSet then
				return
			end
			phase2AttributesSet = true

			enterPhase2Attributes(ctx)
			startAwakeningTheme(ctx)
			debugPrint(ctx, "Phase 2 attributes set")
		end

		local function weaponChangeOnce()
			if weaponChanged then
				return
			end
			weaponChanged = true

			setPhase2AttributesOnce()
			equipPhase2Weapons(ctx)
			debugPrint(ctx, "Weapons changed")
		end

		local function gasterBlasterOnce()
			if blasterFired then
				return
			end
			blasterFired = true

			if attackerCharacter then
				chargeThenFireGasterBlasters(ctx, attackerCharacter, lockToken)
				debugPrint(ctx, "Counter blasters fired")
			else
				debugPrint(ctx, "No attacker found for blasters")
			end
		end

		local function endBlackScreenIfNeeded()
			if blackScreenStarted and not blackScreenEnded then
				blackScreenEnded = true
				fireScreenEffect(character, "BlackScreenEnd")
				debugPrint(ctx, "Forced BlackScreenEnd")
			end
		end

		if transformTrack then
			transformTrack.Looped = false

			transformTrack:GetMarkerReachedSignal(moveData.BlackScreenMarkerName or "BlackScreen"):Connect(function()
				blackScreenStarted = true
				fireScreenEffect(character, "BlackScreen")
				debugPrint(ctx, "BlackScreen marker")
			end)

			transformTrack:GetMarkerReachedSignal(moveData.WeaponChangeMarkerName or "WeaponChange"):Connect(function()
				weaponChangeOnce()
				debugPrint(ctx, "WeaponChange marker")
			end)

			transformTrack
				:GetMarkerReachedSignal(moveData.GasterBlasterMarkerName or "GasterBlaster")
				:Connect(function()
					gasterBlasterOnce()
					debugPrint(ctx, "GasterBlaster marker")
				end)

			transformTrack
				:GetMarkerReachedSignal(moveData.BlackScreenEndMarkerName or "BlackScreenEnd")
				:Connect(function()
					blackScreenEnded = true
					fireScreenEffect(character, "BlackScreenEnd")
					setPhase2AttributesOnce()

					-- Important:
					-- Do NOT reset camera or remove iframes here.
					-- The camera/iframes last until the whole transform animation ends.
					debugPrint(ctx, "BlackScreenEnd marker")
				end)

			transformTrack.Stopped:Connect(function()
				debugPrint(ctx, "Transform animation stopped")

				setPhase2AttributesOnce()

				if not weaponChanged then
					weaponChangeOnce()
				end

				endBlackScreenIfNeeded()
				finish(0)
			end)

			-- IMPORTANT:
			-- Do not Stop/Play this track here.
			-- playCharacterAnimation already started the animation.
			-- Stopping here can fire transformTrack.Stopped instantly and end camera/iframes too early.
		else
			debugPrint(ctx, "Missing transform track, using fallback")

			task.delay(moveData.TransformFallbackTime or 7, function()
				if finished then
					return
				end

				setPhase2AttributesOnce()

				if not weaponChanged then
					weaponChangeOnce()
				end

				endBlackScreenIfNeeded()
				finish(0)
			end)
		end

		task.delay(moveData.TransformFallbackTime or 7, function()
			if finished then
				return
			end

			debugPrint(ctx, "Transform fallback finished")

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
	local graceTime = moveData.CounterGraceTime or 0.15
	local counterEndTime = startTime + counterWindow
	local graceEndTime = counterEndTime + graceTime

	while contextIsActive(ctx) and not finished and os.clock() < counterEndTime do
		enforceCinematicLock(character, lockToken)

		if character:GetAttribute("CounterTriggered") == true then
			triggerUltimate()
			break
		end

		task.wait()
	end

	if not finished and not triggered then
		while contextIsActive(ctx) and not finished and os.clock() < graceEndTime do
			enforceCinematicLock(character, lockToken)

			if character:GetAttribute("CounterTriggered") == true then
				triggerUltimate()
				break
			end

			task.wait()
		end
	end

	if not finished and not triggered then
		debugPrint(ctx, "Counter whiffed")

		if counterTrack and counterTrack.IsPlaying then
			counterTrack:Stop(0.08)
		end

		finish(moveData.WhiffEndlag or 0.1)
	end
end

return EnterDisbeliefPhase2
