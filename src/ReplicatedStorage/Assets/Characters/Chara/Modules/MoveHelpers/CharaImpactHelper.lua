local CharaImpactHelper = {}

function CharaImpactHelper.ShakeCharacter(ctx, targetCharacter, magnitude, roughness, duration)
	if not targetCharacter or not targetCharacter.Parent then return end
	if not ctx or not ctx.CinematicService then return end
	if not ctx.CinematicService.ShakeOnce then return end

	pcall(function()
		ctx.CinematicService:ShakeOnce(targetCharacter, magnitude, roughness, duration)
	end)
end

function CharaImpactHelper.HitFlash(ctx, targetCharacter, duration)
	if not targetCharacter or not targetCharacter.Parent then return end
	if not ctx or not ctx.CinematicService then return end
	if not ctx.CinematicService.HitFlash and not ctx.CinematicService.ImpactFrame then return end

	local hitFlash = ctx.CinematicService.HitFlash or ctx.CinematicService.ImpactFrame

	local success = pcall(function()
		hitFlash(ctx.CinematicService, targetCharacter, duration)
	end)

	if success then
		return
	end

	pcall(function()
		hitFlash(ctx.CinematicService, targetCharacter, {
			Duration = duration,
		})
	end)
end

function CharaImpactHelper.ImpactFrame(...)
	return CharaImpactHelper.HitFlash(...)
end

return CharaImpactHelper
