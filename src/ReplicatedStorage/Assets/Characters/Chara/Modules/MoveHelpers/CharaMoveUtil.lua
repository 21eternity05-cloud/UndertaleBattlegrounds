local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MoveHelperUtil = require(Shared:WaitForChild("Combat"):WaitForChild("MoveHelperUtil"))

local CharaMoveUtil = {}

function CharaMoveUtil.GetHumanoidAndRoot(character)
	return MoveHelperUtil.GetHumanoidAndRoot(character)
end

function CharaMoveUtil.GetRoot(character)
	return MoveHelperUtil.GetRoot(character)
end

function CharaMoveUtil.BuildSphereHitbox(radius, offset)
	return MoveHelperUtil.BuildSphereHitbox(radius, offset)
end

function CharaMoveUtil.SafeCleanup(items)
	return MoveHelperUtil.SafeCleanup(items)
end

function CharaMoveUtil.PlaySFX(ctx, soundName, parentPart, lifetime)
	if not ctx or not ctx.VFXService then return end
	if not ctx.VFXService.PlayCharacterSFXAtPart then return end

	ctx.VFXService:PlayCharacterSFXAtPart("Chara", soundName, parentPart or ctx.Root, lifetime or 2)
end

function CharaMoveUtil.PlayMoveVFX(ctx, moveName, targetCharacter, targetRoot)
	if not ctx or not ctx.VFXService then return end
	if not ctx.VFXService.PlayCharacterMoveVFX then return end

	ctx.VFXService:PlayCharacterMoveVFX(ctx.Character, moveName, targetCharacter, targetRoot)
end

return CharaMoveUtil
