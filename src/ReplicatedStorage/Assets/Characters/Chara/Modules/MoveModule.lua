local MovesFolder = script.Parent:WaitForChild("Moves")

local CharaMoves = {}
CharaMoves.__index = CharaMoves

function CharaMoves.new(config)
	local self = setmetatable({}, CharaMoves)

	self.Config = config

	self.Slots = {
		Move1 = "KnifeDash",
		Move2 = "SlashBarrage",
		Move3 = "RedSlash",
		Move4 = "KillingIntent",
		Ultimate = "SpecialHell",
	}

	self.Moves = {
		KnifeDash = require(MovesFolder:WaitForChild("KnifeDash")),
		SlashBarrage = require(MovesFolder:WaitForChild("SlashBarrage")),
		RedSlash = require(MovesFolder:WaitForChild("RedSlash")),
		KillingIntent = require(MovesFolder:WaitForChild("KillingIntent")),
		SpecialHell = require(MovesFolder:WaitForChild("SpecialHell")),
		Erase = require(MovesFolder:WaitForChild("Erase")),
	}

	return self
end

return CharaMoves
