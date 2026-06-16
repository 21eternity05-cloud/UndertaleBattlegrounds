local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CharacterData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CharacterData"))

local CharacterService = {}
CharacterService.__index = CharacterService

function CharacterService.new(config, weaponService, progressionService, characterMorphService)
	local self = setmetatable({}, CharacterService)

	self.Config = config
	self.WeaponService = weaponService
	self.ProgressionService = progressionService
	self.CharacterMorphService = characterMorphService
	self.CombatStatusService = nil
	self.CharacterIntroService = nil
	self.SpawnService = nil
	self.StateService = nil

	return self
end

function CharacterService:IsPlayerRequestInCombat(player)
	local character = player and player.Character

	if not character then
		return false
	end

	if self.CombatStatusService and self.CombatStatusService.IsInCombat then
		return self.CombatStatusService:IsInCombat(character)
	end

	if os.clock() < (character:GetAttribute("CombatTaggedUntil") or 0) then
		return true
	end

	return character:GetAttribute("Stunned") == true
		or character:GetAttribute("Guardbroken") == true
		or character:GetAttribute("Blocking") == true
		or character:GetAttribute("Attacking") == true
		or character:GetAttribute("UsingMove") == true
		or character:GetAttribute("Grabbed") == true
		or character:GetAttribute("CinematicLocked") == true
		or character:GetAttribute("SpawnSetupActive") == true
		or character:GetAttribute("CharacterSwitchDebounce") == true
		or character:GetAttribute("Morphing") == true
		or character:GetAttribute("IntroLocked") == true
end

function CharacterService:GetNotificationRemote()
	if self.NotificationRemote then
		return self.NotificationRemote
	end

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	local remote = remotes:FindFirstChild("NotificationRemote")
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "NotificationRemote"
		remote.Parent = remotes
	end

	self.NotificationRemote = remote
	return remote
end

function CharacterService:NotifyPlayer(player, message)
	local remote = self:GetNotificationRemote()

	remote:FireClient(player, {
		Action = "Show",
		Text = message,
		Duration = 2.5,
	})
end

function CharacterService:IsValidCharacter(characterName)
	if CharacterData[characterName] then
		return true
	end

	return self.Config.ValidCharacters and self.Config.ValidCharacters[characterName] == true
end

function CharacterService:IsCharacterUnlocked(player, characterName)
	if not self:IsValidCharacter(characterName) then
		return false
	end

	if self.ProgressionService and self.ProgressionService.IsCharacterUnlocked then
		return self.ProgressionService:IsCharacterUnlocked(player, characterName)
	end

	local data = CharacterData[characterName]
	return not data or data.Free == true or (data.Cost or 0) <= 0
end

function CharacterService:GetCharacterName(player)
	local characterName = player:GetAttribute("CharacterName")

	if typeof(characterName) == "string" and self:IsValidCharacter(characterName) then
		return characterName
	end

	return self.Config.DefaultCharacterName or "Chara"
end

function CharacterService:GetDefaultSkin(characterName)
	local skinConfig = self:GetSkinConfig(characterName)

	if skinConfig and skinConfig.DefaultSkin then
		return skinConfig.DefaultSkin
	end

	return "Default"
end

function CharacterService:GetSkinConfig(characterName)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local characters = assets and assets:FindFirstChild("Characters")
	local characterFolder = characters and characters:FindFirstChild(characterName)
	local modulesFolder = characterFolder and characterFolder:FindFirstChild("Modules")
	local skinModule = modulesFolder and modulesFolder:FindFirstChild("SkinModule")

	if not skinModule then
		return nil
	end

	local success, skinConfig = pcall(require, skinModule)
	if not success or typeof(skinConfig) ~= "table" then
		warn("[CharacterService] Failed to load SkinModule:", tostring(characterName))
		return nil
	end

	return skinConfig
end

function CharacterService:GetValidSkinName(player, characterName, skinName)
	local skinConfig = self:GetSkinConfig(characterName)
	local defaultSkinName = (skinConfig and skinConfig.DefaultSkin) or "Default"

	if typeof(skinName) == "string" and skinConfig and skinConfig.Skins and skinConfig.Skins[skinName] then
		if not self.ProgressionService or not self.ProgressionService.IsSkinOwned then
			local skinData = skinConfig.Skins[skinName]
			if skinData.Free == true or (skinData.Cost or 0) <= 0 then
				return skinName
			end
		elseif self.ProgressionService:IsSkinOwned(player, characterName, skinName) then
			return skinName
		end
	end

	return defaultSkinName
end

function CharacterService:NormalizeCharacterOptions(player, characterName, options)
	if typeof(options) ~= "table" then
		options = {}
	end

	local skinName = options.SkinName

	if typeof(skinName) ~= "string" or skinName == "" then
		if self.ProgressionService and self.ProgressionService.GetEquippedSkin then
			skinName = self.ProgressionService:GetEquippedSkin(player, characterName)
		else
			skinName = self:GetDefaultSkin(characterName)
		end
	end

	skinName = self:GetValidSkinName(player, characterName, skinName)

	local requestedMorphEnabled = options.MorphEnabled == true

	return {
		SkinName = skinName,
		RequestedMorphEnabled = requestedMorphEnabled,
		MorphEnabled = requestedMorphEnabled or player:GetAttribute("Setting_MorphAlways") == true,
	}
end

function CharacterService:ApplyCharacterAttributes(player, character, characterName, options)
	player:SetAttribute("CharacterName", characterName)
	player:SetAttribute("MorphEnabled", options.RequestedMorphEnabled == true)

	if options.SkinName then
		player:SetAttribute("SelectedSkin", options.SkinName)
		player:SetAttribute("EquippedSkin_" .. characterName, options.SkinName)
	end

	if characterName == "Chara" then
		player:SetAttribute("CharaSkin", options.SkinName or "Default")
	end

	if character then
		character:SetAttribute("CharacterName", characterName)
		character:SetAttribute("MorphEnabled", options.MorphEnabled == true)
		character:SetAttribute("CombatMode", "Base")
		character:SetAttribute("AwakeningActive", false)
		character:SetAttribute("AwakeningEndsAt", 0)

		if options.SkinName then
			character:SetAttribute("SelectedSkin", options.SkinName)
			character:SetAttribute("EquippedSkin_" .. characterName, options.SkinName)
		end

		if characterName == "Chara" then
			character:SetAttribute("CharaSkin", options.SkinName or "Default")
		end
	end
end

function CharacterService:GetCurrentOptions(player, characterName)
	local skinName = player:GetAttribute("EquippedSkin_" .. characterName)

	if not skinName and self.ProgressionService and self.ProgressionService.GetEquippedSkin then
		skinName = self.ProgressionService:GetEquippedSkin(player, characterName)
	end

	return self:NormalizeCharacterOptions(player, characterName, {
		SkinName = skinName,
		MorphEnabled = player:GetAttribute("MorphEnabled") == true,
	})
end

function CharacterService:PlayCharacterIntro(player, character, characterName)
	if not self.CharacterIntroService then
		return
	end
	if not self.CharacterIntroService.PlayCharacterSwitchIntro then
		return
	end

	self.CharacterIntroService:PlayCharacterSwitchIntro(player, characterName, character)
end

function CharacterService:GetCharacterRoot(character)
	if not character or not character:IsA("Model") then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
		or character:FindFirstChild("Torso")
		or character:FindFirstChild("UpperTorso")
		or character.PrimaryPart
end

function CharacterService:ZeroCharacterVelocity(character)
	local root = self:GetCharacterRoot(character)
	if not root or not root:IsA("BasePart") then
		return
	end

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

function CharacterService:WaitForSpawnParts(character)
	local humanoid = character:WaitForChild("Humanoid", 8)
	local root = character:WaitForChild("HumanoidRootPart", 8)

	if humanoid and humanoid.RigType == Enum.HumanoidRigType.R6 then
		character:WaitForChild("Torso", 4)
	end

	if not humanoid or not root then
		return nil, nil
	end

	return humanoid, root
end

function CharacterService:SetSetupLock(character, enabled)
	if not character or not character.Parent then
		return
	end

	character:SetAttribute("SpawnSetupActive", enabled == true)
	character:SetAttribute("CharacterSwitchDebounce", enabled == true)
	character:SetAttribute("IntroLocked", enabled == true)
	character:SetAttribute("MovementLocked", enabled == true)
	character:SetAttribute("DashLocked", enabled == true)

	if enabled == true then
		character:SetAttribute("Attacking", false)
		character:SetAttribute("BlockHeld", false)
		character:SetAttribute("Blocking", false)
	end
end

function CharacterService:BeginCharacterSetupLock(character)
	self:SetSetupLock(character, true)
end

function CharacterService:IsCharacterSetupLocked(character)
	if not character or not character.Parent then
		return false
	end

	return character:GetAttribute("SpawnSetupActive") == true
		or character:GetAttribute("CharacterSwitchDebounce") == true
		or character:GetAttribute("Morphing") == true
		or character:GetAttribute("IntroLocked") == true
end

function CharacterService:ClearSetupLock(character, humanoid)
	if not character or not character.Parent then
		return
	end

	character:SetAttribute("SpawnSetupActive", false)
	character:SetAttribute("CharacterSwitchDebounce", false)
	character:SetAttribute("Morphing", false)
	character:SetAttribute("IntroLocked", false)
	character:SetAttribute("MovementLocked", false)
	character:SetAttribute("DashLocked", false)

	local currentHumanoid = humanoid
	if not currentHumanoid or not currentHumanoid.Parent then
		currentHumanoid = character:FindFirstChildOfClass("Humanoid")
	end

	if currentHumanoid
		and currentHumanoid.Parent
		and currentHumanoid.Health > 0
		and character:GetAttribute("Stunned") ~= true
		and character:GetAttribute("Guardbroken") ~= true
		and character:GetAttribute("UsingMove") ~= true
		and character:GetAttribute("Blocking") ~= true
	then
		currentHumanoid.WalkSpeed = self.Config.DefaultWalkSpeed
		currentHumanoid.JumpPower = self.Config.DefaultJumpPower
		currentHumanoid.JumpHeight = self.Config.DefaultJumpHeight
		currentHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	end
end

function CharacterService:EndCharacterSetupLock(character, humanoid)
	self:ClearSetupLock(character, humanoid)
end

function CharacterService:PrepareIntroHandoff(character)
	if not character or not character.Parent then
		return
	end

	character:SetAttribute("MovementLocked", false)
	character:SetAttribute("DashLocked", false)
	character:SetAttribute("Attacking", false)
	character:SetAttribute("BlockHeld", false)
	character:SetAttribute("Blocking", false)
end

function CharacterService:WaitForAppearanceStable(player, character, timeout)
	if not player or not character or not character.Parent then
		return
	end

	timeout = timeout or 1.5
	local loaded = false
	local connection = nil

	connection = player.CharacterAppearanceLoaded:Connect(function(loadedCharacter)
		if loadedCharacter == character then
			loaded = true
		end
	end)

	local startTime = os.clock()
	while not loaded and character.Parent and player.Character == character and os.clock() - startTime < timeout do
		RunService.Heartbeat:Wait()
	end

	if connection then
		connection:Disconnect()
	end

	RunService.Heartbeat:Wait()
end

function CharacterService:CharacterHasMorphItems(character)
	if not character or not self.CharacterMorphService or not self.CharacterMorphService.IsMorphItem then
		return false
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		if self.CharacterMorphService:IsMorphItem(descendant) then
			return true
		end
	end

	return false
end

function CharacterService:ApplyCharacterVisualPipeline(player, character, characterName, options)
	self:ApplyCharacterAttributes(player, character, characterName, options)

	if self.CharacterMorphService then
		character:SetAttribute("Morphing", true)

		local ok, err = pcall(function()
			if options.MorphEnabled then
				self.CharacterMorphService:ApplyCharacterMorph(
					player,
					character,
					characterName,
					options.SkinName,
					options.MorphEnabled
				)
			elseif self.CharacterMorphService.ClearMorphItemsOnly and self:CharacterHasMorphItems(character) then
				self.CharacterMorphService:ClearMorphItemsOnly(character)

				if self.CharacterMorphService.NeedsAvatarRestore
					and self.CharacterMorphService:NeedsAvatarRestore(character)
					and self.CharacterMorphService.RestoreOriginalAppearance
				then
					self.CharacterMorphService:RestoreOriginalAppearance(player, character)
				end
			end
		end)

		character:SetAttribute("Morphing", false)

		if not ok then
			error(err)
		end
	end

	if self.WeaponService then
		self.WeaponService:EquipWeapon(character, characterName)
	end

	self:ApplyEquippedTitleAfterCharacterVisuals(player, character)

	if self.CharacterMorphService and self.CharacterMorphService.ApplyCharacterCollisionRules then
		self.CharacterMorphService:ApplyCharacterCollisionRules(character)
	end
end

function CharacterService:PlayCharacterIntroAndWait(player, character, characterName)
	self:PrepareIntroHandoff(character)
	self:PlayCharacterIntro(player, character, characterName)

	RunService.Heartbeat:Wait()

	local deadline = os.clock() + 3
	while character
		and character.Parent
		and character:GetAttribute("CharacterSwitchIntroActive") == true
		and os.clock() < deadline
	do
		task.wait(0.05)
	end
end

function CharacterService:ApplyEquippedTitleAfterCharacterVisuals(player, character)
	if not self.ProgressionService or not self.ProgressionService.ApplyEquippedTitleToCharacter then
		return
	end

	task.defer(function()
		task.wait(0.1)

		if character and character.Parent and player.Character == character then
			self.ProgressionService:ApplyEquippedTitleToCharacter(player, character)

			if self.WeaponService and self.WeaponService.SanitizeEquippedWeapons then
				self.WeaponService:SanitizeEquippedWeapons(character)
			end
		end
	end)
end

function CharacterService:SetCharacter(player, characterName, options)
	if typeof(characterName) ~= "string" then return end
	if not self:IsValidCharacter(characterName) then
		warn("Invalid character:", characterName)
		return
	end

	if not self:IsCharacterUnlocked(player, characterName) then
		warn("[CharacterService] Locked character select rejected:", player.Name, characterName)

		if self.ProgressionService and self.ProgressionService.SendSnapshot then
			self.ProgressionService:SendSnapshot(player)
		end

		return
	end

	if self:IsPlayerRequestInCombat(player) then
		warn("[CharacterService] Character switch rejected while in combat:", player.Name, characterName)
		self:NotifyPlayer(player, "Combat tagged: cannot switch characters.")
		return false
	end

	local character = player.Character
	if character
		and (
			character:GetAttribute("SpawnSetupActive") == true
			or character:GetAttribute("CharacterSwitchDebounce") == true
			or character:GetAttribute("Morphing") == true
			or character:GetAttribute("IntroLocked") == true
		)
	then
		self:NotifyPlayer(player, "Character setup in progress.")
		return false
	end

	if options == nil then
		options = self:GetCurrentOptions(player, characterName)
	else
		options = self:NormalizeCharacterOptions(player, characterName, options)

		if self.ProgressionService and self.ProgressionService.EquipSkin then
			self.ProgressionService:EquipSkin(player, characterName, options.SkinName)
		end
	end

	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		character:SetAttribute("CharacterSwitchDebounce", true)
		character:SetAttribute("IntroLocked", true)

		local ok, err = pcall(function()
			self:ZeroCharacterVelocity(character)
			RunService.Heartbeat:Wait()
			self:WaitForAppearanceStable(player, character, 0.1)
			self:ApplyCharacterVisualPipeline(player, character, characterName, options)
			self:ZeroCharacterVelocity(character)
			RunService.Heartbeat:Wait()
			self:PlayCharacterIntroAndWait(player, character, characterName)
		end)

		self:EndCharacterSetupLock(character, humanoid)

		if not ok then
			warn("[CharacterService] Character switch setup failed:", err)
			return false
		end
	else
		self:ApplyCharacterAttributes(player, nil, characterName, options)
	end

	print(player.Name .. " changed character to " .. characterName)
	return true
end

function CharacterService:RunSpawnSetup(player, character)
	if character and character.Parent then
		character:SetAttribute("SpawnServiceHandledByCharacterService", true)
	end

	local humanoid, root = self:WaitForSpawnParts(character)
	if not humanoid or not root then
		return
	end

	if self.StateService and self.StateService.SetupCharacter then
		self.StateService:SetupCharacter(character)
	end

	self:BeginCharacterSetupLock(character)

	local token = (character:GetAttribute("SpawnSetupToken") or 0) + 1
	character:SetAttribute("SpawnSetupToken", token)

	local cleanedUp = false
	local function cleanup()
		if cleanedUp then
			return
		end
		cleanedUp = true
		self:EndCharacterSetupLock(character, humanoid)
	end

	task.delay(8, function()
		if character
			and character.Parent
			and character:GetAttribute("SpawnSetupToken") == token
			and character:GetAttribute("SpawnSetupActive") == true
		then
			warn("[CharacterService] Spawn setup failsafe unlocked:", player.Name)
			cleanup()
		end
	end)

	local ok, err = pcall(function()
		if self.SpawnService and self.SpawnService.TeleportToSpawn then
			self.SpawnService:TeleportToSpawn(player, character)
			if self.SpawnService.ApplySpawnProtection then
				self.SpawnService:ApplySpawnProtection(character, self.Config.SpawnIFrameDuration or 3)
			end
		end

		self:ZeroCharacterVelocity(character)
		RunService.Heartbeat:Wait()

		local characterName = self:GetCharacterName(player)
		local options = self:GetCurrentOptions(player, characterName)

		self:WaitForAppearanceStable(player, character, options.MorphEnabled and 1.75 or 0.5)
		self:ApplyCharacterVisualPipeline(player, character, characterName, options)

		self:ZeroCharacterVelocity(character)
		RunService.Heartbeat:Wait()
		task.wait(0.08)

		self:PlayCharacterIntroAndWait(player, character, characterName)
		self:ZeroCharacterVelocity(character)
	end)

	if not ok then
		warn("[CharacterService] Spawn setup failed:", player.Name, err)
	end

	cleanup()
end

function CharacterService:SetupPlayer(player)
	if not player:GetAttribute("CharacterName") then
		player:SetAttribute("CharacterName", self.Config.DefaultCharacterName or "Chara")
	end

	player.CharacterAdded:Connect(function(character)
		self:RunSpawnSetup(player, character)
	end)
end

function CharacterService:Start()
	self:GetNotificationRemote()

	Players.PlayerAdded:Connect(function(player)
		self:SetupPlayer(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:SetupPlayer(player)

		if player.Character then
			player.Character:SetAttribute("SpawnServiceHandledByCharacterService", true)
			task.spawn(function()
				self:RunSpawnSetup(player, player.Character)
			end)
		end
	end
end

return CharacterService
