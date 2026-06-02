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

function BlockService:CanBlockHit(targetCharacter, attackerRoot)
	if not targetCharacter:GetAttribute("Blocking") then
		return false
	end

	if targetCharacter:GetAttribute("Guardbroken") then
		return false
	end

	local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return false end

	return self:IsAttackInFrontOfBlocker(targetRoot, attackerRoot)
end

function BlockService:PlayBlockVFX(targetRoot)
	self.VFXService:PlayBlockImpact(targetRoot)
end

function BlockService:PlayBlockBreakVFX(targetRoot)
	self.VFXService:PlayBlockBreak(targetRoot)
end

function BlockService:SetBlocking(player, isBlocking)
	local character, humanoid, root = self.StateService:GetCharacterInfo(player)
	if not character then return end

	if isBlocking then
		if character:GetAttribute("Stunned") then return end
		if character:GetAttribute("Attacking") then return end
		if character:GetAttribute("UsingMove") then return end
		if character:GetAttribute("Guardbroken") then return end

		character:SetAttribute("Blocking", true)

		humanoid.WalkSpeed = 8
		humanoid.Jump = false
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0

		if self.StateService.AnimationService then
			self.StateService.AnimationService:PlayBlockAnimation(character)
		end

		self.VFXService:StartBlockVFX(character)
	else
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