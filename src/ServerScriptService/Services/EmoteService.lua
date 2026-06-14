local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmoteData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EmoteData"))

local EmoteService = {}
EmoteService.__index = EmoteService

local CANCEL_ATTRIBUTES = {
	"Attacking",
	"Stunned",
	"Blocking",
	"Guardbroken",
	"UsingMove",
	"MoveLocked",
	"CinematicLocked",
	"UltimateLocked",
	"UsingUltimate",
	"SoulBursting",
}

function EmoteService.new(config, stateService)
	local self = setmetatable({}, EmoteService)

	self.Config = config
	self.StateService = stateService
	self.ActiveEmotes = {}

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	self.EmoteRemote = remotes:FindFirstChild("EmoteRemote")
	if not self.EmoteRemote then
		self.EmoteRemote = Instance.new("RemoteEvent")
		self.EmoteRemote.Name = "EmoteRemote"
		self.EmoteRemote.Parent = remotes
	end

	local assets = ReplicatedStorage:WaitForChild(config.AssetsFolderName or "Assets")
	self.EmoteAssets = assets:FindFirstChild("Emotes")

	return self
end

function EmoteService:GetAssetFolder(folderName)
	local emotes = self.EmoteAssets
	return emotes and emotes:FindFirstChild(folderName) or nil
end

function EmoteService:GetAnimation(animationName)
	local animations = self:GetAssetFolder("Animations")
	local animation = animations and animations:FindFirstChild(animationName)
	if animation and animation:IsA("Animation") then
		return animation
	end

	return nil
end

function EmoteService:GetSound(soundName)
	local sounds = self:GetAssetFolder("Sounds")
	local sound = sounds and sounds:FindFirstChild(soundName)
	if sound and sound:IsA("Sound") then
		return sound
	end

	return nil
end

function EmoteService:GetCharacterInfo(player)
	if self.StateService then
		return self.StateService:GetCharacterInfo(player)
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if not character or not humanoid or humanoid.Health <= 0 or not root then
		return nil
	end

	return character, humanoid, root
end

function EmoteService:IsBlockedByState(character)
	if not character or not character.Parent then
		return true
	end

	for _, attributeName in ipairs(CANCEL_ATTRIBUTES) do
		if character:GetAttribute(attributeName) == true then
			return true
		end
	end

	return false
end

function EmoteService:StoreMovement(state, humanoid)
	state.OldWalkSpeed = humanoid.WalkSpeed
	state.OldJumpPower = humanoid.JumpPower
	state.OldJumpHeight = humanoid.JumpHeight
	state.OldJumpEnabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping)
end

function EmoteService:ApplyMovementRules(state)
	if state.Data.CanMove == true then
		return
	end

	local humanoid = state.Humanoid
	if not humanoid or not humanoid.Parent then
		return
	end

	humanoid.WalkSpeed = 0
	humanoid.Jump = false
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
end

function EmoteService:RestoreMovement(state)
	local character = state.Character
	local humanoid = state.Humanoid

	if not humanoid or not humanoid.Parent then
		return
	end

	if character and character.Parent then
		if character:GetAttribute("Stunned")
			or character:GetAttribute("Guardbroken")
			or character:GetAttribute("Blocking")
			or character:GetAttribute("UsingMove")
		then
			return
		end
	end

	if typeof(state.OldWalkSpeed) == "number" then
		humanoid.WalkSpeed = state.OldWalkSpeed
	end

	if state.OldJumpEnabled ~= nil then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, state.OldJumpEnabled)
	end

	if typeof(state.OldJumpPower) == "number" then
		humanoid.JumpPower = state.OldJumpPower
	end

	if typeof(state.OldJumpHeight) == "number" then
		humanoid.JumpHeight = state.OldJumpHeight
	end
end

function EmoteService:ApplyHeadless(state)
	if state.Data.VisualMode ~= "Headless" then
		return
	end

	local head = state.Character and state.Character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end

	state.Head = head
	state.OldHeadTransparency = head.Transparency
	head.Transparency = 1

	state.FaceTransparency = {}
	for _, child in ipairs(head:GetChildren()) do
		if child:IsA("Decal") or child:IsA("Texture") then
			state.FaceTransparency[child] = child.Transparency
			child.Transparency = 1
		end
	end
end

function EmoteService:RestoreHeadless(state)
	if state.Head and state.Head.Parent and typeof(state.OldHeadTransparency) == "number" then
		state.Head.Transparency = state.OldHeadTransparency
	end

	for face, transparency in pairs(state.FaceTransparency or {}) do
		if face and face.Parent then
			face.Transparency = transparency
		end
	end
end

function EmoteService:PlayEmoteSound(state, soundName, looped)
	local template = self:GetSound(soundName)
	if not template then
		warn("[EmoteService] Missing emote sound:", soundName)
		return nil
	end

	local sound = template:Clone()
	sound.Looped = looped == true
	sound.Parent = state.Root or state.Character
	sound:Play()

	if not sound.Looped then
		Debris:AddItem(sound, math.max(sound.TimeLength, 1) + 1)
	end

	return sound
end

function EmoteService:ConnectMarkerSounds(state, track)
	local markerSounds = state.Data.MarkerSounds
	if typeof(markerSounds) ~= "table" then
		return
	end

	for markerName, soundName in pairs(markerSounds) do
		if typeof(markerName) == "string" and typeof(soundName) == "string" then
			table.insert(state.Connections, track:GetMarkerReachedSignal(markerName):Connect(function()
				local sound = self:PlayEmoteSound(state, soundName, false)
				if sound then
					table.insert(state.Sounds, sound)
				end
			end))
		end
	end
end

function EmoteService:ConnectCancelSignals(player, state)
	local character = state.Character
	local humanoid = state.Humanoid

	table.insert(state.Connections, humanoid.Died:Connect(function()
		self:CancelEmote(player)
	end))

	table.insert(state.Connections, humanoid.StateChanged:Connect(function(_, newState)
		if state.Data.CancelOnJump ~= true then
			return
		end

		if newState == Enum.HumanoidStateType.Jumping then
			self:CancelEmote(player)
		end
	end))

	table.insert(state.Connections, humanoid.Running:Connect(function(speed)
		if state.Data.CancelOnMove == true and speed > 0.1 then
			self:CancelEmote(player)
		end
	end))

	for _, attributeName in ipairs(CANCEL_ATTRIBUTES) do
		table.insert(state.Connections, character:GetAttributeChangedSignal(attributeName):Connect(function()
			if character:GetAttribute(attributeName) == true then
				self:CancelEmote(player)
			end
		end))
	end

	table.insert(state.Connections, character.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			self:CancelEmote(player)
		end
	end))
end

function EmoteService:CancelEmote(player)
	local state = self.ActiveEmotes[player]
	if not state then
		return
	end

	self.ActiveEmotes[player] = nil

	for _, connection in ipairs(state.Connections) do
		connection:Disconnect()
	end

	if state.Track then
		pcall(function()
			state.Track:Stop(0.12)
			state.Track:Destroy()
		end)
	end

	for _, sound in ipairs(state.Sounds) do
		if sound and sound.Parent then
			sound:Stop()
			sound:Destroy()
		end
	end

	self:RestoreHeadless(state)
	self:RestoreMovement(state)

	if state.Character and state.Character.Parent then
		state.Character:SetAttribute("Emoting", false)
		state.Character:SetAttribute("CurrentEmote", nil)
	end
end

function EmoteService:PlayEmote(player, emoteId)
	if typeof(emoteId) ~= "string" then
		return false
	end

	local data = EmoteData[emoteId]
	if not data then
		return false
	end

	local progressionService = _G.UTBGProgressionService
	if progressionService and progressionService.IsEmoteOwned and not progressionService:IsEmoteOwned(player, emoteId) then
		return false
	end

	local character, humanoid, root = self:GetCharacterInfo(player)
	if not character then
		return false
	end

	if self:IsBlockedByState(character) then
		return false
	end

	local animation = self:GetAnimation(data.AnimationName)
	if not animation then
		warn("[EmoteService] Missing emote animation:", tostring(data.AnimationName))
		return false
	end

	self:CancelEmote(player)

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local track = animator:LoadAnimation(animation)
	track.Looped = data.Looped == true
	track.Priority = Enum.AnimationPriority.Action

	local state = {
		Player = player,
		Character = character,
		Humanoid = humanoid,
		Root = root,
		EmoteId = emoteId,
		Data = data,
		Track = track,
		Connections = {},
		Sounds = {},
		FaceTransparency = {},
	}

	self:StoreMovement(state, humanoid)
	self.ActiveEmotes[player] = state

	character:SetAttribute("Emoting", true)
	character:SetAttribute("CurrentEmote", emoteId)

	self:ApplyMovementRules(state)
	self:ApplyHeadless(state)
	self:ConnectCancelSignals(player, state)
	self:ConnectMarkerSounds(state, track)

	table.insert(state.Connections, track.Stopped:Connect(function()
		if self.ActiveEmotes[player] == state then
			self:CancelEmote(player)
		end
	end))

	if data.MusicName then
		local music = self:PlayEmoteSound(state, data.MusicName, true)
		if music then
			table.insert(state.Sounds, music)
		end
	end

	if data.SoundName then
		local sound = self:PlayEmoteSound(state, data.SoundName, false)
		if sound then
			table.insert(state.Sounds, sound)
		end
	end

	track:Play(0.12)

	if data.Duration and data.Looped ~= true then
		task.delay(data.Duration, function()
			if self.ActiveEmotes[player] == state then
				self:CancelEmote(player)
			end
		end)
	end

	return true
end

function EmoteService:HandleRequest(player, payload)
	if typeof(payload) ~= "table" then
		return
	end

	if payload.Action == "PlayEmote" then
		self:PlayEmote(player, payload.EmoteId)
	elseif payload.Action == "CancelEmote" then
		self:CancelEmote(player)
	end
end

function EmoteService:Start()
	self.EmoteRemote.OnServerEvent:Connect(function(player, payload)
		self:HandleRequest(player, payload)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:CancelEmote(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			self:CancelEmote(player)
		end)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		player.CharacterAdded:Connect(function()
			self:CancelEmote(player)
		end)
	end
end

return EmoteService
