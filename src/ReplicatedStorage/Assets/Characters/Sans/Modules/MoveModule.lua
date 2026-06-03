local MovesFolder = script.Parent:WaitForChild("Moves")

local SansMoves = {}
SansMoves.__index = SansMoves

function SansMoves.new(config)
	local self = setmetatable({}, SansMoves)

	self.Config = config

	self.Slots = {
		Move1 = "BoneShot",
		Move2 = "BoneZone",
		Move3 = "BlueSnare",
		Move4 = "GasterBlaster",
		Ultimate = "BadTime",
	}

	self.Moves = {
		BoneShot = require(MovesFolder:WaitForChild("BoneShot")),
		BoneZone = require(MovesFolder:WaitForChild("BoneZone")),
		BlueSnare = require(MovesFolder:WaitForChild("BlueSnare")),
		GasterBlaster = require(MovesFolder:WaitForChild("GasterBlaster")),
		BadTime = require(MovesFolder:WaitForChild("BadTime")),
	}

	return self
end

return SansMoves