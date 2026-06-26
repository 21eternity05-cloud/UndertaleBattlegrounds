local SlashHelper = {}

function SlashHelper.BuildSlashHitbox(radius, offset)
	return {
		Radius = radius,
		Offset = offset or CFrame.new(0, 0, -5),
	}
end

function SlashHelper.CloneAttackData(moveData, overrides)
	local attackData = {}

	for key, value in pairs(moveData or {}) do
		attackData[key] = value
	end

	for key, value in pairs(overrides or {}) do
		attackData[key] = value
	end

	return attackData
end

return SlashHelper
