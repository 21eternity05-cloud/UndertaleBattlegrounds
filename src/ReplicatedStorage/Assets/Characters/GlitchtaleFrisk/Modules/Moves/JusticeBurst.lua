local JusticeBurst = {
	DisplayName = "Justice Burst",
	AnimationName = "JusticeBurst",

	Cooldown = 1,
	Duration = 0.9,
	LockTime = 0.65,
	MaxLockTime = 1.15,
	HitDelay = 0.3,

	Damage = 10,
	Stun = 0.9,
	KnockbackPreset = "PresetKnockback",
	PresetKnockbackSpeed = 66,
	PresetKnockbackUpward = 30,
	PresetKnockbackDuration = 0.3,
	PresetKnockbackMaxForce = 85000,
	Knockback = 66,
	UpwardKnockback = 30,
	KnockbackDuration = 0.3,
	KnockbackMaxForce = 85000,

	Radius = 8,
	Offset = CFrame.new(0, 0, -6.75),

	Blockable = true,
	Guardbreak = true,
	GuardbreakStun = 1.25,
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

return JusticeBurst
