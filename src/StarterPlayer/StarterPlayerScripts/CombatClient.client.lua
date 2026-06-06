local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local combatRemote = remotes:WaitForChild("CombatRemote")
local moveRemote = remotes:WaitForChild("MoveRemote")
local ultRemote = remotes:WaitForChild("UltRemote")
local cinematicRemote = remotes:WaitForChild("CinematicRemote")

local assets = ReplicatedStorage:WaitForChild("Assets")
local charactersFolder = assets:WaitForChild("Characters")

local mouseHeld = false
local localM1Cooldown = false

local LOCAL_M1_COOLDOWN = 0.27

local uptiltBuffered = false
local UPTILT_BUFFER_TIME = 0.15

local jumpLockedUntil = 0
local CLIENT_JUMP_LOCK_TIME = 0.5

local BLOCK_KEY = Enum.KeyCode.F
local blocking = false
local blockBuffered = false
local BLOCK_BUFFER_TIME = 0.18

local currentUlt = 0
local currentUltMax = 100
local currentUltAlpha = 0
local currentUltFull = false

local ultimateFillTween = nil
local ULT_BAR_TWEEN_TIME = 0.18

local MOVE_KEYS = {
	[Enum.KeyCode.One] = "Move1",
	[Enum.KeyCode.Two] = "Move2",
	[Enum.KeyCode.Three] = "Move3",
	[Enum.KeyCode.Four] = "Move4",
	[Enum.KeyCode.G] = "Ultimate",
}

local DEFAULT_MOVE_DISPLAY = {
	Move1 = {
		Key = "1",
		Name = "Move 1",
		Cooldown = 1,
	},

	Move2 = {
		Key = "2",
		Name = "Move 2",
		Cooldown = 1,
	},

	Move3 = {
		Key = "3",
		Name = "Move 3",
		Cooldown = 1,
	},

	Move4 = {
		Key = "4",
		Name = "Move 4",
		Cooldown = 1,
	},

	Ultimate = {
		Key = "G",
		Name = "Ultimate",
		Cooldown = 35,
	},
}

local currentMoveDisplay = table.clone(DEFAULT_MOVE_DISPLAY)
local localMoveCooldowns = {}

local moveButtons = {}
local moveNameLabels = {}
local cooldownOverlays = {}
local cooldownTexts = {}

local ultimateFill = nil
local ultimateText = nil
local ultimateStroke = nil

local function getCharacter()
	local character = player.Character
	if not character then return nil end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return nil end

	return character, humanoid
end

local function getCurrentCharacterName()
	local character = player.Character

	local playerCharacterName = player:GetAttribute("CharacterName")
	if typeof(playerCharacterName) == "string" and playerCharacterName ~= "" then
		return playerCharacterName
	end

	if character then
		local characterName = character:GetAttribute("CharacterName")
		if typeof(characterName) == "string" and characterName ~= "" then
			return characterName
		end
	end

	return "Chara"
end

local function getMoveModuleForCharacter(characterName)
	local characterFolder = charactersFolder:FindFirstChild(characterName)
	if not characterFolder then return nil end

	local modulesFolder = characterFolder:FindFirstChild("Modules")
	if not modulesFolder then return nil end

	local moveModuleScript = modulesFolder:FindFirstChild("MoveModule")
	if not moveModuleScript then return nil end

	local success, result = pcall(function()
		return require(moveModuleScript)
	end)

	if not success then
		warn("[CombatClient] Failed to require MoveModule:", result)
		return nil
	end

	if typeof(result) == "table" and result.new then
		local ok, moduleObject = pcall(function()
			return result.new({})
		end)

		if ok then
			return moduleObject
		end

		warn("[CombatClient] Failed to create MoveModule object:", moduleObject)
		return nil
	end

	return result
end

local function buildMoveDisplayFromModule(characterName)
	local display = {}

	for slot, data in pairs(DEFAULT_MOVE_DISPLAY) do
		display[slot] = {
			Key = data.Key,
			Name = data.Name,
			Cooldown = data.Cooldown,
		}
	end

	local moveModule = getMoveModuleForCharacter(characterName)
	if not moveModule or not moveModule.Slots or not moveModule.Moves then
		return display
	end

	for slot, moveId in pairs(moveModule.Slots) do
		local moveData = moveModule.Moves[moveId]

		if moveData then
			display[slot] = display[slot] or {}

			display[slot].Key = DEFAULT_MOVE_DISPLAY[slot] and DEFAULT_MOVE_DISPLAY[slot].Key or "?"
			display[slot].Name = moveData.DisplayName or moveId
			display[slot].Cooldown = moveData.Cooldown or 1
			display[slot].MoveId = moveId

			display[slot].RequiresTarget = moveData.RequiresTarget == true
			display[slot].RequiresAim = moveData.RequiresAim == true
		end
	end

	return display
end

function updateUltimateBar()
	local alpha = math.clamp(currentUltAlpha or 0, 0, 1)

	if currentUltMax and currentUltMax > 0 then
		alpha = math.clamp(currentUlt / currentUltMax, 0, 1)
	end

	currentUltAlpha = alpha
	currentUltFull = alpha >= 1

	if ultimateFill then
		if ultimateFillTween then
			ultimateFillTween:Cancel()
			ultimateFillTween = nil
		end

		ultimateFillTween = TweenService:Create(
			ultimateFill,
			TweenInfo.new(
				ULT_BAR_TWEEN_TIME,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			),
			{
				Size = UDim2.fromScale(alpha, 1),
				BackgroundColor3 = currentUltFull
					and Color3.fromRGB(255, 70, 70)
					or Color3.fromRGB(200, 45, 45),
			}
		)

		ultimateFillTween:Play()
	end

	if ultimateStroke then
		if currentUltFull then
			ultimateStroke.Color = Color3.fromRGB(255, 255, 255)
			ultimateStroke.Thickness = 2
		else
			ultimateStroke.Color = Color3.fromRGB(90, 90, 105)
			ultimateStroke.Thickness = 1
		end
	end

	if ultimateText then
		local ultName = "Ultimate"

		if currentMoveDisplay.Ultimate and currentMoveDisplay.Ultimate.Name then
			ultName = currentMoveDisplay.Ultimate.Name
		end

		if currentUltFull then
			ultimateText.Text = string.upper(ultName) .. " READY"
		else
			ultimateText.Text = string.upper(ultName) .. " " .. tostring(math.floor(alpha * 100)) .. "%"
		end
	end
end

local function refreshMoveDisplay()
	local characterName = getCurrentCharacterName()
	currentMoveDisplay = buildMoveDisplayFromModule(characterName)

	for slot, label in pairs(moveNameLabels) do
		local data = currentMoveDisplay[slot]
		if data then
			label.Text = data.Name or slot
		end
	end

	updateUltimateBar()
end

local function canRequestAttack()
	local character = getCharacter()
	if not character then return false end

	if character:GetAttribute("Stunned") then return false end
	if character:GetAttribute("Blocking") then return false end
	if character:GetAttribute("Guardbroken") then return false end
	if character:GetAttribute("UsingMove") then return false end

	return true
end

local function canRequestMove()
	local character = getCharacter()
	if not character then return false end

	if character:GetAttribute("Stunned") then return false end
	if character:GetAttribute("Blocking") then return false end
	if character:GetAttribute("Guardbroken") then return false end
	if character:GetAttribute("UsingMove") then return false end

	return true
end

local function canRequestBlock()
	local character = getCharacter()
	if not character then return false end

	if character:GetAttribute("Stunned") then return false end
	if character:GetAttribute("Blocking") then return false end
	if character:GetAttribute("Guardbroken") then return false end
	if character:GetAttribute("Attacking") then return false end
	if character:GetAttribute("UsingMove") then return false end
	if character:GetAttribute("Grabbed") then return false end
	if character:GetAttribute("CinematicLocked") then return false end

	return true
end

local function bufferUptilt()
	uptiltBuffered = true

	task.delay(UPTILT_BUFFER_TIME, function()
		uptiltBuffered = false
	end)
end

local function requestBlockStart()
	if blocking then return true end
	if not canRequestBlock() then return false end

	blockBuffered = false
	blocking = true
	combatRemote:FireServer("BlockStart")

	return true
end

local function bufferBlock()
	blockBuffered = true

	task.delay(BLOCK_BUFFER_TIME, function()
		blockBuffered = false
	end)

	task.spawn(function()
		while blockBuffered do
			if not UserInputService:IsKeyDown(BLOCK_KEY) then
				blockBuffered = false
				return
			end

			if requestBlockStart() then
				return
			end

			task.wait()
		end
	end)
end

local function lockLocalJump(duration)
	jumpLockedUntil = os.clock() + (duration or CLIENT_JUMP_LOCK_TIME)

	local character, humanoid = getCharacter()
	if humanoid then
		humanoid.Jump = false
	end
end

local function getCooldownForSlot(moveSlot)
	local data = currentMoveDisplay[moveSlot]
	if data and typeof(data.Cooldown) == "number" then
		return data.Cooldown
	end

	return DEFAULT_MOVE_DISPLAY[moveSlot] and DEFAULT_MOVE_DISPLAY[moveSlot].Cooldown or 1
end

local function startLocalCooldown(moveSlot)
	local cooldown = getCooldownForSlot(moveSlot)

	local overlay = cooldownOverlays[moveSlot]
	local cooldownText = cooldownTexts[moveSlot]

	if not overlay then return end

	overlay.Visible = true
	overlay.Size = UDim2.fromScale(1, 1)

	if cooldownText then
		cooldownText.Visible = true
	end

	local startTime = os.clock()

	task.spawn(function()
		while os.clock() - startTime < cooldown do
			local elapsed = os.clock() - startTime
			local remaining = math.max(cooldown - elapsed, 0)
			local alpha = math.clamp(elapsed / cooldown, 0, 1)

			overlay.Size = UDim2.fromScale(1, 1 - alpha)

			if cooldownText then
				cooldownText.Text = string.format("%.1f", remaining)
			end

			task.wait()
		end

		overlay.Visible = false
		overlay.Size = UDim2.fromScale(1, 1)

		if cooldownText then
			cooldownText.Visible = false
		end
	end)
end

local function getMouseTargetCharacter()
	local camera = workspace.CurrentCamera
	if not camera then return nil end

	local mouse = player:GetMouse()
	local unitRay = camera:ScreenPointToRay(mouse.X, mouse.Y)

	local origin = unitRay.Origin
	local direction = unitRay.Direction.Unit
	local maxDistance = 500

	local bestCharacter = nil
	local bestScore = math.huge

	local myCharacter = player.Character

	for _, model in ipairs(workspace:GetDescendants()) do
		if model:IsA("Model") and model ~= myCharacter then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local root = model:FindFirstChild("HumanoidRootPart")

			if humanoid and root and humanoid.Health > 0 then
				local toTarget = root.Position - origin
				local projectedDistance = toTarget:Dot(direction)

				if projectedDistance > 0 and projectedDistance <= maxDistance then
					local closestPointOnRay = origin + direction * projectedDistance
					local distanceFromRay = (root.Position - closestPointOnRay).Magnitude

					local aimAssistRadius = 10

					if distanceFromRay <= aimAssistRadius then
						local score = distanceFromRay + (projectedDistance * 0.01)

						if score < bestScore then
							bestScore = score
							bestCharacter = model
						end
					end
				end
			end
		end
	end

	return bestCharacter
end

local function requestMove(moveSlot)
	if localMoveCooldowns[moveSlot] then return end
	if not canRequestMove() then return end

	local moveInfo = currentMoveDisplay[moveSlot]
	local moveId = moveInfo and moveInfo.MoveId

	local targetCharacter = getMouseTargetCharacter()

	local mouse = player:GetMouse()
	local aimPosition = nil

	if mouse and mouse.Hit then
		aimPosition = mouse.Hit.Position
	end

	if moveInfo and moveInfo.RequiresTarget and not targetCharacter then
		warn("[CombatClient] Move needs a valid mouse target:", moveId or moveSlot)
		return
	end

	if moveInfo and moveInfo.RequiresAim and typeof(aimPosition) ~= "Vector3" then
		warn("[CombatClient] Move needs a valid aim position:", moveId or moveSlot)
		return
	end

	local cooldown = getCooldownForSlot(moveSlot)

	localMoveCooldowns[moveSlot] = true
	lockLocalJump(0.5)

	moveRemote:FireServer({
		MoveSlot = moveSlot,
		TargetCharacter = targetCharacter,
		AimPosition = aimPosition,
	})

	startLocalCooldown(moveSlot)

	task.delay(cooldown, function()
		localMoveCooldowns[moveSlot] = false
	end)
end

local function createMoveGui()
	local oldGui = playerGui:FindFirstChild("MoveHUD")
	if oldGui then
		oldGui:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MoveHUD"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui

	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.fromScale(0.5, 0.965)
	holder.Size = UDim2.fromOffset(360, 118)
	holder.BackgroundTransparency = 1
	holder.Parent = screenGui

	local ultBack = Instance.new("Frame")
	ultBack.Name = "UltimateBack"
	ultBack.Position = UDim2.fromOffset(0, 0)
	ultBack.Size = UDim2.fromOffset(360, 22)
	ultBack.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	ultBack.BorderSizePixel = 0
	ultBack.Parent = holder

	local ultCorner = Instance.new("UICorner")
	ultCorner.CornerRadius = UDim.new(0, 6)
	ultCorner.Parent = ultBack

	ultimateStroke = Instance.new("UIStroke")
	ultimateStroke.Thickness = 1
	ultimateStroke.Color = Color3.fromRGB(90, 90, 105)
	ultimateStroke.Parent = ultBack

	ultimateFill = Instance.new("Frame")
	ultimateFill.Name = "UltimateFill"
	ultimateFill.Size = UDim2.fromScale(0, 1)
	ultimateFill.BackgroundColor3 = Color3.fromRGB(200, 45, 45)
	ultimateFill.BorderSizePixel = 0
	ultimateFill.Parent = ultBack

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = ultimateFill

	ultimateText = Instance.new("TextLabel")
	ultimateText.Name = "UltimateText"
	ultimateText.BackgroundTransparency = 1
	ultimateText.Size = UDim2.fromScale(1, 1)
	ultimateText.Font = Enum.Font.GothamBold
	ultimateText.TextSize = 12
	ultimateText.TextColor3 = Color3.fromRGB(245, 245, 245)
	ultimateText.Text = "ULTIMATE 0%"
	ultimateText.Parent = ultBack

	local buttonsFrame = Instance.new("Frame")
	buttonsFrame.Name = "Buttons"
	buttonsFrame.Position = UDim2.fromOffset(0, 34)
	buttonsFrame.Size = UDim2.fromOffset(360, 84)
	buttonsFrame.BackgroundTransparency = 1
	buttonsFrame.Parent = holder

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = buttonsFrame

	local slots = { "Move1", "Move2", "Move3", "Move4" }

	for index, moveSlot in ipairs(slots) do
		local data = currentMoveDisplay[moveSlot] or DEFAULT_MOVE_DISPLAY[moveSlot]

		local button = Instance.new("TextButton")
		button.Name = moveSlot
		button.LayoutOrder = index
		button.Size = UDim2.fromOffset(78, 78)
		button.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
		button.BorderSizePixel = 0
		button.AutoButtonColor = true
		button.Text = ""
		button.Parent = buttonsFrame

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = button

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.fromRGB(90, 90, 105)
		stroke.Parent = button

		local keyLabel = Instance.new("TextLabel")
		keyLabel.Name = "Key"
		keyLabel.BackgroundTransparency = 1
		keyLabel.Position = UDim2.fromOffset(6, 4)
		keyLabel.Size = UDim2.fromOffset(24, 22)
		keyLabel.Font = Enum.Font.GothamBold
		keyLabel.TextSize = 16
		keyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		keyLabel.Text = data.Key
		keyLabel.Parent = button

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "MoveName"
		nameLabel.BackgroundTransparency = 1
		nameLabel.AnchorPoint = Vector2.new(0.5, 1)
		nameLabel.Position = UDim2.fromScale(0.5, 0.92)
		nameLabel.Size = UDim2.fromOffset(70, 32)
		nameLabel.Font = Enum.Font.GothamSemibold
		nameLabel.TextSize = 12
		nameLabel.TextWrapped = true
		nameLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
		nameLabel.Text = data.Name
		nameLabel.Parent = button

		local overlay = Instance.new("Frame")
		overlay.Name = "CooldownOverlay"
		overlay.AnchorPoint = Vector2.new(0, 1)
		overlay.Position = UDim2.fromScale(0, 1)
		overlay.Size = UDim2.fromScale(1, 1)
		overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		overlay.BackgroundTransparency = 0.45
		overlay.BorderSizePixel = 0
		overlay.Visible = false
		overlay.Parent = button

		local overlayCorner = Instance.new("UICorner")
		overlayCorner.CornerRadius = UDim.new(0, 8)
		overlayCorner.Parent = overlay

		local cooldownText = Instance.new("TextLabel")
		cooldownText.Name = "CooldownText"
		cooldownText.BackgroundTransparency = 1
		cooldownText.Size = UDim2.fromScale(1, 1)
		cooldownText.Font = Enum.Font.GothamBlack
		cooldownText.TextSize = 20
		cooldownText.TextColor3 = Color3.fromRGB(255, 255, 255)
		cooldownText.TextStrokeTransparency = 0.4
		cooldownText.Visible = false
		cooldownText.Parent = button

		moveButtons[moveSlot] = button
		moveNameLabels[moveSlot] = nameLabel
		cooldownOverlays[moveSlot] = overlay
		cooldownTexts[moveSlot] = cooldownText

		button.MouseButton1Click:Connect(function()
			requestMove(moveSlot)
		end)
	end

	refreshMoveDisplay()
	updateUltimateBar()
end

local function requestAttack()
	if localM1Cooldown then return end
	if not canRequestAttack() then return end

	localM1Cooldown = true

	local spaceHeld = UserInputService:IsKeyDown(Enum.KeyCode.Space)
	local wantUptilt = uptiltBuffered or spaceHeld

	uptiltBuffered = false
	lockLocalJump(CLIENT_JUMP_LOCK_TIME)

	combatRemote:FireServer("M1", {
		wantUptilt = wantUptilt,
		spaceHeld = spaceHeld,
	})

	task.delay(LOCAL_M1_COOLDOWN, function()
		localM1Cooldown = false
	end)
end

local function holdM1Loop()
	while mouseHeld do
		requestAttack()
		task.wait(LOCAL_M1_COOLDOWN)
	end
end

local function startBlocking()
	if requestBlockStart() then return end

	bufferBlock()
end

local function stopBlocking()
	blockBuffered = false

	if not blocking then return end

	blocking = false
	combatRemote:FireServer("BlockEnd")
end

ultRemote.OnClientEvent:Connect(function(payload)
	print("[CombatClient] UltRemote payload:", payload)
	
	if typeof(payload) ~= "table" then return end

	if payload.Action == "Update" or payload.Action == "Spent" then
		if typeof(payload.Current) == "number" then
			currentUlt = payload.Current
		end

		if typeof(payload.Max) == "number" and payload.Max > 0 then
			currentUltMax = payload.Max
		end

		if typeof(payload.Alpha) == "number" then
			currentUltAlpha = math.clamp(payload.Alpha, 0, 1)
		else
			currentUltAlpha = math.clamp(currentUlt / currentUltMax, 0, 1)
		end

		currentUltFull = payload.Full == true or currentUltAlpha >= 1

		updateUltimateBar()
	end
end)
--CAMERA STUFF
local activeCinematicCamera = false
local oldCameraType = nil
local oldCameraSubject = nil
local cameraTween = nil

local function getCamera()
	return workspace.CurrentCamera
end

local function beginCinematicCamera()
	local camera = getCamera()
	if not camera then return end

	if not activeCinematicCamera then
		oldCameraType = camera.CameraType
		oldCameraSubject = camera.CameraSubject
	end

	activeCinematicCamera = true
	camera.CameraType = Enum.CameraType.Scriptable
end

local function setCinematicCamera(cframe)
	local camera = getCamera()
	if not camera then return end

	beginCinematicCamera()

	if cameraTween then
		cameraTween:Cancel()
		cameraTween = nil
	end

	camera.CFrame = cframe
end

local function tweenCinematicCamera(cframe, tweenTime)
	local camera = getCamera()
	if not camera then return end

	beginCinematicCamera()

	if cameraTween then
		cameraTween:Cancel()
		cameraTween = nil
	end

	cameraTween = TweenService:Create(
		camera,
		TweenInfo.new(
			tweenTime or 0.25,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		),
		{
			CFrame = cframe,
		}
	)

	cameraTween:Play()
end

local function resetCinematicCamera()
	local camera = getCamera()
	if not camera then return end

	if cameraTween then
		cameraTween:Cancel()
		cameraTween = nil
	end

	activeCinematicCamera = false

	camera.CameraType = oldCameraType or Enum.CameraType.Custom

	if oldCameraSubject then
		camera.CameraSubject = oldCameraSubject
	elseif player.Character then
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

cinematicRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end

	if payload.Action == "SetCamera" and typeof(payload.CFrame) == "CFrame" then
		setCinematicCamera(payload.CFrame)
	elseif payload.Action == "TweenCamera" and typeof(payload.CFrame) == "CFrame" then
		tweenCinematicCamera(payload.CFrame, payload.Time or 0.25)
	elseif payload.Action == "ResetCamera" then
		resetCinematicCamera()
	end
end)
--
UserInputService.JumpRequest:Connect(function()
	local character, humanoid = getCharacter()
	if not humanoid then return end

	if os.clock() < jumpLockedUntil then
		humanoid.Jump = false
		return
	end

	if character:GetAttribute("UsingMove") then
		humanoid.Jump = false
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.Space then
		bufferUptilt()
	end

	local moveSlot = MOVE_KEYS[input.KeyCode]
	if moveSlot then
		requestMove(moveSlot)
		return
	end

	if input.KeyCode == BLOCK_KEY then
		startBlocking()
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if mouseHeld then return end

		mouseHeld = true
		task.spawn(holdM1Loop)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		mouseHeld = false
	end

	if input.KeyCode == BLOCK_KEY then
		stopBlocking()
	end
end)

local function hookCharacter(character)
	task.wait(0.25)

	refreshMoveDisplay()
	updateUltimateBar()

	character:GetAttributeChangedSignal("CharacterName"):Connect(function()
		refreshMoveDisplay()
		updateUltimateBar()
	end)
end

player:GetAttributeChangedSignal("CharacterName"):Connect(function()
	refreshMoveDisplay()
	updateUltimateBar()
end)

player.CharacterAdded:Connect(hookCharacter)

createMoveGui()

if player.Character then
	hookCharacter(player.Character)
end
