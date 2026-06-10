-- BlackScreenClient
-- StarterPlayer > StarterPlayerScripts > BlackScreenClient

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local screenEffectRemote = remotes:WaitForChild("ScreenEffectRemote")

local gui = Instance.new("ScreenGui")
gui.Name = "BlackScreenGui"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 999999
gui.Enabled = true
gui.Parent = playerGui

local blackFrame = Instance.new("Frame")
blackFrame.Name = "BlackScreen"
blackFrame.Size = UDim2.fromScale(1, 1)
blackFrame.Position = UDim2.fromScale(0, 0)
blackFrame.AnchorPoint = Vector2.new(0, 0)
blackFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
blackFrame.BackgroundTransparency = 1
blackFrame.BorderSizePixel = 0
blackFrame.Visible = true
blackFrame.ZIndex = 999999
blackFrame.Parent = gui

local currentTween = nil

local function stopCurrentTween()
	if currentTween then
		currentTween:Cancel()
		currentTween = nil
	end
end

local function fadeToBlack()
	stopCurrentTween()

	blackFrame.Visible = true

	currentTween = TweenService:Create(
		blackFrame,
		TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			BackgroundTransparency = 0,
		}
	)

	currentTween:Play()
end

local function fadeFromBlack()
	stopCurrentTween()

	currentTween = TweenService:Create(
		blackFrame,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			BackgroundTransparency = 1,
		}
	)

	currentTween:Play()

	currentTween.Completed:Once(function()
		if blackFrame.BackgroundTransparency >= 1 then
			blackFrame.Visible = true
		end
	end)
end

screenEffectRemote.OnClientEvent:Connect(function(effectName)
	if effectName == "BlackScreen" then
		fadeToBlack()
	elseif effectName == "BlackScreenEnd" then
		fadeFromBlack()
	end
end)