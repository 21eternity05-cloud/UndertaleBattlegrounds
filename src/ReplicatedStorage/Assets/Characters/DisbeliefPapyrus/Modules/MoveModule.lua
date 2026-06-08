
local MovesFolder = script.Parent:WaitForChild("Moves")

local DisbeliefPapyrusMoves = {}
DisbeliefPapyrusMoves.__index = DisbeliefPapyrusMoves

function DisbeliefPapyrusMoves.new(config)
	local self = setmetatable({}, DisbeliefPapyrusMoves)

	self.Config = config

	self.Slots = {
		Move1 = "WeakBoneShot",
		Move2 = "BoneWall",
		Move3 = "DisbeliefCounter",
		Move4 = "BrokenBlaster",
		Ultimate = "LastStand",
	}

	self.Moves = {
		WeakBoneShot = require(MovesFolder:WaitForChild("WeakBoneShot")),
		BoneWall = require(MovesFolder:WaitForChild("BoneWall")),
		DisbeliefCounter = require(MovesFolder:WaitForChild("DisbeliefCounter")),
		BrokenBlaster = require(MovesFolder:WaitForChild("BrokenBlaster")),
		LastStand = require(MovesFolder:WaitForChild("LastStand")),
	}

	return self
end

return DisbeliefPapyrusMoves