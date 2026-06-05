local Debris = game:GetService("Debris")

local CharaVFX = {}
CharaVFX.__index = CharaVFX

function CharaVFX.new(config, vfxService)
	local self = setmetatable({}, CharaVFX)

	self.Config = config
	self.VFXService = vfxService

	return self
end

function CharaVFX:GetCharaVFXFolder()
	return self.VFXService:GetCharacterVFXFolder("Chara")
end

function CharaVFX:GetEquippedKnife(character)
	if not character then return nil end

	local weapon = character:FindFirstChild("EquippedWeapon")
	if not weapon then return nil end

	return weapon
end

function CharaVFX:GetKnifePrimaryPart(character)
	local knife = self:GetEquippedKnife(character)

	if not knife then
		local realKnife = character and character:FindFirstChild("RealKnife", true)
		if realKnife then
			knife = realKnife
		end
	end

	if not knife then return nil end

	if knife:IsA("Model") then
		if knife.PrimaryPart then
			return knife.PrimaryPart
		end

		local handle = knife:FindFirstChild("HandleKnife", true)
		if handle and handle:IsA("BasePart") then
			knife.PrimaryPart = handle
			return handle
		end

		local handlePart = knife:FindFirstChild("Handle", true)
		if handlePart and handlePart:IsA("BasePart") then
			knife.PrimaryPart = handlePart
			return handlePart
		end

		return knife:FindFirstChildWhichIsA("BasePart", true)
	end

	if knife:IsA("BasePart") then
		return knife
	end

	return nil
end

function CharaVFX:GetRoot(character)
	if not character then return nil end
	return character:FindFirstChild("HumanoidRootPart")
end

function CharaVFX:EmitAttachment(attachment)
	if not attachment then return end

	for _, descendant in ipairs(attachment:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false

			local delayTime = descendant:GetAttribute("EmitDelay")
			local emitCount = descendant:GetAttribute("EmitCount")

			if typeof(emitCount) ~= "number" then
				emitCount = 1
			end

			if typeof(delayTime) == "number" and delayTime > 0 then
				task.delay(delayTime, function()
					if descendant and descendant.Parent then
						descendant:Emit(emitCount)
					end
				end)
			else
				descendant:Emit(emitCount)
			end
		end
	end
end

function CharaVFX:EmitAllParticles(instance)
	if not instance then return end

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false

			local emitCount = descendant:GetAttribute("EmitCount")
			local delayTime = descendant:GetAttribute("EmitDelay")

			if typeof(emitCount) ~= "number" then
				emitCount = 15
			end

			if typeof(delayTime) == "number" and delayTime > 0 then
				task.delay(delayTime, function()
					if descendant and descendant.Parent then
						descendant:Emit(emitCount)
					end
				end)
			else
				descendant:Emit(emitCount)
			end
		end
	end
end

function CharaVFX:PrepareVFXInstance(instance)
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

function CharaVFX:PivotVFX(instance, cframe)
	if not instance then return end

	if instance:IsA("Model") then
		instance:PivotTo(cframe)
	elseif instance:IsA("BasePart") then
		instance.CFrame = cframe
	elseif instance:IsA("Attachment") then
		-- Attachments are positioned by parent.
	end
end

function CharaVFX:CloneWorldVFX(vfxName, cframe, lifetime)
	local vfxFolder = self:GetCharaVFXFolder()
	if not vfxFolder then return nil end

	local template = vfxFolder:FindFirstChild(vfxName)
	if not template then
		warn("[CharaVFX] Missing VFX:", vfxName)
		return nil
	end

	local clone = template:Clone()
	clone.Name = "Active" .. vfxName

	if clone:IsA("Attachment") then
		local holder = Instance.new("Part")
		holder.Name = "Active" .. vfxName .. "Holder"
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanTouch = false
		holder.CanQuery = false
		holder.Transparency = 1
		holder.Size = Vector3.new(0.5, 0.5, 0.5)
		holder.CFrame = cframe
		holder.Parent = workspace

		clone.Parent = holder

		self:EmitAttachment(clone)

		Debris:AddItem(holder, lifetime or 2)
		return holder
	end

	self:PrepareVFXInstance(clone)
	clone.Parent = workspace
	self:PivotVFX(clone, cframe)
	self:EmitAllParticles(clone)

	Debris:AddItem(clone, lifetime or 2)

	return clone
end

function CharaVFX:GetForwardVFXCFrame(character, distance, height)
	local root = self:GetRoot(character)

	if not root then
		return CFrame.new()
	end

	return root.CFrame * CFrame.new(0, height or 0, -(distance or 4))
end

function CharaVFX:PlayKnifeDashStart(character)
	local vfxFolder = self:GetCharaVFXFolder()
	if not vfxFolder then return end

	local knifePart = self:GetKnifePrimaryPart(character)
	if not knifePart then return end

	local template = vfxFolder:FindFirstChild("KnifeShine")
	if not template or not template:IsA("Attachment") then
		warn("[CharaVFX] Missing KnifeShine attachment")
		return
	end

	local attachment = template:Clone()
	attachment.Name = "ActiveKnifeShine"
	attachment.Parent = knifePart

	self:EmitAttachment(attachment)

	Debris:AddItem(attachment, 2)
end

function CharaVFX:PlayKnifeDashTrailStart(character)
	local vfxFolder = self:GetCharaVFXFolder()
	if not vfxFolder then return end

	local knifePart = self:GetKnifePrimaryPart(character)
	if not knifePart then return end

	if knifePart:FindFirstChild("ActiveKnifeTrail") then
		return
	end

	local template = vfxFolder:FindFirstChild("KnifeTrail")
	if not template then
		warn("[CharaVFX] Missing KnifeTrail")
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "ActiveKnifeTrail"
	folder.Parent = knifePart

	local clonedObjects = {}

	for _, child in ipairs(template:GetChildren()) do
		local clone = child:Clone()
		clone.Parent = knifePart
		clone:SetAttribute("KnifeDashTrailObject", true)
		table.insert(clonedObjects, clone)
	end

	local attachments = {}
	local trail = nil

	for _, object in ipairs(clonedObjects) do
		if object:IsA("Attachment") then
			table.insert(attachments, object)
		elseif object:IsA("Trail") then
			trail = object
		end
	end

	if trail and #attachments >= 2 then
		trail.Attachment0 = attachments[1]
		trail.Attachment1 = attachments[2]
		trail.Enabled = true
	end
end

function CharaVFX:PlayKnifeDashTrailStop(character)
	local knifePart = self:GetKnifePrimaryPart(character)
	if not knifePart then return end

	for _, child in ipairs(knifePart:GetChildren()) do
		if child:GetAttribute("KnifeDashTrailObject") == true then
			child:Destroy()
		end
	end

	local folder = knifePart:FindFirstChild("ActiveKnifeTrail")
	if folder then
		folder:Destroy()
	end
end

function CharaVFX:PlayRedSlash(character, targetCharacter, targetRoot)
	local cframe = self:GetForwardVFXCFrame(character, 5, 0)
	self:CloneWorldVFX("RedSlash", cframe, 2)
end

function CharaVFX:PlaySlashBarrageSlash(character, targetCharacter, targetRoot)
	local TweenService = game:GetService("TweenService")

	local root = self:GetRoot(character)
	if not root then return end

	local vfxFolder = self:GetCharaVFXFolder()
	if not vfxFolder then return end

	local template = vfxFolder:FindFirstChild("SlashBarrage")
	if not template then
		warn("[CharaVFX] Missing SlashBarrage")
		return
	end

	local baseCFrame = self:GetForwardVFXCFrame(character, 4, 0)

	local randomRoll = math.rad(math.random(0, 359))
	local randomPitch = math.rad(math.random(-18, 18))
	local randomYaw = math.rad(math.random(-20, 20))

	local startCFrame =
		baseCFrame
		* CFrame.new(
			math.random(-12, 12) / 10,
			math.random(-4, 8) / 10,
			math.random(-10, 10) / 10
		)
		* CFrame.Angles(randomPitch, randomYaw, randomRoll)

	local forwardDistance = 3.5
	local endCFrame = startCFrame * CFrame.new(0, 0, -forwardDistance)

	local clone = template:Clone()
	clone.Name = "ActiveSlashBarrageSlash"

	self:PrepareVFXInstance(clone)
	clone.Parent = workspace
	self:PivotVFX(clone, startCFrame)

	local primaryPart = nil

	if clone:IsA("Model") then
		primaryPart = clone.PrimaryPart

		if not primaryPart then
			primaryPart = clone:FindFirstChild("PrimaryPart", true)

			if primaryPart and primaryPart:IsA("BasePart") then
				clone.PrimaryPart = primaryPart
			else
				primaryPart = nil
			end
		end
	elseif clone:IsA("BasePart") and clone.Name == "PrimaryPart" then
		primaryPart = clone
	end

	local function forcePrimaryInvisible()
		if primaryPart and primaryPart.Parent then
			primaryPart.Transparency = 1
			primaryPart.CanCollide = false
			primaryPart.CanTouch = false
			primaryPart.CanQuery = false
		end
	end

	local originalSizes = {}

	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false

			if descendant == primaryPart then
				descendant.Transparency = 1
			else
				originalSizes[descendant] = descendant.Size
				descendant.Transparency = 1
			end
		elseif descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false
		end
	end

	if clone:IsA("BasePart") then
		clone.CanCollide = false
		clone.CanTouch = false
		clone.CanQuery = false

		if clone == primaryPart then
			clone.Transparency = 1
		else
			originalSizes[clone] = clone.Size
			clone.Transparency = 1
		end
	end

	forcePrimaryInvisible()
	self:EmitAllParticles(clone)

	local fadeInInfo = TweenInfo.new(
		0.06,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)

	local slashInfo = TweenInfo.new(
		0.13,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)

	local fadeOutInfo = TweenInfo.new(
		0.11,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)

	local cframeValue = Instance.new("CFrameValue")
	cframeValue.Value = startCFrame

	local cframeConnection
	cframeConnection = cframeValue:GetPropertyChangedSignal("Value"):Connect(function()
		if clone and clone.Parent then
			self:PivotVFX(clone, cframeValue.Value)
			forcePrimaryInvisible()
		end
	end)

	for part, _ in pairs(originalSizes) do
		if part and part.Parent then
			TweenService:Create(
				part,
				fadeInInfo,
				{
					Transparency = 0,
				}
			):Play()
		end
	end

	forcePrimaryInvisible()

	task.delay(0.04, function()
		if not clone or not clone.Parent then return end

		TweenService:Create(
			cframeValue,
			slashInfo,
			{
				Value = endCFrame,
			}
		):Play()

		for part, originalSize in pairs(originalSizes) do
			if part and part.Parent then
				TweenService:Create(
					part,
					slashInfo,
					{
						Size = Vector3.new(
							originalSize.X * 1.15,
							originalSize.Y * 1.15,
							originalSize.Z * 1.65
						),
					}
				):Play()
			end
		end

		forcePrimaryInvisible()
	end)

	task.delay(0.16, function()
		if not clone or not clone.Parent then return end

		for part, originalSize in pairs(originalSizes) do
			if part and part.Parent then
				TweenService:Create(
					part,
					fadeOutInfo,
					{
						Transparency = 1,
						Size = originalSize,
					}
				):Play()
			end
		end

		forcePrimaryInvisible()
	end)

	task.delay(0.35, function()
		if cframeConnection then
			cframeConnection:Disconnect()
		end

		if cframeValue then
			cframeValue:Destroy()
		end

		if clone and clone.Parent then
			clone:Destroy()
		end
	end)
end

function CharaVFX:PlaySpecialHellStart(character)
	-- Placeholder startup VFX.
	-- Special Hell's main red warning/beam VFX is created inside SpecialHell.lua.
	-- Add knife glitch, red aura, or floor crack particles here later.
	local knifePart = self:GetKnifePrimaryPart(character)
	if not knifePart then return end

	local vfxFolder = self:GetCharaVFXFolder()
	if not vfxFolder then return end

	local template = vfxFolder:FindFirstChild("KnifeShine")
	if template and template:IsA("Attachment") then
		local attachment = template:Clone()
		attachment.Name = "ActiveSpecialHellKnifeShine"
		attachment.Parent = knifePart

		self:EmitAttachment(attachment)

		Debris:AddItem(attachment, 2)
	end
end

function CharaVFX:PlayMove(character, moveName, targetCharacter, targetRoot)
	if moveName == "KnifeDashStart" then
		self:PlayKnifeDashStart(character)
		return
	end

	if moveName == "KnifeDashTrailStart" then
		self:PlayKnifeDashTrailStart(character)
		return
	end

	if moveName == "KnifeDashTrailStop" then
		self:PlayKnifeDashTrailStop(character)
		return
	end

	if moveName == "KnifeDash" then
		-- Optional Knife Dash hit VFX later.
		return
	end

	if moveName == "RedSlash" then
		self:PlayRedSlash(character, targetCharacter, targetRoot)
		return
	end

	if moveName == "SlashBarrage" then
		self:PlaySlashBarrageSlash(character, targetCharacter, targetRoot)
		return
	end

	if moveName == "SpecialHell" then
		-- Special Hell's main VFX is handled inside SpecialHell.lua.
		-- This prevents harmless unknown-VFX warnings from MoveService.
		return
	end

	if moveName == "SpecialHellStart" then
		self:PlaySpecialHellStart(character)
		return
	end

	warn("[CharaVFX] Unknown move VFX:", moveName)
end

function CharaVFX:PlayM1(character, combo)
	-- Placeholder for Chara slash VFX later.
end

return CharaVFX