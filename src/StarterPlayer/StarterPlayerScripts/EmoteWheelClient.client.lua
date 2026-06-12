local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local emoteRemote = remotes:WaitForChild("EmoteRemote")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EmoteData = require(Shared:WaitForChild("EmoteData"))

local EMOTE_ORDER = {
	"DefaultDance",
	"TPose",
	"Headless",
	"Spin",
	"LoudLaugh",
	"CleanGroove",
}

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
local selectedEmoteId = nil
local wheelOpen = false

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

local function highlightSelection(emoteId)
	selectedEmoteId = emoteId

	for id, button in pairs(buttons) do
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = id == emoteId and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(90, 90, 105)
			stroke.Thickness = id == emoteId and 2 or 1
		end

		button.BackgroundColor3 = id == emoteId
			and Color3.fromRGB(58, 58, 70)
			or Color3.fromRGB(28, 28, 34)
	end
end

local function createWheel()
	if gui then
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

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 1)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 15
	title.TextColor3 = Color3.fromRGB(245, 245, 245)
	title.TextWrapped = true
	title.Text = "Emotes"
	title.Parent = center

	local radius = 128
	for index, emoteId in ipairs(EMOTE_ORDER) do
		local data = EmoteData[emoteId] or {}
		local angle = ((index - 1) / #EMOTE_ORDER) * math.pi * 2 - (math.pi / 2)
		local x = math.cos(angle) * radius
		local y = math.sin(angle) * radius

		local button = Instance.new("TextButton")
		button.Name = emoteId
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
		button.Text = data.DisplayName or emoteId
		button.Parent = wheel

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = button

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(90, 90, 105)
		stroke.Thickness = 1
		stroke.Parent = button

		button.MouseEnter:Connect(function()
			highlightSelection(emoteId)
		end)

		button.MouseButton1Click:Connect(function()
			highlightSelection(emoteId)
			requestPlay(emoteId)
			gui.Enabled = false
			wheelOpen = false
		end)

		buttons[emoteId] = button
	end
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

	local index = math.floor((angle / (math.pi * 2)) * #EMOTE_ORDER + 0.5) + 1
	index = ((index - 1) % #EMOTE_ORDER) + 1

	highlightSelection(EMOTE_ORDER[index])
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

	selectedEmoteId = selectedEmoteId or EMOTE_ORDER[1]
	highlightSelection(selectedEmoteId)
	gui.Enabled = true
	wheelOpen = true
	selectFromMouse()
end

local function closeWheel(playSelection)
	if not gui or not wheelOpen then
		return
	end

	gui.Enabled = false
	wheelOpen = false

	if playSelection and selectedEmoteId then
		requestPlay(selectedEmoteId)
	end
end

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
end)

createWheel()
