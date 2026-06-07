local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local MovementService = {}
MovementService.__index = MovementService

function MovementService.new(config)
	local self = setmetatable({}, MovementService)

	self.Config = config
	self.ActiveCarryControllers = {}
	self.ActiveYHoldControllers = {}
	self.ActiveCombatKnockbacks = {}
	self.ActiveCollisionChecks = {}
	self.ActiveGroundSplatDownslams = {}

	return self
end

function MovementService:GetDirectionBetween(attackerRoot, targetRoot)
	local direction = targetRoot.Position - attackerRoot.Position

	if direction.Magnitude < 0.1 then
		return attackerRoot.CFrame.LookVector
	end

	return direction.Unit
end

function MovementService:GetFlatDirection(direction, fallback)
	if typeof(direction) ~= "Vector3" then
		direction = fallback or Vector3.new(0, 0, -1)
	end

	local flat = Vector3.new(direction.X, 0, direction.Z)

	if flat.Magnitude < 0.05 then
		flat = fallback or Vector3.new(0, 0, -1)
		flat = Vector3.new(flat.X, 0, flat.Z)
	end

	if flat.Magnitude < 0.05 then
		return Vector3.new(0, 0, -1)
	end

	return flat.Unit
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

function MovementService:StopCollisionCheck(root)
	if self.ActiveCollisionChecks[root] then
		self.ActiveCollisionChecks[root]:Disconnect()
		self.ActiveCollisionChecks[root] = nil
	end
end

function MovementService:StopGroundSplatDownslam(root)
	local active = self.ActiveGroundSplatDownslams[root]

	if not active then
		return
	end

	if active.Connection then
		active.Connection:Disconnect()
	end

	if active.LinearVelocity and active.LinearVelocity.Parent then
		active.LinearVelocity:Destroy()
	end

	if active.Attachment and active.Attachment.Parent then
		active.Attachment:Destroy()
	end

	self.ActiveGroundSplatDownslams[root] = nil
end

function MovementService:ClearCombatMovementControllers(root)
	if not root or not root.Parent then
		return
	end

	self:StopCarryController(root)
	self:StopYHoldController(root)

	if self.StopCollisionCheck then
		self:StopCollisionCheck(root)
	end

	if self.StopGroundSplatDownslam then
		self:StopGroundSplatDownslam(root)
	end

	if self.ActiveCombatKnockbacks and self.ActiveCombatKnockbacks[root] then
		local active = self.ActiveCombatKnockbacks[root]

		if active.LinearVelocity then
			active.LinearVelocity:Destroy()
		end

		if active.Attachment then
			active.Attachment:Destroy()
		end

		self.ActiveCombatKnockbacks[root] = nil
	end

	for _, child in ipairs(root:GetChildren()) do
		if child:IsA("LinearVelocity") or child:IsA("AlignPosition") or child:IsA("VectorForce") then
			local name = child.Name

			if
				name == "CombatKnockbackLinearVelocity"
				or name == "DownslamLinearVelocity"
				or name == "GroundSplatDownslamLinearVelocity"
				or name == "TempAlignPosition"
				or name == "BlueSnareHoldAlign"
				or name == "DummyUptiltAlign"
				or name == "DummyDownslamLinearVelocity"
			then
				child:Destroy()
			end
		elseif child:IsA("Attachment") then
			local name = child.Name

			if
				name == "CombatKnockbackAttachment"
				or name == "DownslamVelocityAttachment"
				or name == "GroundSplatDownslamAttachment"
				or name == "TempAlignAttachment"
				or name == "BlueSnareHoldAttachment"
				or name == "DummyUptiltAttachment"
				or name == "DummyDownslamVelocityAttachment"
			then
				child:Destroy()
			end
		end
	end

	root.AssemblyAngularVelocity = Vector3.zero
end

function MovementService:SetServerOwnershipIfNPC(root)
	if not root or not root.Parent then
		return
	end

	local character = root:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)

	if not player then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
end

function MovementService:IsKnockbackDebugEnabled()
	if self.Config and self.Config.DebugKnockback == true then
		return true
	end

	if workspace:GetAttribute("DebugKnockback") == true then
		return true
	end

	return false
end

function MovementService:GetKnockbackDebugFolder()
	local folder = workspace:FindFirstChild("KnockbackDebug")

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "KnockbackDebug"
		folder.Parent = workspace
	end

	return folder
end

function MovementService:CreateDebugMarker(name, position)
	local marker = Instance.new("Part")
	marker.Name = name
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false
	marker.Transparency = 1
	marker.Size = Vector3.new(0.35, 0.35, 0.35)
	marker.Position = position
	marker.Parent = self:GetKnockbackDebugFolder()

	return marker
end

function MovementService:ShowKnockbackDebug(root, velocity, duration, label)
	if not self:IsKnockbackDebugEnabled() then
		return
	end

	if not root or not root.Parent then
		return
	end

	if typeof(velocity) ~= "Vector3" then
		return
	end

	duration = duration or 0.3

	local startPosition = root.Position
	local endPosition = startPosition + velocity * duration

	local startMarker = self:CreateDebugMarker("KnockbackStart", startPosition)
	local endMarker = self:CreateDebugMarker("KnockbackEnd", endPosition)
	local movingMarker = self:CreateDebugMarker("KnockbackTrail", startPosition)

	local startAttachment = Instance.new("Attachment")
	startAttachment.Parent = startMarker

	local endAttachment = Instance.new("Attachment")
	endAttachment.Parent = endMarker

	local beam = Instance.new("Beam")
	beam.Name = "KnockbackDebugBeam"
	beam.Attachment0 = startAttachment
	beam.Attachment1 = endAttachment
	beam.Width0 = 0.45
	beam.Width1 = 0.22
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 0, 255))
	beam.Parent = startMarker

	local trailAttachment0 = Instance.new("Attachment")
	trailAttachment0.Position = Vector3.new(0, 0.3, 0)
	trailAttachment0.Parent = movingMarker

	local trailAttachment1 = Instance.new("Attachment")
	trailAttachment1.Position = Vector3.new(0, -0.3, 0)
	trailAttachment1.Parent = movingMarker

	local trail = Instance.new("Trail")
	trail.Name = "KnockbackDebugTrail"
	trail.Attachment0 = trailAttachment0
	trail.Attachment1 = trailAttachment1
	trail.Lifetime = 0.4
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 0, 255))
	trail.Transparency = NumberSequence.new(0.05, 1)
	trail.Enabled = true
	trail.Parent = movingMarker

	local orb = Instance.new("Part")
	orb.Name = "KnockbackDebugOrb"
	orb.Shape = Enum.PartType.Ball
	orb.Anchored = true
	orb.CanCollide = false
	orb.CanTouch = false
	orb.CanQuery = false
	orb.Material = Enum.Material.Neon
	orb.Color = Color3.fromRGB(255, 0, 255)
	orb.Size = Vector3.new(0.8, 0.8, 0.8)
	orb.CFrame = CFrame.new(startPosition)
	orb.Parent = self:GetKnockbackDebugFolder()

	if label then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "KnockbackDebugLabel"
		billboard.Size = UDim2.fromOffset(220, 48)
		billboard.StudsOffset = Vector3.new(0, 3, 0)
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = 350
		billboard.Parent = movingMarker

		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Font = Enum.Font.GothamBlack
		text.TextSize = 17
		text.TextColor3 = Color3.fromRGB(255, 150, 255)
		text.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		text.TextStrokeTransparency = 0
		text.Text = label
		text.Parent = billboard
	end

	TweenService:Create(
		movingMarker,
		TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
		{ Position = endPosition }
	):Play()

	TweenService
		:Create(
			orb,
			TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
			{ Position = endPosition }
		)
		:Play()

	Debris:AddItem(startMarker, duration + 1)
	Debris:AddItem(endMarker, duration + 1)
	Debris:AddItem(movingMarker, duration + 1)
	Debris:AddItem(orb, duration + 1)
end

function MovementService:ApplyWallImpactProtection(targetRoot, wallNormal)
	if not targetRoot or not targetRoot.Parent then return end

	local character = targetRoot:FindFirstAncestorOfClass("Model")
	if not character then return end

	local protectionDuration = self.Config.WallImpactProtectionDuration or 0.65
	local protectedUntil = os.clock() + protectionDuration
	local currentProtectedUntil = character:GetAttribute("WallComboProtectedUntil") or 0
	local currentM1ImmuneUntil = character:GetAttribute("M1ImmuneUntil") or 0

	character:SetAttribute("WallComboProtectedUntil", math.max(currentProtectedUntil, protectedUntil))
	character:SetAttribute("M1ImmuneUntil", math.max(currentM1ImmuneUntil, protectedUntil))

	local pushDirection = self:GetFlatDirection(wallNormal, -targetRoot.CFrame.LookVector)
	local pushSpeed = self.Config.WallImpactPushAwaySpeed or 18
	local currentVelocity = targetRoot.AssemblyLinearVelocity

	targetRoot.AssemblyLinearVelocity = (pushDirection * pushSpeed) + Vector3.new(0, currentVelocity.Y, 0)
	targetRoot.AssemblyAngularVelocity = Vector3.zero
end

function MovementService:StartWallImpactCheck(targetRoot, velocity, options)
	if self.Config.WallComboPreventionEnabled ~= true then return end
	if not targetRoot or not targetRoot.Parent then return end
	if typeof(velocity) ~= "Vector3" then return end

	options = options or {}

	local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	local minSpeed = self.Config.WallImpactMinSpeed or 18

	if horizontalVelocity.Magnitude < minSpeed then
		return
	end

	local direction = horizontalVelocity.Unit
	local checkDuration = self.Config.WallImpactCheckDuration or 0.35
	local rayDistance = self.Config.WallImpactRayDistance or 3
	local startTime = os.clock()
	local finished = false

	local exclude = {}
	local targetCharacter = targetRoot:FindFirstAncestorOfClass("Model")
	if targetCharacter then
		table.insert(exclude, targetCharacter)
	end
	if options.AttackerCharacter then
		table.insert(exclude, options.AttackerCharacter)
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude

	local connection
	connection = RunService.Heartbeat:Connect(function()
		if finished then
			connection:Disconnect()
			return
		end
		if not targetRoot or not targetRoot.Parent then
			connection:Disconnect()
			return
		end
		if os.clock() - startTime > checkDuration then
			connection:Disconnect()
			return
		end

		local currentVelocity = targetRoot.AssemblyLinearVelocity
		local currentHorizontalVelocity = Vector3.new(currentVelocity.X, 0, currentVelocity.Z)
		local currentDirection = direction

		if currentHorizontalVelocity.Magnitude >= 1 then
			currentDirection = currentHorizontalVelocity.Unit
		end

		local result = workspace:Raycast(targetRoot.Position, currentDirection * rayDistance, params)
		if not result and os.clock() - startTime > 0.08 and currentHorizontalVelocity.Magnitude < minSpeed then
			result = workspace:Raycast(targetRoot.Position, direction * rayDistance, params)
		end

		if not result then
			return
		end
		if result.Normal.Y > 0.45 then
			return
		end

		finished = true
		connection:Disconnect()

		if self.ActiveCombatKnockbacks and self.ActiveCombatKnockbacks[targetRoot] then
			local active = self.ActiveCombatKnockbacks[targetRoot]

			if active.LinearVelocity and active.LinearVelocity.Parent then
				active.LinearVelocity:Destroy()
			end
			if active.Attachment and active.Attachment.Parent then
				active.Attachment:Destroy()
			end

			self.ActiveCombatKnockbacks[targetRoot] = nil
		end

		self:ApplyWallImpactProtection(targetRoot, result.Normal)
	end)
end

function MovementService:ApplyForceKnockback(targetRoot, velocity, duration, maxForce, debugLabel, options)
	if not targetRoot or not targetRoot.Parent then
		return nil, nil
	end

	if typeof(velocity) ~= "Vector3" then
		return nil, nil
	end

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
	linearVelocity.MaxForce = maxForce or 65000
	linearVelocity.VectorVelocity = velocity
	linearVelocity.Parent = targetRoot

	self.ActiveCombatKnockbacks[targetRoot] = {
		LinearVelocity = linearVelocity,
		Attachment = attachment,
	}

	self:ShowKnockbackDebug(targetRoot, velocity, duration, debugLabel or "Force")

	options = options or {}
	if options.EnableWallComboPrevention == true then
		self:StartWallImpactCheck(targetRoot, velocity, options)
	end

	task.delay(duration, function()
		if
			self.ActiveCombatKnockbacks[targetRoot]
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

function MovementService:ApplyPresetKnockback(attackerRoot, targetRoot, data, debugLabel)
	if not attackerRoot or not attackerRoot.Parent then
		return nil, nil
	end

	if not targetRoot or not targetRoot.Parent then
		return nil, nil
	end

	data = data or {}

	local direction = self:GetFlatDirection(targetRoot.Position - attackerRoot.Position, attackerRoot.CFrame.LookVector)

	local speed = data.PresetKnockbackSpeed or data.KnockbackSpeed or data.Knockback or 48
	local upward = data.PresetKnockbackUpward or data.UpwardKnockback or 28
	local duration = data.PresetKnockbackDuration or data.KnockbackDuration or 0.28
	local maxForce = data.PresetKnockbackMaxForce or data.KnockbackMaxForce or 65000

	local velocity = direction * speed + Vector3.new(0, upward, 0)

	return self:ApplyForceKnockback(
		targetRoot,
		velocity,
		duration,
		maxForce,
		debugLabel or "PresetKnockback",
		{
			EnableWallComboPrevention = true,
			AttackerCharacter = attackerRoot:FindFirstAncestorOfClass("Model"),
		}
	)
end

function MovementService:ShouldUseWallComboPrevention(data)
	if self.Config.WallComboPreventionEnabled ~= true then
		return false
	end
	if not data then
		return false
	end

	return data.WallComboPrevention == true or data.KnockbackPreset == "PresetKnockback"
end

function MovementService:ApplyDirectionalKnockback(attackerRoot, targetRoot, data, debugLabel)
	if not attackerRoot or not attackerRoot.Parent then
		return nil, nil
	end

	if not targetRoot or not targetRoot.Parent then
		return nil, nil
	end

	data = data or {}

	local direction = self:GetFlatDirection(targetRoot.Position - attackerRoot.Position, attackerRoot.CFrame.LookVector)

	local speed = data.DirectionalSpeed or data.HorizontalKnockback or data.Knockback or 38
	local duration = data.DirectionalDuration or data.KnockbackDuration or 0.3
	local maxForce = data.DirectionalMaxForce or data.KnockbackMaxForce or 60000
	local yHoldDuration = data.DirectionalYHoldDuration or data.YHoldDuration or 0

	local velocity = direction * speed
	local wallOptions = nil

	if self:ShouldUseWallComboPrevention(data) then
		wallOptions = {
			EnableWallComboPrevention = true,
			AttackerCharacter = attackerRoot:FindFirstAncestorOfClass("Model"),
		}
	end

	local linearVelocity, attachment =
		self:ApplyForceKnockback(targetRoot, velocity, duration, maxForce, debugLabel or "DirectionalXZ", wallOptions)

	if yHoldDuration and yHoldDuration > 0 then
		self:StartYHold(targetRoot, yHoldDuration)
	end

	if data.StopOnWallHit == true then
		self:StartHorizontalCollisionStop(targetRoot, direction, duration, linearVelocity, attachment)
	end

	return linearVelocity, attachment
end

function MovementService:ApplyStraightKnockback(targetRoot, direction, speed, upward, duration, maxForce, debugLabel)
	local flatDirection = self:GetFlatDirection(direction)
	local velocity = flatDirection * (speed or 38)

	return self:ApplyForceKnockback(
		targetRoot,
		velocity,
		duration or 0.3,
		maxForce or 60000,
		debugLabel or "StraightXZ"
	)
end

function MovementService:ApplyDownslamKnockback(attackerRoot, targetRoot, data, debugLabel)
	if not attackerRoot or not attackerRoot.Parent then
		return nil, nil
	end

	if not targetRoot or not targetRoot.Parent then
		return nil, nil
	end

	data = data or {}

	local forward = self:GetFlatDirection(attackerRoot.CFrame.LookVector)
	local forwardSpeed = data.DownForwardSpeed or data.DownslamForwardSpeed or 28
	local downSpeed = data.DownSpeed or data.DownslamDownSpeed or -72
	local maxForce = data.DownLaunchMaxForce or data.KnockbackMaxForce or 85000

	local velocity = forward * forwardSpeed + Vector3.new(0, downSpeed, 0)

	self:ClearCombatMovementControllers(targetRoot)
	self:SetServerOwnershipIfNPC(targetRoot)

	targetRoot.AssemblyLinearVelocity = Vector3.zero
	targetRoot.AssemblyAngularVelocity = Vector3.zero

	local attachment = Instance.new("Attachment")
	attachment.Name = "DownslamVelocityAttachment"
	attachment.Parent = targetRoot

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "DownslamLinearVelocity"
	linearVelocity.Attachment0 = attachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	linearVelocity.VectorVelocity = velocity
	linearVelocity.MaxForce = maxForce
	linearVelocity.Parent = targetRoot

	self:ShowKnockbackDebug(targetRoot, velocity, data.AirStunMax or 1.5, debugLabel or "Downslam")

	return linearVelocity, attachment
end

function MovementService:ApplyDownslamStyleKnockback(attackerRoot, targetRoot, data)
	return self:ApplyDownslamKnockback(attackerRoot, targetRoot, data, "Downslam")
end

function MovementService:ApplyLinearVelocityUntilStopped(root, velocity, maxForce)
	if not root or not root.Parent then
		return nil, nil
	end

	self:ClearCombatMovementControllers(root)
	self:SetServerOwnershipIfNPC(root)

	local attachment = Instance.new("Attachment")
	attachment.Name = "DownslamVelocityAttachment"
	attachment.Parent = root

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "DownslamLinearVelocity"
	linearVelocity.Attachment0 = attachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	linearVelocity.VectorVelocity = velocity
	linearVelocity.MaxForce = maxForce or 85000
	linearVelocity.Parent = root

	self:ShowKnockbackDebug(root, velocity, 1.25, "LinearUntilStopped")

	return linearVelocity, attachment
end

function MovementService:CreateGroundSplatPart(position, data)
	local part = Instance.new("Part")
	part.Name = "GroundSlamSplatPlaceholder"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 255, 255)
	part.Transparency = 0.4
	part.Size = data.SplatPartSize or Vector3.new(8, 0.25, 8)
	part.CFrame = CFrame.new(position)
	part.Parent = workspace

	Debris:AddItem(part, data.SplatPartLifetime or 0.35)

	return part
end

function MovementService:PlayGroundSplatVFX(targetRoot, groundPosition, services)
	services = services or {}

	local vfxService = services.VFXService

	if not vfxService then
		return
	end

	if vfxService.EmitAttachmentAtWorldPosition then
		vfxService:EmitAttachmentAtWorldPosition(
			"GroundSplatCrack",
			groundPosition + Vector3.new(0, 0.12, 0),
			1.25,
			true
		)
	end

	if vfxService.PlaySFXAtPart then
		vfxService:PlaySFXAtPart("GroundSplat", targetRoot, 3)
	elseif vfxService.PlayCharacterSFXAtPart then
		vfxService:PlayCharacterSFXAtPart("Universal", "GroundSplat", targetRoot, 3)
	end
end

function MovementService:ApplyGroundSplatDownslam(
	attackerRoot,
	targetCharacter,
	targetHumanoid,
	targetRoot,
	data,
	services,
	debugLabel
)
	if not attackerRoot or not attackerRoot.Parent then
		return nil, nil
	end

	if not targetCharacter or not targetCharacter.Parent then
		return nil, nil
	end

	if not targetHumanoid then
		return nil, nil
	end

	if not targetRoot or not targetRoot.Parent then
		return nil, nil
	end

	data = data or {}
	services = services or {}

	self:ClearCombatMovementControllers(targetRoot)
	self:SetServerOwnershipIfNPC(targetRoot)

	local stateService = services.StateService
	local vfxService = services.VFXService

	if stateService and stateService.StunCharacter then
		stateService:StunCharacter(targetCharacter, data.AirStunMax or 1.15, data.AirAnimationName or "DownslamAir")
	end

	if vfxService then
		if vfxService.EmitHitVFXOnVictim and services.AttackerCharacter then
			vfxService:EmitHitVFXOnVictim(targetRoot, services.AttackerCharacter)
		end

		if vfxService.PlaySFXAtPart then
			vfxService:PlaySFXAtPart("DownslamHit", targetRoot, 3)
		elseif vfxService.PlayCharacterSFXAtPart then
			vfxService:PlayCharacterSFXAtPart("Universal", "DownslamHit", targetRoot, 3)
		end
	end

	local forward = self:GetFlatDirection(attackerRoot.CFrame.LookVector)
	local forwardSpeed = data.DownForwardSpeed or data.DownslamForwardSpeed or 10
	local downSpeed = data.DownSpeed or data.DownslamDownSpeed or -95
	local maxForce = data.DownLaunchMaxForce or data.KnockbackMaxForce or 90000

	local velocity = forward * forwardSpeed + Vector3.new(0, downSpeed, 0)

	targetRoot.AssemblyLinearVelocity = Vector3.zero
	targetRoot.AssemblyAngularVelocity = Vector3.zero

	local attachment = Instance.new("Attachment")
	attachment.Name = "GroundSplatDownslamAttachment"
	attachment.Parent = targetRoot

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "GroundSplatDownslamLinearVelocity"
	linearVelocity.Attachment0 = attachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	linearVelocity.VectorVelocity = velocity
	linearVelocity.MaxForce = maxForce
	linearVelocity.Parent = targetRoot

	self.ActiveGroundSplatDownslams[targetRoot] = {
		Connection = nil,
		LinearVelocity = linearVelocity,
		Attachment = attachment,
	}

	self:ShowKnockbackDebug(targetRoot, velocity, data.AirStunMax or 1.15, debugLabel or "GroundSplatDownslam")

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {
		targetCharacter,
		services.AttackerCharacter,
	}

	local startTime = os.clock()
	local maxAirTime = data.AirStunMax or 1.15
	local minAirTime = data.MinAirTime or 0.08
	local groundRayDistance = data.GroundRayDistance or 5
	local finished = false

	local function cleanupVelocity()
		if self.ActiveGroundSplatDownslams[targetRoot] then
			self.ActiveGroundSplatDownslams[targetRoot] = nil
		end

		if linearVelocity and linearVelocity.Parent then
			linearVelocity:Destroy()
		end

		if attachment and attachment.Parent then
			attachment:Destroy()
		end
	end

	local function finishSplat(groundPosition)
		if finished then
			return
		end

		finished = true

		cleanupVelocity()

		if targetRoot and targetRoot.Parent then
			targetRoot.AssemblyLinearVelocity = Vector3.zero
			targetRoot.AssemblyAngularVelocity = Vector3.zero
		end

		local splatPosition = groundPosition

		if not splatPosition and targetRoot and targetRoot.Parent then
			splatPosition = targetRoot.Position - Vector3.new(0, 2.8, 0)
		end

		if splatPosition then
			self:CreateGroundSplatPart(splatPosition + Vector3.new(0, 0.08, 0), data)

			self:PlayGroundSplatVFX(targetRoot, splatPosition, services)
		end

		if stateService and stateService.StunCharacter and targetCharacter and targetCharacter.Parent then
			stateService:StunCharacter(
				targetCharacter,
				data.GroundSplatStun or 0.55,
				data.SplatAnimationName or "DownslamSplat"
			)
		end

		if
			stateService
			and stateService.StunCharacter
			and targetCharacter
			and targetCharacter.Parent
			and targetHumanoid
			and targetHumanoid.Health > 0
		then
			stateService:StunCharacter(
				targetCharacter,
				data.GroundSplatStun or 0.55,
				data.SplatAnimationName or "DownslamSplat"
			)
		end

	end

	local connection
	connection = RunService.Heartbeat:Connect(function()
		if finished then
			connection:Disconnect()
			return
		end

		if not targetCharacter.Parent or not targetRoot.Parent then
			connection:Disconnect()
			cleanupVelocity()
			return
		end

		local elapsed = os.clock() - startTime

		if elapsed >= maxAirTime then
			connection:Disconnect()
			finishSplat(nil)
			return
		end

		if elapsed < minAirTime then
			return
		end

		local result = workspace:Raycast(targetRoot.Position, Vector3.new(0, -groundRayDistance, 0), params)

		if result then
			connection:Disconnect()
			finishSplat(result.Position)
			return
		end
	end)

	self.ActiveGroundSplatDownslams[targetRoot].Connection = connection

	Debris:AddItem(linearVelocity, maxAirTime + 0.25)
	Debris:AddItem(attachment, maxAirTime + 0.25)

	return linearVelocity, attachment
end

function MovementService:StartHorizontalCollisionStop(root, direction, duration, linearVelocity, attachment)
	if not root or not root.Parent then
		return
	end

	self:StopCollisionCheck(root)

	local startTime = os.clock()

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	local character = root:FindFirstAncestorOfClass("Model")
	params.FilterDescendantsInstances = character and { character } or {}

	local connection

	connection = RunService.Heartbeat:Connect(function()
		if not root or not root.Parent then
			connection:Disconnect()
			self.ActiveCollisionChecks[root] = nil
			return
		end

		if os.clock() - startTime >= duration then
			connection:Disconnect()
			self.ActiveCollisionChecks[root] = nil
			return
		end

		local result = workspace:Raycast(root.Position, direction * 2.5, params)

		if result then
			if linearVelocity and linearVelocity.Parent then
				linearVelocity:Destroy()
			end

			if attachment and attachment.Parent then
				attachment:Destroy()
			end

			root.AssemblyLinearVelocity = Vector3.zero

			connection:Disconnect()
			self.ActiveCollisionChecks[root] = nil
		end
	end)

	self.ActiveCollisionChecks[root] = connection
end

function MovementService:StartYHold(root, duration)
	if not root or not root.Parent then
		return
	end

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

		root.AssemblyLinearVelocity = Vector3.new(currentVelocity.X, 0, currentVelocity.Z)
	end)

	self.ActiveYHoldControllers[root] = connection
end

function MovementService:StartM1Carry(attackerRoot, targetRoot, data)
	if not attackerRoot or not attackerRoot.Parent then
		return
	end

	if not targetRoot or not targetRoot.Parent then
		return
	end

	self:StopCarryController(attackerRoot)
	self:StopCarryController(targetRoot)

	local startTime = os.clock()
	local duration = data.CarryDuration or 0.35

	local victimDirection =
		self:GetFlatDirection(targetRoot.Position - attackerRoot.Position, attackerRoot.CFrame.LookVector)

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

		local toVictim = targetRoot.Position - attackerRoot.Position
		local chaseDirection = self:GetFlatDirection(toVictim, victimDirection)

		local attackerHorizontalVelocity = chaseDirection * (data.AttackerChaseSpeed or 22)
		local victimHorizontalVelocity = victimDirection * (data.VictimPushSpeed or 20)

		attackerRoot.AssemblyLinearVelocity = Vector3.new(attackerHorizontalVelocity.X, 0, attackerHorizontalVelocity.Z)

		targetRoot.AssemblyLinearVelocity = Vector3.new(victimHorizontalVelocity.X, 0, victimHorizontalVelocity.Z)
	end)

	self.ActiveCarryControllers[attackerRoot] = connection
	self.ActiveCarryControllers[targetRoot] = connection
end

function MovementService:CreateTempAlignPosition(root, targetPosition, duration, responsiveness, maxForce, maxVelocity)
	if not root or not root.Parent then
		return nil
	end

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
	if not attackerRoot or not attackerRoot.Parent then
		return
	end

	if not targetRoot or not targetRoot.Parent then
		return
	end

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

	local attackerGoal = Vector3.new(attackerStartPosition.X, targetY, attackerStartPosition.Z)

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
		if attackerAlign then
			attackerAlign:Destroy()
		end

		if victimAlign then
			victimAlign:Destroy()
		end

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

return MovementService
