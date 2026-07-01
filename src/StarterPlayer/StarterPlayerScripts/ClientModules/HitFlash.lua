local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local HitFlash = {}

local effect = nil
local activeTween = nil
local token = 0

local function getEffect()
	if effect and effect.Parent then
		return effect
	end

	effect = Instance.new("ColorCorrectionEffect")
	effect.Name = "UTBGHitFlash"
	effect.Enabled = false
	effect.Parent = Lighting

	return effect
end

local function resetEffect()
	local current = getEffect()
	current.Enabled = false
	current.TintColor = Color3.fromRGB(255, 255, 255)
	current.Contrast = 0
	current.Saturation = 0
	current.Brightness = 0
end

function HitFlash:Flash(color, contrast, saturation, duration)
	token += 1
	local myToken = token

	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end

	local current = getEffect()
	current.Enabled = true
	current.TintColor = color or Color3.fromRGB(255, 255, 255)
	current.Contrast = contrast or 1
	current.Saturation = saturation or -1
	current.Brightness = 0

	activeTween = TweenService:Create(
		current,
		TweenInfo.new(duration or 0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Contrast = 0,
			Saturation = 0,
			Brightness = 0,
			TintColor = Color3.fromRGB(255, 255, 255),
		}
	)

	activeTween:Play()

	task.delay(duration or 0.08, function()
		if myToken == token then
			resetEffect()
		end
	end)
end

function HitFlash:RedBlack(duration)
	self:Flash(Color3.fromRGB(255, 0, 0), 2.4, -1, duration or 0.08)
end

function HitFlash:Invert(duration)
	self:Flash(Color3.fromRGB(0, 0, 0), -2, -1, duration or 0.08)
end

function HitFlash:Reset()
	token += 1

	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end

	resetEffect()
end

return HitFlash
