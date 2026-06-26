local SansImpactHelper = {}

function SansImpactHelper.ShakeCharacter(ctx, targetCharacter, magnitude, roughness, duration)
	if not targetCharacter or not targetCharacter.Parent then return end
	if not ctx or not ctx.CinematicService then return end
	if not ctx.CinematicService.ShakeOnce then return end

	pcall(function()
		ctx.CinematicService:ShakeOnce(targetCharacter, magnitude, roughness, duration)
	end)
end

function SansImpactHelper.ImpactFrame(ctx, targetCharacter, duration)
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

function SansImpactHelper.ShakeRadius(ctx, position, radius, magnitude, roughness, duration, options)
	if not ctx or not ctx.CinematicService then return end
	if not ctx.CinematicService.ShakeRadius then return end

	pcall(function()
		ctx.CinematicService:ShakeRadius(position, radius, magnitude, roughness, duration, options)
	end)
end

function SansImpactHelper.PlayImpact(ctx, options)
	options = options or {}

	if options.AttackerShake then
		SansImpactHelper.ShakeCharacter(
			ctx,
			ctx.Character,
			options.AttackerShake.Magnitude,
			options.AttackerShake.Roughness,
			options.AttackerShake.Duration
		)
	end

	if options.Victim and options.VictimShake then
		SansImpactHelper.ShakeCharacter(
			ctx,
			options.Victim,
			options.VictimShake.Magnitude,
			options.VictimShake.Roughness,
			options.VictimShake.Duration
		)
	end

	if options.ImpactFrameDuration then
		SansImpactHelper.ImpactFrame(ctx, ctx.Character, options.ImpactFrameDuration)

		if options.Victim then
			SansImpactHelper.ImpactFrame(ctx, options.Victim, options.ImpactFrameDuration)
		end
	end
end

return SansImpactHelper
