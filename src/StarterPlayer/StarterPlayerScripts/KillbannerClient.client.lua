local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local progressionRemote = remotes:WaitForChild("ProgressionRemote")

local gui = Instance.new("ScreenGui")
gui.Name = "KillBannerGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local container = Instance.new("Frame")
container.Name = "KillBannerContainer"
container.AnchorPoint = Vector2.new(1, 0.5)
container.Position = UDim2.new(1, -24, 0.5, 0)
container.Size = UDim2.fromOffset(420, 320)
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

local function makeBannerText(payload)
	local attacker = payload.AttackerName or "Someone"
	local victim = payload.VictimName or "Someone"
	local verb = payload.Verb or "defeated"
	local dust = payload.DustReward or 0

	local text = attacker .. " " .. verb .. " " .. victim

	if dust > 0 then
		text ..= "  +" .. tostring(dust) .. " Dust"
	end

	return text
end

local function showKillBanner(payload)
	bannerCount += 1

	local banner = Instance.new("Frame")
	banner.Name = "KillBanner"
	banner.LayoutOrder = -bannerCount
	banner.AnchorPoint = Vector2.new(1, 0)
	banner.Size = UDim2.fromOffset(390, 34)
	banner.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
	banner.BackgroundTransparency = 1
	banner.BorderSizePixel = 0
	banner.Parent = container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = banner

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 70, 70)
	stroke.Thickness = 1
	stroke.Transparency = 1
	stroke.Parent = banner

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromOffset(10, 0)
	text.Size = UDim2.new(1, -20, 1, 0)
	text.Font = Enum.Font.GothamBold
	text.TextSize = 15
	text.TextXAlignment = Enum.TextXAlignment.Right
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	text.TextStrokeTransparency = 0.35
	text.TextTransparency = 1
	text.Text = makeBannerText(payload)
	text.Parent = banner

	banner.Position = UDim2.fromOffset(60, 0)

	TweenService:Create(
		banner,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			BackgroundTransparency = 0.18,
			Position = UDim2.fromOffset(0, 0),
		}
	):Play()

	TweenService:Create(
		stroke,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Transparency = 0.2,
		}
	):Play()

	TweenService:Create(
		text,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			TextTransparency = 0,
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
			text,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				TextTransparency = 1,
				TextStrokeTransparency = 1,
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