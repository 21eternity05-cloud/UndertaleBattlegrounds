local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local combatRemote = remotes:WaitForChild("CombatRemote")
local moveRemote = remotes:WaitForChild("MoveRemote")
local ultRemote = remotes:WaitForChild("UltRemote")
local soulBurstRemote = remotes:WaitForChild("SoulBurstRemote")
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

local currentUlt = 0
local currentUltMax = 100
local currentUltAlpha = 0
local currentUltFull = false

local ultimateFillTween = nil
local ULT_BAR_TWEEN_TIME = 0.18

local currentSoulBurst = 0
local currentSoulBurstMax = 100
local currentSoulBurstAlpha = 0
local soulBurstFillTween = nil
local SOUL_BURST_BAR_TWEEN_TIME = 0.18

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
local soulBurstFill = nil
local soulBurstText = nil
local soulBurstStroke = nil

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

local function getCurrentCombatMode()
	local character = player.Character
	if character then
		local mode = character:GetAttribute("CombatMode")
		if typeof(mode) == "string" and mode ~= "" then
			return mode
		end
	end

	return "Base"
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
			LockTime = data.LockTime or 0,
		}
	end

	local moveModule = getMoveModuleForCharacter(characterName)
	if not moveModule or not moveModule.Slots or not moveModule.Moves then
		return display
	end

	local mode = getCurrentCombatMode()
	local slots = moveModule.Slots

	if moveModule.SlotSets and moveModule.SlotSets[mode] then
		slots = moveModule.SlotSets[mode]
	end

	for slot, moveId in pairs(slots) do
		local moveData = moveModule.Moves[moveId]

		if moveData then
			display[slot] = display[slot] or {}

			display[slot].Key = DEFAULT_MOVE_DISPLAY[slot] and DEFAULT_MOVE_DISPLAY[slot].Key or "?"
			display[slot].Name = moveData.DisplayName or moveId
			display[slot].Cooldown = moveData.Cooldown or 1
			display[slot].LockTime = typeof(moveData.LockTime) == "number" and math.max(0, moveData.LockTime) or 0
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

local function updateSoulBurstBar()
	local alpha = math.clamp(currentSoulBurstAlpha or 0, 0, 1)

	if currentSoulBurstMax and currentSoulBurstMax > 0 then
		alpha = math.clamp(currentSoulBurst / currentSoulBurstMax, 0, 1)
	end

	currentSoulBurstAlpha = alpha

	if soulBurstFill then
		if soulBurstFillTween then
			soulBurstFillTween:Cancel()
			soulBurstFillTween = nil
		end

		soulBurstFillTween = TweenService:Create(
			soulBurstFill,
			TweenInfo.new(
				SOUL_BURST_BAR_TWEEN_TIME,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			),
			{
				Size = UDim2.fromScale(1, alpha),
				Position = UDim2.fromScale(0, 1 - alpha),
			}
		)

		soulBurstFillTween:Play()
	end

	if soulBurstStroke then
		if alpha >= 1 then
			soulBurstStroke.Color = Color3.fromRGB(255, 255, 255)
			soulBurstStroke.Thickness = 2
		else
			soulBurstStroke.Color = Color3.fromRGB(90, 90, 105)
			soulBurstStroke.Thickness = 1
		end
	end

	if soulBurstText then
		soulBurstText.Text = alpha >= 1 and "BURST" or "SOUL"
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
	updateSoulBurstBar()
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

	blocking = true
	combatRemote:FireServer("BlockStart")

	return true
end

local function clearLocalBlockState(sendEnd)
	blocking = false

	if sendEnd then
		combatRemote:FireServer("BlockEnd")
	end
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

	if workspace:GetAttribute("DebugCooldownsEnabled") == true then
		return workspace:GetAttribute("DebugCooldownOverride") or 1
	end

	if data and typeof(data.Cooldown) == "number" then
		return data.Cooldown
	end

	return DEFAULT_MOVE_DISPLAY[moveSlot] and DEFAULT_MOVE_DISPLAY[moveSlot].Cooldown or 1
end

local function getLockTimeForSlot(moveSlot)
	local data = currentMoveDisplay[moveSlot]

	if data and typeof(data.LockTime) == "number" then
		return math.max(0, data.LockTime)
	end

	return 0
end

local function startLocalCooldown(moveSlot)
	local cooldown = getCooldownForSlot(moveSlot)
	local lockTime = getLockTimeForSlot(moveSlot)

	local overlay = cooldownOverlays[moveSlot]
	local cooldownText = cooldownTexts[moveSlot]

	if not overlay then return end

	task.delay(lockTime, function()
		if not localMoveCooldowns[moveSlot] then
			return
		end

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

	local cooldown = getLockTimeForSlot(moveSlot) + getCooldownForSlot(moveSlot)

	-- Ultimates do not use local client cooldown.
	-- The server gates ultimates by ult bar, UsingMove, and normal move state.
	if moveSlot == "Ultimate" then
		moveRemote:FireServer({
			MoveSlot = moveSlot,
			TargetCharacter = targetCharacter,
			AimPosition = aimPosition,
		})

		return
	end

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

	local soulBack = Instance.new("Frame")
	soulBack.Name = "SoulBurstBack"
	soulBack.Position = UDim2.fromOffset(370, 34)
	soulBack.Size = UDim2.fromOffset(34, 84)
	soulBack.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	soulBack.BorderSizePixel = 0
	soulBack.ClipsDescendants = true
	soulBack.Parent = holder

	local soulCorner = Instance.new("UICorner")
	soulCorner.CornerRadius = UDim.new(0, 8)
	soulCorner.Parent = soulBack

	soulBurstStroke = Instance.new("UIStroke")
	soulBurstStroke.Thickness = 1
	soulBurstStroke.Color = Color3.fromRGB(90, 90, 105)
	soulBurstStroke.Parent = soulBack

	soulBurstFill = Instance.new("Frame")
	soulBurstFill.Name = "SoulBurstFill"
	soulBurstFill.AnchorPoint = Vector2.new(0, 0)
	soulBurstFill.Position = UDim2.fromScale(0, 1)
	soulBurstFill.Size = UDim2.fromScale(1, 0)
	soulBurstFill.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
	soulBurstFill.BorderSizePixel = 0
	soulBurstFill.Parent = soulBack

	local soulFillCorner = Instance.new("UICorner")
	soulFillCorner.CornerRadius = UDim.new(0, 8)
	soulFillCorner.Parent = soulBurstFill

	soulBurstText = Instance.new("TextLabel")
	soulBurstText.Name = "SoulBurstText"
	soulBurstText.BackgroundTransparency = 1
	soulBurstText.Size = UDim2.fromScale(1, 1)
	soulBurstText.Font = Enum.Font.GothamBlack
	soulBurstText.TextSize = 9
	soulBurstText.TextColor3 = Color3.fromRGB(255, 255, 255)
	soulBurstText.TextStrokeTransparency = 0.2
	soulBurstText.TextWrapped = true
	soulBurstText.Text = "SOUL"
	soulBurstText.Parent = soulBack

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
	updateSoulBurstBar()
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
	requestBlockStart()
end

local function stopBlocking()
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

soulBurstRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end

	if payload.Action == "Update" or payload.Action == "Activated" or payload.Action == "Ready" then
		local value = payload.Value or payload.Current

		if typeof(value) == "number" then
			currentSoulBurst = value
		end

		if typeof(payload.Max) == "number" and payload.Max > 0 then
			currentSoulBurstMax = payload.Max
		end

		if typeof(payload.Alpha) == "number" then
			currentSoulBurstAlpha = math.clamp(payload.Alpha, 0, 1)
		else
			currentSoulBurstAlpha = math.clamp(currentSoulBurst / currentSoulBurstMax, 0, 1)
		end

		updateSoulBurstBar()
	end
end)

--============================================================
-- CINEMATIC / MOVE-FEEL CLIENT EFFECTS
--============================================================
-- These effects are controlled by CinematicService on the server.
-- Server sends payloads through CinematicRemote.
--
-- Supported actions:
-- SetCamera:
--   Full scripted camera placement, used for true cinematics.
--
-- TweenCamera:
--   Smooth scripted camera movement, used for ult cutscenes.
--
-- ResetCamera:
--   Restores normal player camera after cinematics.
--
-- CameraShakeOnce:
--   Lightweight client-only screen shake.
--   Good for heavy hits, downslams, nearby ult impacts.
--
-- ImpactFrame:
--   Temporary ColorCorrectionEffect flash.
--   Use sparingly for anime-style impact moments.
--
-- FOVPunch:
--   Temporary FOV zoom.
--   Use VERY sparingly. Best for movement moves or very specific cinematic punish moments.
--   Example: Knife Dash speed burst, Killing Intent confirmed punish.
--
-- SetFOVOffset / ClearFOVOffset / ResetFOV:
--   Sustained FOV offsets keyed by id. Use for clean speed FOV while a move is active.
--============================================================

local activeCinematicCamera = false
local oldCameraType = nil
local oldCameraSubject = nil
local cameraTween = nil

local activeCameraShakes = {}
local lastShakeTransform = CFrame.new()

local impactFrameToken = 0
local impactFrameTween = nil

local fovPunchToken = 0
local fovPunchInTween = nil
local fovPunchOutTween = nil
local fovPunchBaseFOV = nil

local activeFOVOffsets = {}
local fovOffsetTween = nil
local fovOffsetTweenToken = 0
local fovOffsetBaseFOV = nil
local fovOffsetCamera = nil

local function getCamera()
	return workspace.CurrentCamera
end

local function ensureFOVBase(camera)
	if not camera then return nil end

	if fovOffsetCamera ~= camera then
		fovOffsetCamera = camera
		fovOffsetBaseFOV = camera.FieldOfView
	end

	if typeof(fovOffsetBaseFOV) ~= "number" then
		fovOffsetBaseFOV = camera.FieldOfView
	end

	return fovOffsetBaseFOV
end

local function getFOVOffsetTotal()
	local total = 0

	for _, amount in pairs(activeFOVOffsets) do
		if typeof(amount) == "number" then
			total += amount
		end
	end

	return total
end

local function getSustainedFOVTarget(camera)
	local baseFOV = ensureFOVBase(camera)
	if not baseFOV then return nil end

	return math.clamp(baseFOV + getFOVOffsetTotal(), 1, 120)
end

local function cancelFOVPunch()
	fovPunchToken += 1

	if fovPunchInTween then
		fovPunchInTween:Cancel()
		fovPunchInTween = nil
	end

	if fovPunchOutTween then
		fovPunchOutTween:Cancel()
		fovPunchOutTween = nil
	end

	fovPunchBaseFOV = nil
end

local function tweenToSustainedFOV(tweenTime)
	local camera = getCamera()
	if not camera then return end

	cancelFOVPunch()
	fovOffsetTweenToken += 1
	local token = fovOffsetTweenToken

	local targetFOV = getSustainedFOVTarget(camera)
	if not targetFOV then return end

	if fovOffsetTween then
		fovOffsetTween:Cancel()
		fovOffsetTween = nil
	end

	tweenTime = typeof(tweenTime) == "number" and math.max(0, tweenTime) or 0.16

	fovOffsetTween = TweenService:Create(
		camera,
		TweenInfo.new(tweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			FieldOfView = targetFOV,
		}
	)

	fovOffsetTween.Completed:Connect(function()
		if token ~= fovOffsetTweenToken then return end
		fovOffsetTween = nil
	end)

	fovOffsetTween:Play()
end

local function setFOVOffset(id, amount, tweenTime)
	if typeof(id) ~= "string" or id == "" then return end
	if typeof(amount) ~= "number" then return end

	activeFOVOffsets[id] = amount
	tweenToSustainedFOV(tweenTime or 0.12)
end

local function clearFOVOffset(id, tweenTime)
	if typeof(id) ~= "string" or id == "" then return end

	activeFOVOffsets[id] = nil
	tweenToSustainedFOV(tweenTime or 0.16)
end

local function resetFOV(tweenTime)
	table.clear(activeFOVOffsets)
	tweenToSustainedFOV(tweenTime or 0.16)
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

local function startCameraShake(intensity, roughness, duration)
	intensity = typeof(intensity) == "number" and math.max(0, intensity) or 1
	roughness = typeof(roughness) == "number" and math.max(0.1, roughness) or 8
	duration = typeof(duration) == "number" and math.max(0.01, duration) or 0.25

	table.insert(activeCameraShakes, {
		StartTime = os.clock(),
		Duration = duration,
		Intensity = intensity,
		Roughness = roughness,
		Seed = math.random() * 1000,
	})
end

local function getImpactFrameEffect()
	local effect = Lighting:FindFirstChild("CombatImpactFrame")

	if effect and not effect:IsA("ColorCorrectionEffect") then
		effect = nil
	end

	if not effect then
		effect = Instance.new("ColorCorrectionEffect")
		effect.Name = "CombatImpactFrame"
		effect.Enabled = false
		effect.Parent = Lighting
	end

	return effect
end

local function playImpactFrame(payload)
	local effect = getImpactFrameEffect()

	impactFrameToken += 1
	local token = impactFrameToken

	local holdTime = typeof(payload.Duration) == "number" and math.max(0.01, payload.Duration) or 0.18
	local inTime = typeof(payload.InTime) == "number" and math.max(0, payload.InTime) or 0.035
	local outTime = typeof(payload.OutTime) == "number" and math.max(0.01, payload.OutTime) or 0.18

	local tintColor = typeof(payload.Color) == "Color3" and payload.Color or Color3.new(1, 1, 1)
	local contrast = typeof(payload.Contrast) == "number" and payload.Contrast or 0.45
	local saturation = typeof(payload.Saturation) == "number" and payload.Saturation or -0.2
	local brightness = typeof(payload.Brightness) == "number" and payload.Brightness or 0.05

	if impactFrameTween then
		impactFrameTween:Cancel()
		impactFrameTween = nil
	end

	effect.Enabled = true
	effect.TintColor = Color3.new(1, 1, 1)
	effect.Contrast = 0
	effect.Saturation = 0
	effect.Brightness = 0

	local tweenIn = TweenService:Create(
		effect,
		TweenInfo.new(inTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			TintColor = tintColor,
			Contrast = contrast,
			Saturation = saturation,
			Brightness = brightness,
		}
	)

	impactFrameTween = tweenIn
	tweenIn:Play()

	tweenIn.Completed:Connect(function()
		if token ~= impactFrameToken then return end

		task.delay(holdTime, function()
			if token ~= impactFrameToken then return end
			if not effect or not effect.Parent then return end

			local tweenOut = TweenService:Create(
				effect,
				TweenInfo.new(outTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					TintColor = Color3.new(1, 1, 1),
					Contrast = 0,
					Saturation = 0,
					Brightness = 0,
				}
			)

			impactFrameTween = tweenOut
			tweenOut:Play()

			tweenOut.Completed:Connect(function()
				if token ~= impactFrameToken then return end
				if not effect or not effect.Parent then return end

				effect.Enabled = false
				effect.TintColor = Color3.new(1, 1, 1)
				effect.Contrast = 0
				effect.Saturation = 0
				effect.Brightness = 0
				impactFrameTween = nil
			end)
		end)
	end)
end

local function playFOVPunch(targetFOV, inTime, outTime, holdTime)
	local camera = getCamera()
	if not camera then return end

	fovPunchToken += 1
	local token = fovPunchToken

	if fovOffsetTween then
		fovOffsetTween:Cancel()
		fovOffsetTween = nil
	end

	local originalFOV = fovPunchBaseFOV or getSustainedFOVTarget(camera) or camera.FieldOfView
	fovPunchBaseFOV = originalFOV

	if fovPunchInTween then
		fovPunchInTween:Cancel()
		fovPunchInTween = nil
	end

	if fovPunchOutTween then
		fovPunchOutTween:Cancel()
		fovPunchOutTween = nil
	end

	targetFOV = typeof(targetFOV) == "number" and math.clamp(targetFOV, 1, 120) or math.max(1, originalFOV - 6)
	inTime = typeof(inTime) == "number" and math.max(0, inTime) or 0.08
	holdTime = typeof(holdTime) == "number" and math.max(0, holdTime) or 0
	outTime = typeof(outTime) == "number" and math.max(0, outTime) or 0.35

	fovPunchInTween = TweenService:Create(
		camera,
		TweenInfo.new(inTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			FieldOfView = targetFOV,
		}
	)

	fovPunchInTween.Completed:Connect(function()
		if token ~= fovPunchToken then return end

		task.delay(holdTime, function()
			if token ~= fovPunchToken then return end
			if not camera or not camera.Parent then return end

			fovPunchOutTween = TweenService:Create(
				camera,
				TweenInfo.new(outTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					FieldOfView = getSustainedFOVTarget(camera) or originalFOV,
				}
			)

			fovPunchOutTween.Completed:Connect(function()
				if token ~= fovPunchToken then return end
				if camera and camera.Parent then
					camera.FieldOfView = getSustainedFOVTarget(camera) or originalFOV
				end

				fovPunchBaseFOV = nil
				fovPunchOutTween = nil
			end)

			fovPunchOutTween:Play()
			fovPunchInTween = nil
		end)
	end)

	fovPunchInTween:Play()
end

RunService:BindToRenderStep("CombatCameraShake", Enum.RenderPriority.Camera.Value + 1, function()
	local camera = getCamera()
	if not camera then return end

	if lastShakeTransform ~= CFrame.new() then
		camera.CFrame = camera.CFrame * lastShakeTransform:Inverse()
		lastShakeTransform = CFrame.new()
	end

	if #activeCameraShakes == 0 then
		return
	end

	local now = os.clock()
	local totalOffset = Vector3.zero

	for index = #activeCameraShakes, 1, -1 do
		local shake = activeCameraShakes[index]
		local elapsed = now - shake.StartTime

		if elapsed >= shake.Duration then
			table.remove(activeCameraShakes, index)
		else
			local alpha = 1 - math.clamp(elapsed / shake.Duration, 0, 1)
			local time = (elapsed * shake.Roughness) + shake.Seed

			local offset = Vector3.new(
				math.noise(time, 0, 0),
				math.noise(0, time, 0),
				math.noise(0, 0, time)
			)

			totalOffset += offset * shake.Intensity * alpha * 0.18
		end
	end

	if totalOffset.Magnitude > 0 then
		lastShakeTransform = CFrame.new(totalOffset)
		camera.CFrame = camera.CFrame * lastShakeTransform
	end
end)

cinematicRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end

	if payload.Action == "SetCamera" and typeof(payload.CFrame) == "CFrame" then
		setCinematicCamera(payload.CFrame)

	elseif payload.Action == "TweenCamera" and typeof(payload.CFrame) == "CFrame" then
		tweenCinematicCamera(payload.CFrame, payload.Time or 0.25)

	elseif payload.Action == "ResetCamera" then
		resetCinematicCamera()

	elseif payload.Action == "CameraShakeOnce" then
		startCameraShake(payload.Intensity, payload.Roughness, payload.Duration)

	elseif payload.Action == "ImpactFrame" then
		playImpactFrame(payload)

	elseif payload.Action == "FOVPunch" then
		playFOVPunch(payload.TargetFOV, payload.InTime, payload.OutTime, payload.HoldTime)

	elseif payload.Action == "SetFOVOffset" then
		setFOVOffset(payload.Id, payload.Amount, payload.TweenTime)

	elseif payload.Action == "ClearFOVOffset" then
		clearFOVOffset(payload.Id, payload.TweenTime)

	elseif payload.Action == "ResetFOV" then
		resetFOV(payload.TweenTime)
	end
end)

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

	character:GetAttributeChangedSignal("CombatMode"):Connect(function()
		refreshMoveDisplay()
		updateUltimateBar()
	end)

	character:GetAttributeChangedSignal("Guardbroken"):Connect(function()
		if character:GetAttribute("Guardbroken") then
			clearLocalBlockState(false)
		end
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
