local CharacterIntroService = {}
CharacterIntroService.__index = CharacterIntroService

local INTRO_ANIMATION_NAME = "CharacterSwitch"
local INTRO_FALLBACK_DURATION = 1.6
local INTRO_TIMEOUT_PADDING = 0.4

function CharacterIntroService.new(config, animationService, vfxService, cinematicService)
	local self = setmetatable({}, CharacterIntroService)

	self.Config = config
	self.AnimationService = animationService
	self.VFXService = vfxService
	self.CinematicService = cinematicService

	return self
end

function CharacterIntroService:GetHumanoidAndRoot(character)
	if not character then
		return nil, nil
	end

	return character:FindFirstChildOfClass("Humanoid"), character:FindFirstChild("HumanoidRootPart")
end

function CharacterIntroService:WaitForTrack(track)
	if not track then
		task.wait(INTRO_FALLBACK_DURATION)
		return
	end

	local stopped = false
	local connection = track.Stopped:Connect(function()
		stopped = true
	end)

	local length = track.Length
	local lengthDeadline = os.clock() + 0.25
	while length <= 0 and os.clock() < lengthDeadline do
		task.wait()
		length = track.Length
	end

	local timeout = (length > 0 and length or INTRO_FALLBACK_DURATION) + INTRO_TIMEOUT_PADDING
	local startTime = os.clock()

	while not stopped and os.clock() - startTime < timeout do
		task.wait()
	end

	if connection then
		connection:Disconnect()
	end
end

function CharacterIntroService:PlayIntroVFX(characterName, character, root)
	if not self.VFXService or not self.VFXService.GetCharacterVFXModule then
		return nil
	end

	local module = self.VFXService:GetCharacterVFXModule(characterName)
	if not module or not module.PlayCharacterSwitchIntro then
		return nil
	end

	local success, cleanup = pcall(function()
		return module:PlayCharacterSwitchIntro({
			Character = character,
			Root = root,
		})
	end)

	if not success then
		warn("[CharacterIntroService] Character intro VFX failed:", cleanup)
		return nil
	end

	if typeof(cleanup) == "function" then
		return cleanup
	end

	return nil
end

function CharacterIntroService:LockCharacter(character, humanoid)
	local savedState = {
		UsingMove = character:GetAttribute("UsingMove"),
		MovementLocked = character:GetAttribute("MovementLocked"),
		DashLocked = character:GetAttribute("DashLocked"),
		Attacking = character:GetAttribute("Attacking"),
		BlockHeld = character:GetAttribute("BlockHeld"),
		Blocking = character:GetAttribute("Blocking"),
	}

	local cinematicState = nil
	if self.CinematicService and self.CinematicService.LockCharacter then
		cinematicState = self.CinematicService:LockCharacter(character, {
			AnchorRoot = false,
			DisableCollision = false,
			IsGrabber = false,
		})
	end

	character:SetAttribute("CharacterSwitchIntroActive", true)
	character:SetAttribute("UsingMove", true)
	character:SetAttribute("MovementLocked", true)
	character:SetAttribute("DashLocked", true)
	character:SetAttribute("Attacking", false)
	character:SetAttribute("BlockHeld", false)
	character:SetAttribute("Blocking", false)

	if humanoid and humanoid.Parent then
		humanoid.WalkSpeed = 0
		humanoid.Jump = false
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	end

	return savedState, cinematicState
end

function CharacterIntroService:UnlockCharacter(character, humanoid, savedState, cinematicState, token)
	if not character or not character.Parent then
		return
	end
	if character:GetAttribute("CharacterSwitchIntroToken") ~= token then
		return
	end

	if self.CinematicService and self.CinematicService.UnlockCharacter and cinematicState then
		self.CinematicService:UnlockCharacter(cinematicState)
	end

	character:SetAttribute("CharacterSwitchIntroActive", false)
	character:SetAttribute("UsingMove", savedState.UsingMove == true)
	character:SetAttribute("MovementLocked", savedState.MovementLocked == true)
	character:SetAttribute("DashLocked", savedState.DashLocked == true)
	character:SetAttribute("Attacking", savedState.Attacking == true)
	character:SetAttribute("BlockHeld", savedState.BlockHeld == true)
	character:SetAttribute("Blocking", savedState.Blocking == true)

	local currentHumanoid = humanoid
	if not currentHumanoid or not currentHumanoid.Parent then
		currentHumanoid = character:FindFirstChildOfClass("Humanoid")
	end

	if currentHumanoid
		and currentHumanoid.Parent
		and currentHumanoid.Health > 0
		and not character:GetAttribute("Stunned")
		and not character:GetAttribute("Guardbroken")
		and not character:GetAttribute("UsingMove")
	then
		currentHumanoid.WalkSpeed = self.Config.DefaultWalkSpeed
		currentHumanoid.JumpPower = self.Config.DefaultJumpPower
		currentHumanoid.JumpHeight = self.Config.DefaultJumpHeight
		currentHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	end
end

function CharacterIntroService:PlayCharacterSwitchIntro(player, characterName, character)
	if characterName ~= "Chara" then
		return
	end
	if not player or not character or not character.Parent then
		return
	end

	local humanoid, root = self:GetHumanoidAndRoot(character)
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	if not root or not root.Parent then
		return
	end

	local token = (character:GetAttribute("CharacterSwitchIntroToken") or 0) + 1
	character:SetAttribute("CharacterSwitchIntroToken", token)

	task.spawn(function()
		local cleanupVFX = nil
		local savedState, cinematicState = self:LockCharacter(character, humanoid)
		local cleanedUp = false

		local diedConnection
		local ancestryConnection

		local function cleanup()
			if cleanedUp then
				return
			end

			cleanedUp = true

			if diedConnection then
				diedConnection:Disconnect()
				diedConnection = nil
			end

			if ancestryConnection then
				ancestryConnection:Disconnect()
				ancestryConnection = nil
			end

			if cleanupVFX then
				cleanupVFX()
				cleanupVFX = nil
			end

			self:UnlockCharacter(character, humanoid, savedState, cinematicState, token)
		end

		diedConnection = humanoid.Died:Connect(cleanup)
		ancestryConnection = character.AncestryChanged:Connect(function(_, parent)
			if not parent then
				cleanup()
			end
		end)

		cleanupVFX = self:PlayIntroVFX(characterName, character, root)

		local track = nil
		if self.AnimationService and self.AnimationService.PlayCharacterAnimation then
			track = self.AnimationService:PlayCharacterAnimation(character, INTRO_ANIMATION_NAME, 0.05, 1, 1, true)
			if track then
				track.Looped = false
			end
		end

		self:WaitForTrack(track)
		cleanup()
	end)
end

return CharacterIntroService
