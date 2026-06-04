local FlamePillar = {
	DisplayName = "Flame Pillar",
	AnimationName = "FlamePillar",

	Cooldown = 9,
	Duration = 0.85,
	LockTime = 0.65,
	MaxLockTime = 1.1,
	HitDelay = 0.35,

	Damage = 11,
	Stun = 0.8,
	Knockback = 45,
	UpwardKnockback = 48,

	Radius = 8,
	Offset = CFrame.new(0, 0, -7),

	Blockable = true,
	CanBeCountered = true,
	HitCancelsTarget = true,
	CancelableByHit = true,
}

return FlamePillar
