local SkinModule = {}

SkinModule.DefaultSkin = "Default"

SkinModule.Skins = {
	Default = {
		DisplayName = "Default",
		Description = "Chara's standard look, built for clean pressure and close-range knife confirms.",
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
		Description = "A darker Chara variant with a sharper, low-light battle silhouette.",
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

	Marin = {
		DisplayName = "Kitagawa Marin",
		Description = "A cosplay-inspired Chara skin with a brighter stage presence.",
		Free = true,
		Cost = 100,
		CharacterModelName = "kitagawa marin",
		WeaponName = "kitchen knife",
		MotorTemplateName = "KnifeMotorTemplate",

		-- Future cosmetic hooks:
		-- VFXColor = Color3.fromRGB(...),
		-- SFXSet = nil,
		-- AuraName = nil,
	},
	XTale = {
		DisplayName = "X!Tale Chara",
		Description = "An alternate-timeline Chara style with a colder, corrupted edge.",
		Free = true,
		Cost = 167,
		CharacterModelName = "xtale chara",
		WeaponName = "xtale purple knife",
		MotorTemplateName = "KnifeMotorTemplate",

		-- Future cosmetic hooks:
		-- VFXColor = Color3.fromRGB(...),
		-- SFXSet = nil,
		-- AuraName = nil,
	},
	StoryFell = {
		DisplayName = "StoryFell Chara",
		Description = "A harsher StoryFell-inspired Chara variant with a ruthless red-and-black mood.",
		Free = true,
		Cost = 167,
		CharacterModelName = "shiftfell chara",
		WeaponName = "RealKnife",
		MotorTemplateName = "KnifeMotorTemplate",

		-- Future cosmetic hooks:
		-- VFXColor = Color3.fromRGB(...),
		-- SFXSet = nil,
		-- AuraName = nil,
	},
}

return SkinModule
