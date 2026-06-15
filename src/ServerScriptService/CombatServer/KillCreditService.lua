local Players = game:GetService("Players")

local KillCreditService = {}
KillCreditService.__index = KillCreditService

function KillCreditService.new(config, progressionService, combatStatusService, vfxService)
	local self = setmetatable({}, KillCreditService)

	self.Config = config
	self.ProgressionService = progressionService
	self.CombatStatusService = combatStatusService
	self.VFXService = vfxService
	self.SetupCharacters = setmetatable({}, { __mode = "k" })
	self.AwardedCharacters = setmetatable({}, { __mode = "k" })
	self.LastHealthByHumanoid = setmetatable({}, { __mode = "k" })

	return self
end

function KillCreditService:IsTestDummy(character)
	if not character then
		return false
	end

	if character:GetAttribute("TestDummy") == true
		or character:GetAttribute("RespawnDummy") == true
		or character:GetAttribute("ComboDummy") == true
		or character:GetAttribute("AirComboDummy") == true
		or character:GetAttribute("BlockDummy") == true
	then
		return true
	end

	local testDummies = workspace:FindFirstChild("TestDummies")
	if testDummies and character:IsDescendantOf(testDummies) then
		return true
	end

	return false
end

function KillCreditService:GetHumanoid(character)
	if not character or not character.Parent then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

function KillCreditService:GetPlayer(character)
	if not character then
		return nil
	end

	return Players:GetPlayerFromCharacter(character)
end

function KillCreditService:GetOrCreateLastAttacker(victimCharacter)
	if not victimCharacter then
		return nil
	end

	local value = victimCharacter:FindFirstChild("LastAttacker")

	if not value then
		value = Instance.new("ObjectValue")
		value.Name = "LastAttacker"
		value.Parent = victimCharacter
	end

	return value
end

function KillCreditService:GetLastAttacker(victimCharacter)
	local value = victimCharacter and victimCharacter:FindFirstChild("LastAttacker")

	if value and value:IsA("ObjectValue") then
		return value.Value
	end

	return nil
end

function KillCreditService:IsRecentDamage(victimCharacter, window)
	local lastDamageTime = victimCharacter and victimCharacter:GetAttribute("LastDamageTime") or 0

	if typeof(lastDamageTime) ~= "number" or lastDamageTime <= 0 then
		return false
	end

	return os.clock() - lastDamageTime <= window
end

function KillCreditService:IsCombatTagged(character)
	if not character or not character.Parent then
		return false
	end

	return os.clock() < (character:GetAttribute("CombatTaggedUntil") or 0)
end

function KillCreditService:IsValidAttacker(attackerCharacter, victimCharacter)
	if not attackerCharacter or not attackerCharacter.Parent then
		return false
	end
	if not victimCharacter or not victimCharacter.Parent then
		return false
	end
	if attackerCharacter == victimCharacter then
		return false
	end

	local attackerPlayer = self:GetPlayer(attackerCharacter)
	if not attackerPlayer then
		return false
	end

	local attackerHumanoid = self:GetHumanoid(attackerCharacter)
	if not attackerHumanoid or attackerHumanoid.Health <= 0 then
		return false
	end

	return true
end

function KillCreditService:RecordDamage(attackerCharacter, victimCharacter, damage, source)
	if not attackerCharacter or not victimCharacter then return end
	if attackerCharacter == victimCharacter then return end
	if typeof(damage) ~= "number" or damage <= 0 then return end

	local attackerPlayer = self:GetPlayer(attackerCharacter)
	local victimPlayer = self:GetPlayer(victimCharacter)
	if not attackerPlayer or not victimPlayer then
		return
	end

	local attackerHumanoid = self:GetHumanoid(attackerCharacter)
	local victimHumanoid = self:GetHumanoid(victimCharacter)
	if not attackerHumanoid or attackerHumanoid.Health <= 0 then return end
	if not victimHumanoid then return end

	local lastAttacker = self:GetOrCreateLastAttacker(victimCharacter)
	if lastAttacker then
		lastAttacker.Value = attackerCharacter
	end

	victimCharacter:SetAttribute("LastDamageTime", os.clock())
	victimCharacter:SetAttribute("LastDamageByUserId", attackerPlayer.UserId)
	victimCharacter:SetAttribute("LastDamageSource", source or "Unknown")

	if self.CombatStatusService and self.CombatStatusService.TagCombatPair then
		self.CombatStatusService:TagCombatPair(attackerCharacter, victimCharacter)
	end
end

function KillCreditService:ApplyHealOnKill(attackerCharacter)
	local healAmount = self.Config.HealOnKillAmount or 0
	if healAmount <= 0 then return end

	local humanoid = self:GetHumanoid(attackerCharacter)
	if not humanoid or humanoid.Health <= 0 then return end

	local oldHealth = humanoid.Health
	attackerCharacter:SetAttribute("AllowCombatHealUntil", os.clock() + 0.2)
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + healAmount)
	self.LastHealthByHumanoid[humanoid] = humanoid.Health

	if humanoid.Health > oldHealth then
		local root = attackerCharacter:FindFirstChild("HumanoidRootPart")
			or attackerCharacter:FindFirstChild("Torso")
			or attackerCharacter:FindFirstChild("UpperTorso")

		if root and self.VFXService and self.VFXService.PlayCharacterSFXAtPart then
			self.VFXService:PlayCharacterSFXAtPart("Universal", "Heal", root, 3)
		end
	end
end

function KillCreditService:AwardKill(attackerCharacter, victimCharacter, reason)
	if not self:IsValidAttacker(attackerCharacter, victimCharacter) then
		return false
	end

	if self.AwardedCharacters[victimCharacter] == true
		or victimCharacter:GetAttribute("KillCreditAwarded") == true
	then
		return false
	end

	self.AwardedCharacters[victimCharacter] = true
	victimCharacter:SetAttribute("KillCreditAwarded", true)
	victimCharacter:SetAttribute("KillCreditReason", reason or "Unknown")

	if self.ProgressionService and self.ProgressionService.AwardKill then
		self.ProgressionService:AwardKill(attackerCharacter, victimCharacter)
	end

	self:ApplyHealOnKill(attackerCharacter)

	print(
		"[KillCreditService] Kill awarded:",
		attackerCharacter.Name,
		"victim:",
		victimCharacter.Name,
		"reason:",
		reason or "Unknown"
	)

	return true
end

function KillCreditService:TryAwardRecentCredit(victimCharacter, window, reason, requireCombatTag)
	if not victimCharacter or not victimCharacter.Parent then
		return false
	end
	if victimCharacter:GetAttribute("KillCreditAwarded") == true then
		return false
	end
	if requireCombatTag and not self:IsCombatTagged(victimCharacter) then
		return false
	end
	if not self:IsRecentDamage(victimCharacter, window) then
		return false
	end

	local attackerCharacter = self:GetLastAttacker(victimCharacter)
	if not attackerCharacter then
		return false
	end

	return self:AwardKill(attackerCharacter, victimCharacter, reason)
end

function KillCreditService:HandleCharacterDeath(victimCharacter)
	self:TryAwardRecentCredit(
		victimCharacter,
		self.Config.KillCreditWindow or 15,
		"Death",
		false
	)
end

function KillCreditService:HandleCharacterRemoving(player, character)
	if not player or not character then
		return
	end

	self:TryAwardRecentCredit(
		character,
		self.Config.ResetKillCreditWindow or 15,
		"AntiReset",
		true
	)
end

function KillCreditService:SetupHealingLock(character, humanoid)
	if self.Config.DisablePassiveHealing ~= true then
		return
	end
	if self:IsTestDummy(character) then
		return
	end

	task.defer(function()
		if not character or not character.Parent then return end
		if not humanoid or not humanoid.Parent then return end

		local correcting = false
		local lastHealth = humanoid.Health
		self.LastHealthByHumanoid[humanoid] = lastHealth

		humanoid.HealthChanged:Connect(function(newHealth)
			if correcting then
				return
			end
			if not humanoid.Parent then
				return
			end

			local previousHealth = self.LastHealthByHumanoid[humanoid] or lastHealth

			if newHealth <= previousHealth then
				lastHealth = newHealth
				self.LastHealthByHumanoid[humanoid] = newHealth
				return
			end

			if os.clock() <= (character:GetAttribute("AllowCombatHealUntil") or 0) then
				lastHealth = newHealth
				self.LastHealthByHumanoid[humanoid] = newHealth
				return
			end

			correcting = true
			humanoid.Health = previousHealth
			correcting = false
		end)
	end)
end

function KillCreditService:SetupCharacter(player, character)
	if not player or not character or self.SetupCharacters[character] then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	self.SetupCharacters[character] = true
	self.AwardedCharacters[character] = nil

	character:SetAttribute("KillCreditAwarded", false)
	character:SetAttribute("KillCreditReason", nil)
	character:SetAttribute("LastDamageTime", 0)
	character:SetAttribute("LastDamageByUserId", 0)
	character:SetAttribute("LastDamageSource", nil)
	character:SetAttribute("AllowCombatHealUntil", 0)

	local lastAttacker = self:GetOrCreateLastAttacker(character)
	if lastAttacker then
		lastAttacker.Value = nil
	end

	humanoid.Died:Connect(function()
		self:HandleCharacterDeath(character)
	end)

	self:SetupHealingLock(character, humanoid)
end

function KillCreditService:SetupPlayer(player)
	if player.Character then
		self:SetupCharacter(player, player.Character)
	end

	player.CharacterAdded:Connect(function(character)
		self:SetupCharacter(player, character)
	end)

	player.CharacterRemoving:Connect(function(character)
		self:HandleCharacterRemoving(player, character)
	end)
end

function KillCreditService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:SetupPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local character = player.Character
		if character then
			self:HandleCharacterRemoving(player, character)
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:SetupPlayer(player)
	end
end

return KillCreditService
