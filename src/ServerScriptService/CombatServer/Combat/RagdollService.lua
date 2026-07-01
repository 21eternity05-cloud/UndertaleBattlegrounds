local RagdollService = {}
RagdollService.__index = RagdollService

local CONSTRAINT_FOLDER_NAME = "ActiveRagdollConstraints"
local ATTACHMENT_PREFIX_0 = "RagdollAttachment0_"
local ATTACHMENT_PREFIX_1 = "RagdollAttachment1_"
local MOVEMENT_LOCK_TOKEN_ATTRIBUTE = "RagdollMovementLockToken"
local DASH_LOCK_TOKEN_ATTRIBUTE = "RagdollDashLockToken"

function RagdollService.new(config, stateService, movementService)
	local self = setmetatable({}, RagdollService)

	self.Config = config or {}
	self.StateService = stateService
	self.MovementService = movementService
	self.Active = setmetatable({}, { __mode = "k" })

	return self
end

function RagdollService:IsRagdolled(character)
	return character ~= nil and character:GetAttribute("Ragdolled") == true
end

function RagdollService:DestroyConstraintFolder(character)
	local folder = character and character:FindFirstChild(CONSTRAINT_FOLDER_NAME)
	if folder then
		folder:Destroy()
	end
end

function RagdollService:DestroyLooseRagdollAttachments(character)
	if not character then
		return
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Attachment")
			and (
				string.sub(descendant.Name, 1, #ATTACHMENT_PREFIX_0) == ATTACHMENT_PREFIX_0
				or string.sub(descendant.Name, 1, #ATTACHMENT_PREFIX_1) == ATTACHMENT_PREFIX_1
			)
		then
			descendant:Destroy()
		end
	end
end

function RagdollService:CreateJointConstraint(folder, motor)
	if not motor.Part0 or not motor.Part1 then
		return nil
	end

	local attachment0 = Instance.new("Attachment")
	attachment0.Name = ATTACHMENT_PREFIX_0 .. motor.Name
	attachment0.CFrame = motor.C0
	attachment0.Parent = motor.Part0

	local attachment1 = Instance.new("Attachment")
	attachment1.Name = ATTACHMENT_PREFIX_1 .. motor.Name
	attachment1.CFrame = motor.C1
	attachment1.Parent = motor.Part1

	local constraint = Instance.new("BallSocketConstraint")
	constraint.Name = "RagdollConstraint_" .. motor.Name
	constraint.Attachment0 = attachment0
	constraint.Attachment1 = attachment1
	constraint.LimitsEnabled = true
	constraint.UpperAngle = 70
	constraint.TwistLimitsEnabled = true
	constraint.TwistLowerAngle = -45
	constraint.TwistUpperAngle = 45
	constraint.Parent = folder

	return {
		Motor = motor,
		WasEnabled = motor.Enabled,
		Attachment0 = attachment0,
		Attachment1 = attachment1,
	}
end

function RagdollService:BuildConstraints(character)
	self:DestroyConstraintFolder(character)
	self:DestroyLooseRagdollAttachments(character)

	local folder = Instance.new("Folder")
	folder.Name = CONSTRAINT_FOLDER_NAME
	folder.Parent = character

	local motors = {}

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Motor6D")
			and descendant.Part0
			and descendant.Part1
			and descendant.Part0:IsDescendantOf(character)
			and descendant.Part1:IsDescendantOf(character)
		then
			local info = self:CreateJointConstraint(folder, descendant)

			if info then
				table.insert(motors, info)
				descendant.Enabled = false
			end
		end
	end

	if #motors <= 0 then
		folder:Destroy()
		warn("[RagdollService] Skipping ragdoll: no valid Motor6D rig")
		return nil, nil
	end

	return folder, motors
end

function RagdollService:CanRestoreMovement(character)
	return character
		and character.Parent
		and character:GetAttribute("Stunned") ~= true
		and character:GetAttribute("Guardbroken") ~= true
		and character:GetAttribute("Grabbed") ~= true
		and character:GetAttribute("CinematicLocked") ~= true
		and character:GetAttribute("UsingMove") ~= true
		and character:GetAttribute("MovementLocked") ~= true
end

function RagdollService:RecoverHumanoidPhysics(character, humanoid, state)
	if not humanoid or not humanoid.Parent or humanoid.Health <= 0 then
		return
	end

	humanoid.PlatformStand = state and state.PlatformStand == true
	humanoid.AutoRotate = state and state.AutoRotate ~= false

	pcall(function()
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end)

	task.defer(function()
		if not character
			or not character.Parent
			or character:GetAttribute("Ragdolled") == true
			or not humanoid
			or not humanoid.Parent
			or humanoid.Health <= 0
		then
			return
		end

		pcall(function()
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end)
	end)
end

function RagdollService:RestoreOwnedLock(character, attributeName, ownerAttributeName, token, previousValue)
	if not character or not character.Parent then
		return
	end

	if character:GetAttribute(ownerAttributeName) ~= token then
		return
	end

	character:SetAttribute(ownerAttributeName, nil)

	if character:GetAttribute(attributeName) == true then
		character:SetAttribute(attributeName, previousValue == true)
	end
end

function RagdollService:RestoreCharacter(character, state, reason)
	if not character then
		return
	end

	if state then
		for _, connection in ipairs(state.Connections or {}) do
			connection:Disconnect()
		end
		table.clear(state.Connections or {})

		for _, info in ipairs(state.Motors or {}) do
			if info.Motor and info.Motor.Parent then
				info.Motor.Enabled = info.WasEnabled ~= false
			end
			if info.Attachment0 and info.Attachment0.Parent then
				info.Attachment0:Destroy()
			end
			if info.Attachment1 and info.Attachment1.Parent then
				info.Attachment1:Destroy()
			end
		end
	end

	self:DestroyConstraintFolder(character)
	self:DestroyLooseRagdollAttachments(character)

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	character:SetAttribute("Ragdolled", false)
	character:SetAttribute("RagdollReason", nil)
	character:SetAttribute("RagdollType", nil)

	self:RecoverHumanoidPhysics(character, humanoid, state)

	if state then
		if state.MovementLockedByRagdoll then
			self:RestoreOwnedLock(
				character,
				"MovementLocked",
				MOVEMENT_LOCK_TOKEN_ATTRIBUTE,
				state.Token,
				state.PreviousMovementLocked
			)
		end

		if state.DashLockedByRagdoll then
			self:RestoreOwnedLock(
				character,
				"DashLocked",
				DASH_LOCK_TOKEN_ATTRIBUTE,
				state.Token,
				state.PreviousDashLocked
			)
		end
	end

	if humanoid and humanoid.Parent and humanoid.Health > 0 and self:CanRestoreMovement(character) then
		humanoid.WalkSpeed = state and state.WalkSpeed or self.Config.DefaultWalkSpeed or 16
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		humanoid.JumpPower = state and state.JumpPower or self.Config.DefaultJumpPower or 50
		humanoid.JumpHeight = state and state.JumpHeight or self.Config.DefaultJumpHeight or 7.2
	end

	if self.StateService and self.StateService.RefreshHumanoidMovement then
		self.StateService:RefreshHumanoidMovement(character, reason or "RagdollEnded")
	end

	self.Active[character] = nil
end

function RagdollService:CancelRagdoll(character, reason)
	local state = self.Active[character]
	if not state then
		if character then
			character:SetAttribute("Ragdolled", false)
			character:SetAttribute("RagdollReason", nil)
			character:SetAttribute("RagdollType", nil)
			character:SetAttribute(MOVEMENT_LOCK_TOKEN_ATTRIBUTE, nil)
			character:SetAttribute(DASH_LOCK_TOKEN_ATTRIBUTE, nil)
			self:DestroyConstraintFolder(character)
			self:DestroyLooseRagdollAttachments(character)
		end
		return
	end

	self:RestoreCharacter(character, state, reason)
end

function RagdollService:CleanupCharacter(character)
	self:CancelRagdoll(character, "Cleanup")
end

function RagdollService:ApplyRagdoll(character, duration, options)
	if not character or not character.Parent then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then
		return nil
	end

	options = options or {}
	duration = math.max(duration or options.Duration or 1.25, 0.05)

	self:CancelRagdoll(character, "Replaced")

	if options.CancelExistingMovement ~= false and self.MovementService and self.MovementService.ClearCombatMovementControllers then
		self.MovementService:ClearCombatMovementControllers(root)
	end

	local token = (character:GetAttribute("RagdollToken") or 0) + 1
	local folder, motors = self:BuildConstraints(character)
	if not folder or not motors or #motors <= 0 then
		return nil
	end

	local state = {
		Token = token,
		Folder = folder,
		Motors = motors,
		WalkSpeed = humanoid.WalkSpeed,
		JumpPower = humanoid.JumpPower,
		JumpHeight = humanoid.JumpHeight,
		AutoRotate = humanoid.AutoRotate,
		PlatformStand = humanoid.PlatformStand,
		PreviousMovementLocked = character:GetAttribute("MovementLocked") == true,
		PreviousDashLocked = character:GetAttribute("DashLocked") == true,
		MovementLockedByRagdoll = options.MovementLocked ~= false,
		DashLockedByRagdoll = options.DashLocked ~= false,
	}

	self.Active[character] = state

	character:SetAttribute("RagdollToken", token)
	character:SetAttribute("Ragdolled", true)
	character:SetAttribute("RagdollReason", options.Reason or "Ragdoll")
	character:SetAttribute("RagdollType", options.Type or "HardRagdoll")
	character:SetAttribute("Blocking", false)
	character:SetAttribute("BlockHeld", false)
	character:SetAttribute("BlockBufferedUntil", 0)
	character:SetAttribute("BlockBufferToken", (character:GetAttribute("BlockBufferToken") or 0) + 1)

	if state.MovementLockedByRagdoll then
		character:SetAttribute(MOVEMENT_LOCK_TOKEN_ATTRIBUTE, token)
		character:SetAttribute("MovementLocked", true)
	end
	if state.DashLockedByRagdoll then
		character:SetAttribute(DASH_LOCK_TOKEN_ATTRIBUTE, token)
		character:SetAttribute("DashLocked", true)
	end

	humanoid.WalkSpeed = 0
	humanoid.Jump = false
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoRotate = false
	humanoid.PlatformStand = true
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	if options.KnockbackVelocity and typeof(options.KnockbackVelocity) == "Vector3" then
		root.AssemblyLinearVelocity = options.KnockbackVelocity
	end

	local connections = {}
	state.Connections = connections

	table.insert(connections, humanoid.Died:Connect(function()
		self:CleanupCharacter(character)
	end))

	table.insert(connections, character.AncestryChanged:Connect(function(_, parent)
		if parent then
			return
		end

		self:CleanupCharacter(character)
	end))

	task.delay(duration, function()
		if not character or not character.Parent then
			return
		end
		if character:GetAttribute("RagdollToken") ~= token then
			return
		end

		self:CancelRagdoll(character, "Duration")
	end)

	return token
end

return RagdollService
