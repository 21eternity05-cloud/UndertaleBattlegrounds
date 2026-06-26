local CharaImpactHelper = {}

function CharaImpactHelper.ShakeCharacter(ctx, targetCharacter, magnitude, roughness, duration)
	if not targetCharacter or not targetCharacter.Parent then return end
	if not ctx or not ctx.CinematicService then return end
	if not ctx.CinematicService.ShakeOnce then return end

	pcall(function()
		ctx.CinematicService:ShakeOnce(targetCharacter, magnitude, roughness, duration)
	end)
end

function CharaImpactHelper.ImpactFrame(ctx, targetCharacter, duration)
	if not targetCharacter or not targetCharacter.Parent then return end
	if not ctx or not ctx.CinematicService then return end
	if not ctx.CinematicService.ImpactFrame then return end

	local success = pcall(function()
		ctx.CinematicService:ImpactFrame(targetCharacter, duration)
	end)

	if success then
		return
	end

	pcall(function()
		ctx.CinematicService:ImpactFrame(targetCharacter, {
			Duration = duration,
		})
	end)
end

return CharaImpactHelper
