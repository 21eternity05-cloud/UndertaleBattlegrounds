local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local devAdminRemote = remotes:WaitForChild("DevAdminRemote", 15)

if not devAdminRemote or not devAdminRemote:IsA("RemoteFunction") then
	return
end

local success, status = pcall(function()
	return devAdminRemote:InvokeServer("GetStatus")
end)

if not success or typeof(status) ~= "table" or status.CanUseDevMenu ~= true then
	return
end

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Icon = require(Packages:WaitForChild("TopBarPlus"))

local PIXEL_FONT = Enum.Font.Arcade
local UT_WHITE = Color3.fromRGB(255, 255, 255)
local UT_BLACK = Color3.fromRGB(0, 0, 0)
local UT_GRAY = Color3.fromRGB(135, 135, 135)
local UT_DARK = Color3.fromRGB(16, 16, 18)
local UT_RED = Color3.fromRGB(170, 30, 40)
local UT_BLUE = Color3.fromRGB(45, 95, 220)
local UT_GREEN = Color3.fromRGB(45, 155, 70)
local UT_PURPLE = Color3.fromRGB(115, 65, 180)
local UT_YELLOW = Color3.fromRGB(235, 190, 55)

local ACTIONS = {
	{ Key = "HealSelf", Label = "Heal Self", Style = "Heal", Color = UT_GREEN },
	{ Key = "HealAll", Label = "Heal All", Style = "Heal", Color = UT_GREEN },
	{ Key = "FillSoulBurst", Label = "Fill SOUL", Style = "SoulBurst", Color = UT_BLUE },
	{ Key = "FillUlt", Label = "Fill Ult", Style = "Ult", Color = UT_RED },
	{ Key = "ToggleCooldowns", Label = "Cooldown Toggle", Style = "Cooldown", Color = UT_YELLOW },
	{ Key = "ToggleDebug", Label = "Debug Toggle", Style = "Debug", Color = UT_PURPLE },
}

local DUMMY_TYPES = {
	{ Key = "Basic", Label = "Spawn Basic Dummy" },
	{ Key = "Blocking", Label = "Spawn Blocking Dummy" },
	{ Key = "Moving", Label = "Spawn Moving Dummy" },
	{ Key = "Combo", Label = "Spawn Combo Dummy" },
	{ Key = "AirCombo", Label = "Spawn AirCombo Dummy" },
	{ Key = "SOULBURST", Label = "Spawn SOULBURST Dummy" },
	{ Key = "SUPER", Label = "Spawn SUPER Dummy" },
	{ Key = "TRUE", Label = "Spawn TRUE Dummy" },
}

local gui = Instance.new("ScreenGui")
gui.Name = "DevDebugMenuGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled = false
gui.Parent = playerGui

local selectedTab = "Combat"
local tabButtons = {}
local content = nil
local statusLabel = nil
local renderData = nil
local dataManagerState = {
	SelectedUserId = player.UserId,
	Data = nil,
	TextBoxes = {},
}

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
	Debris:AddItem(sound, math.max(sound.TimeLength, 1) + 0.5)
end

local function addStroke(instance, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or UT_WHITE
	stroke.Thickness = thickness or 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.LineJoinMode = Enum.LineJoinMode.Miter
	stroke.Parent = instance
	return stroke
end

local function applyTextStyle(textObject, size)
	textObject.Font = PIXEL_FONT
	textObject.TextSize = size or 14
	textObject.TextColor3 = UT_WHITE
	textObject.TextXAlignment = Enum.TextXAlignment.Left
	textObject.TextYAlignment = Enum.TextYAlignment.Center
end

local function setStatus(message, isSuccess)
	if not statusLabel then
		return
	end

	statusLabel.Text = message or ""
	statusLabel.TextColor3 = isSuccess == false and Color3.fromRGB(255, 110, 110) or UT_WHITE

	if isSuccess == true then
		playMenuSound("Notification")
	end
end

local function invoke(action, payload)
	local ok, result = pcall(function()
		return devAdminRemote:InvokeServer(action, payload)
	end)

	if not ok then
		return {
			Success = false,
			Message = "Remote failed.",
		}
	end

	if typeof(result) ~= "table" then
		return {
			Success = false,
			Message = "Invalid server response.",
		}
	end

	return result
end

local function findFirstImage(instance)
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("Decal") or descendant:IsA("Texture") then
			return descendant.Texture
		end

		if descendant:IsA("ImageLabel") or descendant:IsA("ImageButton") then
			return descendant.Image
		end
	end

	return nil
end

local function getLegacyButtonStyle(styleName)
	local names = {
		Heal = { "HEAL_BUTTON", "HealButton", "Heal" },
		SoulBurst = { "SOULBURST_BUTTON", "SoulBurstButton", "SoulBurst" },
		Ult = { "ULT_BUTTON", "UltButton", "UltimateButton", "Ult" },
		Cooldown = { "COOLDOWN_BUTTON", "CooldownButton", "Cooldown" },
		Debug = { "DEBUG_BUTTON", "DebugButton", "Debug" },
	}

	for _, expectedName in ipairs(names[styleName] or {}) do
		local found = Workspace:FindFirstChild(expectedName, true)
		if found then
			local part = found:IsA("BasePart") and found or found:FindFirstAncestorWhichIsA("BasePart")
			return {
				Color = part and part.Color or nil,
				Image = findFirstImage(found),
			}
		end
	end

	return {}
end

local function makeButton(parent, name, text, options)
	options = options or {}

	local button = Instance.new("TextButton")
	button.Name = name
	button.BackgroundColor3 = options.Color or UT_BLACK
	button.BorderSizePixel = 0
	button.AutoButtonColor = options.Disabled ~= true
	button.Text = text
	button.Size = options.Size or UDim2.new(1, 0, 0, 38)
	button.Parent = parent
	applyTextStyle(button, options.TextSize or 13)
	button.TextXAlignment = Enum.TextXAlignment.Center
	addStroke(button, options.StrokeColor or UT_WHITE, options.StrokeThickness or 2)

	if options.Disabled then
		button.TextColor3 = UT_GRAY
	end

	if options.Image then
		local icon = Instance.new("ImageLabel")
		icon.Name = "LegacyIcon"
		icon.BackgroundTransparency = 1
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.new(0, 8, 0.5, 0)
		icon.Size = UDim2.fromOffset(22, 22)
		icon.Image = options.Image
		icon.Parent = button
	end

	button.MouseEnter:Connect(function()
		if button.AutoButtonColor then
			playMenuSound("Hover")
		end
	end)

	button.MouseButton1Click:Connect(function()
		if button.AutoButtonColor then
			playMenuSound("Press")
		end
	end)

	return button
end

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -18, 0, 76)
panel.Size = UDim2.fromOffset(620, 420)
panel.BackgroundColor3 = UT_BLACK
panel.BorderSizePixel = 0
panel.Parent = gui
addStroke(panel, UT_WHITE, 4)

local header = Instance.new("Frame")
header.Name = "Header"
header.BackgroundColor3 = UT_BLACK
header.BorderSizePixel = 0
header.Size = UDim2.new(1, 0, 0, 62)
header.Parent = panel

local headerPad = Instance.new("UIPadding")
headerPad.PaddingLeft = UDim.new(0, 14)
headerPad.PaddingRight = UDim.new(0, 14)
headerPad.Parent = header

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, 0, 0, 36)
title.Text = "DEV DEBUG"
title.Parent = header
applyTextStyle(title, 20)

local closeButton = makeButton(header, "Close", "X", {
	Color = UT_BLACK,
	Size = UDim2.fromOffset(34, 30),
	TextSize = 16,
	StrokeThickness = 2,
})
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -2, 0, 10)

local roleLabel = Instance.new("TextLabel")
roleLabel.Name = "Role"
roleLabel.BackgroundTransparency = 1
roleLabel.Position = UDim2.new(0, 0, 0, 34)
roleLabel.Size = UDim2.new(1, 0, 0, 22)
roleLabel.Text = "Role: " .. tostring(status.Role or "Developer")
roleLabel.TextColor3 = UT_GRAY
roleLabel.Parent = header
applyTextStyle(roleLabel, 12)

local body = Instance.new("Frame")
body.Name = "Body"
body.BackgroundTransparency = 1
body.Position = UDim2.new(0, 14, 0, 76)
body.Size = UDim2.new(1, -28, 1, -90)
body.Parent = panel

local tabs = Instance.new("Frame")
tabs.Name = "Tabs"
tabs.BackgroundTransparency = 1
tabs.Size = UDim2.fromOffset(165, 260)
tabs.Parent = body

local tabLayout = Instance.new("UIListLayout")
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Padding = UDim.new(0, 10)
tabLayout.Parent = tabs

content = Instance.new("ScrollingFrame")
content.Name = "Content"
content.BackgroundColor3 = UT_DARK
content.BorderSizePixel = 0
content.Position = UDim2.new(0, 185, 0, 0)
content.Size = UDim2.new(1, -185, 1, -34)
content.CanvasSize = UDim2.fromOffset(0, 0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.ScrollBarThickness = 6
content.Parent = body
addStroke(content, UT_WHITE, 3)

local contentPadding = Instance.new("UIPadding")
contentPadding.PaddingTop = UDim.new(0, 12)
contentPadding.PaddingBottom = UDim.new(0, 12)
contentPadding.PaddingLeft = UDim.new(0, 12)
contentPadding.PaddingRight = UDim.new(0, 12)
contentPadding.Parent = content

local contentLayout = Instance.new("UIListLayout")
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Padding = UDim.new(0, 10)
contentLayout.Parent = content

statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.BackgroundTransparency = 1
statusLabel.Position = UDim2.new(0, 185, 1, -24)
statusLabel.Size = UDim2.new(1, -185, 0, 24)
statusLabel.Text = "Ready."
statusLabel.Parent = body
applyTextStyle(statusLabel, 12)

local function clearContent()
	for _, child in ipairs(content:GetChildren()) do
		if child ~= contentPadding and child ~= contentLayout then
			child:Destroy()
		end
	end
end

local function makeSectionTitle(text)
	local label = Instance.new("TextLabel")
	label.Name = "SectionTitle"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 28)
	label.Text = text
	label.Parent = content
	applyTextStyle(label, 15)
	return label
end

local function makeParagraph(text)
	local label = Instance.new("TextLabel")
	label.Name = "Paragraph"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 58)
	label.Text = text
	label.TextWrapped = true
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Parent = content
	applyTextStyle(label, 12)
	return label
end

local function makeGrid(parent, columns)
	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(1, 0, 0, 1)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.Parent = parent or content

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(1 / (columns or 2), -6, 0, 40)
	layout.CellPadding = UDim2.fromOffset(12, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	return grid
end

local function makeTextBox(name, placeholder, defaultText)
	local box = Instance.new("TextBox")
	box.Name = name
	box.BackgroundColor3 = UT_BLACK
	box.BorderSizePixel = 0
	box.ClearTextOnFocus = false
	box.PlaceholderText = placeholder or ""
	box.PlaceholderColor3 = UT_GRAY
	box.Text = defaultText or ""
	box.Size = UDim2.new(1, 0, 0, 36)
	box.Parent = content
	applyTextStyle(box, 12)
	box.TextXAlignment = Enum.TextXAlignment.Left
	addStroke(box, UT_GRAY, 2)

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = box

	dataManagerState.TextBoxes[name] = box
	return box
end

local function getBoxText(name)
	local box = dataManagerState.TextBoxes[name]
	return box and box.Text or ""
end

local function countKeys(map)
	local total = 0
	if typeof(map) ~= "table" then
		return total
	end

	for _, value in pairs(map) do
		if value == true or typeof(value) == "string" then
			total += 1
		end
	end

	return total
end

local function sortedTruthyKeys(map)
	local keys = {}
	if typeof(map) ~= "table" then
		return keys
	end

	for key, value in pairs(map) do
		if value == true then
			table.insert(keys, tostring(key))
		end
	end
	table.sort(keys)
	return keys
end

local function shortList(list, limit)
	limit = limit or 16
	if typeof(list) ~= "table" or #list == 0 then
		return "None"
	end

	local shown = {}
	for index = 1, math.min(#list, limit) do
		table.insert(shown, tostring(list[index]))
	end
	if #list > limit then
		table.insert(shown, "+" .. tostring(#list - limit) .. " more")
	end
	return table.concat(shown, ", ")
end

local function loadDataManagerSnapshot(targetUserId)
	local payload = nil
	if targetUserId then
		payload = {
			TargetUserId = targetUserId,
		}
	end

	local result = invoke("GetDataManagerSnapshot", payload)
	if result.Data then
		dataManagerState.Data = result.Data
		if result.Data.TargetData and result.Data.TargetData.Target then
			dataManagerState.SelectedUserId = result.Data.TargetData.Target.UserId
		elseif not dataManagerState.SelectedUserId and result.Data.OnlinePlayers and result.Data.OnlinePlayers[1] then
			dataManagerState.SelectedUserId = result.Data.OnlinePlayers[1].UserId
		end
	end

	setStatus(result.Message, result.Success)
	return result
end

local function applyDataAction(actionName, extraPayload)
	local payload = extraPayload or {}
	payload.Action = actionName
	payload.TargetUserId = dataManagerState.SelectedUserId

	local result = invoke("ApplyDataManagerAction", payload)
	if result.Data then
		dataManagerState.Data = result.Data
	end

	setStatus(result.Message, result.Success)
	if renderData then
		renderData()
	end
end

local function makeActionButton(grid, actionName, label, payloadBuilder, color)
	local button = makeButton(grid, actionName, label, {
		Color = color or Color3.fromRGB(36, 36, 42),
		TextSize = 11,
	})

	button.MouseButton1Click:Connect(function()
		applyDataAction(actionName, payloadBuilder and payloadBuilder() or {})
	end)

	return button
end

local function renderCombat()
	clearContent()
	makeSectionTitle("Combat Debug")

	local actionGrid = makeGrid()
	for _, action in ipairs(ACTIONS) do
		local legacy = getLegacyButtonStyle(action.Style)
		local button = makeButton(actionGrid, action.Key, action.Label, {
			Color = legacy.Color or action.Color,
			Image = legacy.Image,
			Size = UDim2.fromOffset(190, 40),
		})

		button.MouseButton1Click:Connect(function()
			local result = invoke("CombatDebugAction", {
				Action = action.Key,
			})

			setStatus(result.Message, result.Success)
		end)
	end

	makeSectionTitle("Dummy Spawning")
	local dummyGrid = makeGrid()

	for _, dummyType in ipairs(DUMMY_TYPES) do
		local button = makeButton(dummyGrid, dummyType.Key, dummyType.Label, {
			Color = Color3.fromRGB(36, 36, 42),
			TextSize = 11,
			Size = UDim2.fromOffset(190, 40),
		})

		button.MouseButton1Click:Connect(function()
			local result = invoke("SpawnDummy", {
				DummyType = dummyType.Key,
			})

			setStatus(result.Message, result.Success)
		end)
	end

	local clearButton = makeButton(content, "ClearDebugDummies", "Clear Debug Dummies", {
		Color = Color3.fromRGB(90, 25, 30),
		Size = UDim2.new(1, 0, 0, 40),
	})

	clearButton.MouseButton1Click:Connect(function()
		local result = invoke("ClearDebugDummies")
		setStatus(result.Message, result.Success)
	end)
end

renderData = function()
	clearContent()
	dataManagerState.TextBoxes = {}
	makeSectionTitle("Data Manager")

	if status.CanUseDataManager ~= true then
		makeParagraph("Owner-only tools are locked for this account.")
		return
	end

	if not dataManagerState.Data then
		loadDataManagerSnapshot(dataManagerState.SelectedUserId)
	end

	local data = dataManagerState.Data or {}
	local onlinePlayers = data.OnlinePlayers or {}
	local definitions = data.Definitions or {}
	local targetData = data.TargetData

	local refreshButton = makeButton(content, "RefreshDataManager", "Refresh Online Players", {
		Color = Color3.fromRGB(36, 36, 42),
		Size = UDim2.new(1, 0, 0, 36),
	})
	refreshButton.MouseButton1Click:Connect(function()
		loadDataManagerSnapshot(dataManagerState.SelectedUserId)
		renderData()
	end)

	makeSectionTitle("Online Target")
	if #onlinePlayers == 0 then
		makeParagraph("No online players found.")
		return
	end

	local playerGrid = makeGrid(content, 2)
	for _, targetInfo in ipairs(onlinePlayers) do
		local selected = targetInfo.UserId == dataManagerState.SelectedUserId
		local button = makeButton(playerGrid, "Target_" .. tostring(targetInfo.UserId), targetInfo.Label or targetInfo.Name, {
			Color = selected and UT_WHITE or UT_BLACK,
			TextSize = 10,
		})
		button.TextColor3 = selected and UT_BLACK or UT_WHITE
		button.MouseButton1Click:Connect(function()
			dataManagerState.SelectedUserId = targetInfo.UserId
			loadDataManagerSnapshot(targetInfo.UserId)
			renderData()
		end)
	end

	if dataManagerState.SelectedUserId and not targetData then
		loadDataManagerSnapshot(dataManagerState.SelectedUserId)
		data = dataManagerState.Data or {}
		definitions = data.Definitions or definitions
		targetData = data.TargetData
	end

	if not targetData or not targetData.Raw then
		makeParagraph("Pick an online target with a loaded profile.")
		return
	end

	local raw = targetData.Raw
	local profile = targetData.Profile or {}
	local equippedEmotes = raw.EquippedEmotes or {}
	local emoteLines = {}
	for slot = 1, 8 do
		if equippedEmotes[slot] then
			table.insert(emoteLines, tostring(slot) .. ":" .. tostring(equippedEmotes[slot]))
		end
	end

	makeSectionTitle("Snapshot")
	makeParagraph(string.format(
		"%s\nDust: %s | Kills: %s\nCharacter: %s | Title: %s\nOwned: %d chars, %d titles, %d emotes | Lore read: %d\nEmotes: %s",
		targetData.Target and targetData.Target.Label or "Target",
		tostring(raw.Dust or profile.Dust or 0),
		tostring(raw.Kills or profile.Kills or 0),
		tostring(targetData.EquippedCharacter or profile.Equipped or "Unknown"),
		tostring(raw.EquippedTitle or "None"),
		countKeys(raw.OwnedCharacters),
		countKeys(raw.OwnedTitles),
		countKeys(raw.OwnedEmotes),
		countKeys(raw.Lore),
		#emoteLines > 0 and table.concat(emoteLines, ", ") or "None"
	))

	makeSectionTitle("Player Values")
	makeTextBox("Amount", "Amount", "0")
	local valueGrid = makeGrid(content, 2)
	makeActionButton(valueGrid, "SetDust", "Set Dust", function()
		return { Amount = getBoxText("Amount") }
	end, UT_BLUE)
	makeActionButton(valueGrid, "AddDust", "Add Dust", function()
		return { Amount = getBoxText("Amount") }
	end, UT_GREEN)
	makeActionButton(valueGrid, "SetKills", "Set Kills", function()
		return { Amount = getBoxText("Amount") }
	end, UT_BLUE)
	makeActionButton(valueGrid, "AddKills", "Add Kills", function()
		return { Amount = getBoxText("Amount") }
	end, UT_GREEN)

	makeSectionTitle("Characters")
	makeParagraph("Valid: " .. shortList(definitions.Characters, 18))
	makeTextBox("CharacterName", "Character ID", shortList(sortedTruthyKeys(raw.OwnedCharacters), 1) ~= "None" and shortList(sortedTruthyKeys(raw.OwnedCharacters), 1) or "")
	local characterGrid = makeGrid(content, 2)
	makeActionButton(characterGrid, "UnlockCharacter", "Unlock", function()
		return { CharacterName = getBoxText("CharacterName") }
	end)
	makeActionButton(characterGrid, "RelockCharacter", "Relock", function()
		return { CharacterName = getBoxText("CharacterName") }
	end, UT_RED)
	makeActionButton(characterGrid, "EquipCharacter", "Equip", function()
		return { CharacterName = getBoxText("CharacterName") }
	end, UT_BLUE)
	makeActionButton(characterGrid, "UnlockAllCharacters", "Unlock All", nil, UT_GREEN)
	makeActionButton(characterGrid, "RelockAllNonDefaultCharacters", "Relock Paid", nil, UT_RED)

	makeSectionTitle("Skins")
	makeTextBox("SkinCharacterName", "Character ID", tostring(targetData.EquippedCharacter or ""))
	makeTextBox("SkinName", "Skin ID", "Default")
	local skinsForCharacter = definitions.Skins and definitions.Skins[getBoxText("SkinCharacterName")]
	makeParagraph("Skins for typed character show after refresh. Known current: " .. shortList(skinsForCharacter, 18))
	local skinGrid = makeGrid(content, 2)
	makeActionButton(skinGrid, "UnlockSkin", "Unlock Skin", function()
		return { CharacterName = getBoxText("SkinCharacterName"), SkinName = getBoxText("SkinName") }
	end)
	makeActionButton(skinGrid, "RelockSkin", "Relock Skin", function()
		return { CharacterName = getBoxText("SkinCharacterName"), SkinName = getBoxText("SkinName") }
	end, UT_RED)
	makeActionButton(skinGrid, "EquipSkin", "Equip Skin", function()
		return { CharacterName = getBoxText("SkinCharacterName"), SkinName = getBoxText("SkinName") }
	end, UT_BLUE)
	makeActionButton(skinGrid, "UnlockAllSkinsForCharacter", "Unlock Char Skins", function()
		return { CharacterName = getBoxText("SkinCharacterName") }
	end, UT_GREEN)
	makeActionButton(skinGrid, "UnlockAllSkinsGlobal", "Unlock All Skins", nil, UT_GREEN)
	makeActionButton(skinGrid, "RelockAllSkins", "Relock All Skins", nil, UT_RED)

	makeSectionTitle("Titles")
	makeParagraph("Valid: " .. shortList(definitions.Titles, 18))
	makeTextBox("TitleId", "Title ID", tostring(raw.EquippedTitle or "None"))
	local titleGrid = makeGrid(content, 2)
	makeActionButton(titleGrid, "UnlockTitle", "Unlock Title", function()
		return { TitleId = getBoxText("TitleId") }
	end)
	makeActionButton(titleGrid, "RelockTitle", "Relock Title", function()
		return { TitleId = getBoxText("TitleId") }
	end, UT_RED)
	makeActionButton(titleGrid, "EquipTitle", "Equip Title", function()
		return { TitleId = getBoxText("TitleId") }
	end, UT_BLUE)
	makeActionButton(titleGrid, "UnlockAllTitles", "Unlock All Titles", nil, UT_GREEN)

	makeSectionTitle("Emotes")
	makeParagraph("Valid: " .. shortList(definitions.Emotes, 18))
	makeTextBox("EmoteId", "Emote ID", "")
	makeTextBox("EmoteSlot", "Slot 1-8", "1")
	local emoteGrid = makeGrid(content, 2)
	makeActionButton(emoteGrid, "UnlockEmote", "Unlock Emote", function()
		return { EmoteId = getBoxText("EmoteId") }
	end)
	makeActionButton(emoteGrid, "RelockEmote", "Relock Emote", function()
		return { EmoteId = getBoxText("EmoteId") }
	end, UT_RED)
	makeActionButton(emoteGrid, "EquipEmoteSlot", "Equip Slot", function()
		return { EmoteId = getBoxText("EmoteId"), Slot = getBoxText("EmoteSlot") }
	end, UT_BLUE)
	makeActionButton(emoteGrid, "UnlockAllEmotes", "Unlock All Emotes", nil, UT_GREEN)

	makeSectionTitle("Lore")
	makeParagraph("Valid: " .. shortList(definitions.Lore, 18))
	makeTextBox("LoreId", "Lore Fragment ID", "")
	local loreGrid = makeGrid(content, 2)
	makeActionButton(loreGrid, "UnlockLore", "Unlock Lore", function()
		return { LoreId = getBoxText("LoreId") }
	end)
	makeActionButton(loreGrid, "LockLore", "Lock Lore", function()
		return { LoreId = getBoxText("LoreId") }
	end, UT_RED)
	makeActionButton(loreGrid, "UnlockAllLore", "Unlock All Lore", nil, UT_GREEN)
	makeActionButton(loreGrid, "ResetLore", "Reset Lore", nil, UT_RED)
end

local function renderAbuse()
	clearContent()
	makeSectionTitle("OWNER ABUSE")

	if status.CanUseAbuseTools ~= true then
		makeParagraph("Owner-only abuse tools are locked for this account.")
		return
	end

	makeParagraph("This will nuke the server and kick everyone.")

	local nukeButton = makeButton(content, "NukeServer", "NUKE SERVER", {
		Color = Color3.fromRGB(115, 0, 0),
		Size = UDim2.new(1, 0, 0, 64),
		TextSize = 18,
		StrokeThickness = 4,
	})

	nukeButton.MouseButton1Click:Connect(function()
		nukeButton.AutoButtonColor = false
		nukeButton.Text = "NUKE LAUNCHED"
		nukeButton.BackgroundColor3 = Color3.fromRGB(55, 0, 0)

		local result = invoke("AbuseAction", {
			Action = "NukeServer",
		})

		setStatus(result.Message, result.Success)
		if result.Success ~= true then
			nukeButton.AutoButtonColor = true
			nukeButton.Text = "NUKE SERVER"
			nukeButton.BackgroundColor3 = Color3.fromRGB(115, 0, 0)
		end
	end)
end

local function showTab(tabName)
	if tabName == "Data" and status.CanUseDataManager ~= true then
		setStatus("Data Manager is owner-only.", false)
		return
	end

	if tabName == "Abuse" and status.CanUseAbuseTools ~= true then
		setStatus("ABUSE is owner-only.", false)
	end

	selectedTab = tabName

	for name, button in pairs(tabButtons) do
		local disabled = name == "Data" and status.CanUseDataManager ~= true
			or name == "Abuse" and status.CanUseAbuseTools ~= true
		button.BackgroundColor3 = name == selectedTab and UT_WHITE or UT_BLACK
		button.TextColor3 = name == selectedTab and UT_BLACK or (disabled and UT_GRAY or UT_WHITE)
	end

	if selectedTab == "Combat" then
		renderCombat()
	elseif selectedTab == "Data" then
		renderData()
	elseif selectedTab == "Abuse" then
		renderAbuse()
	end
end

local function makeTab(name, label, disabled)
	local button = makeButton(tabs, name .. "Tab", label, {
		Disabled = disabled,
		TextSize = disabled and 11 or 13,
	})

	tabButtons[name] = button
	button.MouseButton1Click:Connect(function()
		showTab(name)
	end)

	return button
end

makeTab("Combat", "Combat Debug", false)
makeTab("Data", status.CanUseDataManager and "Data Manager" or "Data Manager\nOwner only", status.CanUseDataManager ~= true)
makeTab("Abuse", status.CanUseAbuseTools and "ABUSE" or "ABUSE\nOwner only", false)

local dragging = false
local dragStart = nil
local panelStart = nil

header.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	dragging = true
	dragStart = input.Position
	panelStart = panel.Position

	input.Changed:Connect(function()
		if input.UserInputState == Enum.UserInputState.End then
			dragging = false
		end
	end)
end)

UserInputService.InputChanged:Connect(function(input)
	if not dragging then
		return
	end

	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	local delta = input.Position - dragStart
	panel.Position = UDim2.new(
		panelStart.X.Scale,
		panelStart.X.Offset + delta.X,
		panelStart.Y.Scale,
		panelStart.Y.Offset + delta.Y
	)
end)

showTab("Combat")

local devIcon = Icon.new()
	:setImage("rbxassetid://5954353763")
	:setLabel("DEV")
	:setOrder(500)

local function setMenuOpen(isOpen)
	gui.Enabled = isOpen == true
end

closeButton.MouseButton1Click:Connect(function()
	setMenuOpen(false)
	pcall(function()
		devIcon:deselect()
	end)
end)

devIcon:bindEvent("selected", function()
	setMenuOpen(not gui.Enabled)

	pcall(function()
		devIcon:deselect()
	end)
end)
