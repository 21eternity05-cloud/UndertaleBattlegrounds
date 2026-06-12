local BlockService = {}
BlockService.__index = BlockService

function BlockService.new(config, stateService, vfxService)
	local self = setmetatable({}, BlockService)
	self.Config = config
	self.StateService = stateService
	self.VFXService = vfxService
	self.BlockRetryTokens = setmetatable({}, { __mode = "k" })
	self.BlockRetryPlayers = setmetatable({}, { __mode = "k" })
	self.BlockWakeConnections = setmetatable({}, { __mode = "k" })
	return self
end

function BlockService:IsAttackInFrontOfBlocker(blockerRoot, attackerRoot)
	local directionToAttacker = attackerRoot.Position - blockerRoot.Position

	if directionToAttacker.Magnitude < 0.1 then
		return true
	end

	directionToAttacker = directionToAttacker.Unit

	local blockerLook = blockerRoot.CFrame.LookVector
	local dot = blockerLook:Dot(directionToAttacker)

	return dot > 0.15
end

function BlockService:CanBlockHit(targetCharacter, attackerRoot, attackData)
	if not targetCharacter:GetAttribute("Blocking") then
		return false
	end

	if targetCharacter:GetAttribute("Guardbroken") then
		return false
	end

	local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return false end

	if attackData and attackData.IgnoreBlockDirection == true then
		return true
	end
	if attackData and attackData.AllRoundBlock == true then
		return true
	end

	return self:IsAttackInFrontOfBlocker(targetRoot, attackerRoot)
end

function BlockService:PlayBlockVFX(targetRoot)
	self.VFXService:PlayBlockImpact(targetRoot)
end

function BlockService:PlayBlockBreakVFX(targetRoot)
	self.VFXService:PlayBlockBreak(targetRoot)
end

function BlockService:CanBlockNow(character)
	if not character or not character.Parent then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end

	local allowBlockWhileDamageLocked = character:GetAttribute("AllowBlockWhileDamageLocked") == true

	if character:GetAttribute("Blocking") then return false end
	if character:GetAttribute("Emoting") then return false end
	if character:GetAttribute("Stunned") then return false end
	if character:GetAttribute("Attacking") then return false end
	if character:GetAttribute("UsingMove") then return false end
	if character:GetAttribute("Guardbroken") then return false end
	if os.clock() < (character:GetAttribute("BlockLockedUntil") or 0) then return false end
	if character:GetAttribute("Grabbed") then return false end
	if character:GetAttribute("GrabLocked") then return false end
	if character:GetAttribute("CinematicLocked") and not allowBlockWhileDamageLocked then return false end
	if character:GetAttribute("MovementLocked") and not allowBlockWhileDamageLocked then return false end
	if character:GetAttribute("ReservedVictim") and not allowBlockWhileDamageLocked then return false end
	if character:GetAttribute("DamageLocked") and not allowBlockWhileDamageLocked then return false end
	if character:GetAttribute("SoulBursting") then return false end

	return true
end

function BlockService:CanStartBlock(character)
	return self:CanBlockNow(character)
end

function BlockService:CanStartBlocking(character)
	return self:CanBlockNow(character)
end

function BlockService:ClearBlockBuffer(character)
	if not character or not character.Parent then return end

	character:SetAttribute("BlockBufferedUntil", 0)
	character:SetAttribute("BlockBufferToken", (character:GetAttribute("BlockBufferToken") or 0) + 1)
end

function BlockService:StopBlockRetry(character)
	if not character then return end

	self.BlockRetryTokens[character] = nil
	self.BlockRetryPlayers[character] = nil
	self:ClearBlockBuffer(character)
end

function BlockService:WakeHeldBlock(player, character)
	if not player or not character or not character.Parent then return end
	if character:GetAttribute("BlockHeld") ~= true then return end
	if character:GetAttribute("Blocking") == true then return end

	local currentCharacter, currentHumanoid = self.StateService:GetCharacterInfo(player)
	if currentCharacter ~= character or not currentHumanoid then return end

	if self:CanBlockNow(character) then
		self:StartBlockingNow(character, currentHumanoid)
	else
		self:StartBlockRetry(player, character)
	end
end

function BlockService:HookBlockWakeSignals(player, character)
	if self.BlockWakeConnections[character] then
		self.BlockRetryPlayers[character] = player
		return
	end

	self.BlockRetryPlayers[character] = player

	local connections = {}
	local attributes = {
		"Blocking",
		"Stunned",
		"Guardbroken",
		"Grabbed",
		"GrabLocked",
		"CinematicLocked",
		"MovementLocked",
		"ReservedVictim",
		"DamageLocked",
		"AllowBlockWhileDamageLocked",
		"SoulBursting",
		"UsingMove",
		"Attacking",
		"Emoting",
		"BlockLockedUntil",
	}

	for _, attributeName in ipairs(attributes) do
		table.insert(connections, character:GetAttributeChangedSignal(attributeName):Connect(function()
			local retryPlayer = self.BlockRetryPlayers[character] or player
			self:WakeHeldBlock(retryPlayer, character)
		end))
	end

	table.insert(connections, character.AncestryChanged:Connect(function(_, parent)
		if parent then return end

		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end

		self.BlockWakeConnections[character] = nil
		self.BlockRetryTokens[character] = nil
		self.BlockRetryPlayers[character] = nil
	end))

	self.BlockWakeConnections[character] = connections
end

function BlockService:StartBlockingNow(character, humanoid)
	if self.SpawnService and self.SpawnService.ClearSpawnProtection then
		self.SpawnService:ClearSpawnProtection(character, "BlockStart")
	end

	self:StopBlockRetry(character)
	character:SetAttribute("BlockHeld", true)
	character:SetAttribute("Blocking", true)

	humanoid.WalkSpeed = 8
	humanoid.Jump = false
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0

	if self.StateService.AnimationService then
		self.StateService.AnimationService:PlayBlockAnimation(character)
	end

	self.VFXService:StartBlockVFX(character)
end

function BlockService:StartBlockRetry(player, character)
	self.BlockRetryPlayers[character] = player

	if self.BlockRetryTokens[character] then
		return
	end

	local retryToken = (character:GetAttribute("BlockBufferToken") or 0) + 1
	self.BlockRetryTokens[character] = retryToken
	character:SetAttribute("BlockBufferedUntil", 0)
	character:SetAttribute("BlockBufferToken", retryToken)

	task.spawn(function()
		while character and character.Parent do
			if self.BlockRetryTokens[character] ~= retryToken then
				return
			end
			if character:GetAttribute("BlockBufferToken") ~= retryToken then
				return
			end
			if character:GetAttribute("BlockHeld") ~= true then
				self:StopBlockRetry(character)
				return
			end
			if character:GetAttribute("Blocking") == true then
				self.BlockRetryTokens[character] = nil
				return
			end

			local currentCharacter, currentHumanoid = self.StateService:GetCharacterInfo(player)
			if currentCharacter ~= character or not currentHumanoid then
				self.BlockRetryTokens[character] = nil
				return
			end

			if self:CanBlockNow(character) then
				self:StartBlockingNow(character, currentHumanoid)
				return
			end

			task.wait(0.03)
		end

		self.BlockRetryTokens[character] = nil
	end)
end

function BlockService:SetCharacterBlocking(character, isBlocking)
	if not character or not character.Parent then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	if isBlocking then
		character:SetAttribute("BlockHeld", true)

		if self:CanBlockNow(character) then
			self:StartBlockingNow(character, humanoid)
		end
	else
		character:SetAttribute("BlockHeld", false)
		self:StopBlockRetry(character)
		character:SetAttribute("Blocking", false)

		if self.StateService.AnimationService then
			self.StateService.AnimationService:StopBlockAnimation(character)
		end

		self.VFXService:StopBlockVFX(character)

		if not character:GetAttribute("Stunned")
			and not character:GetAttribute("Guardbroken")
			and not character:GetAttribute("UsingMove")
			and not character:GetAttribute("Emoting")
		then
			humanoid.WalkSpeed = self.Config.DefaultWalkSpeed
			humanoid.JumpPower = self.Config.DefaultJumpPower
			humanoid.JumpHeight = self.Config.DefaultJumpHeight
		end
	end
end

function BlockService:SetBlocking(player, isBlocking)
	local character, humanoid, root = self.StateService:GetCharacterInfo(player)
	if not character then return end

	if isBlocking then
		character:SetAttribute("BlockHeld", true)
		self:HookBlockWakeSignals(player, character)

		if self:CanBlockNow(character) then
			character:SetAttribute("BlockHeld", true)
			self:StartBlockingNow(character, humanoid)
		else
			self:StartBlockRetry(player, character)
		end
	else
		character:SetAttribute("BlockHeld", false)
		self:StopBlockRetry(character)
		character:SetAttribute("Blocking", false)

		if self.StateService.AnimationService then
			self.StateService.AnimationService:StopBlockAnimation(character)
		end

		self.VFXService:StopBlockVFX(character)

		if not character:GetAttribute("Stunned")
			and not character:GetAttribute("Guardbroken")
			and not character:GetAttribute("UsingMove")
			and not character:GetAttribute("Emoting")
		then
			humanoid.WalkSpeed = self.Config.DefaultWalkSpeed
			humanoid.JumpPower = self.Config.DefaultJumpPower
			humanoid.JumpHeight = self.Config.DefaultJumpHeight
		end
	end
end

return BlockService
