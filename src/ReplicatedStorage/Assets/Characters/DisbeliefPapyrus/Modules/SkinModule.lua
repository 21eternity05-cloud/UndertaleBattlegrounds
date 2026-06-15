local SkinModule = {}

SkinModule.DefaultSkin = "Default"

SkinModule.Skins = {
	Default = {
		DisplayName = "Default",
		Description = "Papyrus pushed past his limit, carrying a broken resolve into every exchange.",
		Free = true,
		Cost = 0,
		CharacterModelName = "Disbeilef Pap",

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
