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
		Fresh = {
		DisplayName = "Fresh Sans",
		Free = true,
		Cost = 10,
		CharacterModelName = "Underfresh Sans",
		WeaponName = nil,
		MotorTemplateName = nil,
		Weapons = nil,

		-- Future cosmetic hooks:
		-- VFXColor = Color3.fromRGB(...),
		-- SFXSet = nil,
		-- AuraName = nil,
	},
		Ink = {
		DisplayName = "Ink Sans",
		Free = true,
		Cost = 10,
		CharacterModelName = "Inktale Sans",
		WeaponName = nil,
		MotorTemplateName = nil,
		Weapons = nil,

		-- Future cosmetic hooks:
		-- VFXColor = Color3.fromRGB(...),
		-- SFXSet = nil,
		-- AuraName = nil,
	},
		 dontworry= {
		DisplayName = "AHH DONT BUY",
		Free = false,
		Cost = 6767676767676767,
		CharacterModelName = "",
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
