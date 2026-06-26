local BlueSoulHelper = {}

function BlueSoulHelper.ClearCombatMovement(ctx, attackerRoot, victimRoot)
	if not ctx or not ctx.MovementService then
		return
	end

	if ctx.MovementService.ClearCombatMovementControllers then
		if attackerRoot then
			ctx.MovementService:ClearCombatMovementControllers(attackerRoot)
		end

		if victimRoot then
			ctx.MovementService:ClearCombatMovementControllers(victimRoot)
		end

		return
	end

	if ctx.MovementService.StopCarryController then
		if attackerRoot then
			ctx.MovementService:StopCarryController(attackerRoot)
		end

		if victimRoot then
			ctx.MovementService:StopCarryController(victimRoot)
		end
	end

	if ctx.MovementService.StopYHoldController then
		if attackerRoot then
			ctx.MovementService:StopYHoldController(attackerRoot)
		end

		if victimRoot then
			ctx.MovementService:StopYHoldController(victimRoot)
		end
	end
end

function BlueSoulHelper.ReleaseBlueSoulLock(_, targetRoot)
	if targetRoot and targetRoot.Parent then
		targetRoot.AssemblyAngularVelocity = Vector3.zero
	end
end

return BlueSoulHelper
