local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local loreRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("LoreRemote")

local gui = Instance.new("ScreenGui")
gui.Name = "LoreGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Name = "Dialogue"
frame.AnchorPoint = Vector2.new(0.5, 1)
frame.Position = UDim2.fromScale(0.5, 0.88)
frame.Size = UDim2.fromOffset(560, 130)
frame.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
frame.BackgroundTransparency = 0.08
frame.BorderSizePixel = 0
frame.Visible = false
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(90, 90, 105)
stroke.Thickness = 1
stroke.Parent = frame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(16, 10)
title.Size = UDim2.new(1, -32, 0, 24)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Parent = frame

local body = Instance.new("TextLabel")
body.Name = "Body"
body.BackgroundTransparency = 1
body.Position = UDim2.fromOffset(16, 42)
body.Size = UDim2.new(1, -32, 0, 70)
body.Font = Enum.Font.Gotham
body.TextSize = 15
body.TextWrapped = true
body.TextXAlignment = Enum.TextXAlignment.Left
body.TextYAlignment = Enum.TextYAlignment.Top
body.TextColor3 = Color3.fromRGB(235, 235, 240)
body.Parent = frame

local token = 0

local function playEntry(entry)
	token += 1
	local myToken = token

	title.Text = entry.DisplayName or "Memory"
	frame.Visible = true

	local lines = entry.Lines or {}

	task.spawn(function()
		for _, line in ipairs(lines) do
			if myToken ~= token then return end
			body.Text = line
			task.wait(math.max(1.8, #line * 0.045))
		end

		task.wait(0.8)

		if myToken == token then
			frame.Visible = false
		end
	end)
end

loreRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end

	if payload.Action == "PlayLore" and typeof(payload.Entry) == "table" then
		playEntry(payload.Entry)
	end
end)
