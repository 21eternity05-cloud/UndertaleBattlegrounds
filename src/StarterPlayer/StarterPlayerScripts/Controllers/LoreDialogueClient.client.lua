local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local interactableRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("InteractableRemote")

local TYPE_DELAY = 0.026
local SILKSCREEN_FONT = Font.new("rbxassetid://12187371840")

local function applyDialogueFont(textObject)
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
gui.Name = "LoreDialogueGui"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 500
gui.Parent = playerGui

local dialogueBox = Instance.new("Frame")
dialogueBox.Name = "DialogueBox"
dialogueBox.AnchorPoint = Vector2.new(0.5, 1)
dialogueBox.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
dialogueBox.BackgroundTransparency = 0
dialogueBox.BorderSizePixel = 0
dialogueBox.Position = UDim2.fromScale(0.5, 0.965)
dialogueBox.Size = UDim2.new(0.88, 0, 0, 168)
dialogueBox.Visible = false
dialogueBox.Parent = gui

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MaxSize = Vector2.new(980, 190)
sizeConstraint.MinSize = Vector2.new(320, 148)
sizeConstraint.Parent = dialogueBox

local boxStroke = Instance.new("UIStroke")
boxStroke.Color = Color3.fromRGB(245, 245, 245)
boxStroke.Thickness = 12
boxStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
boxStroke.LineJoinMode = Enum.LineJoinMode.Miter
boxStroke.Parent = dialogueBox

local portraitFrame = Instance.new("ViewportFrame")
portraitFrame.Name = "Portrait"
portraitFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
portraitFrame.BorderSizePixel = 0
portraitFrame.Position = UDim2.fromOffset(18, 18)
portraitFrame.Size = UDim2.fromOffset(118, 118)
portraitFrame.Ambient = Color3.fromRGB(220, 220, 220)
portraitFrame.LightColor = Color3.fromRGB(255, 255, 235)
portraitFrame.Parent = dialogueBox

local speakerLabel = Instance.new("TextLabel")
speakerLabel.Name = "Speaker"
speakerLabel.BackgroundTransparency = 1
speakerLabel.Font = Enum.Font.Arcade
speakerLabel.Position = UDim2.fromOffset(154, 18)
speakerLabel.Size = UDim2.new(1, -188, 0, 24)
speakerLabel.TextColor3 = Color3.fromRGB(255, 226, 126)
speakerLabel.TextSize = 18
speakerLabel.TextXAlignment = Enum.TextXAlignment.Left
speakerLabel.Parent = dialogueBox
applyDialogueFont(speakerLabel)

local textLabel = Instance.new("TextLabel")
textLabel.Name = "Text"
textLabel.BackgroundTransparency = 1
textLabel.Font = Enum.Font.Arcade
textLabel.Position = UDim2.fromOffset(154, 50)
textLabel.Size = UDim2.new(1, -188, 0, 82)
textLabel.TextColor3 = Color3.fromRGB(245, 245, 248)
textLabel.TextSize = 20
textLabel.TextWrapped = true
textLabel.TextXAlignment = Enum.TextXAlignment.Left
textLabel.TextYAlignment = Enum.TextYAlignment.Top
textLabel.Parent = dialogueBox
applyDialogueFont(textLabel)

local continueLabel = Instance.new("TextLabel")
continueLabel.Name = "Continue"
continueLabel.AnchorPoint = Vector2.new(1, 1)
continueLabel.BackgroundTransparency = 1
continueLabel.Font = Enum.Font.Arcade
continueLabel.Position = UDim2.new(1, -18, 1, -12)
continueLabel.Size = UDim2.fromOffset(36, 24)
continueLabel.Text = "..."
continueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
continueLabel.TextSize = 18
continueLabel.Visible = false
continueLabel.Parent = dialogueBox
applyDialogueFont(continueLabel)

local portraitWorld = nil
local portraitCamera = nil
local active = false
local typing = false
local finishRequested = false
local advanceRequested = false
local dialogueToken = 0
local textSoundCache = {}
local eventSoundCache = {}

local function clearPortrait()
	for _, child in ipairs(portraitFrame:GetChildren()) do
		child:Destroy()
	end

	portraitWorld = Instance.new("WorldModel")
	portraitWorld.Parent = portraitFrame

	portraitCamera = Instance.new("Camera")
	portraitCamera.CFrame = CFrame.new(Vector3.new(0, 0, 6), Vector3.zero)
	portraitCamera.Parent = portraitFrame
	portraitFrame.CurrentCamera = portraitCamera
end

local function addFallbackPortrait(portraitName)
	clearPortrait()

	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.Neon
	part.Position = Vector3.zero

	if portraitName == "SaveStar" then
		part.Name = "SaveStarFallback"
		part.Color = Color3.fromRGB(255, 221, 71)
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(2.2, 2.2, 0.5)
	else
		part.Name = "UnknownFallback"
		part.Color = Color3.fromRGB(18, 18, 24)
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(2.1, 2.5, 0.7)
	end

	part.Parent = portraitWorld
end

local function setPortrait(portraitName)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local portraitAsset = assets and assets:FindFirstChild(portraitName, true)

	if portraitAsset and (portraitAsset:IsA("Model") or portraitAsset:IsA("BasePart")) then
		clearPortrait()

		local clone = portraitAsset:Clone()
		clone.Parent = portraitWorld

		if clone:IsA("Model") then
			clone:PivotTo(CFrame.new())
		elseif clone:IsA("BasePart") then
			clone.Anchored = true
			clone.CFrame = CFrame.new()
		end

		return
	end

	addFallbackPortrait(portraitName)
end

local function getDialogueSoundFolder(folderName)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local ui = assets and assets:FindFirstChild("UI")
	local dialogue = ui and ui:FindFirstChild("Dialogue")

	return dialogue and dialogue:FindFirstChild(folderName)
end

local function collectFolderSounds(folder)
	local sounds = {}

	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Sound") then
			table.insert(sounds, child)
		end
	end

	table.sort(sounds, function(left, right)
		local leftNumber = tonumber(left.Name)
		local rightNumber = tonumber(right.Name)

		if leftNumber and rightNumber then
			return leftNumber < rightNumber
		end

		if leftNumber then
			return true
		end

		if rightNumber then
			return false
		end

		return left.Name < right.Name
	end)

	return sounds
end

local function getSoundEntry(cache, folderName, soundName)
	if typeof(soundName) ~= "string" or soundName == "" then
		return nil
	end

	if cache[soundName] then
		return cache[soundName]
	end

	local soundFolder = getDialogueSoundFolder(folderName)
	local soundObject = soundFolder and soundFolder:FindFirstChild(soundName)

	if not soundObject then
		return nil
	end

	if soundObject:IsA("Sound") then
		cache[soundName] = {
			Kind = "Sound",
			Sound = soundObject,
		}

		return cache[soundName]
	end

	if soundObject:IsA("Folder") then
		local sounds = collectFolderSounds(soundObject)
		if #sounds == 0 then
			return nil
		end

		cache[soundName] = {
			Kind = "Folder",
			Sounds = sounds,
		}

		return cache[soundName]
	end

	return nil
end

local function playSound(soundTemplate)
	if not soundTemplate or not soundTemplate:IsA("Sound") then
		return nil
	end

	local sound = soundTemplate:Clone()
	sound.Parent = gui
	sound:Play()

	sound.Ended:Connect(function()
		sound:Destroy()
	end)

	Debris:AddItem(sound, 3)

	return sound
end

local function playSoundEntry(entry)
	if not entry then
		return
	end

	if entry.Kind == "Sound" then
		playSound(entry.Sound)
	elseif entry.Kind == "Folder" and entry.Sounds and #entry.Sounds > 0 then
		local index = math.random(1, #entry.Sounds)
		local soundTemplate = entry.Sounds[index]

		playSound(soundTemplate)
	end
end

local function playNamedDialogueSound(cache, folderName, soundName)
	playSoundEntry(getSoundEntry(cache, folderName, soundName))
end

local function playTextTick(soundName)
	playNamedDialogueSound(textSoundCache, "TextSounds", soundName)
end

local function playEventSound(soundName)
	playNamedDialogueSound(eventSoundCache, "EventSounds", soundName)
end

local function playLineEventSounds(singleSound, soundList)
	if typeof(singleSound) == "string" then
		playEventSound(singleSound)
	end

	if typeof(soundList) ~= "table" then
		return
	end

	for _, soundName in ipairs(soundList) do
		if typeof(soundName) == "string" then
			playEventSound(soundName)
		end
	end
end

local function closeDialogue()
	active = false
	typing = false
	finishRequested = false
	advanceRequested = false
	dialogueToken += 1
	dialogueBox.Visible = false
	continueLabel.Visible = false
	player:SetAttribute("LoreDialogueOpen", false)
end

local function requestContinue()
	if not active then
		return
	end

	if typing then
		finishRequested = true
	else
		advanceRequested = true
	end
end

local function typeLine(line, token)
	local text = ""
	if typeof(line.Text) == "string" then
		text = line.Text
	end

	speakerLabel.Text = line.Speaker or "???"
	textLabel.Text = ""
	continueLabel.Visible = false
	setPortrait(line.Portrait or "Unknown")
	playLineEventSounds(line.StartSound, line.StartSounds)

	typing = true
	finishRequested = false

	for index = 1, #text do
		if token ~= dialogueToken or not active then
			return false
		end

		if finishRequested then
			break
		end

		textLabel.Text = string.sub(text, 1, index)

		local character = string.sub(text, index, index)
		if character ~= " " and index % 2 == 0 then
			playTextTick(line.TextSound)
		end

		task.wait(TYPE_DELAY)
	end

	textLabel.Text = text
	if token ~= dialogueToken or not active then
		return false
	end

	playLineEventSounds(line.EndSound, line.EndSounds)

	typing = false
	finishRequested = false
	advanceRequested = false
	continueLabel.Visible = true

	while token == dialogueToken and active and not advanceRequested do
		task.wait()
	end

	return token == dialogueToken and active
end

local function playDialogue(payload)
	if active then
		return
	end

	local lines = payload.Lines
	if typeof(lines) ~= "table" or #lines == 0 then
		return
	end

	active = true
	dialogueToken += 1
	local token = dialogueToken
	player:SetAttribute("LoreDialogueOpen", true)
	dialogueBox.Visible = true

	task.spawn(function()
		for _, line in ipairs(lines) do
			if typeof(line) == "table" then
				local shouldContinue = typeLine(line, token)
				if not shouldContinue then
					return
				end
			end
		end

		if token == dialogueToken then
			closeDialogue()
		end
	end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end

	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Space or input.UserInputType == Enum.UserInputType.MouseButton1 then
		requestContinue()
	end
end)

interactableRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	if payload.Action == "ShowLoreDialogue" then
		playDialogue(payload)
	end
end)
