local SkinModule = {}

SkinModule.DefaultSkin = "Default"

SkinModule.Skins = {
	Default = {
		DisplayName = "Default",
		Description = "Toriel's default royal guardian look, warm at first glance and dangerous up close.",
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
}

return SkinModule
