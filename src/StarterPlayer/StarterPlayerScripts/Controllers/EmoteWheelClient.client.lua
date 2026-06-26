local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local emoteRemote = remotes:WaitForChild("EmoteRemote")
local progressionRemote = remotes:WaitForChild("ProgressionRemote")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EmoteData = require(Shared:WaitForChild("EmoteData"))

local MAX_SLOTS = 8
local WHEEL_KEY = Enum.KeyCode.R

local PIXEL_FONT = Enum.Font.Arcade

local UT_BLACK = Color3.fromRGB(0, 0, 0)
local UT_WHITE = Color3.fromRGB(255, 255, 255)
local UT_GRAY = Color3.fromRGB(145, 145, 145)
local UT_DARK_GRAY = Color3.fromRGB(42, 42, 42)
local UT_ORANGE = Color3.fromRGB(255, 150, 40)
local UT_YELLOW = Color3.fromRGB(255, 205, 50)

local MOVE_KEYS = {
	[Enum.KeyCode.W] = true,
	[Enum.KeyCode.A] = true,
	[Enum.KeyCode.S] = true,
	[Enum.KeyCode.D] = true,
}

local gui = nil
local wheel = nil
local buttons = {}
local equippedEmotes = {}

local centerPanel = nil
local centerSlotLabel = nil
local centerTitle = nil
local centerHint = nil

local selectedSlot = 1
local selectedEmoteId = nil
local wheelOpen = false

local function applyPixelFont(textObject)
	textObject.Font = PIXEL_FONT
end

local function addPixelStroke(instance, thickness, color)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or UT_WHITE
	stroke.Thickness = thickness or 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.LineJoinMode = Enum.LineJoinMode.Miter
	stroke.Parent = instance

	return stroke
end

local function setMouseFreeMode(active)
	player:SetAttribute("MouseFreeMode", active == true)
end

local function getCharacter()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if not character or not humanoid or humanoid.Health <= 0 then
		return nil
	end

	return character, humanoid
end

local function isEmoting()
	local character = player.Character
	return character and character:GetAttribute("Emoting") == true
end

local function requestCancel()
	emoteRemote:FireServer({
		Action = "CancelEmote",
	})
end

local function requestPlay(emoteId)
	if typeof(emoteId) ~= "string" then
		return
	end

	emoteRemote:FireServer({
		Action = "PlayEmote",
		EmoteId = emoteId,
	})
end

local function getEquippedEmote(slot)
	local emoteId = equippedEmotes[slot] or equippedEmotes[tostring(slot)]
	if typeof(emoteId) == "string" and EmoteData[emoteId] then
		return emoteId
	end

	return nil
end

local function setButtonSelected(button, selected, hasEmote)
	local stroke = button:FindFirstChildOfClass("UIStroke")

	if stroke then
		if selected then
			stroke.Color = hasEmote and UT_YELLOW or UT_ORANGE
			stroke.Thickness = 4
		else
			stroke.Color = hasEmote and UT_WHITE or UT_DARK_GRAY
			stroke.Thickness = 3
		end
	end

	if selected then
		button.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
		button.TextColor3 = hasEmote and UT_YELLOW or UT_ORANGE
	else
		button.BackgroundColor3 = UT_BLACK
		button.TextColor3 = hasEmote and UT_WHITE or UT_GRAY
	end
end

local function updateCenter()
	local data = selectedEmoteId and EmoteData[selectedEmoteId]

	if centerSlotLabel then
		centerSlotLabel.Text = "SLOT " .. tostring(selectedSlot or 1)
		centerSlotLabel.TextColor3 = data and UT_YELLOW or UT_ORANGE
	end

	if centerTitle then
		centerTitle.Text = data and string.upper(data.DisplayName or selectedEmoteId) or "EMPTY"
		centerTitle.TextColor3 = data and UT_WHITE or UT_GRAY
	end

	if centerHint then
		centerHint.Text = data and "RELEASE R\nTO EMOTE" or "CHOOSE\nAN EMOTE"
		centerHint.TextColor3 = data and UT_YELLOW or UT_GRAY
	end

	if centerPanel then
		local stroke = centerPanel:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = data and UT_WHITE or UT_DARK_GRAY
		end
	end
end

local function highlightSelection(slot)
	selectedSlot = slot
	selectedEmoteId = getEquippedEmote(slot)

	for index, button in pairs(buttons) do
		local hasEmote = getEquippedEmote(index) ~= nil
		setButtonSelected(button, index == slot, hasEmote)
	end

	updateCenter()
end

local function refreshWheel()
	for slot = 1, MAX_SLOTS do
		local button = buttons[slot]
		if button then
			local emoteId = getEquippedEmote(slot)
			local data = emoteId and EmoteData[emoteId]

			button.Name = "Slot" .. tostring(slot)

			if data then
				button.Text = tostring(slot) .. "\n" .. string.upper(data.DisplayName or emoteId)
				button.TextColor3 = UT_WHITE
			else
				button.Text = tostring(slot) .. "\nEMPTY"
				button.TextColor3 = UT_GRAY
			end
		end
	end

	highlightSelection(selectedSlot or 1)
end

local function closeWheel(playSelection)
	if not gui or not wheelOpen then
		return
	end

	gui.Enabled = false
	wheelOpen = false
	setMouseFreeMode(false)

	if playSelection and selectedEmoteId then
		requestPlay(selectedEmoteId)
	end
end

local function createWheel()
	if gui then
		refreshWheel()
		return
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "EmoteWheelGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	gui.DisplayOrder = 50
	gui.Parent = playerGui

	wheel = Instance.new("Frame")
	wheel.Name = "Wheel"
	wheel.AnchorPoint = Vector2.new(0.5, 0.5)
	wheel.Position = UDim2.fromScale(0.5, 0.5)
	wheel.Size = UDim2.fromOffset(440, 440)
	wheel.BackgroundTransparency = 1
	wheel.BorderSizePixel = 0
	wheel.Parent = gui

	centerPanel = Instance.new("Frame")
	centerPanel.Name = "Description"
	centerPanel.AnchorPoint = Vector2.new(0.5, 0.5)
	centerPanel.Position = UDim2.fromScale(0.5, 0.5)
	centerPanel.Size = UDim2.fromOffset(132, 132)
	centerPanel.BackgroundColor3 = UT_BLACK
	centerPanel.BackgroundTransparency = 0
	centerPanel.BorderSizePixel = 0
	centerPanel.ZIndex = 5
	centerPanel.Parent = wheel
	addPixelStroke(centerPanel, 4, UT_WHITE)

	centerSlotLabel = Instance.new("TextLabel")
	centerSlotLabel.Name = "SlotLabel"
	centerSlotLabel.BackgroundTransparency = 1
	centerSlotLabel.AnchorPoint = Vector2.new(0.5, 0)
	centerSlotLabel.Position = UDim2.new(0.5, 0, 0, 12)
	centerSlotLabel.Size = UDim2.new(1, -14, 0, 18)
	applyPixelFont(centerSlotLabel)
	centerSlotLabel.TextSize = 9
	centerSlotLabel.TextColor3 = UT_YELLOW
	centerSlotLabel.TextWrapped = true
	centerSlotLabel.TextXAlignment = Enum.TextXAlignment.Center
	centerSlotLabel.TextYAlignment = Enum.TextYAlignment.Center
	centerSlotLabel.Text = "SLOT 1"
	centerSlotLabel.ZIndex = 6
	centerSlotLabel.Parent = centerPanel

	centerTitle = Instance.new("TextLabel")
	centerTitle.Name = "SelectedLabel"
	centerTitle.BackgroundTransparency = 1
	centerTitle.AnchorPoint = Vector2.new(0.5, 0.5)
	centerTitle.Position = UDim2.fromScale(0.5, 0.45)
	centerTitle.Size = UDim2.new(1, -16, 0, 40)
	applyPixelFont(centerTitle)
	centerTitle.TextSize = 12
	centerTitle.TextColor3 = UT_WHITE
	centerTitle.TextWrapped = true
	centerTitle.TextXAlignment = Enum.TextXAlignment.Center
	centerTitle.TextYAlignment = Enum.TextYAlignment.Center
	centerTitle.Text = "EMOTES"
	centerTitle.ZIndex = 6
	centerTitle.Parent = centerPanel

	centerHint = Instance.new("TextLabel")
	centerHint.Name = "Hint"
	centerHint.BackgroundTransparency = 1
	centerHint.AnchorPoint = Vector2.new(0.5, 1)
	centerHint.Position = UDim2.new(0.5, 0, 1, -12)
	centerHint.Size = UDim2.new(1, -14, 0, 34)
	applyPixelFont(centerHint)
	centerHint.TextSize = 8
	centerHint.TextColor3 = UT_YELLOW
	centerHint.TextWrapped = true
	centerHint.TextXAlignment = Enum.TextXAlignment.Center
	centerHint.TextYAlignment = Enum.TextYAlignment.Center
	centerHint.Text = "HOLD R"
	centerHint.ZIndex = 6
	centerHint.Parent = centerPanel

	local radius = 158
	local buttonSize = Vector2.new(112, 56)

	for index = 1, MAX_SLOTS do
		local angle = ((index - 1) / MAX_SLOTS) * math.pi * 2 - (math.pi / 2)
		local x = math.cos(angle) * radius
		local y = math.sin(angle) * radius

		local button = Instance.new("TextButton")
		button.Name = "Slot" .. tostring(index)
		button.AnchorPoint = Vector2.new(0.5, 0.5)
		button.Position = UDim2.new(0.5, x, 0.5, y)
		button.Size = UDim2.fromOffset(buttonSize.X, buttonSize.Y)
		button.BackgroundColor3 = UT_BLACK
		button.BackgroundTransparency = 0
		button.BorderSizePixel = 0
		button.AutoButtonColor = false
		applyPixelFont(button)
		button.TextSize = 10
		button.TextWrapped = true
		button.TextColor3 = UT_GRAY
		button.TextXAlignment = Enum.TextXAlignment.Center
		button.TextYAlignment = Enum.TextYAlignment.Center
		button.Text = tostring(index) .. "\nEMPTY"
		button.ZIndex = 3
		button.Parent = wheel

		addPixelStroke(button, 3, UT_DARK_GRAY)

		button.MouseEnter:Connect(function()
			if wheelOpen then
				highlightSelection(index)
			end
		end)

		button.MouseButton1Click:Connect(function()
			if not wheelOpen then
				return
			end

			highlightSelection(index)
			closeWheel(true)
		end)

		buttons[index] = button
	end

	refreshWheel()
end

local function selectFromMouse()
	if not wheelOpen or not wheel then
		return
	end

	local mouse = UserInputService:GetMouseLocation()
	local center = wheel.AbsolutePosition + (wheel.AbsoluteSize / 2)
	local offset = mouse - center

	if offset.Magnitude < 62 then
		return
	end

	local angle = math.atan2(offset.Y, offset.X) + (math.pi / 2)
	if angle < 0 then
		angle += math.pi * 2
	end

	local index = math.floor((angle / (math.pi * 2)) * MAX_SLOTS + 0.5) + 1
	index = ((index - 1) % MAX_SLOTS) + 1

	highlightSelection(index)
end

local function openWheel()
	createWheel()

	if isEmoting() then
		requestCancel()
		return
	end

	if not getCharacter() then
		return
	end

	highlightSelection(selectedSlot or 1)

	gui.Enabled = true
	wheelOpen = true
	setMouseFreeMode(true)

	selectFromMouse()
end

progressionRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	local snapshot = payload.Profile
	if typeof(snapshot) ~= "table" then
		return
	end

	equippedEmotes = typeof(snapshot.EquippedEmotes) == "table" and snapshot.EquippedEmotes or {}
	refreshWheel()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == WHEEL_KEY then
		openWheel()
	elseif MOVE_KEYS[input.KeyCode] and isEmoting() then
		local character = player.Character
		local emoteId = character and character:GetAttribute("CurrentEmote")
		local data = emoteId and EmoteData[emoteId]

		if data and data.CancelOnMove == true then
			requestCancel()
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == WHEEL_KEY then
		closeWheel(true)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		selectFromMouse()
	end
end)

UserInputService.JumpRequest:Connect(function()
	if isEmoting() then
		requestCancel()
	end
end)

player.CharacterAdded:Connect(function()
	closeWheel(false)
	setMouseFreeMode(false)
end)

createWheel()

progressionRemote:FireServer({
	Action = "RequestSnapshot",
})