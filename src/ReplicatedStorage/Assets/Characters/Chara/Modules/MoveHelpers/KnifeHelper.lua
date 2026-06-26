local KnifeHelper = {}

function KnifeHelper.GetFlatForward(root)
	local forward = root.CFrame.LookVector
	forward = Vector3.new(forward.X, 0, forward.Z)

	if forward.Magnitude < 0.05 then
		return Vector3.new(0, 0, -1)
	end

	return forward.Unit
end

function KnifeHelper.BuildDashHitbox(moveData, offset)
	local hitbox = moveData and moveData.Hitbox or {}

	return {
		Radius = hitbox.Radius,
		Offset = offset or CFrame.new(),
	}
end

function KnifeHelper.StopKnifeAnimation(ctx, delayTime)
	task.delay(delayTime or 0, function()
		if not ctx.Character or not ctx.Character.Parent then return end
		if not ctx.StateService or not ctx.StateService.AnimationService then return end

		ctx.StateService.AnimationService:StopCharacterAnimationByName(
			ctx.Character,
			(ctx.MoveData and ctx.MoveData.AnimationName) or "KnifeDash",
			0.05
		)
	end)
end

return KnifeHelper
