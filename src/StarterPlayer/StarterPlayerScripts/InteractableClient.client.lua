local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera
local interactableRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("InteractableRemote")
local LoreFragmentData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Interactables"):WaitForChild("LoreFragmentData"))

local INTERACTABLE_TAG = "Interactable"
local DEFAULT_DISTANCE = 12
local PROMPT_UPDATE_INTERVAL = 0.05
local DEBUG_PERF = false
local SILKSCREEN_FONT = Font.new("rbxassetid://12187371840")
local trackedInteractables = {}
local interactableInfo = {}
local promptDebugCount = 0
local lastPromptDebugPrint = 0
local lastPromptUpdate = 0

local function debugRate(label)
	if not DEBUG_PERF then
		return
	end

	promptDebugCount += 1
	if os.clock() - lastPromptDebugPrint >= 5 then
		lastPromptDebugPrint = os.clock()
		print("[PERF]", label, "ran", promptDebugCount, "times in 5 seconds")
		promptDebugCount = 0
	end
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
promptText.Text = "..."
promptText.TextColor3 = Color3.fromRGB(255, 255, 255)
promptText.TextSize = 15
promptText.TextWrapped = true
promptText.TextXAlignment = Enum.TextXAlignment.Left
promptText.Parent = prompt
applyPromptFont(promptText)

local currentInteractable = nil
local currentPromptText = nil
local lastInteractTime = 0

local function getCharacterRoot()
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function getPromptPart(instance)
	if not instance then
		return nil
	end

	if instance:IsA("BasePart") then
		return instance
	end

	if not instance:IsA("Model") then
		return nil
	end

	local displayPart = instance:FindFirstChild("DisplayPart")
	if displayPart and displayPart:IsA("BasePart") then
		return displayPart
	end

	if instance.PrimaryPart then
		return instance.PrimaryPart
	end

	for _, child in ipairs(instance:GetChildren()) do
		if child:IsA("BasePart") then
			return child
		end
	end

	return nil
end

local function getNumberAttribute(instance, name, defaultValue)
	local value = instance:GetAttribute(name)
	if typeof(value) == "number" then
		return value
	end

	return defaultValue
end

local function isDialogueOpen()
	return player:GetAttribute("LoreDialogueOpen") == true
end

local function cacheInteractable(instance)
	if not instance or trackedInteractables[instance] then
		return
	end

	local promptPart = getPromptPart(instance)
	if not promptPart then
		return
	end

	trackedInteractables[instance] = true
	interactableInfo[instance] = {
		PromptPart = promptPart,
		InteractDistance = getNumberAttribute(instance, "InteractDistance", DEFAULT_DISTANCE),
		LookRequired = instance:GetAttribute("LookRequired") == true,
		LookDot = getNumberAttribute(instance, "LookDot", 0.82),
	}
end

local function uncacheInteractable(instance)
	trackedInteractables[instance] = nil
	interactableInfo[instance] = nil
end

local function isLookingAt(part, info)
	if not info.LookRequired then
		return true
	end

	local activeCamera = workspace.CurrentCamera
	if not activeCamera then
		return false
	end

	local offset = part.Position - activeCamera.CFrame.Position
	if offset.Magnitude < 0.05 then
		return true
	end

	return activeCamera.CFrame.LookVector:Dot(offset.Unit) >= info.LookDot
end

local function getPromptText(interactable)
	local interactableId = interactable:GetAttribute("InteractableId")
	if typeof(interactableId) == "string" then
		local fragment = LoreFragmentData[interactableId]
		if typeof(fragment) == "table" and typeof(fragment.DisplayPromptText) == "string" and fragment.DisplayPromptText ~= "" then
			return fragment.DisplayPromptText
		end
	end

	local attributeText = interactable:GetAttribute("PromptText")
	if typeof(attributeText) == "string" and attributeText ~= "" then
		return attributeText
	end

	return "E"
end

local function getBestInteractable()
	local root = getCharacterRoot()
	if not root then
		return nil, nil
	end

	local bestInteractable = nil
	local bestPart = nil
	local bestDistance = math.huge

	for interactable, info in pairs(interactableInfo) do
		local promptPart = info.PromptPart
		if not interactable:IsDescendantOf(workspace) or not promptPart or not promptPart:IsDescendantOf(workspace) then
			uncacheInteractable(interactable)
		else
			local distance = (root.Position - promptPart.Position).Magnitude

			if distance <= info.InteractDistance and distance < bestDistance and isLookingAt(promptPart, info) then
				bestInteractable = interactable
				bestPart = promptPart
				bestDistance = distance
			end
		end
	end

	return bestInteractable, bestPart
end

local function updatePrompt()
	debugRate("InteractableClient.updatePrompt")

	camera = workspace.CurrentCamera

	if isDialogueOpen() or not camera then
		currentInteractable = nil
		currentPromptText = nil
		prompt.Visible = false
		return
	end

	local previousInteractable = currentInteractable
	local interactable, part = getBestInteractable()
	currentInteractable = interactable

	if not interactable or not part then
		currentPromptText = nil
		prompt.Visible = false
		return
	end

	local viewportPosition, onScreen = camera:WorldToViewportPoint(part.Position)
	if not onScreen then
		currentPromptText = nil
		prompt.Visible = false
		return
	end

	if currentPromptText == nil or previousInteractable ~= interactable then
		currentPromptText = getPromptText(interactable)
		promptText.Text = currentPromptText
	end

	prompt.Position = UDim2.fromOffset(viewportPosition.X, viewportPosition.Y)
	prompt.Visible = true
end

local function requestInteract()
	if isDialogueOpen() or not currentInteractable then
		return
	end

	local now = os.clock()
	if now - lastInteractTime < 0.25 then
		return
	end
	lastInteractTime = now

	interactableRemote:FireServer("Interact", currentInteractable)
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

CollectionService:GetInstanceAddedSignal(INTERACTABLE_TAG):Connect(cacheInteractable)
CollectionService:GetInstanceRemovedSignal(INTERACTABLE_TAG):Connect(uncacheInteractable)

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	if now - lastPromptUpdate < PROMPT_UPDATE_INTERVAL then
		return
	end

	lastPromptUpdate = now
	updatePrompt()
end)
