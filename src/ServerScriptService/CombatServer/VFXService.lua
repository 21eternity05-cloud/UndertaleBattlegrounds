local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local VFXService = {}
VFXService.__index = VFXService

function VFXService.new(config)
	local self = setmetatable({}, VFXService)

	self.Config = config

	local assetsFolder = ReplicatedStorage:FindFirstChild(config.AssetsFolderName or "Assets")
	self.AssetsFolder = assetsFolder

	if assetsFolder then
		self.UniversalFolder = assetsFolder:FindFirstChild(config.UniversalFolderName or "Universal")
		self.CharactersFolder = assetsFolder:FindFirstChild(config.CharactersFolderName or "Characters")
	end

	if not assetsFolder then
		warn("[VFXService] Missing ReplicatedStorage > Assets")
	end

	if not self.UniversalFolder then
		warn("[VFXService] Missing Assets > Universal")
	end

	if not self.CharactersFolder then
		warn("[VFXService] Missing Assets > Characters")
	end

	self.CharacterVFXModules = {}

	return self
end

function VFXService:GetUniversalVFXFolder()
	if not self.UniversalFolder then return nil end
	return self.UniversalFolder:FindFirstChild("VFX")
end

function VFXService:GetUniversalSFXFolder()
	if not self.UniversalFolder then return nil end
	return self.UniversalFolder:FindFirstChild("SFX")
end

function VFXService:GetCharacterFolder(characterName)
	if not self.CharactersFolder then return nil end
	return self.CharactersFolder:FindFirstChild(characterName)
end

function VFXService:GetCharacterSFXFolder(characterName)
	local characterFolder = self:GetCharacterFolder(characterName)
	if not characterFolder then return nil end

	return characterFolder:FindFirstChild("SFX")
end

function VFXService:GetCharacterVFXFolder(characterName)
	local characterFolder = self:GetCharacterFolder(characterName)
	if not characterFolder then return nil end

	return characterFolder:FindFirstChild("VFX")
end

function VFXService:GetCharacterName(character)
	if not character then
		return self.Config.DefaultCharacterName or "Chara"
	end

	local characterName = character:GetAttribute("CharacterName")

	if typeof(characterName) == "string" and characterName ~= "" then
		return characterName
	end

	return self.Config.DefaultCharacterName or "Chara"
end

function VFXService:GetCharacterVFXModule(characterName)
	if self.CharacterVFXModules[characterName] then
		return self.CharacterVFXModules[characterName]
	end

	local characterFolder = self:GetCharacterFolder(characterName)
	if not characterFolder then return nil end

	local modulesFolder = characterFolder:FindFirstChild("Modules")
	if not modulesFolder then return nil end

	local moduleScript = modulesFolder:FindFirstChild("VFXModule")
	if not moduleScript then return nil end

	local module = require(moduleScript).new(self.Config, self)
	self.CharacterVFXModules[characterName] = module

	return module
end

function VFXService:PlaySFXAtPart(soundName, parentPart, lifetime)
	if not parentPart or not parentPart.Parent then return end

	local universalSFX = self:GetUniversalSFXFolder()
	if not universalSFX then return end

	local soundTemplate = universalSFX:FindFirstChild(soundName)
	if not soundTemplate or not soundTemplate:IsA("Sound") then return end

	local sound = soundTemplate:Clone()
	sound.Parent = parentPart
	sound:Play()

	Debris:AddItem(sound, lifetime or 3)
end

function VFXService:PlayCharacterSFXAtPart(characterName, soundName, parentPart, lifetime)
	if not parentPart or not parentPart.Parent then return false end
	if not soundName then return false end

	local soundTemplate = nil

	local characterSFX = self:GetCharacterSFXFolder(characterName)
	if characterSFX then
		soundTemplate = characterSFX:FindFirstChild(soundName)
	end

	if not soundTemplate then
		local universalSFX = self:GetUniversalSFXFolder()
		if universalSFX then
			soundTemplate = universalSFX:FindFirstChild(soundName)
		end
	end

	if not soundTemplate or not soundTemplate:IsA("Sound") then
		return false
	end

	local sound = soundTemplate:Clone()
	sound.Parent = parentPart
	sound:Play()

	Debris:AddItem(sound, lifetime or 3)

	return true
end

function VFXService:EmitParticlesFromAttachment(attachment)
	if not attachment then return end

	for _, descendant in ipairs(attachment:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false

			local emitCount = descendant:GetAttribute("EmitCount")
			if typeof(emitCount) ~= "number" then
				emitCount = 20
			end

			descendant:Emit(emitCount)
		end
	end
end

function VFXService:SetAttachmentEmittersEnabled(attachment, enabled)
	if not attachment then return end

	for _, descendant in ipairs(attachment:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = enabled
		end
	end
end

function VFXService:EmitAttachmentOnPart(attachmentName, parentPart, lifetime)
	if not parentPart or not parentPart.Parent then return end

	local vfxFolder = self:GetUniversalVFXFolder()
	if not vfxFolder then return end

	local template = vfxFolder:FindFirstChild(attachmentName)
	if not template or not template:IsA("Attachment") then return end

	local attachment = template:Clone()
	attachment.Name = attachmentName .. "_Emit"
	attachment.Position = Vector3.new(0, 0, 0)
	attachment.Parent = parentPart

	self:EmitParticlesFromAttachment(attachment)

	Debris:AddItem(attachment, lifetime or 2)
end

function VFXService:EnableAttachmentOnPart(attachmentName, parentPart, lifetime, activeName)
	if not parentPart or not parentPart.Parent then return nil end

	local vfxFolder = self:GetUniversalVFXFolder()
	if not vfxFolder then return nil end

	local template = vfxFolder:FindFirstChild(attachmentName)
	if not template or not template:IsA("Attachment") then return nil end

	local attachment = template:Clone()
	attachment.Name = activeName or (attachmentName .. "_Active")
	attachment.Position = Vector3.new(0, 0, 0)
	attachment.Parent = parentPart

	self:SetAttachmentEmittersEnabled(attachment, true)

	if lifetime then
		task.delay(lifetime, function()
			if attachment and attachment.Parent then
				self:SetAttachmentEmittersEnabled(attachment, false)
			end
		end)

		Debris:AddItem(attachment, lifetime + 1.5)
	end

	return attachment
end

function VFXService:EmitAttachmentAtWorldPosition(attachmentName, position, lifetime, useEnabled)
	local vfxFolder = self:GetUniversalVFXFolder()
	if not vfxFolder then return end

	local template = vfxFolder:FindFirstChild(attachmentName)
	if not template or not template:IsA("Attachment") then return end

	local holder = Instance.new("Part")
	holder.Name = attachmentName .. "_WorldVFXHolder"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanTouch = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.new(1, 1, 1)
	holder.CFrame = CFrame.new(position)
	holder.Parent = workspace

	local attachment = template:Clone()
	attachment.Position = Vector3.new(0, 0, 0)
	attachment.Parent = holder

	if useEnabled then
		self:SetAttachmentEmittersEnabled(attachment, true)

		task.delay(lifetime or 1.25, function()
			if attachment and attachment.Parent then
				self:SetAttachmentEmittersEnabled(attachment, false)
			end
		end)
	else
		self:EmitParticlesFromAttachment(attachment)
	end

	Debris:AddItem(holder, lifetime or 2)
end

function VFXService:StartBlockBillboard(character)
	if not character or not character.Parent then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	if root:FindFirstChild("ActiveBlockBillboard") then return end

	local vfxFolder = self:GetUniversalVFXFolder()
	if not vfxFolder then return end

	local template = vfxFolder:FindFirstChild("BlockShieldBillboard")
	if not template or not template:IsA("BillboardGui") then return end

	local billboard = template:Clone()
	billboard.Name = "ActiveBlockBillboard"
	billboard.Adornee = root
	billboard.Enabled = true
	billboard.Parent = root

	local image = billboard:FindFirstChildWhichIsA("ImageLabel", true)
	if image then
		image.ImageTransparency = 1

		local originalSize = image.Size
		image.Size = UDim2.fromScale(0.65, 0.65)

		TweenService:Create(
			image,
			TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ ImageTransparency = 0 }
		):Play()

		TweenService:Create(
			image,
			TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = originalSize }
		):Play()
	end
end

function VFXService:StopBlockBillboard(character)
	if not character or not character.Parent then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local billboard = root:FindFirstChild("ActiveBlockBillboard")
	if not billboard then return end

	local image = billboard:FindFirstChildWhichIsA("ImageLabel", true)

	if image then
		TweenService:Create(
			image,
			TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ ImageTransparency = 1 }
		):Play()

		task.delay(0.13, function()
			if billboard and billboard.Parent then
				billboard:Destroy()
			end
		end)
	else
		billboard:Destroy()
	end
end

function VFXService:StartBlockVFX(character)
	if not character or not character.Parent then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	if not root:FindFirstChild("ActiveBlockVFX") then
		self:EnableAttachmentOnPart("Block", root, nil, "ActiveBlockVFX")
	end

	self:StartBlockBillboard(character)
end

function VFXService:StopBlockVFX(character)
	if not character or not character.Parent then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local active = root:FindFirstChild("ActiveBlockVFX")
	if active then
		self:SetAttachmentEmittersEnabled(active, false)
		Debris:AddItem(active, 0.75)
	end

	self:StopBlockBillboard(character)
end

function VFXService:EmitHitVFXOnVictim(targetRoot, attackerCharacter)
	if not targetRoot or not targetRoot.Parent then return end

	self:EmitAttachmentOnPart("Hit", targetRoot, 2)

	if attackerCharacter then
		local characterName = self:GetCharacterName(attackerCharacter)
		local hitSound = self.Config.CharacterM1HitSFX and self.Config.CharacterM1HitSFX[characterName]

		if hitSound then
			self:PlayCharacterSFXAtPart(characterName, hitSound, targetRoot, 2)
			return
		end
	end

	self:PlaySFXAtPart("M1Hit", targetRoot, 2)
end

function VFXService:PlayCharacterM1VFX(character, combo, targetCharacter, targetRoot, didHit)
	local characterName = self:GetCharacterName(character)
	local module = self:GetCharacterVFXModule(characterName)

	if module and module.PlayM1 then
		module:PlayM1(character, combo, targetCharacter, targetRoot, didHit)
	end
end

function VFXService:PlayBlockImpact(targetRoot)
	self:PlaySFXAtPart("Block", targetRoot, 2)
end

function VFXService:PlayBlockBreak(targetRoot)
	self:EmitAttachmentOnPart("BlockBreak", targetRoot, 2)
	self:PlaySFXAtPart("BlockBreak", targetRoot, 2)
end

function VFXService:PlayCharacterMoveVFX(character, moveName, targetCharacter, targetRoot)
	local characterName = self:GetCharacterName(character)
	local module = self:GetCharacterVFXModule(characterName)

	if module and module.PlayMove then
		module:PlayMove(character, moveName, targetCharacter, targetRoot)
	end
end

return VFXService
