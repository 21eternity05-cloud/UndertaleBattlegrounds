-- Character visibility:
-- Released = true means public players can see, select, and buy this character.
-- DeveloperOnly = true means dev/admin players may access this character for testing.
-- PublicPreview = true means public players can see this character as COMING SOON, but cannot select or buy it unless Released is true.
-- PublicPreview = false means hide this character from public preview entirely.
local CharacterData = {
	Chara = {
		Id = "Chara",
		DisplayName = "Chara",
		Role = "Rushdown knife fighter",
		Description = "Fast, aggressive pressure with sharp confirms and dangerous close-range punishment.",
		Cost = 0,
		Free = true,
		Released = true,
		DeveloperOnly = false,
		PublicPreview = true,
		Moves = {
			"Knife Dash",
			"Slash Barrage",
			"Red Slash",
			"Killing Intent",
			"Special Hell",
		},
	},

	Sans = {
		Id = "Sans",
		DisplayName = "Sans",
		Role = "Trickster zoner",
		Description = "Projectile pressure, traps, blue magic control, and punishing ultimate confirms.",
		Cost = 0,
		Free = true,
		Released = true,
		DeveloperOnly = false,
		PublicPreview = true,
		Moves = {
			"Bone Shot",
			"Bone Zone",
			"Blue Snare",
			"Gaster Blaster",
			"Bad Time",
		},
	},

	Toriel = {
		Id = "Toriel",
		DisplayName = "Toriel",
		Role = "Protective fire bruiser",
		Description = "A disciplined royal guardian who controls space with fire and punishes careless pressure.",
		Cost = 1,
		Currency = "Dust",
		Free = false,
		Locked = true,
		Released = false,
		DeveloperOnly = true,
		PublicPreview = false,
		Lore = "She enters the Hollow Route because it imitates a child in danger.",
		Moves = {
			"Mother's Grip",
			"Flame Pillar",
			"Guardian Break",
			"Royal Snap",
			"Royal Pyre",
		},
	},

	DisbeliefPapyrus = {
		Id = "DisbeliefPapyrus",
		DisplayName = "Disbelief Papyrus",
		Cost = 35,
		Free = false,
		Released = false,
		DeveloperOnly = true,
		PublicPreview = true,
	},

	GlitchtaleFrisk = {
		Id = "GlitchtaleFrisk",
		DisplayName = "Glitchtale Frisk",
		Cost = 40,
		Free = false,
		Released = false,
		DeveloperOnly = true,
		PublicPreview = true,
	},
}

return CharacterData
