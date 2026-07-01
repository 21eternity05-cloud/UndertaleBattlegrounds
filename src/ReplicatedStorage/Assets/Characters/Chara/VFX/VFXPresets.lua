return {
	ImpactFrames = {
		SoulBurst = {
			Duration = 0.12,
			UseUltColor = true,
			BackgroundColor = Color3.fromRGB(0, 0, 0),
			FlashColor = nil,
			HighlightColor = nil,
			BackgroundTransparency = 0.12,
			FlashTransparency = 0.18,
			FOVPunch = 4,
			ShakeMagnitude = 0.8,
			Contrast = 0.35,
			Saturation = -0.25,
			Brightness = 0.1,
		},
	},

	AfterImages = {
		Default = {
			Lifetime = 0.35,
			FadeTime = 0.25,
			Transparency = 0.55,
			UseUltColor = true,
			Material = Enum.Material.Neon,
			MaxParts = 16,
			IncludeWeapons = false,
		},

		SlashBarrageHit = {
			Lifetime = 0.28,
			FadeTime = 0.22,
			Transparency = 0.58,
			UseUltColor = true,
			Material = Enum.Material.Neon,
			MaxParts = 14,
			IncludeWeapons = true,
		},
	},
}
