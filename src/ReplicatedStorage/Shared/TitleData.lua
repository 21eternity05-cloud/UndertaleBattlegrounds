return {
	None = {
		DisplayName = "None",
		Description = "No title equipped.",
		Starter = true,
		Hidden = false,
		Order = 0,
	},

	Bonehead = {
		DisplayName = "Bonehead",
		Description = "Get 1 kill.",
		Starter = false,
		Hidden = false,
		Order = 10,
		UnlockType = "Kills",
		RequiredKills = 1,
	},

	RouteWitness = {
		DisplayName = "Route Witness",
		Description = "Find a Hollow Route lore fragment.",
		Starter = false,
		Hidden = true,
		Order = 20,
		UnlockType = "Lore",
	},

	Determined = {
		DisplayName = "Determined",
		Description = "Get kills as Chara.",
		Starter = false,
		Hidden = false,
		Order = 30,
		UnlockType = "CharacterKills",
		CharacterName = "Chara",
		RequiredKills = 10,
	},

	BadTime = {
		DisplayName = "Bad Time",
		Description = "Get kills as Sans.",
		Starter = false,
		Hidden = false,
		Order = 40,
		UnlockType = "CharacterKills",
		CharacterName = "Sans",
		RequiredKills = 10,
	},
}
