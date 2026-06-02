local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local SansVFX = {}
SansVFX.__index = SansVFX

local PROJECTILE_TRAVEL_TIME = 0.12
local POP_IN_TIME = 0.08
local PRE_SHOOT_DELAY = 0.07
local FADE_OUT_TIME = 0.07

function SansVFX.new(config, vfxService)
	local self = setmetatable({}, SansVFX)

	self.Config = config
	self.VFXService = vfxService

	return self
end

function SansVFX:GetSansVFXFolder()
	return self.VFXService:GetCharacterVFXFolder("Sans")
end

function SansVFX:GetBoneTemplate()
	local sansVFXFolder = self:GetSansVFXFolder()
	if not sansVFXFolder then
		warn("[SansVFX] Missing Assets > Characters > Sans > VFX")
		return nil
	end

	local boneTemplate = sansVFXFolder:FindFirstChild("M1Bone")
	if not boneTemplate then
		warn("[SansVFX] Missing Sans VFX > M1Bone")
		return nil
	end

	return boneTemplate
end

function SansVFX:SetBoneProperties(instance)
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end

	if instance:IsA("BasePart") then
		instance.Anchored = true
		instance.CanCollide = false
		instance.CanTouch = false
		instance.CanQuery = false
		instance.Massless = true
	end
end

function SansVFX:EnsurePrimaryPart(model)
	if not model:IsA("Model") then return nil end

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

function SansVFX:PivotObject(object, cframe)
	if object:IsA("Model") then
		local primary = self:EnsurePrimaryPart(object)
		if not primary then return end

		object:PivotTo(cframe)
	elseif object:IsA("BasePart") then
		object.CFrame = cframe
	end
end

function SansVFX:GetRoot(character)
	if not character or not character.Parent then return nil end
	return character:FindFirstChild("HumanoidRootPart")
end

function SansVFX:GetSideDirection(combo)
	if combo % 2 == 1 then
		return 1, -1 -- odd M1: right to left
	end

	return -1, 1 -- even M1: left to right
end

function SansVFX:MakeLookCFrame(position, lookAtPosition)
	local direction = lookAtPosition - position

	if direction.Magnitude < 0.1 then
		direction = Vector3.new(0, 0, -1)
	end

	return CFrame.lookAt(position, position + direction.Unit)
end

function SansVFX:GetMissFloorCFrame(character, combo)
	local root = self:GetRoot(character)
	if not root then return nil end

	local _, endSide = self:GetSideDirection(combo)

	local rayOrigin = (root.CFrame * CFrame.new(endSide * 2.4, 2, -10)).Position
	local rayDirection = Vector3.new(0, -35, 0)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local result = workspace:Raycast(rayOrigin, rayDirection, params)

	local endPosition
	if result then
		endPosition = result.Position + Vector3.new(0, 0.25, 0)
	else
		endPosition = (root.CFrame * CFrame.new(endSide * 2.4, -2.5, -10)).Position
	end

	local previousPosition = (root.CFrame * CFrame.new(-endSide * 2.4, 1.5, -6.5)).Position
	return self:MakeLookCFrame(endPosition, endPosition + (endPosition - previousPosition).Unit)
end

function SansVFX:GetStartAndEndCFrame(character, combo, targetRoot, didHit)
	local root = self:GetRoot(character)
	if not root then return nil, nil end

	local startSide, endSide = self:GetSideDirection(combo)

	local startHeight = 4.25
	local startForward = 2.25
	local startSideOffset = startSide * 2.6

	if combo == 3 or combo == 4 then
		startHeight = 4.6
	elseif combo == 5 then
		startHeight = 5
		startForward = 2.8
	end

	local startPosition = (root.CFrame * CFrame.new(startSideOffset, startHeight, startForward)).Position

	local endCFrame

	if didHit and targetRoot and targetRoot.Parent then
		local endPosition = (targetRoot.CFrame * CFrame.new(endSide * 1.35, 1.15, 0)).Position
		endCFrame = self:MakeLookCFrame(endPosition, targetRoot.Position + Vector3.new(0, 1.15, 0))
	else
		endCFrame = self:GetMissFloorCFrame(character, combo)
	end

	if not endCFrame then return nil, nil end

	local startCFrame = self:MakeLookCFrame(startPosition, endCFrame.Position)

	return startCFrame, endCFrame
end

function SansVFX:GetVisualParts(bone)
	local parts = {}

	if bone:IsA("BasePart") then
		table.insert(parts, bone)
		return parts
	end

	for _, descendant in ipairs(bone:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name ~= "PrimaryPart" then
			table.insert(parts, descendant)
		end
	end

	return parts
end

function SansVFX:StoreOriginalPartData(bone)
	for _, part in ipairs(self:GetVisualParts(bone)) do
		part:SetAttribute("OriginalSize", part.Size)
		part:SetAttribute("OriginalTransparency", part.Transparency)
	end
end

function SansVFX:ScaleBoneSmall(bone, scale)
	scale = scale or 0.55

	for _, part in ipairs(self:GetVisualParts(bone)) do
		part.Size = part.Size * scale
	end
end

function SansVFX:SetBoneTransparency(bone, transparency)
	for _, part in ipairs(self:GetVisualParts(bone)) do
		part.Transparency = transparency
	end
end

function SansVFX:TweenBonePopIn(bone)
	for _, part in ipairs(self:GetVisualParts(bone)) do
		local originalSize = part:GetAttribute("OriginalSize") or part.Size
		local originalTransparency = part:GetAttribute("OriginalTransparency")

		if typeof(originalTransparency) ~= "number" then
			originalTransparency = 0
		end

		TweenService:Create(
			part,
			TweenInfo.new(POP_IN_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{
				Size = originalSize,
				Transparency = originalTransparency,
			}
		):Play()
	end
end

function SansVFX:FadeOutBone(bone)
	if not bone or not bone.Parent then return end

	for _, part in ipairs(self:GetVisualParts(bone)) do
		TweenService:Create(
			part,
			TweenInfo.new(FADE_OUT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Size = part.Size * 1.2,
				Transparency = 1,
			}
		):Play()
	end

	Debris:AddItem(bone, FADE_OUT_TIME + 0.05)
end

function SansVFX:TweenProjectile(bone, startCFrame, endCFrame)
	task.delay(PRE_SHOOT_DELAY, function()
		if not bone or not bone.Parent then return end

		local startTime = os.clock()

		local connection
		connection = RunService.Heartbeat:Connect(function()
			if not bone or not bone.Parent then
				if connection then
					connection:Disconnect()
				end
				return
			end

			local alpha = math.clamp((os.clock() - startTime) / PROJECTILE_TRAVEL_TIME, 0, 1)
			local easedAlpha = 1 - ((1 - alpha) * (1 - alpha))

			local currentCFrame = startCFrame:Lerp(endCFrame, easedAlpha)
			self:PivotObject(bone, currentCFrame)

			if alpha >= 1 then
				connection:Disconnect()

				self:PivotObject(bone, endCFrame)
				self:FadeOutBone(bone)
			end
		end)
	end)
end

function SansVFX:PlayM1(character, combo, targetCharacter, targetRoot, didHit)
	if not character or not character.Parent then return end

	local boneTemplate = self:GetBoneTemplate()
	if not boneTemplate then return end

	local startCFrame, endCFrame = self:GetStartAndEndCFrame(character, combo, targetRoot, didHit)
	if not startCFrame or not endCFrame then return end

	local bone = boneTemplate:Clone()
	bone.Name = "SansM1BoneProjectileVFX"

	if bone:IsA("Model") then
		local primary = self:EnsurePrimaryPart(bone)
		if not primary then
			warn("[SansVFX] M1Bone model has no PrimaryPart or BasePart")
			bone:Destroy()
			return
		end
	end

	self:SetBoneProperties(bone)
	self:StoreOriginalPartData(bone)
	self:ScaleBoneSmall(bone, 0.5)
	self:SetBoneTransparency(bone, 1)

	bone.Parent = workspace

	self:PivotObject(bone, startCFrame)
	self:TweenBonePopIn(bone)
	self:TweenProjectile(bone, startCFrame, endCFrame)

	Debris:AddItem(bone, 1.25)
end

function SansVFX:PlayMove(character, moveName, targetCharacter, targetRoot)
	-- Move VFX will be upgraded separately.
end

return SansVFX
