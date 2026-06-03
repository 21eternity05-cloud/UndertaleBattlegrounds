local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local SansVFX = {}
SansVFX.__index = SansVFX

local PROJECTILE_TRAVEL_TIME = 0.12
local POP_IN_TIME = 0.08
local PRE_SHOOT_DELAY = 0.07
local FADE_OUT_TIME = 0.07

local BONE_WALL_ARC_TIME = 0.36
local BONE_WALL_LIFETIME = 0.9

function SansVFX.new(config, vfxService)
	local self = setmetatable({}, SansVFX)

	self.Config = config
	self.VFXService = vfxService

	return self
end

function SansVFX:GetSansVFXFolder()
	return self.VFXService:GetCharacterVFXFolder("Sans")
end

function SansVFX:GetVFXTemplate(templateName)
	local sansVFXFolder = self:GetSansVFXFolder()

	if not sansVFXFolder then
		warn("[SansVFX] Missing Assets > Characters > Sans > VFX")
		return nil
	end

	local template = sansVFXFolder:FindFirstChild(templateName)

	if not template then
		warn("[SansVFX] Missing Sans VFX >", templateName)
		return nil
	end

	return template
end

function SansVFX:GetBoneTemplate()
	return self:GetVFXTemplate("M1Bone")
end

function SansVFX:GetBoneWallTemplate()
	return self:GetVFXTemplate("BoneWall")
end

function SansVFX:GetBlueHeartTemplate()
	return self:GetVFXTemplate("BlueHeart")
end

function SansVFX:SetModelPartProperties(instance)
	if not instance then return end

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
	if not model or not model:IsA("Model") then
		return nil
	end

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

function SansVFX:ForcePrimaryInvisible(model)
	if not model or not model:IsA("Model") then return end

	local primary = self:EnsurePrimaryPart(model)

	if primary then
		primary.Transparency = 1
		primary.CanCollide = false
		primary.CanTouch = false
		primary.CanQuery = false
	end
end

function SansVFX:PivotObject(object, cframe)
	if not object then return end

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
		return 1, -1
	end

	return -1, 1
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
	local travelDirection = endPosition - previousPosition

	if travelDirection.Magnitude < 0.1 then
		travelDirection = root.CFrame.LookVector
	end

	return self:MakeLookCFrame(endPosition, endPosition + travelDirection.Unit)
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

	if not endCFrame then
		return nil, nil
	end

	local startCFrame = self:MakeLookCFrame(startPosition, endCFrame.Position)

	return startCFrame, endCFrame
end

function SansVFX:GetVisualParts(object)
	local parts = {}

	if object:IsA("BasePart") then
		table.insert(parts, object)
		return parts
	end

	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name ~= "PrimaryPart" then
			table.insert(parts, descendant)
		end
	end

	return parts
end

function SansVFX:StoreOriginalPartData(object)
	for _, part in ipairs(self:GetVisualParts(object)) do
		part:SetAttribute("OriginalSize", part.Size)
		part:SetAttribute("OriginalTransparency", part.Transparency)
	end
end

function SansVFX:ScaleVisualSmall(object, scale)
	scale = scale or 0.55

	for _, part in ipairs(self:GetVisualParts(object)) do
		part.Size = part.Size * scale
	end
end

function SansVFX:SetVisualTransparency(object, transparency)
	for _, part in ipairs(self:GetVisualParts(object)) do
		part.Transparency = transparency
	end

	if object:IsA("Model") then
		self:ForcePrimaryInvisible(object)
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

function SansVFX:FadeOutObject(object, fadeTime)
	if not object or not object.Parent then return end

	fadeTime = fadeTime or FADE_OUT_TIME

	for _, part in ipairs(self:GetVisualParts(object)) do
		TweenService:Create(
			part,
			TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Size = part.Size * 1.08,
				Transparency = 1,
			}
		):Play()
	end

	if object:IsA("Model") then
		self:ForcePrimaryInvisible(object)
	end

	Debris:AddItem(object, fadeTime + 0.08)
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
				self:FadeOutObject(bone, FADE_OUT_TIME)
			end
		end)
	end)
end

function SansVFX:GetBoneWallCFrames(character)
	local root = self:GetRoot(character)

	if not root then
		return nil, nil, nil
	end

	local baseCFrame = root.CFrame * CFrame.new(0, 0, -6.4)

	local startCFrame = baseCFrame * CFrame.new(0, -4.5, 1.2)
	local peakCFrame = baseCFrame * CFrame.new(0, 2.25, -3.4)
	local endCFrame = baseCFrame * CFrame.new(0, -4.8, -8.4)

	return startCFrame, peakCFrame, endCFrame
end

function SansVFX:QuadraticBezierCFrame(startCFrame, peakCFrame, endCFrame, alpha)
	local first = startCFrame:Lerp(peakCFrame, alpha)
	local second = peakCFrame:Lerp(endCFrame, alpha)

	return first:Lerp(second, alpha)
end

function SansVFX:TweenBoneWallAlongArc(boneWall, startCFrame, peakCFrame, endCFrame)
	if not boneWall or not boneWall.Parent then return end

	local alphaValue = Instance.new("NumberValue")
	alphaValue.Name = "BoneWallArcAlpha"
	alphaValue.Value = 0

	local connection

	connection = alphaValue:GetPropertyChangedSignal("Value"):Connect(function()
		if not boneWall or not boneWall.Parent then
			if connection then
				connection:Disconnect()
			end

			if alphaValue then
				alphaValue:Destroy()
			end

			return
		end

		local alpha = math.clamp(alphaValue.Value, 0, 1)
		local currentCFrame = self:QuadraticBezierCFrame(startCFrame, peakCFrame, endCFrame, alpha)

		self:PivotObject(boneWall, currentCFrame)

		if boneWall:IsA("Model") then
			self:ForcePrimaryInvisible(boneWall)
		end
	end)

	local tween = TweenService:Create(
		alphaValue,
		TweenInfo.new(BONE_WALL_ARC_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Value = 1,
		}
	)

	tween:Play()

	tween.Completed:Connect(function()
		if connection then
			connection:Disconnect()
		end

		if alphaValue then
			alphaValue:Destroy()
		end

		if boneWall and boneWall.Parent then
			self:FadeOutObject(boneWall, 0.08)
		end
	end)
end

function SansVFX:PlayBoneWallM5(character)
	local template = self:GetBoneWallTemplate()
	if not template then return end

	local startCFrame, peakCFrame, endCFrame = self:GetBoneWallCFrames(character)

	if not startCFrame or not peakCFrame or not endCFrame then
		return
	end

	local boneWall = template:Clone()
	boneWall.Name = "SansM5BoneWallVFX"

	if boneWall:IsA("Model") then
		local primary = self:EnsurePrimaryPart(boneWall)

		if not primary then
			warn("[SansVFX] BoneWall model has no PrimaryPart or BasePart")
			boneWall:Destroy()
			return
		end
	end

	self:SetModelPartProperties(boneWall)
	self:StoreOriginalPartData(boneWall)
	boneWall.Parent = workspace

	self:PivotObject(boneWall, startCFrame)

	if boneWall:IsA("Model") then
		self:ForcePrimaryInvisible(boneWall)
	end

	self:TweenBoneWallAlongArc(boneWall, startCFrame, peakCFrame, endCFrame)

	Debris:AddItem(boneWall, BONE_WALL_LIFETIME)
end

function SansVFX:EmitBlueHeart(targetRoot)
	if not targetRoot or not targetRoot.Parent then return end

	local template = self:GetBlueHeartTemplate()
	if not template then return end

	if not template:IsA("Attachment") then
		warn("[SansVFX] BlueHeart must be an Attachment")
		return
	end

	local attachment = template:Clone()
	attachment.Name = "ActiveBlueHeart"
	attachment.Parent = targetRoot

	for _, descendant in ipairs(attachment:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false
			descendant:Emit(1)
		end
	end

	Debris:AddItem(attachment, 1.75)
end

function SansVFX:EmitEyeGlow(character)
	if not character or not character.Parent then return end

	local template = self:GetVFXTemplate("EyeGlow")
	if not template then return end

	if not template:IsA("Attachment") then
		warn("[SansVFX] EyeGlow must be an Attachment")
		return
	end

	local head = character:FindFirstChild("Head")

	if not head then
		warn("[SansVFX] Missing Head for EyeGlow")
		return
	end

	local attachment = template:Clone()
	attachment.Name = "ActiveEyeGlow"
	attachment.Parent = head

	for _, descendant in ipairs(attachment:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false

			local emitCount = descendant:GetAttribute("EmitCount")

			if typeof(emitCount) ~= "number" then
				emitCount = 1
			end

			descendant:Emit(emitCount)
		end
	end

	Debris:AddItem(attachment, 1.5)
end

function SansVFX:PlayM1(character, combo, targetCharacter, targetRoot, didHit)
	if not character or not character.Parent then return end

	if combo == 5 then
		self:PlayBoneWallM5(character)
		return
	end

	local boneTemplate = self:GetBoneTemplate()
	if not boneTemplate then return end

	local startCFrame, endCFrame = self:GetStartAndEndCFrame(character, combo, targetRoot, didHit)

	if not startCFrame or not endCFrame then
		return
	end

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

	self:SetModelPartProperties(bone)
	self:StoreOriginalPartData(bone)
	self:ScaleVisualSmall(bone, 0.5)
	self:SetVisualTransparency(bone, 1)

	bone.Parent = workspace

	self:PivotObject(bone, startCFrame)
	self:TweenBonePopIn(bone)
	self:TweenProjectile(bone, startCFrame, endCFrame)

	Debris:AddItem(bone, 1.25)
end

function SansVFX:PlayMove(character, moveName, targetCharacter, targetRoot)
	if moveName == "BlueHeart" then
		self:EmitBlueHeart(targetRoot)
		return
	end

	if moveName == "EyeGlow" then
		self:EmitEyeGlow(character)
		return
	end

	if moveName == "UptiltHit" then
		self:EmitBlueHeart(targetRoot)
		return
	end

	if moveName == "DownslamHit" then
		self:EmitBlueHeart(targetRoot)
		return
	end
end

return SansVFX