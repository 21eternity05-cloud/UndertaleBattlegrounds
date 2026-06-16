
local MovesFolder = script.Parent:WaitForChild("Moves")

local DisbeliefPapyrusMoves = {}
DisbeliefPapyrusMoves.__index = DisbeliefPapyrusMoves

function DisbeliefPapyrusMoves.new(config)
	local self = setmetatable({}, DisbeliefPapyrusMoves)

	self.Config = config

	self.SlotSets = {
		Base = {
			Move1 = "WeakBoneShot",
			Move2 = "BoneWall",
			Move3 = "DisbeliefCounter",
			Move4 = "BrokenBlaster",
			Ultimate = "EnterDisbeliefPhase2",
		},

		Phase2 = {
			Move1 = "BrokenBoneRush",
			Move2 = "YoureBlueNow",
			Move3 = "TwinBoneThrow",
			Move4 = "BlueTrap",
			Ultimate = "DisbeliefFinale",
		},
	}

	self.Slots = self.SlotSets.Base

	self.Moves = {
		WeakBoneShot = require(MovesFolder:WaitForChild("WeakBoneShot")),
		BoneWall = require(MovesFolder:WaitForChild("BoneWall")),
		DisbeliefCounter = require(MovesFolder:WaitForChild("DisbeliefCounter")),
		BrokenBlaster = require(MovesFolder:WaitForChild("BrokenBlaster")),
		EnterDisbeliefPhase2 = require(MovesFolder:WaitForChild("EnterDisbeliefPhase2")),

		BrokenBoneRush = require(MovesFolder:WaitForChild("BrokenBoneRush")),
		YoureBlueNow = require(MovesFolder:WaitForChild("YoureBlueNow")),
		TwinBoneThrow = require(MovesFolder:WaitForChild("TwinBoneThrow")),
		BlueTrap = require(MovesFolder:WaitForChild("BlueTrap")),
		DisbeliefFinale = require(MovesFolder:WaitForChild("DisbeliefFinale")),
	}

	return self
end

return DisbeliefPapyrusMoves
