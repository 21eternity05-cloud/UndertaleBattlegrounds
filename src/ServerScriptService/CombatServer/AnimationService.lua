local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationService = {}
AnimationService.__index = AnimationService

function AnimationService.new(config)
	local self = setmetatable({}, AnimationService)

	self.Config = config

	local assetsFolder = ReplicatedStorage:FindFirstChild(config.AssetsFolderName or "Assets")
	self.AssetsFolder = assetsFolder

	if assetsFolder then
		self.UniversalFolder = assetsFolder:FindFirstChild(config.UniversalFolderName or "Universal")
		self.CharactersFolder = assetsFolder:FindFirstChild(config.CharactersFolderName or "Characters")
	end

	if not assetsFolder then
		warn("[AnimationService] Missing ReplicatedStorage > Assets")
	end

	if not self.UniversalFolder then
		warn("[AnimationService] Missing Assets > Universal")
	end

	if not self.CharactersFolder then
		warn("[AnimationService] Missing Assets > Characters")
	end

	return self
end

function AnimationService:GetCharacterNameFromCharacter(character)
	if not character then
		return self.Config.DefaultCharacterName or "Chara"
	end

	local characterName = character:GetAttribute("CharacterName")

	if typeof(characterName) == "string" and characterName ~= "" then
		return characterName
	end

	return self.Config.DefaultCharacterName or "Chara"
end

function AnimationService:IsAnimationUsable(animation)
	if not animation or not animation:IsA("Animation") then
		return false
	end

	if typeof(animation.AnimationId) ~= "string" then
		return false
	end

	if animation.AnimationId == "" then
		return false
	end

	return true
end

function AnimationService:GetUniversalAnimation(animationKey)
	if not self.UniversalFolder then return nil end

	local animationsFolder = self.UniversalFolder:FindFirstChild("Animations")
	if not animationsFolder then return nil end

	local animationName = self.Config.UniversalAnimations and self.Config.UniversalAnimations[animationKey]
	if not animationName then return nil end

	if typeof(animationName) == "table" then
		local validAnimations = {}

		for _, name in ipairs(animationName) do
			local animation = animationsFolder:FindFirstChild(name)

			if self:IsAnimationUsable(animation) then
				table.insert(validAnimations, animation)
			end
		end

		if #validAnimations <= 0 then
			return nil
		end

		return validAnimations[math.random(1, #validAnimations)]
	end

	local animation = animationsFolder:FindFirstChild(animationName)

	if self:IsAnimationUsable(animation) then
		return animation
	end

	return nil
end

function AnimationService:GetCharacterAnimation(characterName, animationName)
	if not self.CharactersFolder then return nil end
	if not characterName or characterName == "" then return nil end
	if not animationName or animationName == "" then return nil end

	local characterFolder = self.CharactersFolder:FindFirstChild(characterName)
	if not characterFolder then return nil end

	local animationsFolder = characterFolder:FindFirstChild("Animations")
	if not animationsFolder then return nil end

	local animation = animationsFolder:FindFirstChild(animationName)

	if animation and animation:IsA("Animation") then
		return animation
	end

	return nil
end

function AnimationService:StopM1LikeTracks(animator, fadeTime)
	if not animator then return end

	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		local trackName = track.Name

		if trackName == "M1"
			or trackName == "M2"
			or trackName == "M3"
			or trackName == "M4"
			or trackName == "M5"
			or trackName == "Uptilt"
			or trackName == "Downslam"
		then
			track:Stop(fadeTime or 0.03)
		end
	end
end

function AnimationService:PlayAnimationObject(character, animation, fadeTime, weight, speed, stopM1Tracks)
	if not character or not character.Parent then return nil end
	if not self:IsAnimationUsable(animation) then return nil end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end

	local animator = humanoid:FindFirstChildOfClass("Animator")

	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	if stopM1Tracks then
		self:StopM1LikeTracks(animator, 0.03)
	end

	local success, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	if not success or not track then
		warn("[AnimationService] Failed to load animation:", animation.Name)
		return nil
	end

	track.Name = animation.Name
	track.Priority = Enum.AnimationPriority.Action
	track:Play(fadeTime or 0.04, weight or 1, speed or 1)

	return track
end

function AnimationService:PlayUniversalAnimation(character, animationKey, fadeTime, weight, speed, looped)
	local animation = self:GetUniversalAnimation(animationKey)

	if not animation then
		return nil
	end

	local track = self:PlayAnimationObject(character, animation, fadeTime, weight, speed)

	if track and looped ~= nil then
		track.Looped = looped
	end

	return track
end

function AnimationService:PlayCharacterAnimation(character, animationName, fadeTime, weight, speed, stopM1Tracks)
	if not animationName or animationName == "" then
		return nil
	end

	local characterName = self:GetCharacterNameFromCharacter(character)
	local defaultCharacterName = self.Config.DefaultCharacterName or "Chara"

	local animation = self:GetCharacterAnimation(characterName, animationName)

	-- Important:
	-- If the selected character owns this animation object but its AnimationId is empty,
	-- intentionally play nothing. Do NOT fallback to Chara.
	-- This lets Sans have blank M1 animations without using Chara's M1s.
	if animation then
		if not self:IsAnimationUsable(animation) then
			return nil
		end

		return self:PlayAnimationObject(character, animation, fadeTime, weight, speed, stopM1Tracks)
	end

	-- If the selected character does not have the animation object at all,
	-- fallback to default/Chara.
	if characterName ~= defaultCharacterName then
		animation = self:GetCharacterAnimation(defaultCharacterName, animationName)

		if self:IsAnimationUsable(animation) then
			return self:PlayAnimationObject(character, animation, fadeTime, weight, speed, stopM1Tracks)
		end
	end

	warn("[AnimationService] Missing character animation:", characterName, animationName)
	return nil
end

function AnimationService:PlayM1Animation(character, combo)
	local animationName = self.Config.M1Animations and self.Config.M1Animations[combo]

	if not animationName then
		return nil
	end

	return self:PlayCharacterAnimation(character, animationName, 0.04, 1, 1, true)
end

function AnimationService:PlayUptiltAnimation(character)
	local animationName = self.Config.M1Animations and self.Config.M1Animations.Uptilt

	if not animationName then
		return nil
	end

	return self:PlayCharacterAnimation(character, animationName, 0.04, 1, 1, true)
end

function AnimationService:PlayDownslamAnimation(character)
	local animationName = self.Config.M1Animations and self.Config.M1Animations.Downslam

	if not animationName then
		return nil
	end

	return self:PlayCharacterAnimation(character, animationName, 0.03, 1, 1, true)
end

function AnimationService:StopCharacterAnimationByName(character, animationName, fadeTime)
	if not character or not character.Parent then return end
	if not animationName or animationName == "" then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end

	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if track.Name == animationName then
			track:Stop(fadeTime or 0.12)
		end
	end
end

function AnimationService:PlayBlockAnimation(character)
	local animationName = self.Config.BlockAnimation or "Block"
	local track = self:PlayCharacterAnimation(character, animationName, 0.08, 1, 1)

	if track then
		track.Name = animationName
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
	end

	return track
end

function AnimationService:StopBlockAnimation(character)
	local animationName = self.Config.BlockAnimation or "Block"
	self:StopCharacterAnimationByName(character, animationName, 0.12)
end

function AnimationService:StopUniversalAnimation(character, animationKey, fadeTime)
	if not character or not character.Parent then return end
	if not animationKey then return end

	local animationName = self.Config.UniversalAnimations and self.Config.UniversalAnimations[animationKey]

	if not animationName then
		return
	end

	local namesToStop = {}

	if typeof(animationName) == "table" then
		for _, name in ipairs(animationName) do
			table.insert(namesToStop, name)
		end
	else
		table.insert(namesToStop, animationName)
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end

	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		for _, name in ipairs(namesToStop) do
			if track.Name == name then
				track:Stop(fadeTime or 0.12)
				break
			end
		end
	end
end

function AnimationService:StopAllStunAnimations(character, fadeTime)
	self:StopUniversalAnimation(character, "Hitstun", fadeTime)
	self:StopUniversalAnimation(character, "DownslamAir", fadeTime)
	self:StopUniversalAnimation(character, "DownslamSplat", fadeTime)
	self:StopUniversalAnimation(character, "BlockBreak", fadeTime)
end

return AnimationService