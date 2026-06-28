local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local soulBurstRemote = remotes:WaitForChild("SoulBurstRemote")
local emoteRemote = remotes:WaitForChild("EmoteRemote")

local DASH_KEY = Enum.KeyCode.Q

local DASH_DURATION = 0.28
local DASH_SPEED = 82
local DASH_COOLDOWN = 1.1

local DASH_MAX_FORCE = 80000
local TURN_SPEED = 20
local STEERING_TIME = 0.22

local WALL_CHECK_DISTANCE = 2.9
local WALL_CHECK_FRAME_INTERVAL = 2
local POST_DASH_MAX_HORIZONTAL_SPEED = 48
local DASH_TRAIL_ACTIVE_TIME = DASH_DURATION + 0.04
local DASH_TRAIL_LIFETIME = 0.22
local DASH_TRAIL_CLEANUP_BUFFER = 0.05
local DASH_TRAIL_FAILSAFE_TIME = 0.8
local DASH_TRAIL_LIMBS = {
	"Left Arm",
	"Right Arm",
	"Left Leg",
	"Right Leg",
}

local canDash = true
local isDashing = false
local wallRaycastParams = RaycastParams.new()
wallRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
local wallRaycastFilterCharacter = nil

local function getCharacter()
	local character = player.Character
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not root or humanoid.Health <= 0 then
		return nil
	end

	return character, humanoid, root
end

local function isDashLocked(character)
	if not character then
		return true
	end

	if character:GetAttribute("DashLocked") then
		return true
	end

	if character:GetAttribute("MovementLocked") then
		return true
	end

	if character:GetAttribute("SpawnSetupActive") then
		return true
	end

	if character:GetAttribute("CharacterSwitchDebounce") then
		return true
	end

	if character:GetAttribute("Morphing") then
		return true
	end

	if character:GetAttribute("IntroLocked") then
		return true
	end

	if character:GetAttribute("Emoting") then
		return true
	end

	if character:GetAttribute("UsingMove") and character:GetAttribute("MovementLocked") then
		return true
	end

	return false
end

local function canDashNow(character, humanoid, root)
	if not character or not character.Parent then
		return false
	end

	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	if not root or not root.Parent then
		return false
	end

	if character:GetAttribute("Stunned") then
		return false
	end

	if character:GetAttribute("Guardbroken") then
		return false
	end

	if isDashLocked(character) then
		return false
	end

	return true
end

local function getFlatCameraCFrame()
	local camera = workspace.CurrentCamera

	if not camera then
		return CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, -1))
	end

	local look = camera.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)

	if flatLook.Magnitude < 0.05 then
		flatLook = Vector3.new(0, 0, -1)
	end

	flatLook = flatLook.Unit

	return CFrame.lookAt(Vector3.zero, flatLook)
end

local function getDashType()
	local wHeld = UserInputService:IsKeyDown(Enum.KeyCode.W)
	local aHeld = UserInputService:IsKeyDown(Enum.KeyCode.A)
	local sHeld = UserInputService:IsKeyDown(Enum.KeyCode.S)
	local dHeld = UserInputService:IsKeyDown(Enum.KeyCode.D)

	if sHeld then
		return "Back"
	end

	if wHeld then
		return "Forward"
	end

	if aHeld then
		return "Left"
	end

	if dHeld then
		return "Right"
	end

	return "Back"
end

local function getDirectionFromDashType(dashType)
	local cameraCFrame = getFlatCameraCFrame()

	local forward = cameraCFrame.LookVector
	local right = cameraCFrame.RightVector

	if dashType == "Forward" then
		return forward
	elseif dashType == "Back" then
		return -forward
	elseif dashType == "Left" then
		return -right
	elseif dashType == "Right" then
		return right
	end

	return -forward
end

local function getFlatDirection(direction)
	local flat = Vector3.new(direction.X, 0, direction.Z)

	if flat.Magnitude < 0.05 then
		return Vector3.new(0, 0, -1)
	end

	return flat.Unit
end

local function createDashLimbTrails(character)
	if not character or not character.Parent then
		return nil
	end

	local createdObjects = {}
	local cleanedUp = false

	for _, limbName in ipairs(DASH_TRAIL_LIMBS) do
		local limb = character:FindFirstChild(limbName)
		if limb and limb:IsA("BasePart") then
			local upperAttachment = Instance.new("Attachment")
			upperAttachment.Name = "DashTrailAttachmentA"
			upperAttachment.Position = Vector3.new(0, limb.Size.Y * 0.45, 0)
			upperAttachment.Parent = limb

			local lowerAttachment = Instance.new("Attachment")
			lowerAttachment.Name = "DashTrailAttachmentB"
			lowerAttachment.Position = Vector3.new(0, -limb.Size.Y * 0.45, 0)
			lowerAttachment.Parent = limb

			local trail = Instance.new("Trail")
			trail.Name = "DashLimbTrail"
			trail.Attachment0 = upperAttachment
			trail.Attachment1 = lowerAttachment
			trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
			trail.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.25),
				NumberSequenceKeypoint.new(1, 1),
			})
			trail.WidthScale = NumberSequence.new(0.2)
			trail.Lifetime = DASH_TRAIL_LIFETIME
			trail.MinLength = 0.1
			trail.MaxLength = 0
			trail.LightEmission = .2
			trail.LightInfluence = 0
			trail.Texture = ""
			trail.TextureMode = Enum.TextureMode.Stretch
			trail.FaceCamera = true
			trail.Parent = limb

			table.insert(createdObjects, trail)
			table.insert(createdObjects, upperAttachment)
			table.insert(createdObjects, lowerAttachment)

			Debris:AddItem(trail, DASH_TRAIL_FAILSAFE_TIME)
			Debris:AddItem(upperAttachment, DASH_TRAIL_FAILSAFE_TIME)
			Debris:AddItem(lowerAttachment, DASH_TRAIL_FAILSAFE_TIME)
		end
	end

	local function cleanup()
		if cleanedUp then
			return
		end

		cleanedUp = true

		for _, object in ipairs(createdObjects) do
			if object and object:IsA("Trail") then
				object.Enabled = false
			end
		end

		task.delay(DASH_TRAIL_LIFETIME + DASH_TRAIL_CLEANUP_BUFFER, function()
			for _, object in ipairs(createdObjects) do
				if object and object.Parent then
					object:Destroy()
				end
			end
		end)
	end

	task.delay(DASH_TRAIL_ACTIVE_TIME, cleanup)

	return cleanup
end

local function getWallRaycastParams(character)
	if wallRaycastFilterCharacter ~= character then
		wallRaycastFilterCharacter = character
		wallRaycastParams.FilterDescendantsInstances = { character }
	end

	return wallRaycastParams
end

local function isWallAhead(character, root, direction)
	if not character or not root then
		return false
	end

	local flatDirection = getFlatDirection(direction)

	local origin = root.Position + Vector3.new(0, 0.4, 0)
	local result = workspace:Raycast(origin, flatDirection * WALL_CHECK_DISTANCE, getWallRaycastParams(character))

	if not result then
		return false
	end

	if result.Normal.Y > 0.45 then
		return false
	end

	return true
end

local function clampPostDashVelocity(root)
	if not root or not root.Parent then
		return
	end

	local velocity = root.AssemblyLinearVelocity
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)

	if horizontal.Magnitude > POST_DASH_MAX_HORIZONTAL_SPEED then
		horizontal = horizontal.Unit * POST_DASH_MAX_HORIZONTAL_SPEED

		root.AssemblyLinearVelocity = Vector3.new(
			horizontal.X,
			velocity.Y,
			horizontal.Z
		)
	end

	root.AssemblyAngularVelocity = Vector3.zero
end

local function setDashPlaneVelocity(linearVelocity, direction)
	if not linearVelocity or not linearVelocity.Parent then
		return
	end

	linearVelocity.PlaneVelocity = Vector2.new(
		direction.X * DASH_SPEED,
		direction.Z * DASH_SPEED
	)
end

local function dash()
	if not canDash then return end
	if isDashing then return end

	local character, humanoid, root = getCharacter()
	if not character then return end

	if not canDashNow(character, humanoid, root) then
		if character:GetAttribute("Emoting") == true then
			emoteRemote:FireServer({
				Action = "CancelEmote",
			})
		end
		return
	end

	canDash = false
	isDashing = true

	local dashType = getDashType()
	local currentDirection = getFlatDirection(getDirectionFromDashType(dashType))

	local oldAutoRotate = humanoid.AutoRotate
	humanoid.AutoRotate = false

	local attachment = Instance.new("Attachment")
	attachment.Name = "DashAttachment"
	attachment.Parent = root

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "DashLinearVelocity"
	linearVelocity.Attachment0 = attachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	linearVelocity.PrimaryTangentAxis = Vector3.new(1, 0, 0)
	linearVelocity.SecondaryTangentAxis = Vector3.new(0, 0, 1)
	linearVelocity.MaxForce = DASH_MAX_FORCE
	linearVelocity.Parent = root

	setDashPlaneVelocity(linearVelocity, currentDirection)
	local lastAppliedDirection = currentDirection
	local lastFaceDirection = nil
	local cleanupDashTrails = createDashLimbTrails(character)

	local startTime = os.clock()
	local cleanedUp = false
	local wallCheckFrame = WALL_CHECK_FRAME_INTERVAL - 1
	local connection = nil
	local diedConnection = nil
	local ancestryConnection = nil
	local characterRemovingConnection = nil

	Debris:AddItem(linearVelocity, DASH_DURATION + 1)
	Debris:AddItem(attachment, DASH_DURATION + 1)

	local function cleanupDash()
		if cleanedUp then
			return
		end

		cleanedUp = true

		if connection then
			connection:Disconnect()
			connection = nil
		end

		if diedConnection then
			diedConnection:Disconnect()
			diedConnection = nil
		end

		if ancestryConnection then
			ancestryConnection:Disconnect()
			ancestryConnection = nil
		end

		if characterRemovingConnection then
			characterRemovingConnection:Disconnect()
			characterRemovingConnection = nil
		end

		if cleanupDashTrails then
			cleanupDashTrails()
			cleanupDashTrails = nil
		end

		if linearVelocity and linearVelocity.Parent then
			linearVelocity:Destroy()
		end

		if attachment and attachment.Parent then
			attachment:Destroy()
		end

		if humanoid and humanoid.Parent then
			humanoid.AutoRotate = oldAutoRotate
		end

		clampPostDashVelocity(root)

		isDashing = false

		task.delay(DASH_COOLDOWN, function()
			canDash = true
		end)
	end

	diedConnection = humanoid.Died:Connect(cleanupDash)
	ancestryConnection = character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			cleanupDash()
		end
	end)
	characterRemovingConnection = player.CharacterRemoving:Connect(function(removedCharacter)
		if removedCharacter == character then
			cleanupDash()
		end
	end)

	connection = RunService.PreRender:Connect(function(deltaTime)
		local elapsed = os.clock() - startTime

		if not character or not character.Parent then
			cleanupDash()
			return
		end

		if not humanoid or not humanoid.Parent or humanoid.Health <= 0 then
			cleanupDash()
			return
		end

		if not root or not root.Parent then
			cleanupDash()
			return
		end

		if character:GetAttribute("Stunned")
			or character:GetAttribute("Guardbroken")
			or isDashLocked(character)
		then
			cleanupDash()
			return
		end

		if elapsed >= DASH_DURATION then
			cleanupDash()
			return
		end

		if elapsed <= STEERING_TIME then
			local desiredDirection = getFlatDirection(getDirectionFromDashType(dashType))
			local alpha = math.clamp(deltaTime * TURN_SPEED, 0, 1)

			currentDirection = currentDirection:Lerp(desiredDirection, alpha)

			if currentDirection.Magnitude > 0.05 then
				currentDirection = currentDirection.Unit
			else
				currentDirection = desiredDirection
			end
		end

		wallCheckFrame += 1
		if wallCheckFrame >= WALL_CHECK_FRAME_INTERVAL then
			wallCheckFrame = 0

			if isWallAhead(character, root, currentDirection) then
				cleanupDash()
				return
			end
		end

		if currentDirection:Dot(lastAppliedDirection) < 0.999 then
			setDashPlaneVelocity(linearVelocity, currentDirection)
			lastAppliedDirection = currentDirection
		end

		local cameraCFrame = getFlatCameraCFrame()
		local faceDirection = Vector3.new(
			cameraCFrame.LookVector.X,
			0,
			cameraCFrame.LookVector.Z
		)

		if faceDirection.Magnitude > 0.05 then
			local unitFaceDirection = faceDirection.Unit

			if not lastFaceDirection or unitFaceDirection:Dot(lastFaceDirection) < 0.995 then
				root.CFrame = CFrame.lookAt(root.Position, root.Position + unitFaceDirection)
				lastFaceDirection = unitFaceDirection
			end
		end
	end)
end

local function requestSoulBurstIfStunned()
	local character = player.Character
	if not character or not character.Parent then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	if character:GetAttribute("Stunned") ~= true then
		return false
	end

	soulBurstRemote:FireServer("Activate")
	return true
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		if input.KeyCode ~= DASH_KEY or UserInputService:GetFocusedTextBox() then
			return
		end
	end

	if input.KeyCode == DASH_KEY then
		if requestSoulBurstIfStunned() then
			return
		end

		dash()
	end
end)
