local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local BlasterHelper = {}

function BlasterHelper.EnsurePrimaryPart(model)
	if not model or not model:IsA("Model") then return nil end

	if model.PrimaryPart then
		return model.PrimaryPart
	end

	local primary = model:FindFirstChild("PrimaryPart", true)
	if primary and primary:IsA("BasePart") then
		model.PrimaryPart = primary
		return primary
	end

	local firstPart = model:FindFirstChildWhichIsA("BasePart", true)
	if firstPart then
		model.PrimaryPart = firstPart
		return firstPart
	end

	return nil
end

function BlasterHelper.SetupWorldModel(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end

	local primary = BlasterHelper.EnsurePrimaryPart(model)
	if primary then
		primary.Transparency = 1
	end

	return primary
end

function BlasterHelper.GetVisibleParts(model, excludePrimaryInstance)
	local parts = {}

	if model:IsA("BasePart") then
		table.insert(parts, model)
		return parts
	end

	local primary = excludePrimaryInstance and BlasterHelper.EnsurePrimaryPart(model) or nil

	for _, descendant in ipairs(model:GetDescendants()) do
		local shouldInclude = descendant:IsA("BasePart")
		if shouldInclude and excludePrimaryInstance then
			shouldInclude = descendant ~= primary
		elseif shouldInclude then
			shouldInclude = descendant.Name ~= "PrimaryPart"
		end

		if shouldInclude then
			table.insert(parts, descendant)
		end
	end

	return parts
end

function BlasterHelper.ForcePrimaryInvisible(model)
	local primary = BlasterHelper.EnsurePrimaryPart(model)

	if primary then
		primary.Transparency = 1
		primary.CanCollide = false
		primary.CanTouch = false
		primary.CanQuery = false
	end
end

function BlasterHelper.TweenPivot(model, startCFrame, endCFrame, tweenInfo)
	if not model or not model.Parent then
		return nil
	end

	local cframeValue = Instance.new("CFrameValue")
	cframeValue.Name = "BlasterTweenCFrame"
	cframeValue.Value = startCFrame

	local connection
	connection = cframeValue:GetPropertyChangedSignal("Value"):Connect(function()
		if model and model.Parent then
			model:PivotTo(cframeValue.Value)
			BlasterHelper.ForcePrimaryInvisible(model)
		end
	end)

	local tween = TweenService:Create(cframeValue, tweenInfo, {
		Value = endCFrame,
	})

	tween.Completed:Connect(function()
		if connection then
			connection:Disconnect()
		end

		if cframeValue then
			cframeValue:Destroy()
		end

		if model and model.Parent then
			model:PivotTo(endCFrame)
			BlasterHelper.ForcePrimaryInvisible(model)
		end
	end)

	tween:Play()

	return tween
end

function BlasterHelper.FadeOutObject(object, fadeTime)
	if not object or not object.Parent then
		return
	end

	fadeTime = fadeTime or 0.15

	for _, part in ipairs(BlasterHelper.GetVisibleParts(object)) do
		TweenService:Create(part, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 1,
		}):Play()
	end

	if object:IsA("Model") then
		BlasterHelper.ForcePrimaryInvisible(object)
	end

	Debris:AddItem(object, fadeTime + 0.08)
end

return BlasterHelper
