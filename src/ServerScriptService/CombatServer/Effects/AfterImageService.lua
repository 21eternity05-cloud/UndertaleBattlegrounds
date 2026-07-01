local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AfterImageService = {}
AfterImageService.__index = AfterImageService

local DEFAULT_AFTERIMAGE = {
	Lifetime = 0.35,
	FadeTime = 0.25,
	Transparency = 0.58,
	UseUltColor = true,
	Material = Enum.Material.Neon,
	MaxParts = 14,
	IncludeWeapons = false,
}

local INTERNAL_OPTION_KEYS = {
	Character = true,
	CharacterName = true,
	PresetName = true,
}

local function mergeInto(target, source)
	if typeof(source) ~= "table" then
		return target
	end

	for key, value in pairs(source) do
		target[key] = value
	end

	return target
end

local function stripInternalOptions(options)
	local cleaned = {}

	for key, value in pairs(options or {}) do
		if not INTERNAL_OPTION_KEYS[key] then
			cleaned[key] = value
		end
	end

	return cleaned
end

function AfterImageService.new(config)
	local self = setmetatable({}, AfterImageService)

	self.Config = config or {}
	self.RuntimeFolderName = self.Config.AfterImageFolderName or "VFX"
	self.CharactersFolder = nil
	self.PresetModules = {}
	self.ActiveTrails = {}

	local assets = ReplicatedStorage:FindFirstChild(self.Config.AssetsFolderName or "Assets")
	if assets then
		self.CharactersFolder = assets:FindFirstChild(self.Config.CharactersFolderName or "Characters")
	end

	return self
end

function AfterImageService:GetRuntimeFolder()
	local folder = workspace:FindFirstChild(self.RuntimeFolderName)

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = self.RuntimeFolderName
		folder.Parent = workspace
	end

	return folder
end

function AfterImageService:GetCharacterName(characterOrName)
	if typeof(characterOrName) == "string" and characterOrName ~= "" then
		return characterOrName
	end

	if typeof(characterOrName) == "Instance" and characterOrName:IsA("Model") then
		local characterName = characterOrName:GetAttribute("CharacterName")
		if typeof(characterName) == "string" and characterName ~= "" then
			return characterName
		end
	end

	return self.Config.DefaultCharacterName or "Chara"
end

function AfterImageService:GetCharacterVFXFolder(characterName)
	if not self.CharactersFolder then
		return nil
	end

	local characterFolder = self.CharactersFolder:FindFirstChild(characterName)
	return characterFolder and characterFolder:FindFirstChild("VFX") or nil
end

function AfterImageService:GetPresetModule(characterName)
	if self.PresetModules[characterName] ~= nil then
		return self.PresetModules[characterName]
	end

	local vfxFolder = self:GetCharacterVFXFolder(characterName)
	local moduleScript = vfxFolder and vfxFolder:FindFirstChild("VFXPresets")

	if not moduleScript or not moduleScript:IsA("ModuleScript") then
		self.PresetModules[characterName] = false
		return nil
	end

	local ok, result = pcall(require, moduleScript)
	if not ok or typeof(result) ~= "table" then
		warn("[AfterImageService] Failed to require VFXPresets for", characterName, result)
		self.PresetModules[characterName] = false
		return nil
	end

	self.PresetModules[characterName] = result
	return result
end

function AfterImageService:GetCharacterColor(characterOrName)
	local characterName = self:GetCharacterName(characterOrName)
	local vfxFolder = self:GetCharacterVFXFolder(characterName)

	for _, valueName in ipairs({ "UltColor", "SoulColor", "HeartColor" }) do
		local object = vfxFolder and vfxFolder:FindFirstChild(valueName)
		if object and object:IsA("Color3Value") then
			return object.Value
		end
	end

	return Color3.fromRGB(255, 55, 80)
end

function AfterImageService:ResolvePreset(characterOrName, presetName, options)
	options = options or {}
	local character = options.Character or (typeof(characterOrName) == "Instance" and characterOrName:IsA("Model") and characterOrName or nil)
	local characterName = self:GetCharacterName(character or options.CharacterName or characterOrName)
	local presetModule = self:GetPresetModule(characterName)
	local afterImages = presetModule and presetModule.AfterImages
	local defaultPreset = afterImages and afterImages.Default
	local namedPreset = afterImages and afterImages[presetName or "Default"]

	local resolved = {}
	mergeInto(resolved, DEFAULT_AFTERIMAGE)
	mergeInto(resolved, defaultPreset)
	mergeInto(resolved, namedPreset)
	mergeInto(resolved, stripInternalOptions(options))

	if resolved.UseUltColor == true and not resolved.Color then
		resolved.Color = self:GetCharacterColor(character or characterName)
	end

	return resolved
end

function AfterImageService:IsWeaponPart(part)
	if part:GetAttribute("WeaponVisual") == true
		or part:GetAttribute("EquippedWeapon") == true
		or part:GetAttribute("CharacterWeapon") == true
	then
		return true
	end

	for _, ancestorName in ipairs({ "RealKnife", "EquippedKnife", "EquippedWeapon", "EquippedWeapons" }) do
		if part:FindFirstAncestor(ancestorName) then
			return true
		end
	end

	return false
end

function AfterImageService:PrepareGhostPart(sourcePart, options)
	local ghost = sourcePart:Clone()

	for _, descendant in ipairs(ghost:GetDescendants()) do
		if not descendant:IsA("SpecialMesh") then
			descendant:Destroy()
		end
	end

	ghost.Name = "AfterImagePart"
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.CanTouch = false
	ghost.CanQuery = false
	ghost.Massless = true
	ghost.CastShadow = false
	ghost.Material = options.Material or DEFAULT_AFTERIMAGE.Material
	ghost.Color = options.Color or sourcePart.Color
	ghost.Transparency = options.Transparency or DEFAULT_AFTERIMAGE.Transparency
	ghost.CFrame = sourcePart.CFrame

	if ghost:IsA("MeshPart") then
		ghost.TextureID = ""
	end

	return ghost
end

function AfterImageService:SpawnAfterImage(character, options)
	if not character or not character.Parent then
		return nil
	end

	options = options or {}
	local presetName = options.PresetName or options.Preset or "Default"
	local resolved = self:ResolvePreset(character, presetName, options)
	local folder = Instance.new("Folder")
	folder.Name = "AfterImage"
	folder.Parent = self:GetRuntimeFolder()

	local maxParts = math.max(1, resolved.MaxParts or DEFAULT_AFTERIMAGE.MaxParts)
	local count = 0

	for _, descendant in ipairs(character:GetDescendants()) do
		if count >= maxParts then
			break
		end

		if descendant:IsA("BasePart")
			and descendant.Name ~= "HumanoidRootPart"
			and descendant.Transparency < 1
			and (resolved.IncludeWeapons == true or not self:IsWeaponPart(descendant))
		then
			count += 1
			local ghost = self:PrepareGhostPart(descendant, resolved)
			ghost.Parent = folder

			TweenService:Create(
				ghost,
				TweenInfo.new(resolved.FadeTime or DEFAULT_AFTERIMAGE.FadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Transparency = 1 }
			):Play()
		end
	end

	Debris:AddItem(folder, (resolved.Lifetime or DEFAULT_AFTERIMAGE.Lifetime) + 0.08)
	return folder
end

function AfterImageService:StartTrail(character, options)
	if not character or not character.Parent then
		return nil
	end

	options = options or {}
	local handle = {
		Active = true,
		Character = character,
		Connections = {},
	}

	self.ActiveTrails[handle] = true

	local function stop()
		self:StopTrail(handle)
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		table.insert(handle.Connections, humanoid.Died:Connect(stop))
	end

	table.insert(handle.Connections, character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			stop()
		end
	end))

	task.spawn(function()
		while handle.Active and character.Parent do
			self:SpawnAfterImage(character, options)
			task.wait(options.Interval or 0.08)
		end
	end)

	return handle
end

function AfterImageService:StopTrail(handle)
	if not handle or handle.Active == false then
		return
	end

	handle.Active = false
	self.ActiveTrails[handle] = nil

	for _, connection in ipairs(handle.Connections or {}) do
		connection:Disconnect()
	end

	table.clear(handle.Connections or {})
end

function AfterImageService:StopAllForCharacter(character)
	for handle in pairs(self.ActiveTrails) do
		if handle.Character == character then
			self:StopTrail(handle)
		end
	end
end

return AfterImageService
