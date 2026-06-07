local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local soulBurstRemote = remotes:WaitForChild("SoulBurstRemote")

local DASH_KEY = Enum.KeyCode.Q

local DASH_DURATION = 0.25
local DASH_SPEED = 75
local DASH_COOLDOWN = 1.1

-- Higher = follows camera more sharply.
local TURN_SPEED = 24

-- How long camera steering is allowed.
-- Set equal to DASH_DURATION if you want steering for the whole dash.
local STEERING_TIME = 0.25

local canDash = true
local isDashing = false

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

	-- Default if no movement key is held.
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

local function createDashDust(root, dashDirection)
	local dust = Instance.new("Part")
	dust.Name = "DashDust"
	dust.Anchored = true
	dust.CanCollide = false
	dust.CanTouch = false
	dust.CanQuery = false
	dust.Size = Vector3.new(2, 0.15, 2)
	dust.CFrame = CFrame.lookAt(
		root.Position - Vector3.new(0, 2.7, 0),
		root.Position - Vector3.new(0, 2.7, 0) + dashDirection
	)
	dust.Transparency = 0.45
	dust.Parent = workspace

	Debris:AddItem(dust, 0.15)
end

local function dash()
	if not canDash then return end
	if isDashing then return end

	local character, humanoid, root = getCharacter()
	if not character then return end

	if not canDashNow(character, humanoid, root) then
		return
	end

	canDash = false
	isDashing = true

	local dashType = getDashType()
	local currentDirection = getDirectionFromDashType(dashType)

	local oldAutoRotate = humanoid.AutoRotate
	humanoid.AutoRotate = false

	local attachment = Instance.new("Attachment")
	attachment.Name = "DashAttachment"
	attachment.Parent = root

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "DashLinearVelocity"
	linearVelocity.Attachment0 = attachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	linearVelocity.MaxForce = math.huge
	linearVelocity.VectorVelocity = currentDirection * DASH_SPEED
	linearVelocity.Parent = root

	createDashDust(root, currentDirection)

	local startTime = os.clock()

	local function cleanupDash()
		if linearVelocity and linearVelocity.Parent then
			linearVelocity:Destroy()
		end

		if attachment and attachment.Parent then
			attachment:Destroy()
		end

		if humanoid and humanoid.Parent then
			humanoid.AutoRotate = oldAutoRotate
		end

		isDashing = false

		task.delay(DASH_COOLDOWN, function()
			canDash = true
		end)
	end

	local connection
	connection = RunService.PreRender:Connect(function(deltaTime)
		local elapsed = os.clock() - startTime

		if not character or not character.Parent then
			connection:Disconnect()
			cleanupDash()
			return
		end

		if not humanoid or not humanoid.Parent or humanoid.Health <= 0 then
			connection:Disconnect()
			cleanupDash()
			return
		end

		if not root or not root.Parent then
			connection:Disconnect()
			cleanupDash()
			return
		end

		-- Dash gets canceled immediately if hard movement lock/status starts mid-dash.
		-- Blocking does NOT cancel dash anymore.
		if character:GetAttribute("Stunned")
			or character:GetAttribute("Guardbroken")
			or isDashLocked(character)
		then
			connection:Disconnect()
			cleanupDash()
			return
		end

		if elapsed >= DASH_DURATION then
			connection:Disconnect()
			cleanupDash()
			return
		end

		-- This is the camera-guided part.
		if elapsed <= STEERING_TIME then
			local desiredDirection = getDirectionFromDashType(dashType)
			local alpha = math.clamp(deltaTime * TURN_SPEED, 0, 1)

			currentDirection = currentDirection:Lerp(desiredDirection, alpha)

			if currentDirection.Magnitude > 0.05 then
				currentDirection = currentDirection.Unit
			end
		end

		linearVelocity.VectorVelocity = currentDirection * DASH_SPEED

		-- Character keeps facing the camera direction, even during side/back dashes.
		local cameraCFrame = getFlatCameraCFrame()
		local faceDirection = cameraCFrame.LookVector
		root.CFrame = CFrame.lookAt(root.Position, root.Position + faceDirection)
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
	if gameProcessed then return end

	if input.KeyCode == DASH_KEY then
		if requestSoulBurstIfStunned() then
			return
		end

		dash()
	end
end)
