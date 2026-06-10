-- EnterDisbeliefPhase2
-- ReplicatedStorage > Assets > Characters > DisbeliefPapyrus > Modules > Moves > EnterDisbeliefPhase2

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

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

	AttackerTriggerStun = 7,

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
	BlasterRange = 28,
	BlasterStep = 5,
	BlasterHeight = 3,
	BlasterSideOffset = 8,
	BlasterBackwardOffset = 4,

	BlasterChargeTime = 0.65,
	BlasterVFXLifetime = 1.45,
	BlasterFireLifetime = 0.35,
}

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

	local remote = getScreenEffectRemote()
	remote:FireClient(player, effectName)
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

local function playCharacterAnimation(ctx, animationName, looped)
	local character = ctx.Character
	local animationService = ctx.StateService and ctx.StateService.AnimationService

	if not animationService then
		warn("[EnterDisbeliefPhase2] Missing AnimationService")
		return nil
	end

	local track = animationService:PlayCharacterAnimation(
		character,
		animationName,
		0.05,
		1,
		1,
		true
	)

	if track then
		track.Looped = looped == true
	else
		warn("[EnterDisbeliefPhase2] Failed to play animation:", animationName)
	end

	return track
end

local function zeroVelocity(root)
	if not root or not root.Parent then return end

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

local function startActionLock(character, humanoid, root)
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

	humanoid.WalkSpeed = 0
	humanoid.AutoRotate = true
	humanoid.Jump = false
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	zeroVelocity(root)

	return oldState
end

local function enforceActionLock(character, humanoid, root)
	if not character or not character.Parent then return end
	if not humanoid or not humanoid.Parent then return end

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

	if root and root.Parent then
		zeroVelocity(root)
	end
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

local function hardStunCharacter(ctx, targetCharacter, duration)
	if not targetCharacter or not targetCharacter.Parent then return end

	duration = duration or 1

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
			targetCharacter:SetAttribute("M1Locked", true)
			targetCharacter:SetAttribute("MoveLocked", true)
			targetCharacter:SetAttribute("BlockLocked", true)
			targetCharacter:SetAttribute("ActionLocked", true)

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
				targetCharacter:SetAttribute("M1Locked", false)
				targetCharacter:SetAttribute("MoveLocked", false)
				targetCharacter:SetAttribute("BlockLocked", false)
				targetCharacter:SetAttribute("ActionLocked", false)

				humanoid.WalkSpeed = oldWalkSpeed
				humanoid.JumpPower = oldJumpPower
				humanoid.JumpHeight = oldJumpHeight
			end)
		end
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
		local method = service[methodName]

		if typeof(method) == "function" then
			pcall(function()
				method(service, ctx.Character, {
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
		local method = service[methodName]

		if typeof(method) == "function" then
			pcall(function()
				method(service, ctx.Character, token)
			end)

			return
		end
	end
end

local function equipPhase2Weapons(ctx)
	local character = ctx.Character

	if not character or not character.Parent then
		return
	end

	local equipped = false

	if ctx.WeaponService then
		local serviceMethods = {
			"EquipWeapon",
			"EquipCharacterWeapon",
			"Equip",
		}

		for _, methodName in ipairs(serviceMethods) do
			local method = ctx.WeaponService[methodName]

			if typeof(method) == "function" then
				local success = pcall(function()
					method(ctx.WeaponService, character, "DisbeliefPapyrus")
				end)

				if success then
					equipped = true
					break
				end
			end
		end
	end

	if not equipped then
		local assets = ReplicatedStorage:WaitForChild("Assets")
		local charactersFolder = assets:WaitForChild("Characters")
		local papyrusFolder = charactersFolder:WaitForChild("DisbeliefPapyrus")
		local modulesFolder = papyrusFolder:WaitForChild("Modules")
		local weaponModuleScript = modulesFolder:WaitForChild("WeaponModule")

		local weaponModule = require(weaponModuleScript).new(ctx.Config or {}, papyrusFolder)
		weaponModule:Equip(character)

		equipped = true
	end

	print("[EnterDisbeliefPhase2] Equipped Phase2 weapons through WeaponModule:", equipped)
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

	print("[DisbeliefPapyrus] Phase2 attributes set.")
end

local function getCharactersFolder()
	local assets = ReplicatedStorage:WaitForChild("Assets")
	return assets:WaitForChild("Characters")
end

local function findBlasterTemplate()
	local charactersFolder = getCharactersFolder()

	local papyrus = charactersFolder:FindFirstChild("DisbeliefPapyrus")
	if papyrus then
		local vfxFolder = papyrus:FindFirstChild("VFX")
		if vfxFolder then
			return vfxFolder:FindFirstChild("GasterBlaster")
				or vfxFolder:FindFirstChild("BrokenBlaster")
				or vfxFolder:FindFirstChild("Blaster")
		end
	end

	local sans = charactersFolder:FindFirstChild("Sans")
	if sans then
		local vfxFolder = sans:FindFirstChild("VFX")
		if vfxFolder then
			return vfxFolder:FindFirstChild("GasterBlaster")
				or vfxFolder:FindFirstChild("Blaster")
		end
	end

	return nil
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
end

local function emitParticles(object, emitName)
	if not object then return end

	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			local emitCount = descendant:GetAttribute("EmitCount")

			if emitName == nil or descendant.Name == emitName or descendant.Parent.Name == emitName then
				if typeof(emitCount) == "number" then
					descendant:Emit(emitCount)
				else
					descendant:Emit(10)
				end
			end
		elseif descendant:IsA("Beam") then
			if emitName == nil or descendant.Name == emitName or descendant.Parent.Name == emitName then
				descendant.Enabled = true
			end
		elseif descendant:IsA("Trail") then
			if emitName == nil or descendant.Name == emitName or descendant.Parent.Name == emitName then
				descendant.Enabled = true
			end
		end
	end
end

local function setBeamState(object, enabled)
	if not object then return end

	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("Beam") or descendant:IsA("Trail") then
			descendant.Enabled = enabled
		elseif descendant:IsA("ParticleEmitter") then
			descendant.Enabled = enabled
		end
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

		local primary = object:FindFirstChild("PrimaryPart", true)
		if primary and primary:IsA("BasePart") then
			object.PrimaryPart = primary
			return primary
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
		if not getPrimaryPart(object) then return end
		object:PivotTo(cframe)
	elseif object:IsA("BasePart") then
		object.CFrame = cframe
	end
end

local function fadeAndDestroy(object, lifetime)
	if not object or not object.Parent then return end

	lifetime = lifetime or 1

	task.delay(lifetime * 0.7, function()
		if not object or not object.Parent then return end

		for _, descendant in ipairs(object:GetDescendants()) do
			if descendant:IsA("BasePart") then
				TweenService:Create(
					descendant,
					TweenInfo.new(lifetime * 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Transparency = 1 }
				):Play()
			end
		end
	end)

	Debris:AddItem(object, lifetime)
end

local function getBlasterSidePositions(ctx, targetRoot)
	local attackerRoot = ctx.Root
	local moveData = ctx.MoveData

	local forwardDirection

	if attackerRoot and attackerRoot.Parent then
		forwardDirection = targetRoot.Position - attackerRoot.Position
	else
		forwardDirection = targetRoot.CFrame.LookVector
	end

	forwardDirection = Vector3.new(forwardDirection.X, 0, forwardDirection.Z)

	if forwardDirection.Magnitude < 0.05 then
		forwardDirection = targetRoot.CFrame.LookVector
	else
		forwardDirection = forwardDirection.Unit
	end

	local rightDirection = forwardDirection:Cross(Vector3.yAxis)

	if rightDirection.Magnitude < 0.05 then
		rightDirection = targetRoot.CFrame.RightVector
	else
		rightDirection = rightDirection.Unit
	end

	local sideOffset = moveData.BlasterSideOffset or 8
	local backwardOffset = moveData.BlasterBackwardOffset or 4
	local height = moveData.BlasterHeight or 3

	local center = targetRoot.Position + Vector3.new(0, height, 0)

	local leftPosition =
		center
		- (rightDirection * sideOffset)
		- (forwardDirection * backwardOffset)

	local rightPosition =
		center
		+ (rightDirection * sideOffset)
		- (forwardDirection * backwardOffset)

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

local function spawnGasterBlasterVFX(ctx, targetRoot)
	if not targetRoot or not targetRoot.Parent then return {} end

	local template = findBlasterTemplate()
	if not template then
		warn("[EnterDisbeliefPhase2] No GasterBlaster/BrokenBlaster VFX found.")
		return {}
	end

	local blasterPositions = getBlasterSidePositions(ctx, targetRoot)
	local spawnedBlasters = {}

	for _, blasterData in ipairs(blasterPositions) do
		local blasterCFrame = CFrame.lookAt(
			blasterData.Position,
			targetRoot.Position + Vector3.new(0, 2, 0)
		)

		local blaster = template:Clone()
		blaster.Name = "EnterDisbeliefPhase2_" .. blasterData.Name
		prepareVFXObject(blaster)
		blaster.Parent = workspace
		pivotObject(blaster, blasterCFrame)

		setBeamState(blaster, false)
		emitParticles(blaster, "Charge")

		table.insert(spawnedBlasters, blaster)
	end

	return spawnedBlasters
end

local function fireSpawnedBlasters(ctx, blasters)
	for _, blaster in ipairs(blasters or {}) do
		if blaster and blaster.Parent then
			setBeamState(blaster, true)
			emitParticles(blaster, "Fire")
			emitParticles(blaster, "Shoot")
			fadeAndDestroy(blaster, ctx.MoveData.BlasterFireLifetime or 0.35)
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
		HitCancelsTarget = true,
		CancelableByHit = false,

		HasIFrames = false,
		HasArmor = false,

		Knockback = 0,
		UpwardKnockback = 0,
		KnockbackDuration = 0,
		KnockbackMaxForce = 0,
	}
end

local function fireGasterBlasterAtCounterAttacker(ctx, attackerCharacter)
	if not attackerCharacter or not attackerCharacter.Parent then
		warn("[EnterDisbeliefPhase2] GasterBlaster marker reached but no attacker was stored.")
		return
	end

	local attackerHumanoid = attackerCharacter:FindFirstChildOfClass("Humanoid")
	local attackerRoot = attackerCharacter:FindFirstChild("HumanoidRootPart")

	if not attackerHumanoid or attackerHumanoid.Health <= 0 or not attackerRoot then
		return
	end

	local character = ctx.Character
	local moveData = ctx.MoveData

	hardStunCharacter(ctx, attackerCharacter, (moveData.BlasterChargeTime or 0.65) + (moveData.BlasterStun or 1.15) + 0.25)
	zeroVelocity(attackerRoot)

	local spawnedBlasters = spawnGasterBlasterVFX(ctx, attackerRoot)

	playPapyrusSFX(ctx, "Ding", attackerRoot, 2)

	task.delay(moveData.BlasterChargeTime or 0.65, function()
		if not attackerCharacter or not attackerCharacter.Parent then return end
		if not attackerHumanoid or not attackerHumanoid.Parent or attackerHumanoid.Health <= 0 then return end
		if not attackerRoot or not attackerRoot.Parent then return end

		zeroVelocity(attackerRoot)
		fireSpawnedBlasters(ctx, spawnedBlasters)

		playPapyrusSFX(ctx, "M1", attackerRoot, 2)

		local hitData = makeBlasterHitData(moveData)
		local didHitAttacker = false

		local function applyBlasterHit()
			if didHitAttacker then return end
			didHitAttacker = true

			if ctx.ApplyStandardHit then
				local result = ctx:ApplyStandardHit(
					attackerCharacter,
					attackerHumanoid,
					attackerRoot,
					hitData,
					ctx.MoveId or "EnterDisbeliefPhase2GasterBlaster"
				)

				print("[EnterDisbeliefPhase2] Charged Dual GasterBlaster result:", result)
			elseif ctx.DefaultApplyHit then
				local result = ctx:DefaultApplyHit(attackerCharacter, attackerHumanoid, attackerRoot)
				print("[EnterDisbeliefPhase2] Charged Dual GasterBlaster result:", result)
			else
				attackerHumanoid:TakeDamage(moveData.BlasterDamage or 18)
				print("[EnterDisbeliefPhase2] Charged Dual GasterBlaster direct damage applied.")
			end
		end

		if not ctx.HitboxService or not ctx.HitboxService.PerformSphereAtCFrame then
			applyBlasterHit()
			return
		end

		local blasterPositions = getBlasterSidePositions(ctx, attackerRoot)
		local alreadyHit = {}

		for _, blasterData in ipairs(blasterPositions) do
			local direction = blasterData.Direction

			for distance = 0, (moveData.BlasterRange or 28), (moveData.BlasterStep or 5) do
				local position = blasterData.Position + (direction * distance)
				local cframe = CFrame.lookAt(position, position + direction)

				ctx.HitboxService:PerformSphereAtCFrame(
					character,
					cframe,
					hitData,
					function(targetCharacter, targetHumanoid, targetRoot)
						if targetCharacter ~= attackerCharacter then
							return
						end

						if alreadyHit[targetCharacter] then
							return
						end

						alreadyHit[targetCharacter] = true
						applyBlasterHit()
					end
				)
			end
		end

		task.delay(0.05, function()
			if not didHitAttacker and attackerHumanoid and attackerHumanoid.Parent and attackerHumanoid.Health > 0 then
				applyBlasterHit()
			end
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
		if ctx and ctx.FinishMove then
			ctx:FinishMove()
		end
		return
	end

	if not humanoid or humanoid.Health <= 0 then
		ctx:FinishMove()
		return
	end

	if not root then
		ctx:FinishMove()
		return
	end

	if character:GetAttribute("CombatMode") == "Phase2" or character:GetAttribute("AwakeningActive") == true then
		print("[DisbeliefPapyrus] Already in Phase2.")
		ctx:FinishMove()
		return
	end

	print("[EnterDisbeliefPhase2] Counter animation started.")

	local oldActionState = startActionLock(character, humanoid, root)

	local lockConnection
	lockConnection = RunService.Heartbeat:Connect(function()
		if not character or not character.Parent then
			if lockConnection then
				lockConnection:Disconnect()
			end
			return
		end

		if not humanoid or not humanoid.Parent or humanoid.Health <= 0 then
			if lockConnection then
				lockConnection:Disconnect()
			end
			return
		end

		enforceActionLock(character, humanoid, root)
	end)

	local counterTrack = playCharacterAnimation(
		ctx,
		moveData.CounterAnimationName or "EnterDisbeliefPhase2Counter",
		true
	)

	playPapyrusSFX(ctx, "Summon", root, 2)

	task.wait(moveData.StartupTime or 0.05)

	if not ctx:IsActive() or not character.Parent or humanoid.Health <= 0 then
		if lockConnection then
			lockConnection:Disconnect()
			lockConnection = nil
		end

		if counterTrack and counterTrack.IsPlaying then
			counterTrack:Stop(0.05)
		end

		restoreActionLock(character, humanoid, oldActionState)
		ctx:FinishMove()
		return
	end

	local counterToken = (character:GetAttribute("CounterToken") or 0) + 1
	local counterAttacker = getOrCreateCounterAttackerValue(character)
	counterAttacker.Value = nil

	character:SetAttribute("Countering", true)
	character:SetAttribute("CounterTriggered", false)
	character:SetAttribute("CounterToken", counterToken)
	character:SetAttribute("CounterMoveId", ctx.MoveId or "EnterDisbeliefPhase2")
	character:SetAttribute("CounterAttackName", nil)

	tryCounterServiceStart(ctx, counterToken)

	local finished = false
	local triggered = false
	local counterConnection = nil

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

		task.delay(delayTime or 0, function()
			if lockConnection then
				lockConnection:Disconnect()
				lockConnection = nil
			end

			restoreActionLock(character, humanoid, oldActionState)
			ctx:FinishMove()
		end)
	end

	local function triggerUltimate()
		if finished or triggered then return end
		if character:GetAttribute("CounterToken") ~= counterToken then return end

		triggered = true

		local attackerCharacter = getStoredAttacker(character)

		print("[EnterDisbeliefPhase2] Counter triggered by:", attackerCharacter and attackerCharacter.Name or "unknown")

		character:SetAttribute("Countering", false)
		character:SetAttribute("CounterTriggered", true)

		enforceActionLock(character, humanoid, root)

		playPapyrusSFX(ctx, "Ding", root, 2)

		if attackerCharacter then
			hardStunCharacter(ctx, attackerCharacter, moveData.AttackerTriggerStun or 7)
		end

		if counterTrack and counterTrack.IsPlaying then
			counterTrack:Stop(0.05)
		end

		task.wait(0.05)

		local transformTrack = playCharacterAnimation(
			ctx,
			moveData.TransformAnimationName or "EnterDisbeliefPhase2Transform",
			false
		)

		print("[EnterDisbeliefPhase2] Playing transform animation:", moveData.TransformAnimationName or "EnterDisbeliefPhase2Transform", transformTrack)

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

			print("[EnterDisbeliefPhase2] WeaponChange marker reached. Switched to LeftBone + RightBone.")
		end

		local function gasterBlasterOnce()
			if blasterFired then return end
			blasterFired = true

			print("[EnterDisbeliefPhase2] GasterBlaster marker reached. Charging dual blasters.")

			if attackerCharacter then
				fireGasterBlasterAtCounterAttacker(ctx, attackerCharacter)
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
				print("[EnterDisbeliefPhase2] BlackScreen marker reached")
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
				print("[EnterDisbeliefPhase2] BlackScreenEnd marker reached")
				blackScreenEnded = true
				fireScreenEffect(character, "BlackScreenEnd")
				setPhase2AttributesOnce()
			end)

			transformTrack.Stopped:Connect(function()
				print("[EnterDisbeliefPhase2] Transform animation stopped")

				setPhase2AttributesOnce()

				if not weaponChanged then
					weaponChangeOnce()
				end

				endBlackScreenIfNeeded()
				finish(0)
			end)

			pcall(function()
				transformTrack:Play(0.05, 1, 1)
			end)
		else
			warn("[EnterDisbeliefPhase2] Transform animation failed to load/play.")

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

	while ctx:IsActive() and not finished and os.clock() - startTime < counterWindow do
		enforceActionLock(character, humanoid, root)

		if character:GetAttribute("CounterTriggered") == true then
			triggerUltimate()
			break
		end

		task.wait()
	end

	if not finished and not triggered then
		print("[EnterDisbeliefPhase2] Counter whiffed.")

		if counterTrack and counterTrack.IsPlaying then
			counterTrack:Stop(0.08)
		end

		finish(moveData.WhiffEndlag or 0.35)
	end
end

return EnterDisbeliefPhase2