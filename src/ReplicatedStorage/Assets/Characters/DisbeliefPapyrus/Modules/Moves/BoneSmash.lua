local SpineWall = {
	DisplayName = "Spine Wall",
	AnimationName = "SpineWall",

	Cooldown = 1,
	Duration = 1,
	LockTime = 0.7,
	MaxLockTime = 1.25,
	HitDelay = 0.35,

	Damage = 9,
	Stun = 0.9,
	KnockbackPreset = "PresetKnockback",
	PresetKnockbackSpeed = 70,
	PresetKnockbackUpward = 24,
	PresetKnockbackDuration = 0.32,
	PresetKnockbackMaxForce = 85000,
	Knockback = 70,
	UpwardKnockback = 24,
	KnockbackDuration = 0.32,
	KnockbackMaxForce = 85000,

	Radius = 8,
	Offset = CFrame.new(0, 0, -7),

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

return SpineWall
