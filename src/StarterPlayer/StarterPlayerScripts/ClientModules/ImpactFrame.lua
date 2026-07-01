local Lighting = game:GetService("Lighting")

local ImpactFrame = {}

local HIGHLIGHT_NAME = "UTBGImpactFrameHighlight"
local COLOR_CORRECTION_NAME = "UTBGImpactFrameColorCorrection"

local activeToken = 0
local activeHighlights = {}
local activeColorCorrection = nil

local function destroyHighlightOn(character)
	if not character then
		return
	end

	for _, child in ipairs(character:GetChildren()) do
		if child.Name == HIGHLIGHT_NAME and child:IsA("Highlight") then
			child:Destroy()
		end
	end
end

local function clearHighlights()
	for _, highlight in ipairs(activeHighlights) do
		if highlight and highlight.Parent then
			highlight:Destroy()
		end
	end

	table.clear(activeHighlights)
end

local function clearColorCorrection()
	if activeColorCorrection then
		activeColorCorrection:Destroy()
		activeColorCorrection = nil
	end

	local existing = Lighting:FindFirstChild(COLOR_CORRECTION_NAME)
	if existing then
		existing:Destroy()
	end

	local oldExisting = Lighting:FindFirstChild("UTBGImpactFrameColor")
	if oldExisting then
		oldExisting:Destroy()
	end
end

local function addSubjectHighlight(character, color, fillTransparency, outlineTransparency)
	if not character or not character.Parent then
		return nil
	end

	destroyHighlightOn(character)

	local highlight = Instance.new("Highlight")
	highlight.Name = HIGHLIGHT_NAME
	highlight.FillColor = color or Color3.fromRGB(255, 255, 255)
	highlight.OutlineColor = highlight.FillColor
	highlight.FillTransparency = fillTransparency or 0
	highlight.OutlineTransparency = outlineTransparency or 1
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = character

	table.insert(activeHighlights, highlight)
	return highlight
end

function ImpactFrame:Reset()
	activeToken += 1
	clearHighlights()
	clearColorCorrection()
end

function ImpactFrame:Play(options)
	options = options or {}

	activeToken += 1
	local token = activeToken

	clearHighlights()
	clearColorCorrection()

	local duration = math.max(options.Duration or 0.1, 0.03)
	local tintColor = options.TintColor or options.BackgroundColor or Color3.fromRGB(255, 255, 255)
	local brightness = typeof(options.Brightness) == "number" and options.Brightness or 1
	local outlineTransparency = typeof(options.OutlineTransparency) == "number" and options.OutlineTransparency or 1

	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = COLOR_CORRECTION_NAME
	effect.Enabled = true
	effect.TintColor = tintColor
	effect.Brightness = brightness
	effect.Contrast = options.Contrast or 0
	effect.Saturation = options.Saturation or 0
	effect.Parent = Lighting
	activeColorCorrection = effect

	addSubjectHighlight(
		options.Attacker,
		options.AttackerColor or options.HighlightColor or Color3.fromRGB(255, 255, 255),
		typeof(options.AttackerFillTransparency) == "number" and options.AttackerFillTransparency or 0,
		outlineTransparency
	)

	addSubjectHighlight(
		options.Victim,
		options.VictimColor or Color3.fromRGB(0, 0, 0),
		typeof(options.VictimFillTransparency) == "number" and options.VictimFillTransparency or 0,
		outlineTransparency
	)

	task.delay(duration, function()
		if token ~= activeToken then
			return
		end

		clearHighlights()
		clearColorCorrection()
	end)
end

return ImpactFrame
