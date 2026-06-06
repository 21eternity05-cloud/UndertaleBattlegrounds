local MovesFolder = script.Parent:WaitForChild("Moves")

local GlitchtaleFriskMoves = {}
GlitchtaleFriskMoves.__index = GlitchtaleFriskMoves

function GlitchtaleFriskMoves.new(config)
	local self = setmetatable({}, GlitchtaleFriskMoves)

	self.Config = config

	self.Slots = {
		Move1 = "DeterminationSlash",
		Move2 = "JusticeBurst",
		Move3 = "SoulDash",
		Move4 = "ResetCounter",
		Ultimate = "DeterminationOverload",
	}

	self.Moves = {
		DeterminationSlash = require(MovesFolder:WaitForChild("DeterminationSlash")),
		JusticeBurst = require(MovesFolder:WaitForChild("JusticeBurst")),
		SoulDash = require(MovesFolder:WaitForChild("SoulDash")),
		ResetCounter = require(MovesFolder:WaitForChild("ResetCounter")),
		DeterminationOverload = require(MovesFolder:WaitForChild("DeterminationOverload")),
	}

	return self
end

return GlitchtaleFriskMoves
