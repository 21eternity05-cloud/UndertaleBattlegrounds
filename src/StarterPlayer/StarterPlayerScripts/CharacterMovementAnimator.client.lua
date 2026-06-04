local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local MovementAnimationData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MovementAnimationData"))
local charactersFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Characters")

local activeTracks = {}
local runningConnection = nil

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
end

local function getCharacterName(character)
	local playerName = player:GetAttribute("CharacterName")
	if typeof(playerName) == "string" and playerName ~= "" then
		return playerName
	end

	local characterName = character and character:GetAttribute("CharacterName")
	if typeof(characterName) == "string" and characterName ~= "" then
		return characterName
	end

	return "Chara"
end

local function findAnimation(characterName, animationName)
	if not animationName then return nil end

	local characterFolder = charactersFolder:FindFirstChild(characterName)
	if not characterFolder then return nil end

	local animationsFolder = characterFolder:FindFirstChild("Animations")
	if not animationsFolder then return nil end

	local animation = animationsFolder:FindFirstChild(animationName)
	if animation and animation:IsA("Animation") then
		return animation
	end

	return nil
end

local function loadTrack(animator, animation, priority, looped)
	if not animation then return nil end

	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	if not ok or not track then
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

local function setupCharacter(character)
	stopTracks()

	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local characterName = getCharacterName(character)
	local config = MovementAnimationData[characterName]
	if not config then return end

	activeTracks.Idle = loadTrack(animator, findAnimation(characterName, config.Idle), Enum.AnimationPriority.Idle, true)
	activeTracks.Walk = loadTrack(animator, findAnimation(characterName, config.Walk), Enum.AnimationPriority.Movement, true)
	activeTracks.Run = loadTrack(animator, findAnimation(characterName, config.Run), Enum.AnimationPriority.Movement, true)

	if not activeTracks.Idle and not activeTracks.Walk and not activeTracks.Run then
		return
	end

	playOnly("Idle")

	runningConnection = humanoid.Running:Connect(function(speed)
		if humanoid.Health <= 0 then return end

		if speed < 0.5 then
			playOnly("Idle")
		elseif speed >= 18 and activeTracks.Run then
			playOnly("Run")
		elseif activeTracks.Walk then
			playOnly("Walk")
		else
			playOnly("Idle")
		end
	end)

	humanoid.Died:Connect(stopTracks)
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
