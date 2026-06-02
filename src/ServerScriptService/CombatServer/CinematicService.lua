local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local CinematicService = {}
CinematicService.__index = CinematicService

function CinematicService.new(config)
	local self = setmetatable({}, CinematicService)

	self.Config = config
	self.Remote = nil

	return self
end

function CinematicService:Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local remote = remotes:FindFirstChild("CinematicRemote")

	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "CinematicRemote"
		remote.Parent = remotes
	end

	self.Remote = remote
end

function CinematicService:GetRemote()
	if self.Remote then
		return self.Remote
	end

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local remote = remotes:FindFirstChild("CinematicRemote")

	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "CinematicRemote"
		remote.Parent = remotes
	end

	self.Remote = remote
	return remote
end

function CinematicService:GetPlayerFromCharacter(character)
	if not character then return nil end
	return Players:GetPlayerFromCharacter(character)
end

function CinematicService:GetHumanoidAndRoot(character)
	if not character then return nil, nil end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	return humanoid, root
end

function CinematicService:FireCamera(character, payload)
	local player = self:GetPlayerFromCharacter(character)
	if not player then return end

	self:GetRemote():FireClient(player, payload)
end

function CinematicService:SetCamera(character, cframe)
	self:FireCamera(character, {
		Action = "SetCamera",
		CFrame = cframe,
	})
end

function CinematicService:TweenCamera(character, cframe, tweenTime)
	self:FireCamera(character, {
		Action = "TweenCamera",
		CFrame = cframe,
		Time = tweenTime or 0.25,
	})
end

function CinematicService:ResetCamera(character)
	self:FireCamera(character, {
		Action = "ResetCamera",
	})
end

function CinematicService:ZeroVelocity(root)
	if not root or not root.Parent then return end

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

function CinematicService:ZeroHorizontalVelocity(root)
	if not root or not root.Parent then return end

	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)
	root.AssemblyAngularVelocity = Vector3.zero
end

function CinematicService:SetCharacterCollision(character, canCollide)
	if not character then return end

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = canCollide == true
		end
	end
end

function CinematicService:SetTemporaryCombatStatus(character, data)
	if not character then return end

	if data.IFrameActive ~= nil then
		character:SetAttribute("IFrameActive", data.IFrameActive == true)
	end

	if data.ArmorActive ~= nil then
		character:SetAttribute("ArmorActive", data.ArmorActive == true)
	end

	if data.ArmorDamageReduction ~= nil then
		character:SetAttribute("ArmorDamageReduction", data.ArmorDamageReduction)
	end

	if data.ArmorPreventsStun ~= nil then
		character:SetAttribute("ArmorPreventsStun", data.ArmorPreventsStun == true)
	end

	if data.ArmorPreventsKnockback ~= nil then
		character:SetAttribute("ArmorPreventsKnockback", data.ArmorPreventsKnockback == true)
	end

	if data.ArmorPreventsHitCancel ~= nil then
		character:SetAttribute("ArmorPreventsHitCancel", data.ArmorPreventsHitCancel == true)
	end
end

function CinematicService:ClearTemporaryCombatStatus(character)
	if not character then return end

	character:SetAttribute("IFrameActive", false)
	character:SetAttribute("ArmorActive", false)
	character:SetAttribute("ArmorDamageReduction", 0)
	character:SetAttribute("ArmorPreventsStun", false)
	character:SetAttribute("ArmorPreventsKnockback", false)
	character:SetAttribute("ArmorPreventsHitCancel", false)
end

function CinematicService:LockCharacter(character, options)
	options = options or {}

	local humanoid, root = self:GetHumanoidAndRoot(character)
	if not humanoid or not root then return nil end

	local state = {
		Character = character,
		Humanoid = humanoid,
		Root = root,

		WalkSpeed = humanoid.WalkSpeed,
		JumpPower = humanoid.JumpPower,
		JumpHeight = humanoid.JumpHeight,
		AutoRotate = humanoid.AutoRotate,
		Anchored = root.Anchored,
	}

	character:SetAttribute("CinematicLocked", true)

	if options.IsGrabber then
		character:SetAttribute("Grabbing", true)
	end

	if options.IsVictim then
		character:SetAttribute("Grabbed", true)
	end

	character:SetAttribute("Blocking", false)

	humanoid.WalkSpeed = 0
	humanoid.Jump = false
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoRotate = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	self:ZeroVelocity(root)

	if options.AnchorRoot then
		root.Anchored = true
	end

	if options.DisableCollision ~= false then
		self:SetCharacterCollision(character, false)
	end

	return state
end

function CinematicService:UnlockCharacter(state)
	if not state then return end

	local character = state.Character
	local humanoid = state.Humanoid
	local root = state.Root

	if not character or not character.Parent then return end

	character:SetAttribute("CinematicLocked", false)
	character:SetAttribute("Grabbing", false)
	character:SetAttribute("Grabbed", false)

	if root and root.Parent then
		root.Anchored = state.Anchored == true
		self:ZeroVelocity(root)
	end

	self:SetCharacterCollision(character, true)
	self:ClearTemporaryCombatStatus(character)

	if not humanoid or not humanoid.Parent then return end

	humanoid.WalkSpeed = state.WalkSpeed or self.Config.DefaultWalkSpeed or 16
	humanoid.JumpPower = state.JumpPower or self.Config.DefaultJumpPower or 50
	humanoid.JumpHeight = state.JumpHeight or self.Config.DefaultJumpHeight or 7.2
	humanoid.AutoRotate = state.AutoRotate ~= false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
end

function CinematicService:StartForwardDrift(root, speed, maxForce)
	if not root or not root.Parent then return nil end

	local attachment = Instance.new("Attachment")
	attachment.Name = "CinematicForwardDriftAttachment"
	attachment.Parent = root

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "CinematicForwardDriftVelocity"
	linearVelocity.Attachment0 = attachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.MaxForce = maxForce or 65000
	linearVelocity.Parent = root

	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not root or not root.Parent then
			if connection then
				connection:Disconnect()
			end

			return
		end

		local look = root.CFrame.LookVector
		local flatLook = Vector3.new(look.X, 0, look.Z)

		if flatLook.Magnitude < 0.05 then
			flatLook = Vector3.new(0, 0, -1)
		else
			flatLook = flatLook.Unit
		end

		linearVelocity.VectorVelocity = flatLook * (speed or 8)
	end)

	local function cleanup()
		if connection then
			connection:Disconnect()
			connection = nil
		end

		if linearVelocity then
			linearVelocity:Destroy()
			linearVelocity = nil
		end

		if attachment then
			attachment:Destroy()
			attachment = nil
		end
	end

	Debris:AddItem(linearVelocity, 2)
	Debris:AddItem(attachment, 2)

	return cleanup
end

function CinematicService:PositionVictimInFront(attackerRoot, victimRoot, distance)
	if not attackerRoot or not victimRoot then return end

	local attackerPosition = attackerRoot.Position
	local forward = attackerRoot.CFrame.LookVector
	forward = Vector3.new(forward.X, 0, forward.Z)

	if forward.Magnitude < 0.05 then
		forward = Vector3.new(0, 0, -1)
	else
		forward = forward.Unit
	end

	local victimPosition = attackerPosition + (forward * (distance or 3.8))

	attackerRoot.CFrame = CFrame.lookAt(attackerPosition, victimPosition)
	victimRoot.CFrame = CFrame.lookAt(victimPosition, attackerPosition)

	self:ZeroVelocity(attackerRoot)
	self:ZeroVelocity(victimRoot)
end

function CinematicService:TeleportAttackerBehindVictim(attackerRoot, victimRoot, distance)
	if not attackerRoot or not victimRoot then return end

	local victimPosition = victimRoot.Position
	local victimLook = victimRoot.CFrame.LookVector
	victimLook = Vector3.new(victimLook.X, 0, victimLook.Z)

	if victimLook.Magnitude < 0.05 then
		victimLook = Vector3.new(0, 0, -1)
	else
		victimLook = victimLook.Unit
	end

	local attackerPosition = victimPosition - (victimLook * (distance or 3.5))

	attackerRoot.CFrame = CFrame.lookAt(attackerPosition, victimPosition)
	victimRoot.CFrame = CFrame.lookAt(victimPosition, attackerPosition)

	self:ZeroVelocity(attackerRoot)
	self:ZeroVelocity(victimRoot)
end

function CinematicService:GetStartCameraCFrame(attackerRoot, victimRoot)
	local victimPosition = victimRoot.Position
	local charaPosition = attackerRoot.Position

	local victimLook = victimRoot.CFrame.LookVector
	local victimRight = victimRoot.CFrame.RightVector

	local cameraPosition =
		victimPosition
		+ (-victimRight * 4.2)
		+ (-victimLook * 7.2)
		+ Vector3.new(0, 3.4, 0)

	return CFrame.lookAt(cameraPosition, charaPosition + Vector3.new(0, 1.7, 0))
end

function CinematicService:GetFirstSlashCameraCFrame(attackerRoot)
	local attackerPosition = attackerRoot.Position
	local attackerLook = attackerRoot.CFrame.LookVector

	local cameraPosition =
		attackerPosition
		+ (attackerLook * 6.2)
		+ Vector3.new(0, 3.6, 0)

	return CFrame.lookAt(cameraPosition, attackerPosition + Vector3.new(0, 1.8, 0))
end

function CinematicService:EraseCharacter(character, restoreDelay)
	if not character or not character.Parent then return end

	local humanoid, root = self:GetHumanoidAndRoot(character)

	local savedVisuals = {}

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			savedVisuals[descendant] = {
				Transparency = descendant.Transparency,
				CanCollide = descendant.CanCollide,
				CanTouch = descendant.CanTouch,
				CanQuery = descendant.CanQuery,
			}

			descendant.Transparency = 1
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			savedVisuals[descendant] = {
				Transparency = descendant.Transparency,
			}

			descendant.Transparency = 1
		elseif descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") or descendant:IsA("Beam") then
			savedVisuals[descendant] = {
				Enabled = descendant.Enabled,
			}

			descendant.Enabled = false
		end
	end

	character:SetAttribute("CinematicLocked", false)
	character:SetAttribute("Grabbed", false)
	character:SetAttribute("Grabbing", false)

	if root and root.Parent then
		root.Anchored = false
		self:ZeroVelocity(root)
	end

	self:ClearTemporaryCombatStatus(character)

	local player = game:GetService("Players"):GetPlayerFromCharacter(character)

	if player then
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = 0
		end
	else
		-- Test dummy / NPC: fake erase instead of permanent death.
		if humanoid then
			humanoid.Health = math.max(1, humanoid.Health)
		end
	end

	task.delay(restoreDelay or 2, function()
		if not character or not character.Parent then return end

		for instance, data in pairs(savedVisuals) do
			if instance and instance.Parent then
				if instance:IsA("BasePart") then
					instance.Transparency = data.Transparency
					instance.CanCollide = data.CanCollide
					instance.CanTouch = data.CanTouch
					instance.CanQuery = data.CanQuery
				elseif instance:IsA("Decal") or instance:IsA("Texture") then
					instance.Transparency = data.Transparency
				elseif instance:IsA("ParticleEmitter") or instance:IsA("Trail") or instance:IsA("Beam") then
					instance.Enabled = data.Enabled
				end
			end
		end

		local currentHumanoid, currentRoot = self:GetHumanoidAndRoot(character)

		if currentRoot and currentRoot.Parent then
			currentRoot.Anchored = false
		end

		if currentHumanoid then
			currentHumanoid.Health = currentHumanoid.MaxHealth
			currentHumanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end

		self:SetCharacterCollision(character, true)
	end)
end

function CinematicService:IsValidGrabTarget(ctx, targetCharacter, targetHumanoid, targetRoot, grabData)
	if not targetCharacter or not targetCharacter.Parent then return false end
	if not targetHumanoid or targetHumanoid.Health <= 0 then return false end
	if not targetRoot or not targetRoot.Parent then return false end
	if targetCharacter == ctx.Character then return false end

	if targetCharacter:GetAttribute("CinematicLocked") then return false end
	if targetCharacter:GetAttribute("Grabbed") then return false end

	if ctx.CombatStatusService then
		if grabData.CanGrabIFrame ~= true and ctx.CombatStatusService:HasIFrames(targetCharacter, grabData) then
			return false
		end

		local armorInfo = ctx.CombatStatusService:GetArmorInfo(targetCharacter, grabData)

		if grabData.CanGrabArmored ~= true and armorInfo.Active then
			return false
		end
	end

	return true
end

return CinematicService