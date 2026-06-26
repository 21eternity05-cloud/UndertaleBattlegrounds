local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- TODO: Redesign with Undertale-style black panels, thick white borders, square corners, and pixel typography.

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local emoteRemote = remotes:WaitForChild("EmoteRemote")
local progressionRemote = remotes:WaitForChild("ProgressionRemote")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EmoteData = require(Shared:WaitForChild("EmoteData"))

local MAX_SLOTS = 8
local WHEEL_KEY = Enum.KeyCode.R
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
local centerTitle = nil
local selectedSlot = 1
local selectedEmoteId = nil
local wheelOpen = false

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

local function highlightSelection(slot)
	selectedSlot = slot
	selectedEmoteId = getEquippedEmote(slot)

	for index, button in pairs(buttons) do
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = index == slot and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(90, 90, 105)
			stroke.Thickness = index == slot and 2 or 1
		end

		button.BackgroundColor3 = index == slot
			and Color3.fromRGB(58, 58, 70)
			or Color3.fromRGB(28, 28, 34)
	end

	if centerTitle then
		local data = selectedEmoteId and EmoteData[selectedEmoteId]
		centerTitle.Text = data and (data.DisplayName or selectedEmoteId) or "Empty"
	end
end

local function refreshWheel()
	for slot = 1, MAX_SLOTS do
		local button = buttons[slot]
		if button then
			local emoteId = getEquippedEmote(slot)
			local data = emoteId and EmoteData[emoteId]

			button.Name = "Slot" .. tostring(slot)
			button.Text = data and (tostring(slot) .. "\n" .. (data.DisplayName or emoteId)) or (tostring(slot) .. "\nEmpty")
			button.TextColor3 = data and Color3.fromRGB(245, 245, 245) or Color3.fromRGB(145, 145, 158)
		end
	end

	highlightSelection(selectedSlot)
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
	gui.Parent = playerGui

	wheel = Instance.new("Frame")
	wheel.Name = "Wheel"
	wheel.AnchorPoint = Vector2.new(0.5, 0.5)
	wheel.Position = UDim2.fromScale(0.5, 0.5)
	wheel.Size = UDim2.fromOffset(360, 360)
	wheel.BackgroundTransparency = 1
	wheel.Parent = gui

	local center = Instance.new("Frame")
	center.Name = "Center"
	center.AnchorPoint = Vector2.new(0.5, 0.5)
	center.Position = UDim2.fromScale(0.5, 0.5)
	center.Size = UDim2.fromOffset(118, 118)
	center.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	center.BackgroundTransparency = 0.08
	center.BorderSizePixel = 0
	center.Parent = wheel

	local centerCorner = Instance.new("UICorner")
	centerCorner.CornerRadius = UDim.new(1, 0)
	centerCorner.Parent = center

	local centerStroke = Instance.new("UIStroke")
	centerStroke.Color = Color3.fromRGB(90, 90, 105)
	centerStroke.Thickness = 1
	centerStroke.Parent = center

	centerTitle = Instance.new("TextLabel")
	centerTitle.Name = "Title"
	centerTitle.BackgroundTransparency = 1
	centerTitle.Size = UDim2.fromScale(1, 1)
	centerTitle.Font = Enum.Font.GothamBold
	centerTitle.TextSize = 15
	centerTitle.TextColor3 = Color3.fromRGB(245, 245, 245)
	centerTitle.TextWrapped = true
	centerTitle.Text = "Emotes"
	centerTitle.Parent = center

	local radius = 128
	for index = 1, MAX_SLOTS do
		local angle = ((index - 1) / MAX_SLOTS) * math.pi * 2 - (math.pi / 2)
		local x = math.cos(angle) * radius
		local y = math.sin(angle) * radius

		local button = Instance.new("TextButton")
		button.Name = "Slot" .. tostring(index)
		button.AnchorPoint = Vector2.new(0.5, 0.5)
		button.Position = UDim2.new(0.5, x, 0.5, y)
		button.Size = UDim2.fromOffset(112, 54)
		button.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
		button.BorderSizePixel = 0
		button.AutoButtonColor = true
		button.Font = Enum.Font.GothamSemibold
		button.TextSize = 13
		button.TextWrapped = true
		button.TextColor3 = Color3.fromRGB(245, 245, 245)
		button.Text = tostring(index) .. "\nEmpty"
		button.Parent = wheel

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = button

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(90, 90, 105)
		stroke.Thickness = 1
		stroke.Parent = button

		button.MouseEnter:Connect(function()
			highlightSelection(index)
		end)

		button.MouseButton1Click:Connect(function()
			highlightSelection(index)
			if selectedEmoteId then
				requestPlay(selectedEmoteId)
			end
			gui.Enabled = false
			wheelOpen = false
			setMouseFreeMode(false)
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

	if offset.Magnitude < 36 then
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
	if gameProcessed then return end

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
