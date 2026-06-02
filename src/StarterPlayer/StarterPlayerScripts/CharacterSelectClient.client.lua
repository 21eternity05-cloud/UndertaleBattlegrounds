local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local characterRemote = remotes:WaitForChild("CharacterRemote")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CharacterSelectGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Name = "CharacterFrame"
frame.Size = UDim2.fromOffset(190, 120)
frame.Position = UDim2.new(0, 20, 0.5, -60)
frame.BackgroundTransparency = 0.25
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
frame.BorderSizePixel = 0
frame.Parent = screenGui

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.fromOffset(170, 25)
title.Position = UDim2.fromOffset(10, 5)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Text = "Characters"
title.Parent = frame

local function makeButton(name, yPosition)
	local button = Instance.new("TextButton")
	button.Name = name .. "Button"
	button.Size = UDim2.fromOffset(160, 35)
	button.Position = UDim2.fromOffset(15, yPosition)
	button.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextScaled = true
	button.Font = Enum.Font.GothamBold
	button.Text = name
	button.Parent = frame

	button.MouseButton1Click:Connect(function()
		characterRemote:FireServer("SelectCharacter", name)
	end)
end

makeButton("Chara", 35)
makeButton("Sans", 75)