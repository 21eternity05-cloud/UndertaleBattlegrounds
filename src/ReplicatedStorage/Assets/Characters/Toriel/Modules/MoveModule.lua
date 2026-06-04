local MovesFolder = script.Parent:WaitForChild("Moves")

local TorielMoves = {}
TorielMoves.__index = TorielMoves

function TorielMoves.new(config)
	local self = setmetatable({}, TorielMoves)

	self.Config = config

	self.Slots = {
		Move1 = "MothersGrip",
		Move2 = "FlamePillar",
		Move3 = "GuardianBreak",
		Move4 = "RoyalSnap",
		Ultimate = "RoyalPyre",
	}

	self.Moves = {
		MothersGrip = require(MovesFolder:WaitForChild("MothersGrip")),
		FlamePillar = require(MovesFolder:WaitForChild("FlamePillar")),
		GuardianBreak = require(MovesFolder:WaitForChild("GuardianBreak")),
		RoyalSnap = require(MovesFolder:WaitForChild("RoyalSnap")),
		RoyalPyre = require(MovesFolder:WaitForChild("RoyalPyre")),
	}

	return self
end

return TorielMoves
