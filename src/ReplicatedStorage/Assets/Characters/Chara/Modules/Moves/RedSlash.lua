local RedSlash = {
	DisplayName = "Red Slash",
	AnimationName = nil,

	Cooldown = 1,
	Duration = 1.45,
	LockTime = 1.45,
	MaxLockTime = 1.7,

	Damage = 8,
	Stun = 0.65,

	Radius = 5,
	Offset = CFrame.new(0, 0, -4),

	-- Red Slash should feel like M5 knockback,
	-- but with more forward strength.
	-- It should NOT apply knockback on guardbreak.
	KnockbackPreset = "PresetKnockback",

	PresetKnockbackSpeed = 92,
	PresetKnockbackUpward = 36,
	PresetKnockbackDuration = 0.34,
	PresetKnockbackMaxForce = 85000,

	-- Backward compatibility.
	Knockback = 92,
	UpwardKnockback = 36,
	KnockbackDuration = 0.34,
	KnockbackMaxForce = 85000,

	Blockable = true,
	CanBeBlocked = true,
	Unblockable = false,

	Guardbreak = true,
	GuardbreakStun = 1.35,

	CanBeCountered = true,
	HitCancelsTarget = true,

	-- Red Slash should not lose its hitbox just because the user gets touched
	-- during the armored/active section.
	CancelableByHit = false,

	HasIFrames = false,

	HasArmor = true,
	ArmorStart = 0.15,
	ArmorEnd = 1.18,
	ArmorDamageReduction = 0.5,
	ArmorPreventsStun = true,
	ArmorPreventsKnockback = true,
	ArmorPreventsHitCancel = true,
}

local ANIMATION_NAME = "RedSlash"

local WINDUP_TIME = 1
local HITBOX_ACTIVE_TIME = 0.16
local HITBOX_TICK_RATE = 0.04
local ENDLAG_TIME = 0.35

local function copyTable(source)
	local copy = {}

	for key, value in pairs(source or {}) do
		copy[key] = value
	end

	return copy
end

local function makeNoKnockbackHitData(moveData)
	local hitData = copyTable(moveData)

	-- Keep damage/stun/guardbreak/block/counter logic,
	-- but prevent ApplyStandardHit from applying its own movement.
	hitData.KnockbackPreset = nil

	hitData.PresetKnockbackSpeed = nil
	hitData.PresetKnockbackUpward = nil
	hitData.PresetKnockbackDuration = nil
	hitData.PresetKnockbackMaxForce = nil

	hitData.DirectionalSpeed = nil
	hitData.DirectionalDuration = nil
	hitData.DirectionalMaxForce = nil
	hitData.DirectionalYHoldDuration = nil

	hitData.DownForwardSpeed = nil
	hitData.DownSpeed = nil
	hitData.DownLaunchMaxForce = nil

	hitData.Knockback = 0
	hitData.UpwardKnockback = 0
	hitData.KnockbackDuration = 0
	hitData.KnockbackMaxForce = 0

	return hitData
end

local function makeManualKnockbackData(moveData)
	local knockbackData = copyTable(moveData)

	-- Use M5-style preset launch, but more forward strength.
	knockbackData.KnockbackPreset = "PresetKnockback"

	knockbackData.PresetKnockbackSpeed = moveData.PresetKnockbackSpeed or 92
	knockbackData.PresetKnockbackUpward = moveData.PresetKnockbackUpward or 36
	knockbackData.PresetKnockbackDuration = moveData.PresetKnockbackDuration or 0.34
	knockbackData.PresetKnockbackMaxForce = moveData.PresetKnockbackMaxForce or 85000

	knockbackData.Knockback = knockbackData.PresetKnockbackSpeed
	knockbackData.UpwardKnockback = knockbackData.PresetKnockbackUpward
	knockbackData.KnockbackDuration = knockbackData.PresetKnockbackDuration
	knockbackData.KnockbackMaxForce = knockbackData.PresetKnockbackMaxForce

	return knockbackData
end

local function shouldApplyKnockback(result)
	-- Important:
	-- Do NOT apply knockback on Guardbreak.
	return result == "Hit"
		or result == "ArmoredHit"
end

function RedSlash.Execute(context)
	print("[RedSlash] Execute started")

	local character = context.Character
	local humanoid = context.Humanoid
	local root = context.Root
	local moveData = context.MoveData

	if not character or not character.Parent then
		context:FinishMove(0)
		return
	end

	if not humanoid or humanoid.Health <= 0 then
		context:FinishMove(0)
		return
	end

	if not root then
		context:FinishMove(0)
		return
	end

	local animationService = context.StateService and context.StateService.AnimationService

	if not animationService then
		warn("[RedSlash] Missing AnimationService on StateService")
		context:FinishMove(0)
		return
	end

	local function playCharaSFX(soundName, part, lifetime)
		if context.VFXService and context.VFXService.PlayCharacterSFXAtPart then
			context.VFXService:PlayCharacterSFXAtPart("Chara", soundName, part or root, lifetime or 2)
		end
	end

	local function playRedSlashVFX()
		if context.VFXService and context.VFXService.PlayCharacterMoveVFX then
			context.VFXService:PlayCharacterMoveVFX(character, "RedSlash")
		end
	end

	local track = animationService:PlayCharacterAnimation(
		character,
		ANIMATION_NAME,
		0.04,
		1,
		1,
		true
	)

	if not track then
		warn("[RedSlash] Could not play animation:", ANIMATION_NAME)
		context:FinishMove(0)
		return
	end

	playCharaSFX("KnifeSwing", root, 2)

	local windupStart = os.clock()

	while os.clock() - windupStart < WINDUP_TIME do
		if not character.Parent or humanoid.Health <= 0 then
			context:FinishMove(0)
			return
		end

		-- Guardbreak should still stop Red Slash.
		if character:GetAttribute("Guardbroken") then
			if track and track.IsPlaying then
				track:Stop(0.05)
			end

			context:FinishMove(0)
			return
		end

		if not context:IsActive() then
			context:FinishMove(0)
			return
		end

		task.wait()
	end

	if not context:IsActive() then
		context:FinishMove(0)
		return
	end

	playRedSlashVFX()

	local alreadyHit = {}
	local startTime = os.clock()

	while context:IsActive() and os.clock() - startTime < HITBOX_ACTIVE_TIME do
		context.HitboxService:PerformSphereAtCFrame(
			character,
			root.CFrame,
			moveData,
			function(targetCharacter, targetHumanoid, targetRoot)
				if alreadyHit[targetCharacter] then
					return
				end

				alreadyHit[targetCharacter] = true

				local result
				local hitData = makeNoKnockbackHitData(moveData)

				if context.ApplyStandardHit then
					result = context:ApplyStandardHit(
						targetCharacter,
						targetHumanoid,
						targetRoot,
						hitData,
						context.MoveId or "RedSlash"
					)
				else
					result = context:DefaultApplyHit(targetCharacter, targetHumanoid, targetRoot)
				end

				if result == "Hit"
					or result == "ArmoredHit"
					or result == "Guardbreak"
					or result == "Blocked"
				then
					playCharaSFX("M1", targetRoot, 2)
				end

				if shouldApplyKnockback(result)
					and context.MovementService
					and context.MovementService.ApplyPresetKnockback
				then
					local knockbackData = makeManualKnockbackData(moveData)

					context.MovementService:ApplyPresetKnockback(
						root,
						targetRoot,
						knockbackData,
						"RedSlashPreset"
					)
				end
			end
		)

		task.wait(HITBOX_TICK_RATE)
	end

	task.wait(ENDLAG_TIME)
	context:FinishMove(0)
end

return RedSlash