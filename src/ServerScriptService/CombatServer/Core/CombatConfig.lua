local CombatConfig = {}

CombatConfig.DataStoreName = "UTBG_PlayerData_v1"

-- PvP kill reward later. Keep 0 for now while testing.
CombatConfig.KillDustReward = 10

-- Test dummy reward.
CombatConfig.RespawnDummyKillDustReward = 1

CombatConfig.KillstreakDustBonuses = {
	[3] = 5,
	[5] = 10,
	[10] = 20,
}
CombatConfig.KillstreakRepeatEvery = 5
CombatConfig.KillstreakRepeatBonus = 10

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
CombatConfig.DebugSplatPlaceholders = false

CombatConfig.PostM5M1Immunity = 1

CombatConfig.DisablePassiveHealing = true
CombatConfig.AllowOutOfCombatRegen = false -- placeholder for future out of combat regen system, currently has no effect since passive healing is disabled
CombatConfig.KillCreditWindow = 15
CombatConfig.ResetKillCreditWindow = 15
CombatConfig.HealOnKillAmount = 25

CombatConfig.WallComboPreventionEnabled = true
CombatConfig.WallImpactCheckDuration = 0.35
CombatConfig.WallImpactRayDistance = 3
CombatConfig.WallImpactProtectionDuration = 1.5 --to REALLy discourage wall combos, this has to be pretty long. 
CombatConfig.WallImpactPushAwaySpeed = 18
CombatConfig.WallImpactMinSpeed = 18

-- Ultimate meter
CombatConfig.UltMax = 100

CombatConfig.UltDamageDealtMultiplier = 0.5
CombatConfig.UltDamageTakenMultiplier = 0.25

CombatConfig.UltGuardbreakGain = 6
CombatConfig.UltCounterGain = 8
CombatConfig.UltComboEnderGain = 4
CombatConfig.UltKillGain = 12

-- Keep true while testing on debug/arena dummies.
-- Turn false later for real PvP balance.
CombatConfig.AllowDummyUltGain = true

-- Universal SOUL BURST evasive meter
CombatConfig.SoulBurstMax = 300
CombatConfig.SoulBurstHitGain = 6
CombatConfig.SoulBurstDamageGainMultiplier = 0.5
CombatConfig.SoulBurstStunGainMultiplier = 5
CombatConfig.SoulBurstComboExtenderBonus = 5

CombatConfig.SoulBurstCost = 300
CombatConfig.SoulBurstIFrameDuration = 2.25
CombatConfig.SoulBurstRadius = 15
CombatConfig.SoulBurstDamage = 0
CombatConfig.SoulBurstKnockbackSpeed = 55
CombatConfig.SoulBurstUpwardKnockback = 18
CombatConfig.SoulBurstKnockbackDuration = 0.22
CombatConfig.SoulBurstCooldown = 8

CombatConfig.SoulBurstDebugEnabled = true

CombatConfig.DefaultCharacterName = "Chara"

CombatConfig.SpawnIFrameDuration = 10
CombatConfig.SpawnYOffset = 3
CombatConfig.SpawnEnemyAvoidRadius = 25

CombatConfig.StartingDust = 0

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
		Damage = 2,
		Stun = 0.6,
		Cooldown = 0.42,
		HitDelay = 0.18,

		Radius = 7.5,
		Offset = CFrame.new(0, 0, -6.4),

		CarryDuration = 0.30,
		VictimPushSpeed = 20,
		AttackerChaseSpeed = 22,

		YHoldDuration = 0.5,
	},

	[2] = {
		Damage = 2,
		Stun = 0.6,
		Cooldown = 0.42,
		HitDelay = 0.18,

		Radius = 7.5,
		Offset = CFrame.new(0, 0, -6.4),

		CarryDuration = 0.30,
		VictimPushSpeed = 20,
		AttackerChaseSpeed = 22,

		YHoldDuration = 0.5,
	},

	[3] = {
		Damage = 2,
		Stun = 0.6,
		Cooldown = 0.44,
		HitDelay = 0.19,

		Radius = 7.5,
		Offset = CFrame.new(0, 0, -6.5),

		CarryDuration = 0.32,
		VictimPushSpeed = 20,
		AttackerChaseSpeed = 22,

		YHoldDuration = 0.5,
	},

	[4] = {
		Damage = 2,
		Stun = 0.6,
		Cooldown = 0.44,
		HitDelay = 0.19,

		Radius = 7.5,
		Offset = CFrame.new(0, 0, -6.5),

		CarryDuration = 0.32,
		VictimPushSpeed = 20,
		AttackerChaseSpeed = 22,

		YHoldDuration = 0.5,
	},

	[5] = {
		Damage = 5,
		Stun = 0.5,
		Cooldown = 0.72,
		HitDelay = 0.20,

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
		Stun = 0.7,
		Cooldown = 0.55,
		MoveCooldown = 0.8,
		HitDelay = 0.20,

		Radius = 7.5,
		Offset = CFrame.new(0, 1.5, -6.4),

		RawRadius = 4.25,
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
		Damage = 2,
		Cooldown = 0.70,
		HitDelay = 0.20,

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

function CombatConfig.GetM1HitDelay(comboOrData)
	local data = typeof(comboOrData) == "table" and comboOrData or CombatConfig.M1Data[comboOrData]
	return (data and data.HitDelay) or 0.08
end

function CombatConfig.GetM1Cooldown(comboOrData)
	local data = typeof(comboOrData) == "table" and comboOrData or CombatConfig.M1Data[comboOrData]
	return (data and data.Cooldown) or CombatConfig.TestDummyAttackInterval or 0.36
end

function CombatConfig.GetM1NextInputDelay(comboOrData)
	return CombatConfig.GetM1Cooldown(comboOrData)
end

function CombatConfig.GetM1FinalLock()
	return CombatConfig.GetM1Cooldown(CombatConfig.FinalM1 or 5)
end

return CombatConfig
