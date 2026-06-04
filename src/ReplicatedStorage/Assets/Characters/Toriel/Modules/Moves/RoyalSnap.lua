local RoyalSnap = {
	DisplayName = "Royal Snap",
	AnimationName = "RoyalSnap",

	Cooldown = 6,
	Duration = 0.45,
	LockTime = 0.45,
	MaxLockTime = 0.7,
	HitDelay = 0.14,

	Damage = 7,
	Stun = 0.55,
	Knockback = 38,
	UpwardKnockback = 10,

	Radius = 7,
	Offset = CFrame.new(0, 0, -8),

	Blockable = true,
	CanBeCountered = true,
	HitCancelsTarget = true,
	CancelableByHit = true,
}

return RoyalSnap
