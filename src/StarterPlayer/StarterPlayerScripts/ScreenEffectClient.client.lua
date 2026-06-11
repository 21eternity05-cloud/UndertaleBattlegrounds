local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local screenEffectRemote = remotes:WaitForChild("ScreenEffectRemote")

local gui = Instance.new("ScreenGui")
gui.Name = "ScreenEffectGui"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 10000
gui.Parent = playerGui

local blackFrame = Instance.new("Frame")
blackFrame.Name = "BlackScreen"
blackFrame.BackgroundColor3 = Color3.new(0, 0, 0)
blackFrame.BackgroundTransparency = 1
blackFrame.BorderSizePixel = 0
blackFrame.Size = UDim2.fromScale(1, 1)
blackFrame.Visible = false
blackFrame.Parent = gui

local activeTween = nil
local effectToken = 0

local function cancelTween()
	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end
end

local function normalizePayload(payload)
	if typeof(payload) == "string" then
		return payload, true, 0
	end

	if typeof(payload) ~= "table" then
		return nil, true, 0
	end

	local fadeTime = 0
	if typeof(payload.FadeTime) == "number" then
		fadeTime = math.max(0, payload.FadeTime)
	end

	return payload.Action, payload.Instant == true, fadeTime
end

local function tweenTransparency(targetTransparency, fadeTime, onComplete)
	cancelTween()

	activeTween = TweenService:Create(
		blackFrame,
		TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			BackgroundTransparency = targetTransparency,
		}
	)

	local tween = activeTween
	tween.Completed:Connect(function(playbackState)
		if activeTween == tween then
			activeTween = nil
		end

		if playbackState == Enum.PlaybackState.Completed and onComplete then
			onComplete()
		end
	end)

	tween:Play()
end

local function showBlackScreen(instant, fadeTime)
	effectToken += 1
	cancelTween()
	blackFrame.Visible = true
	blackFrame.BackgroundColor3 = Color3.new(0, 0, 0)

	if instant or fadeTime <= 0 then
		blackFrame.BackgroundTransparency = 0
		return
	end

	tweenTransparency(0, fadeTime)
end

local function hideBlackScreen(instant, fadeTime)
	effectToken += 1
	local token = effectToken
	cancelTween()

	if instant or fadeTime <= 0 then
		blackFrame.BackgroundTransparency = 1
		blackFrame.Visible = false
		return
	end

	tweenTransparency(1, fadeTime, function()
		if effectToken == token then
			blackFrame.Visible = false
		end
	end)
end

screenEffectRemote.OnClientEvent:Connect(function(payload)
	local action, instant, fadeTime = normalizePayload(payload)

	if action == "BlackScreen" then
		showBlackScreen(instant, fadeTime)
	elseif action == "BlackScreenEnd" then
		hideBlackScreen(instant, fadeTime)
	end
end)
