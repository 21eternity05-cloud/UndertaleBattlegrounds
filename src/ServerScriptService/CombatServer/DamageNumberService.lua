local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local DamageNumberService = {}
DamageNumberService.__index = DamageNumberService

function DamageNumberService.new(config)
	local self = setmetatable({}, DamageNumberService)

	self.Config = config

	return self
end

function DamageNumberService:IsEnabled()
	if self.Config and self.Config.DebugDamageNumbers == true then
		return true
	end

	if workspace:GetAttribute("DebugDamageNumbers") == true then
		return true
	end

	return false
end

function DamageNumberService:ShowDamage(targetRoot, amount, options)
	if not self:IsEnabled() then
		return
	end

	if not targetRoot or not targetRoot.Parent then
		return
	end

	if typeof(amount) ~= "number" then
		return
	end

	options = options or {}

	local holder = Instance.new("Part")
	holder.Name = "DamageNumberHolder"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanTouch = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.25, 0.25, 0.25)
	holder.CFrame = CFrame.new(
		targetRoot.Position
			+ Vector3.new(
				math.random(-12, 12) / 10,
				3 + math.random(0, 8) / 10,
				math.random(-12, 12) / 10
			)
	)
	holder.Parent = workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DamageNumberGui"
	billboard.Size = UDim2.fromOffset(100, 44)
	billboard.AlwaysOnTop = true
	billboard.Parent = holder

	local text = Instance.new("TextLabel")
	text.Name = "DamageText"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBlack
	text.TextSize = options.TextSize or 24
	text.TextColor3 = options.Color or Color3.fromRGB(255, 80, 80)
	text.TextStrokeTransparency = 0.15
	text.Text = tostring(math.floor(amount + 0.5))
	text.Parent = billboard

	TweenService:Create(
		holder,
		TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Position = holder.Position + Vector3.new(0, 2.2, 0),
		}
	):Play()

	TweenService:Create(
		text,
		TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}
	):Play()

	Debris:AddItem(holder, 0.65)
end

return DamageNumberService