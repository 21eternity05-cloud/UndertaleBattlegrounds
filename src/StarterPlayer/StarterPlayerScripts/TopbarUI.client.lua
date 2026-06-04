local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local characterRemote = remotes:WaitForChild("CharacterRemote")
local progressionRemote = remotes:WaitForChild("ProgressionRemote")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterData = require(Shared:WaitForChild("CharacterData"))
local TitleData = require(Shared:WaitForChild("TitleData"))
local CustomizationData = require(Shared:WaitForChild("CustomizationData"))

local profile = nil
local currentPanel = nil

local gui = Instance.new("ScreenGui")
gui.Name = "TopbarFrameworkGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local topbar = Instance.new("Frame")
topbar.Name = "Topbar"
topbar.Size = UDim2.new(1, 0, 0, 42)
topbar.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
topbar.BackgroundTransparency = 0.08
topbar.BorderSizePixel = 0
topbar.Parent = gui

local list = Instance.new("UIListLayout")
list.FillDirection = Enum.FillDirection.Horizontal
list.VerticalAlignment = Enum.VerticalAlignment.Center
list.Padding = UDim.new(0, 8)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = topbar

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 12)
padding.PaddingRight = UDim.new(0, 12)
padding.Parent = topbar

local panels = Instance.new("Frame")
panels.Name = "Panels"
panels.Position = UDim2.fromOffset(12, 52)
panels.Size = UDim2.fromOffset(430, 360)
panels.BackgroundTransparency = 1
panels.Parent = gui

local function makeTopButton(name, text, width)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.fromOffset(width or 112, 30)
	button.BackgroundColor3 = Color3.fromRGB(34, 34, 42)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 13
	button.TextColor3 = Color3.fromRGB(245, 245, 245)
	button.Text = text
	button.Parent = topbar

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button

	return button
end

local characterButton = makeTopButton("CharactersButton", "Characters", 116)
local settingsButton = makeTopButton("SettingsButton", "Settings", 92)
local customizeButton = makeTopButton("CustomizeButton", "Customize", 112)
local dustButton = makeTopButton("DustButton", "Dust 0", 110)

local function clearPanels()
	for _, child in ipairs(panels:GetChildren()) do
		child:Destroy()
	end

	currentPanel = nil
end

local function makePanel(name, titleText)
	clearPanels()

	local panel = Instance.new("Frame")
	panel.Name = name
	panel.Size = UDim2.fromOffset(430, 360)
	panel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	panel.BorderSizePixel = 0
	panel.Parent = panels

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(78, 78, 90)
	stroke.Thickness = 1
	stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(14, 10)
	title.Size = UDim2.new(1, -52, 0, 26)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Text = titleText
	title.Parent = panel

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 8)
	close.Size = UDim2.fromOffset(28, 28)
	close.BackgroundColor3 = Color3.fromRGB(42, 42, 50)
	close.BorderSizePixel = 0
	close.Font = Enum.Font.GothamBold
	close.TextSize = 16
	close.TextColor3 = Color3.fromRGB(255, 255, 255)
	close.Text = "X"
	close.Parent = panel

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 6)
	closeCorner.Parent = close

	close.MouseButton1Click:Connect(clearPanels)

	currentPanel = name
	return panel
end

local function makeText(parent, text, position, size, textSize, bold)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	label.TextSize = textSize or 13
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextColor3 = Color3.fromRGB(232, 232, 238)
	label.Text = text
	label.Parent = parent
	return label
end

local function isOwned(characterName)
	if not profile then
		local data = CharacterData[characterName]
		return data and data.Free == true
	end

	return profile.OwnedCharacters and profile.OwnedCharacters[characterName] == true
end

local function showCharacters()
	local panel = makePanel("CharactersPanel", "Characters")

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "CharacterList"
	scroll.Position = UDim2.fromOffset(12, 48)
	scroll.Size = UDim2.new(1, -24, 1, -60)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 4
	scroll.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	for _, characterName in ipairs({ "Chara", "Sans", "Toriel" }) do
		local data = CharacterData[characterName]
		if data then
			local owned = isOwned(characterName)
			local card = Instance.new("Frame")
			card.Name = characterName .. "Card"
			card.Size = UDim2.new(1, -6, 0, 116)
			card.BackgroundColor3 = owned and Color3.fromRGB(30, 30, 36) or Color3.fromRGB(25, 23, 27)
			card.BorderSizePixel = 0
			card.Parent = scroll

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = card

			makeText(card, data.DisplayName or characterName, UDim2.fromOffset(12, 10), UDim2.fromOffset(240, 22), 16, true)
			makeText(card, data.Role or "", UDim2.fromOffset(12, 34), UDim2.fromOffset(250, 18), 12, false)
			makeText(card, data.Description or "", UDim2.fromOffset(12, 55), UDim2.fromOffset(270, 42), 12, false)

			local movesText = data.Moves and table.concat(data.Moves, " / ") or ""
			makeText(card, movesText, UDim2.fromOffset(12, 96), UDim2.new(1, -120, 0, 16), 10, false)

			local button = Instance.new("TextButton")
			button.Name = "Action"
			button.AnchorPoint = Vector2.new(1, 0.5)
			button.Position = UDim2.new(1, -12, 0.5, 0)
			button.Size = UDim2.fromOffset(96, 34)
			button.BackgroundColor3 = owned and Color3.fromRGB(155, 36, 36) or Color3.fromRGB(66, 50, 34)
			button.BorderSizePixel = 0
			button.Font = Enum.Font.GothamBold
			button.TextSize = 12
			button.TextColor3 = Color3.fromRGB(255, 255, 255)
			button.Text = owned and "Select" or ("Buy " .. tostring(data.Cost or 0))
			button.Parent = card

			local buttonCorner = Instance.new("UICorner")
			buttonCorner.CornerRadius = UDim.new(0, 6)
			buttonCorner.Parent = button

			button.MouseButton1Click:Connect(function()
				if owned then
					characterRemote:FireServer("SelectCharacter", characterName)
				else
					progressionRemote:FireServer({
						Action = "BuyCharacter",
						CharacterName = characterName,
					})
				end
			end)
		end
	end
end

local function showSettings()
	local panel = makePanel("SettingsPanel", "Settings")
	local settings = {
		"Music",
		"SFX",
		"Camera Shake",
		"Hitbox Debug",
	}

	for index, name in ipairs(settings) do
		local row = Instance.new("TextButton")
		row.Name = name:gsub("%s+", "") .. "Toggle"
		row.Position = UDim2.fromOffset(16, 48 + (index - 1) * 44)
		row.Size = UDim2.new(1, -32, 0, 34)
		row.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
		row.BorderSizePixel = 0
		row.Font = Enum.Font.GothamBold
		row.TextSize = 13
		row.TextColor3 = Color3.fromRGB(245, 245, 245)
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text = "  " .. name .. ": On"
		row.Parent = panel

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = row

		local enabled = true
		row.MouseButton1Click:Connect(function()
			enabled = not enabled
			row.Text = "  " .. name .. ": " .. (enabled and "On" or "Off")
		end)
	end
end

local function showCustomize()
	local panel = makePanel("CustomizePanel", "Customize")
	local categories = { "Morphs", "Titles", "Auras", "Skins", "Emotes" }

	for index, category in ipairs(categories) do
		local config = CustomizationData.Categories[category]
		local row = Instance.new("Frame")
		row.Name = category
		row.Position = UDim2.fromOffset(16, 48 + (index - 1) * 48)
		row.Size = UDim2.new(1, -32, 0, 40)
		row.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
		row.BorderSizePixel = 0
		row.Parent = panel

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = row

		local status = config and config.Enabled and "Available" or "Reserved"
		makeText(row, category, UDim2.fromOffset(10, 7), UDim2.fromOffset(150, 18), 13, true)
		makeText(row, status, UDim2.new(1, -140, 0, 7), UDim2.fromOffset(120, 18), 12, false)
	end

	local equippedTitle = profile and profile.EquippedTitle or "HollowWitness"
	local titleData = TitleData[equippedTitle]
	makeText(
		panel,
		"Equipped Title: " .. ((titleData and titleData.DisplayName) or "None"),
		UDim2.fromOffset(16, 300),
		UDim2.new(1, -32, 0, 24),
		13,
		true
	)
end

local function refreshDust()
	local dust = profile and profile.Dust or player:GetAttribute("Dust") or 0
	dustButton.Text = "Dust " .. tostring(dust)
end

progressionRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end

	if payload.Profile then
		profile = payload.Profile
		refreshDust()

		if currentPanel == "CharactersPanel" then
			showCharacters()
		elseif currentPanel == "CustomizePanel" then
			showCustomize()
		end
	end
end)

characterButton.MouseButton1Click:Connect(function()
	if currentPanel == "CharactersPanel" then
		clearPanels()
	else
		showCharacters()
	end
end)

settingsButton.MouseButton1Click:Connect(function()
	if currentPanel == "SettingsPanel" then
		clearPanels()
	else
		showSettings()
	end
end)

customizeButton.MouseButton1Click:Connect(function()
	if currentPanel == "CustomizePanel" then
		clearPanels()
	else
		showCustomize()
	end
end)

dustButton.MouseButton1Click:Connect(function()
	progressionRemote:FireServer({ Action = "RequestSnapshot" })
end)

player:GetAttributeChangedSignal("Dust"):Connect(refreshDust)
progressionRemote:FireServer({ Action = "RequestSnapshot" })
