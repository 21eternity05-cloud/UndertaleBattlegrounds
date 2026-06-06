local BlueSlam = {
	DisplayName = "Blue Slam",
	AnimationName = "BlueSlam",

	Cooldown = 1,
	Duration = 0.9,
	LockTime = 0.65,
	MaxLockTime = 1.15,
	HitDelay = 0.28,

	Damage = 10,
	Stun = 0.95,
	KnockbackPreset = "PresetKnockback",
	PresetKnockbackSpeed = 62,
	PresetKnockbackUpward = 42,
	PresetKnockbackDuration = 0.3,
	PresetKnockbackMaxForce = 85000,
	Knockback = 62,
	UpwardKnockback = 42,
	KnockbackDuration = 0.3,
	KnockbackMaxForce = 85000,

	Radius = 7.5,
	Offset = CFrame.new(0, 0.5, -6.5),

	Blockable = true,
	Guardbreak = false,
	CanBeCountered = true,
	HitCancelsTarget = true,
	CancelableByHit = true,

	HasArmor = true,
	ArmorStart = 0.18,
	ArmorEnd = 0.55,
	ArmorDamageReduction = 0.35,
	ArmorPreventsStun = true,
	ArmorPreventsKnockback = true,
	ArmorPreventsHitCancel = true,
}

return BlueSlam
