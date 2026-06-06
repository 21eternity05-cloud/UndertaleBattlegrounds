local BlockService = {}
BlockService.__index = BlockService

function BlockService.new(config, stateService, vfxService)
	local self = setmetatable({}, BlockService)
	self.Config = config
	self.StateService = stateService
	self.VFXService = vfxService
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

function BlockService:CanStartBlocking(character)
	if not character or not character.Parent then
		return false
	end

	if character:GetAttribute("Stunned") then return false end
	if character:GetAttribute("Attacking") then return false end
	if character:GetAttribute("UsingMove") then return false end
	if character:GetAttribute("Guardbroken") then return false end
	if character:GetAttribute("Grabbed") then return false end
	if character:GetAttribute("CinematicLocked") then return false end

	return true
end

function BlockService:StartBlockingNow(character, humanoid)
	character:SetAttribute("BlockBufferedUntil", 0)
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

function BlockService:BufferBlockStart(player, character)
	local bufferUntil = os.clock() + (self.Config.BlockBufferTime or 0.18)
	character:SetAttribute("BlockBufferedUntil", bufferUntil)

	task.spawn(function()
		while character and character.Parent do
			if character:GetAttribute("BlockBufferedUntil") ~= bufferUntil then
				return
			end
			if os.clock() >= bufferUntil then
				character:SetAttribute("BlockBufferedUntil", 0)
				return
			end

			local currentCharacter, currentHumanoid = self.StateService:GetCharacterInfo(player)
			if currentCharacter ~= character or not currentHumanoid then
				return
			end

			if self:CanStartBlocking(character) then
				self:StartBlockingNow(character, currentHumanoid)
				return
			end

			task.wait()
		end
	end)
end

function BlockService:SetBlocking(player, isBlocking)
	local character, humanoid, root = self.StateService:GetCharacterInfo(player)
	if not character then return end

	if isBlocking then
		if self:CanStartBlocking(character) then
			self:StartBlockingNow(character, humanoid)
		elseif not character:GetAttribute("Stunned")
			and not character:GetAttribute("Guardbroken")
			and not character:GetAttribute("Grabbed")
			and not character:GetAttribute("CinematicLocked")
		then
			self:BufferBlockStart(player, character)
		end
	else
		character:SetAttribute("BlockBufferedUntil", 0)
		character:SetAttribute("Blocking", false)

		if self.StateService.AnimationService then
			self.StateService.AnimationService:StopBlockAnimation(character)
		end

		self.VFXService:StopBlockVFX(character)

		if not character:GetAttribute("Stunned")
			and not character:GetAttribute("Guardbroken")
			and not character:GetAttribute("UsingMove")
		then
			humanoid.WalkSpeed = self.Config.DefaultWalkSpeed
			humanoid.JumpPower = self.Config.DefaultJumpPower
			humanoid.JumpHeight = self.Config.DefaultJumpHeight
		end
	end
end

return BlockService
