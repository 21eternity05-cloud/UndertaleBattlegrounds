local ResetCounter = {
	DisplayName = "Reset Counter",
	AnimationName = "ResetCounter",

	Cooldown = 1,
	Duration = 0.8,
	LockTime = 0.8,
	MaxLockTime = 1.05,
	HitDelay = 0.12,

	Damage = 7,
	Stun = 1,
	KnockbackPreset = "PresetKnockback",
	PresetKnockbackSpeed = 58,
	PresetKnockbackUpward = 28,
	PresetKnockbackDuration = 0.28,
	PresetKnockbackMaxForce = 80000,
	Knockback = 58,
	UpwardKnockback = 28,
	KnockbackDuration = 0.28,
	KnockbackMaxForce = 80000,

	Radius = 6,
	Offset = CFrame.new(0, 0, -4.5),

	Blockable = false,
	Guardbreak = false,
	CanBeCountered = false,
	IsCounter = true,
	CounterWindow = 0.45,
	HitCancelsTarget = true,
	CancelableByHit = false,

	HasArmor = false,
	ArmorStart = 0,
	ArmorEnd = 0,
	ArmorDamageReduction = 0,
	ArmorPreventsStun = false,
	ArmorPreventsKnockback = false,
	ArmorPreventsHitCancel = false,
}

return ResetCounter
