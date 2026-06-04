local MothersGrip = {
	DisplayName = "Mother's Grip",
	AnimationName = "MothersGrip",

	Cooldown = 7,
	Duration = 0.75,
	LockTime = 0.75,
	MaxLockTime = 1,

	Damage = 9,
	Stun = 0.95,
	Knockback = 70,
	UpwardKnockback = 18,

	Radius = 6,
	Offset = CFrame.new(0, 0, -4.8),

	Blockable = true,
	CanBeCountered = true,
	HitCancelsTarget = true,
	CancelableByHit = true,
}

return MothersGrip
