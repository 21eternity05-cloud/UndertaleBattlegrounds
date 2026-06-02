local RedSlash = {
	DisplayName = "Red Slash",

	AnimationName = nil,

	Cooldown = 1,
	Duration = 0.85,
	LockTime = 0.85,
	MaxLockTime = 1.1,

	Damage = 8,
	Stun = 0.55,
	Knockback = 200,
	UpwardKnockback = 85,

	Radius = 5,
	Offset = CFrame.new(0, 0, -4),

	CanBeBlocked = true,
	Unblockable = false,
	Guardbreak = true,
	GuardbreakStun = 1.35,
	CanBeCountered = true,

	HitCancelsTarget = true,
	CancelableByHit = true,

	HasIFrames = false,
	HasArmor = false,
}

local ANIMATION_NAME = "RedSlash"

local WINDUP_TIME = 1
local HITBOX_ACTIVE_TIME = 0.16
local HITBOX_TICK_RATE = 0.04
local ENDLAG_TIME = 0.35

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

	local animationService = context.StateService.AnimationService

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

	task.wait(WINDUP_TIME)

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

				local result = context:DefaultApplyHit(targetCharacter, targetHumanoid, targetRoot)

				if result == "Hit"
					or result == "ArmoredHit"
					or result == "Guardbreak"
					or result == "Blocked"
				then
					playCharaSFX("M1", targetRoot, 2)
				end
			end
		)

		task.wait(HITBOX_TICK_RATE)
	end

	task.wait(ENDLAG_TIME)

	context:FinishMove(0)
end

return RedSlash