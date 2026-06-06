local SkinModule = {}

SkinModule.DefaultSkin = "Default"

SkinModule.Skins = {
	Default = {
		DisplayName = "Default",
		Free = true,
		Cost = 0,
		CharacterModelName = "Default",

		WeaponName = "BoneStaff",
		MotorTemplateName = "BoneStaffMotorTemplate",
		Weapons = nil,

		-- Future customization hooks:
		-- VFXColor = nil,
		-- SFXSet = nil,
		-- AuraName = nil,
	},
}

return SkinModule
