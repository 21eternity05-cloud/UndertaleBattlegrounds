local RoyalPyre = {
	DisplayName = "Royal Pyre",
	AnimationName = "RoyalPyre",

	Cooldown = 35,
	Duration = 2.5,
	LockTime = 2.5,
	MaxLockTime = 3,
	HitDelay = 1.1,

	Damage = 90,
	AwardsUlt = false,
	Stun = 1.4,
	Knockback = 180,
	UpwardKnockback = 90,
	KnockbackDuration = 0.35,

	Radius = 18,
	Offset = CFrame.new(0, 0, -12),

	Blockable = false,
	CanBeBlocked = false,
	Unblockable = true,
	CanBeCountered = false,
	HitCancelsTarget = true,
	CancelableByHit = false,

	HasIFrames = true,
	IFrameStart = 0,
	IFrameEnd = 2.5,
}

return RoyalPyre
