local SansImpactHelper = {}

function SansImpactHelper.ShakeCharacter(ctx, targetCharacter, magnitude, roughness, duration)
	if not targetCharacter or not targetCharacter.Parent then return end
	if not ctx or not ctx.CinematicService then return end
	if not ctx.CinematicService.ShakeOnce then return end

	pcall(function()
		ctx.CinematicService:ShakeOnce(targetCharacter, magnitude, roughness, duration)
	end)
end

function SansImpactHelper.HitFlash(ctx, targetCharacter, duration)
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

function SansImpactHelper.ImpactFrame(...)
	return SansImpactHelper.HitFlash(...)
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

	local hitFlashDuration = options.HitFlashDuration or options.ImpactFrameDuration
	if hitFlashDuration then
		SansImpactHelper.HitFlash(ctx, ctx.Character, hitFlashDuration)

		if options.Victim then
			SansImpactHelper.HitFlash(ctx, options.Victim, hitFlashDuration)
		end
	end
end

return SansImpactHelper
