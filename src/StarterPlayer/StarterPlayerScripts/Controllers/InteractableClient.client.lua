local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local interactableRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("InteractableRemote")
local LoreFragmentData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Interactables"):WaitForChild("LoreFragmentData"))

local INTERACTABLE_TAG = "Interactable"
local DEFAULT_DISTANCE = 12
local INTERACT_DEBOUNCE = 0.25
local DEBUG_INTERACTABLE_PROMPT = false
local SILKSCREEN_FONT = Font.new("rbxassetid://12187371840")

local interactableInfo = {}
local currentTarget = nil
local currentPromptText = nil
local lastInteractTime = 0
local lastDebugPrint = 0

local function debugPromptFailure(reason, interactable, distance, maxDistance)
	if not DEBUG_INTERACTABLE_PROMPT then
		return
	end

	if not interactable or interactable.Name ~= "Lore_SaveStar_001" then
		return
	end

	local now = os.clock()
	if now - lastDebugPrint < 1 then
		return
	end
	lastDebugPrint = now

	print("[InteractableClient] Lore_SaveStar_001 prompt fail:", reason, "distance:", distance, "max:", maxDistance)
end

local function applyPromptFont(textObject)
	if not textObject then
		return
	end

	if not textObject:IsA("TextLabel")
		and not textObject:IsA("TextButton")
		and not textObject:IsA("TextBox")
	then
		return
	end

	local success = pcall(function()
		textObject.FontFace = SILKSCREEN_FONT
	end)

	if not success then
		textObject.Font = Enum.Font.Arcade
	end
end

local gui = Instance.new("ScreenGui")
gui.Name = "InteractablePromptGui"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 250
gui.Parent = playerGui

local prompt = Instance.new("Frame")
prompt.Name = "Prompt"
prompt.AnchorPoint = Vector2.new(0.5, 1)
prompt.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
prompt.BackgroundTransparency = 0.12
prompt.BorderSizePixel = 0
prompt.Size = UDim2.fromOffset(150, 38)
prompt.Visible = false
prompt.Parent = gui

local promptCorner = Instance.new("UICorner")
promptCorner.CornerRadius = UDim.new(0, 6)
promptCorner.Parent = prompt

local promptStroke = Instance.new("UIStroke")
promptStroke.Color = Color3.fromRGB(245, 245, 245)
promptStroke.Thickness = 1
promptStroke.Transparency = 0.15
promptStroke.Parent = prompt

local keyBox = Instance.new("TextLabel")
keyBox.Name = "KeyBox"
keyBox.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
keyBox.BorderSizePixel = 0
keyBox.Position = UDim2.fromOffset(8, 7)
keyBox.Size = UDim2.fromOffset(24, 24)
keyBox.Font = Enum.Font.Arcade
keyBox.Text = "E"
keyBox.TextColor3 = Color3.fromRGB(10, 10, 12)
keyBox.TextSize = 15
keyBox.Parent = prompt
applyPromptFont(keyBox)

local keyCorner = Instance.new("UICorner")
keyCorner.CornerRadius = UDim.new(0, 4)
keyCorner.Parent = keyBox

local promptText = Instance.new("TextLabel")
promptText.Name = "PromptText"
promptText.BackgroundTransparency = 1
promptText.Position = UDim2.fromOffset(40, 0)
promptText.Size = UDim2.new(1, -48, 1, 0)
promptText.Font = Enum.Font.Arcade
promptText.Text = ""
promptText.TextColor3 = Color3.fromRGB(255, 255, 255)
promptText.TextSize = 15
promptText.TextWrapped = true
promptText.TextXAlignment = Enum.TextXAlignment.Left
promptText.Parent = prompt
applyPromptFont(promptText)

local function getCharacterRoot()
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function getNumberAttribute(instance, name, defaultValue)
	local value = instance:GetAttribute(name)
	if typeof(value) == "number" then
		return value
	end

	return defaultValue
end

local function getPromptPart(instance)
	if not instance then
		return nil
	end

	if instance:IsA("BasePart") then
		return instance
	end

	if not instance:IsA("Model") and not instance:IsA("Folder") then
		return nil
	end

	local displayPart = instance:FindFirstChild("DisplayPart")
	if displayPart and displayPart:IsA("BasePart") then
		return displayPart
	end

	if instance:IsA("Model") and instance.PrimaryPart and instance.PrimaryPart:IsA("BasePart") then
		return instance.PrimaryPart
	end

	for _, child in ipairs(instance:GetChildren()) do
		if child:IsA("BasePart") then
			return child
		end
	end

	return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function getPromptText(interactable)
	local interactableId = interactable:GetAttribute("InteractableId")
	if typeof(interactableId) == "string" and interactableId ~= "" then
		local fragment = LoreFragmentData[interactableId]
		if typeof(fragment) == "table"
			and typeof(fragment.DisplayPromptText) == "string"
			and fragment.DisplayPromptText ~= ""
		then
			return fragment.DisplayPromptText
		end
	end

	local displayPromptText = interactable:GetAttribute("DisplayPromptText")
	if typeof(displayPromptText) == "string" and displayPromptText ~= "" then
		return displayPromptText
	end

	local promptAttribute = interactable:GetAttribute("PromptText")
	if typeof(promptAttribute) == "string" and promptAttribute ~= "" then
		promptAttribute = string.gsub(promptAttribute, "^%s*[Ee]%s*%-?%s*", " - ")
		return promptAttribute
	end

	return " - INTERACT"
end

local function cacheInteractable(instance)
	if not instance then
		return
	end

	local promptPart = getPromptPart(instance)
	if not promptPart then
		debugPromptFailure("missing prompt part", instance, nil, nil)
		return
	end

	interactableInfo[instance] = {
		PromptPart = promptPart,
		InteractDistance = getNumberAttribute(instance, "InteractDistance", DEFAULT_DISTANCE),
		LookRequired = instance:GetAttribute("LookRequired") == true,
		LookDot = math.min(getNumberAttribute(instance, "LookDot", 0.65), 0.75),
		PromptText = getPromptText(instance),
	}

	if DEBUG_INTERACTABLE_PROMPT then
		print("[InteractableClient] Cached", instance:GetFullName(), "PromptPart:", promptPart:GetFullName())
	end
end

local function uncacheInteractable(instance)
	interactableInfo[instance] = nil

	if currentTarget == instance then
		currentTarget = nil
		currentPromptText = nil
		prompt.Visible = false
	end
end

local function isDialogueOpen()
	return player:GetAttribute("LoreDialogueOpen") == true
end

local function passesLookCheck(camera, promptPart, info)
	if not info.LookRequired then
		return true
	end

	local viewportPosition, onScreen = camera:WorldToViewportPoint(promptPart.Position)
	if not onScreen or viewportPosition.Z <= 0 then
		return false
	end

	local viewportSize = camera.ViewportSize
	local screenCenter = viewportSize / 2
	local point2D = Vector2.new(viewportPosition.X, viewportPosition.Y)

	local distanceFromCenter = (point2D - screenCenter).Magnitude
	local allowedRadius = math.min(viewportSize.X, viewportSize.Y) * 0.28

	if distanceFromCenter <= allowedRadius then
		return true
	end

	local directionToPart = promptPart.Position - camera.CFrame.Position
	if directionToPart.Magnitude <= 0.05 then
		return true
	end

	local requestedDot = info.LookDot or 0.65
	local forgivingDot = math.min(requestedDot, 0.65)

	return camera.CFrame.LookVector:Dot(directionToPart.Unit) >= forgivingDot
end

local function getBestInteractable(camera)
	local root = getCharacterRoot()
	if not root then
		for interactable in pairs(interactableInfo) do
			debugPromptFailure("missing root", interactable, nil, nil)
		end
		return nil, nil
	end

	local bestInteractable = nil
	local bestPart = nil
	local bestDistance = math.huge

	for interactable, info in pairs(interactableInfo) do
		local promptPart = info.PromptPart
		if not interactable:IsDescendantOf(workspace) or not promptPart or not promptPart:IsDescendantOf(workspace) then
			debugPromptFailure("not in workspace", interactable, nil, info.InteractDistance)
			uncacheInteractable(interactable)
		else
			local distance = (root.Position - promptPart.Position).Magnitude
			if distance > info.InteractDistance then
				debugPromptFailure("too far", interactable, distance, info.InteractDistance)
			elseif not passesLookCheck(camera, promptPart, info) then
				debugPromptFailure("failed look check", interactable, distance, info.InteractDistance)
			elseif distance < bestDistance then
				bestInteractable = interactable
				bestPart = promptPart
				bestDistance = distance
			end
		end
	end

	return bestInteractable, bestPart
end

local function hidePrompt()
	currentTarget = nil
	currentPromptText = nil
	prompt.Visible = false
end

local function updatePrompt()
	local camera = workspace.CurrentCamera
	if isDialogueOpen() or not camera then
		if not camera then
			for interactable in pairs(interactableInfo) do
				debugPromptFailure("missing camera", interactable, nil, nil)
			end
		end

		hidePrompt()
		return
	end

	local target, promptPart = getBestInteractable(camera)
	if not target or not promptPart then
		hidePrompt()
		return
	end

	local viewportPosition, onScreen = camera:WorldToViewportPoint(promptPart.Position)
	if not onScreen or viewportPosition.Z <= 0 then
		debugPromptFailure("offscreen", target, nil, nil)
		hidePrompt()
		return
	end

	local info = interactableInfo[target]
	local nextPromptText = info and info.PromptText or getPromptText(target)
	if currentTarget ~= target or currentPromptText ~= nextPromptText then
		currentPromptText = nextPromptText
		promptText.Text = nextPromptText
	end

	currentTarget = target
	prompt.Position = UDim2.fromOffset(viewportPosition.X, viewportPosition.Y)
	prompt.Visible = true
end

local function requestInteract()
	if isDialogueOpen() or not currentTarget then
		return
	end

	local now = os.clock()
	if now - lastInteractTime < INTERACT_DEBOUNCE then
		return
	end
	lastInteractTime = now

	interactableRemote:FireServer("Interact", currentTarget)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.E then
		requestInteract()
	end
end)

for _, instance in ipairs(CollectionService:GetTagged(INTERACTABLE_TAG)) do
	cacheInteractable(instance)
end

local function scanInteractablesFolder()
	local mapRoot = workspace:FindFirstChild("BattlegroundsMap")
	local hollowSnowdin = mapRoot and mapRoot:FindFirstChild("HollowSnowdin")
	local folder = hollowSnowdin and hollowSnowdin:FindFirstChild("Interactables")

	if not folder then
		return
	end

	for _, child in ipairs(folder:GetChildren()) do
		cacheInteractable(child)
	end
end

scanInteractablesFolder()

CollectionService:GetInstanceAddedSignal(INTERACTABLE_TAG):Connect(cacheInteractable)
CollectionService:GetInstanceRemovedSignal(INTERACTABLE_TAG):Connect(uncacheInteractable)

workspace.DescendantAdded:Connect(function(instance)
	if instance.Name == "Interactables" then
		task.defer(scanInteractablesFolder)
	elseif instance.Name == "Lore_SaveStar_001" then
		task.defer(cacheInteractable, instance)
	elseif instance.Name == "DisplayPart" and instance.Parent then
		task.defer(cacheInteractable, instance.Parent)
	elseif instance:IsA("BasePart") and instance.Parent and interactableInfo[instance.Parent] == nil then
		local parent = instance.Parent
		if parent.Name == "Lore_SaveStar_001" or parent:GetAttribute("InteractableType") ~= nil then
			task.defer(cacheInteractable, parent)
		end
	end
end)

RunService.RenderStepped:Connect(updatePrompt)
