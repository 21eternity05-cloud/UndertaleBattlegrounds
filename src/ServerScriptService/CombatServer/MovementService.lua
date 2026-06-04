local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local MovementService = {}
MovementService.__index = MovementService

function MovementService.new(config)
	local self = setmetatable({}, MovementService)
	self.Config = config
	self.ActiveCarryControllers = {}
	self.ActiveYHoldControllers = {}
	self.ActiveCombatKnockbacks = {}
	return self
end

function MovementService:GetDirectionBetween(attackerRoot, targetRoot)
	local direction = targetRoot.Position - attackerRoot.Position

	if direction.Magnitude < 0.1 then
		return attackerRoot.CFrame.LookVector
	end

	return direction.Unit
end

function MovementService:StopCarryController(root)
	if self.ActiveCarryControllers[root] then
		self.ActiveCarryControllers[root]:Disconnect()
		self.ActiveCarryControllers[root] = nil
	end
end

function MovementService:StopYHoldController(root)
	if self.ActiveYHoldControllers[root] then
		self.ActiveYHoldControllers[root]:Disconnect()
		self.ActiveYHoldControllers[root] = nil
	end
end

function MovementService:ClearCombatMovementControllers(root)
	if not root or not root.Parent then return end

	self:StopCarryController(root)
	self:StopYHoldController(root)

	local active = self.ActiveCombatKnockbacks[root]
	if active then
		if active.LinearVelocity then
			active.LinearVelocity:Destroy()
		end

		if active.Attachment then
			active.Attachment:Destroy()
		end

		self.ActiveCombatKnockbacks[root] = nil
	end

	for _, child in ipairs(root:GetChildren()) do
		if child:IsA("LinearVelocity") and (
			child.Name == "CombatKnockbackLinearVelocity"
			or child.Name == "DownslamLinearVelocity"
			or child.Name == "KnifeDashLinearVelocity"
		) then
			child:Destroy()
		elseif child:IsA("Attachment") and (
			child.Name == "CombatKnockbackAttachment"
			or child.Name == "DownslamVelocityAttachment"
			or child.Name == "KnifeDashVelocityAttachment"
		) then
			child:Destroy()
		end
	end
end

function MovementService:SetServerOwnershipIfNPC(root)
	if not root or not root.Parent then return end

	local character = root:FindFirstAncestorOfClass("Model")
	local player = character and game.Players:GetPlayerFromCharacter(character)

	if not player then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
end

function MovementService:ApplyForceKnockback(targetRoot, velocity, duration, maxForce)
	if not targetRoot or not targetRoot.Parent then return nil, nil end
	if typeof(velocity) ~= "Vector3" then return nil, nil end

	duration = duration or 0.22

	self:ClearCombatMovementControllers(targetRoot)
	self:SetServerOwnershipIfNPC(targetRoot)

	targetRoot.AssemblyLinearVelocity = Vector3.zero
	targetRoot.AssemblyAngularVelocity = Vector3.zero

	local attachment = Instance.new("Attachment")
	attachment.Name = "CombatKnockbackAttachment"
	attachment.Parent = targetRoot

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "CombatKnockbackLinearVelocity"
	linearVelocity.Attachment0 = attachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	linearVelocity.MaxForce = maxForce or 120000
	linearVelocity.VectorVelocity = velocity
	linearVelocity.Parent = targetRoot

	self.ActiveCombatKnockbacks[targetRoot] = {
		LinearVelocity = linearVelocity,
		Attachment = attachment,
	}

	task.delay(duration, function()
		if self.ActiveCombatKnockbacks[targetRoot]
			and self.ActiveCombatKnockbacks[targetRoot].LinearVelocity == linearVelocity
		then
			self.ActiveCombatKnockbacks[targetRoot] = nil
		end

		if linearVelocity and linearVelocity.Parent then
			linearVelocity:Destroy()
		end

		if attachment and attachment.Parent then
			attachment:Destroy()
		end
	end)

	Debris:AddItem(linearVelocity, duration + 0.2)
	Debris:AddItem(attachment, duration + 0.2)

	return linearVelocity, attachment
end

function MovementService:ApplyStraightKnockback(targetRoot, direction, speed, upward, duration, maxForce)
	if typeof(direction) ~= "Vector3" then return nil, nil end

	local flatDirection = Vector3.new(direction.X, 0, direction.Z)

	if flatDirection.Magnitude < 0.05 then
		flatDirection = Vector3.new(0, 0, -1)
	else
		flatDirection = flatDirection.Unit
	end

	local velocity = (flatDirection * (speed or 80)) + Vector3.new(0, upward or 0, 0)
	return self:ApplyForceKnockback(targetRoot, velocity, duration, maxForce)
end

function MovementService:ApplyDirectionalKnockback(attackerRoot, targetRoot, data)
	if not attackerRoot or not attackerRoot.Parent then return nil, nil end
	if not targetRoot or not targetRoot.Parent then return nil, nil end

	data = data or {}

	local direction = self:GetDirectionBetween(attackerRoot, targetRoot)

	return self:ApplyStraightKnockback(
		targetRoot,
		direction,
		data.Speed or data.Knockback or 80,
		data.Upward or data.UpwardKnockback or 0,
		data.Duration or data.KnockbackDuration or 0.22,
		data.MaxForce or data.KnockbackMaxForce or 120000
	)
end

function MovementService:ApplyDownslamStyleKnockback(attackerRoot, targetRoot, data)
	if not attackerRoot or not attackerRoot.Parent then return nil, nil end
	if not targetRoot or not targetRoot.Parent then return nil, nil end

	data = data or {}

	local forward = attackerRoot.CFrame.LookVector
	local flatForward = Vector3.new(forward.X, 0, forward.Z)

	if flatForward.Magnitude < 0.05 then
		flatForward = Vector3.new(0, 0, -1)
	else
		flatForward = flatForward.Unit
	end

	local velocity =
		(flatForward * (data.ForwardSpeed or data.DownForwardSpeed or 75))
		+ Vector3.new(0, data.DownSpeed or data.Upward or -90, 0)

	return self:ApplyForceKnockback(
		targetRoot,
		velocity,
		data.Duration or data.KnockbackDuration or 0.35,
		data.MaxForce or data.DownLaunchMaxForce or data.KnockbackMaxForce or 120000
	)
end

function MovementService:StartYHold(root, duration)
	if not root or not root.Parent then return end

	self:StopYHoldController(root)

	local startTime = os.clock()

	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not root.Parent then
			connection:Disconnect()
			self.ActiveYHoldControllers[root] = nil
			return
		end

		local elapsed = os.clock() - startTime

		if elapsed >= duration then
			connection:Disconnect()
			self.ActiveYHoldControllers[root] = nil
			return
		end

		local currentVelocity = root.AssemblyLinearVelocity

		root.AssemblyLinearVelocity = Vector3.new(
			currentVelocity.X,
			0,
			currentVelocity.Z
		)
	end)

	self.ActiveYHoldControllers[root] = connection
end

function MovementService:StartM1Carry(attackerRoot, targetRoot, data)
	if not attackerRoot or not attackerRoot.Parent then return end
	if not targetRoot or not targetRoot.Parent then return end

	self:StopCarryController(attackerRoot)
	self:StopCarryController(targetRoot)

	local startTime = os.clock()
	local duration = data.CarryDuration or 0.35

	local victimDirection = self:GetDirectionBetween(attackerRoot, targetRoot)
	victimDirection = Vector3.new(victimDirection.X, 0, victimDirection.Z)

	if victimDirection.Magnitude < 0.05 then
		victimDirection = attackerRoot.CFrame.LookVector
	else
		victimDirection = victimDirection.Unit
	end

	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not attackerRoot.Parent or not targetRoot.Parent then
			connection:Disconnect()
			self.ActiveCarryControllers[attackerRoot] = nil
			self.ActiveCarryControllers[targetRoot] = nil
			return
		end

		local elapsed = os.clock() - startTime

		if elapsed >= duration then
			connection:Disconnect()
			self.ActiveCarryControllers[attackerRoot] = nil
			self.ActiveCarryControllers[targetRoot] = nil
			return
		end

		local attackerPos = attackerRoot.Position
		local targetPos = targetRoot.Position

		local toVictim = targetPos - attackerPos
		local chaseDirection = Vector3.new(toVictim.X, 0, toVictim.Z)

		if chaseDirection.Magnitude < 0.05 then
			chaseDirection = victimDirection
		else
			chaseDirection = chaseDirection.Unit
		end

		local attackerHorizontalVelocity =
			chaseDirection * (data.AttackerChaseSpeed or 22)

		local victimHorizontalVelocity =
			victimDirection * (data.VictimPushSpeed or 20)

		attackerRoot.AssemblyLinearVelocity = Vector3.new(
			attackerHorizontalVelocity.X,
			0,
			attackerHorizontalVelocity.Z
		)

		targetRoot.AssemblyLinearVelocity = Vector3.new(
			victimHorizontalVelocity.X,
			0,
			victimHorizontalVelocity.Z
		)
	end)

	self.ActiveCarryControllers[attackerRoot] = connection
	self.ActiveCarryControllers[targetRoot] = connection
end

function MovementService:CreateTempAlignPosition(root, targetPosition, duration, responsiveness, maxForce, maxVelocity)
	if not root or not root.Parent then return nil end

	local attachment = Instance.new("Attachment")
	attachment.Name = "TempAlignAttachment"
	attachment.Parent = root

	local alignPosition = Instance.new("AlignPosition")
	alignPosition.Name = "TempAlignPosition"
	alignPosition.Attachment0 = attachment
	alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
	alignPosition.Position = targetPosition
	alignPosition.RigidityEnabled = false
	alignPosition.ReactionForceEnabled = false
	alignPosition.ApplyAtCenterOfMass = true
	alignPosition.Responsiveness = responsiveness or 35
	alignPosition.MaxForce = maxForce or 100000
	alignPosition.MaxVelocity = maxVelocity or 55
	alignPosition.Parent = root

	Debris:AddItem(alignPosition, duration)
	Debris:AddItem(attachment, duration)

	return alignPosition
end

function MovementService:StartUptiltCarry(attackerRoot, targetRoot, data)
	if not attackerRoot or not attackerRoot.Parent then return end
	if not targetRoot or not targetRoot.Parent then return end

	self:StopCarryController(attackerRoot)
	self:StopCarryController(targetRoot)
	self:StopYHoldController(attackerRoot)
	self:StopYHoldController(targetRoot)

	attackerRoot.AssemblyLinearVelocity = Vector3.zero
	targetRoot.AssemblyLinearVelocity = Vector3.zero

	local duration = data.LiftDuration or 0.85

	local attackerStartPosition = attackerRoot.Position
	local targetY = attackerStartPosition.Y + (data.LiftHeight or 20)

	local startingOffset = targetRoot.Position - attackerRoot.Position
	local horizontalOffset = Vector3.new(startingOffset.X, 0, startingOffset.Z)

	if horizontalOffset.Magnitude < (data.MinHorizontalSpacing or 4) then
		horizontalOffset = attackerRoot.CFrame.LookVector * (data.MinHorizontalSpacing or 4)
	end

	local attackerGoal = Vector3.new(
		attackerStartPosition.X,
		targetY,
		attackerStartPosition.Z
	)

	local victimGoal = attackerGoal + horizontalOffset

	local attackerAlign = self:CreateTempAlignPosition(
		attackerRoot,
		attackerGoal,
		duration,
		data.UptiltResponsiveness,
		data.UptiltMaxForce,
		data.UptiltMaxVelocity
	)

	local victimAlign = self:CreateTempAlignPosition(
		targetRoot,
		victimGoal,
		duration,
		data.UptiltResponsiveness,
		data.UptiltMaxForce,
		data.UptiltMaxVelocity
	)

	task.delay(duration, function()
		if attackerAlign then attackerAlign:Destroy() end
		if victimAlign then victimAlign:Destroy() end

		if attackerRoot and attackerRoot.Parent then
			attackerRoot.AssemblyLinearVelocity = Vector3.zero
			self:StartYHold(attackerRoot, data.PostLiftYHold or 0.5)
		end

		if targetRoot and targetRoot.Parent then
			targetRoot.AssemblyLinearVelocity = Vector3.zero
			self:StartYHold(targetRoot, data.PostLiftYHold or 0.5)
		end
	end)
end

function MovementService:ApplyLinearVelocityUntilStopped(root, velocity, maxForce)
	if not root or not root.Parent then return nil, nil end

	self:ClearCombatMovementControllers(root)
	self:SetServerOwnershipIfNPC(root)

	local attachment = Instance.new("Attachment")
	attachment.Name = "DownslamVelocityAttachment"
	attachment.Parent = root

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "DownslamLinearVelocity"
	linearVelocity.Attachment0 = attachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.VectorVelocity = velocity
	linearVelocity.MaxForce = maxForce or 100000
	linearVelocity.Parent = root

	return linearVelocity, attachment
end

return MovementService
