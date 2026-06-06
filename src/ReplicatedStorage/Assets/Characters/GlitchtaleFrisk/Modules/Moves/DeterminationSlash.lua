local DeterminationSlash = {
	DisplayName = "Determination Slash",
	AnimationName = "DeterminationSlash",

	Cooldown = 1,
	Duration = 0.8,
	LockTime = 0.55,
	MaxLockTime = 1.05,
	HitDelay = 0.18,

	Damage = 8,
	Stun = 0.8,
	KnockbackPreset = "PresetKnockback",
	PresetKnockbackSpeed = 56,
	PresetKnockbackUpward = 18,
	PresetKnockbackDuration = 0.25,
	PresetKnockbackMaxForce = 80000,
	Knockback = 56,
	UpwardKnockback = 18,
	KnockbackDuration = 0.25,
	KnockbackMaxForce = 80000,

	Radius = 7,
	Offset = CFrame.new(0, 0, -5.75),

	Blockable = true,
	Guardbreak = false,
	CanBeCountered = true,
	HitCancelsTarget = true,
	CancelableByHit = true,

	HasArmor = false,
	ArmorStart = 0,
	ArmorEnd = 0,
	ArmorDamageReduction = 0,
	ArmorPreventsStun = false,
	ArmorPreventsKnockback = false,
	ArmorPreventsHitCancel = false,
}

return DeterminationSlash
