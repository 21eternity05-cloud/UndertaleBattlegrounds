local SkinModule = {}

SkinModule.DefaultSkin = "Default"

SkinModule.Skins = {
	Default = {
		DisplayName = "Default",
		Free = true,
		Cost = 0,
		CharacterModelName = "Default",

		WeaponName = nil,
		MotorTemplateName = nil,
		Weapons = nil,

		-- Future customization hooks:
		-- VFXColor = nil,
		-- SFXSet = nil,
		-- AuraName = nil,
	},

	DarkMode = {
		DisplayName = "Dark Mode",
		Free = false,
		Cost = 10,
		CharacterModelName = "DarkMode",
		WeaponName = nil,
		MotorTemplateName = nil,
		Weapons = nil,

		-- Future cosmetic hooks:
		-- VFXColor = Color3.fromRGB(...),
		-- SFXSet = nil,
		-- AuraName = nil,
	},
}

return SkinModule
