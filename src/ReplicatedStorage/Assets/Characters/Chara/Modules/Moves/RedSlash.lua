local RedSlash = {
	DisplayName = "Red Slash",
	AnimationName = nil,

	Cooldown = 13,
	Duration = 1.45,
	LockTime = 1.45,
	MaxLockTime = 1.7,

	Damage = 10,
	Stun = 1,
	WhiffEndlag = 0.5,

	Radius = 9,
	Offset = CFrame.new(0, 0, -6.4),

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
	GuardbreakStun = 1.8,

	CanBeCountered = true,
	HitCancelsTarget = true,

	-- Red Slash should not lose its hitbox just because the user gets touched
	-- during the armored/active section.
	CancelableByHit = false,

	HasIFrames = false,

	HasArmor = true,
	ArmorStart = 0.15,
	ArmorEnd = 2,
	ArmorDamageReduction = 0.5,
	ArmorPreventsStun = true,
	ArmorPreventsKnockback = true,
	ArmorPreventsHitCancel = true,

	-- Polish.
	-- Red Slash is stronger than Knife Dash / Slash Barrage, but should not feel like an ultimate.
	HitAttackerShakeMagnitude = 0.75,
	HitAttackerShakeRoughness = 9,
	HitAttackerShakeDuration = 0.14,

	HitVictimShakeMagnitude = 1.15,
	HitVictimShakeRoughness = 11,
	HitVictimShakeDuration = 0.18,

	BlockVictimShakeMagnitude = 0.55,
	BlockVictimShakeRoughness = 8,
	BlockVictimShakeDuration = 0.11,

	GuardbreakVictimShakeMagnitude = 1.45,
	GuardbreakVictimShakeRoughness = 13,
	GuardbreakVictimShakeDuration = 0.22,

	HitFlashDuration = 0.055,
	GuardbreakHitFlashDuration = 0.075,
}

local ANIMATION_NAME = "RedSlash"
local CHARGE_MARKER = "charge"

local WINDUP_TIME = 0.66
local HITBOX_ACTIVE_TIME = 0.16
local HITBOX_TICK_RATE = 0.04
local ENDLAG_TIME = 0.35

local MoveHelpers = script.Parent.Parent:WaitForChild("MoveHelpers")
local CharaMoveUtil = require(MoveHelpers:WaitForChild("CharaMoveUtil"))
local SlashHelper = require(MoveHelpers:WaitForChild("SlashHelper"))
local CharaImpactHelper = require(MoveHelpers:WaitForChild("CharaImpactHelper"))

local function copyTable(source)
	return SlashHelper.CloneAttackData(source)
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
		CharaMoveUtil.PlaySFX(context, soundName, part or root, lifetime or 2)
	end

	local function playMoveVFX(vfxName, targetCharacter, targetRoot)
		CharaMoveUtil.PlayMoveVFX(context, vfxName, targetCharacter, targetRoot)
	end

	local function shakeCharacter(targetCharacter, magnitude, roughness, duration)
		CharaImpactHelper.ShakeCharacter(context, targetCharacter, magnitude, roughness, duration)
	end

	local function playHitFlash(targetCharacter, duration)
		CharaImpactHelper.HitFlash(context, targetCharacter, duration)
	end

	local function playHitPolish(result, targetCharacter)
		if result == "Hit" or result == "ArmoredHit" then
			shakeCharacter(
				character,
				moveData.HitAttackerShakeMagnitude or RedSlash.HitAttackerShakeMagnitude or 0.75,
				moveData.HitAttackerShakeRoughness or RedSlash.HitAttackerShakeRoughness or 9,
				moveData.HitAttackerShakeDuration or RedSlash.HitAttackerShakeDuration or 0.14
			)

			shakeCharacter(
				targetCharacter,
				moveData.HitVictimShakeMagnitude or RedSlash.HitVictimShakeMagnitude or 1.15,
				moveData.HitVictimShakeRoughness or RedSlash.HitVictimShakeRoughness or 11,
				moveData.HitVictimShakeDuration or RedSlash.HitVictimShakeDuration or 0.18
			)

			local hitFlashDuration = moveData.HitFlashDuration or moveData.ImpactFrameDuration or RedSlash.HitFlashDuration or 0.055
			playHitFlash(character, hitFlashDuration)
			playHitFlash(targetCharacter, hitFlashDuration)

			return
		end

		if result == "Guardbreak" then
			shakeCharacter(
				character,
				moveData.HitAttackerShakeMagnitude or RedSlash.HitAttackerShakeMagnitude or 0.75,
				moveData.HitAttackerShakeRoughness or RedSlash.HitAttackerShakeRoughness or 9,
				moveData.HitAttackerShakeDuration or RedSlash.HitAttackerShakeDuration or 0.14
			)

			shakeCharacter(
				targetCharacter,
				moveData.GuardbreakVictimShakeMagnitude or RedSlash.GuardbreakVictimShakeMagnitude or 1.45,
				moveData.GuardbreakVictimShakeRoughness or RedSlash.GuardbreakVictimShakeRoughness or 13,
				moveData.GuardbreakVictimShakeDuration or RedSlash.GuardbreakVictimShakeDuration or 0.22
			)

			local guardbreakHitFlashDuration = moveData.GuardbreakHitFlashDuration or moveData.GuardbreakImpactFrameDuration or RedSlash.GuardbreakHitFlashDuration or 0.075
			playHitFlash(character, guardbreakHitFlashDuration)
			playHitFlash(targetCharacter, guardbreakHitFlashDuration)

			return
		end

		if result == "Blocked" then
			shakeCharacter(
				targetCharacter,
				moveData.BlockVictimShakeMagnitude or RedSlash.BlockVictimShakeMagnitude or 0.55,
				moveData.BlockVictimShakeRoughness or RedSlash.BlockVictimShakeRoughness or 8,
				moveData.BlockVictimShakeDuration or RedSlash.BlockVictimShakeDuration or 0.11
			)
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

	local finished = false
	local chargeTriggered = false
	local trailStarted = false
	local didConnect = false

	local chargeConnection
	local stoppedConnection
	local endedConnection

	local function stopTrail()
		if trailStarted then
			trailStarted = false
			playMoveVFX("RedSlashTrailStop")
		end
	end

	local function disconnect()
		if chargeConnection then
			chargeConnection:Disconnect()
			chargeConnection = nil
		end

		if stoppedConnection then
			stoppedConnection:Disconnect()
			stoppedConnection = nil
		end

		if endedConnection then
			endedConnection:Disconnect()
			endedConnection = nil
		end
	end

	local function finishMove(delayTime)
		if finished then return end
		finished = true

		disconnect()
		stopTrail()

		context:FinishMove(delayTime or 0)
	end

	local function startChargeVFX()
		if chargeTriggered then return end
		chargeTriggered = true

		if not context:IsActive() then
			finishMove(0)
			return
		end

		print("[RedSlash] Charge VFX started")

		-- Uses the simple Knife Dash style VFX from Chara VFXModule.
		playMoveVFX("RedSlashStart")
		playMoveVFX("RedSlashTrailStart")

		-- Put this Sound inside:
		-- ReplicatedStorage > Assets > Characters > Chara > SFX > RedSlashCharge
		playCharaSFX("RedSlashCharge", root, 2)

		trailStarted = true
	end

	chargeConnection = track:GetMarkerReachedSignal(CHARGE_MARKER):Connect(function()
		startChargeVFX()
	end)

	stoppedConnection = track.Stopped:Connect(function()
		finishMove(0)
	end)

	endedConnection = track.Ended:Connect(function()
		finishMove(0)
	end)

	-- Silent fallback in case marker is missing/wrong name/late.
	-- No warning because the move still works fine and this fallback is intentional.
	task.delay(WINDUP_TIME * 0.35, function()
		if finished then return end
		if chargeTriggered then return end

		startChargeVFX()
	end)

	local windupStart = os.clock()

	while os.clock() - windupStart < WINDUP_TIME do
		if not character.Parent or humanoid.Health <= 0 then
			finishMove(0)
			return
		end

		-- Guardbreak should still stop Red Slash.
		if character:GetAttribute("Guardbroken") then
			if track and track.IsPlaying then
				track:Stop(0.05)
			end

			finishMove(0)
			return
		end

		if not context:IsActive() then
			finishMove(0)
			return
		end

		task.wait()
	end

	if finished then
		return
	end

	if not context:IsActive() then
		finishMove(0)
		return
	end

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
					didConnect = true
					-- Put this Sound inside:
					-- ReplicatedStorage > Assets > Characters > Chara > SFX > RedSlashHit
					playCharaSFX("RedSlashHit", targetRoot, 2)
					playHitPolish(result, targetCharacter)
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

	-- Do NOT stop trail here.
	-- Trail stops when the animation ends/stops, or when finishMove runs.

	local endlag = didConnect and ENDLAG_TIME or (moveData.WhiffEndlag or RedSlash.WhiffEndlag or 0.5)
	if not didConnect and context.ApplyWhiffMovementLock then
		context:ApplyWhiffMovementLock(endlag)
	end

	task.wait(endlag)

	if not finished then
		finishMove(0)
	end
end

return RedSlash
