local SkinModule = {}

SkinModule.DefaultSkin = "Default"

SkinModule.Skins = {
	Default = {
		DisplayName = "Default",
		Description = "Frisk's default Glitchtale-inspired loadout with sword, shield, and determination.",
		Free = true,
		Cost = 0,
		CharacterModelName = "Default",

		WeaponName = nil,
		MotorTemplateName = nil,
		Weapons = {
			{
				WeaponName = "GT Frisk Sword",
				MotorTemplateName = "GT Frisk SwordMotorTemplate",
			},
			{
				WeaponName = "GT Frisk Shield",
				MotorTemplateName = "GT Frisk ShieldMotorTemplate",
			},
		},

		-- Future customization hooks:
		-- VFXColor = nil,
		-- SFXSet = nil,
		-- AuraName = nil,
	},
}

return SkinModule
