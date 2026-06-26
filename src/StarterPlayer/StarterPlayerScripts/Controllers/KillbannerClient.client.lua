local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local progressionRemote = remotes:WaitForChild("ProgressionRemote")

local SILKSCREEN_FONT = Font.new("rbxassetid://12187371840")
local UT_BLACK = Color3.fromRGB(0, 0, 0)
local UT_WHITE = Color3.fromRGB(255, 255, 255)
local UT_GRAY = Color3.fromRGB(150, 150, 150)
local UT_RED = Color3.fromRGB(220, 20, 45)
local UT_ORANGE = Color3.fromRGB(255, 150, 40)

local function applyPixelFont(textObject)
	local success = pcall(function()
		textObject.FontFace = SILKSCREEN_FONT
	end)

	if not success then
		textObject.Font = Enum.Font.Arcade
	end
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

local gui = Instance.new("ScreenGui")
gui.Name = "KillBannerGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local container = Instance.new("Frame")
container.Name = "KillBannerContainer"
container.AnchorPoint = Vector2.new(1, 0.5)
container.Position = UDim2.new(1, -22, 0.42, 0)
container.Size = UDim2.new(0, 420, 0.42, 0)
container.BackgroundTransparency = 1
container.Parent = gui

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = container

local bannerCount = 0

local function getBannerParts(payload)
	return payload.AttackerName or "Someone",
		payload.Verb or "defeated",
		payload.VictimName or "Someone",
		payload.DustReward or 0
end

local function showKillBanner(payload)
	bannerCount += 1
	local attacker, verb, victim, dust = getBannerParts(payload)

	local banner = Instance.new("Frame")
	banner.Name = "KillBanner"
	banner.LayoutOrder = -bannerCount
	banner.AnchorPoint = Vector2.new(1, 0)
	banner.Size = UDim2.new(1, -18, 0, 58)
	banner.BackgroundColor3 = UT_BLACK
	banner.BackgroundTransparency = 1
	banner.BorderSizePixel = 0
	banner.Parent = container

	local stroke = addPixelStroke(banner, 3, UT_WHITE)
	stroke.Transparency = 1

	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.BackgroundColor3 = UT_RED
	accent.BackgroundTransparency = 1
	accent.BorderSizePixel = 0
	accent.Position = UDim2.fromOffset(6, 6)
	accent.Size = UDim2.new(0, 5, 1, -12)
	accent.Parent = banner

	local slash = Instance.new("Frame")
	slash.Name = "Slash"
	slash.BackgroundColor3 = UT_ORANGE
	slash.BackgroundTransparency = 1
	slash.BorderSizePixel = 0
	slash.Position = UDim2.new(0, 14, 0, 7)
	slash.Size = UDim2.new(0, 2, 1, -14)
	slash.Parent = banner

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(24, 7)
	title.Size = UDim2.new(1, -38, 0, 25)
	applyPixelFont(title)
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = UT_WHITE
	title.TextStrokeTransparency = 1
	title.TextTransparency = 1
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.Text = attacker .. " " .. verb
	title.Parent = banner

	local detail = Instance.new("TextLabel")
	detail.Name = "Detail"
	detail.BackgroundTransparency = 1
	detail.Position = UDim2.fromOffset(24, 31)
	detail.Size = UDim2.new(1, -38, 0, 18)
	applyPixelFont(detail)
	detail.TextSize = 12
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.TextColor3 = dust > 0 and UT_ORANGE or UT_GRAY
	detail.TextStrokeTransparency = 1
	detail.TextTransparency = 1
	detail.TextTruncate = Enum.TextTruncate.AtEnd
	detail.Text = dust > 0 and (victim .. "   +" .. tostring(dust) .. " DUST") or victim
	detail.Parent = banner

	local minSize = Instance.new("UISizeConstraint")
	minSize.MinSize = Vector2.new(270, 58)
	minSize.MaxSize = Vector2.new(402, 58)
	minSize.Parent = banner

	banner.Position = UDim2.fromOffset(60, 0)

	TweenService:Create(
		banner,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			BackgroundTransparency = 0,
			Position = UDim2.fromOffset(0, 0),
		}
	):Play()

	TweenService:Create(
		stroke,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Transparency = 0,
		}
	):Play()

	TweenService:Create(
		title,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			TextTransparency = 0,
		}
	):Play()

	TweenService:Create(
		detail,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			TextTransparency = 0,
		}
	):Play()

	TweenService:Create(
		accent,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			BackgroundTransparency = 0,
		}
	):Play()

	TweenService:Create(
		slash,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			BackgroundTransparency = 0,
		}
	):Play()

	task.delay(2.6, function()
		if not banner or not banner.Parent then
			return
		end

		TweenService:Create(
			banner,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(60, 0),
			}
		):Play()

		TweenService:Create(
			stroke,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				Transparency = 1,
			}
		):Play()

		TweenService:Create(
			title,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				TextTransparency = 1,
			}
		):Play()

		TweenService:Create(
			detail,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				TextTransparency = 1,
			}
		):Play()

		TweenService:Create(
			accent,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				BackgroundTransparency = 1,
			}
		):Play()

		TweenService:Create(
			slash,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				BackgroundTransparency = 1,
			}
		):Play()
	end)

	Debris:AddItem(banner, 3)
end

progressionRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	if payload.Action == "KillBanner" then
		showKillBanner(payload)
	end
end)

print("[KillBannerClient] Loaded")
