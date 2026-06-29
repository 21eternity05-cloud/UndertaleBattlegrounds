local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local characterRemote = remotes:WaitForChild("CharacterRemote")
local progressionRemote = remotes:WaitForChild("ProgressionRemote")
local settingsRemote = remotes:WaitForChild("SettingsRemote")
local notificationRemote = remotes:WaitForChild("NotificationRemote", 10)

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Icon = require(Packages:WaitForChild("TopBarPlus"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterData = require(Shared:WaitForChild("CharacterData"))
local CustomizationData = require(Shared:WaitForChild("CustomizationData"))
local TitleData = require(Shared:WaitForChild("TitleData"))
local EmoteData = require(Shared:WaitForChild("EmoteData"))
local DevProductData = require(Shared:WaitForChild("DevProductData"))
local DeveloperPermissions = require(Shared:WaitForChild("DeveloperPermissions"))

local ClientModules = script.Parent.Parent:WaitForChild("ClientModules")
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
local selectedCustomizeTitle = nil
local selectedCustomizeEmote = "DefaultDance"
local selectedEmoteSlot = 1
local emoteStatusMessage = ""
local shopStatusMessage = ""
local shopExpandedSections = {
	Support = true,
}
local morphEnabled = false
local pendingPurchaseCharacter = nil
local pendingPurchaseSkin = nil
local settings = {
	Music = true,
	CameraShake = true,
	MorphAlways = false,
	Titles = true,
}

local shopPreviewController = ShopPreviewController.new(player, ReplicatedStorage)
shopPreviewController:Start()

local hiddenCombatGuiStates = {}

local HIDDEN_GUI_NAMES = {
	MoveHUD = true,
}

local gui = Instance.new("ScreenGui")
gui.Name = "TopBarPlusMenus"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local activeNotification = nil
local activeNotificationTween = nil
local notificationToken = 0
local PIXEL_FONT = Enum.Font.Arcade
local UT_WHITE = Color3.fromRGB(255, 255, 255)
local UT_BLACK = Color3.fromRGB(0, 0, 0)
local UT_GRAY = Color3.fromRGB(150, 150, 150)
local UT_ORANGE = Color3.fromRGB(255, 150, 40)
local UT_YELLOW = Color3.fromRGB(255, 190, 40)

local function getMenuSoundsFolder()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local ui = assets and assets:FindFirstChild("UI")
	local menu = ui and ui:FindFirstChild("Menu")

	return menu and menu:FindFirstChild("Sounds") or nil
end

local function playMenuSound(soundName)
	local sounds = getMenuSoundsFolder()
	local template = sounds and sounds:FindFirstChild(soundName)
	if not template or not template:IsA("Sound") then
		return
	end

	local sound = template:Clone()
	sound.Parent = gui
	sound:Play()
	Debris:AddItem(sound, math.max(sound.TimeLength, 1) + 1)
end

local function addUndertaleStroke(instance, color, thickness)
	local stroke = instance:FindFirstChildOfClass("UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Parent = instance
	end

	stroke.Color = color or UT_WHITE
	stroke.Thickness = thickness or 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.LineJoinMode = Enum.LineJoinMode.Miter

	return stroke
end

local function setStrokeThickness(instance, thickness)
	local stroke = instance:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Thickness = thickness
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.LineJoinMode = Enum.LineJoinMode.Miter
	end
end

local function addListPadding(scrollingFrame, padding)
	local inset = padding or 4
	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingTop = UDim.new(0, inset)
	listPadding.PaddingBottom = UDim.new(0, inset)
	listPadding.PaddingLeft = UDim.new(0, inset)
	listPadding.PaddingRight = UDim.new(0, inset)
	listPadding.Parent = scrollingFrame

	return listPadding
end

local function removeRoundedCorners(instance)
	for _, child in ipairs(instance:GetChildren()) do
		if child:IsA("UICorner") then
			child:Destroy()
		end
	end
end

local function applyPixelText(textObject)
	textObject.Font = PIXEL_FONT
	textObject.TextColor3 = textObject.TextColor3 or UT_WHITE
end

local function showBottomRightNotification(text, duration)
	notificationToken += 1
	local token = notificationToken
	playMenuSound("Notification")

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
		activeNotification.BackgroundTransparency = 0
		activeNotification.BorderSizePixel = 0
		activeNotification.Font = PIXEL_FONT
		activeNotification.TextSize = 12
		activeNotification.TextColor3 = UT_WHITE
		activeNotification.TextWrapped = true
		activeNotification.Parent = gui

		addUndertaleStroke(activeNotification, UT_WHITE, 3)
	end

	activeNotification.Text = text or ""
	activeNotification.TextTransparency = 0
	activeNotification.BackgroundTransparency = 0
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

	if DeveloperPermissions.CanAccessCharacter(player, data)
		and not DeveloperPermissions.IsPublicCharacter(data)
	then
		return true
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

local function canShowCharacter(characterName)
	local data = getCharacterData(characterName)

	if not data then
		return false
	end

	return DeveloperPermissions.CanAccessCharacter(player, data)
end

local function canPreviewCharacter(characterName)
	local data = getCharacterData(characterName)

	return DeveloperPermissions.CanPreviewCharacter(player, data)
end

local function isPreviewOnlyCharacter(characterName)
	local data = getCharacterData(characterName)

	if not data then
		return false
	end

	return not DeveloperPermissions.CanAccessCharacter(player, data)
end

local function getSortedCharacters(ownedOnly)
	local characters = {}

	for _, characterName in ipairs(getCharacterOrder()) do
		local data = getCharacterData(characterName)

		if data and canShowCharacter(characterName) and (not ownedOnly or isOwned(characterName)) then
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

local function getSortedCustomizeCharacters()
	local characters = {}

	for _, characterName in ipairs(getCharacterOrder()) do
		if canPreviewCharacter(characterName) then
			table.insert(characters, characterName)
		end
	end

	table.sort(characters, function(a, b)
		local dataA = getCharacterData(a) or {}
		local dataB = getCharacterData(b) or {}

		if DeveloperPermissions.IsPublicCharacter(dataA) ~= DeveloperPermissions.IsPublicCharacter(dataB) then
			return DeveloperPermissions.IsPublicCharacter(dataA)
		end

		return (dataA.DisplayName or a) < (dataB.DisplayName or b)
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

	for skinName, skinData in pairs(skins) do
		if typeof(skinData) == "table"
			and skinData.Hidden ~= true
			and (skinData.DeveloperOnly ~= true or DeveloperPermissions.IsDeveloper(player))
		then
			table.insert(order, skinName)
		end
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

local function isTitleOwned(titleId, titleData)
	if titleData and titleData.Starter == true then
		return true
	end

	if profile and profile.OwnedTitles and profile.OwnedTitles[titleId] == true then
		return true
	end

	return false
end

local function getSortedTitles()
	local titles = {}

	for titleId, data in pairs(TitleData) do
		if typeof(data) == "table" and (data.Hidden ~= true or isTitleOwned(titleId, data)) then
			table.insert(titles, titleId)
		end
	end

	table.sort(titles, function(left, right)
		local leftData = TitleData[left] or {}
		local rightData = TitleData[right] or {}
		local leftOrder = leftData.Order or math.huge
		local rightOrder = rightData.Order or math.huge

		if leftOrder == rightOrder then
			return (leftData.DisplayName or left) < (rightData.DisplayName or right)
		end

		return leftOrder < rightOrder
	end)

	return titles
end

local getEquippedEmote
local getEmoteEquippedSlot

local function getSortedEmotes()
	local emotes = {}

	for emoteId, data in pairs(EmoteData) do
		if typeof(data) == "table" then
			table.insert(emotes, emoteId)
		end
	end

	table.sort(emotes, function(left, right)
		local leftData = EmoteData[left] or {}
		local rightData = EmoteData[right] or {}
		local leftSlot = getEmoteEquippedSlot(left)
		local rightSlot = getEmoteEquippedSlot(right)

		if leftSlot and rightSlot then
			return leftSlot < rightSlot
		end

		if leftSlot then
			return true
		end

		if rightSlot then
			return false
		end

		local leftOrder = leftData.Order or math.huge
		local rightOrder = rightData.Order or math.huge

		if leftOrder == rightOrder then
			return (leftData.DisplayName or left) < (rightData.DisplayName or right)
		end

		return leftOrder < rightOrder
	end)

	return emotes
end

local function isEmoteOwned(emoteId, emoteData)
	if emoteData and (emoteData.Starter == true or emoteData.Free == true or (emoteData.Cost or 0) <= 0) then
		return true
	end

	return profile and profile.OwnedEmotes and profile.OwnedEmotes[emoteId] == true
end

getEquippedEmote = function(slot)
	if not profile or typeof(profile.EquippedEmotes) ~= "table" then
		return nil
	end

	local emoteId = profile.EquippedEmotes[slot] or profile.EquippedEmotes[tostring(slot)]
	if typeof(emoteId) == "string" and EmoteData[emoteId] then
		return emoteId
	end

	return nil
end

getEmoteEquippedSlot = function(emoteId)
	if not profile or typeof(profile.EquippedEmotes) ~= "table" then
		return nil
	end

	for slot = 1, 8 do
		if getEquippedEmote(slot) == emoteId then
			return slot
		end
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
	label.Font = PIXEL_FONT
	label.TextSize = (textSize or 13) + 2
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextColor3 = color or UT_WHITE
	label.Text = text
	label.Parent = parent

	return label
end

local function makeButton(parent, name, text, position, size, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = position
	button.Size = size
	button.BackgroundColor3 = color or UT_BLACK
	button.BackgroundTransparency = 0
	button.BorderSizePixel = 0
	button.Font = PIXEL_FONT
	button.TextSize = 14
	button.TextColor3 = UT_WHITE
	button.Text = text
	button.AutoButtonColor = true
	button.Parent = parent

	local stroke = addUndertaleStroke(button, UT_WHITE, 3)

	button.MouseEnter:Connect(function()
		playMenuSound("Hover")
	end)

	button.MouseButton1Click:Connect(function()
		playMenuSound("Press")
	end)

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
	panel.BackgroundColor3 = UT_BLACK
	panel.BackgroundTransparency = 0
	panel.BorderSizePixel = 0
	panel.Parent = parent

	addUndertaleStroke(panel, UT_WHITE, 4)

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

local function applySettingsSnapshot(snapshot)
	if typeof(snapshot) ~= "table" then
		return
	end

	for settingName in pairs(settings) do
		if typeof(snapshot[settingName]) == "boolean" then
			local value = snapshot[settingName]
			settings[settingName] = value

			if player:GetAttribute("Setting_" .. settingName) ~= value then
				player:SetAttribute("Setting_" .. settingName, value)
			end
		end
	end
end

local function setLocalSetting(settingName, value)
	if settings[settingName] == nil then
		return
	end

	local enabled = value == true
	settings[settingName] = enabled

	if player:GetAttribute("Setting_" .. settingName) ~= enabled then
		player:SetAttribute("Setting_" .. settingName, enabled)
	end
end

local function sendSetting(settingName, value)
	if settings[settingName] == (value == true) then
		return
	end

	setLocalSetting(settingName, value)

	settingsRemote:FireServer({
		Action = "SetSetting",
		Setting = settingName,
		Value = settings[settingName],
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
		UDim2.fromOffset(460, 470),
		0.04
	)

	makeText(
		panel,
		"Title",
		"SHOP",
		UDim2.fromOffset(16, 14),
		UDim2.new(1, -32, 0, 28),
		22,
		true
	)

	local donatedLabel = makeText(
		panel,
		"DonatedTotal",
		"Total donated: " .. tostring((profile and profile.DonatedRobux) or 0) .. " R$",
		UDim2.fromOffset(16, 46),
		UDim2.new(1, -32, 0, 22),
		14,
		true,
		Color3.fromRGB(150, 210, 255)
	)

	local statusLabel = makeText(
		panel,
		"ShopStatus",
		shopStatusMessage,
		UDim2.fromOffset(16, 70),
		UDim2.new(1, -32, 0, 34),
		13,
		false
	)
	statusLabel.TextColor3 = Color3.fromRGB(235, 210, 175)

	local list = Instance.new("ScrollingFrame")
	list.Name = "ShopList"
	list.Position = UDim2.fromOffset(16, 110)
	list.Size = UDim2.new(1, -32, 1, -126)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel
	local listPadding = addListPadding(list, 5)

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local function setShopStatus(message)
		shopStatusMessage = message or ""
		statusLabel.Text = shopStatusMessage
		donatedLabel.Text = "Total donated: " .. tostring((profile and profile.DonatedRobux) or 0) .. " R$"
	end

	local function getSortedSections()
		local sections = table.clone(DevProductData.Sections or {})

		table.sort(sections, function(left, right)
			local leftOrder = left.Order or math.huge
			local rightOrder = right.Order or math.huge

			if leftOrder == rightOrder then
				return (left.DisplayName or left.Id or "") < (right.DisplayName or right.Id or "")
			end

			return leftOrder < rightOrder
		end)

		return sections
	end

	local function clearShopList()
		for _, child in ipairs(list:GetChildren()) do
			if child ~= layout and child ~= listPadding then
				child:Destroy()
			end
		end
	end

	local renderShopSections

	local function addSectionHeader(section)
		local sectionId = section.Id or section.DisplayName or "Section"
		local isExpanded = shopExpandedSections[sectionId] == true
		local arrow = isExpanded and "v" or ">"
		local button = makeButton(
			list,
			sectionId .. "Header",
			(section.DisplayName or sectionId) .. " " .. arrow,
			UDim2.fromOffset(0, 0),
			UDim2.new(1, -12, 0, 36),
			Color3.fromRGB(34, 34, 44)
		)
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.Text = "  " .. button.Text
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = isExpanded and UT_ORANGE or UT_WHITE
		end

		button.MouseButton1Click:Connect(function()
			shopExpandedSections[sectionId] = not isExpanded
			renderShopSections()
		end)
	end

	local function addComingSoon(section)
		makeText(
			list,
			(section.Id or "Section") .. "ComingSoon",
			section.ComingSoonText or "Coming soon",
			UDim2.fromOffset(0, 0),
			UDim2.new(1, -6, 0, 28),
			13,
			false,
			Color3.fromRGB(170, 170, 182)
		)
	end

	local function addProductRow(productKey, product)
		local row = Instance.new("Frame")
		row.Name = productKey .. "Row"
		row.Size = UDim2.new(1, -12, 0, 118)
		row.BackgroundColor3 = UT_BLACK
		row.BackgroundTransparency = 0
		row.BorderSizePixel = 0
		row.Parent = list

		addUndertaleStroke(row, UT_WHITE, 3)

		makeText(
			row,
			"Name",
			product.DisplayName or productKey,
			UDim2.fromOffset(12, 10),
			UDim2.new(1, -24, 0, 22),
			16,
			true
		)

		makeText(
			row,
			"Description",
			product.Description or "",
			UDim2.fromOffset(12, 36),
			UDim2.new(1, -128, 0, 44),
			13,
			false,
			Color3.fromRGB(210, 210, 220)
		)

		makeText(
			row,
			"Price",
			tostring(product.AmountRobux or 0) .. " R$",
			UDim2.fromOffset(12, 84),
			UDim2.fromOffset(90, 22),
			14,
			true,
			Color3.fromRGB(235, 210, 175)
		)

		local buyButton = makeButton(
			row,
			"BuyButton",
			product.ProductType == "Donation" and "Donate" or "Buy",
			UDim2.new(1, -104, 0, 76),
			UDim2.fromOffset(88, 30),
			Color3.fromRGB(42, 56, 80)
		)

		buyButton.MouseButton1Click:Connect(function()
			local productId = tonumber(product.ProductId)
			if not productId or productId <= 0 then
				setShopStatus("Product not configured yet.")
				showBottomRightNotification("Product not configured yet.", 2.5)
				return
			end

			setShopStatus("Opening purchase prompt...")
			MarketplaceService:PromptProductPurchase(player, productId)
		end)
	end

	renderShopSections = function()
		clearShopList()

		for _, section in ipairs(getSortedSections()) do
			local sectionId = section.Id or section.DisplayName or "Section"
			if shopExpandedSections[sectionId] == nil then
				shopExpandedSections[sectionId] = section.OpenByDefault == true
			end

			addSectionHeader(section)

			if shopExpandedSections[sectionId] then
				if section.Enabled == false then
					addComingSoon(section)
				else
					local productKeys = table.clone(section.Products or {})
					table.sort(productKeys, function(left, right)
						local leftProduct = DevProductData.Products[left] or {}
						local rightProduct = DevProductData.Products[right] or {}

						return (leftProduct.Order or math.huge) < (rightProduct.Order or math.huge)
					end)

					if #productKeys == 0 then
						addComingSoon(section)
					end

					for _, productKey in ipairs(productKeys) do
						local product = DevProductData.Products[productKey]
						if typeof(product) == "table" then
							addProductRow(productKey, product)
						end
					end
				end
			end
		end
	end

	renderShopSections()
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

	local settingRows = {
		{ Id = "Music", Label = "Music" },
		{ Id = "CameraShake", Label = "Camera Shake" },
		{ Id = "MorphAlways", Label = "Morph Always" },
		{ Id = "Titles", Label = "Titles" },
	}

	local helpPanel = nil
	local function closeHelp()
		if helpPanel then
			helpPanel:Destroy()
			helpPanel = nil
		end
	end

	local function showHelp()
		closeHelp()

		helpPanel = makeFloatingPanel(
			root,
			"ControlsHelpPanel",
			UDim2.fromOffset(430, 54),
			UDim2.fromOffset(360, 390),
			0.04
		)

		makeText(
			helpPanel,
			"HelpTitle",
			"Controls",
			UDim2.fromOffset(16, 14),
			UDim2.new(1, -92, 0, 28),
			20,
			true
		)

		local closeButton = makeButton(
			helpPanel,
			"CloseHelp",
			"X",
			UDim2.new(1, -54, 0, 12),
			UDim2.fromOffset(38, 32),
			Color3.fromRGB(45, 36, 36)
		)
		closeButton.MouseButton1Click:Connect(closeHelp)

		local controls = {
			"Mouse hold - M1 auto combo",
			"Spacebar + Mouse - Uptilt",
			"F - Block",
			"Q - Dash",
			"Q while stunned - Soul Burst",
			"R - Emote Wheel",
			"1, 2, 3, 4 - Moves",
			"G - Ultimate Move",
		}

		for index, line in ipairs(controls) do
			local label = makeText(
				helpPanel,
				"ControlLine" .. tostring(index),
				line,
				UDim2.fromOffset(18, 58 + (index - 1) * 34),
				UDim2.new(1, -36, 0, 26),
				14,
				false
			)
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextColor3 = Color3.fromRGB(245, 245, 248)
		end
	end

	for index, settingInfo in ipairs(settingRows) do
		local rowY = 58 + (index - 1) * 48
		local label = makeText(
			panel,
			settingInfo.Id .. "Label",
			settingInfo.Label,
			UDim2.fromOffset(16, rowY + 8),
			UDim2.new(1, -124, 0, 22),
			15,
			true
		)
		label.TextColor3 = Color3.fromRGB(245, 245, 248)

		local toggle = makeButton(
			panel,
			settingInfo.Id .. "Toggle",
			"",
			UDim2.new(1, -92, 0, rowY),
			UDim2.fromOffset(76, 36),
			Color3.fromRGB(42, 42, 50)
		)

		local function refreshToggle()
			local enabled = settings[settingInfo.Id] == true
			toggle.Text = enabled and "ON" or "OFF"
			toggle.BackgroundColor3 = enabled
				and Color3.fromRGB(48, 76, 54)
				or Color3.fromRGB(62, 45, 45)
		end

		refreshToggle()

		toggle.MouseButton1Click:Connect(function()
			sendSetting(settingInfo.Id, settings[settingInfo.Id] ~= true)
			refreshToggle()
		end)
	end

	local helpButton = makeButton(
		panel,
		"HelpControlsButton",
		"Help / Controls",
		UDim2.fromOffset(16, 256),
		UDim2.new(1, -32, 0, 38),
		Color3.fromRGB(36, 36, 46)
	)
	helpButton.MouseButton1Click:Connect(showHelp)
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
	local normalDescriptionPosition = descriptionLabel.Position
	local normalDescriptionSize = descriptionLabel.Size
	local emoteDescriptionPosition = UDim2.fromOffset(16, 68)
	local emoteDescriptionSize = UDim2.new(1, -360, 0, 52)

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

	local emoteSlotButtons = {}
	for slot = 1, 8 do
		local column = (slot - 1) % 4
		local row = math.floor((slot - 1) / 4)
		local slotButton = makeButton(
			bottomPanel,
			"EmoteSlot" .. tostring(slot),
			tostring(slot),
			UDim2.new(1, -336 + column * 34, 0, 54 + row * 34),
			UDim2.fromOffset(28, 28),
			Color3.fromRGB(42, 42, 50)
		)
		slotButton.TextSize = 13
		slotButton.Visible = false
		setStrokeThickness(slotButton, 2)
		emoteSlotButtons[slot] = slotButton
	end

	local emoteBuyButton = makeButton(
		bottomPanel,
		"EmoteBuyButton",
		"Buy",
		UDim2.new(1, -190, 0, 16),
		UDim2.fromOffset(82, 30),
		Color3.fromRGB(90, 50, 36)
	)
	emoteBuyButton.Visible = false
	emoteBuyButton.TextSize = 12
	setStrokeThickness(emoteBuyButton, 2)

	local emoteEquipButton = makeButton(
		bottomPanel,
		"EmoteEquipButton",
		"Equip",
		UDim2.new(1, -98, 0, 16),
		UDim2.fromOffset(82, 30),
		Color3.fromRGB(42, 56, 80)
	)
	emoteEquipButton.Visible = false
	emoteEquipButton.TextSize = 11
	emoteEquipButton.TextScaled = true
	emoteEquipButton.TextWrapped = true
	setStrokeThickness(emoteEquipButton, 2)

	local emoteClearButton = makeButton(
		bottomPanel,
		"EmoteClearButton",
		"Clear Slot",
		UDim2.new(1, -190, 0, 54),
		UDim2.fromOffset(174, 30),
		Color3.fromRGB(62, 45, 45)
	)
	emoteClearButton.Visible = false
	emoteClearButton.TextSize = 12
	setStrokeThickness(emoteClearButton, 2)

	local emotePreviewButton = makeButton(
		bottomPanel,
		"EmotePreviewButton",
		"Preview",
		UDim2.new(1, -190, 0, 92),
		UDim2.fromOffset(174, 30),
		Color3.fromRGB(42, 42, 50)
	)
	emotePreviewButton.Visible = false
	emotePreviewButton.TextSize = 12
	setStrokeThickness(emotePreviewButton, 2)

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
	local itemListPadding = addListPadding(itemList, 3)

	local itemLayout = Instance.new("UIListLayout")
	itemLayout.Padding = UDim.new(0, 8)
	itemLayout.SortOrder = Enum.SortOrder.LayoutOrder
	itemLayout.Parent = itemList

	local function clearItems()
		for _, child in ipairs(itemList:GetChildren()) do
			if child ~= itemLayout and child ~= itemListPadding then
				child:Destroy()
			end
		end
	end

	local function setEmoteControlsVisible(visible)
		playAsButton.Visible = not visible
		morphButton.Visible = not visible
		emoteBuyButton.Visible = visible
		emoteEquipButton.Visible = visible
		emoteClearButton.Visible = visible
		emotePreviewButton.Visible = visible
		descriptionLabel.Position = visible and emoteDescriptionPosition or normalDescriptionPosition
		descriptionLabel.Size = visible and emoteDescriptionSize or normalDescriptionSize

		if not visible then
			shopPreviewController:StopPreviewEmote()
			if shopPreviewController.ActivePreviewModel and shopPreviewController.LastCharacterName then
				shopPreviewController:PlayPreviewIdle(
					shopPreviewController.LastCharacterName,
					shopPreviewController.ActivePreviewModel
				)
			end
		end

		for _, slotButton in pairs(emoteSlotButtons) do
			slotButton.Visible = visible
		end
	end

	local function refreshEmoteBottom()
		local emoteId = selectedCustomizeEmote
		local data = emoteId and EmoteData[emoteId]
		local owned = data and isEmoteOwned(emoteId, data)
		local equippedSlot = emoteId and getEmoteEquippedSlot(emoteId)
		local selectedSlotEmote = getEquippedEmote(selectedEmoteSlot)

		if data then
			characterNameLabel.Text = data.DisplayName or emoteId
			roleLabel.Text = emoteStatusMessage ~= "" and emoteStatusMessage
				or (owned and "Owned. Choose a slot to equip." or (tostring(data.Cost or 0) .. " Dust"))
			descriptionLabel.Text = data.Description or "No description yet."
		else
			characterNameLabel.Text = "Emotes"
			roleLabel.Text = ""
			descriptionLabel.Text = "Select an emote."
		end

		if equippedSlot then
			roleLabel.Text = "Equipped in slot " .. tostring(equippedSlot)
		end

		for slot, slotButton in pairs(emoteSlotButtons) do
			local slotEmote = getEquippedEmote(slot)
			slotButton.Text = slotEmote and tostring(slot) or tostring(slot)
			slotButton.BackgroundColor3 = slot == selectedEmoteSlot
				and Color3.fromRGB(58, 58, 70)
				or (slotEmote and Color3.fromRGB(42, 56, 80) or Color3.fromRGB(42, 42, 50))
		end

		emoteBuyButton.Visible = data ~= nil and not owned
		emoteBuyButton.Active = data ~= nil and not owned
		emoteBuyButton.AutoButtonColor = data ~= nil and not owned
		emoteBuyButton.Text = data and ("Buy " .. tostring(data.Cost or 0)) or "Buy"

		emoteEquipButton.Visible = data ~= nil and owned == true
		emoteEquipButton.Active = data ~= nil and owned == true
		emoteEquipButton.AutoButtonColor = data ~= nil and owned == true
		emoteEquipButton.Text = "Equip Slot " .. tostring(selectedEmoteSlot)

		emoteClearButton.Visible = selectedSlotEmote ~= nil
		emoteClearButton.Active = selectedSlotEmote ~= nil
		emoteClearButton.AutoButtonColor = selectedSlotEmote ~= nil

		emotePreviewButton.Visible = data ~= nil
	end

	local function setCharacterBottomInfo(characterName)
		setEmoteControlsVisible(false)
		local data = getCharacterData(characterName)

		if not data then
			return
		end

		selectedCustomizeCharacter = characterName

		selectedCustomizeSkin = getEquippedSkin(characterName)

		characterNameLabel.Text = data.DisplayName or characterName
		local previewOnly = isPreviewOnlyCharacter(characterName)
		roleLabel.Text = previewOnly and "COMING SOON" or (data.Role or "")
		descriptionLabel.Text = previewOnly
			and ((data.Description or "No description yet.") .. "\nPreview only. This character is not publicly selectable yet.")
			or (data.Description or "No description yet.")

		local owned = isOwned(characterName)
		local canPlay = owned and not previewOnly
		playAsButton.Text = previewOnly and "Coming Soon" or (owned and "Play As" or "Locked")
		playAsButton.Active = canPlay
		playAsButton.AutoButtonColor = canPlay
		playAsButton.BackgroundColor3 = canPlay
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

	local function setSkinBottomInfo(characterName, skinName, skinData)
		local characterData = getCharacterData(characterName) or {}
		characterNameLabel.Text = characterData.DisplayName or characterName
		roleLabel.Text = skinData.DisplayName or skinName
		descriptionLabel.Text = skinData.Description or "No skin description yet."
	end

	local function setTitleBottomInfo(titleId, titleData)
		selectedCustomizeTitle = titleId
		characterNameLabel.Text = "Title"
		roleLabel.Text = titleData.DisplayName or titleId
		descriptionLabel.Text = titleData.Description or "No title description yet."
	end

	local function findCurrentTitleInfo()
		local titleId = selectedCustomizeTitle

		if typeof(titleId) ~= "string" or not TitleData[titleId] then
			titleId = profile and profile.EquippedTitle
		end

		if typeof(titleId) ~= "string" or not TitleData[titleId] then
			titleId = "None"
		end

		if TitleData[titleId] then
			return titleId, TitleData[titleId]
		end

		for _, fallbackTitleId in ipairs(getSortedTitles()) do
			local data = TitleData[fallbackTitleId]
			if typeof(data) == "table" then
				return fallbackTitleId, data
			end
		end

		return nil, nil
	end

	local function findCurrentSkinInfo()
		local skinOrder, skins = getSkinOrder(selectedCustomizeCharacter)
		local skinName = selectedCustomizeSkin

		if typeof(skinName) ~= "string" or skinName == "" or not skins[skinName] then
			skinName = getEquippedSkin(selectedCustomizeCharacter)
		end

		if typeof(skinName) ~= "string" or skinName == "" or not skins[skinName] then
			skinName = skinOrder[1] or "Default"
		end

		return skinName, skins[skinName] or {
			DisplayName = skinName == "Default" and "Default" or skinName,
			Description = "No skin description yet.",
		}
	end

	local function refreshBottomForCategory(category)
		if category == "Skins" then
			setEmoteControlsVisible(false)
			local skinName, skinData = findCurrentSkinInfo()
			setSkinBottomInfo(selectedCustomizeCharacter, skinName, skinData)
		elseif category == "Titles" then
			setEmoteControlsVisible(false)
			local titleId, titleData = findCurrentTitleInfo()
			if titleId and titleData then
				setTitleBottomInfo(titleId, titleData)
			else
				characterNameLabel.Text = "Title"
				roleLabel.Text = ""
				descriptionLabel.Text = "No title description yet."
			end
		elseif category == "Emotes" then
			setEmoteControlsVisible(true)
			refreshEmoteBottom()
		else
			setCharacterBottomInfo(selectedCustomizeCharacter)
		end
	end

	playAsButton.MouseButton1Click:Connect(function()
		if not isOwned(selectedCustomizeCharacter) or isPreviewOnlyCharacter(selectedCustomizeCharacter) then
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

	for slot, slotButton in pairs(emoteSlotButtons) do
		slotButton.MouseButton1Click:Connect(function()
			selectedEmoteSlot = slot
			emoteStatusMessage = ""
			refreshEmoteBottom()
		end)
	end

	emoteBuyButton.MouseButton1Click:Connect(function()
		if not selectedCustomizeEmote then
			return
		end

		progressionRemote:FireServer({
			Action = "BuyEmote",
			EmoteId = selectedCustomizeEmote,
		})

		emoteStatusMessage = "Purchase request sent."
		refreshEmoteBottom()
	end)

	emoteEquipButton.MouseButton1Click:Connect(function()
		if not selectedCustomizeEmote then
			return
		end

		progressionRemote:FireServer({
			Action = "EquipEmote",
			EmoteId = selectedCustomizeEmote,
			Slot = selectedEmoteSlot,
		})

		emoteStatusMessage = "Equip request sent."
		refreshEmoteBottom()
	end)

	emoteClearButton.MouseButton1Click:Connect(function()
		progressionRemote:FireServer({
			Action = "UnequipEmote",
			Slot = selectedEmoteSlot,
		})

		emoteStatusMessage = "Clear request sent."
		refreshEmoteBottom()
	end)

	emotePreviewButton.MouseButton1Click:Connect(function()
		if selectedCustomizeEmote then
			shopPreviewController:PreviewEmote(selectedCustomizeEmote)
		end
	end)

	local function addItemButton(text, callback, owned)
		local safeName = text:gsub("%W+", "")

		if safeName == "" then
			safeName = "Item"
		end

		local button = Instance.new("TextButton")
		button.Name = safeName .. "Button"
		button.Size = UDim2.new(1, -8, 0, 40)
		button.BackgroundColor3 = owned == false and Color3.fromRGB(62, 45, 34) or Color3.fromRGB(36, 36, 46)
		button.BackgroundTransparency = 0
		button.BorderSizePixel = 0
		button.Font = PIXEL_FONT
		button.TextSize = 16
		button.TextColor3 = UT_WHITE
		button.TextWrapped = true
		button.AutoButtonColor = true
		button.Parent = itemList

		button.TextXAlignment = Enum.TextXAlignment.Left
		button.Text = "  " .. text

		button.MouseEnter:Connect(function()
			playMenuSound("Hover")
		end)

		button.MouseButton1Click:Connect(function()
			playMenuSound("Press")
		end)

		button.MouseButton1Click:Connect(callback)

		return button
	end

	local function showCategory(category)
		selectedCustomizeCategory = category
		clearItems()
		refreshBottomForCategory(category)

		if category == "Characters" then
			setEmoteControlsVisible(false)
			for _, characterName in ipairs(getSortedCustomizeCharacters()) do
				local data = getCharacterData(characterName)

				if data then
					local owned = isOwned(characterName)
					local previewOnly = isPreviewOnlyCharacter(characterName)
					local text = data.DisplayName or characterName

					if previewOnly then
						text ..= "  -  COMING SOON"
					elseif not owned then
						text ..= "  -  " .. tostring(data.Cost or 0) .. " Dust"
					end

					addItemButton(text, function()
						clearPurchaseConfirm()
						setCharacterBottomInfo(characterName)

						if previewOnly then
							purchaseLabel.Text = "Preview only. This character is not publicly selectable yet."
							confirmButton.Visible = false
							cancelButton.Visible = false
						elseif not owned then
							showPurchaseConfirm(characterName)
						end
					end, owned and not previewOnly)
				end
			end
		elseif category == "Titles" then
			setEmoteControlsVisible(false)
			for _, titleId in ipairs(getSortedTitles()) do
				local data = TitleData[titleId]
				if typeof(data) == "table" then
					local owned = isTitleOwned(titleId, data)
					local text = data.DisplayName or titleId

					if not owned then
						text ..= "  -  Locked"
					elseif profile and profile.EquippedTitle == titleId then
						text ..= "  -  Equipped"
					end

					addItemButton(text, function()
						clearPurchaseConfirm()
						setTitleBottomInfo(titleId, data)

						if owned then
							progressionRemote:FireServer({
								Action = "EquipTitle",
								TitleId = titleId,
							})
						end
					end, owned)
				end
			end
		elseif category == "Skins" then
			setEmoteControlsVisible(false)
			local skinOrder, skins = getSkinOrder(selectedCustomizeCharacter)

			if #skinOrder == 0 then
				addItemButton("Default Skin", function()
					clearPurchaseConfirm()
					selectedCustomizeSkin = "Default"
					shopPreviewController:Enter(selectedCustomizeCharacter, selectedCustomizeSkin)
					setSkinBottomInfo(selectedCustomizeCharacter, "Default", {
						DisplayName = "Default",
						Description = "No skin description yet.",
					})
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
						setSkinBottomInfo(selectedCustomizeCharacter, skinName, skin)

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
			clearPurchaseConfirm()
			setEmoteControlsVisible(true)

			for _, emoteId in ipairs(getSortedEmotes()) do
				local data = EmoteData[emoteId]
				local owned = isEmoteOwned(emoteId, data)
				local equippedSlot = getEmoteEquippedSlot(emoteId)
				local text = data.DisplayName or emoteId

				if equippedSlot then
					text ..= "  -  Slot " .. tostring(equippedSlot)
				elseif not owned then
					text ..= "  -  " .. tostring(data.Cost or 0) .. " Dust"
				end

				addItemButton(text, function()
					selectedCustomizeEmote = emoteId
					if equippedSlot then
						selectedEmoteSlot = equippedSlot
					end
					emoteStatusMessage = ""
					shopPreviewController:PreviewEmote(emoteId)
					refreshEmoteBottom()
				end, owned)
			end

			refreshEmoteBottom()
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

local function destroyCharacterDropdownIcons()
	if icons.Characters then
		pcall(function()
			icons.Characters:setDropdown({})
		end)
	end

	for _, itemIcon in ipairs(dropdownIcons) do
		if itemIcon then
			pcall(function()
				if itemIcon.destroy then
					itemIcon:destroy()
				elseif itemIcon.Destroy then
					itemIcon:Destroy()
				end
			end)
		end
	end

	table.clear(dropdownIcons)
end

local function rebuildCharacterDropdown()
	destroyCharacterDropdownIcons()

	local newDropdownIcons = {}
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

			table.insert(newDropdownIcons, itemIcon)
		end
	end

	dropdownIcons = newDropdownIcons

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
if icons.Settings then
	icons.Settings:setImage("rbxassetid://7059346373")
end

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
		if payload.Action == "BuyEmoteResult" then
			selectedCustomizeEmote = payload.EmoteId or selectedCustomizeEmote
			emoteStatusMessage = payload.Success == true and "Owned. Choose a slot to equip."
				or ("Could not buy emote: " .. tostring(payload.Reason or "Unknown"))
		elseif payload.Action == "EquipEmoteResult" then
			selectedCustomizeEmote = payload.EmoteId or selectedCustomizeEmote
			selectedEmoteSlot = payload.Slot or selectedEmoteSlot
			emoteStatusMessage = payload.Success == true and "Equipped."
				or ("Could not equip emote: " .. tostring(payload.Reason or "Unknown"))
		elseif payload.Action == "UnequipEmoteResult" then
			selectedEmoteSlot = payload.Slot or selectedEmoteSlot
			emoteStatusMessage = payload.Success == true and "Slot cleared."
				or ("Could not clear slot: " .. tostring(payload.Reason or "Unknown"))
		elseif payload.Action == "DonationProductResult" then
			shopStatusMessage = payload.Message or "Thank you for supporting Undertale Battlegrounds!"
			if typeof(payload.AmountRobux) == "number" and payload.AmountRobux > 0 then
				shopStatusMessage = "Thanks for donating " .. tostring(payload.AmountRobux) .. " R$!"
			end
			showBottomRightNotification(shopStatusMessage, 3)
		end

		profile = payload.Profile
		applySettingsSnapshot(profile.Settings)
		refreshDust()
		rebuildCharacterDropdown()

		if currentPanelName == "Customize" then
			local oldCategory = selectedCustomizeCategory
			local oldCharacter = selectedCustomizeCharacter
			local oldSkin = selectedCustomizeSkin
			local oldTitle = selectedCustomizeTitle
			local oldEmote = selectedCustomizeEmote
			local oldEmoteSlot = selectedEmoteSlot
			local oldEmoteStatusMessage = emoteStatusMessage

			clearCurrentGui()

			selectedCustomizeCategory = oldCategory
			selectedCustomizeCharacter = oldCharacter
			selectedCustomizeSkin = oldSkin
			selectedCustomizeTitle = oldTitle
			selectedCustomizeEmote = oldEmote
			selectedEmoteSlot = oldEmoteSlot
			emoteStatusMessage = oldEmoteStatusMessage

			showCustomize()
		elseif currentPanelName == "ShopUI" then
			clearCurrentGui()
			showShop()
		end
	end
end)

settingsRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	if payload.Settings then
		applySettingsSnapshot(payload.Settings)
	elseif payload.Action == "SettingChanged"
		and typeof(payload.Setting) == "string"
		and typeof(payload.Value) == "boolean"
	then
		setLocalSetting(payload.Setting, payload.Value)
	end

	if currentPanelName == "Settings" then
		clearCurrentGui()
		showSettings()
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
settingsRemote:FireServer({
	Action = "RequestSettings",
})

print("[TopBarUI] Loaded TSB-style TopBarPlus UI")
