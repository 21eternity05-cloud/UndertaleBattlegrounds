local Players = game:GetService("Players")

local StateService = {}
StateService.__index = StateService

function StateService.new(config, animationService, vfxService)
	local self = setmetatable({}, StateService)

	self.Config = config
	self.AnimationService = animationService
	self.VFXService = vfxService

	return self
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

	character:SetAttribute("AirComboReady", false)
	character:SetAttribute("UsedUptiltInCombo", false)
	character:SetAttribute("SuccessfulM1InCombo", false)
	character:SetAttribute("UptiltCooldownUntil", 0)
	character:SetAttribute("BlockBufferedUntil", 0)
	character:SetAttribute("BlockHeld", false)
	character:SetAttribute("BlockBufferToken", 0)
	character:SetAttribute("BlockLockedUntil", 0)
	character:SetAttribute("BlockInputReleasedAfterGuardbreak", true)

	character:SetAttribute("JumpLockedUntil", 0)
	character:SetAttribute("StunId", 0)
	character:SetAttribute("GuardbreakId", 0)
	character:SetAttribute("M1ImmuneUntil", 0)
	character:SetAttribute("CurrentMoveId", nil)
	character:SetAttribute("MoveCancelableByHit", true)
	character:SetAttribute("MoveHitCancelsTarget", true)

	character:SetAttribute("IFrameActive", false)
	character:SetAttribute("ArmorActive", false)
	character:SetAttribute("CombatTaggedUntil", 0)
	character:SetAttribute("SoulBurst", character:GetAttribute("SoulBurst") or 0)
	character:SetAttribute("SoulBurstCooldownUntil", character:GetAttribute("SoulBurstCooldownUntil") or 0)
	character:SetAttribute("SoulBursting", false)
	character:SetAttribute("SoulBurstIFrameId", character:GetAttribute("SoulBurstIFrameId") or 0)
	character:SetAttribute("SpawnProtected", false)
	character:SetAttribute("SpawnIFrameUntil", 0)
	character:SetAttribute("SpawnIFrameToken", character:GetAttribute("SpawnIFrameToken") or 0)

	character:SetAttribute("ArmorDamageReduction", 0)
	character:SetAttribute("ArmorPreventsStun", false)
	character:SetAttribute("ArmorPreventsKnockback", false)
	character:SetAttribute("ArmorPreventsHitCancel", false)

	if not character:GetAttribute("CharacterName") then
		character:SetAttribute("CharacterName", self.Config.DefaultCharacterName or "Chara")
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
	if character:GetAttribute("Attacking") then return false end
	if character:GetAttribute("UsingMove") then return false end
	if character:GetAttribute("Stunned") then return false end
	if character:GetAttribute("Blocking") then return false end
	if character:GetAttribute("Guardbroken") then return false end

	return true
end

function StateService:CanUseMove(character)
	if character:GetAttribute("Attacking") then return false end
	if character:GetAttribute("UsingMove") then return false end
	if character:GetAttribute("Stunned") then return false end
	if character:GetAttribute("Blocking") then return false end
	if character:GetAttribute("Guardbroken") then return false end

	return true
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

	character:SetAttribute("M1ImmuneUntil", os.clock() + duration)
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

		currentHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		currentHumanoid.JumpPower = self.Config.DefaultJumpPower
		currentHumanoid.JumpHeight = self.Config.DefaultJumpHeight
	end)
end

function StateService:StopCurrentStunAnimations(character)
	if self.AnimationService and self.AnimationService.StopAllStunAnimations then
		self.AnimationService:StopAllStunAnimations(character, 0.08)
	end
end

function StateService:StunCharacter(character, duration, animationKey)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local stunId = (character:GetAttribute("StunId") or 0) + 1
	character:SetAttribute("StunId", stunId)

	character:SetAttribute("BlockBufferedUntil", 0)
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

		if self.ClearDebugHighlight then
			self:ClearDebugHighlight(character)
		end

		currentHumanoid.WalkSpeed = self.Config.DefaultWalkSpeed

		if not character:GetAttribute("UsingMove") then
			currentHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			currentHumanoid.JumpPower = self.Config.DefaultJumpPower
			currentHumanoid.JumpHeight = self.Config.DefaultJumpHeight
		end
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

	character:SetAttribute("BlockBufferedUntil", 0)
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
		end

		if self.ClearDebugHighlight then
			self:ClearDebugHighlight(character)
		end

		if not character:GetAttribute("Stunned") then
			currentHumanoid.WalkSpeed = self.Config.DefaultWalkSpeed
		end

		if not character:GetAttribute("Stunned") and not character:GetAttribute("UsingMove") then
			currentHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			currentHumanoid.JumpPower = self.Config.DefaultJumpPower
			currentHumanoid.JumpHeight = self.Config.DefaultJumpHeight
		end
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
