local RunService = game:GetService("RunService")

local SlashBarrage = {
	DisplayName = "SlashBarrage",

	AnimationName = nil,

	Cooldown = 14,
	Duration = 1.65,
	LockTime = 1.65,
	MaxLockTime = 2,

	CancelWindow = 0.35,

	Damage = 1.5,
	Stun = 0.35,
	KnockbackPreset = nil,
	Knockback = 0,
	UpwardKnockback = 0,

	CarryDuration = 0.08,
	VictimPushSpeed = 4,
	AttackerChaseSpeed = 6,
	YHoldDuration = 0.05,

	Radius = 8,
	Offset = CFrame.new(0, 0, -4),

	CanBeBlocked = true,
	Unblockable = false,
	Guardbreak = false,
	CanBeCountered = true,

	HitCancelsTarget = true,
	CancelableByHit = true,
	
	PlayMoveHitVFX = false,

	HasIFrames = false,
	HasArmor = false,

	SlashEffectName = "SlashBarrage",
}

local ANIMATION_NAME = "SlashBarrage"
local HIT_MARKER = "Hit"

function SlashBarrage.Execute(context)
	print("[SlashBarrage] Execute started")

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

	local animationService = context.StateService.AnimationService

	if not animationService then
		warn("[SlashBarrage] Missing AnimationService on StateService")
		context:FinishMove(0)
		return
	end

	local function playCharaSFX(soundName, lifetime)
		if context.VFXService and context.VFXService.PlayCharacterSFXAtPart then
			context.VFXService:PlayCharacterSFXAtPart("Chara", soundName, root, lifetime or 2)
		end
	end

	local function playCharaM1HitSFX(targetRoot)
		if not targetRoot then return end

		if context.VFXService and context.VFXService.PlayCharacterSFXAtPart then
			context.VFXService:PlayCharacterSFXAtPart("Chara", "M1", targetRoot, 2)
		end
	end

	local function playSlashVFX(targetCharacter, targetRoot)
		if context.VFXService and context.VFXService.PlayCharacterMoveVFX then
			context.VFXService:PlayCharacterMoveVFX(
				character,
				moveData.SlashEffectName or "SlashBarrageSlash",
				targetCharacter,
				targetRoot
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
		warn("[SlashBarrage] Could not play animation:", ANIMATION_NAME)
		context:FinishMove(0)
		return
	end

	local finished = false
	local hitConnection
	local stoppedConnection
	local endedConnection
	local cancelConnection

	local function disconnect()
		if hitConnection then
			hitConnection:Disconnect()
			hitConnection = nil
		end

		if stoppedConnection then
			stoppedConnection:Disconnect()
			stoppedConnection = nil
		end

		if endedConnection then
			endedConnection:Disconnect()
			endedConnection = nil
		end

		if cancelConnection then
			cancelConnection:Disconnect()
			cancelConnection = nil
		end
	end

	local function stopAnimation()
		if track and track.IsPlaying then
			track:Stop(0.05)
		end
	end

	local function finish(delayTime)
		if finished then
			return
		end

		finished = true
		disconnect()
		context:FinishMove(delayTime or 0)
	end

	local function cancelMove(reason)
		if finished then
			return
		end

		print("[SlashBarrage] Canceled:", reason or "Unknown")

		stopAnimation()
		finish(0)
	end

	local function isCanceledByHit()
		if not character or not character.Parent then
			return true
		end

		if not humanoid or not humanoid.Parent or humanoid.Health <= 0 then
			return true
		end

		if character:GetAttribute("Stunned") then
			return true
		end

		if character:GetAttribute("Guardbroken") then
			return true
		end

		return false
	end

	local cancelStartTime = os.clock()
	local cancelWindow = moveData.CancelWindow or SlashBarrage.CancelWindow or 0.35

	cancelConnection = RunService.Heartbeat:Connect(function()
		if finished then return end

		local stillInCancelWindow = os.clock() - cancelStartTime <= cancelWindow

		if stillInCancelWindow and isCanceledByHit() then
			cancelMove("Hit/Stunned/Guardbroken")
			return
		end

		if not context:IsActive() then
			cancelMove("Inactive")
			return
		end
	end)

	local function doHit()
		if finished then
			return
		end

		if not context:IsActive() then
			finish(0)
			return
		end

		print("[SlashBarrage] Hit marker reached")

		playSlashVFX()
		playCharaSFX("KnifeSwing", 2)

		context.HitboxService:PerformSphereAtCFrame(
			character,
			root.CFrame,
			moveData,
			function(targetCharacter, targetHumanoid, targetRoot)
				if finished then return end

				local result = context:DefaultApplyHit(targetCharacter, targetHumanoid, targetRoot)

				if result == "Hit" or result == "ArmoredHit" or result == "Guardbreak" then
					playCharaM1HitSFX(targetRoot)
				end
			end
		)
	end

	hitConnection = track:GetMarkerReachedSignal(HIT_MARKER):Connect(doHit)

	stoppedConnection = track.Stopped:Connect(function()
		finish(0)
	end)

	endedConnection = track.Ended:Connect(function()
		finish(0)
	end)

	task.delay(moveData.Duration or SlashBarrage.Duration, function()
		if not finished then
			finish(0)
		end
	end)
end

return SlashBarrage
