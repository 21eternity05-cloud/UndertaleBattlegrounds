local SkinModule = {}

SkinModule.DefaultSkin = "Default"

SkinModule.Skins = {
	Default = {
		DisplayName = "Default",
		Description = "Sans's classic jacket-and-slippers look for bone setups and bad-time pressure.",
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
		Description = "A shadowed Sans variant that keeps the jokes dry and the pressure colder.",
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
		Description = "A loud, colorful Sans style with maximum swagger in the preview room.",
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
		Description = "An Ink-inspired Sans variant with a creative multiverse flair.",
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
		Description = "A deliberately cursed shop entry. The warning is part of the bit.",
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
