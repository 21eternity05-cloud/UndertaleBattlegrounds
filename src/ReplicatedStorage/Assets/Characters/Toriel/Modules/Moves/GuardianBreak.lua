local GuardianBreak = {
	DisplayName = "Guardian Break",
	AnimationName = "GuardianBreak",

	Cooldown = 12,
	Duration = 0.95,
	LockTime = 0.95,
	MaxLockTime = 1.2,
	HitDelay = 0.42,

	Damage = 16,
	Stun = 1.1,
	Knockback = 110,
	UpwardKnockback = 34,
	KnockbackDuration = 0.28,

	Radius = 6.5,
	Offset = CFrame.new(0, 0, -5.5),

	Blockable = true,
	Guardbreak = true,
	GuardbreakStun = 1.5,
	CanBeCountered = true,
	HitCancelsTarget = true,
	CancelableByHit = true,

	HasArmor = true,
	ArmorStart = 0.18,
	ArmorEnd = 0.62,
	ArmorDamageReduction = 0.45,
	ArmorPreventsStun = true,
	ArmorPreventsKnockback = true,
	ArmorPreventsHitCancel = true,
}

return GuardianBreak
