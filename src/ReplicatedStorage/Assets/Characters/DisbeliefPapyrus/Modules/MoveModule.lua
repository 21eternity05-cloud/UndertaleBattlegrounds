local MovesFolder = script.Parent:WaitForChild("Moves")

local DisbeliefPapyrusMoves = {}
DisbeliefPapyrusMoves.__index = DisbeliefPapyrusMoves

function DisbeliefPapyrusMoves.new(config)
	local self = setmetatable({}, DisbeliefPapyrusMoves)

	self.Config = config

	self.Slots = {
		Move1 = "BoneRush",
		Move2 = "BlueSlam",
		Move3 = "DisbeliefCounter",
		Move4 = "SpineWall",
		Ultimate = "LastStand",
	}

	self.Moves = {
		BoneRush = require(MovesFolder:WaitForChild("BoneRush")),
		BlueSlam = require(MovesFolder:WaitForChild("BlueSlam")),
		DisbeliefCounter = require(MovesFolder:WaitForChild("DisbeliefCounter")),
		SpineWall = require(MovesFolder:WaitForChild("SpineWall")),
		LastStand = require(MovesFolder:WaitForChild("LastStand")),
	}

	return self
end

return DisbeliefPapyrusMoves
