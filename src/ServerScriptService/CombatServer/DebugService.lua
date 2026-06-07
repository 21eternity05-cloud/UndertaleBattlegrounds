local Players = game:GetService("Players")

local DebugService = {}
DebugService.__index = DebugService

function DebugService.new(config)
	local self = setmetatable({}, DebugService)

	self.Config = config
	self.Enabled = false
	self.CooldownsEnabled = false
	self.TouchDebounce = {}
	self.SoulBurstService = nil

	return self
end

function DebugService:SetWorkspaceAttributes(enabled)
	workspace:SetAttribute("DebugEnabled", enabled)
	workspace:SetAttribute("DebugHitboxes", enabled)
	workspace:SetAttribute("DebugKnockback", enabled)
	workspace:SetAttribute("DebugDamageNumbers", enabled)
end

function DebugService:SetConfigValues(enabled)
	self.Config.DebugEnabled = enabled
	self.Config.DebugHitboxes = enabled
	self.Config.DebugKnockback = enabled
	self.Config.DebugDamageNumbers = enabled
end

function DebugService:SetEnabled(enabled)
	self.Enabled = enabled == true

	self:SetConfigValues(self.Enabled)
	self:SetWorkspaceAttributes(self.Enabled)

	print("[DebugService] Debug enabled:", self.Enabled)
	print("[DebugService] DebugHitboxes:", self.Config.DebugHitboxes)
	print("[DebugService] DebugKnockback:", self.Config.DebugKnockback)
	print("[DebugService] DebugDamageNumbers:", self.Config.DebugDamageNumbers)
end

function DebugService:SetCooldownDebugEnabled(enabled)
	self.CooldownsEnabled = enabled == true

	workspace:SetAttribute("DebugCooldownsEnabled", self.CooldownsEnabled)
	workspace:SetAttribute("DebugCooldownOverride", self.CooldownsEnabled and 1 or nil)

	print("[DebugService] Debug cooldowns enabled:", self.CooldownsEnabled)
end

function DebugService:ToggleCooldowns()
	self:SetCooldownDebugEnabled(not self.CooldownsEnabled)
end

function DebugService:Toggle()
	self:SetEnabled(not self.Enabled)
end

function DebugService:IsDebugButton(instance)
	if not instance then
		return false
	end

	if instance.Name == "DEBUG_BUTTON" then
		return true
	end

	if instance:GetAttribute("DebugButton") == true then
		return true
	end

	return false
end

function DebugService:IsCooldownButton(instance)
	if not instance then
		return false
	end

	if instance.Name == "COOLDOWN_BUTTON" then
		return true
	end

	if instance:GetAttribute("CooldownButton") == true then
		return true
	end

	return false
end

function DebugService:IsSoulBurstButton(instance)
	if not instance then
		return false
	end

	if instance.Name == "SOULBURST_BUTTON" then
		return true
	end

	if instance:GetAttribute("SoulBurstButton") == true then
		return true
	end

	return false
end

function DebugService:GetPlayerFromHit(hit)
	if not hit then
		return nil
	end

	local character = hit:FindFirstAncestorOfClass("Model")

	if not character then
		return nil
	end

	return Players:GetPlayerFromCharacter(character)
end

function DebugService:CanTouch(player)
	if not player then
		return false
	end

	local now = os.clock()
	local lastTouch = self.TouchDebounce[player] or 0

	if now - lastTouch < 1.5 then
		return false
	end

	self.TouchDebounce[player] = now

	return true
end

function DebugService:HookDebugButton(button)
	if not button or not button:IsA("BasePart") then
		return
	end

	button.Touched:Connect(function(hit)
		local player = self:GetPlayerFromHit(hit)

		if not player then
			return
		end

		if not self:CanTouch(player) then
			return
		end

		self:Toggle()
	end)

	print("[DebugService] Hooked debug button:", button:GetFullName())
end

function DebugService:HookCooldownButton(button)
	if not button or not button:IsA("BasePart") then
		return
	end

	button.Touched:Connect(function(hit)
		local player = self:GetPlayerFromHit(hit)

		if not player then
			return
		end

		if not self:CanTouch(player) then
			return
		end

		self:ToggleCooldowns()
	end)

	print("[DebugService] Hooked cooldown button:", button:GetFullName())
end

function DebugService:HookSoulBurstButton(button)
	if not button or not button:IsA("BasePart") then
		return
	end

	button.Touched:Connect(function(hit)
		local player = self:GetPlayerFromHit(hit)

		if not player then
			return
		end

		if not self:CanTouch(player) then
			return
		end

		if self.SoulBurstService then
			self.SoulBurstService:SetSoulBurst(player, self.SoulBurstService:GetMax(), "DebugService")
		else
			workspace:SetAttribute("DebugSoulBurstFill", true)
			warn("[DebugService] SoulBurstService is not wired; set DebugSoulBurstFill attribute")
		end
	end)

	print("[DebugService] Hooked soul burst button:", button:GetFullName())
end

function DebugService:Start()
	self:SetEnabled(false)
	self:SetCooldownDebugEnabled(false)
	workspace:SetAttribute("DebugSoulBurstFill", false)

	local button = workspace:FindFirstChild("DEBUG_BUTTON")

	if button and button:IsA("BasePart") then
		self:HookDebugButton(button)
	else
		warn("[DebugService] Missing workspace.DEBUG_BUTTON")
	end

	local cooldownButton = workspace:FindFirstChild("COOLDOWN_BUTTON")

	if cooldownButton and cooldownButton:IsA("BasePart") then
		self:HookCooldownButton(cooldownButton)
	else
		warn("[DebugService] Missing workspace.COOLDOWN_BUTTON")
	end

	local soulBurstButton = workspace:FindFirstChild("SOULBURST_BUTTON")

	if soulBurstButton and soulBurstButton:IsA("BasePart") then
		self:HookSoulBurstButton(soulBurstButton)
	end

	workspace.DescendantAdded:Connect(function(descendant)
		if self:IsDebugButton(descendant) and descendant:IsA("BasePart") then
			self:HookDebugButton(descendant)
		elseif self:IsCooldownButton(descendant) and descendant:IsA("BasePart") then
			self:HookCooldownButton(descendant)
		elseif self:IsSoulBurstButton(descendant) and descendant:IsA("BasePart") then
			self:HookSoulBurstButton(descendant)
		end
	end)
end

return DebugService
