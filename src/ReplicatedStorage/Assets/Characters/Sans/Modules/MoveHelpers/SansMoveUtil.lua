local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MoveHelperUtil = require(Shared:WaitForChild("Combat"):WaitForChild("MoveHelperUtil"))

local SansMoveUtil = {}

function SansMoveUtil.GetHumanoidAndRoot(character)
	return MoveHelperUtil.GetHumanoidAndRoot(character)
end

function SansMoveUtil.GetRoot(character)
	return MoveHelperUtil.GetRoot(character)
end

function SansMoveUtil.SafeCleanup(items)
	return MoveHelperUtil.SafeCleanup(items)
end

function SansMoveUtil.BuildSphereHitbox(radius, offset)
	return MoveHelperUtil.BuildSphereHitbox(radius, offset)
end

function SansMoveUtil.GetSansVFXFolder(ctx)
	local assets = ReplicatedStorage:WaitForChild(ctx.Config.AssetsFolderName or "Assets")
	local characters = assets:WaitForChild(ctx.Config.CharactersFolderName or "Characters")
	local sans = characters:WaitForChild("Sans")

	return sans:WaitForChild("VFX")
end

function SansMoveUtil.GetVFXTemplate(ctx, templateName)
	return SansMoveUtil.GetSansVFXFolder(ctx):FindFirstChild(templateName)
end

function SansMoveUtil.PlaySFX(ctx, soundName, parentPart, lifetime)
	if not ctx or not ctx.VFXService then return end
	if not ctx.VFXService.PlayCharacterSFXAtPart then return end
	if not parentPart or not parentPart.Parent then return end

	ctx.VFXService:PlayCharacterSFXAtPart("Sans", soundName, parentPart, lifetime or 3)
end

function SansMoveUtil.PlayMoveVFX(ctx, moveName, targetCharacter, targetRoot)
	if not ctx or not ctx.VFXService then return end
	if not ctx.VFXService.PlayCharacterMoveVFX then return end

	ctx.VFXService:PlayCharacterMoveVFX(ctx.Character, moveName, targetCharacter, targetRoot)
end

function SansMoveUtil.IsMoveInterrupted(ctx)
	local character = ctx and ctx.Character

	if not ctx or not ctx.IsActive or not ctx:IsActive() then
		return true
	end

	if ctx.CombatStatusService and ctx.CombatStatusService.CanAttackContinue then
		return not ctx.CombatStatusService:CanAttackContinue(character, ctx.MoveData)
	end

	return character
		and (character:GetAttribute("Stunned") == true or character:GetAttribute("Guardbroken") == true)
end

return SansMoveUtil
