local Players = game:GetService("Players")

local StateService = {}
StateService.__index = StateService

function StateService.new(config, animationService, vfxService)
	local self = setmetatable({}, StateService)

	self.Config = config
	self.AnimationService = animationService
	self.VFXService = vfxService
	self.BlockVisualConnections = setmetatable({}, { __mode = "k" })
	self.ImmunityVisualConnections = setmetatable({}, { __mode = "k" })
	self.ImmunityVisualTokens = setmetatable({}, { __mode = "k" })
	self.WhiffMovementLocks = setmetatable({}, { __mode = "k" })

	return self
end

function StateService:ReconcileBlockingVisuals(character)
	if not self.VFXService or not character or not character.Parent then
		return
	end

	if self.VFXService.ReconcileBlockVFX then
		self.VFXService:ReconcileBlockVFX(character)
	elseif character:GetAttribute("Blocking") == true then
		self.VFXService:StartBlockVFX(character)
	else
		self.VFXService:StopBlockVFX(character)
	end
end

function StateService:HookBlockingVisualState(character)
	if not character or self.BlockVisualConnections[character] then
		return
	end

	local connections = {}

	local function reconcile()
		self:ReconcileBlockingVisuals(character)
	end

	for _, attributeName in ipairs({ "Blocking", "Stunned", "Guardbroken" }) do
		table.insert(connections, character:GetAttributeChangedSignal(attributeName):Connect(reconcile))
	end

	local deathConnected = false
	local function connectHumanoid(humanoid)
		if deathConnected or not humanoid or not humanoid:IsA("Humanoid") then
			return
		end

		deathConnected = true
		table.insert(connections, humanoid.Died:Connect(function()
			if self.VFXService and self.VFXService.StopBlockVFX then
				self.VFXService:StopBlockVFX(character)
			end
		end))
	end

	connectHumanoid(character:FindFirstChildOfClass("Humanoid"))

	table.insert(connections, character.ChildAdded:Connect(function(child)
		connectHumanoid(child)
	end))

	table.insert(connections, character.AncestryChanged:Connect(function(_, parent)
		if parent then
			return
		end

		if self.VFXService and self.VFXService.StopBlockVFX then
			self.VFXService:StopBlockVFX(character)
		end

		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end

		self.BlockVisualConnections[character] = nil
	end))

	self.BlockVisualConnections[character] = connections
	self:ReconcileBlockingVisuals(character)
end

function StateService:ReconcileImmunityVisuals(character)
	if not character or not character.Parent then
		return
	end

	local now = os.clock()
	local m1ImmuneUntil = character:GetAttribute("M1ImmuneUntil") or 0
	local wallImmuneUntil = character:GetAttribute("WallComboProtectedUntil") or 0
	local m1Immune = now < m1ImmuneUntil
	local wallImmune = now < wallImmuneUntil

	if character:GetAttribute("M1Immune") ~= m1Immune then
		character:SetAttribute("M1Immune", m1Immune)
	end

	if character:GetAttribute("WallImmune") ~= wallImmune then
		character:SetAttribute("WallImmune", wallImmune)
	end

	if self.VFXService and self.VFXService.ReconcileImmunityHighlight then
		self.VFXService:ReconcileImmunityHighlight(character)
	end

	local nextUntil = math.huge
	if m1Immune then
		nextUntil = math.min(nextUntil, m1ImmuneUntil)
	end
	if wallImmune then
		nextUntil = math.min(nextUntil, wallImmuneUntil)
	end
	if nextUntil == math.huge or nextUntil <= now then
		return
	end

	local token = (self.ImmunityVisualTokens[character] or 0) + 1
	self.ImmunityVisualTokens[character] = token

	task.delay(math.max(nextUntil - now, 0) + 0.03, function()
		if self.ImmunityVisualTokens[character] ~= token then
			return
		end

		self:ReconcileImmunityVisuals(character)
	end)
end

function StateService:HookImmunityVisualState(character)
	if not character or self.ImmunityVisualConnections[character] then
		return
	end

	local connections = {}

	local function reconcileTimedState()
		self:ReconcileImmunityVisuals(character)
	end

	local function reconcileHighlightOnly()
		if self.VFXService and self.VFXService.ReconcileImmunityHighlight then
			self.VFXService:ReconcileImmunityHighlight(character)
		end
	end

	for _, attributeName in ipairs({ "M1ImmuneUntil", "WallComboProtectedUntil" }) do
		table.insert(connections, character:GetAttributeChangedSignal(attributeName):Connect(reconcileTimedState))
	end

	for _, attributeName in ipairs({ "M1Immune", "WallImmune" }) do
		table.insert(connections, character:GetAttributeChangedSignal(attributeName):Connect(reconcileHighlightOnly))
	end

	local deathConnected = false
	local function connectHumanoid(humanoid)
		if deathConnected or not humanoid or not humanoid:IsA("Humanoid") then
			return
		end

		deathConnected = true
		table.insert(connections, humanoid.Died:Connect(function()
			character:SetAttribute("M1Immune", false)
			character:SetAttribute("WallImmune", false)

			if self.VFXService and self.VFXService.ClearImmunityHighlight then
				self.VFXService:ClearImmunityHighlight(character)
			end
		end))
	end

	connectHumanoid(character:FindFirstChildOfClass("Humanoid"))

	table.insert(connections, character.ChildAdded:Connect(function(child)
		connectHumanoid(child)
	end))

	table.insert(connections, character.AncestryChanged:Connect(function(_, parent)
		if parent then
			return
		end

		if self.VFXService and self.VFXService.ClearImmunityHighlight then
			self.VFXService:ClearImmunityHighlight(character)
		end

		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end

		self.ImmunityVisualConnections[character] = nil
		self.ImmunityVisualTokens[character] = nil
	end))

	self.ImmunityVisualConnections[character] = connections
	self:ReconcileImmunityVisuals(character)
end

function StateService:SetupCharacter(character)
	character:SetAttribute("ComboCount", 0)
	character:SetAttribute("LastM1Time", 0)

	character:SetAttribute("Attacking", false)
	character:SetAttribute("UsingMove", false)
	character:SetAttribute("DebugHighlighted", false)
	character:SetAttribute("Stunned", false)
	character:SetAttribute("Blocking", false)
	character:SetAttribute("Guardbroken", false)
	character:SetAttribute("Emoting", false)
	character:SetAttribute("CurrentEmote", nil)
	character:SetAttribute("SpawnSetupActive", false)
	character:SetAttribute("CharacterSwitchDebounce", false)
	character:SetAttribute("Morphing", false)
	character:SetAttribute("IntroLocked", false)

	character:SetAttribute("AirComboReady", false)
	character:SetAttribute("UsedUptiltInCombo", false)
	character:SetAttribute("SuccessfulM1InCombo", false)
	character:SetAttribute("UptiltCooldownUntil", 0)
	character:SetAttribute("BlockBufferedUntil", 0)
	character:SetAttribute("BlockHeld", false)
	character:SetAttribute("BlockBufferToken", 0)
	character:SetAttribute("BlockLockedUntil", 0)
	character:SetAttribute("AllowBlockWhileDamageLocked", false)
	character:SetAttribute("BadTimeBlockPermissionToken", nil)
	character:SetAttribute("BlockInputReleasedAfterGuardbreak", true)

	character:SetAttribute("JumpLockedUntil", 0)
	character:SetAttribute("StunId", 0)
	character:SetAttribute("GuardbreakId", 0)
	character:SetAttribute("M1ImmuneUntil", 0)
	character:SetAttribute("WallComboProtectedUntil", 0)
	character:SetAttribute("M1Immune", false)
	character:SetAttribute("WallImmune", false)
	character:SetAttribute("CurrentMoveId", nil)
	character:SetAttribute("WhiffMovementLocked", false)
	character:SetAttribute("WhiffMoveLockToken", 0)
	character:SetAttribute("MoveCancelableByHit", true)
	character:SetAttribute("MoveHitCancelsTarget", true)
	character:SetAttribute("M1Token", 0)
	character:SetAttribute("M1CancelableByHit", true)
	character:SetAttribute("CurrentM1Action", nil)
	character:SetAttribute("CombatMode", "Base")
	character:SetAttribute("AwakeningActive", false)
	character:SetAttribute("AwakeningEndsAt", 0)
	character:SetAttribute("Ragdolled", false)
	character:SetAttribute("RagdollReason", nil)
	character:SetAttribute("RagdollType", nil)
	character:SetAttribute("RagdollToken", character:GetAttribute("RagdollToken") or 0)

	character:SetAttribute("IFrameActive", false)
	character:SetAttribute("ArmorActive", false)
	character:SetAttribute("CombatTaggedUntil", 0)
	character:SetAttribute("SoulBurst", character:GetAttribute("SoulBurst") or 0)
	character:SetAttribute("SoulBurstCooldownUntil", character:GetAttribute("SoulBurstCooldownUntil") or 0)
	character:SetAttribute("SoulBursting", false)
	character:SetAttribute("SoulBurstIFrameActive", false)
	character:SetAttribute("SoulBurstIFrameId", character:GetAttribute("SoulBurstIFrameId") or 0)
	character:SetAttribute("SpawnProtected", false)
	character:SetAttribute("SpawnIFrameUntil", 0)
	character:SetAttribute("SpawnIFrameToken", character:GetAttribute("SpawnIFrameToken") or 0)

	character:SetAttribute("ArmorDamageReduction", 0)
	character:SetAttribute("ArmorPreventsStun", false)
	character:SetAttribute("ArmorPreventsKnockback", false)
	character:SetAttribute("ArmorPreventsHitCancel", false)
	character:SetAttribute("ConfirmedCounterProtected", false)
	character:SetAttribute("CounterConfirmed", false)

	if not character:GetAttribute("CharacterName") then
		character:SetAttribute("CharacterName", self.Config.DefaultCharacterName or "Chara")
	end

	self:HookBlockingVisualState(character)
	self:HookImmunityVisualState(character)

	if self.RagdollService and self.RagdollService.CleanupCharacter then
		self.RagdollService:CleanupCharacter(character)
	end
end

function StateService:StartCharacterSetup()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			self:SetupCharacter(character)
		end)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			self:SetupCharacter(player.Character)
		end

		player.CharacterAdded:Connect(function(character)
			self:SetupCharacter(character)
		end)
	end
end

function StateService:GetCharacterInfo(player)
	local character = player.Character
	if not character then return nil end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not root or humanoid.Health <= 0 then
		return nil
	end

	return character, humanoid, root
end

function StateService:CanAttack(character)
	if character:GetAttribute("SpawnSetupActive") then return false end
	if character:GetAttribute("CharacterSwitchDebounce") then return false end
	if character:GetAttribute("Morphing") then return false end
	if character:GetAttribute("IntroLocked") then return false end
	if character:GetAttribute("Emoting") then return false end
	if character:GetAttribute("Attacking") then return false end
	if character:GetAttribute("UsingMove") then return false end
	if character:GetAttribute("Stunned") then return false end
	if character:GetAttribute("Blocking") then return false end
	if character:GetAttribute("Guardbroken") then return false end
	if character:GetAttribute("Ragdolled") then return false end

	return true
end

function StateService:CanUseMove(character)
	if character:GetAttribute("SpawnSetupActive") then return false end
	if character:GetAttribute("CharacterSwitchDebounce") then return false end
	if character:GetAttribute("Morphing") then return false end
	if character:GetAttribute("IntroLocked") then return false end
	if character:GetAttribute("Emoting") then return false end
	if character:GetAttribute("Attacking") then return false end
	if character:GetAttribute("UsingMove") then return false end
	if character:GetAttribute("Stunned") then return false end
	if character:GetAttribute("Blocking") then return false end
	if character:GetAttribute("Guardbroken") then return false end
	if character:GetAttribute("Ragdolled") then return false end

	return true
end

function StateService:ApplyRagdoll(character, duration, options)
	if not self.RagdollService or not self.RagdollService.ApplyRagdoll then
		return nil
	end

	return self.RagdollService:ApplyRagdoll(character, duration, options)
end

function StateService:CancelRagdoll(character, reason)
	if not self.RagdollService or not self.RagdollService.CancelRagdoll then
		return
	end

	self.RagdollService:CancelRagdoll(character, reason)
end

function StateService:IsRagdolled(character)
	if self.RagdollService and self.RagdollService.IsRagdolled then
		return self.RagdollService:IsRagdolled(character)
	end

	return character ~= nil and character:GetAttribute("Ragdolled") == true
end

function StateService:IsAirborne(humanoid)
	local state = humanoid:GetState()

	return state == Enum.HumanoidStateType.Jumping
		or state == Enum.HumanoidStateType.Freefall
end

function StateService:ResetCombo(character)
	character:SetAttribute("ComboCount", 0)
	character:SetAttribute("LastM1Time", 0)
	character:SetAttribute("AirComboReady", false)
	character:SetAttribute("UsedUptiltInCombo", false)
	character:SetAttribute("SuccessfulM1InCombo", false)
end

function StateService:RefreshComboTimeout(character)
	local now = os.clock()
	local lastM1Time = character:GetAttribute("LastM1Time") or 0

	if lastM1Time > 0 and now - lastM1Time > self.Config.M1ResetTime then
		self:ResetCombo(character)
	end
end

function StateService:IsM1Immune(character)
	local immuneUntil = character:GetAttribute("M1ImmuneUntil") or 0
	return os.clock() < immuneUntil
end

function StateService:ApplyM1Immunity(character, duration)
	if not character or not character.Parent then return end

	local immuneUntil = os.clock() + duration
	character:SetAttribute("M1ImmuneUntil", immuneUntil)
	self:ReconcileImmunityVisuals(character)
end

function StateService:StopBlockingVisuals(character)
	if not character or not character.Parent then return end

	character:SetAttribute("Blocking", false)

	if self.AnimationService then
		self.AnimationService:StopBlockAnimation(character)
	end

	if self.VFXService then
		self.VFXService:StopBlockVFX(character)
	end
end

function StateService:ClearBlockIntent(character)
	if not character or not character.Parent then return end

	character:SetAttribute("BlockHeld", false)
	character:SetAttribute("BlockBufferedUntil", 0)
	character:SetAttribute("BlockBufferToken", (character:GetAttribute("BlockBufferToken") or 0) + 1)
end

function StateService:LockJump(character, duration)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local unlockTime = os.clock() + duration
	character:SetAttribute("JumpLockedUntil", unlockTime)

	humanoid.Jump = false
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	task.delay(duration, function()
		if not character or not character.Parent then return end

		local currentHumanoid = character:FindFirstChildOfClass("Humanoid")
		if not currentHumanoid then return end

		local currentUnlockTime = character:GetAttribute("JumpLockedUntil") or 0
		if os.clock() < currentUnlockTime then return end

		if character:GetAttribute("Stunned") then return end
		if character:GetAttribute("Guardbroken") then return end
		if character:GetAttribute("Blocking") then return end
		if character:GetAttribute("UsingMove") then return end
		if character:GetAttribute("Emoting") then return end

		currentHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		currentHumanoid.JumpPower = self.Config.DefaultJumpPower
		currentHumanoid.JumpHeight = self.Config.DefaultJumpHeight
	end)
end

function StateService:CanRefreshHumanoidMovement(character)
	if not character or not character.Parent then
		return false
	end

	if character:GetAttribute("Ragdolled") == true then return false end
	if character:GetAttribute("Stunned") == true then return false end
	if character:GetAttribute("Guardbroken") == true then return false end
	if character:GetAttribute("Grabbed") == true then return false end
	if character:GetAttribute("CinematicLocked") == true then return false end
	if character:GetAttribute("ReservedVictim") == true then return false end
	if character:GetAttribute("UsingMove") == true then return false end
	if character:GetAttribute("MovementLocked") == true then return false end
	if character:GetAttribute("Blocking") == true then return false end
	if character:GetAttribute("Emoting") == true then return false end

	return true
end

function StateService:RefreshHumanoidMovement(character, _reason)
	if not self:CanRefreshHumanoidMovement(character) then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or not humanoid.Parent or humanoid.Health <= 0 then
		return
	end

	humanoid.PlatformStand = false
	humanoid.AutoRotate = true

	pcall(function()
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end)

	task.defer(function()
		if not self:CanRefreshHumanoidMovement(character) then
			return
		end
		if not humanoid.Parent or humanoid.Health <= 0 then
			return
		end

		humanoid.WalkSpeed = self.Config.DefaultWalkSpeed or 16
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		humanoid.JumpPower = self.Config.DefaultJumpPower or 50
		humanoid.JumpHeight = self.Config.DefaultJumpHeight or 7.2

		pcall(function()
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end)
	end)
end

function StateService:CanRestoreWhiffWalkSpeed(character)
	if character:GetAttribute("Stunned") then return false end
	if character:GetAttribute("Guardbroken") then return false end
	if character:GetAttribute("Grabbed") then return false end
	if character:GetAttribute("CinematicLocked") then return false end
	if character:GetAttribute("MovementLocked") then return false end
	if character:GetAttribute("Blocking") then return false end
	if character:GetAttribute("Emoting") then return false end
	if character:GetAttribute("Ragdolled") then return false end

	return true
end

function StateService:HasNonWhiffDashLock(character)
	return character:GetAttribute("SpawnSetupActive") == true
		or character:GetAttribute("CharacterSwitchDebounce") == true
		or character:GetAttribute("Morphing") == true
		or character:GetAttribute("IntroLocked") == true
		or character:GetAttribute("MovementLocked") == true
		or character:GetAttribute("CinematicLocked") == true
		or character:GetAttribute("Ragdolled") == true
		or character:GetAttribute("Grabbed") == true
		or character:GetAttribute("Grabbing") == true
		or character:GetAttribute("UltimateLocked") == true
end

function StateService:ReleaseWhiffMovementLock(character, token)
	if not character then
		return
	end
	if character:GetAttribute("WhiffMoveLockToken") ~= token then
		return
	end

	local lockState = self.WhiffMovementLocks[character]
	self.WhiffMovementLocks[character] = nil

	character:SetAttribute("WhiffMovementLocked", false)

	if character.Parent then
		local shouldStayDashLocked = (lockState and lockState.PreviousDashLocked == true)
			or self:HasNonWhiffDashLock(character)

		character:SetAttribute("DashLocked", shouldStayDashLocked)
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	if not character.Parent then
		return
	end
	if not self:CanRestoreWhiffWalkSpeed(character) then
		return
	end

	local previousWalkSpeed = lockState and lockState.PreviousWalkSpeed
	if typeof(previousWalkSpeed) ~= "number" or previousWalkSpeed <= 0 then
		previousWalkSpeed = self.Config.DefaultWalkSpeed or 16
	end

	humanoid.WalkSpeed = previousWalkSpeed
end

function StateService:ApplyWhiffMovementLock(character, duration, options)
	if not character or not character.Parent then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end

	duration = math.max(0, duration or 0)
	options = options or {}

	local token = (character:GetAttribute("WhiffMoveLockToken") or 0) + 1
	local existing = self.WhiffMovementLocks[character]
	local previousWalkSpeed = existing and existing.PreviousWalkSpeed or humanoid.WalkSpeed
	local previousDashLocked = existing and existing.PreviousDashLocked or character:GetAttribute("DashLocked") == true
	local whiffWalkSpeed = options.WalkSpeed or self.Config.WhiffWalkSpeed or 8

	self.WhiffMovementLocks[character] = {
		Token = token,
		PreviousWalkSpeed = previousWalkSpeed,
		PreviousDashLocked = previousDashLocked,
	}

	character:SetAttribute("WhiffMoveLockToken", token)
	character:SetAttribute("WhiffMovementLocked", true)
	character:SetAttribute("DashLocked", options.DashLocked ~= false)

	humanoid.WalkSpeed = whiffWalkSpeed

	task.delay(duration, function()
		self:ReleaseWhiffMovementLock(character, token)
	end)

	return token
end

function StateService:StopCurrentStunAnimations(character)
	if self.AnimationService and self.AnimationService.StopAllStunAnimations then
		self.AnimationService:StopAllStunAnimations(character, 0.08)
	end
end

function StateService:RecoverFromStaleRagdollPhysics(character, humanoid)
	if not character or not character.Parent then
		return
	end
	if character:GetAttribute("Ragdolled") == true then
		return
	end
	if character:GetAttribute("Grabbed") == true
		or character:GetAttribute("CinematicLocked") == true
		or character:GetAttribute("ReservedVictim") == true
	then
		return
	end
	if not humanoid or not humanoid.Parent or humanoid.Health <= 0 then
		return
	end

	humanoid.PlatformStand = false
	pcall(function()
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end)

	self:RefreshHumanoidMovement(character, "RecoverFromStaleRagdollPhysics")
end

function StateService:StunCharacter(character, duration, animationKey)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local stunId = (character:GetAttribute("StunId") or 0) + 1
	character:SetAttribute("StunId", stunId)

	character:SetAttribute("Stunned", true)
	self:StopBlockingVisuals(character)
	self:StopCurrentStunAnimations(character)

	humanoid.WalkSpeed = 0
	humanoid.Jump = false
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	local chosenAnimationKey = animationKey or "Hitstun"
	local shouldLoop = chosenAnimationKey == "DownslamAir"

	self.AnimationService:PlayUniversalAnimation(
		character,
		chosenAnimationKey,
		0.05,
		1,
		1,
		shouldLoop
	)

	if self.ApplyDebugHighlight then
		self:ApplyDebugHighlight(
			character,
			Color3.fromRGB(255, 230, 60),
			Color3.fromRGB(255, 255, 255)
		)
	end

	task.delay(duration, function()
		if not character or not character.Parent then return end
		if character:GetAttribute("StunId") ~= stunId then return end

		local currentHumanoid = character:FindFirstChildOfClass("Humanoid")
		if not currentHumanoid or currentHumanoid.Health <= 0 then return end

		self:StopCurrentStunAnimations(character)

		character:SetAttribute("Stunned", false)
		self:RecoverFromStaleRagdollPhysics(character, currentHumanoid)

		if self.ClearDebugHighlight then
			self:ClearDebugHighlight(character)
		end

		self:RefreshHumanoidMovement(character, "StunEnded")
	end)
end

function StateService:GuardbreakCharacter(character, duration)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	duration = duration or 1.25
	local guardbreakId = (character:GetAttribute("GuardbreakId") or 0) + 1
	local stunId = (character:GetAttribute("StunId") or 0) + 1
	local blockLockedUntil = os.clock() + duration + 0.1

	character:SetAttribute("GuardbreakId", guardbreakId)
	character:SetAttribute("StunId", stunId)

	self:StopBlockingVisuals(character)
	self:StopCurrentStunAnimations(character)

	character:SetAttribute("BlockLockedUntil", blockLockedUntil)
	character:SetAttribute("BlockInputReleasedAfterGuardbreak", true)
	character:SetAttribute("Guardbroken", true)
	character:SetAttribute("Stunned", true)

	humanoid.WalkSpeed = 0
	humanoid.Jump = false
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	self.AnimationService:PlayUniversalAnimation(character, "BlockBreak", 0.05, 1, 1, false)

	if self.ApplyDebugHighlight then
		self:ApplyDebugHighlight(
			character,
			Color3.fromRGB(255, 70, 70),
			Color3.fromRGB(255, 255, 255)
		)
	end

	task.delay(duration, function()
		if not character or not character.Parent then return end
		if character:GetAttribute("GuardbreakId") ~= guardbreakId then return end

		local currentHumanoid = character:FindFirstChildOfClass("Humanoid")
		if not currentHumanoid or currentHumanoid.Health <= 0 then return end

		self.AnimationService:StopUniversalAnimation(character, "BlockBreak", 0.08)

		character:SetAttribute("Guardbroken", false)

		if character:GetAttribute("StunId") == stunId then
			character:SetAttribute("Stunned", false)
			self:RecoverFromStaleRagdollPhysics(character, currentHumanoid)
		end

		if self.ClearDebugHighlight then
			self:ClearDebugHighlight(character)
		end

		self:RefreshHumanoidMovement(character, "GuardbreakEnded")
	end)
end

function StateService:IsDebugEnabled()
	return self.Config.DebugEnabled == true
end

function StateService:ApplyDebugHighlight(character, fillColor, outlineColor)
	if not self:IsDebugEnabled() then return end
	if not character or not character.Parent then return end

	local existing = character:FindFirstChild("DebugStateHighlight")
	if existing then
		existing:Destroy()
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "DebugStateHighlight"
	highlight.FillColor = fillColor or Color3.fromRGB(255, 255, 0)
	highlight.OutlineColor = outlineColor or Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.45
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = character

	character:SetAttribute("DebugHighlighted", true)
end

function StateService:ClearDebugHighlight(character)
	if not character or not character.Parent then return end

	local existing = character:FindFirstChild("DebugStateHighlight")
	if existing then
		existing:Destroy()
	end

	character:SetAttribute("DebugHighlighted", false)
end
function StateService:GetOrCreateCounterAttackerValue(character)
	if not character then return nil end

	local value = character:FindFirstChild("CounterAttacker")

	if not value then
		value = Instance.new("ObjectValue")
		value.Name = "CounterAttacker"
		value.Parent = character
	end

	return value
end

function StateService:ClearCounterState(character)
	if not character or not character.Parent then return end

	character:SetAttribute("Countering", false)
	character:SetAttribute("CounterTriggered", false)
	character:SetAttribute("CounterMoveId", nil)

	local value = character:FindFirstChild("CounterAttacker")
	if value and value:IsA("ObjectValue") then
		value.Value = nil
	end
end

function StateService:TryTriggerCounter(targetCharacter, attackerCharacter, attackName, attackData, onCountered)
	if self.CounterService and self.CounterService.TryCounterHit then
		return self.CounterService:TryCounterHit({
			AttackerCharacter = attackerCharacter,
			TargetCharacter = targetCharacter,
			AttackName = attackName or "UnknownAttack",
			AttackData = attackData,
			OnCountered = onCountered,
		})
	end

	if not targetCharacter or not targetCharacter.Parent then return false end
	if not attackerCharacter or not attackerCharacter.Parent then return false end
	if targetCharacter == attackerCharacter then return false end

	local alreadyTriggered = targetCharacter:GetAttribute("CounterTriggered") == true
	local isCountering = targetCharacter:GetAttribute("Countering") == true

	if not isCountering and not alreadyTriggered then
		return false
	end

	local value = targetCharacter:FindFirstChild("CounterAttacker")

	if not value then
		value = Instance.new("ObjectValue")
		value.Name = "CounterAttacker"
		value.Parent = targetCharacter
	end

	if value.Value == nil then
		value.Value = attackerCharacter
	end

	targetCharacter:SetAttribute("CounterTriggered", true)
	targetCharacter:SetAttribute("Countering", false)

	print("[StateService] Counter triggered by:", value.Value and value.Value.Name or "nil")

	return true
end
return StateService
