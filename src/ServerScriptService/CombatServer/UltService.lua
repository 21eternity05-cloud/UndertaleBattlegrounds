local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UltService = {}
UltService.__index = UltService

function UltService.new(config)
	local self = setmetatable({}, UltService)

	self.Config = config

	self.UltMax = config.UltMax or 100

	self.DamageDealtMultiplier = config.UltDamageDealtMultiplier or 0.7
	self.DamageTakenMultiplier = config.UltDamageTakenMultiplier or 0.35

	self.GuardbreakGain = config.UltGuardbreakGain or 8
	self.CounterGain = config.UltCounterGain or 10
	self.ComboEnderGain = config.UltComboEnderGain or 5
	self.KillGain = config.UltKillGain or 15

	self.AllowDummyUltGain = config.AllowDummyUltGain == true

	self.PlayerUlt = {}

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	self.UltRemote = remotes:FindFirstChild("UltRemote")

	if not self.UltRemote then
		self.UltRemote = Instance.new("RemoteEvent")
		self.UltRemote.Name = "UltRemote"
		self.UltRemote.Parent = remotes
	end

	return self
end

function UltService:GetPlayerFromCharacter(character)
	if not character then return nil end
	return Players:GetPlayerFromCharacter(character)
end

function UltService:IsDummyCharacter(character)
	if not character then return false end
	if Players:GetPlayerFromCharacter(character) then return false end

	return character:FindFirstChildOfClass("Humanoid") ~= nil
end

function UltService:CanGainFromTarget(targetCharacter)
	if not targetCharacter then return true end

	if self.AllowDummyUltGain then
		return true
	end

	if self:IsDummyCharacter(targetCharacter) then
		return false
	end

	return true
end

function UltService:SetupPlayer(player)
	if not player then return end

	if self.PlayerUlt[player] == nil then
		self.PlayerUlt[player] = 0
	end

	self:SendUpdate(player)
end

function UltService:CleanupPlayer(player)
	self.PlayerUlt[player] = nil
end

function UltService:SetupDebugUltButton()
	local button = workspace:FindFirstChild("ULT_BUTTON")

	if not button or not button:IsA("BasePart") then
		warn("[UltService] No workspace ULT_BUTTON found")
		return
	end

	local debounce = {}

	button.Touched:Connect(function(hit)
		local character = hit and hit:FindFirstAncestorOfClass("Model")
		if not character then return end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end

		if debounce[player] then return end
		debounce[player] = true

		self:SetUlt(player, self.UltMax, "DebugButton")

		task.delay(0.75, function()
			debounce[player] = nil
		end)
	end)

	print("[UltService] Debug ULT_BUTTON connected")
end

function UltService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:SetupPlayer(player)

		player.CharacterAdded:Connect(function()
			self:SendUpdate(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:CleanupPlayer(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:SetupPlayer(player)

		player.CharacterAdded:Connect(function()
			self:SendUpdate(player)
		end)
	end

	self:SetupDebugUltButton()
end

function UltService:GetUlt(player)
	if not player then return 0 end

	if self.PlayerUlt[player] == nil then
		self.PlayerUlt[player] = 0
	end

	return self.PlayerUlt[player]
end

function UltService:GetUltMax()
	return self.UltMax
end

function UltService:GetUltAlpha(player)
	return math.clamp(self:GetUlt(player) / self.UltMax, 0, 1)
end

function UltService:IsFull(player)
	return self:GetUlt(player) >= self.UltMax
end

function UltService:SendUpdate(player)
	if not player then return end
	if not self.UltRemote then return end

	self.UltRemote:FireClient(player, {
		Action = "Update",
		Current = self:GetUlt(player),
		Max = self.UltMax,
		Alpha = self:GetUltAlpha(player),
		Full = self:IsFull(player),
	})
end

function UltService:SetUlt(player, amount, reason)
	if not player then return end

	local value = math.clamp(amount or 0, 0, self.UltMax)
	self.PlayerUlt[player] = value

	self:SendUpdate(player)

	if reason then
		print("[UltService]", player.Name, "ult set to", value, "reason:", reason)
	end
end

function UltService:AddUlt(player, amount, reason)
	if not player then return end
	if not amount or amount <= 0 then return end
	
	print("[UltService] AddUlt:", player.Name, amount, reason or "NoReason")

	local current = self:GetUlt(player)
	self:SetUlt(player, current + amount, reason)
end

function UltService:SpendUlt(player)
	if not player then return false end
	if not self:IsFull(player) then return false end

	self:SetUlt(player, 0, "SpendUlt")

	if self.UltRemote then
		self.UltRemote:FireClient(player, {
			Action = "Spent",
			Current = 0,
			Max = self.UltMax,
			Alpha = 0,
			Full = false,
		})
	end

	return true
end

function UltService:CanUseUltimate(player)
	return self:IsFull(player)
end

function UltService:AwardDamageDealt(attackerCharacter, targetCharacter, damageAmount)
	if not damageAmount or damageAmount <= 0 then return end
	if not self:CanGainFromTarget(targetCharacter) then return end

	local attackerPlayer = self:GetPlayerFromCharacter(attackerCharacter)
	if not attackerPlayer then return end

	self:AddUlt(
		attackerPlayer,
		damageAmount * self.DamageDealtMultiplier,
		"DamageDealt"
	)
end

function UltService:AwardDamageTaken(targetCharacter, attackerCharacter, damageAmount)
	if not damageAmount or damageAmount <= 0 then return end
	if not self:CanGainFromTarget(attackerCharacter) then return end

	local targetPlayer = self:GetPlayerFromCharacter(targetCharacter)
	if not targetPlayer then return end

	self:AddUlt(
		targetPlayer,
		damageAmount * self.DamageTakenMultiplier,
		"DamageTaken"
	)
end

function UltService:AwardGuardbreak(attackerCharacter, targetCharacter)
	if not self:CanGainFromTarget(targetCharacter) then return end

	local attackerPlayer = self:GetPlayerFromCharacter(attackerCharacter)
	if not attackerPlayer then return end

	self:AddUlt(attackerPlayer, self.GuardbreakGain, "Guardbreak")
end

function UltService:AwardCounter(attackerCharacter, targetCharacter)
	local attackerPlayer = self:GetPlayerFromCharacter(attackerCharacter)
	if not attackerPlayer then return end

	self:AddUlt(attackerPlayer, self.CounterGain, "Counter")
end

function UltService:AwardComboEnder(attackerCharacter, targetCharacter)
	if not self:CanGainFromTarget(targetCharacter) then return end

	local attackerPlayer = self:GetPlayerFromCharacter(attackerCharacter)
	if not attackerPlayer then return end

	self:AddUlt(attackerPlayer, self.ComboEnderGain, "ComboEnder")
end

function UltService:AwardKill(attackerCharacter, targetCharacter)
	if not self:CanGainFromTarget(targetCharacter) then return end

	local attackerPlayer = self:GetPlayerFromCharacter(attackerCharacter)
	if not attackerPlayer then return end

	self:AddUlt(attackerPlayer, self.KillGain, "Kill")
end

function UltService:AwardDamageEvent(attackerCharacter, targetCharacter, damageAmount)
	self:AwardDamageDealt(attackerCharacter, targetCharacter, damageAmount)
	self:AwardDamageTaken(targetCharacter, attackerCharacter, damageAmount)

	local targetHumanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")

	if targetHumanoid and targetHumanoid.Health <= 0 then
		self:AwardKill(attackerCharacter, targetCharacter)

		if self.ProgressionService and self.ProgressionService.AwardKill then
			self.ProgressionService:AwardKill(attackerCharacter, targetCharacter)
		end
	end
end

return UltService