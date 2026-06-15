-- EnterDisbeliefPhase2
-- ReplicatedStorage > Assets > Characters > DisbeliefPapyrus > Modules > Moves > EnterDisbeliefPhase2

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
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

	-- The GasterBlaster marker is the actual fire moment.
	-- Black screens happen before this marker, so the blasters should fire instantly here.
	BlasterChargeTime = 0.2,
	BlasterLifetime = 2.8,

	BlasterHeight = 3,
	BlasterSideOffset = 8,
	BlasterBackwardOffset = 4,

	-- Sans-style blaster tween polish.
	FadeInOffset = CFrame.new(0, 0, 7),
	FadeOutOffset = CFrame.new(0, 0, 7),
	FadeInTime = 0.16,
	FadeOutTime = 0.32,
	JawOpenTime = 0.18,
	JawOpenAngle = 22,

	-- Code-created beam visual like Sans Gaster Blaster.
	BeamLength = 90,
	BeamRadius = 5.5,
	BeamVisualTransparency = 0.06,
	BeamVisualSizeMultiplier = 1.75,
	BeamFadeTime = 0.18,
	BeamExtraLength = 8,

	-- Standardized MovementService preset knockback.
	BlasterKnockbackSpeed = 105,
	BlasterKnockbackUpward = 28,
	BlasterKnockbackDuration = 0.32,
	BlasterKnockbackMaxForce = 130000,

	-- This needs to last through the awakening animation, not just the blaster hit.
	AttackerCounterStun = 7.75,
	CounterCinematicLockTime = 7.75,

	-- Iframes stay on during the whole counter cinematic, then linger after movement/camera restore.
	PostCounterIFrameLinger = 2.3,

	-- Camera: in front of Papyrus, looking at him.
	CounterCameraDistance = 18,
	CounterCameraHeight = 8,
	CounterCameraLookHeight = 2.2,
	CounterCameraTweenTime = 0.25,

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

	local distance = moveData.CounterCameraDistance or 10
	local height = moveData.CounterCameraHeight or 3.6
	local lookHeight = moveData.CounterCameraLookHeight or 2.2

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

local function startCameraForCharacter(ctx, targetCharacter, lockToken)
	if not ctx or not ctx.CinematicService then
		return false
	end

	if not targetCharacter or not targetCharacter.Parent then
		return false
	end

	local cameraCFrame = getPapyrusCameraCFrame(ctx)
	if not cameraCFrame then
		return false
	end

	targetCharacter:SetAttribute("CinematicCameraToken", lockToken)

	local moveData = ctx.MoveData or EnterDisbeliefPhase2
	local tweenTime = moveData.CounterCameraTweenTime or 0.25
	local service = ctx.CinematicService
	local success = false

	if service.TweenCamera then
		success = pcall(function()
			service:TweenCamera(targetCharacter, cameraCFrame, tweenTime)
		end)
	end

	if not success and service.SetCamera then
		success = pcall(function()
			service:SetCamera(targetCharacter, cameraCFrame)
		end)
	end

	if success and service.SetCamera then
		task.delay(tweenTime + 0.05, function()
			if targetCharacter
				and targetCharacter.Parent
				and targetCharacter:GetAttribute("CinematicCameraToken") == lockToken
			then
				local lockedCFrame = getPapyrusCameraCFrame(ctx)

				if lockedCFrame then
					pcall(function()
						service:SetCamera(targetCharacter, lockedCFrame)
					end)
				end
			end
		end)
	end

	return success
end

local function maintainCameraForCharacter(ctx, targetCharacter, lockToken)
	if not ctx or not ctx.CinematicService then
		return
	end

	if not ctx.CinematicService.SetCamera then
		return
	end

	if not targetCharacter or not targetCharacter.Parent then
		return
	end

	if targetCharacter:GetAttribute("CinematicCameraToken") ~= lockToken then
		return
	end

	local cameraCFrame = getPapyrusCameraCFrame(ctx)
	if not cameraCFrame then
		return
	end

	pcall(function()
		ctx.CinematicService:SetCamera(targetCharacter, cameraCFrame)
	end)
end

local function resetCameraForCharacter(ctx, targetCharacter, lockToken)
	if not ctx or not ctx.CinematicService then
		return
	end

	if not targetCharacter or not targetCharacter.Parent then
		return
	end

	if targetCharacter:GetAttribute("CinematicCameraToken") ~= lockToken then
		return
	end

	targetCharacter:SetAttribute("CinematicCameraToken", nil)

	if ctx.CinematicService.ResetCamera then
		pcall(function()
			ctx.CinematicService:ResetCamera(targetCharacter)
		end)
	end
end

local function getSansVFXFolder(ctx)
	local assets = ReplicatedStorage:WaitForChild(ctx.Config.AssetsFolderName or "Assets")
	local characters = assets:WaitForChild(ctx.Config.CharactersFolderName or "Characters")
	local sans = characters:FindFirstChild("Sans")

	if sans and sans:FindFirstChild("VFX") then
		return sans.VFX
	end

	return nil
end

local function getDisbeliefVFXFolder(ctx)
	local assets = ReplicatedStorage:WaitForChild(ctx.Config.AssetsFolderName or "Assets")
	local characters = assets:WaitForChild(ctx.Config.CharactersFolderName or "Characters")
	local papyrus = characters:FindFirstChild("DisbeliefPapyrus")

	if papyrus and papyrus:FindFirstChild("VFX") then
		return papyrus.VFX
	end

	return nil
end

local function getGasterBlasterTemplate(ctx)
	local papyrusVFX = getDisbeliefVFXFolder(ctx)

	if papyrusVFX then
		local papyrusTemplate = papyrusVFX:FindFirstChild("GasterBlaster")
			or papyrusVFX:FindFirstChild("BrokenBlaster")
			or papyrusVFX:FindFirstChild("Blaster")

		if papyrusTemplate then
			return papyrusTemplate
		end
	end

	local sansVFX = getSansVFXFolder(ctx)

	if sansVFX then
		return sansVFX:FindFirstChild("GasterBlaster")
			or sansVFX:FindFirstChild("Blaster")
	end

	return nil
end

local function ensurePrimaryPart(model)
	if not model or not model:IsA("Model") then
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

local function setupBlasterParts(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end

	local primary = ensurePrimaryPart(model)

	if primary then
		primary.Transparency = 1
	end
end

local function getVisibleParts(model)
	local primary = ensurePrimaryPart(model)
	local parts = {}

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= primary then
			table.insert(parts, descendant)
		end
	end

	return parts
end

local function forcePrimaryInvisible(model)
	local primary = ensurePrimaryPart(model)

	if primary then
		primary.Transparency = 1
		primary.CanCollide = false
		primary.CanTouch = false
		primary.CanQuery = false
	end
end

local function capturePartTransparencies(model)
	local transparencies = {}

	for _, part in ipairs(getVisibleParts(model)) do
		transparencies[part] = part.Transparency
	end

	return transparencies
end

local function setVisiblePartsTransparency(model, transparency)
	for _, part in ipairs(getVisibleParts(model)) do
		part.Transparency = transparency
	end

	forcePrimaryInvisible(model)
end

local function tweenVisibleParts(model, transparencies, tweenInfo, fadeOut)
	for part, originalTransparency in pairs(transparencies) do
		if part and part.Parent then
			local goalTransparency = fadeOut and 1 or originalTransparency

			TweenService:Create(
				part,
				tweenInfo,
				{
					Transparency = goalTransparency,
				}
			):Play()
		end
	end

	forcePrimaryInvisible(model)
end

local function tweenModelPivot(model, startCFrame, endCFrame, tweenInfo)
	if not model or not model.Parent then
		return nil
	end

	local cframeValue = Instance.new("CFrameValue")
	cframeValue.Name = "GasterBlasterTweenCFrame"
	cframeValue.Value = startCFrame

	local connection
	connection = cframeValue:GetPropertyChangedSignal("Value"):Connect(function()
		if model and model.Parent then
			model:PivotTo(cframeValue.Value)
			forcePrimaryInvisible(model)
		end
	end)

	local tween = TweenService:Create(
		cframeValue,
		tweenInfo,
		{
			Value = endCFrame,
		}
	)

	tween.Completed:Connect(function()
		if connection then
			connection:Disconnect()
		end

		if cframeValue then
			cframeValue:Destroy()
		end

		if model and model.Parent then
			model:PivotTo(endCFrame)
			forcePrimaryInvisible(model)
		end
	end)

	tween:Play()
	return tween
end

local function fadeInBlaster(model, finalCFrame, data)
	local offset = data.FadeInOffset or CFrame.new(0, 0, 7)
	local startCFrame = finalCFrame * offset
	local fadeInTime = data.FadeInTime or 0.16
	local transparencies = capturePartTransparencies(model)

	local tweenInfo = TweenInfo.new(
		fadeInTime,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)

	model:PivotTo(startCFrame)
	setVisiblePartsTransparency(model, 1)
	forcePrimaryInvisible(model)

	tweenModelPivot(model, startCFrame, finalCFrame, tweenInfo)
	tweenVisibleParts(model, transparencies, tweenInfo, false)

	return transparencies
end

local function fadeOutBlaster(model, currentCFrame, transparencies, data)
	if not model or not model.Parent then
		return
	end

	local offset = data.FadeOutOffset or CFrame.new(0, 0, 7)
	local endCFrame = currentCFrame * offset
	local fadeOutTime = data.FadeOutTime or 0.16

	local tweenInfo = TweenInfo.new(
		fadeOutTime,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)

	tweenModelPivot(model, currentCFrame, endCFrame, tweenInfo)
	tweenVisibleParts(model, transparencies or capturePartTransparencies(model), tweenInfo, true)

	task.delay(fadeOutTime + 0.03, function()
		if model and model.Parent then
			model:Destroy()
		end
	end)
end

local function getBeamOrigin(blaster)
	local attachment = blaster:FindFirstChild("BeamOrgin", true)

	if attachment and attachment:IsA("Attachment") then
		return attachment
	end

	attachment = blaster:FindFirstChild("BeamOrigin", true)

	if attachment and attachment:IsA("Attachment") then
		return attachment
	end

	return nil
end

local function getWorldBeamPosition(blaster)
	local attachment = getBeamOrigin(blaster)

	if attachment then
		return attachment.WorldPosition
	end

	local primary = ensurePrimaryPart(blaster)

	if primary then
		return primary.Position
	end

	return blaster:GetPivot().Position
end

local function openJaws(blaster, data)
	local leftJaw = blaster:FindFirstChild("Left Jaw", true)
	local rightJaw = blaster:FindFirstChild("Right Jaw", true)

	local jawOpenTime = data.JawOpenTime or 0.18
	local jawOpenAngle = math.rad(data.JawOpenAngle or 22)

	local tweenInfo = TweenInfo.new(
		jawOpenTime,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.Out
	)

	if leftJaw and leftJaw:IsA("BasePart") then
		local goalCFrame = leftJaw.CFrame * CFrame.Angles(-jawOpenAngle, 0, 0)

		TweenService:Create(leftJaw, tweenInfo, {
			CFrame = goalCFrame,
		}):Play()
	end

	if rightJaw and rightJaw:IsA("BasePart") then
		local goalCFrame = rightJaw.CFrame * CFrame.Angles(-jawOpenAngle, 0, 0)

		TweenService:Create(rightJaw, tweenInfo, {
			CFrame = goalCFrame,
		}):Play()
	end
end

local function hideRightEye(blaster)
	local rightEye = blaster:FindFirstChild("RightEye", true)

	if rightEye and rightEye:IsA("BasePart") then
		rightEye.Transparency = 1
	end
end

local function createBeamVisual(startPosition, direction, data)
	if not direction or direction.Magnitude < 0.05 then
		return
	end

	local length = (data.BeamLength or 90) + (data.BeamExtraLength or 8)
	local radius = data.BeamRadius or 5.5
	local sizeMultiplier = data.BeamVisualSizeMultiplier or 1.75
	local visualRadius = radius * sizeMultiplier
	local fadeTime = data.BeamFadeTime or 0.18

	local beam = Instance.new("Part")
	beam.Name = "EnterDisbeliefPhase2GasterBeam"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanTouch = false
	beam.CanQuery = false
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(255, 255, 255)
	beam.Transparency = data.BeamVisualTransparency or 0.06
	beam.Size = Vector3.new(visualRadius, visualRadius, length)

	local center = startPosition + (direction.Unit * (length / 2))
	beam.CFrame = CFrame.lookAt(center, center + direction.Unit)
	beam.Parent = workspace

	local core = Instance.new("Part")
	core.Name = "EnterDisbeliefPhase2GasterBeamCore"
	core.Anchored = true
	core.CanCollide = false
	core.CanTouch = false
	core.CanQuery = false
	core.Material = Enum.Material.Neon
	core.Color = Color3.fromRGB(255, 255, 255)
	core.Transparency = 0
	core.Size = Vector3.new(visualRadius * 0.48, visualRadius * 0.48, length + 3)
	core.CFrame = beam.CFrame
	core.Parent = workspace

	TweenService:Create(
		core,
		TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Transparency = 1,
			Size = Vector3.new(visualRadius * 0.08, visualRadius * 0.08, length + 3),
		}
	):Play()

	TweenService:Create(
		beam,
		TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Transparency = 1,
			Size = Vector3.new(visualRadius * 0.15, visualRadius * 0.15, length),
		}
	):Play()

	Debris:AddItem(core, fadeTime + 0.08)
	Debris:AddItem(beam, fadeTime + 0.08)
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

	local template = getGasterBlasterTemplate(ctx)

	if not template then
		warn("[EnterDisbeliefPhase2] Missing GasterBlaster / BrokenBlaster VFX")
		return {}
	end

	local spawned = {}
	local positions = getBlasterSidePositions(ctx, targetRoot)

	for _, info in ipairs(positions) do
		local blaster = template:Clone()
		blaster.Name = "EnterDisbeliefPhase2_" .. info.Name

		if not blaster:IsA("Model") then
			warn("[EnterDisbeliefPhase2] GasterBlaster VFX should be a Model")
			blaster:Destroy()
			continue
		end

		setupBlasterParts(blaster)

		if not ensurePrimaryPart(blaster) then
			warn("[EnterDisbeliefPhase2] GasterBlaster missing PrimaryPart/BasePart")
			blaster:Destroy()
			continue
		end

		local finalCFrame = CFrame.lookAt(info.Position, targetRoot.Position + Vector3.new(0, 2, 0))

		blaster.Parent = workspace

		local originalTransparencies = fadeInBlaster(blaster, finalCFrame, ctx.MoveData)

		Debris:AddItem(blaster, ctx.MoveData.BlasterLifetime or 1.8)

		table.insert(spawned, {
			Model = blaster,
			FinalCFrame = finalCFrame,
			OriginalTransparencies = originalTransparencies,
		})
	end

	return spawned
end

local function fireSpawnedBlasters(ctx, blasters, targetRoot)
	if not targetRoot or not targetRoot.Parent then
		return
	end

	for _, blasterData in ipairs(blasters or {}) do
		local blaster = blasterData.Model

		if blaster and blaster.Parent then
			openJaws(blaster, ctx.MoveData)
			hideRightEye(blaster)
			forcePrimaryInvisible(blaster)

			local beamStart = getWorldBeamPosition(blaster)
			local aimPosition = targetRoot.Position + Vector3.new(0, 2, 0)
			local direction = aimPosition - beamStart

			if direction.Magnitude < 0.05 then
				direction = blaster:GetPivot().LookVector
			end

			createBeamVisual(beamStart, direction.Unit, ctx.MoveData)

			task.delay(0.35, function()
				if blaster and blaster.Parent then
					fadeOutBlaster(
						blaster,
						blaster:GetPivot(),
						blasterData.OriginalTransparencies,
						ctx.MoveData
					)
				end
			end)
		end
	end
end

local function makeBlasterHitData(moveData)
	return {
		Radius = moveData.BlasterRadius or moveData.BeamRadius or 7,
		Offset = CFrame.new(),

		Damage = moveData.BlasterDamage or 18,
		Stun = moveData.BlasterStun or 1.15,

		Blockable = false,
		CanBeBlocked = false,
		Unblockable = true,

		Guardbreak = false,
		CanBeCountered = false,

		-- Knockback is manual through MovementService so it uses the standardized preset path.
		Knockback = 0,
		UpwardKnockback = 0,
		KnockbackDuration = 0,
		KnockbackMaxForce = 0,

		HitCancelsTarget = false,
		AwardsUlt = false,
	}
end

local function applyBlasterKnockback(ctx, targetRoot, moveData)
	if not targetRoot or not targetRoot.Parent then
		return
	end

	if not ctx.Root or not ctx.Root.Parent then
		return
	end

	if not ctx.MovementService or not ctx.MovementService.ApplyPresetKnockback then
		warn("[EnterDisbeliefPhase2] Missing MovementService:ApplyPresetKnockback for Gaster Blaster knockback")
		return
	end

	local knockbackData = {
		KnockbackPreset = "PresetKnockback",

		PresetKnockbackSpeed = moveData.BlasterKnockbackSpeed or 105,
		PresetKnockbackUpward = moveData.BlasterKnockbackUpward or 28,
		PresetKnockbackDuration = moveData.BlasterKnockbackDuration or 0.32,
		PresetKnockbackMaxForce = moveData.BlasterKnockbackMaxForce or 130000,

		Knockback = moveData.BlasterKnockbackSpeed or 105,
		UpwardKnockback = moveData.BlasterKnockbackUpward or 28,
		KnockbackDuration = moveData.BlasterKnockbackDuration or 0.32,
		KnockbackMaxForce = moveData.BlasterKnockbackMaxForce or 130000,
	}

	ctx.MovementService:ApplyPresetKnockback(
		ctx.Root,
		targetRoot,
		knockbackData,
		"EnterDisbeliefPhase2GasterBlaster"
	)
end

local function applyConfirmedBlasterHit(ctx, targetCharacter, targetHumanoid, targetRoot, hitData)
	if not targetCharacter or not targetHumanoid or targetHumanoid.Health <= 0 then
		return nil
	end

	if not targetRoot or not targetRoot.Parent then
		return nil
	end

	if ctx.ApplyStandardHit and typeof(ctx.ApplyStandardHit) == "function" then
		local success, result = pcall(function()
			return ctx:ApplyStandardHit(
				targetCharacter,
				targetHumanoid,
				targetRoot,
				hitData,
				ctx.MoveId or "EnterDisbeliefPhase2GasterBlaster"
			)
		end)

		if success then
			return result
		end
	end

	targetHumanoid:TakeDamage(hitData.Damage or 18)
	softDamageStun(ctx, targetCharacter, hitData.Stun or 1.15)

	return "Hit"
end

local function applyGuaranteedBlasterHit(ctx, targetCharacter, targetHumanoid, targetRoot)
	if not targetCharacter or not targetCharacter.Parent then
		return
	end

	if not targetHumanoid or targetHumanoid.Health <= 0 then
		return
	end

	if not targetRoot or not targetRoot.Parent then
		return
	end

	local hitData = makeBlasterHitData(ctx.MoveData)
	local result = applyConfirmedBlasterHit(ctx, targetCharacter, targetHumanoid, targetRoot, hitData)

	if result == "Hit" or result == "ArmoredHit" or result == nil then
		applyBlasterKnockback(ctx, targetRoot, ctx.MoveData)
	end
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
	local lockTime = moveData.CounterCinematicLockTime
		or moveData.AttackerCounterStun
		or math.max(moveData.TransformFallbackTime or 7, 0.75)

	enforceCinematicLock(attackerCharacter, lockToken)
	stunCounterAttacker(ctx, attackerCharacter, lockTime)
	zeroVelocity(attackerRoot)

	local blasters = spawnGasterBlasters(ctx, attackerRoot)
	playPapyrusSFX(ctx, "Ding", attackerRoot, 2)

	local chargeTime = moveData.BlasterChargeTime or 0

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

		-- Release the attacker from velocity-zeroing cinematic lock right as the beam fires.
		-- Otherwise the standardized knockback gets eaten by the lock heartbeat.
		attackerCharacter:SetAttribute("CounterBlasterKnockbackReleased", true)

		fireSpawnedBlasters(ctx, blasters, attackerRoot)
		playPapyrusSFX(ctx, "M1", attackerRoot, 2)

		applyGuaranteedBlasterHit(ctx, attackerCharacter, attackerHumanoid, attackerRoot)
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
	local cameraTargets = {}
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
			if attackerCharacter:GetAttribute("CounterBlasterKnockbackReleased") ~= true then
				enforceCinematicLock(attackerCharacter, lockToken)
			end
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

			if now - lastCameraMaintain >= 0.35 then
				lastCameraMaintain = now

				for _, cameraTarget in ipairs(cameraTargets) do
					maintainCameraForCharacter(ctx, cameraTarget, lockToken)
				end
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
				for _, cameraTarget in ipairs(cameraTargets) do
					resetCameraForCharacter(ctx, cameraTarget, lockToken)
				end

				cameraStarted = false
			end

			if attackerCharacter and attackerCharacter.Parent then
				attackerCharacter:SetAttribute("CounterBlasterKnockbackReleased", nil)
			end

			restoreCinematicLock(attackerOldState, lockToken)
			restoreCinematicLock(casterOldState, lockToken)

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

	local function addCameraTarget(targetCharacter)
		if not targetCharacter or not targetCharacter.Parent then
			return
		end

		for _, existing in ipairs(cameraTargets) do
			if existing == targetCharacter then
				return
			end
		end

		local started = startCameraForCharacter(ctx, targetCharacter, lockToken)

		if started then
			table.insert(cameraTargets, targetCharacter)
			cameraStarted = true
		end
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

		beginTransformIFramesOnce()

		attackerCharacter = getStoredAttacker(character)

		addCameraTarget(character)

		if attackerCharacter then
			addCameraTarget(attackerCharacter)
		end

		lastCameraMaintain = os.clock()
		debugPrint(ctx, "Camera targets:", #cameraTargets)

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

				if attackerCharacter then
					fireScreenEffect(attackerCharacter, "BlackScreenEnd")
				end

				debugPrint(ctx, "Forced BlackScreenEnd")
			end
		end

		if transformTrack then
			transformTrack.Looped = false

			transformTrack:GetMarkerReachedSignal(moveData.BlackScreenMarkerName or "BlackScreen"):Connect(function()
				blackScreenStarted = true

				fireScreenEffect(character, "BlackScreen")

				if attackerCharacter then
					fireScreenEffect(attackerCharacter, "BlackScreen")
				end

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

					if attackerCharacter then
						fireScreenEffect(attackerCharacter, "BlackScreenEnd")
					end

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

			-- Do not Stop/Play this track here.
			-- playCharacterAnimation already started the animation.
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