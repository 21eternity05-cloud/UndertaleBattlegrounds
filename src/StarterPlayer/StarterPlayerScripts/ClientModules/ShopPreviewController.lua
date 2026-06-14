local Workspace = game:GetService("Workspace")

local ShopPreviewController = {}
ShopPreviewController.__index = ShopPreviewController

local SHOP_FOLDER_NAME = "SHOP"
local SHOP_PLACEHOLDER_NAME = "Placeholder"
local PREVIEW_FOLDER_NAME = "ClientShopPreviews"
local PREVIEW_NAME_PREFIX = "ClientShopPreview_"
local PREVIEW_CAMERA_DISTANCE = 7.25
local PREVIEW_CAMERA_HEIGHT = 1.85
local PREVIEW_FOCUS_HEIGHT = 1.35
local NONE_TITLE_ID = "None"
local BODY_PART_NAMES = {
	"Head",
	"Torso",
	"UpperTorso",
	"LowerTorso",
	"Left Arm",
	"Right Arm",
	"Left Leg",
	"Right Leg",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
}
local COLLIDABLE_PARTS = {
	Torso = true,
	Head = true,
	HumanoidRootPart = true,
}

local function applySimpleCharacterCollision(character)
	if not character then
		return
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local canCollide = COLLIDABLE_PARTS[descendant.Name] == true
			descendant.CanCollide = canCollide
			descendant.CanTouch = false
			descendant.CanQuery = canCollide

			if not canCollide then
				descendant.Massless = true
			end
		end
	end
end

function ShopPreviewController.new(player, replicatedStorage)
	local self = setmetatable({}, ShopPreviewController)

	self.Player = player
	self.ReplicatedStorage = replicatedStorage
	self.ShopLocationRemote = nil
	self.ActivePreviewModel = nil
	self.ActivePreviewIdleTrack = nil
	self.ActivePreviewEmoteTrack = nil
	self.ActivePreviewEmoteConnection = nil
	self.ActivePreviewEmoteSounds = {}
	self.ActivePreviewMarkerConnections = {}
	self.OldCameraType = nil
	self.OldCameraSubject = nil
	self.OldCameraCFrame = nil
	self.CameraHoldCharacter = nil
	self.ShopCameraCFrame = nil
	self.LastCharacterName = nil
	self.LastSkinName = nil
	self.LastShopPosition = nil

	return self
end

function ShopPreviewController:GetShopLocationRemote()
	if self.ShopLocationRemote then
		return self.ShopLocationRemote
	end

	local remotes = self.ReplicatedStorage:FindFirstChild("Remotes")
	local remote = remotes and remotes:FindFirstChild("ShopLocationRemote")

	if remote and remote:IsA("RemoteFunction") then
		self.ShopLocationRemote = remote
		return remote
	end

	return nil
end

function ShopPreviewController:GetIdleAnimation(characterName)
	local assets = self.ReplicatedStorage:FindFirstChild("Assets")
	local characters = assets and assets:FindFirstChild("Characters")
	local characterFolder = characters and characters:FindFirstChild(characterName)
	local animationsFolder = characterFolder and characterFolder:FindFirstChild("Animations")
	local idleAnimation = animationsFolder and animationsFolder:FindFirstChild("Idle")

	if idleAnimation and idleAnimation:IsA("Animation") then
		return idleAnimation
	end

	return nil
end

function ShopPreviewController:GetEmoteData()
	local shared = self.ReplicatedStorage:FindFirstChild("Shared")
	local emoteModule = shared and shared:FindFirstChild("EmoteData")

	if not emoteModule or not emoteModule:IsA("ModuleScript") then
		return nil
	end

	local success, result = pcall(require, emoteModule)
	if success and typeof(result) == "table" then
		return result
	end

	return nil
end

function ShopPreviewController:GetEmoteAnimation(animationName)
	local assets = self.ReplicatedStorage:FindFirstChild("Assets")
	local emotes = assets and assets:FindFirstChild("Emotes")
	local animations = emotes and emotes:FindFirstChild("Animations")
	local animation = animations and animations:FindFirstChild(animationName)

	if animation and animation:IsA("Animation") then
		return animation
	end

	return nil
end

function ShopPreviewController:GetEmoteSound(soundName)
	local assets = self.ReplicatedStorage:FindFirstChild("Assets")
	local emotes = assets and assets:FindFirstChild("Emotes")
	local sounds = emotes and emotes:FindFirstChild("Sounds")
	local sound = sounds and sounds:FindFirstChild(soundName)

	if sound and sound:IsA("Sound") then
		return sound
	end

	return nil
end

function ShopPreviewController:GetServerShopLocation()
	local remote = self:GetShopLocationRemote()
	if not remote then
		return nil
	end

	local success, result = pcall(function()
		return remote:InvokeServer()
	end)

	if not success or typeof(result) ~= "table" or result.Exists ~= true then
		return nil
	end

	if typeof(result.PlaceholderPosition) == "Vector3" then
		self.LastShopPosition = result.PlaceholderPosition
		return result.PlaceholderPosition, result.PlaceholderCFrame
	end

	if typeof(result.PlaceholderCFrame) == "CFrame" then
		self.LastShopPosition = result.PlaceholderCFrame.Position
		return result.PlaceholderCFrame.Position, result.PlaceholderCFrame
	end

	return nil
end

function ShopPreviewController:RequestStreamAround(position)
	if typeof(position) ~= "Vector3" then
		return
	end

	self.LastShopPosition = position

	task.spawn(function()
		pcall(function()
			self.Player:RequestStreamAroundAsync(position, 3)
		end)
	end)
end

function ShopPreviewController:RequestShopStream()
	local position = self.LastShopPosition

	if not position then
		position = self:GetServerShopLocation()
	end

	if position then
		self:RequestStreamAround(position)
	end
end

function ShopPreviewController:Start()
	task.defer(function()
		self:RequestShopStream()
	end)

	self.Player:GetAttributeChangedSignal("EquippedTitle"):Connect(function()
		self:ApplyTitleToActivePreview(true)
	end)

	self.Player:GetAttributeChangedSignal("Setting_Titles"):Connect(function()
		self:ApplyTitleToActivePreview(true)
	end)
end

function ShopPreviewController:GetCurrentHumanoid()
	local character = self.Player.Character
	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

function ShopPreviewController:RestoreCameraToPlayer()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	camera.CameraType = Enum.CameraType.Custom

	local humanoid = self:GetCurrentHumanoid()
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

function ShopPreviewController:GetShopFolder()
	local shopFolder = Workspace:FindFirstChild(SHOP_FOLDER_NAME)

	if not shopFolder then
		warn("[ShopPreviewController] Missing workspace.SHOP folder")
		return nil
	end

	return shopFolder
end

function ShopPreviewController:GetShopPlaceholder()
	local shopFolder = self:GetShopFolder()
	if not shopFolder then
		self:RequestShopStream()
		return nil
	end

	local placeholder = shopFolder:FindFirstChild(SHOP_PLACEHOLDER_NAME)

	if not placeholder or not placeholder:IsA("BasePart") then
		self:RequestShopStream()
		placeholder = shopFolder:WaitForChild(SHOP_PLACEHOLDER_NAME, 5)

		if not placeholder or not placeholder:IsA("BasePart") then
			warn("[ShopPreviewController] Missing workspace.SHOP.Placeholder part")
			return nil
		end
	end

	self.LastShopPosition = placeholder.Position

	return placeholder
end

function ShopPreviewController:GetPreviewFolder()
	local folder = Workspace:FindFirstChild(PREVIEW_FOLDER_NAME)

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = PREVIEW_FOLDER_NAME
		folder.Parent = Workspace
	elseif not folder:IsA("Folder") then
		warn("[ShopPreviewController] Refused to use non-folder preview object:", folder:GetFullName())
		return nil
	end

	return folder
end

function ShopPreviewController:GetSkinData(characterFolder, skinName)
	local modulesFolder = characterFolder and characterFolder:FindFirstChild("Modules")
	local skinModule = modulesFolder and modulesFolder:FindFirstChild("SkinModule")

	if not skinModule or not skinModule:IsA("ModuleScript") then
		return nil, skinName or "Default"
	end

	local success, skinConfig = pcall(require, skinModule)
	if not success or typeof(skinConfig) ~= "table" then
		warn("[ShopPreviewController] Failed to load SkinModule for", characterFolder:GetFullName())
		return nil, skinName or "Default"
	end

	local defaultSkinName = skinConfig.DefaultSkin or "Default"
	local resolvedSkinName = skinName or defaultSkinName
	local skinData = skinConfig.Skins and skinConfig.Skins[resolvedSkinName]

	if not skinData then
		resolvedSkinName = defaultSkinName
		skinData = skinConfig.Skins and skinConfig.Skins[resolvedSkinName]
	end

	return skinData, resolvedSkinName
end

function ShopPreviewController:GetCharacterFolder(characterName)
	local assets = self.ReplicatedStorage:FindFirstChild("Assets")
	local characters = assets and assets:FindFirstChild("Characters")

	return characters and characters:FindFirstChild(characterName) or nil
end

function ShopPreviewController:GetCharacterModel(characterName, skinName)
	local characterFolder = self:GetCharacterFolder(characterName)

	if not characterFolder then
		return nil
	end

	local characterModelFolder = characterFolder:FindFirstChild("CharacterModel")
	local skinData = self:GetSkinData(characterFolder, skinName)

	if characterModelFolder then
		if characterModelFolder:IsA("Model") then
			return characterModelFolder
		end

		if characterModelFolder:IsA("Folder") then
			local skinModelName = skinData and skinData.CharacterModelName
			local namedModel = skinModelName and characterModelFolder:FindFirstChild(skinModelName)

			if namedModel and namedModel:IsA("Model") then
				return namedModel
			end

			namedModel = characterModelFolder:FindFirstChild("Default")

			if namedModel and namedModel:IsA("Model") then
				return namedModel
			end

			namedModel = characterModelFolder:FindFirstChild(characterName)

			if namedModel and namedModel:IsA("Model") then
				return namedModel
			end

			local firstModel = characterModelFolder:FindFirstChildWhichIsA("Model")

			if firstModel then
				return firstModel
			end
		end
	end

	for _, modelName in ipairs({ "Model", "Rig", "ViewportModel" }) do
		local model = characterFolder:FindFirstChild(modelName)

		if model and model:IsA("Model") then
			return model
		end
	end

	return nil
end

function ShopPreviewController:MakePreviewModelSafe(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant.Disabled = true
		end
	end

	local root = model:FindFirstChild("HumanoidRootPart", true)

	if root and root:IsA("BasePart") then
		root.Anchored = true
	end

	self:ApplyPreviewCollisionRules(model)
end

function ShopPreviewController:ApplyPreviewCollisionRules(model)
	applySimpleCharacterCollision(model)
end

function ShopPreviewController:PreparePreviewWeapon(model)
	if model:IsA("BasePart") then
		model.Anchored = false
		model.CanCollide = false
		model.CanTouch = false
		model.CanQuery = false
		model.Massless = true
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant.Disabled = true
		end
	end
end

function ShopPreviewController:FindWeaponHandle(weapon)
	for _, handleName in ipairs({
		"HandleKnife",
		"Handle",
		"HandleSword",
		"HandleShield",
		"HandleStaff",
		"BoneStaffHandle",
		"SwordHandle",
		"ShieldHandle",
	}) do
		local handle = weapon:FindFirstChild(handleName, true)

		if handle and handle:IsA("BasePart") then
			return handle
		end
	end

	if weapon:IsA("BasePart") then
		return weapon
	end

	return weapon:FindFirstChildWhichIsA("BasePart", true)
end

function ShopPreviewController:WeldWeaponPartsToHandle(weapon, handle)
	for _, part in ipairs(weapon:GetDescendants()) do
		if part:IsA("BasePart") and part ~= handle then
			local alreadyConnected = false

			for _, child in ipairs(part:GetChildren()) do
				if child:IsA("WeldConstraint") or child:IsA("Weld") or child:IsA("Motor6D") then
					alreadyConnected = true
					break
				end
			end

			if not alreadyConnected then
				local weld = Instance.new("WeldConstraint")
				weld.Name = "PreviewWeaponWeld"
				weld.Part0 = handle
				weld.Part1 = part
				weld.Parent = handle
			end
		end
	end
end

function ShopPreviewController:GetPreviewWeaponLimb(characterName, weaponData)
	if weaponData.LimbName then
		return weaponData.LimbName
	end

	local weaponName = tostring(weaponData.WeaponName or "")
	local motorName = tostring(weaponData.MotorTemplateName or "")
	local combinedName = string.lower(weaponName .. " " .. motorName)

	if string.find(combinedName, "shield") then
		return "Left Arm"
	end

	return "Right Arm"
end

function ShopPreviewController:EquipSinglePreviewWeapon(previewModel, characterFolder, weaponData, index)
	if typeof(weaponData) ~= "table" then
		return
	end

	local weaponName = weaponData.WeaponName
	local motorTemplateName = weaponData.MotorTemplateName

	if typeof(weaponName) ~= "string" or weaponName == "" then
		return
	end

	local weaponsFolder = characterFolder:FindFirstChild("Weapons")
	if not weaponsFolder then
		warn("[ShopPreviewController] Missing Weapons folder for", characterFolder.Name)
		return
	end

	local weaponTemplate = weaponsFolder:FindFirstChild(weaponName)
	if not weaponTemplate then
		warn("[ShopPreviewController] Missing preview weapon:", characterFolder.Name, weaponName)
		return
	end

	local motorTemplate = nil
	if typeof(motorTemplateName) == "string" and motorTemplateName ~= "" then
		motorTemplate = weaponsFolder:FindFirstChild(motorTemplateName)
	end

	if not motorTemplate or not motorTemplate:IsA("Motor6D") then
		warn("[ShopPreviewController] Missing preview Motor6D template:", characterFolder.Name, tostring(motorTemplateName))
		return
	end

	local limbName = self:GetPreviewWeaponLimb(characterFolder.Name, weaponData)
	local limb = previewModel:FindFirstChild(limbName, true)

	if not limb or not limb:IsA("BasePart") then
		warn("[ShopPreviewController] Missing preview limb:", characterFolder.Name, limbName)
		return
	end

	local weapon = weaponTemplate:Clone()
	weapon.Name = "PreviewWeapon_" .. tostring(index or 1) .. "_" .. weaponName
	weapon.Parent = previewModel

	local handle = self:FindWeaponHandle(weapon)
	if not handle then
		weapon:Destroy()
		warn("[ShopPreviewController] Preview weapon has no handle:", characterFolder.Name, weaponName)
		return
	end

	self:PreparePreviewWeapon(weapon)
	self:WeldWeaponPartsToHandle(weapon, handle)

	local motor = motorTemplate:Clone()
	motor.Name = "PreviewWeaponMotor_" .. tostring(index or 1)
	motor.Part0 = limb
	motor.Part1 = handle
	motor.Parent = limb
end

function ShopPreviewController:EquipPreviewWeapons(previewModel, characterName, skinName)
	local characterFolder = self:GetCharacterFolder(characterName)
	if not characterFolder then
		return
	end

	local skinData = self:GetSkinData(characterFolder, skinName)
	if not skinData then
		return
	end

	if typeof(skinData.Weapons) == "table" then
		for index, weaponData in ipairs(skinData.Weapons) do
			self:EquipSinglePreviewWeapon(previewModel, characterFolder, weaponData, index)
		end

		return
	end

	self:EquipSinglePreviewWeapon(previewModel, characterFolder, {
		WeaponName = skinData.WeaponName,
		MotorTemplateName = skinData.MotorTemplateName,
		LimbName = skinData.LimbName,
	}, 1)
end

function ShopPreviewController:GetTitlesFolder()
	local assets = self.ReplicatedStorage:FindFirstChild("Assets")
	return assets and assets:FindFirstChild("Titles") or nil
end

function ShopPreviewController:ClearTitleVisuals(model)
	if not model then
		return
	end

	for _, child in ipairs(model:GetChildren()) do
		if child:GetAttribute("TitleVisual") == true then
			child:Destroy()
		end
	end

	for _, bodyPartName in ipairs(BODY_PART_NAMES) do
		local bodyPart = model:FindFirstChild(bodyPartName, true)
		if bodyPart then
			for _, child in ipairs(bodyPart:GetChildren()) do
				if child:GetAttribute("TitleVisual") == true then
					child:Destroy()
				end
			end
		end
	end

	local folder = model:FindFirstChild("ActiveTitleVisuals")
	if folder then
		folder:Destroy()
	end

	model:SetAttribute("AppliedTitleId", nil)
end

function ShopPreviewController:ApplyTitleVisualsToModel(model, titleId, force)
	if not model or not model.Parent then
		return
	end

	if self.Player:GetAttribute("Setting_Titles") == false then
		self:ClearTitleVisuals(model)
		self:ApplyPreviewCollisionRules(model)
		return
	end

	if typeof(titleId) ~= "string" or titleId == "" or titleId == NONE_TITLE_ID then
		self:ClearTitleVisuals(model)
		self:ApplyPreviewCollisionRules(model)
		return
	end

	if force ~= true and model:GetAttribute("AppliedTitleId") == titleId then
		return
	end

	local titlesFolder = self:GetTitlesFolder()
	local noneModel = titlesFolder and titlesFolder:FindFirstChild(NONE_TITLE_ID)
	local titleModel = titlesFolder and titlesFolder:FindFirstChild(titleId)

	if not titlesFolder or not noneModel or not titleModel then
		self:ClearTitleVisuals(model)
		self:ApplyPreviewCollisionRules(model)
		return
	end

	self:ClearTitleVisuals(model)

	for _, bodyPartName in ipairs(BODY_PART_NAMES) do
		local selectedBodyPart = titleModel:FindFirstChild(bodyPartName)
		local noneBodyPart = noneModel:FindFirstChild(bodyPartName)
		local previewBodyPart = model:FindFirstChild(bodyPartName, true)

		if selectedBodyPart and noneBodyPart and previewBodyPart then
			for _, selectedChild in ipairs(selectedBodyPart:GetChildren()) do
				if not noneBodyPart:FindFirstChild(selectedChild.Name) then
					local clone = selectedChild:Clone()
					clone:SetAttribute("TitleVisual", true)
					clone:SetAttribute("TitleId", titleId)
					clone.Parent = previewBodyPart
				end
			end
		end
	end

	model:SetAttribute("AppliedTitleId", titleId)
	self:ApplyPreviewCollisionRules(model)
end

function ShopPreviewController:ApplyTitleToActivePreview(force)
	local model = self.ActivePreviewModel
	if not model or not model.Parent then
		return
	end

	local titleId = self.Player:GetAttribute("EquippedTitle")
	self:ApplyTitleVisualsToModel(model, titleId, force)
end

function ShopPreviewController:DestroyActivePreview()
	self:StopPreviewEmote()

	if self.ActivePreviewIdleTrack then
		pcall(function()
			self.ActivePreviewIdleTrack:Stop(0)
			self.ActivePreviewIdleTrack:Destroy()
		end)

		self.ActivePreviewIdleTrack = nil
	end

	local model = self.ActivePreviewModel
	self.ActivePreviewModel = nil

	if not model or not model.Parent then
		return
	end

	if model.Name:match("^" .. PREVIEW_NAME_PREFIX) then
		model:Destroy()
	else
		warn("[ShopPreviewController] Refused to destroy unsafe preview object:", model:GetFullName())
	end
end

function ShopPreviewController:StopPreviewEmote()
	if self.ActivePreviewEmoteConnection then
		self.ActivePreviewEmoteConnection:Disconnect()
		self.ActivePreviewEmoteConnection = nil
	end

	for _, connection in ipairs(self.ActivePreviewMarkerConnections or {}) do
		connection:Disconnect()
	end
	table.clear(self.ActivePreviewMarkerConnections)

	if self.ActivePreviewEmoteTrack then
		pcall(function()
			self.ActivePreviewEmoteTrack:Stop(0.12)
			self.ActivePreviewEmoteTrack:Destroy()
		end)

		self.ActivePreviewEmoteTrack = nil
	end

	for _, sound in ipairs(self.ActivePreviewEmoteSounds or {}) do
		if sound and sound.Parent then
			sound:Stop()
			sound:Destroy()
		end
	end
	table.clear(self.ActivePreviewEmoteSounds)
end

function ShopPreviewController:PlayPreviewEmoteSound(soundName, looped)
	local template = self:GetEmoteSound(soundName)
	if not template then
		warn("[ShopPreviewController] Missing preview emote sound:", tostring(soundName))
		return nil
	end

	local model = self.ActivePreviewModel
	local root = model and model:FindFirstChild("HumanoidRootPart", true)
	local parent = root or model
	if not parent then
		return nil
	end

	local sound = template:Clone()
	sound.Looped = looped == true
	sound.Parent = parent
	sound:Play()
	table.insert(self.ActivePreviewEmoteSounds, sound)

	return sound
end

function ShopPreviewController:ConnectPreviewMarkerSounds(data, track)
	if typeof(data.MarkerSounds) ~= "table" then
		return
	end

	for markerName, soundName in pairs(data.MarkerSounds) do
		if typeof(markerName) == "string" and typeof(soundName) == "string" then
			table.insert(self.ActivePreviewMarkerConnections, track:GetMarkerReachedSignal(markerName):Connect(function()
				self:PlayPreviewEmoteSound(soundName, false)
			end))
		end
	end
end

function ShopPreviewController:PlayPreviewIdle(characterName, model)
	self:StopPreviewEmote()

	if self.ActivePreviewIdleTrack then
		pcall(function()
			self.ActivePreviewIdleTrack:Stop(0)
			self.ActivePreviewIdleTrack:Destroy()
		end)

		self.ActivePreviewIdleTrack = nil
	end

	local idleAnimation = self:GetIdleAnimation(characterName)
	if not idleAnimation then
		warn("[ShopPreviewController] No preview Idle animation for", characterName)
		return
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn("[ShopPreviewController] Preview model has no Humanoid for", characterName)
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")

	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local success, track = pcall(function()
		return animator:LoadAnimation(idleAnimation)
	end)

	if not success or not track then
		warn("[ShopPreviewController] Failed to play preview idle for", characterName)
		return
	end

	track.Looped = true
	track.Name = "PreviewIdle"
	track.Priority = Enum.AnimationPriority.Idle
	track:Play(0.15)
	self.ActivePreviewIdleTrack = track
end

function ShopPreviewController:PreviewEmote(emoteId)
	self:StopPreviewEmote()

	local model = self.ActivePreviewModel
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end
	self:ApplyPreviewCollisionRules(model)

	local emoteData = self:GetEmoteData()
	local data = emoteData and emoteData[emoteId]
	if typeof(data) ~= "table" then
		return false
	end

	local animation = self:GetEmoteAnimation(data.AnimationName)
	if not animation then
		warn("[ShopPreviewController] Missing preview emote animation:", tostring(data.AnimationName))
		return false
	end

	if self.ActivePreviewIdleTrack then
		pcall(function()
			self.ActivePreviewIdleTrack:Stop(0.12)
			self.ActivePreviewIdleTrack:Destroy()
		end)

		self.ActivePreviewIdleTrack = nil
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local success, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	if not success or not track then
		warn("[ShopPreviewController] Failed to play preview emote:", tostring(emoteId))
		return false
	end

	track.Looped = data.Looped == true
	track.Name = "PreviewEmote"
	track.Priority = Enum.AnimationPriority.Action
	self.ActivePreviewEmoteTrack = track
	self:ConnectPreviewMarkerSounds(data, track)

	if data.MusicName then
		self:PlayPreviewEmoteSound(data.MusicName, true)
	end

	if data.SoundName then
		self:PlayPreviewEmoteSound(data.SoundName, false)
	end

	if data.Looped ~= true then
		self.ActivePreviewEmoteConnection = track.Stopped:Connect(function()
			if self.ActivePreviewEmoteTrack == track then
				self.ActivePreviewEmoteTrack = nil
				if self.ActivePreviewEmoteConnection then
					self.ActivePreviewEmoteConnection:Disconnect()
					self.ActivePreviewEmoteConnection = nil
				end
				pcall(function()
					track:Destroy()
				end)
				self:PlayPreviewIdle(self.LastCharacterName, model)
			end
		end)
	end

	track:Play(0.12)
	self:ApplyPreviewCollisionRules(model)
	return true
end

function ShopPreviewController:SetupPreviewModel(characterName, skinName)
	self:DestroyActivePreview()

	local placeholder = self:GetShopPlaceholder()
	if not placeholder then
		return
	end

	local previewFolder = self:GetPreviewFolder()
	if not previewFolder then
		return
	end

	local sourceModel = self:GetCharacterModel(characterName, skinName)
	local previewCFrame = placeholder.CFrame * CFrame.Angles(0, math.rad(180), 0)

	if sourceModel then
		local clone = sourceModel:Clone()
		clone.Name = PREVIEW_NAME_PREFIX .. characterName .. "_" .. tostring(skinName or "Default")
		self:MakePreviewModelSafe(clone)
		clone.Parent = previewFolder
		clone:PivotTo(previewCFrame)
		self:EquipPreviewWeapons(clone, characterName, skinName)
		self.ActivePreviewModel = clone
		self:ApplyTitleToActivePreview(true)
		self:ApplyPreviewCollisionRules(clone)
		self:PlayPreviewIdle(characterName, clone)
	else
		local fallback = Instance.new("Model")
		fallback.Name = PREVIEW_NAME_PREFIX .. characterName .. "_" .. tostring(skinName or "Default")

		local body = Instance.new("Part")
		body.Name = "PreviewPlaceholderBody"
		body.Anchored = true
		body.CanCollide = false
		body.CanTouch = false
		body.CanQuery = false
		body.Size = Vector3.new(3, 5, 1)
		body.Color = Color3.fromRGB(120, 120, 140)
		body.CFrame = previewCFrame + Vector3.new(0, 2.5, 0)
		body.Parent = fallback

		fallback.PrimaryPart = body
		fallback.Parent = previewFolder
		self.ActivePreviewModel = fallback
		self:ApplyTitleToActivePreview(true)
		self:ApplyPreviewCollisionRules(fallback)
	end
end

function ShopPreviewController:GetPreviewCameraCFrame(placeholder)
	local model = self.ActivePreviewModel
	local root = model and model:FindFirstChild("HumanoidRootPart", true)

	if root and root:IsA("BasePart") then
		local focus = root.Position + Vector3.new(0, PREVIEW_FOCUS_HEIGHT, 0)
		local cameraPosition = root.Position
			+ (root.CFrame.LookVector * PREVIEW_CAMERA_DISTANCE)
			+ Vector3.new(0, PREVIEW_CAMERA_HEIGHT, 0)

		return CFrame.lookAt(cameraPosition, focus)
	end

	local focusPosition = placeholder.Position + Vector3.new(0, PREVIEW_FOCUS_HEIGHT, 0)
	local cameraPosition = (placeholder.CFrame * CFrame.new(0, PREVIEW_CAMERA_HEIGHT, PREVIEW_CAMERA_DISTANCE)).Position

	return CFrame.lookAt(cameraPosition, focusPosition)
end

function ShopPreviewController:Enter(characterName, skinName)
	self.LastCharacterName = characterName
	self.LastSkinName = skinName
	self:RequestShopStream()

	local camera = Workspace.CurrentCamera
	local placeholder = self:GetShopPlaceholder()

	if not camera or not placeholder then
		return
	end

	if self.OldCameraType == nil then
		self.OldCameraType = camera.CameraType
		self.OldCameraSubject = camera.CameraSubject
		self.OldCameraCFrame = camera.CFrame
		self.CameraHoldCharacter = self.Player.Character
	end

	self:SetupPreviewModel(characterName, skinName)

	local shopCameraCFrame = self:GetPreviewCameraCFrame(placeholder)

	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = shopCameraCFrame
	self.ShopCameraCFrame = shopCameraCFrame
end

function ShopPreviewController:Exit()
	local camera = Workspace.CurrentCamera

	self:DestroyActivePreview()

	if not camera then
		return
	end

	if self.OldCameraType ~= nil then
		local characterChanged = self.CameraHoldCharacter ~= nil and self.CameraHoldCharacter ~= self.Player.Character
		local subjectInvalid = self.OldCameraSubject == nil or self.OldCameraSubject.Parent == nil
		local oldHumanoid = self.OldCameraSubject and self.OldCameraSubject:IsA("Humanoid") and self.OldCameraSubject or nil
		local oldHumanoidDead = oldHumanoid and oldHumanoid.Health <= 0

		if characterChanged or subjectInvalid or oldHumanoidDead then
			self:RestoreCameraToPlayer()
		else
			camera.CameraType = self.OldCameraType
			camera.CameraSubject = self.OldCameraSubject

			if self.OldCameraType ~= Enum.CameraType.Custom and self.OldCameraCFrame then
				camera.CFrame = self.OldCameraCFrame
			end
		end
	else
		self:RestoreCameraToPlayer()
	end

	self.OldCameraType = nil
	self.OldCameraSubject = nil
	self.OldCameraCFrame = nil
	self.CameraHoldCharacter = nil
	self.ShopCameraCFrame = nil
end

function ShopPreviewController:HandleCharacterRespawnedDuringCustomize(character)
	task.wait(0.2)

	if not self.ShopCameraCFrame and self.LastCharacterName then
		self:Enter(self.LastCharacterName, self.LastSkinName)
	end

	local function reapplyShopCamera()
		local camera = Workspace.CurrentCamera

		if camera and self.ShopCameraCFrame then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = self.ShopCameraCFrame
		end
	end

	reapplyShopCamera()

	if self.OldCameraType ~= nil then
		self.OldCameraType = Enum.CameraType.Custom
		self.OldCameraSubject = self:GetCurrentHumanoid()
		self.OldCameraCFrame = nil
		self.CameraHoldCharacter = character
	end

	task.delay(0.5, reapplyShopCamera)
end

return ShopPreviewController
