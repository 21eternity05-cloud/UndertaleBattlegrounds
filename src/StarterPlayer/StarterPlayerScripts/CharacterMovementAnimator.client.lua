local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local charactersFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Characters")

local ANIMATION_NAMES = {
	Idle = "Idle",
	Walk = "Walk",
	Run = "Run",
}

local AWAKEN_ANIMATION_NAMES = {
	Idle = "AwakenIdle",
	Walk = "AwakenWalk",
}

local activeTracks = {}

local runningConnection = nil
local diedConnection = nil
local attributeConnections = {}
local setupToken = 0
local activeCharacter = nil
local currentAnimationSetKey = nil
local reloadRequestToken = 0

local RELOAD_DEBOUNCE_TIME = 0.1

local function disconnectAttributeConnections()
	for _, connection in ipairs(attributeConnections) do
		if connection then
			connection:Disconnect()
		end
	end

	table.clear(attributeConnections)
end

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

	disconnectAttributeConnections()
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

local function isDisbeliefPapyrusAwakened(character)
	if not character then
		return false
	end

	local characterName = getCharacterName(character)

	if characterName ~= "DisbeliefPapyrus" then
		return false
	end

	return character:GetAttribute("CombatMode") == "Phase2"
		or character:GetAttribute("PapyrusMode") == "Phase2"
		or character:GetAttribute("DisbeliefPhase") == 2
		or character:GetAttribute("Phase2Active") == true
end

local function getMovementAnimationName(character, animationType)
	if isDisbeliefPapyrusAwakened(character) then
		if animationType == "Idle" then
			return AWAKEN_ANIMATION_NAMES.Idle
		elseif animationType == "Walk" then
			return AWAKEN_ANIMATION_NAMES.Walk
		end
	end

	return ANIMATION_NAMES[animationType]
end

local function stringifyAttribute(value)
	if value == nil then
		return ""
	end

	return tostring(value)
end

local function buildAnimationSetKey(character)
	if not character then
		return ""
	end

	return table.concat({
		getCharacterName(character),
		stringifyAttribute(character:GetAttribute("CombatMode")),
		stringifyAttribute(character:GetAttribute("PapyrusMode")),
		stringifyAttribute(character:GetAttribute("DisbeliefPhase")),
		stringifyAttribute(character:GetAttribute("Phase2Active")),
		stringifyAttribute(player:GetAttribute("CharacterName")),
	}, "|")
end

local function getFallbackMovementAnimationName(animationType)
	return ANIMATION_NAMES[animationType]
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

local function findMovementAnimation(animationsFolder, character, animationType)
	local animationName = getMovementAnimationName(character, animationType)
	local animation = findAnimation(animationsFolder, animationName)

	if animation then
		return animation
	end

	local fallbackName = getFallbackMovementAnimationName(animationType)

	if fallbackName and fallbackName ~= animationName then
		local fallbackAnimation = findAnimation(animationsFolder, fallbackName)

		if fallbackAnimation then
			warn(
				"[CharacterMovementAnimator] Missing movement animation:",
				animationName,
				"using fallback:",
				fallbackName
			)

			return fallbackAnimation
		end
	end

	if animationName then
		warn("[CharacterMovementAnimator] Missing movement animation:", animationName)
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

local function setupCharacter(character, forceReload)
	local nextAnimationSetKey = buildAnimationSetKey(character)
	if not forceReload
		and character == activeCharacter
		and nextAnimationSetKey == currentAnimationSetKey
		and next(activeTracks) ~= nil
	then
		return
	end

	setupToken += 1

	local myToken = setupToken

	stopTracks()
	activeCharacter = character
	currentAnimationSetKey = nextAnimationSetKey

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
		findMovementAnimation(animationsFolder, character, "Idle"),
		Enum.AnimationPriority.Idle,
		true
	)

	activeTracks.Walk = loadTrack(
		animator,
		findMovementAnimation(animationsFolder, character, "Walk"),
		Enum.AnimationPriority.Movement,
		true
	)

	activeTracks.Run = loadTrack(
		animator,
		findMovementAnimation(animationsFolder, character, "Run"),
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

	local function requestAnimationReload()
		if myToken ~= setupToken then
			return
		end

		local nextKey = buildAnimationSetKey(character)
		if nextKey == currentAnimationSetKey then
			return
		end

		reloadRequestToken += 1
		local requestToken = reloadRequestToken

		task.delay(RELOAD_DEBOUNCE_TIME, function()
			if requestToken ~= reloadRequestToken then
				return
			end

			if myToken == setupToken and character and character.Parent then
				setupCharacter(character, true)
			end
		end)
	end

	table.insert(attributeConnections, character:GetAttributeChangedSignal("CharacterName"):Connect(requestAnimationReload))
	table.insert(attributeConnections, character:GetAttributeChangedSignal("CombatMode"):Connect(requestAnimationReload))
	table.insert(attributeConnections, character:GetAttributeChangedSignal("PapyrusMode"):Connect(requestAnimationReload))
	table.insert(attributeConnections, character:GetAttributeChangedSignal("DisbeliefPhase"):Connect(requestAnimationReload))
	table.insert(attributeConnections, character:GetAttributeChangedSignal("Phase2Active"):Connect(requestAnimationReload))

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

if player.Character then
	task.defer(refresh)
end
