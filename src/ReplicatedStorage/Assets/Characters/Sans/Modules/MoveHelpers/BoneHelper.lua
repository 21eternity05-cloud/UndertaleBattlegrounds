local BoneHelper = {}

function BoneHelper.MakeLookCFrame(position, lookAtPosition)
	local direction = lookAtPosition - position

	if direction.Magnitude < 0.1 then
		direction = Vector3.new(0, 0, -1)
	end

	return CFrame.lookAt(position, position + direction.Unit)
end

function BoneHelper.EnsurePrimaryPart(model)
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

function BoneHelper.PivotObject(object, cframe)
	if object:IsA("Model") then
		BoneHelper.EnsurePrimaryPart(object)
		object:PivotTo(cframe)
	elseif object:IsA("BasePart") then
		object.CFrame = cframe
	end
end

function BoneHelper.SetProjectileSpawnProperties(projectile, ownerName)
	if projectile:IsA("Model") then
		projectile:SetAttribute("IsProjectile", true)
		projectile:SetAttribute("ProjectileOwner", ownerName or "SansBone")
	end

	for _, descendant in ipairs(projectile:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			descendant:SetAttribute("IsProjectile", true)
			descendant:SetAttribute("ProjectileOwner", ownerName or "SansBone")
		end
	end

	if projectile:IsA("BasePart") then
		projectile.Anchored = true
		projectile.CanCollide = false
		projectile.CanTouch = false
		projectile.CanQuery = false
		projectile.Massless = true
		projectile:SetAttribute("IsProjectile", true)
		projectile:SetAttribute("ProjectileOwner", ownerName or "SansBone")
	end
end

return BoneHelper
