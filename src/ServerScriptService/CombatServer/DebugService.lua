local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DebugService = {}
DebugService.__index = DebugService

function DebugService.new(config)
	local self = setmetatable({}, DebugService)

	self.Config = config
	self.Enabled = false
	self.CooldownsEnabled = false
	self.TouchDebounce = {}
	self.SoulBurstService = nil
	self.CombatStateDebugConnection = nil
	self.CombatStateDebugAccumulator = 0

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

	if not self.Enabled then
		self:ClearAllCombatStateBillboards()
	end

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

function DebugService:IsEnabled()
	return self.Config.DebugEnabled == true or workspace:GetAttribute("DebugEnabled") == true
end

function DebugService:FormatRemaining(untilTime)
	if typeof(untilTime) ~= "number" then
		return nil
	end

	local remaining = untilTime - os.clock()

	if remaining <= 0 then
		return nil
	end

	return string.format("%.1f", remaining)
end

function DebugService:AddTimedState(lines, character, attributeName, label)
	local remaining = self:FormatRemaining(character:GetAttribute(attributeName) or 0)

	if remaining then
		table.insert(lines, label .. ": " .. remaining)
	end
end

function DebugService:AddBoolState(lines, character, attributeName, label)
	if character:GetAttribute(attributeName) == true then
		table.insert(lines, label)
	end
end

function DebugService:GetCombatStateLines(character)
	local lines = {}

	self:AddTimedState(lines, character, "M1ImmuneUntil", "M1 IMMUNE")
	self:AddTimedState(lines, character, "WallComboProtectedUntil", "WALL")

	if character:GetAttribute("SpawnProtected") == true then
		local remaining = self:FormatRemaining(character:GetAttribute("SpawnIFrameUntil") or 0)
		table.insert(lines, remaining and ("SPAWN: " .. remaining) or "SPAWN")
	else
		self:AddTimedState(lines, character, "SpawnIFrameUntil", "SPAWN")
	end

	self:AddBoolState(lines, character, "IFrameActive", "IFRAME")
	self:AddBoolState(lines, character, "SoulBursting", "SOUL BURST")

	local armorRemaining = self:FormatRemaining(character:GetAttribute("ArmorUntil") or 0)
	if armorRemaining then
		table.insert(lines, "ARMOR: " .. armorRemaining)
	elseif character:GetAttribute("ArmorActive") == true then
		table.insert(lines, "ARMOR")
	end

	self:AddBoolState(lines, character, "HasArmor", "HAS ARMOR")
	self:AddBoolState(lines, character, "Guardbroken", "GUARDBREAK")
	self:AddBoolState(lines, character, "Stunned", "STUN")
	self:AddBoolState(lines, character, "Blocking", "BLOCK")
	self:AddBoolState(lines, character, "Grabbed", "GRABBED")
	self:AddBoolState(lines, character, "DamageLocked", "DAMAGE LOCK")
	self:AddBoolState(lines, character, "CinematicLocked", "CINEMATIC")

	return lines
end

function DebugService:GetCombatStateAdornee(character)
	if not character or not character.Parent then
		return nil
	end

	return character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
end

function DebugService:GetOrCreateCombatStateBillboard(character)
	local adornee = self:GetCombatStateAdornee(character)
	if not adornee then
		return nil
	end

	local billboard = character:FindFirstChild("CombatStateDebugBillboard")

	if not billboard then
		billboard = Instance.new("BillboardGui")
		billboard.Name = "CombatStateDebugBillboard"
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = 180
		billboard.Size = UDim2.fromOffset(150, 120)
		billboard.StudsOffset = Vector3.new(0, 3.6, 0)
		billboard.Parent = character

		local text = Instance.new("TextLabel")
		text.Name = "StateText"
		text.BackgroundTransparency = 0.25
		text.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
		text.BorderSizePixel = 0
		text.Size = UDim2.fromScale(1, 1)
		text.Font = Enum.Font.GothamBold
		text.TextSize = 13
		text.TextColor3 = Color3.fromRGB(245, 245, 245)
		text.TextStrokeTransparency = 0.3
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.TextYAlignment = Enum.TextYAlignment.Top
		text.Parent = billboard
	end

	billboard.Adornee = adornee

	return billboard
end

function DebugService:ClearCombatStateBillboard(character)
	if not character then
		return
	end

	local billboard = character:FindFirstChild("CombatStateDebugBillboard")

	if billboard then
		billboard:Destroy()
	end
end

function DebugService:UpdateCombatStateBillboard(character)
	if not character or not character.Parent then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if not humanoid or humanoid.Health <= 0 or not self:IsEnabled() then
		self:ClearCombatStateBillboard(character)
		return
	end

	local lines = self:GetCombatStateLines(character)

	if #lines == 0 then
		self:ClearCombatStateBillboard(character)
		return
	end

	local billboard = self:GetOrCreateCombatStateBillboard(character)
	if not billboard then
		return
	end

	local text = billboard:FindFirstChild("StateText")
	if text and text:IsA("TextLabel") then
		text.Text = table.concat(lines, "\n")
	end
end

function DebugService:GetCombatDebugCharacters()
	local characters = {}
	local seen = {}

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character

		if character and not seen[character] then
			seen[character] = true
			table.insert(characters, character)
		end
	end

	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("Humanoid") then
			local character = descendant.Parent

			if character and character:IsA("Model") and not seen[character] then
				seen[character] = true
				table.insert(characters, character)
			end
		end
	end

	return characters
end

function DebugService:ClearAllCombatStateBillboards()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant.Name == "CombatStateDebugBillboard" and descendant:IsA("BillboardGui") then
			descendant:Destroy()
		end
	end
end

function DebugService:StartCombatStateDebugLoop()
	if self.CombatStateDebugConnection then
		return
	end

	self.CombatStateDebugConnection = RunService.Heartbeat:Connect(function(deltaTime)
		self.CombatStateDebugAccumulator += deltaTime

		if self.CombatStateDebugAccumulator < 0.1 then
			return
		end

		self.CombatStateDebugAccumulator = 0

		if not self:IsEnabled() then
			self:ClearAllCombatStateBillboards()
			return
		end

		for _, character in ipairs(self:GetCombatDebugCharacters()) do
			self:UpdateCombatStateBillboard(character)
		end
	end)
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

	self:StartCombatStateDebugLoop()
end

return DebugService
