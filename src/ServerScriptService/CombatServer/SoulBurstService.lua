local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoulBurstService = {}
SoulBurstService.__index = SoulBurstService

function SoulBurstService.new(
	config,
	stateService,
	combatStatusService,
	movementService,
	hitboxService,
	vfxService,
	counterService,
	ultService,
	grabService,
	cinematicService
)
	local self = setmetatable({}, SoulBurstService)

	self.Config = config
	self.StateService = stateService
	self.CombatStatusService = combatStatusService
	self.MovementService = movementService
	self.HitboxService = hitboxService
	self.VFXService = vfxService
	self.CounterService = counterService
	self.UltService = ultService
	self.GrabService = grabService
	self.CinematicService = cinematicService

	self.PlayerSoulBurst = {}

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	self.SoulBurstRemote = remotes:FindFirstChild("SoulBurstRemote")

	if not self.SoulBurstRemote then
		self.SoulBurstRemote = Instance.new("RemoteEvent")
		self.SoulBurstRemote.Name = "SoulBurstRemote"
		self.SoulBurstRemote.Parent = remotes
	end

	return self
end

function SoulBurstService:GetMax()
	return self.Config.SoulBurstMax or 100
end

function SoulBurstService:GetCost()
	return self.Config.SoulBurstCost or self:GetMax()
end

function SoulBurstService:GetPlayerFromCharacter(character)
	if not character then return nil end
	return Players:GetPlayerFromCharacter(character)
end

function SoulBurstService:IsNPCSoulBurstCharacter(character)
	if not character or not character.Parent then
		return false
	end

	return character:GetAttribute("CanSoulBurst") == true
		or character:GetAttribute("SoulBurstDummy") == true
		or character.Name == "SOULBURSTDummy"
end

function SoulBurstService:InitializeCharacter(player, character)
	if not player then
		player = self:GetPlayerFromCharacter(character)
	end

	if player and self.PlayerSoulBurst[player] == nil then
		self.PlayerSoulBurst[player] = 0
	end

	if character and character.Parent then
		character:SetAttribute("SoulBurst", player and self:GetSoulBurst(player) or 0)
		character:SetAttribute("SoulBursting", false)
		character:SetAttribute("SoulBurstCooldownUntil", character:GetAttribute("SoulBurstCooldownUntil") or 0)
		character:SetAttribute("SoulBurstIFrameId", character:GetAttribute("SoulBurstIFrameId") or 0)
	end

	if player then
		self:SendUpdate(player)
	end
end

function SoulBurstService:SetupPlayer(player)
	if not player then return end

	if self.PlayerSoulBurst[player] == nil then
		self.PlayerSoulBurst[player] = 0
	end

	if player.Character then
		self:InitializeCharacter(player, player.Character)
	end

	self:SendUpdate(player)
end

function SoulBurstService:CleanupPlayer(player)
	self.PlayerSoulBurst[player] = nil
end

function SoulBurstService:GetSoulBurst(playerOrCharacter)
	local player = playerOrCharacter
	local character = nil

	if typeof(playerOrCharacter) == "Instance" and playerOrCharacter:IsA("Model") then
		character = playerOrCharacter
		player = self:GetPlayerFromCharacter(character)
	end

	if not player then
		if character and self:IsNPCSoulBurstCharacter(character) then
			return character:GetAttribute("SoulBurst") or 0
		end

		return 0
	end

	if self.PlayerSoulBurst[player] == nil then
		self.PlayerSoulBurst[player] = 0
	end

	return self.PlayerSoulBurst[player]
end

function SoulBurstService:SendUpdate(player)
	if not player or not self.SoulBurstRemote then return end

	local current = self:GetSoulBurst(player)
	local maxValue = self:GetMax()

	self.SoulBurstRemote:FireClient(player, {
		Action = "Update",
		Value = current,
		Current = current,
		Max = maxValue,
		Alpha = math.clamp(current / maxValue, 0, 1),
		Ready = current >= self:GetCost(),
	})
end

function SoulBurstService:SetSoulBurst(playerOrCharacter, amount, reason)
	local player = playerOrCharacter
	local character = nil

	if typeof(playerOrCharacter) == "Instance" and playerOrCharacter:IsA("Model") then
		character = playerOrCharacter
		player = self:GetPlayerFromCharacter(character)
	elseif typeof(playerOrCharacter) == "Instance" and playerOrCharacter:IsA("Player") then
		character = playerOrCharacter.Character
	end

	if not player then
		if not character or not self:IsNPCSoulBurstCharacter(character) then
			return
		end

		local value = math.clamp(amount or 0, 0, self:GetMax())
		character:SetAttribute("SoulBurst", value)

		if reason then
			print("[SoulBurstService]", character.Name, "soul burst set to", value, "reason:", reason)
		end

		return
	end

	local value = math.clamp(amount or 0, 0, self:GetMax())
	self.PlayerSoulBurst[player] = value

	if character and character.Parent then
		character:SetAttribute("SoulBurst", value)
	elseif player.Character then
		player.Character:SetAttribute("SoulBurst", value)
	end

	self:SendUpdate(player)

	if reason then
		print("[SoulBurstService]", player.Name, "soul burst set to", value, "reason:", reason)
	end
end

function SoulBurstService:AddSoulBurst(playerOrCharacter, amount, reason)
	if not amount or amount <= 0 then
		return
	end

	local current = self:GetSoulBurst(playerOrCharacter)
	self:SetSoulBurst(playerOrCharacter, current + amount, reason)
end

function SoulBurstService:CanAwardForHitTaken(targetCharacter, attackData)
	if not targetCharacter or not targetCharacter.Parent then
		return false
	end

	local player = self:GetPlayerFromCharacter(targetCharacter)
	if not player and not self:IsNPCSoulBurstCharacter(targetCharacter) then
		return false
	end

	if attackData then
		if attackData.AwardsSoulBurst == false then
			return false
		end
		if attackData.IsSoulBurst == true then
			return false
		end
		if attackData.AwardsUlt == false then
			return false
		end
	end

	if targetCharacter:GetAttribute("Guardbroken") == true then return false end
	if targetCharacter:GetAttribute("Grabbed") == true then return false end
	if targetCharacter:GetAttribute("CinematicLocked") == true then return false end
	if targetCharacter:GetAttribute("UltimateLocked") == true then return false end
	if targetCharacter:GetAttribute("UsingUltimate") == true then return false end
	if targetCharacter:GetAttribute("DamageLocked") == true then return false end

	return true
end

function SoulBurstService:CanSoulBurstCharacter(character)
	if not character or not character.Parent then
		return false, "NoCharacter"
	end

	local player = self:GetPlayerFromCharacter(character)
	if player then
		return self:CanSoulBurst(player, character)
	end

	if not self:IsNPCSoulBurstCharacter(character) then
		return false, "NoPlayer"
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or humanoid.Health <= 0 then return false, "Dead" end
	if not root then return false, "NoRoot" end
	if self:GetSoulBurst(character) < self:GetCost() then return false, "NotReady" end
	if os.clock() < (character:GetAttribute("SoulBurstCooldownUntil") or 0) then return false, "Cooldown" end
	if character:GetAttribute("SoulBursting") == true then return false, "AlreadyBursting" end
	if character:GetAttribute("Emoting") == true then return false, "Emoting" end
	if character:GetAttribute("Stunned") ~= true then return false, "NotStunned" end
	if character:GetAttribute("Guardbroken") == true then return false, "Guardbroken" end
	if character:GetAttribute("Grabbed") == true then return false, "Grabbed" end
	if character:GetAttribute("CinematicLocked") == true then return false, "CinematicLocked" end
	if character:GetAttribute("UltimateLocked") == true then return false, "UltimateLocked" end
	if character:GetAttribute("UsingUltimate") == true then return false, "UsingUltimate" end
	if character:GetAttribute("DamageLocked") == true then return false, "DamageLocked" end
	if self:HasActiveReservedVictim(character) then return false, "ReservedVictim" end

	return true, "Ready"
end

function SoulBurstService:AwardForHitTaken(targetCharacter, damage, stun, attackData)
	if not self:CanAwardForHitTaken(targetCharacter, attackData) then
		return
	end

	local amount = (self.Config.SoulBurstHitGain or 18)
		+ ((damage or 0) * (self.Config.SoulBurstDamageGainMultiplier or 0.8))
		+ ((stun or 0) * (self.Config.SoulBurstStunGainMultiplier or 12))

	if attackData and (attackData.IsComboExtender == true or attackData.ComboExtender == true) then
		amount += self.Config.SoulBurstComboExtenderBonus or 10
	end

	self:AddSoulBurst(targetCharacter, amount, "HitTaken")
end

function SoulBurstService:HasActiveReservedVictim(character)
	local value = character and character:FindFirstChild("ReservedVictim")

	if value and value:IsA("ObjectValue") and value.Value ~= nil then
		return true
	end

	return false
end

function SoulBurstService:CanSoulBurst(player, character)
	if not player then
		return false, "NoPlayer"
	end

	character = character or player.Character
	if not character or not character.Parent then
		return false, "NoCharacter"
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or humanoid.Health <= 0 then
		return false, "Dead"
	end
	if not root then
		return false, "NoRoot"
	end
	if self:GetSoulBurst(player) < self:GetCost() then
		return false, "NotReady"
	end
	if os.clock() < (character:GetAttribute("SoulBurstCooldownUntil") or 0) then
		return false, "Cooldown"
	end
	if character:GetAttribute("SoulBursting") == true then return false, "AlreadyBursting" end
	if character:GetAttribute("Emoting") == true then return false, "Emoting" end
	if character:GetAttribute("Stunned") ~= true then return false, "NotStunned" end
	if character:GetAttribute("Guardbroken") == true then return false, "Guardbroken" end
	if character:GetAttribute("Grabbed") == true then return false, "Grabbed" end
	if character:GetAttribute("CinematicLocked") == true then return false, "CinematicLocked" end
	if character:GetAttribute("UltimateLocked") == true then return false, "UltimateLocked" end
	if character:GetAttribute("UsingUltimate") == true then return false, "UsingUltimate" end
	if character:GetAttribute("DamageLocked") == true then return false, "DamageLocked" end
	if self:HasActiveReservedVictim(character) then return false, "ReservedVictim" end

	return true, "Ready"
end

function SoulBurstService:ClearNormalStun(character, humanoid)
	if not character or not character.Parent then return end
	if not humanoid or not humanoid.Parent then return end

	local stunId = (character:GetAttribute("StunId") or 0) + 1
	character:SetAttribute("StunId", stunId)
	character:SetAttribute("Stunned", false)
	character:SetAttribute("Attacking", false)
	character:SetAttribute("UsingMove", false)
	character:SetAttribute("Blocking", false)
	character:SetAttribute("BlockBufferedUntil", 0)

	if self.StateService then
		if self.StateService.StopBlockingVisuals then
			self.StateService:StopBlockingVisuals(character)
		end
		if self.StateService.StopCurrentStunAnimations then
			self.StateService:StopCurrentStunAnimations(character)
		end
		if self.StateService.ClearDebugHighlight then
			self.StateService:ClearDebugHighlight(character)
		end
	end

	humanoid.WalkSpeed = self.Config.DefaultWalkSpeed or 16
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	humanoid.JumpPower = self.Config.DefaultJumpPower or 50
	humanoid.JumpHeight = self.Config.DefaultJumpHeight or 7.2
end

function SoulBurstService:ApplyBurstIFrames(character)
	local iframeId = (character:GetAttribute("SoulBurstIFrameId") or 0) + 1
	local duration = self.Config.SoulBurstIFrameDuration or 1

	character:SetAttribute("SoulBurstIFrameId", iframeId)
	character:SetAttribute("IFrameActive", true)

	task.delay(duration, function()
		if not character or not character.Parent then return end
		if character:GetAttribute("SoulBurstIFrameId") ~= iframeId then return end

		character:SetAttribute("SoulBursting", false)

		if character:GetAttribute("UsingMove") == true and character:GetAttribute("CurrentMoveId") ~= nil then
			return
		end

		character:SetAttribute("IFrameActive", false)
	end)
end

function SoulBurstService:ApplyBurstHitbox(character, root)
	if not self.HitboxService or not root then
		return
	end

	local radius = self.Config.SoulBurstRadius or 10
	local damage = self.Config.SoulBurstDamage or 0
	local speed = self.Config.SoulBurstKnockbackSpeed or 55
	local upward = self.Config.SoulBurstUpwardKnockback or 18
	local duration = self.Config.SoulBurstKnockbackDuration or 0.22
	local maxForce = self.Config.SoulBurstKnockbackMaxForce or 65000

	self.HitboxService:PerformSphereAtPosition(character, root.Position, radius, function(targetCharacter, targetHumanoid, targetRoot)
		if not targetCharacter or not targetHumanoid or not targetRoot then
			return
		end

		if damage > 0 then
			targetHumanoid:TakeDamage(damage)

			if self.CombatStatusService and self.CombatStatusService.TagCombatPair then
				self.CombatStatusService:TagCombatPair(character, targetCharacter)
			end
		end

		if self.MovementService and self.MovementService.ApplyForceKnockback then
			local direction = targetRoot.Position - root.Position
			direction = Vector3.new(direction.X, 0, direction.Z)

			if direction.Magnitude < 0.05 then
				direction = root.CFrame.LookVector
			else
				direction = direction.Unit
			end

			self.MovementService:ApplyForceKnockback(
				targetRoot,
				(direction * speed) + Vector3.new(0, upward, 0),
				duration,
				maxForce,
				"SoulBurst"
			)
		end
	end)
end

function SoulBurstService:ActivateSoulBurst(player)
	local character = player and player.Character
	local canBurst, reason = self:CanSoulBurst(player, character)

	if not canBurst then
		if self.Config.SoulBurstDebugEnabled == true then
			print("[SoulBurstService] Activation denied:", player and player.Name or "nil", reason)
		end
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	self:SetSoulBurst(player, self:GetSoulBurst(player) - self:GetCost(), "Activate")

	character:SetAttribute("SoulBursting", true)
	character:SetAttribute("SoulBurstCooldownUntil", os.clock() + (self.Config.SoulBurstCooldown or 8))

	if self.MovementService and self.MovementService.ClearCombatMovementControllers then
		self.MovementService:ClearCombatMovementControllers(root)
	end

	self:ClearNormalStun(character, humanoid)
	self:ApplyBurstIFrames(character)

	if self.VFXService and self.VFXService.PlaySoulBurst then
		self.VFXService:PlaySoulBurst(character)
	end

	self:ApplyBurstHitbox(character, root)

	if self.SoulBurstRemote then
		self.SoulBurstRemote:FireClient(player, {
			Action = "Activated",
			Value = self:GetSoulBurst(player),
			Max = self:GetMax(),
		})
	end

	return true
end

function SoulBurstService:ActivateSoulBurstForCharacter(character)
	local player = self:GetPlayerFromCharacter(character)

	if player then
		return self:ActivateSoulBurst(player)
	end

	local canBurst, reason = self:CanSoulBurstCharacter(character)
	if not canBurst then
		if self.Config.SoulBurstDebugEnabled == true then
			print("[SoulBurstService] NPC activation denied:", character and character.Name or "nil", reason)
		end
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	self:SetSoulBurst(character, self:GetSoulBurst(character) - self:GetCost(), "ActivateNPC")

	character:SetAttribute("SoulBursting", true)
	character:SetAttribute("SoulBurstCooldownUntil", os.clock() + (self.Config.SoulBurstCooldown or 8))

	if self.MovementService and self.MovementService.ClearCombatMovementControllers then
		self.MovementService:ClearCombatMovementControllers(root)
	end

	self:ClearNormalStun(character, humanoid)
	self:ApplyBurstIFrames(character)

	if self.VFXService and self.VFXService.PlaySoulBurst then
		self.VFXService:PlaySoulBurst(character)
	end

	self:ApplyBurstHitbox(character, root)

	return true
end

function SoulBurstService:SetupDebugButton()
	local button = workspace:FindFirstChild("SOULBURST_BUTTON")

	if not button or not button:IsA("BasePart") then
		return
	end

	local debounce = {}

	button.Touched:Connect(function(hit)
		local character = hit and hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)

		if not player then return end
		if debounce[player] then return end

		debounce[player] = true
		self:SetSoulBurst(player, self:GetMax(), "DebugButton")

		task.delay(0.75, function()
			debounce[player] = nil
		end)
	end)

	print("[SoulBurstService] Debug SOULBURST_BUTTON connected")
end

function SoulBurstService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:SetupPlayer(player)

		player.CharacterAdded:Connect(function(character)
			self:InitializeCharacter(player, character)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:CleanupPlayer(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:SetupPlayer(player)

		player.CharacterAdded:Connect(function(character)
			self:InitializeCharacter(player, character)
		end)
	end

end

return SoulBurstService
