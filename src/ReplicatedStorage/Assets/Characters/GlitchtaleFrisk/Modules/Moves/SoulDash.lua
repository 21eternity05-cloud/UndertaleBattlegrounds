local SoulDash = {
	DisplayName = "Soul Dash",
	AnimationName = "SoulDash",

	Cooldown = 1,
	Duration = 0.75,
	LockTime = 0.45,
	MaxLockTime = 1,
	HitDelay = 0.16,

	Damage = 7,
	Stun = 0.75,
	KnockbackPreset = "PresetKnockback",
	PresetKnockbackSpeed = 64,
	PresetKnockbackUpward = 18,
	PresetKnockbackDuration = 0.24,
	PresetKnockbackMaxForce = 80000,
	Knockback = 64,
	UpwardKnockback = 18,
	KnockbackDuration = 0.24,
	KnockbackMaxForce = 80000,

	Radius = 6.5,
	Offset = CFrame.new(0, 0, -6),

	Blockable = true,
	Guardbreak = false,
	CanBeCountered = true,
	HitCancelsTarget = true,
	CancelableByHit = true,

	HasArmor = true,
	ArmorStart = 0.08,
	ArmorEnd = 0.36,
	ArmorDamageReduction = 0.3,
	ArmorPreventsStun = true,
	ArmorPreventsKnockback = true,
	ArmorPreventsHitCancel = true,
}

return SoulDash
