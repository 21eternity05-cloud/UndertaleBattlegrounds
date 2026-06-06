local CombatConfig = {}

CombatConfig.DataStoreName = "UTBG_PlayerData_v1"

-- PvP kill reward later. Keep 0 for now while testing.
CombatConfig.KillDustReward = 0

-- Test dummy reward.
CombatConfig.RespawnDummyKillDustReward = 1

CombatConfig.KillBannerVerbs = {
	"erased",
	"sent to the Hollow Route",
	"judged",
	"shattered",
	"overwrote",
	"combo ended",
}

CombatConfig.FinalM1 = 5

CombatConfig.M1ResetTime = 1.25
CombatConfig.AirComboTime = 2.6
CombatConfig.JumpLockAfterM1 = 0.5

CombatConfig.DefaultWalkSpeed = 16
CombatConfig.DefaultJumpPower = 50
CombatConfig.DefaultJumpHeight = 7.2

CombatConfig.DebugHitboxes = false
CombatConfig.DebugKnockback = false
CombatConfig.DebugDamageNumbers = false
CombatConfig.DebugEnabled = false

CombatConfig.PostM5M1Immunity = 1

-- Ultimate meter
CombatConfig.UltMax = 100

CombatConfig.UltDamageDealtMultiplier = 0.7
CombatConfig.UltDamageTakenMultiplier = 0.35

CombatConfig.UltGuardbreakGain = 8
CombatConfig.UltCounterGain = 10
CombatConfig.UltComboEnderGain = 5
CombatConfig.UltKillGain = 15

-- Keep true while testing on TestDummies.
-- Turn false later for real PvP balance.
CombatConfig.AllowDummyUltGain = true

CombatConfig.DefaultCharacterName = "Chara"

CombatConfig.StartingDust = 0
CombatConfig.TorielDustCost = 2500

-- Test dummy values
CombatConfig.TestDummyAttackRange = 8
CombatConfig.TestDummyAttackInterval = 0.36
CombatConfig.TestDummyComboPause = 1.5
CombatConfig.TestDummyRespawnTime = 1.5
CombatConfig.TestDummyHealth = 100000
CombatConfig.RespawnDummyHealth = 100

CombatConfig.ValidCharacters = {
	Chara = true,
	Sans = true,
	Toriel = true,
	DisbeliefPapyrus = true,
	GlitchtaleFrisk = true,
}

CombatConfig.AssetsFolderName = "Assets"
CombatConfig.UniversalFolderName = "Universal"
CombatConfig.CharactersFolderName = "Characters"

CombatConfig.UniversalAnimations = {
	Hitstun = {
		"Hitstun1",
		"Hitstun2",
		"Hitstun3",
		"Hitstun4",
	},

	DownslamAir = "DownslamAir",
	DownslamSplat = "DownslamSplat",
	BlockBreak = "BlockBreak",
}

CombatConfig.M1Animations = {
	[1] = "M1",
	[2] = "M2",
	[3] = "M3",
	[4] = "M4",
	[5] = "M5",

	Uptilt = "Uptilt",
	Downslam = "Downslam",
}

CombatConfig.BlockAnimation = "Block"

CombatConfig.M1Data = {
	[1] = {
		Damage = 4,
		Stun = 0.78,
		Cooldown = 0.30,
		HitDelay = 0.08,

		Radius = 7.5,
		Offset = CFrame.new(0, 0, -6.4),

		CarryDuration = 0.30,
		VictimPushSpeed = 20,
		AttackerChaseSpeed = 22,

		YHoldDuration = 0.5,
	},

	[2] = {
		Damage = 4,
		Stun = 0.8,
		Cooldown = 0.30,
		HitDelay = 0.08,

		Radius = 7.5,
		Offset = CFrame.new(0, 0, -6.4),

		CarryDuration = 0.30,
		VictimPushSpeed = 20,
		AttackerChaseSpeed = 22,

		YHoldDuration = 0.5,
	},

	[3] = {
		Damage = 5,
		Stun = 0.85,
		Cooldown = 0.32,
		HitDelay = 0.09,

		Radius = 7.5,
		Offset = CFrame.new(0, 0, -6.5),

		CarryDuration = 0.32,
		VictimPushSpeed = 20,
		AttackerChaseSpeed = 22,

		YHoldDuration = 0.5,
	},

	[4] = {
		Damage = 5,
		Stun = 0.88,
		Cooldown = 0.32,
		HitDelay = 0.09,

		Radius = 7.5,
		Offset = CFrame.new(0, 0, -6.5),

		CarryDuration = 0.32,
		VictimPushSpeed = 20,
		AttackerChaseSpeed = 22,

		YHoldDuration = 0.5,
	},

	[5] = {
		Damage = 9,
		Stun = 1.05,
		Cooldown = 0.56,
		HitDelay = 0.12,

		Radius = 7.5,
		Offset = CFrame.new(0, 0, -6.6),

		-- M5 should feel like a strong combo finisher.
		-- Target feel: further + higher launch.
		KnockbackPreset = "PresetKnockback",

		PresetKnockbackSpeed = 76,
		PresetKnockbackUpward = 36,
		PresetKnockbackDuration = 0.34,
		PresetKnockbackMaxForce = 80000,

		-- Backward compatibility for older callers.
		Knockback = 76,
		UpwardKnockback = 36,
		KnockbackDuration = 0.34,
		KnockbackMaxForce = 80000,

		Guardbreak = true,
		GuardbreakStun = 1.4,
	},

	Uptilt = {
		Damage = 1,
		Stun = 1,
		Cooldown = 0.42,
		MoveCooldown = 0.8,
		HitDelay = 0.1,

		Radius = 7.5,
		Offset = CFrame.new(0, 1.5, -6.4),

		RawRadius = 5.25,
		RawOffset = CFrame.new(0, 1, -4.8),

		ComboRadius = 7.5,
		ComboOffset = CFrame.new(0, 1.5, -6.4),

		LiftHeight = 20,
		LiftDuration = 0.5,

		MinHorizontalSpacing = 4,

		UptiltResponsiveness = 35,
		UptiltMaxForce = 100000,
		UptiltMaxVelocity = 55,

		PostLiftYHold = 0.4,
	},

	Downslam = {
		Damage = 6,
		Cooldown = 0.62,
		HitDelay = 0.12,

		Radius = 7.5,
		Offset = CFrame.new(0, -1.1, -6.5),

		-- Standard downslam preset.
		-- Downslam should force the target downward, stun them in the air,
		-- and end in ground splat when they hit the floor.
		KnockbackPreset = "Downslam",

		DownForwardSpeed = 28,
		DownSpeed = -72,
		DownLaunchMaxForce = 85000,

		AirStunMax = 1.5,
		GroundSplatStun = 0.65,

		SplatPartLifetime = 0.35,
		SplatPartSize = Vector3.new(8, 0.25, 8),
	},
}

return CombatConfig
