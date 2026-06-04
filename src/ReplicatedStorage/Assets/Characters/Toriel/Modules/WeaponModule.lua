local TorielWeapon = {}
TorielWeapon.__index = TorielWeapon

function TorielWeapon.new(config, characterFolder)
	local self = setmetatable({}, TorielWeapon)

	self.Config = config
	self.CharacterFolder = characterFolder

	return self
end

function TorielWeapon:Equip(character)
	-- Toriel uses the player's Roblox avatar for now. Future morph/hand-fire assets can attach here.
	if character then
		character:SetAttribute("WeaponStyle", "FireFists")
	end
end

return TorielWeapon
