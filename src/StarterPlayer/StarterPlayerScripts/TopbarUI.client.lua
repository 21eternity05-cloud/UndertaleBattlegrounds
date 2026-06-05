local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local characterRemote = remotes:WaitForChild("CharacterRemote")
local progressionRemote = remotes:WaitForChild("ProgressionRemote")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Icon = require(Packages:WaitForChild("TopBarPlus"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterData = require(Shared:WaitForChild("CharacterData"))
local CustomizationData = require(Shared:WaitForChild("CustomizationData"))
local TitleData = require(Shared:WaitForChild("TitleData"))

local profile = nil
local icons = {}
local dropdownIcons = {}

local currentPanelName = nil
local currentGui = nil
local dustIcon = nil

local selectedCharacter = "Chara"
local selectedCustomizeCategory = "Characters"

local activePreviewModel = nil
local oldCameraType = nil
local oldCameraSubject = nil
local oldCameraCFrame = nil

local hiddenCombatGuiStates = {}

local SHOP_FOLDER_NAME = "SHOP"
local SHOP_PLACEHOLDER_NAME = "Placeholder"

local HIDDEN_GUI_NAMES = {
	MoveHUD = true,
	LoreGui = true,
}

local gui = Instance.new("ScreenGui")
gui.Name = "TopBarPlusMenus"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local function getCharacterOrder()
	if typeof(CharacterData.Order) == "table" then
		return CharacterData.Order
	end

	local order = {}

	for characterName, data in pairs(CharacterData) do
		if typeof(data) == "table" then
			table.insert(order, characterName)
		end
	end

	table.sort(order)
	return order
end

local function getDust()
	if profile and typeof(profile.Dust) == "number" then
		return profile.Dust
	end

	local attributeDust = player:GetAttribute("Dust")

	if typeof(attributeDust) == "number" then
		return attributeDust
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local dustValue = leaderstats and leaderstats:FindFirstChild("Dust")

	if dustValue and (dustValue:IsA("IntValue") or dustValue:IsA("NumberValue")) then
		return dustValue.Value
	end

	return 0
end

local function isOwned(characterName)
	local data = CharacterData[characterName]

	if not data then
		return false
	end

	if data.Free == true or data.Cost == 0 then
		return true
	end

	if profile and profile.OwnedCharacters and profile.OwnedCharacters[characterName] == true then
		return true
	end

	local ownedFolder = player:FindFirstChild("OwnedCharacters")
	local ownedValue = ownedFolder and ownedFolder:FindFirstChild(characterName)

	if ownedValue and ownedValue:IsA("BoolValue") then
		return ownedValue.Value == true
	end

	return false
end

local function getCharacterData(characterName)
	local data = CharacterData[characterName]

	if typeof(data) == "table" then
		return data
	end

	return nil
end

local function hideCombatUI()
	for _, child in ipairs(playerGui:GetChildren()) do
		if child:IsA("ScreenGui") and HIDDEN_GUI_NAMES[child.Name] then
			if hiddenCombatGuiStates[child] == nil then
				hiddenCombatGuiStates[child] = child.Enabled
			end

			child.Enabled = false
		end
	end
end

local function restoreCombatUI()
	for screenGui, wasEnabled in pairs(hiddenCombatGuiStates) do
		if screenGui and screenGui.Parent then
			screenGui.Enabled = wasEnabled
		end
	end

	table.clear(hiddenCombatGuiStates)
end

local function getShopPlaceholder()
	local shopFolder = Workspace:FindFirstChild(SHOP_FOLDER_NAME)

	if not shopFolder then
		warn("[TopBarUI] Missing workspace SHOP folder")
		return nil
	end

	local placeholder = shopFolder:FindFirstChild(SHOP_PLACEHOLDER_NAME)

	if not placeholder or not placeholder:IsA("BasePart") then
		warn("[TopBarUI] Missing workspace SHOP Placeholder part")
		return nil
	end

	return placeholder
end

local function clearPreviewModel()
	if activePreviewModel then
		activePreviewModel:Destroy()
		activePreviewModel = nil
	end
end

local function getCharacterModel(characterName)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local characters = assets and assets:FindFirstChild("Characters")
	local characterFolder = characters and characters:FindFirstChild(characterName)

	if not characterFolder then
		return nil
	end

	-- Preferred structure:
	-- Assets/Characters/[Character]/CharacterModel/[ActualRigModel]
	local characterModelFolder = characterFolder:FindFirstChild("CharacterModel")

	if characterModelFolder then
		if characterModelFolder:IsA("Model") then
			return characterModelFolder
		end

		if characterModelFolder:IsA("Folder") then
			local namedModel = characterModelFolder:FindFirstChild(characterName)

			if namedModel and namedModel:IsA("Model") then
				return namedModel
			end

			local firstModel = characterModelFolder:FindFirstChildWhichIsA("Model")

			if firstModel then
				return firstModel
			end
		end
	end

	local possibleNames = {
		"Model",
		"Rig",
		"ViewportModel",
	}

	for _, modelName in ipairs(possibleNames) do
		local model = characterFolder:FindFirstChild(modelName)

		if model and model:IsA("Model") then
			return model
		end
	end

	return nil
end

local function setupPreviewModel(characterName)
	clearPreviewModel()

	local placeholder = getShopPlaceholder()

	if not placeholder then
		return
	end

	local sourceModel = getCharacterModel(characterName)
	local previewCFrame = placeholder.CFrame * CFrame.Angles(0, math.rad(180), 0)

	if sourceModel then
		activePreviewModel = sourceModel:Clone()
		activePreviewModel.Name = "ClientShopPreview_" .. characterName
		activePreviewModel.Parent = Workspace
		activePreviewModel:PivotTo(previewCFrame)
	else
		local fallback = Instance.new("Model")
		fallback.Name = "ClientShopPreview_" .. characterName

		local body = Instance.new("Part")
		body.Name = "PlaceholderBody"
		body.Anchored = true
		body.CanCollide = false
		body.Size = Vector3.new(3, 5, 1)
		body.Color = Color3.fromRGB(120, 120, 140)
		body.CFrame = previewCFrame + Vector3.new(0, 2.5, 0)
		body.Parent = fallback

		fallback.PrimaryPart = body
		fallback.Parent = Workspace

		activePreviewModel = fallback
	end
end

local function enterShopCamera(characterName)
	local camera = Workspace.CurrentCamera
	local placeholder = getShopPlaceholder()

	if not camera or not placeholder then
		return
	end

	if oldCameraType == nil then
		oldCameraType = camera.CameraType
		oldCameraSubject = camera.CameraSubject
		oldCameraCFrame = camera.CFrame
	end

	setupPreviewModel(characterName)

	local focusPosition = placeholder.Position + Vector3.new(0, 2.8, 0)
	local cameraPosition = (placeholder.CFrame * CFrame.new(0, 3.2, 11)).Position

	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(cameraPosition, focusPosition)
end

local function exitShopCamera()
	local camera = Workspace.CurrentCamera

	clearPreviewModel()

	if not camera then
		return
	end

	if oldCameraType ~= nil then
		camera.CameraType = oldCameraType
		camera.CameraSubject = oldCameraSubject

		if oldCameraCFrame then
			camera.CFrame = oldCameraCFrame
		end
	end

	oldCameraType = nil
	oldCameraSubject = nil
	oldCameraCFrame = nil
end

local function clearCurrentGui()
	local wasCustomize = currentPanelName == "Customize"

	if currentGui then
		currentGui:Destroy()
		currentGui = nil
	end

	if wasCustomize then
		exitShopCamera()
		restoreCombatUI()
	end

	currentPanelName = nil
end

local function deselectAllTopIcons()
	for _, icon in pairs(icons) do
		pcall(function()
			icon:deselect()
		end)
	end
end

local function makeText(parent, name, text, position, size, textSize, bold, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	label.TextSize = textSize or 14
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextColor3 = color or Color3.fromRGB(235, 235, 242)
	label.Text = text
	label.Parent = parent

	return label
end

local function makeButton(parent, name, text, position, size, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = position
	button.Size = size
	button.BackgroundColor3 = color or Color3.fromRGB(34, 34, 42)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Text = text
	button.AutoButtonColor = true
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = button

	return button
end

local function makePanelRoot(name)
	clearCurrentGui()

	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Parent = gui

	currentGui = frame
	currentPanelName = name

	return frame
end

local function makeFloatingPanel(parent, name, position, size, transparency)
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.Position = position
	panel.Size = size
	panel.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
	panel.BackgroundTransparency = transparency or 0.08
	panel.BorderSizePixel = 0
	panel.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(76, 76, 92)
	stroke.Thickness = 1
	stroke.Parent = panel

	return panel
end

local function refreshDust()
	if dustIcon then
		dustIcon:setLabel("Dust " .. tostring(getDust()))
	end
end

local function requestSnapshot()
	progressionRemote:FireServer({
		Action = "RequestSnapshot",
	})
end

local function selectOrBuyCharacter(characterName)
	if isOwned(characterName) then
		characterRemote:FireServer("SelectCharacter", characterName)
	else
		progressionRemote:FireServer({
			Action = "BuyCharacter",
			CharacterName = characterName,
		})
	end
end

local function showShop()
	if currentPanelName == "Shop" then
		clearCurrentGui()
		deselectAllTopIcons()
		return
	end

	local root = makePanelRoot("Shop")

	local panel = makeFloatingPanel(
		root,
		"ShopPanel",
		UDim2.fromOffset(14, 54),
		UDim2.fromOffset(430, 300),
		0.04
	)

	makeText(
		panel,
		"Title",
		"Shop",
		UDim2.fromOffset(16, 14),
		UDim2.new(1, -32, 0, 28),
		22,
		true
	)

	makeText(
		panel,
		"Body",
		"Future Robux shop placeholder.\n\nThis will be used for Robux purchases later, not normal Dust inventory.\n\nIdeas:\n- Gamepasses\n- Donation products\n- Premium bundles\n- Limited cosmetics",
		UDim2.fromOffset(16, 58),
		UDim2.new(1, -32, 0, 210),
		15,
		false
	)
end

local function showSettings()
	if currentPanelName == "Settings" then
		clearCurrentGui()
		deselectAllTopIcons()
		return
	end

	local root = makePanelRoot("Settings")

	local panel = makeFloatingPanel(
		root,
		"SettingsPanel",
		UDim2.fromOffset(14, 54),
		UDim2.fromOffset(400, 310),
		0.04
	)

	makeText(
		panel,
		"Title",
		"Settings",
		UDim2.fromOffset(16, 14),
		UDim2.new(1, -32, 0, 28),
		22,
		true
	)

	local settings = {
		"Music",
		"SFX",
		"Camera Shake",
		"Hitbox Debug",
	}

	for index, settingName in ipairs(settings) do
		local row = makeButton(
			panel,
			settingName:gsub("%s+", "") .. "Toggle",
			"  " .. settingName .. ": On",
			UDim2.fromOffset(16, 58 + (index - 1) * 46),
			UDim2.new(1, -32, 0, 36),
			Color3.fromRGB(30, 30, 38)
		)

		row.TextXAlignment = Enum.TextXAlignment.Left

		local enabled = true

		row.MouseButton1Click:Connect(function()
			enabled = not enabled
			row.Text = "  " .. settingName .. ": " .. (enabled and "On" or "Off")
		end)
	end
end

local function showCustomize()
	if currentPanelName == "Customize" then
		clearCurrentGui()
		deselectAllTopIcons()
		return
	end

	local root = makePanelRoot("Customize")
	enterShopCamera(selectedCharacter)
	hideCombatUI()

	local leftPanel = makeFloatingPanel(
		root,
		"LeftCategoryPanel",
		UDim2.fromOffset(14, 70),
		UDim2.fromOffset(210, 520),
		0.06
	)

	makeText(
		leftPanel,
		"Title",
		"Customize",
		UDim2.fromOffset(14, 12),
		UDim2.new(1, -28, 0, 28),
		22,
		true
	)

	local bottomPanel = makeFloatingPanel(
		root,
		"BottomInfoPanel",
		UDim2.new(0.5, -320, 1, -158),
		UDim2.fromOffset(640, 132),
		0.08
	)

	local rightPanel = makeFloatingPanel(
		root,
		"RightInventoryPanel",
		UDim2.new(1, -334, 0, 70),
		UDim2.fromOffset(320, 520),
		0.06
	)

	makeText(
		rightPanel,
		"Title",
		"Inventory",
		UDim2.fromOffset(14, 12),
		UDim2.new(1, -28, 0, 28),
		22,
		true
	)

	local characterNameLabel = makeText(
		bottomPanel,
		"CharacterName",
		"",
		UDim2.fromOffset(16, 12),
		UDim2.fromOffset(260, 28),
		22,
		true
	)

	local roleLabel = makeText(
		bottomPanel,
		"Role",
		"",
		UDim2.fromOffset(16, 42),
		UDim2.fromOffset(300, 22),
		14,
		true,
		Color3.fromRGB(150, 210, 255)
	)

	local descriptionLabel = makeText(
		bottomPanel,
		"Description",
		"",
		UDim2.fromOffset(16, 68),
		UDim2.new(1, -32, 0, 52),
		14,
		false
	)

	local itemList = Instance.new("ScrollingFrame")
	itemList.Name = "ItemList"
	itemList.Position = UDim2.fromOffset(14, 54)
	itemList.Size = UDim2.new(1, -28, 1, -68)
	itemList.BackgroundTransparency = 1
	itemList.BorderSizePixel = 0
	itemList.ScrollBarThickness = 4
	itemList.CanvasSize = UDim2.fromOffset(0, 0)
	itemList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	itemList.Parent = rightPanel

	local itemLayout = Instance.new("UIListLayout")
	itemLayout.Padding = UDim.new(0, 8)
	itemLayout.SortOrder = Enum.SortOrder.LayoutOrder
	itemLayout.Parent = itemList

	local function clearItems()
		for _, child in ipairs(itemList:GetChildren()) do
			if child ~= itemLayout then
				child:Destroy()
			end
		end
	end

	local function setBottomInfo(characterName)
		local data = getCharacterData(characterName)

		if not data then
			return
		end

		selectedCharacter = characterName

		characterNameLabel.Text = data.DisplayName or characterName
		roleLabel.Text = data.Role or ""
		descriptionLabel.Text = data.Description or "No description yet."

		enterShopCamera(characterName)
	end

	local function addItemButton(text, callback, owned)
		local safeName = text:gsub("%W+", "")

		if safeName == "" then
			safeName = "Item"
		end

		local button = makeButton(
			itemList,
			safeName .. "Button",
			text,
			UDim2.fromOffset(0, 0),
			UDim2.new(1, -6, 0, 38),
			owned == false and Color3.fromRGB(62, 45, 34) or Color3.fromRGB(36, 36, 46)
		)

		button.TextXAlignment = Enum.TextXAlignment.Left
		button.Text = "  " .. text

		button.MouseButton1Click:Connect(callback)

		return button
	end

	local function showCategory(category)
		selectedCustomizeCategory = category
		clearItems()

		if category == "Characters" then
			for _, characterName in ipairs(getCharacterOrder()) do
				local data = getCharacterData(characterName)

				if data then
					local owned = isOwned(characterName)
					local text = data.DisplayName or characterName

					if not owned then
						text ..= "  -  " .. tostring(data.Cost or 0) .. " Dust"
					end

					addItemButton(text, function()
						setBottomInfo(characterName)

						if owned then
							characterRemote:FireServer("SelectCharacter", characterName)
						else
							progressionRemote:FireServer({
								Action = "BuyCharacter",
								CharacterName = characterName,
							})
						end
					end, owned)
				end
			end
		elseif category == "Titles" then
			for titleId, data in pairs(TitleData) do
				if typeof(data) == "table" then
					addItemButton(data.DisplayName or titleId, function()
						progressionRemote:FireServer({
							Action = "EquipTitle",
							TitleId = titleId,
						})
					end, true)
				end
			end
		elseif category == "Skins" then
			addItemButton("Default Skin", function() end, true)
			addItemButton("Future Skin Slot", function() end, false)
		elseif category == "Auras" then
			addItemButton("No Aura", function() end, true)
			addItemButton("Future Aura Slot", function() end, false)
		elseif category == "Emotes" then
			addItemButton("Future Emote Slot", function() end, false)
		elseif category == "Morphs" then
			addItemButton("Morphs Reserved - Not Active Yet", function() end, false)
		end
	end

	local categories = {
		"Characters",
		"Skins",
		"Titles",
		"Auras",
		"Emotes",
		"Morphs",
	}

	for index, category in ipairs(categories) do
		local button = makeButton(
			leftPanel,
			category .. "CategoryButton",
			category,
			UDim2.fromOffset(14, 54 + (index - 1) * 48),
			UDim2.new(1, -28, 0, 38),
			Color3.fromRGB(34, 34, 44)
		)

		button.MouseButton1Click:Connect(function()
			showCategory(category)
		end)
	end

	setBottomInfo(selectedCharacter)
	showCategory(selectedCustomizeCategory or "Characters")
end

local function makeTopbarIcon(name, label, callback)
	local icon = Icon.new()
		:setName(name)
		:setLabel(label)
		:align("Left")
		:autoDeselect(false)

	icon:bindEvent("selected", function()
		callback()
		pcall(function()
			icon:deselect()
		end)
	end)

	icons[name] = icon

	return icon
end

local function rebuildCharacterDropdown()
	for _, icon in ipairs(dropdownIcons) do
		pcall(function()
			icon:destroy()
		end)
	end

	dropdownIcons = {}

	for _, characterName in ipairs(getCharacterOrder()) do
		local data = getCharacterData(characterName)

		if data then
			local owned = isOwned(characterName)
			local displayName = data.DisplayName or characterName
			local label = owned and displayName or (displayName .. " [" .. tostring(data.Cost or 0) .. "]")

			local itemIcon = Icon.new()
				:setName("Character_" .. characterName)
				:setLabel(label)
				:oneClick(true)

			itemIcon:bindEvent("selected", function()
				selectOrBuyCharacter(characterName)
			end)

			table.insert(dropdownIcons, itemIcon)
		end
	end

	if icons.Characters then
		icons.Characters:setDropdown(dropdownIcons)
	end
end

icons.Characters = Icon.new()
	:setName("Characters")
	:setLabel("Characters")
	:align("Left")
	:autoDeselect(true)

makeTopbarIcon("Customize", "Customize", showCustomize)
makeTopbarIcon("Shop", "Shop", showShop)
makeTopbarIcon("Settings", "Settings", showSettings)

dustIcon = Icon.new()
	:setName("Dust")
	:setLabel("Dust 0")
	:align("Left")
	:autoDeselect(false)
	:oneClick(true)

dustIcon:bindEvent("selected", function()
	requestSnapshot()
end)

progressionRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	if payload.Profile then
		profile = payload.Profile
		refreshDust()
		rebuildCharacterDropdown()

		if currentPanelName == "Customize" then
			local oldCategory = selectedCustomizeCategory
			local oldCharacter = selectedCharacter

			clearCurrentGui()

			selectedCustomizeCategory = oldCategory
			selectedCharacter = oldCharacter

			showCustomize()
		end
	end
end)

player:GetAttributeChangedSignal("Dust"):Connect(refreshDust)

player.ChildAdded:Connect(function(child)
	if child.Name == "leaderstats" then
		task.wait()

		local dustValue = child:FindFirstChild("Dust")

		if dustValue then
			dustValue.Changed:Connect(refreshDust)
		end

		refreshDust()
	elseif child.Name == "OwnedCharacters" then
		rebuildCharacterDropdown()
	end
end)

local leaderstats = player:FindFirstChild("leaderstats")

if leaderstats then
	local dustValue = leaderstats:FindFirstChild("Dust")

	if dustValue then
		dustValue.Changed:Connect(refreshDust)
	end
end

refreshDust()
rebuildCharacterDropdown()
requestSnapshot()

print("[TopBarUI] Loaded TSB-style TopBarPlus UI")