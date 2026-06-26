local Debris = game:GetService("Debris")

local HitboxService = {}
HitboxService.__index = HitboxService

function HitboxService.new(config)
	local self = setmetatable({}, HitboxService)
	self.Config = config
	return self
end

function HitboxService:ShowDebugSphere(position, radius)
	if not self.Config.DebugHitboxes then return end

	local sphere = Instance.new("Part")
	sphere.Name = "DebugSphereHitbox"
	sphere.Shape = Enum.PartType.Ball
	sphere.Anchored = true
	sphere.CanCollide = false
	sphere.CanTouch = false
	sphere.CanQuery = false
	sphere.Material = Enum.Material.Neon
	sphere.Color = Color3.fromRGB(255, 0, 0)
	sphere.Transparency = 0.4
	sphere.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
	sphere.Position = position
	sphere.Parent = workspace

	Debris:AddItem(sphere, 0.13)
end

function HitboxService:GetCharactersInSphere(attackerCharacter, position, radius)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { attackerCharacter }

	local parts = workspace:GetPartBoundsInRadius(position, radius, params)

	local foundCharacters = {}
	local alreadyFound = {}

	for _, part in ipairs(parts) do
		local model = part:FindFirstAncestorOfClass("Model")

		if model and not alreadyFound[model] then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local root = model:FindFirstChild("HumanoidRootPart")

			if humanoid and root and humanoid.Health > 0 then
				alreadyFound[model] = true
				table.insert(foundCharacters, model)
			end
		end
	end

	return foundCharacters
end

function HitboxService:PerformSphereHitbox(attackerCharacter, attackerRoot, data, onHit)
	local hitboxCFrame = attackerRoot.CFrame * data.Offset
	local position = hitboxCFrame.Position
	local radius = data.Radius

	self:ShowDebugSphere(position, radius)

	local targets = self:GetCharactersInSphere(attackerCharacter, position, radius)

	for _, targetCharacter in ipairs(targets) do
		local targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
		local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")

		if targetHumanoid and targetRoot then
			onHit(targetCharacter, targetHumanoid, targetRoot)
		end
	end
end

function HitboxService:PerformSphereAtPosition(attackerCharacter, position, radius, onHit)
	self:ShowDebugSphere(position, radius)

	local targets = self:GetCharactersInSphere(attackerCharacter, position, radius)

	for _, targetCharacter in ipairs(targets) do
		local targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
		local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")

		if targetHumanoid and targetRoot then
			onHit(targetCharacter, targetHumanoid, targetRoot)
		end
	end
end

function HitboxService:PerformSphereAtCFrame(attackerCharacter, cframe, data, onHit)
	local hitboxCFrame = cframe * data.Offset
	local position = hitboxCFrame.Position
	local radius = data.Radius

	self:PerformSphereAtPosition(attackerCharacter, position, radius, onHit)
end

function HitboxService:PerformSphereChain(attackerCharacter, startPosition, direction, length, step, radius, onHit)
	if typeof(startPosition) ~= "Vector3" then return end
	if typeof(direction) ~= "Vector3" then return end

	if direction.Magnitude < 0.05 then
		return
	end

	length = length or 60
	step = step or 6
	radius = radius or 5

	local unitDirection = direction.Unit
	local hitThisChain = {}

	for distance = 0, length, step do
		local position = startPosition + (unitDirection * distance)

		self:ShowDebugSphere(position, radius)

		local targets = self:GetCharactersInSphere(attackerCharacter, position, radius)

		for _, targetCharacter in ipairs(targets) do
			if not hitThisChain[targetCharacter] then
				hitThisChain[targetCharacter] = true

				local targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
				local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")

				if targetHumanoid and targetRoot then
					onHit(targetCharacter, targetHumanoid, targetRoot, position)
				end
			end
		end
	end
end

return HitboxService
