local DeterminationOverload = {
	DisplayName = "Determination Overload",
	AnimationName = "DeterminationOverload",

	Cooldown = 1,
	Duration = 1.35,
	LockTime = 1,
	MaxLockTime = 1.6,
	HitDelay = 0.45,

	Damage = 18,
	Stun = 1.25,
	KnockbackPreset = "PresetKnockback",
	PresetKnockbackSpeed = 92,
	PresetKnockbackUpward = 48,
	PresetKnockbackDuration = 0.38,
	PresetKnockbackMaxForce = 100000,
	Knockback = 92,
	UpwardKnockback = 48,
	KnockbackDuration = 0.38,
	KnockbackMaxForce = 100000,

	Radius = 10,
	Offset = CFrame.new(0, 0, -8),

	Blockable = true,
	Guardbreak = true,
	GuardbreakStun = 1.6,
	CanBeCountered = true,
	HitCancelsTarget = true,
	CancelableByHit = true,

	HasArmor = true,
	ArmorStart = 0.2,
	ArmorEnd = 0.85,
	ArmorDamageReduction = 0.5,
	ArmorPreventsStun = true,
	ArmorPreventsKnockback = true,
	ArmorPreventsHitCancel = true,
}

return DeterminationOverload
