local MoveHudController = {}
MoveHudController.__index = MoveHudController

local DEFAULT_MOVE_DISPLAY = {
	Move1 = {
		Key = "1",
		Name = "Move 1",
		Cooldown = 1,
	},

	Move2 = {
		Key = "2",
		Name = "Move 2",
		Cooldown = 1,
	},

	Move3 = {
		Key = "3",
		Name = "Move 3",
		Cooldown = 1,
	},

	Move4 = {
		Key = "4",
		Name = "Move 4",
		Cooldown = 1,
	},

	Ultimate = {
		Key = "G",
		Name = "Ultimate",
		Cooldown = 35,
	},
}

local ULT_BAR_TWEEN_TIME = 0.18
local SOUL_BURST_BAR_TWEEN_TIME = 0.18

local SILKSCREEN_FONT = Font.new("rbxassetid://12187371840")
local UT_BLACK = Color3.fromRGB(0, 0, 0)
local UT_WHITE = Color3.fromRGB(255, 255, 255)
local UT_ORANGE = Color3.fromRGB(255, 150, 40)
local UT_YELLOW = Color3.fromRGB(255, 190, 40)
local DEFAULT_HEART_COLOR = Color3.fromRGB(220, 20, 45)
local DEFAULT_ULT_COLOR = Color3.fromRGB(180, 35, 35)

local HEART_IMAGE = "rbxassetid://125096613002078"
local FLOWEY_IMAGE = "rbxassetid://15703651166"
local HEART_GLOW_IMAGE = "rbxassetid://867619398"

local SOUL_HEART_SIZE = 60
local SOUL_HEART_OUTLINE_SIZE = 68
local SOUL_GLOW_NORMAL_SIZE = 78
local SOUL_GLOW_READY_SIZE = 112

local function applySilkscreen(textObject)
	local success = pcall(function()
		textObject.FontFace = SILKSCREEN_FONT
	end)

	if not success then
		textObject.Font = Enum.Font.Arcade
	end
end

local function addWhiteStroke(instance, thickness)
	local stroke = instance:FindFirstChildOfClass("UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Parent = instance
	end

	stroke.Color = UT_WHITE
	stroke.Thickness = thickness or 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.LineJoinMode = Enum.LineJoinMode.Miter

	return stroke
end

local function isNearWhite(color)
	return color.R >= 0.96 and color.G >= 0.96 and color.B >= 0.96
end

local function lightenColor(color, amount)
	local alpha = math.clamp(amount or 0.2, 0, 1)
	return Color3.new(
		color.R + (1 - color.R) * alpha,
		color.G + (1 - color.G) * alpha,
		color.B + (1 - color.B) * alpha
	)
end

function MoveHudController.new(config)
	local self = setmetatable({}, MoveHudController)

	self.Player = config.Player
	self.ReplicatedStorage = config.ReplicatedStorage
	self.CharactersFolder = config.CharactersFolder
	self.TweenService = config.TweenService
	self.GetCurrentCharacterName = config.GetCurrentCharacterName
	self.OnMoveButtonPressed = config.OnMoveButtonPressed

	self.PlayerGui = self.Player:WaitForChild("PlayerGui")
	self.MoveDisplay = table.clone(DEFAULT_MOVE_DISPLAY)

	self.MoveButtons = {}
	self.MoveButtonStrokes = {}
	self.MoveNameLabels = {}
	self.CooldownOverlays = {}
	self.CooldownTexts = {}

	self.CurrentHeartColor = DEFAULT_HEART_COLOR
	self.CurrentUltColor = DEFAULT_ULT_COLOR
	self.CurrentUltReadyColor = lightenColor(DEFAULT_ULT_COLOR, 0.28)
	self.CurrentHeartIsWhite = false

	return self
end

function MoveHudController:GetCharacterVFXColor(characterName, valueName)
	local characterFolder = self.CharactersFolder:FindFirstChild(characterName)
	local vfxFolder = characterFolder and characterFolder:FindFirstChild("VFX")
	local colorValue = vfxFolder and vfxFolder:FindFirstChild(valueName)

	if colorValue and colorValue:IsA("Color3Value") then
		return colorValue.Value
	end

	return nil
end

function MoveHudController:ApplyCharacterUIColor()
	local characterName = self.GetCurrentCharacterName()
	local heartColor = self:GetCharacterVFXColor(characterName, "HeartColor") or DEFAULT_HEART_COLOR
	local ultColor = self:GetCharacterVFXColor(characterName, "UltColor") or DEFAULT_ULT_COLOR

	self.CurrentHeartColor = heartColor
	self.CurrentUltColor = ultColor
	self.CurrentUltReadyColor = lightenColor(ultColor, 0.28)
	self.CurrentHeartIsWhite = isNearWhite(heartColor)

	if self.UltimateHeartImage then
		self.UltimateHeartImage.ImageColor3 = self.CurrentHeartColor
		self.UltimateHeartImage.Image = HEART_IMAGE
		self.UltimateHeartImage.Rotation = self.CurrentHeartIsWhite and 180 or 0
	end

	if self.UltimateHeartGlow then
		self.UltimateHeartGlow.ImageColor3 = self.CurrentHeartColor
		self.UltimateHeartGlow.ImageTransparency = 0.25
	end

	if self.SoulHeartFillImage then
		self.SoulHeartFillImage.ImageColor3 = self.CurrentHeartColor
		self.SoulHeartFillImage.Image = HEART_IMAGE
		self.SoulHeartFillImage.Rotation = self.CurrentHeartIsWhite and 180 or 0
	end

	if self.SoulHeartGlow then
		self.SoulHeartGlow.ImageColor3 = self.CurrentHeartColor
	end

	if self.SoulHeartBackImage then
		self.SoulHeartBackImage.ImageColor3 = UT_BLACK
		self.SoulHeartBackImage.Image = HEART_IMAGE
		self.SoulHeartBackImage.Rotation = self.CurrentHeartIsWhite and 180 or 0
	end

	if self.SoulHeartOutlineImage then
		self.SoulHeartOutlineImage.Image = HEART_IMAGE
		self.SoulHeartOutlineImage.Rotation = self.CurrentHeartIsWhite and 180 or 0
	end
end

function MoveHudController:RefreshMoveDisplay(moveDisplay)
	self.MoveDisplay = moveDisplay or self.MoveDisplay or table.clone(DEFAULT_MOVE_DISPLAY)
	self:ApplyCharacterUIColor()

	for slot, label in pairs(self.MoveNameLabels) do
		local data = self.MoveDisplay[slot]
		if data then
			label.Text = data.Name or slot
		end
	end
end

function MoveHudController:UpdateUltimate(state)
	local current = typeof(state.Current) == "number" and state.Current or 0
	local max = typeof(state.Max) == "number" and state.Max > 0 and state.Max or 100
	local alpha = typeof(state.Alpha) == "number" and math.clamp(state.Alpha, 0, 1) or math.clamp(current / max, 0, 1)
	local full = state.Full == true or alpha >= 1

	if self.UltimateFill then
		if self.UltimateFillTween then
			self.UltimateFillTween:Cancel()
			self.UltimateFillTween = nil
		end

		self.UltimateFillTween = self.TweenService:Create(
			self.UltimateFill,
			TweenInfo.new(ULT_BAR_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Size = UDim2.fromScale(alpha, 1),
				BackgroundColor3 = full and self.CurrentUltReadyColor or self.CurrentUltColor,
			}
		)

		self.UltimateFillTween:Play()
	end

	if self.UltimateStroke then
		self.UltimateStroke.Color = UT_WHITE
		self.UltimateStroke.Thickness = 4
	end

	if self.UltimateText then
		local ultName = state.UltName or "Ultimate"
		self.UltimateText.Text = full
			and (string.upper(ultName) .. " READY")
			or (string.upper(ultName) .. " " .. tostring(math.floor(alpha * 100)) .. "%")
	end
end

function MoveHudController:UpdateSoulBurst(state)
	local current = typeof(state.Current) == "number" and state.Current or 0
	local max = typeof(state.Max) == "number" and state.Max > 0 and state.Max or 100
	local alpha = typeof(state.Alpha) == "number" and math.clamp(state.Alpha, 0, 1) or math.clamp(current / max, 0, 1)

	if self.SoulHeartFillImage then
		if self.SoulBurstFillTween then
			self.SoulBurstFillTween:Cancel()
			self.SoulBurstFillTween = nil
		end

		local fillSize = SOUL_HEART_SIZE * alpha

		self.SoulBurstFillTween = self.TweenService:Create(
			self.SoulHeartFillImage,
			TweenInfo.new(SOUL_BURST_BAR_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Size = UDim2.fromOffset(fillSize, fillSize),
			}
		)

		self.SoulBurstFillTween:Play()
	end

	if self.SoulBurstText then
		self.SoulBurstText.Text = alpha >= 1 and "BURST" or "SOUL"
	end

	if self.SoulHeartGlow then
		local glowSize = alpha >= 1 and SOUL_GLOW_READY_SIZE or SOUL_GLOW_NORMAL_SIZE
		local glowTransparency = alpha >= 1 and 0.18 or 0.28

		self.SoulHeartGlow.Size = UDim2.fromOffset(glowSize, glowSize)
		self.SoulHeartGlow.ImageTransparency = glowTransparency
		self.SoulHeartGlow.ImageColor3 = self.CurrentHeartColor
	end
end

function MoveHudController:SetActiveMove(moveSlot, active)
	local stroke = self.MoveButtonStrokes[moveSlot]
	if not stroke then
		return
	end

	stroke.Color = active and UT_ORANGE or UT_WHITE
	stroke.Thickness = active and 4 or 3
end

function MoveHudController:StartCooldown(moveSlot, cooldown, lockTime)
	cooldown = math.max(cooldown or 0, 0)

	local overlay = self.CooldownOverlays[moveSlot]
	local cooldownText = self.CooldownTexts[moveSlot]

	if not overlay then
		return
	end

	task.delay(lockTime or 0, function()
		if not self.ScreenGui or not self.ScreenGui.Parent then
			return
		end

		overlay.Visible = true
		overlay.Size = UDim2.fromScale(1, 1)

		if cooldownText then
			cooldownText.Visible = true
		end

		local startTime = os.clock()

		task.spawn(function()
			while os.clock() - startTime < cooldown do
				local elapsed = os.clock() - startTime
				local remaining = math.max(cooldown - elapsed, 0)
				local alpha = math.clamp(elapsed / cooldown, 0, 1)

				overlay.Size = UDim2.fromScale(1, 1 - alpha)

				if cooldownText then
					cooldownText.Text = string.format("%.1f", remaining)
				end

				task.wait()
			end

			overlay.Visible = false
			overlay.Size = UDim2.fromScale(1, 1)

			if cooldownText then
				cooldownText.Visible = false
			end
		end)
	end)
end

function MoveHudController:Destroy()
	if self.ScreenGui then
		self.ScreenGui:Destroy()
		self.ScreenGui = nil
	end

	local oldGui = self.PlayerGui:FindFirstChild("MoveHUD")
	if oldGui then
		oldGui:Destroy()
	end

	table.clear(self.MoveButtons)
	table.clear(self.MoveButtonStrokes)
	table.clear(self.MoveNameLabels)
	table.clear(self.CooldownOverlays)
	table.clear(self.CooldownTexts)
end

function MoveHudController:Create()
	self:Destroy()
	self:ApplyCharacterUIColor()

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MoveHUD"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = self.PlayerGui
	self.ScreenGui = screenGui

	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.fromScale(0.5, 0.965)
	holder.Size = UDim2.fromOffset(360, 118)
	holder.BackgroundTransparency = 1
	holder.Parent = screenGui

	local ultBack = Instance.new("Frame")
	ultBack.Name = "UltimateBack"
	ultBack.Position = UDim2.fromOffset(0, 0)
	ultBack.Size = UDim2.fromOffset(360, 22)
	ultBack.BackgroundColor3 = UT_BLACK
	ultBack.BorderSizePixel = 0
	ultBack.Parent = holder

	self.UltimateStroke = addWhiteStroke(ultBack, 4)

	self.UltimateFill = Instance.new("Frame")
	self.UltimateFill.Name = "UltimateFill"
	self.UltimateFill.Size = UDim2.fromScale(0, 1)
	self.UltimateFill.BackgroundColor3 = self.CurrentUltColor
	self.UltimateFill.BorderSizePixel = 0
	self.UltimateFill.Parent = ultBack

	local leftFlowey = Instance.new("ImageLabel")
	leftFlowey.Name = "LeftFlowey"
	leftFlowey.BackgroundTransparency = 1
	leftFlowey.AnchorPoint = Vector2.new(1, 0.5)
	leftFlowey.Position = UDim2.new(0, -8, 0.5, 0)
	leftFlowey.Size = UDim2.fromOffset(42, 42)
	leftFlowey.Image = FLOWEY_IMAGE
	leftFlowey.Parent = ultBack

	local rightFlowey = Instance.new("ImageLabel")
	rightFlowey.Name = "RightFlowey"
	rightFlowey.BackgroundTransparency = 1
	rightFlowey.AnchorPoint = Vector2.new(0, 0.5)
	rightFlowey.Position = UDim2.new(1, 8, 0.5, 0)
	rightFlowey.Size = UDim2.fromOffset(42, 42)
	rightFlowey.Image = FLOWEY_IMAGE
	rightFlowey.Parent = ultBack

	self.UltimateHeartGlow = Instance.new("ImageLabel")
	self.UltimateHeartGlow.Name = "HeartGlow"
	self.UltimateHeartGlow.BackgroundTransparency = 1
	self.UltimateHeartGlow.AnchorPoint = Vector2.new(0.5, 0.5)
	self.UltimateHeartGlow.Position = UDim2.new(0.5, 0, 0, -10)
	self.UltimateHeartGlow.Size = UDim2.fromOffset(88, 88)
	self.UltimateHeartGlow.Image = HEART_GLOW_IMAGE
	self.UltimateHeartGlow.ImageColor3 = self.CurrentHeartColor
	self.UltimateHeartGlow.ImageTransparency = 0.25
	self.UltimateHeartGlow.ZIndex = 1
	self.UltimateHeartGlow.Parent = ultBack

	self.UltimateHeartImage = Instance.new("ImageLabel")
	self.UltimateHeartImage.Name = "Heart"
	self.UltimateHeartImage.BackgroundTransparency = 1
	self.UltimateHeartImage.AnchorPoint = Vector2.new(0.5, 0.5)
	self.UltimateHeartImage.Position = UDim2.new(0.5, 0, 0, -10)
	self.UltimateHeartImage.Size = UDim2.fromOffset(36, 36)
	self.UltimateHeartImage.Image = HEART_IMAGE
	self.UltimateHeartImage.ImageColor3 = self.CurrentHeartColor
	self.UltimateHeartImage.Rotation = self.CurrentHeartIsWhite and 180 or 0
	self.UltimateHeartImage.ZIndex = 2
	self.UltimateHeartImage.Parent = ultBack

	self.UltimateText = Instance.new("TextLabel")
	self.UltimateText.Name = "UltimateText"
	self.UltimateText.BackgroundTransparency = 1
	self.UltimateText.Size = UDim2.fromScale(1, 1)
	self.UltimateText.TextSize = 13
	self.UltimateText.TextColor3 = UT_WHITE
	self.UltimateText.Text = "ULTIMATE 0%"
	self.UltimateText.ZIndex = 3
	self.UltimateText.Parent = ultBack
	applySilkscreen(self.UltimateText)

	local buttonsFrame = Instance.new("Frame")
	buttonsFrame.Name = "Buttons"
	buttonsFrame.Position = UDim2.fromOffset(0, 34)
	buttonsFrame.Size = UDim2.fromOffset(360, 84)
	buttonsFrame.BackgroundTransparency = 1
	buttonsFrame.Parent = holder

	local soulBack = Instance.new("Frame")
	soulBack.Name = "SoulBurstBack"
	soulBack.Position = UDim2.fromOffset(370, 42)
	soulBack.Size = UDim2.fromOffset(70, 70)
	soulBack.BackgroundTransparency = 1
	soulBack.BorderSizePixel = 0
	soulBack.ClipsDescendants = false
	soulBack.Parent = holder

	self.SoulHeartGlow = Instance.new("ImageLabel")
	self.SoulHeartGlow.Name = "HeartGlow"
	self.SoulHeartGlow.BackgroundTransparency = 1
	self.SoulHeartGlow.AnchorPoint = Vector2.new(0.5, 0.5)
	self.SoulHeartGlow.Position = UDim2.fromScale(0.5, 0.5)
	self.SoulHeartGlow.Size = UDim2.fromOffset(SOUL_GLOW_NORMAL_SIZE, SOUL_GLOW_NORMAL_SIZE)
	self.SoulHeartGlow.Image = HEART_GLOW_IMAGE
	self.SoulHeartGlow.ImageColor3 = self.CurrentHeartColor
	self.SoulHeartGlow.ImageTransparency = 0.28
	self.SoulHeartGlow.ZIndex = 1
	self.SoulHeartGlow.Parent = soulBack

	self.SoulHeartOutlineImage = Instance.new("ImageLabel")
	self.SoulHeartOutlineImage.Name = "HeartContext"
	self.SoulHeartOutlineImage.BackgroundTransparency = 1
	self.SoulHeartOutlineImage.AnchorPoint = Vector2.new(0.5, 0.5)
	self.SoulHeartOutlineImage.Position = UDim2.fromScale(0.5, 0.5)
	self.SoulHeartOutlineImage.Size = UDim2.fromOffset(SOUL_HEART_OUTLINE_SIZE, SOUL_HEART_OUTLINE_SIZE)
	self.SoulHeartOutlineImage.Image = HEART_IMAGE
	self.SoulHeartOutlineImage.ImageColor3 = UT_BLACK
	self.SoulHeartOutlineImage.Rotation = self.CurrentHeartIsWhite and 180 or 0
	self.SoulHeartOutlineImage.ZIndex = 2
	self.SoulHeartOutlineImage.Parent = soulBack

	self.SoulHeartBackImage = Instance.new("ImageLabel")
	self.SoulHeartBackImage.Name = "HeartBack"
	self.SoulHeartBackImage.BackgroundTransparency = 1
	self.SoulHeartBackImage.AnchorPoint = Vector2.new(0.5, 0.5)
	self.SoulHeartBackImage.Position = UDim2.fromScale(0.5, 0.5)
	self.SoulHeartBackImage.Size = UDim2.fromOffset(SOUL_HEART_SIZE, SOUL_HEART_SIZE)
	self.SoulHeartBackImage.Image = HEART_IMAGE
	self.SoulHeartBackImage.ImageColor3 = UT_BLACK
	self.SoulHeartBackImage.Rotation = self.CurrentHeartIsWhite and 180 or 0
	self.SoulHeartBackImage.ZIndex = 3
	self.SoulHeartBackImage.Parent = soulBack

	self.SoulHeartFillImage = Instance.new("ImageLabel")
	self.SoulHeartFillImage.Name = "SoulFillHeart"
	self.SoulHeartFillImage.BackgroundTransparency = 1
	self.SoulHeartFillImage.AnchorPoint = Vector2.new(0.5, 0.5)
	self.SoulHeartFillImage.Position = UDim2.fromScale(0.5, 0.5)
	self.SoulHeartFillImage.Size = UDim2.fromOffset(0, 0)
	self.SoulHeartFillImage.Image = HEART_IMAGE
	self.SoulHeartFillImage.ImageColor3 = self.CurrentHeartColor
	self.SoulHeartFillImage.Rotation = self.CurrentHeartIsWhite and 180 or 0
	self.SoulHeartFillImage.ZIndex = 4
	self.SoulHeartFillImage.Parent = soulBack

	self.SoulBurstText = Instance.new("TextLabel")
	self.SoulBurstText.Name = "SoulBurstText"
	self.SoulBurstText.BackgroundTransparency = 1
	self.SoulBurstText.Size = UDim2.fromScale(1, 1)
	self.SoulBurstText.TextSize = 11
	self.SoulBurstText.TextColor3 = UT_WHITE
	self.SoulBurstText.TextStrokeTransparency = 0.2
	self.SoulBurstText.TextWrapped = true
	self.SoulBurstText.Text = "SOUL"
	self.SoulBurstText.ZIndex = 6
	self.SoulBurstText.Parent = soulBack
	applySilkscreen(self.SoulBurstText)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = buttonsFrame

	local slots = { "Move1", "Move2", "Move3", "Move4" }

	for index, moveSlot in ipairs(slots) do
		local data = self.MoveDisplay[moveSlot] or DEFAULT_MOVE_DISPLAY[moveSlot]

		local button = Instance.new("TextButton")
		button.Name = moveSlot
		button.LayoutOrder = index
		button.Size = UDim2.fromOffset(78, 78)
		button.BackgroundColor3 = UT_BLACK
		button.BorderSizePixel = 0
		button.AutoButtonColor = true
		button.Text = ""
		button.Parent = buttonsFrame

		local stroke = addWhiteStroke(button, 3)

		local keyLabel = Instance.new("TextLabel")
		keyLabel.Name = "Key"
		keyLabel.BackgroundTransparency = 1
		keyLabel.Position = UDim2.fromOffset(6, 4)
		keyLabel.Size = UDim2.fromOffset(24, 22)
		keyLabel.TextSize = 18
		keyLabel.TextColor3 = UT_WHITE
		keyLabel.Text = data.Key
		keyLabel.Parent = button
		applySilkscreen(keyLabel)

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "MoveName"
		nameLabel.BackgroundTransparency = 1
		nameLabel.AnchorPoint = Vector2.new(0.5, 1)
		nameLabel.Position = UDim2.fromScale(0.5, 0.92)
		nameLabel.Size = UDim2.fromOffset(70, 32)
		nameLabel.TextSize = 12
		nameLabel.TextWrapped = true
		nameLabel.TextColor3 = UT_WHITE
		nameLabel.Text = data.Name
		nameLabel.Parent = button
		applySilkscreen(nameLabel)

		local overlay = Instance.new("Frame")
		overlay.Name = "CooldownOverlay"
		overlay.AnchorPoint = Vector2.new(0, 1)
		overlay.Position = UDim2.fromScale(0, 1)
		overlay.Size = UDim2.fromScale(1, 1)
		overlay.BackgroundColor3 = UT_WHITE
		overlay.BackgroundTransparency = 0.15
		overlay.BorderSizePixel = 0
		overlay.Visible = false
		overlay.Parent = button

		local cooldownText = Instance.new("TextLabel")
		cooldownText.Name = "CooldownText"
		cooldownText.BackgroundTransparency = 1
		cooldownText.Size = UDim2.fromScale(1, 1)
		cooldownText.TextSize = 22
		cooldownText.TextColor3 = UT_YELLOW
		cooldownText.TextStrokeTransparency = 0.4
		cooldownText.Visible = false
		cooldownText.Parent = button
		applySilkscreen(cooldownText)

		self.MoveButtons[moveSlot] = button
		self.MoveButtonStrokes[moveSlot] = stroke
		self.MoveNameLabels[moveSlot] = nameLabel
		self.CooldownOverlays[moveSlot] = overlay
		self.CooldownTexts[moveSlot] = cooldownText

		button.MouseButton1Click:Connect(function()
			if self.OnMoveButtonPressed then
				self.OnMoveButtonPressed(moveSlot)
			end
		end)
	end
end

return MoveHudController
