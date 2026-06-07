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

	Marin = {
		DisplayName = "Kitagawa Marin",
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
