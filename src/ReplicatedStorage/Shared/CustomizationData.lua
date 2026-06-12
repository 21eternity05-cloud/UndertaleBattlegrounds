local CustomizationData = {
	Categories = {
		Morphs = {
			Enabled = false,
			Description = "Reserved for future character morphs. Roblox avatars remain active for now.",
			Items = {},
		},

		Titles = {
			Enabled = true,
			ItemsSource = "TitleData",
		},

		Auras = {
			Enabled = false,
			Items = {},
		},

		Skins = {
			Enabled = false,
			Items = {},
		},

		Emotes = {
			Enabled = false,
			Items = {},
		},
	},

	DefaultEquipped = {
		Title = "None",
		Morph = nil,
		Aura = nil,
		Skin = nil,
		Emote = nil,
	},
}

return CustomizationData
