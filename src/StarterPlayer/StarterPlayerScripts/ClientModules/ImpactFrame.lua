local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local CameraShake = require(script.Parent:WaitForChild("CameraShake"))

local ImpactFrame = {}

local activeToken = 0
local activeTweens = {}
local activeHighlight = nil
local originalFOV = nil

local function cancelTweens()
	for _, tween in ipairs(activeTweens) do
		tween:Cancel()
	end

	table.clear(activeTweens)
end

local function getGui()
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = playerGui:FindFirstChild("UTBGImpactFrame")

	if gui and not gui:IsA("ScreenGui") then
		gui:Destroy()
		gui = nil
	end

	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = "UTBGImpactFrame"
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 9000
		gui.Enabled = false
		gui.Parent = playerGui

		local background = Instance.new("Frame")
		background.Name = "Background"
		background.BorderSizePixel = 0
		background.Size = UDim2.fromScale(1, 1)
		background.ZIndex = 1
		background.Parent = gui

		local flash = Instance.new("Frame")
		flash.Name = "Flash"
		flash.BorderSizePixel = 0
		flash.Size = UDim2.fromScale(1, 1)
		flash.ZIndex = 2
		flash.Parent = gui
	end

	return gui
end

local function getColorCorrection()
	local effect = Lighting:FindFirstChild("UTBGImpactFrameColor")

	if effect and not effect:IsA("ColorCorrectionEffect") then
		effect:Destroy()
		effect = nil
	end

	if not effect then
		effect = Instance.new("ColorCorrectionEffect")
		effect.Name = "UTBGImpactFrameColor"
		effect.Enabled = false
		effect.Parent = Lighting
	end

	return effect
end

local function resetColorCorrection()
	local effect = getColorCorrection()
	effect.Enabled = false
	effect.TintColor = Color3.new(1, 1, 1)
	effect.Contrast = 0
	effect.Saturation = 0
	effect.Brightness = 0
end

local function clearHighlight()
	if activeHighlight then
		activeHighlight:Destroy()
		activeHighlight = nil
	end
end

local function restoreFOV()
	local camera = workspace.CurrentCamera

	if camera and originalFOV then
		camera.FieldOfView = originalFOV
	end

	originalFOV = nil
end

function ImpactFrame:Reset()
	activeToken += 1
	cancelTweens()
	clearHighlight()
	restoreFOV()
	resetColorCorrection()

	local gui = getGui()
	gui.Enabled = false
end

function ImpactFrame:Play(options)
	options = options or {}

	activeToken += 1
	local token = activeToken

	cancelTweens()
	clearHighlight()

	local duration = math.max(options.Duration or 0.1, 0.03)
	local outTime = math.max(options.OutTime or duration * 1.35, 0.04)
	local backgroundColor = options.BackgroundColor or Color3.fromRGB(0, 0, 0)
	local flashColor = options.FlashColor or options.HighlightColor or Color3.fromRGB(255, 255, 255)
	local highlightColor = options.HighlightColor or flashColor

	local gui = getGui()
	local background = gui:FindFirstChild("Background")
	local flash = gui:FindFirstChild("Flash")

	gui.Enabled = true
	background.BackgroundColor3 = backgroundColor
	background.BackgroundTransparency = options.BackgroundTransparency or 0.15
	flash.BackgroundColor3 = flashColor
	flash.BackgroundTransparency = options.FlashTransparency or 0.25

	local effect = getColorCorrection()
	effect.Enabled = true
	effect.TintColor = flashColor
	effect.Contrast = options.Contrast or 0.35
	effect.Saturation = options.Saturation or -0.2
	effect.Brightness = options.Brightness or 0.1

	local character = player.Character
	if character and options.HighlightColor ~= false then
		local highlight = Instance.new("Highlight")
		highlight.Name = "UTBGImpactFrameHighlight"
		highlight.FillColor = highlightColor
		highlight.OutlineColor = highlightColor
		highlight.FillTransparency = 0.35
		highlight.OutlineTransparency = 0
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Parent = character
		activeHighlight = highlight
	end

	local camera = workspace.CurrentCamera
	local fovPunch = options.FOVPunch
	if camera and typeof(fovPunch) == "number" and fovPunch ~= 0 then
		originalFOV = originalFOV or camera.FieldOfView
		camera.FieldOfView = math.clamp(originalFOV - fovPunch, 1, 120)
	end

	if player:GetAttribute("Setting_CameraShake") ~= false then
		local shakeMagnitude = options.ShakeMagnitude
		if typeof(shakeMagnitude) == "number" and shakeMagnitude > 0 then
			CameraShake:ShakeOnce(shakeMagnitude, options.ShakeRoughness or 12, duration + outTime)
		end
	end

	local function addTween(instance, tweenInfo, goal)
		local tween = TweenService:Create(instance, tweenInfo, goal)
		table.insert(activeTweens, tween)
		tween:Play()
		return tween
	end

	task.delay(duration, function()
		if token ~= activeToken then
			return
		end

		addTween(background, TweenInfo.new(outTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		})

		addTween(flash, TweenInfo.new(outTime * 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		})

		addTween(effect, TweenInfo.new(outTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Contrast = 0,
			Saturation = 0,
			Brightness = 0,
			TintColor = Color3.new(1, 1, 1),
		})

		if activeHighlight then
			addTween(activeHighlight, TweenInfo.new(outTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				FillTransparency = 1,
				OutlineTransparency = 1,
			})
		end

		if camera and originalFOV then
			addTween(camera, TweenInfo.new(outTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				FieldOfView = originalFOV,
			})
		end
	end)

	task.delay(duration + outTime + 0.08, function()
		if token ~= activeToken then
			return
		end

		cancelTweens()
		clearHighlight()
		restoreFOV()
		resetColorCorrection()
		gui.Enabled = false
	end)
end

return ImpactFrame
