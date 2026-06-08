local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local characterRemote = remotes:WaitForChild("CharacterRemote")
local progressionRemote = remotes:WaitForChild("ProgressionRemote")
local notificationRemote = remotes:WaitForChild("NotificationRemote", 10)

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Icon = require(Packages:WaitForChild("TopBarPlus"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterData = require(Shared:WaitForChild("CharacterData"))
local CustomizationData = require(Shared:WaitForChild("CustomizationData"))
local TitleData = require(Shared:WaitForChild("TitleData"))

local ClientModules = script.Parent:WaitForChild("ClientModules")
local ShopPreviewController = require(ClientModules:WaitForChild("ShopPreviewController"))

local profile = nil
local icons = {}
local dropdownIcons = {}

local currentPanelName = nil
local currentGui = nil
local dustIcon = nil

local selectedCharacter = "Chara"
local selectedCustomizeCharacter = "Chara"
local selectedCustomizeSkin = "Default"
local selectedCustomizeCategory = "Characters"
local morphEnabled = false
local pendingPurchaseCharacter = nil
local pendingPurchaseSkin = nil

local shopPreviewController = ShopPreviewController.new(player, ReplicatedStorage)
shopPreviewController:Start()

local hiddenCombatGuiStates = {}

local HIDDEN_GUI_NAMES = {
	MoveHUD = true,
	LoreGui = true,
}

local gui = Instance.new("ScreenGui")
gui.Name = "TopBarPlusMenus"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local activeNotification = nil
local activeNotificationTween = nil
local notificationToken = 0

local function showBottomRightNotification(text, duration)
	notificationToken += 1
	local token = notificationToken

	if activeNotificationTween then
		activeNotificationTween:Cancel()
		activeNotificationTween = nil
	end

	if not activeNotification or not activeNotification.Parent then
		activeNotification = Instance.new("TextLabel")
		activeNotification.Name = "BottomRightNotification"
		activeNotification.AnchorPoint = Vector2.new(1, 1)
		activeNotification.Position = UDim2.new(1, -24, 1, -120)
		activeNotification.Size = UDim2.fromOffset(330, 42)
		activeNotification.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
		activeNotification.BackgroundTransparency = 0.08
		activeNotification.BorderSizePixel = 0
		activeNotification.Font = Enum.Font.GothamSemibold
		activeNotification.TextSize = 14
		activeNotification.TextColor3 = Color3.fromRGB(245, 245, 245)
		activeNotification.TextWrapped = true
		activeNotification.Parent = gui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 7)
		corner.Parent = activeNotification

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(90, 90, 105)
		stroke.Thickness = 1
		stroke.Parent = activeNotification
	end

	activeNotification.Text = text or ""
	activeNotification.TextTransparency = 0
	activeNotification.BackgroundTransparency = 0.08
	activeNotification.Visible = true

	task.delay(duration or 2.5, function()
		if token ~= notificationToken or not activeNotification then
			return
		end

		activeNotificationTween = game:GetService("TweenService"):Create(
			activeNotification,
			TweenInfo.new(0.25),
			{
				TextTransparency = 1,
				BackgroundTransparency = 1,
			}
		)

		activeNotificationTween:Play()
		activeNotificationTween.Completed:Once(function()
			if token == notificationToken and activeNotification then
				activeNotification.Visible = false
			end
		end)
	end)
end

if notificationRemote then
	notificationRemote.OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" and payload.Action == "Show" then
			showBottomRightNotification(payload.Text, payload.Duration)
		end
	end)
end

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

local function getSortedCharacters(ownedOnly)
	local characters = {}

	for _, characterName in ipairs(getCharacterOrder()) do
		local data = getCharacterData(characterName)

		if data and (not ownedOnly or isOwned(characterName)) then
			table.insert(characters, characterName)
		end
	end

	table.sort(characters, function(a, b)
		local dataA = getCharacterData(a) or {}
		local dataB = getCharacterData(b) or {}
		local costA = dataA.Cost or 0
		local costB = dataB.Cost or 0

		if costA == costB then
			return (dataA.DisplayName or a) < (dataB.DisplayName or b)
		end

		return costA < costB
	end)

	return characters
end

local function getSkinConfig(characterName)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local characters = assets and assets:FindFirstChild("Characters")
	local characterFolder = characters and characters:FindFirstChild(characterName)
	local modulesFolder = characterFolder and characterFolder:FindFirstChild("Modules")
	local skinModule = modulesFolder and modulesFolder:FindFirstChild("SkinModule")

	if not skinModule or not skinModule:IsA("ModuleScript") then
		return nil
	end

	local success, result = pcall(require, skinModule)

	if success and typeof(result) == "table" then
		return result
	end

	warn("[TopbarUI] Failed to load SkinModule for", characterName)
	return nil
end

local function getSkinData(characterName, skinName)
	local skinConfig = getSkinConfig(characterName)
	if not skinConfig then
		return nil, "Default"
	end

	local defaultSkinName = skinConfig.DefaultSkin or "Default"
	local resolvedSkinName = skinName or defaultSkinName
	local skinData = skinConfig.Skins and skinConfig.Skins[resolvedSkinName]

	if not skinData then
		resolvedSkinName = defaultSkinName
		skinData = skinConfig.Skins and skinConfig.Skins[resolvedSkinName]
	end

	return skinData, resolvedSkinName
end

local function getSkinOrder(characterName)
	local skinConfig = getSkinConfig(characterName)
	local skins = skinConfig and skinConfig.Skins
	local order = {}

	if typeof(skins) ~= "table" then
		return order, skins
	end

	for skinName in pairs(skins) do
		table.insert(order, skinName)
	end

	table.sort(order, function(a, b)
		if a == (skinConfig.DefaultSkin or "Default") then
			return true
		end

		if b == (skinConfig.DefaultSkin or "Default") then
			return false
		end

		local skinA = skins[a] or {}
		local skinB = skins[b] or {}

		return (skinA.DisplayName or a) < (skinB.DisplayName or b)
	end)

	return order, skins
end

local function isSkinOwned(characterName, skinName, skinData)
	if skinData and (skinData.Free == true or (skinData.Cost or 0) <= 0) then
		return true
	end

	if profile and profile.OwnedSkins and profile.OwnedSkins[characterName] then
		return profile.OwnedSkins[characterName][skinName] == true
	end

	return false
end

local function getEquippedSkin(characterName)
	if profile and profile.EquippedSkins and typeof(profile.EquippedSkins[characterName]) == "string" then
		return profile.EquippedSkins[characterName]
	end

	local attributeSkin = player:GetAttribute("EquippedSkin_" .. characterName)
	if typeof(attributeSkin) == "string" then
		return attributeSkin
	end

	local _, defaultSkinName = getSkinData(characterName, nil)
	return defaultSkinName or "Default"
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

local function clearCurrentGui()
	local wasCustomize = currentPanelName == "Customize"

	if currentGui then
		currentGui:Destroy()
		currentGui = nil
	end

	if wasCustomize then
		shopPreviewController:Exit()
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

local function requestPlayAs(characterName, skinName)
	if isOwned(characterName) then
		characterRemote:FireServer("PlayAsCharacter", {
			CharacterName = characterName,
			SkinName = skinName or getEquippedSkin(characterName),
			MorphEnabled = morphEnabled,
		})
	end
end

local function showShop()
	if currentPanelName == "ShopUI" then
		clearCurrentGui()
		deselectAllTopIcons()
		return
	end

	local root = makePanelRoot("ShopUI")

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
	selectedCustomizeCharacter = selectedCustomizeCharacter or selectedCharacter
	shopPreviewController:Enter(selectedCustomizeCharacter, selectedCustomizeSkin)
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
		UDim2.new(1, -260, 0, 52),
		14,
		false
	)

	local playAsButton = makeButton(
		bottomPanel,
		"PlayAsButton",
		"Play As",
		UDim2.new(1, -228, 0, 18),
		UDim2.fromOffset(96, 34),
		Color3.fromRGB(42, 56, 80)
	)

	local morphButton = makeButton(
		bottomPanel,
		"MorphToggle",
		morphEnabled and "Morph: On" or "Morph: Off",
		UDim2.new(1, -120, 0, 18),
		UDim2.fromOffset(104, 34),
		morphEnabled and Color3.fromRGB(48, 76, 54) or Color3.fromRGB(42, 42, 50)
	)

	local purchaseLabel = makeText(
		bottomPanel,
		"PurchaseLabel",
		"",
		UDim2.new(1, -228, 0, 58),
		UDim2.fromOffset(212, 24),
		12,
		false,
		Color3.fromRGB(235, 210, 175)
	)

	local confirmButton = makeButton(
		bottomPanel,
		"ConfirmBuyButton",
		"Confirm",
		UDim2.new(1, -228, 0, 88),
		UDim2.fromOffset(96, 30),
		Color3.fromRGB(90, 50, 36)
	)

	local cancelButton = makeButton(
		bottomPanel,
		"CancelBuyButton",
		"Cancel",
		UDim2.new(1, -120, 0, 88),
		UDim2.fromOffset(104, 30),
		Color3.fromRGB(42, 42, 50)
	)

	confirmButton.Visible = false
	cancelButton.Visible = false

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

		selectedCustomizeCharacter = characterName

		selectedCustomizeSkin = getEquippedSkin(characterName)

		characterNameLabel.Text = data.DisplayName or characterName
		roleLabel.Text = data.Role or ""
		descriptionLabel.Text = data.Description or "No description yet."

		local owned = isOwned(characterName)
		playAsButton.Text = owned and "Play As" or "Locked"
		playAsButton.Active = owned
		playAsButton.AutoButtonColor = owned
		playAsButton.BackgroundColor3 = owned
			and Color3.fromRGB(42, 56, 80)
			or Color3.fromRGB(45, 36, 36)

		shopPreviewController:Enter(characterName, selectedCustomizeSkin)
	end

	local function clearPurchaseConfirm()
		pendingPurchaseCharacter = nil
		pendingPurchaseSkin = nil
		purchaseLabel.Text = ""
		confirmButton.Visible = false
		cancelButton.Visible = false
	end

	local function showPurchaseConfirm(characterName)
		local data = getCharacterData(characterName)
		if not data then return end

		pendingPurchaseCharacter = characterName
		purchaseLabel.Text = "Buy " .. (data.DisplayName or characterName) .. " for " .. tostring(data.Cost or 0) .. " Dust?"
		confirmButton.Visible = true
		cancelButton.Visible = true
	end

	local function showSkinPurchaseConfirm(characterName, skinName, skinData)
		pendingPurchaseCharacter = characterName
		pendingPurchaseSkin = skinName
		purchaseLabel.Text = "Buy " .. (skinData.DisplayName or skinName) .. " for " .. tostring(skinData.Cost or 0) .. " Dust?"
		confirmButton.Visible = true
		cancelButton.Visible = true
	end

	playAsButton.MouseButton1Click:Connect(function()
		if not isOwned(selectedCustomizeCharacter) then
			return
		end

		requestPlayAs(selectedCustomizeCharacter, selectedCustomizeSkin)
	end)

	morphButton.MouseButton1Click:Connect(function()
		morphEnabled = not morphEnabled
		morphButton.Text = morphEnabled and "Morph: On" or "Morph: Off"
		morphButton.BackgroundColor3 = morphEnabled
			and Color3.fromRGB(48, 76, 54)
			or Color3.fromRGB(42, 42, 50)
	end)

	confirmButton.MouseButton1Click:Connect(function()
		if not pendingPurchaseCharacter then
			return
		end

		if pendingPurchaseSkin then
			progressionRemote:FireServer({
				Action = "BuySkin",
				CharacterName = pendingPurchaseCharacter,
				SkinName = pendingPurchaseSkin,
			})
		else
			progressionRemote:FireServer({
				Action = "BuyCharacter",
				CharacterName = pendingPurchaseCharacter,
			})
		end

		purchaseLabel.Text = "Purchase request sent."
		confirmButton.Visible = false
		cancelButton.Visible = false
	end)

	cancelButton.MouseButton1Click:Connect(clearPurchaseConfirm)

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
			for _, characterName in ipairs(getSortedCharacters(false)) do
				local data = getCharacterData(characterName)

				if data then
					local owned = isOwned(characterName)
					local text = data.DisplayName or characterName

					if not owned then
						text ..= "  -  " .. tostring(data.Cost or 0) .. " Dust"
					end

					addItemButton(text, function()
						clearPurchaseConfirm()
						setBottomInfo(characterName)

						if not owned then
							showPurchaseConfirm(characterName)
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
			local skinOrder, skins = getSkinOrder(selectedCustomizeCharacter)

			if #skinOrder == 0 then
				addItemButton("Default Skin", function()
					selectedCustomizeSkin = "Default"
					shopPreviewController:Enter(selectedCustomizeCharacter, selectedCustomizeSkin)
				end, true)
			else
				for _, skinName in ipairs(skinOrder) do
					local skin = skins[skinName] or {}
					local owned = isSkinOwned(selectedCustomizeCharacter, skinName, skin)
					local text = skin.DisplayName or skinName

					if not owned then
						text ..= "  -  " .. tostring(skin.Cost or 0) .. " Dust"
					end

					addItemButton(text, function()
						clearPurchaseConfirm()
						selectedCustomizeSkin = skinName
						shopPreviewController:Enter(selectedCustomizeCharacter, selectedCustomizeSkin)

						if owned then
							progressionRemote:FireServer({
								Action = "EquipSkin",
								CharacterName = selectedCustomizeCharacter,
								SkinName = skinName,
							})
						else
							showSkinPurchaseConfirm(selectedCustomizeCharacter, skinName, skin)
						end
					end, owned)
				end
			end
		elseif category == "Emotes" then
			addItemButton("Future Emote Slot", function() end, false)
		end
	end

	local categories = {
		"Characters",
		"Skins",
		"Titles",
		"Emotes",
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

	setBottomInfo(selectedCustomizeCharacter)
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

	for _, characterName in ipairs(getSortedCharacters(true)) do
		local data = getCharacterData(characterName)

		if data then
			local displayName = data.DisplayName or characterName

			local itemIcon = Icon.new()
				:setName("Character_" .. characterName)
				:setLabel(displayName)
				:oneClick(true)

			itemIcon:bindEvent("selected", function()
				requestPlayAs(characterName)
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
			local oldCharacter = selectedCustomizeCharacter
			local oldSkin = selectedCustomizeSkin

			clearCurrentGui()

			selectedCustomizeCategory = oldCategory
			selectedCustomizeCharacter = oldCharacter
			selectedCustomizeSkin = oldSkin

			showCustomize()
		end
	end
end)

player:GetAttributeChangedSignal("Dust"):Connect(refreshDust)

player.CharacterAdded:Connect(function(character)
	if currentPanelName == "Customize" then
		shopPreviewController:HandleCharacterRespawnedDuringCustomize(character)
	end
end)

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
