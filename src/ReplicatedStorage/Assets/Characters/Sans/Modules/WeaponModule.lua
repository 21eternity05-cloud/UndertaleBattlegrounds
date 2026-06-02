local SansWeapon = {}
SansWeapon.__index = SansWeapon

function SansWeapon.new(config, characterFolder)
	local self = setmetatable({}, SansWeapon)
	self.Config = config
	self.CharacterFolder = characterFolder
	return self
end

function SansWeapon:Equip(character)
	-- Sans has no held weapon.
end

return SansWeapon