local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local KillingIntent = {
	DisplayName = "Killing Intent",
	AnimationName = nil,

	Cooldown = 18,
	Duration = 1.35,
	LockTime = 1.35,
	MaxLockTime = 1.6,

	Damage = 10,
	Stun = 2.25,

	Radius = 20,
	Offset = CFrame.new(0, 0, -4),

	KnockbackPreset = "Downslam",
	DownForwardSpeed = 10,
	DownSpeed = -95,
	DownLaunchMaxForce = 90000,
	AirStunMax = 1.15,
	GroundSplatStun = 2.5,
	PostSplatM1Immunity = 0,
	SplatPartLifetime = 0.35,
	SplatPartSize = Vector3.new(8, 0.25, 8),

	Knockback = 20,
	UpwardKnockback = 0,
	KnockbackDuration = 0.25,
	KnockbackMaxForce = 85000,

	Blockable = false,
	CanBeBlocked = false,
	Unblockable = true,

	Guardbreak = true,
	GuardbreakStun = 1.25,

	CanBeCountered = false,
	IgnoresIFrames = true,
	IgnoresArmor = true,

	HitCancelsTarget = true,
	CancelableByHit = false,

	HasIFrames = false,
	HasArmor = false,

	CounterWindow = 0.7,
}

local COUNTER_ANIMATION = "KillingIntentCounter"
local HIT_ANIMATION = "KillingIntentHit"

local STARTUP_TIME = 0.3
local COUNTER_WINDOW = 1.35
local WHIFF_ENDLAG = 1

local HIT_FREEZE_TIME = 1.4
local DOWNSLAM_IMPACT_DELAY = 0

local HIT_FINISH_DELAY = 0.35
local ATTACKER_COUNTER_STUN = 1.65

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

local function safeSetCounterInvincible(character, enabled)
	if not character or not character.Parent then
		return
	end

	character:SetAttribute("Countering", enabled == true)
end

local function getGroundBelow(root, exclude)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude or {}

	return workspace:Raycast(root.Position, Vector3.new(0, -7, 0), params)
end

local function createSplatPart(position, moveData)
	local size = moveData.SplatPartSize or Vector3.new(8, 0.25, 8)
	local lifetime = moveData.SplatPartLifetime or 0.35

	local part = Instance.new("Part")
	part.Name = "KillingIntentDownslamSplat"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 0, 0)
	part.Transparency = 0.45
	part.Size = size
	part.CFrame = CFrame.new(position + Vector3.new(0, 0.08, 0))
	part.Parent = workspace

	Debris:AddItem(part, lifetime)
end

local function monitorDownslamGroundSplat(context, targetCharacter, targetRoot, moveData, linearVelocity, attachment)
	if not targetCharacter or not targetCharacter.Parent then
		return
	end

	if not targetRoot or not targetRoot.Parent then
		return
	end

	local startTime = os.clock()
	local maxTime = moveData.AirStunMax or 1.35

	if context.StateService and context.StateService.StunCharacter then
		context.StateService:StunCharacter(targetCharacter, maxTime)
	end

	if
		context.StateService
		and context.StateService.AnimationService
		and context.StateService.AnimationService.PlayUniversalAnimation
	then
		context.StateService.AnimationService:PlayUniversalAnimation(targetCharacter, "DownslamAir", 0.05, 1, 1)
	end

	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not targetCharacter.Parent or not targetRoot.Parent then
			connection:Disconnect()

			if linearVelocity then
				linearVelocity:Destroy()
			end

			if attachment then
				attachment:Destroy()
			end

			return
		end

		if os.clock() - startTime > maxTime then
			connection:Disconnect()

			if linearVelocity then
				linearVelocity:Destroy()
			end

			if attachment then
				attachment:Destroy()
			end

			return
		end

		local result = getGroundBelow(targetRoot, { targetCharacter })

		if result then
			connection:Disconnect()

			if linearVelocity then
				linearVelocity:Destroy()
			end

			if attachment then
				attachment:Destroy()
			end

			targetRoot.AssemblyLinearVelocity = Vector3.zero
			targetRoot.AssemblyAngularVelocity = Vector3.zero

			if context.StateService and context.StateService.StunCharacter then
				context.StateService:StunCharacter(targetCharacter, moveData.GroundSplatStun or 0.65)
			end

			if
				context.StateService
				and context.StateService.AnimationService
				and context.StateService.AnimationService.PlayUniversalAnimation
			then
				context.StateService.AnimationService:PlayUniversalAnimation(
					targetCharacter,
					"DownslamSplat",
					0.04,
					1,
					1
				)
			end

			if context.VFXService and context.VFXService.PlayUniversalSFXAtPart then
				context.VFXService:PlayUniversalSFXAtPart("GroundSplat", targetRoot, 2)
			end

			createSplatPart(result.Position, moveData)
		end
	end)
end

function KillingIntent.Execute(context)
	print("[KillingIntent] Execute started")

	local character = context.Character
	local humanoid = context.Humanoid
	local root = context.Root
	local moveData = context.MoveData

	if not character or not character.Parent then
		context:FinishMove(0)
		return
	end

	if not humanoid or humanoid.Health <= 0 then
		context:FinishMove(0)
		return
	end

	if not root then
		context:FinishMove(0)
		return
	end

	local animationService = context.StateService and context.StateService.AnimationService

	if not animationService then
		warn("[KillingIntent] Missing AnimationService on StateService")
		context:FinishMove(0)
		return
	end

	local oldWalkSpeed = humanoid.WalkSpeed
	local oldJumpPower = humanoid.JumpPower
	local oldJumpHeight = humanoid.JumpHeight
	local oldAutoRotate = humanoid.AutoRotate
	local movementLockConnection = nil

	local function addActiveFrameHighlight()
		if not character or not character.Parent then
			return
		end

		local existing = character:FindFirstChild("KillingIntentActiveHighlight")
		if existing then
			existing:Destroy()
		end

		local highlight = Instance.new("Highlight")
		highlight.Name = "KillingIntentActiveHighlight"
		highlight.FillColor = Color3.fromRGB(255, 0, 0)
		highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
		highlight.FillTransparency = 0.35
		highlight.OutlineTransparency = 0
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Parent = character
	end

	local function removeActiveFrameHighlight()
		if not character or not character.Parent then
			return
		end

		local existing = character:FindFirstChild("KillingIntentActiveHighlight")

		if existing then
			existing:Destroy()
		end
	end

	local function zeroHorizontalVelocity(part)
		if not part or not part.Parent then
			return
		end

		local velocity = part.AssemblyLinearVelocity
		part.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)
		part.AssemblyAngularVelocity = Vector3.zero
	end

	local function startHardMovementLock()
		if movementLockConnection then
			movementLockConnection:Disconnect()
			movementLockConnection = nil
		end

		character:SetAttribute("DashLocked", true)
		character:SetAttribute("MovementLocked", true)

		humanoid.WalkSpeed = 0
		humanoid.Jump = false
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid.AutoRotate = true
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

		zeroHorizontalVelocity(root)

		movementLockConnection = RunService.Heartbeat:Connect(function()
			if not character or not character.Parent then
				return
			end

			if not humanoid or not humanoid.Parent then
				return
			end

			if not root or not root.Parent then
				return
			end

			humanoid.WalkSpeed = 0
			humanoid.Jump = false
			humanoid.JumpPower = 0
			humanoid.JumpHeight = 0
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

			zeroHorizontalVelocity(root)
		end)
	end

	local function stopHardMovementLock()
		if movementLockConnection then
			movementLockConnection:Disconnect()
			movementLockConnection = nil
		end

		if character and character.Parent then
			character:SetAttribute("DashLocked", false)
			character:SetAttribute("MovementLocked", false)
		end

		if not humanoid or not humanoid.Parent then
			return
		end

		humanoid.WalkSpeed = oldWalkSpeed
		humanoid.JumpPower = oldJumpPower
		humanoid.JumpHeight = oldJumpHeight
		humanoid.AutoRotate = oldAutoRotate
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	end

	local function playCharaSFX(soundName, part, lifetime)
		if context.VFXService and context.VFXService.PlayCharacterSFXAtPart then
			context.VFXService:PlayCharacterSFXAtPart("Chara", soundName, part or root, lifetime or 2)
		end
	end

	local function playMoveVFX(vfxName, targetCharacter, targetRoot)
		if context.VFXService and context.VFXService.PlayCharacterMoveVFX then
			context.VFXService:PlayCharacterMoveVFX(character, vfxName, targetCharacter, targetRoot)
		end
	end

	local function stunAttacker(targetCharacter, duration)
		if not targetCharacter or not targetCharacter.Parent then
			return
		end

		if context.StateService and context.StateService.StunCharacter then
			context.StateService:StunCharacter(targetCharacter, duration)
		end
	end

	startHardMovementLock()

	local counterTrack = animationService:PlayCharacterAnimation(character, COUNTER_ANIMATION, 0.04, 1, 1, true)

	if not counterTrack then
		warn("[KillingIntent] Could not play animation:", COUNTER_ANIMATION)

		stopHardMovementLock()
		removeActiveFrameHighlight()
		context:FinishMove(0)

		return
	end

	playMoveVFX("KillingIntentCounterStart")
	playCharaSFX("KillingIntentCharge", root, 2)

	local startupStart = os.clock()

	while os.clock() - startupStart < STARTUP_TIME do
		if not character.Parent or humanoid.Health <= 0 then
			playMoveVFX("KillingIntentCounterEnd")
			stopHardMovementLock()
			removeActiveFrameHighlight()
			context:FinishMove(0)
			return
		end

		if character:GetAttribute("Stunned") or character:GetAttribute("Guardbroken") then
			print("[KillingIntent] Canceled during startup")

			if counterTrack and counterTrack.IsPlaying then
				counterTrack:Stop(0.05)
			end

			character:SetAttribute("Countering", false)
			character:SetAttribute("CounterTriggered", false)
			character:SetAttribute("CounterMoveId", nil)
			character:SetAttribute("CounterAttackName", nil)
			character:SetAttribute("DashLocked", false)
			character:SetAttribute("MovementLocked", false)

			clearCounterAttacker(character)
			removeActiveFrameHighlight()
			playMoveVFX("KillingIntentCounterEnd")
			stopHardMovementLock()
			context:FinishMove(0)

			return
		end

		if not context:IsActive() then
			playMoveVFX("KillingIntentCounterEnd")
			stopHardMovementLock()
			removeActiveFrameHighlight()
			context:FinishMove(0)
			return
		end

		zeroHorizontalVelocity(root)
		task.wait()
	end

	local counterToken = (character:GetAttribute("CounterToken") or 0) + 1
	local attackerValue = getOrCreateCounterAttackerValue(character)
	attackerValue.Value = nil

	character:SetAttribute("Countering", true)
	character:SetAttribute("CounterTriggered", false)
	character:SetAttribute("CounterToken", counterToken)
	character:SetAttribute("CounterMoveId", context.MoveId)
	character:SetAttribute("CounterAttackName", nil)

	addActiveFrameHighlight()

	print("[KillingIntent] Counter window started")

	local finished = false
	local counterConnection

	local function cleanupCounterState()
		removeActiveFrameHighlight()

		if character and character.Parent and character:GetAttribute("CounterToken") == counterToken then
			character:SetAttribute("Countering", false)
			character:SetAttribute("CounterTriggered", false)
			character:SetAttribute("CounterMoveId", nil)
			character:SetAttribute("CounterAttackName", nil)
			clearCounterAttacker(character)
		end
	end

	local function disconnect()
		if counterConnection then
			counterConnection:Disconnect()
			counterConnection = nil
		end
	end

	local function finish(delayTime)
		if finished then
			return
		end

		finished = true
		disconnect()
		cleanupCounterState()

		task.delay(delayTime or 0, function()
			safeSetCounterInvincible(character, false)

			if character and character.Parent then
				character:SetAttribute("DashLocked", false)
				character:SetAttribute("MovementLocked", false)
			end

			playMoveVFX("KillingIntentCounterEnd")
			stopHardMovementLock()
			removeActiveFrameHighlight()
			context:FinishMove(0)
		end)
	end

	local function getStoredAttacker()
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

	local function doCounterHit()
		if finished then
			return
		end

		if not context:IsActive() then
			finish(0)
			return
		end

		if character:GetAttribute("CounterToken") ~= counterToken then
			return
		end

		print("[KillingIntent] Counter triggered")

		local targetCharacter = getStoredAttacker()
		local targetHumanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")
		local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")

		removeActiveFrameHighlight()
		safeSetCounterInvincible(character, true)

		character:SetAttribute("CounterTriggered", true)
		character:SetAttribute("DashLocked", true)
		character:SetAttribute("MovementLocked", true)

		if counterTrack and counterTrack.IsPlaying then
			counterTrack:Stop(0.05)
		end

		local hitTrack = animationService:PlayCharacterAnimation(character, HIT_ANIMATION, 0.03, 1, 1, true)

		if not hitTrack then
			warn("[KillingIntent] Could not play animation:", HIT_ANIMATION)
		end

		playMoveVFX("KillingIntentHit", targetCharacter, targetRoot)
		playCharaSFX("KillingIntentTrigger", root, 2)

		if targetCharacter and targetHumanoid and targetRoot and targetHumanoid.Health > 0 then
			stunAttacker(targetCharacter, ATTACKER_COUNTER_STUN)
			zeroHorizontalVelocity(targetRoot)
		end

		task.wait(HIT_FREEZE_TIME)

		if DOWNSLAM_IMPACT_DELAY > 0 then
			task.wait(DOWNSLAM_IMPACT_DELAY)
		end

		if targetCharacter and targetHumanoid and targetRoot and targetHumanoid.Health > 0 then
			-- KillingIntentHit SFX now plays exactly when the downslam comes out.
			playCharaSFX("KillingIntentHit", targetRoot, 2)

			local counterHitData = {}

			for key, value in pairs(moveData) do
				counterHitData[key] = value
			end

			counterHitData.CanBeBlocked = false
			counterHitData.Unblockable = true
			counterHitData.CanBeCountered = false
			counterHitData.IgnoresIFrames = true
			counterHitData.IgnoresArmor = true
			counterHitData.HitCancelsTarget = true

			counterHitData.KnockbackPreset = "Downslam"
			counterHitData.DownForwardSpeed = moveData.DownForwardSpeed or 10
			counterHitData.DownSpeed = moveData.DownSpeed or -95
			counterHitData.DownLaunchMaxForce = moveData.DownLaunchMaxForce or 90000
			counterHitData.AirStunMax = moveData.AirStunMax or 1.15
			counterHitData.GroundSplatStun = moveData.GroundSplatStun or 0.55
			counterHitData.PostSplatM1Immunity = moveData.PostSplatM1Immunity or 0
			counterHitData.SplatPartLifetime = moveData.SplatPartLifetime or 0.35
			counterHitData.SplatPartSize = moveData.SplatPartSize or Vector3.new(8, 0.25, 8)
			counterHitData.AirAnimationName = "DownslamAir"
			counterHitData.SplatAnimationName = "DownslamSplat"

			local damage = moveData.Damage or 16

			if context.MovementService and context.MovementService.ApplyGroundSplatDownslam then
				context.MovementService:ApplyGroundSplatDownslam(
					root,
					targetCharacter,
					targetHumanoid,
					targetRoot,
					counterHitData,
					{
						StateService = context.StateService,
						VFXService = context.VFXService,
						AttackerCharacter = character,
					},
					"KillingIntentDownslam"
				)
			elseif context.MovementService and context.MovementService.ApplyDownslamKnockback then
				context.MovementService:ApplyDownslamKnockback(
					root,
					targetRoot,
					counterHitData,
					"KillingIntentDownslam"
				)
			end

			if targetHumanoid.Health > 0 then
				targetHumanoid:TakeDamage(damage)

				if context.ReportDamageEvent then
					context:ReportDamageEvent(targetCharacter, damage, targetRoot)
				elseif context.UltService and context.UltService.AwardDamageEvent then
					context.UltService:AwardDamageEvent(character, targetCharacter, damage)
				end
			end

			print("[KillingIntent] Counter hit:", targetCharacter.Name, "Downslam")
		else
			warn("[KillingIntent] Counter triggered but attacker was invalid")
		end

		finish(HIT_FINISH_DELAY)
	end

	counterConnection = character:GetAttributeChangedSignal("CounterTriggered"):Connect(function()
		if character:GetAttribute("CounterTriggered") == true then
			doCounterHit()
		end
	end)

	task.delay(COUNTER_WINDOW, function()
		if finished then
			return
		end

		print("[KillingIntent] Counter whiffed")

		if counterTrack and counterTrack.IsPlaying then
			counterTrack:Stop(0.08)
		end

		finish(WHIFF_ENDLAG)
	end)
end

return KillingIntent
