local SkinModule = {}

SkinModule.DefaultSkin = "Default"

SkinModule.Skins = {
	Default = {
		DisplayName = "Default",
		Free = true,
		CharacterModelName = "Default",
		WeaponName = "RealKnife",
		MotorTemplateName = "KnifeMotorTemplate",

		-- Future cosmetic hooks:
		-- VFXColor = nil,
		-- SFXSet = nil,
		-- AuraName = nil,
	},

	DarkMode = {
		DisplayName = "Dark Mode",
		Free = false,
		Cost = 10,
		CharacterModelName = "DarkMode",
		WeaponName = "WornKnife",
		MotorTemplateName = "KnifeMotorTemplate",

		-- Future cosmetic hooks:
		-- VFXColor = Color3.fromRGB(...),
		-- SFXSet = nil,
		-- AuraName = nil,
	},
}

return SkinModule
