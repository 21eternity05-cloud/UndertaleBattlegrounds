local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local charactersFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Characters")

local ANIMATION_NAMES = {
	Idle = "Idle",
	Walk = "Walk",
	Run = "Run",
}

local activeTracks = {}
local runningConnection = nil
local diedConnection = nil
local attributeConnection = nil
local setupToken = 0

local function stopTracks()
	for _, track in pairs(activeTracks) do
		if track and track.IsPlaying then
			track:Stop(0.15)
		end
	end

	table.clear(activeTracks)

	if runningConnection then
		runningConnection:Disconnect()
		runningConnection = nil
	end

	if diedConnection then
		diedConnection:Disconnect()
		diedConnection = nil
	end
end

local function getCharacterName(character)
	local characterName = character and character:GetAttribute("CharacterName")
	if typeof(characterName) == "string" and characterName ~= "" then
		return characterName
	end

	local playerName = player:GetAttribute("CharacterName")
	if typeof(playerName) == "string" and playerName ~= "" then
		return playerName
	end

	return "Chara"
end

local function getAnimationsFolder(characterName)
	local characterFolder = charactersFolder:FindFirstChild(characterName)
	if not characterFolder then
		warn("[CharacterMovementAnimator] Missing character folder:", characterName)
		return nil
	end

	local animationsFolder = characterFolder:FindFirstChild("Animations")
	if not animationsFolder then
		warn("[CharacterMovementAnimator] Missing Animations folder for:", characterName)
		return nil
	end

	return animationsFolder
end

local function findAnimation(animationsFolder, animationName)
	if not animationsFolder or not animationName then
		return nil
	end

	local animation = animationsFolder:FindFirstChild(animationName)

	if animation and animation:IsA("Animation") then
		return animation
	end

	return nil
end

local function loadTrack(animator, animation, priority, looped)
	if not animation then
		return nil
	end

	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	if not ok or not track then
		warn("[CharacterMovementAnimator] Failed to load animation:", animation:GetFullName())
		return nil
	end

	track.Name = animation.Name
	track.Priority = priority
	track.Looped = looped == true

	return track
end

local function playOnly(trackName)
	for name, track in pairs(activeTracks) do
		if name == trackName then
			if track and not track.IsPlaying then
				track:Play(0.18)
			end
		elseif track and track.IsPlaying then
			track:Stop(0.18)
		end
	end
end

local function updateMovementState(humanoid)
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local moveDirection = humanoid.MoveDirection
	local speed = humanoid.RootPart and humanoid.RootPart.AssemblyLinearVelocity.Magnitude or 0

	if moveDirection.Magnitude < 0.05 or speed < 0.5 then
		playOnly("Idle")
		return
	end

	if speed >= 18 and activeTracks.Run then
		playOnly("Run")
	elseif activeTracks.Walk then
		playOnly("Walk")
	else
		playOnly("Idle")
	end
end

local function setupCharacter(character)
	setupToken += 1
	local myToken = setupToken

	stopTracks()

	if not character or not character.Parent then
		return
	end

	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")

	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local characterName = getCharacterName(character)
	local animationsFolder = getAnimationsFolder(characterName)

	if myToken ~= setupToken then
		return
	end

	if not animationsFolder then
		return
	end

	activeTracks.Idle = loadTrack(
		animator,
		findAnimation(animationsFolder, ANIMATION_NAMES.Idle),
		Enum.AnimationPriority.Idle,
		true
	)

	activeTracks.Walk = loadTrack(
		animator,
		findAnimation(animationsFolder, ANIMATION_NAMES.Walk),
		Enum.AnimationPriority.Movement,
		true
	)

	activeTracks.Run = loadTrack(
		animator,
		findAnimation(animationsFolder, ANIMATION_NAMES.Run),
		Enum.AnimationPriority.Movement,
		true
	)

	if not activeTracks.Idle and not activeTracks.Walk and not activeTracks.Run then
		warn("[CharacterMovementAnimator] No movement animations loaded for:", characterName)
		return
	end

	playOnly("Idle")

	runningConnection = humanoid.Running:Connect(function()
		updateMovementState(humanoid)
	end)

	diedConnection = humanoid.Died:Connect(stopTracks)

	task.defer(function()
		if myToken == setupToken then
			updateMovementState(humanoid)
		end
	end)
end

local function refresh()
	local character = player.Character

	if character then
		setupCharacter(character)
	end
end

player.CharacterAdded:Connect(function(character)
	task.wait(0.35)
	setupCharacter(character)
end)

player:GetAttributeChangedSignal("CharacterName"):Connect(refresh)

if attributeConnection then
	attributeConnection:Disconnect()
	attributeConnection = nil
end

if player.Character then
	task.defer(refresh)
end