local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local function loadNPCM1()
	local moduleScript = script.Parent:FindFirstChild("NPCM1")

	if not moduleScript then
		moduleScript = script.Parent:WaitForChild("NPCM1", 5)
	end

	if not moduleScript then
		warn("[DebugDummyController] NPCM1 missing under ServerScriptService/TestTools; dummy M1 support disabled.")
		return nil
	end

	if not moduleScript:IsA("ModuleScript") then
		warn("[DebugDummyController] NPCM1 exists but is not a ModuleScript; dummy M1 support disabled.")
		return nil
	end

	local success, moduleOrError = pcall(require, moduleScript)
	if not success then
		warn("[DebugDummyController] Failed to require NPCM1; dummy M1 support disabled:", moduleOrError)
		return nil
	end

	if typeof(moduleOrError) ~= "table" or typeof(moduleOrError.new) ~= "function" then
		warn("[DebugDummyController] NPCM1 did not return a constructor table; dummy M1 support disabled.")
		return nil
	end

	return moduleOrError
end

local NPCM1 = loadNPCM1()

local DebugDummyController = {}
DebugDummyController.__index = DebugDummyController

local COLLIDABLE_PARTS = {
	Head = true,
	Torso = true,
	HumanoidRootPart = true,
}

function DebugDummyController.new(services)
	local self = setmetatable({}, DebugDummyController)

	self.Services = services or {}
	self.Active = {}
	self.WarnedMissingGreenSound = false

	if NPCM1 then
		self.NPCM1 = NPCM1.new(self.Services.Config or {}, {
			StateService = self.Services.StateService,
			AnimationService = self.Services.AnimationService,
			MovementService = self.Services.MovementService,
			BlockService = self.Services.BlockService,
			VFXService = self.Services.VFXService,
			CounterService = self.Services.CounterService,
			CombatStatusService = self.Services.CombatStatusService,
		})
	else
		self.NPCM1 = nil
	end

	return self
end

function DebugDummyController:GetHumanoidAndRoot(dummy)
	if not dummy then
		return nil, nil
	end

	return dummy:FindFirstChildOfClass("Humanoid"), dummy:FindFirstChild("HumanoidRootPart")
end

function DebugDummyController:Track(dummy, connection)
	local state = self.Active[dummy]
	if not state or not connection then
		return
	end

	table.insert(state.Connections, connection)
end

function DebugDummyController:IsAlive(dummy)
	local state = self.Active[dummy]
	local humanoid, root = self:GetHumanoidAndRoot(dummy)

	return state
		and state.Running == true
		and dummy.Parent ~= nil
		and humanoid ~= nil
		and humanoid.Health > 0
		and root ~= nil
end

function DebugDummyController:Cleanup(dummy)
	local state = self.Active[dummy]
	if not state then
		return
	end

	state.Running = false

	for _, connection in ipairs(state.Connections) do
		if connection and connection.Disconnect then
			connection:Disconnect()
		end
	end

	for _, track in ipairs(state.AnimationTracks) do
		pcall(function()
			track:Stop(0.1)
			track:Destroy()
		end)
	end

	for _, instance in ipairs(state.ManagedInstances or {}) do
		if instance and instance.Parent then
			instance:Destroy()
		end
	end

	self.Active[dummy] = nil
end

function DebugDummyController:ApplyCollisionRules(dummy)
	local morphService = self.Services.CharacterMorphService
	if morphService and morphService.ApplyCharacterCollisionRules then
		morphService:ApplyCharacterCollisionRules(dummy)
	else
		for _, descendant in ipairs(dummy:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.CanCollide = COLLIDABLE_PARTS[descendant.Name] == true
				descendant.CanTouch = descendant.Name == "HumanoidRootPart"
				descendant.CanQuery = true

				if not descendant.CanCollide then
					descendant.Massless = true
				end
			end
		end
	end

	local weaponService = self.Services.WeaponService
	if weaponService and weaponService.SanitizeEquippedWeapons then
		weaponService:SanitizeEquippedWeapons(dummy)
	end
end

function DebugDummyController:PrepareCombatAttributes(dummy, features)
	dummy:SetAttribute("TestDummy", true)
	dummy:SetAttribute("ComboCount", 0)
	dummy:SetAttribute("LastM1Time", 0)
	dummy:SetAttribute("Attacking", false)
	dummy:SetAttribute("Stunned", false)
	dummy:SetAttribute("Guardbroken", false)
	dummy:SetAttribute("Blocking", false)
	dummy:SetAttribute("BlockHeld", features.Block == true)
	dummy:SetAttribute("BlockBufferedUntil", 0)
	dummy:SetAttribute("BlockBufferToken", 0)
	dummy:SetAttribute("BlockLockedUntil", 0)
	dummy:SetAttribute("BlockInputReleasedAfterGuardbreak", true)
	dummy:SetAttribute("UsingMove", false)
	dummy:SetAttribute("MoveToken", 0)
	dummy:SetAttribute("AirComboReady", features.Aircombo == true)
	dummy:SetAttribute("UsedUptiltInCombo", false)
	dummy:SetAttribute("UptiltCooldownUntil", 0)
	dummy:SetAttribute("JumpLockedUntil", 0)
	dummy:SetAttribute("M1ImmuneUntil", 0)
	dummy:SetAttribute("StunId", 0)
	dummy:SetAttribute("Countering", false)
	dummy:SetAttribute("CounterTriggered", false)
	dummy:SetAttribute("CounterToken", 0)
	dummy:SetAttribute("CounterMoveId", nil)
	dummy:SetAttribute("CounterAttackName", nil)

	if features.SOULBURST then
		dummy:SetAttribute("Soul", dummy:GetAttribute("Soul") or 0)
		dummy:SetAttribute("SoulBurst", dummy:GetAttribute("SoulBurst") or 0)
		dummy:SetAttribute("CanSoulBurst", true)
		dummy:SetAttribute("SoulBurstDummy", true)
	end

	if features.TRUE then
		dummy:SetAttribute("TRUEDummy", true)
		dummy:SetAttribute("TrueDummy", true)
	end
end

function DebugDummyController:SetupStats(dummy, humanoid, features)
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false

	if features.Immortal or features.Super then
		humanoid.MaxHealth = math.max(humanoid.MaxHealth, 100000)
		humanoid.Health = humanoid.MaxHealth
	end
end

function DebugDummyController:FaceNearestPlayer(dummy)
	local _, root = self:GetHumanoidAndRoot(dummy)
	if not root then
		return
	end

	local nearestRoot = nil
	local nearestDistance = math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local playerRoot = character and character:FindFirstChild("HumanoidRootPart")

		if humanoid and humanoid.Health > 0 and playerRoot then
			local distance = (playerRoot.Position - root.Position).Magnitude
			if distance < nearestDistance then
				nearestDistance = distance
				nearestRoot = playerRoot
			end
		end
	end

	if not nearestRoot then
		return
	end

	local lookPosition = Vector3.new(nearestRoot.Position.X, root.Position.Y, nearestRoot.Position.Z)
	if (lookPosition - root.Position).Magnitude > 0.05 then
		root.CFrame = CFrame.lookAt(root.Position, lookPosition)
	end
end

function DebugDummyController:RetryBlock(dummy)
	if dummy:GetAttribute("Stunned") == true or dummy:GetAttribute("Guardbroken") == true then
		return
	end

	dummy:SetAttribute("BlockHeld", true)

	if dummy:GetAttribute("Blocking") == true then
		return
	end

	local blockService = self.Services.BlockService
	if blockService and blockService.SetCharacterBlocking then
		blockService:SetCharacterBlocking(dummy, true)
	else
		dummy:SetAttribute("Blocking", true)
	end
end

function DebugDummyController:StartBlockingLoop(dummy)
	task.spawn(function()
		while self:IsAlive(dummy) do
			self:RetryBlock(dummy)
			task.wait(0.2)
		end
	end)
end

function DebugDummyController:GetNearestLivePlayerTarget(position, maxDistance)
	local nearest = nil
	local nearestDistance = maxDistance or math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")

		if character and humanoid and root and humanoid.Health > 0 then
			local distance = (root.Position - position).Magnitude
			if distance <= nearestDistance then
				nearestDistance = distance
				nearest = {
					Player = player,
					Character = character,
					Humanoid = humanoid,
					Root = root,
					Distance = distance,
				}
			end
		end
	end

	return nearest
end

function DebugDummyController:FaceRoot(dummyRoot, targetRoot)
	if not dummyRoot or not targetRoot then
		return
	end

	local lookPosition = Vector3.new(targetRoot.Position.X, dummyRoot.Position.Y, targetRoot.Position.Z)
	if (lookPosition - dummyRoot.Position).Magnitude > 0.05 then
		dummyRoot.CFrame = CFrame.lookAt(dummyRoot.Position, lookPosition)
	end
end

function DebugDummyController:GetGroundedRoamPosition(dummy, root, rawTarget)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { dummy }

	local origin = rawTarget + Vector3.new(0, 35, 0)
	local result = Workspace:Raycast(origin, Vector3.new(0, -120, 0), params)
	if result then
		return result.Position + Vector3.new(0, 2.8, 0)
	end

	return Vector3.new(rawTarget.X, root.Position.Y, rawTarget.Z)
end

function DebugDummyController:StartMovingLoop(dummy)
	task.spawn(function()
		while self:IsAlive(dummy) do
			local humanoid, root = self:GetHumanoidAndRoot(dummy)
			if not humanoid or not root then
				break
			end

			local angle = math.rad(math.random(0, 359))
			local radius = math.random(10, 35)
			local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			local target = self:GetGroundedRoamPosition(dummy, root, root.Position + offset)

			if math.random(1, 4) == 1 then
				humanoid.Jump = true
			end

			humanoid:MoveTo(target)

			local finished = false
			local connection
			connection = humanoid.MoveToFinished:Connect(function()
				finished = true
				if connection then
					connection:Disconnect()
				end
			end)

			local startTime = os.clock()
			while self:IsAlive(dummy) and not finished and os.clock() - startTime < 3.5 do
				task.wait(0.1)
			end

			if connection then
				connection:Disconnect()
			end

			task.wait(math.random(15, 60) / 100)
		end
	end)
end

function DebugDummyController:StartImmortalLoop(dummy)
	local humanoid = dummy:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not self:IsAlive(dummy) then
			if connection then
				connection:Disconnect()
			end
			return
		end

		if humanoid.Health < humanoid.MaxHealth then
			humanoid.Health = humanoid.MaxHealth
		end
	end)

	self:Track(dummy, connection)
end

function DebugDummyController:StartSoulBurstLoop(dummy)
	local soulBurstService = self.Services.SoulBurstService
	local humanoid, root = self:GetHumanoidAndRoot(dummy)
	if not humanoid or not root then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "SoulBurstDummyBillboard"
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 180
	billboard.Size = UDim2.fromOffset(120, 34)
	billboard.StudsOffset = Vector3.new(0, 0, 0)
	billboard.Adornee = root
	billboard.Parent = dummy

	local text = Instance.new("TextLabel")
	text.Name = "SoulText"
	text.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	text.BackgroundTransparency = 0.15
	text.BorderSizePixel = 0
	text.Font = Enum.Font.Arcade
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.TextScaled = true
	text.TextStrokeTransparency = 0
	text.Size = UDim2.fromScale(1, 1)
	text.Parent = billboard

	local state = self.Active[dummy]
	if state then
		table.insert(state.ManagedInstances, billboard)
	end

	local function setSoul(value)
		local maxValue = (self.Services.Config and self.Services.Config.SoulBurstMax)
			or (soulBurstService and soulBurstService.GetMax and soulBurstService:GetMax())
			or 100

		value = math.clamp(value or 0, 0, maxValue)
		dummy:SetAttribute("Soul", value)
		dummy:SetAttribute("SoulBurst", value)
		text.Text = string.format("Soul: %d / %d", math.floor(value), maxValue)
	end

	setSoul(dummy:GetAttribute("Soul") or dummy:GetAttribute("SoulBurst") or 0)

	local lastHealth = humanoid.Health
	self:Track(dummy, humanoid.HealthChanged:Connect(function(newHealth)
		if newHealth < lastHealth then
			local damage = lastHealth - newHealth

			if soulBurstService and soulBurstService.GetSoulBurst and soulBurstService.AwardForHitTaken then
				local previousSoul = soulBurstService:GetSoulBurst(dummy)

				task.defer(function()
					if not dummy or not dummy.Parent then
						return
					end

					local currentSoul = soulBurstService:GetSoulBurst(dummy)

					if currentSoul <= previousSoul then
						soulBurstService:AwardForHitTaken(dummy, damage, 0, {
							AttackType = "SoulBurstDummyDamage",
						})
						currentSoul = soulBurstService:GetSoulBurst(dummy)
					end

					setSoul(currentSoul)
				end)
			else
				local config = self.Services.Config or {}
				local gained = (config.SoulBurstHitGain or 6)
					+ (damage * (config.SoulBurstDamageGainMultiplier or 0.5))
				setSoul((dummy:GetAttribute("Soul") or 0) + gained)
			end
		end

		lastHealth = newHealth
	end))

	task.spawn(function()
		while self:IsAlive(dummy) do
			if soulBurstService
				and dummy:GetAttribute("SoulBurstDummy") == true
				and dummy:GetAttribute("Stunned") == true
			then
				if soulBurstService.GetSoulBurst
					and soulBurstService.GetCost
					and soulBurstService.ActivateSoulBurstForCharacter
					and soulBurstService:GetSoulBurst(dummy) >= soulBurstService:GetCost()
				then
					soulBurstService:ActivateSoulBurstForCharacter(dummy)
				end
			end

			task.wait(0.15)
		end
	end)
end

function DebugDummyController:GetGreenSoundTemplate()
	local sound = script.Parent:FindFirstChild("GREEN")
	if sound and sound:IsA("Sound") then
		return sound
	end

	if not self.WarnedMissingGreenSound then
		self.WarnedMissingGreenSound = true
		warn("[DebugDummyController] Missing ServerScriptService/TestTools/GREEN sound for TRUE dummy.")
	end

	return nil
end

function DebugDummyController:PlayGreenSound(dummy)
	local template = self:GetGreenSoundTemplate()
	local _, root = self:GetHumanoidAndRoot(dummy)
	if not template or not root then
		return
	end

	local sound = template:Clone()
	sound.Parent = root
	sound:Play()
	Debris:AddItem(sound, math.max(sound.TimeLength, 1) + 0.5)
end

function DebugDummyController:StartTrueLoop(dummy)
	local highlight = Instance.new("Highlight")
	highlight.Name = "TRUEHighlight"
	highlight.Adornee = dummy
	highlight.FillTransparency = 0.35
	highlight.OutlineTransparency = 0
	highlight.FillColor = Color3.fromRGB(30, 220, 80)
	highlight.OutlineColor = Color3.fromRGB(210, 255, 220)
	highlight.Parent = dummy

	local state = self.Active[dummy]
	if state then
		table.insert(state.ManagedInstances, highlight)
	end

	local wasStunned = false
	local connection = RunService.Heartbeat:Connect(function()
		if not self:IsAlive(dummy) then
			return
		end

		local stunned = dummy:GetAttribute("Stunned") == true
			or dummy:GetAttribute("Guardbroken") == true
			or dummy:GetAttribute("DamageLocked") == true

		if stunned == wasStunned then
			return
		end

		wasStunned = stunned

		if stunned then
			highlight.FillColor = Color3.fromRGB(230, 40, 45)
			highlight.OutlineColor = Color3.fromRGB(255, 210, 210)
		else
			highlight.FillColor = Color3.fromRGB(30, 220, 80)
			highlight.OutlineColor = Color3.fromRGB(210, 255, 220)
			self:PlayGreenSound(dummy)
		end
	end)

	self:Track(dummy, connection)
end

function DebugDummyController:GetAnimationObject(characterName, animationName)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local characters = assets and assets:FindFirstChild("Characters")
	local characterFolder = characters and characters:FindFirstChild(characterName)
	local animations = characterFolder and characterFolder:FindFirstChild("Animations")
	if not animations then
		return nil
	end

	local animation = animations:FindFirstChild(animationName)
	if animation and animation:IsA("Animation") then
		return animation
	end

	return nil
end

function DebugDummyController:GetAnimator(dummy)
	local humanoid = dummy and dummy:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	return animator
end

function DebugDummyController:LoadAnimationTrack(dummy, characterName, animationName, priority, looped)
	local animation = self:GetAnimationObject(characterName, animationName)
	local animator = animation and self:GetAnimator(dummy)
	if not animation or not animator then
		return nil
	end

	local success, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	if not success or not track then
		return nil
	end

	track.Priority = priority or Enum.AnimationPriority.Action
	track.Looped = looped == true

	local state = self.Active[dummy]
	if state then
		table.insert(state.AnimationTracks, track)
	end

	return track
end

function DebugDummyController:PlayOneShotAnimation(dummy, characterName, animationName)
	local track = self:LoadAnimationTrack(dummy, characterName, animationName, Enum.AnimationPriority.Action, false)
	if track then
		track:Play(0.05)
	end
end

function DebugDummyController:GetM1ActionData(action)
	local config = self.Services.Config or {}
	local m1Data = config.M1Data or {}

	if typeof(action) == "number" then
		return m1Data[action] or {}
	end

	return m1Data[action] or {}
end

function DebugDummyController:GetActionCooldown(action)
	if self.NPCM1 then
		if action == "Uptilt" then
			return self.NPCM1:GetAttackDelay(self.NPCM1:GetUptiltData(), "Uptilt")
		elseif action == "Downslam" then
			return self.NPCM1:GetAttackDelay(self.NPCM1:GetDownslamData(), "Downslam")
		elseif action == "M1" then
			return self.NPCM1:GetM1NextInputDelay(1)
		elseif typeof(action) == "number" then
			return self.NPCM1:GetM1NextInputDelay(action)
		end
	end

	local data = self:GetM1ActionData(action)
	return data.Cooldown or 0.35
end

function DebugDummyController:WaitActionCooldown(dummy, action)
	local cooldown = self:GetActionCooldown(action)
	local startTime = os.clock()

	while self:IsAlive(dummy) and os.clock() - startTime < cooldown do
		if self.NPCM1 and self.NPCM1.ClearDummyAttackStateIfTimedOut then
			self.NPCM1:ClearDummyAttackStateIfTimedOut(dummy)
		end

		task.wait(0.05)
	end
end

function DebugDummyController:RecoverM1StateIfNeeded(dummy)
	if not self.NPCM1 or not self.NPCM1.ClearDummyAttackStateIfTimedOut then
		return false
	end

	return self.NPCM1:ClearDummyAttackStateIfTimedOut(dummy)
end

function DebugDummyController:StartM1Loop(dummy, features, metadata)
	if not self.NPCM1 or not self.NPCM1.SetupNPC or not self.NPCM1.AttemptNormalM1 then
		warn("[DebugDummyController] M1 dummy started without NPCM1 support:", dummy.Name)
		return
	end

	self.NPCM1:SetupNPC(dummy, {
		AirCombo = features.Aircombo == true or features.AirComboNPC == true,
	})

	local comboPause = (self.Services.Config and self.Services.Config.TestDummyComboPause) or 1.5
	local retryDelay = (self.Services.Config and self.Services.Config.TestDummyM1RetryDelay) or 0.12

	task.spawn(function()
		local airStep = 1

		while self:IsAlive(dummy) do
			self:RecoverM1StateIfNeeded(dummy)

			local humanoid, root = self:GetHumanoidAndRoot(dummy)
			if not humanoid or not root then
				break
			end

			if features.Aircombo then
				if not self.NPCM1:CanAttack(dummy) then
					if dummy:GetAttribute("Stunned") == true or dummy:GetAttribute("Guardbroken") == true then
						airStep = 1
						if self.NPCM1.ResetCombo then
							self.NPCM1:ResetCombo(dummy)
						end
					end

					task.wait(retryDelay)
				elseif airStep <= 3 then
					if self.NPCM1:AttemptNormalM1(dummy) then
						self:WaitActionCooldown(dummy, airStep)
						airStep += 1
					else
						task.wait(retryDelay)
					end
				elseif airStep == 4 then
					if self.NPCM1:AttemptUptilt(dummy) then
						self:WaitActionCooldown(dummy, "Uptilt")
						airStep = 5
					else
						task.wait(retryDelay)
					end
				else
					if self.NPCM1:AttemptNormalM1(dummy) then
						self:WaitActionCooldown(dummy, self.NPCM1.GetFinalM1 and self.NPCM1:GetFinalM1() or "M1")

						if self.NPCM1.ResetCombo then
							self.NPCM1:ResetCombo(dummy)
						end

						airStep = 1
						task.wait(comboPause)
					else
						task.wait(retryDelay)
					end
				end
			else
				if self.NPCM1:CanAttack(dummy) then
					local accepted = self.NPCM1:AttemptNormalM1(dummy)

					if accepted then
						self:WaitActionCooldown(dummy, "M1")
					else
						task.wait(retryDelay)
					end
				else
					task.wait(retryDelay)
				end
			end
		end
	end)
end

function DebugDummyController:StartAnimationLoop(dummy, characterName)
	local humanoid = dummy:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local idleAnimation = self:GetAnimationObject(characterName, "Idle")
	local walkAnimation = self:GetAnimationObject(characterName, "Walk")

	if not idleAnimation and not walkAnimation then
		return
	end

	local animator = self:GetAnimator(dummy)
	if not animator then
		return
	end

	local state = self.Active[dummy]
	local idleTrack = idleAnimation and animator:LoadAnimation(idleAnimation) or nil
	local walkTrack = walkAnimation and animator:LoadAnimation(walkAnimation) or nil

	if idleTrack then
		table.insert(state.AnimationTracks, idleTrack)
		idleTrack.Looped = true
		idleTrack.Priority = Enum.AnimationPriority.Idle
		idleTrack:Play(0.1)
	end

	if walkTrack then
		table.insert(state.AnimationTracks, walkTrack)
		walkTrack.Looped = true
		walkTrack.Priority = Enum.AnimationPriority.Movement
	end

	local lastPosition = nil
	local currentState = "Idle"
	local connection = RunService.Heartbeat:Connect(function()
		if not self:IsAlive(dummy) then
			return
		end

		local _, root = self:GetHumanoidAndRoot(dummy)
		local moving = false

		if root then
			local velocity = root.AssemblyLinearVelocity
			local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			local currentPosition = root.Position
			local deltaSpeed = 0

			if lastPosition then
				local delta = currentPosition - lastPosition
				deltaSpeed = Vector3.new(delta.X, 0, delta.Z).Magnitude
			end

			lastPosition = currentPosition
			moving = horizontalSpeed > 0.75 or deltaSpeed > 0.03
		end

		local nextState = moving and "Walk" or "Idle"
		if nextState == currentState then
			return
		end

		currentState = nextState

		if moving then
			if idleTrack and idleTrack.IsPlaying then
				idleTrack:Stop(0.15)
			end
			if walkTrack and not walkTrack.IsPlaying then
				walkTrack:Play(0.15)
			end
		else
			if walkTrack and walkTrack.IsPlaying then
				walkTrack:Stop(0.15)
			end
			if idleTrack and not idleTrack.IsPlaying then
				idleTrack:Play(0.15)
			end
		end
	end)

	self:Track(dummy, connection)
end

function DebugDummyController:Start(dummy, features, metadata)
	if not dummy or not dummy:IsA("Model") then
		return false, "Invalid dummy model."
	end

	local humanoid, root = self:GetHumanoidAndRoot(dummy)
	if not humanoid or not root then
		return false, "Missing Humanoid/root."
	end

	self:Cleanup(dummy)
	self.Active[dummy] = {
		Running = true,
		Connections = {},
		AnimationTracks = {},
		ManagedInstances = {},
	}

	features = features or {}
	metadata = metadata or {}

	self:PrepareCombatAttributes(dummy, features)
	self:SetupStats(dummy, humanoid, features)
	self:ApplyCollisionRules(dummy)

	if self.Services.KillCreditService and self.Services.KillCreditService.SetupDummy then
		self.Services.KillCreditService:SetupDummy(dummy)
	end

	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	self:Track(dummy, humanoid.Died:Connect(function()
		self:Cleanup(dummy)
	end))

	self:Track(dummy, dummy.AncestryChanged:Connect(function(_, parent)
		if not parent then
			self:Cleanup(dummy)
		end
	end))

	if features.M1NPC == true
		or features.Combo == true
		or features.AirComboNPC == true
		or features.Aircombo == true
	then
		self:StartM1Loop(dummy, features, metadata)
	end

	if features.Block then
		self:StartBlockingLoop(dummy)
	end

	if features.Moving then
		self:StartMovingLoop(dummy)
	end

	if features.Immortal or features.Super then
		self:StartImmortalLoop(dummy)
	end

	if features.SOULBURST then
		self:StartSoulBurstLoop(dummy)
	end

	if features.TRUE then
		self:StartTrueLoop(dummy)
	end

	self:StartAnimationLoop(dummy, metadata.CharacterName or dummy:GetAttribute("CharacterName"))
	print("[DebugDummyController] Started behavior:", dummy.Name)
	return true, "Behavior started."
end

return DebugDummyController
