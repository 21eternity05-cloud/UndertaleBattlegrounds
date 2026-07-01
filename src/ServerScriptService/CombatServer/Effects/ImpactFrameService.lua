local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ImpactFrameService = {}
ImpactFrameService.__index = ImpactFrameService

local DEFAULT_IMPACT_FRAME = {
	Duration = 0.1,
	TintColor = Color3.fromRGB(255, 255, 255),
	Brightness = 1,
	UseUltColor = true,
	VictimColor = Color3.fromRGB(0, 0, 0),
	AttackerFillTransparency = 0,
	VictimFillTransparency = 0,
	OutlineTransparency = 1,
	Contrast = 0,
	Saturation = 0,
	Radius = 70,
}

local INTERNAL_OPTION_KEYS = {
	Character = true,
	CharacterName = true,
	Attacker = true,
	Victim = true,
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

function ImpactFrameService.new(config)
	local self = setmetatable({}, ImpactFrameService)

	self.Config = config or {}
	self.Remote = nil
	self.CharactersFolder = nil
	self.PresetModules = {}

	local assets = ReplicatedStorage:FindFirstChild(self.Config.AssetsFolderName or "Assets")
	if assets then
		self.CharactersFolder = assets:FindFirstChild(self.Config.CharactersFolderName or "Characters")
	end

	return self
end

function ImpactFrameService:GetRemote()
	if self.Remote then
		return self.Remote
	end

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local remote = remotes:FindFirstChild("CinematicRemote")

	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "CinematicRemote"
		remote.Parent = remotes
	end

	self.Remote = remote
	return remote
end

function ImpactFrameService:GetCharacterName(characterOrName)
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

function ImpactFrameService:GetCharacterVFXFolder(characterName)
	if not self.CharactersFolder then
		return nil
	end

	local characterFolder = self.CharactersFolder:FindFirstChild(characterName)
	return characterFolder and characterFolder:FindFirstChild("VFX") or nil
end

function ImpactFrameService:GetPresetModule(characterName)
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
		warn("[ImpactFrameService] Failed to require VFXPresets for", characterName, result)
		self.PresetModules[characterName] = false
		return nil
	end

	self.PresetModules[characterName] = result
	return result
end

function ImpactFrameService:GetCharacterColor(characterOrName)
	local characterName = self:GetCharacterName(characterOrName)
	local vfxFolder = self:GetCharacterVFXFolder(characterName)

	for _, valueName in ipairs({ "UltColor", "SoulColor", "HeartColor" }) do
		local object = vfxFolder and vfxFolder:FindFirstChild(valueName)
		if object and object:IsA("Color3Value") then
			return object.Value
		end
	end

	if typeof(characterOrName) == "Instance" and characterOrName:IsA("Model") then
		local attributeColor = characterOrName:GetAttribute("HeartColor")
		if typeof(attributeColor) == "Color3" then
			return attributeColor
		end
	end

	return Color3.fromRGB(255, 55, 80)
end

function ImpactFrameService:ResolvePreset(characterOrName, presetName, options)
	options = options or {}
	local attacker = options.Attacker or options.Character or (typeof(characterOrName) == "Instance" and characterOrName:IsA("Model") and characterOrName or nil)
	local victim = options.Victim
	local characterName = self:GetCharacterName(attacker or options.CharacterName or characterOrName)
	local presetModule = self:GetPresetModule(characterName)
	local characterPreset = presetModule
		and presetModule.ImpactFrames
		and presetModule.ImpactFrames[presetName or "Default"]

	local resolved = {}
	mergeInto(resolved, DEFAULT_IMPACT_FRAME)
	mergeInto(resolved, characterPreset)
	mergeInto(resolved, stripInternalOptions(options))

	if resolved.UseUltColor == true then
		local color = self:GetCharacterColor(attacker or characterName)
		if options.AttackerColor == nil then
			resolved.AttackerColor = color
		end
		if options.HighlightColor == nil then
			resolved.HighlightColor = color
		end
	end

	resolved.Attacker = attacker
	resolved.Victim = victim

	return resolved
end

function ImpactFrameService:PlayForPlayer(player, presetName, options)
	if not player then
		return
	end

	local character = (options and options.Character) or player.Character
	local resolved = self:ResolvePreset(character, presetName, options)

	self:GetRemote():FireClient(player, {
		Action = "ImpactFrame",
		Preset = presetName,
		Options = resolved,
	})
end

function ImpactFrameService:PlayForCharacter(character, presetName, options)
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	options = options or {}
	options.Character = options.Character or character
	self:PlayForPlayer(player, presetName, options)
end

function ImpactFrameService:PlayForSubjects(attackerCharacter, victimCharacter, presetName, options)
	options = options or {}
	options.Attacker = attackerCharacter
	options.Victim = victimCharacter
	options.Character = attackerCharacter

	local players = {}
	local attackerPlayer = attackerCharacter and Players:GetPlayerFromCharacter(attackerCharacter)
	local victimPlayer = victimCharacter and Players:GetPlayerFromCharacter(victimCharacter)

	if attackerPlayer then
		table.insert(players, attackerPlayer)
	end

	if victimPlayer and victimPlayer ~= attackerPlayer then
		table.insert(players, victimPlayer)
	end

	for _, player in ipairs(players) do
		self:PlayForPlayer(player, presetName, options)
	end
end

function ImpactFrameService:PlayForPlayers(players, presetName, options)
	if typeof(players) ~= "table" then
		return
	end

	for _, player in ipairs(players) do
		self:PlayForPlayer(player, presetName, options)
	end
end

function ImpactFrameService:PlayRadius(position, radius, presetName, options)
	if typeof(position) ~= "Vector3" then
		return
	end

	options = options or {}
	radius = radius or options.Radius or DEFAULT_IMPACT_FRAME.Radius

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")

		if root and (root.Position - position).Magnitude <= radius then
			local playerOptions = table.clone(options)
			playerOptions.Character = options.Character or character
			playerOptions.Radius = radius
			self:PlayForPlayer(player, presetName, playerOptions)
		end
	end
end

return ImpactFrameService
