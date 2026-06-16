local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local combatRemote = remotes:WaitForChild("CombatRemote")
local moveRemote = remotes:WaitForChild("MoveRemote")
local ultRemote = remotes:WaitForChild("UltRemote")
local soulBurstRemote = remotes:WaitForChild("SoulBurstRemote")
local cinematicRemote = remotes:WaitForChild("CinematicRemote")
local emoteRemote = remotes:WaitForChild("EmoteRemote")

local assets = ReplicatedStorage:WaitForChild("Assets")
local charactersFolder = assets:WaitForChild("Characters")
local ClientModules = script.Parent:WaitForChild("ClientModules")
local MoveHudController = require(ClientModules:WaitForChild("MoveHudController"))

local mouseHeld = false
local localM1Cooldown = false

local LOCAL_M1_COOLDOWN = 0.27

local uptiltBuffered = false
local UPTILT_BUFFER_TIME = 0.15

local jumpLockedUntil = 0
local CLIENT_JUMP_LOCK_TIME = 0.5

local BLOCK_KEY = Enum.KeyCode.F
local blocking = false

local currentUlt = 0
local currentUltMax = 100
local currentUltAlpha = 0
local currentUltFull = false

local currentSoulBurst = 0
local currentSoulBurstMax = 100
local currentSoulBurstAlpha = 0

local MOVE_KEYS = {
	[Enum.KeyCode.One] = "Move1",
	[Enum.KeyCode.Two] = "Move2",
	[Enum.KeyCode.Three] = "Move3",
	[Enum.KeyCode.Four] = "Move4",
	[Enum.KeyCode.G] = "Ultimate",
}

local DEFAULT_MOVE_DISPLAY = {
	Move1 = {
		Key = "1",
		Name = "Move 1",
		Cooldown = 1,
	},

	Move2 = {
		Key = "2",
		Name = "Move 2",
		Cooldown = 1,
	},

	Move3 = {
		Key = "3",
		Name = "Move 3",
		Cooldown = 1,
	},

	Move4 = {
		Key = "4",
		Name = "Move 4",
		Cooldown = 1,
	},

	Ultimate = {
		Key = "G",
		Name = "Ultimate",
		Cooldown = 35,
	},
}

local TARGETABLE_FOLDERS = {
	"Dummies",
	"TestDummies",
	"NPCs",
	"Characters",
	"TargetDummies",
}

local DEBUG_COMBAT_CLIENT = false

local currentMoveDisplay = table.clone(DEFAULT_MOVE_DISPLAY)
local localMoveCooldowns = {}
local getCurrentCharacterName
local moveHudController = nil

local function getCharacter()
	local character = player.Character
	if not character then return nil end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return nil end

	return character, humanoid
end

local function cancelEmoteIfActive()
	local character = player.Character
	if character and character:GetAttribute("Emoting") == true then
		emoteRemote:FireServer({
			Action = "CancelEmote",
		})

		return true
	end

	return false
end

getCurrentCharacterName = function()
	local character = player.Character

	local playerCharacterName = player:GetAttribute("CharacterName")
	if typeof(playerCharacterName) == "string" and playerCharacterName ~= "" then
		return playerCharacterName
	end

	if character then
		local characterName = character:GetAttribute("CharacterName")
		if typeof(characterName) == "string" and characterName ~= "" then
			return characterName
		end
	end

	return "Chara"
end

local function getCurrentCombatMode()
	local character = player.Character
	if character then
		local mode = character:GetAttribute("CombatMode")
		if typeof(mode) == "string" and mode ~= "" then
			return mode
		end
	end

	return "Base"
end

local function getMoveModuleForCharacter(characterName)
	local characterFolder = charactersFolder:FindFirstChild(characterName)
	if not characterFolder then return nil end

	local modulesFolder = characterFolder and characterFolder:FindFirstChild("Modules")
	if not modulesFolder then return nil end

	local moveModuleScript = modulesFolder:FindFirstChild("MoveModule")
	if not moveModuleScript then return nil end

	local success, result = pcall(function()
		return require(moveModuleScript)
	end)

	if not success then
		warn("[CombatClient] Failed to require MoveModule:", result)
		return nil
	end

	if typeof(result) == "table" and result.new then
		local ok, moduleObject = pcall(function()
			return result.new({})
		end)

		if ok then
			return moduleObject
		end

		warn("[CombatClient] Failed to create MoveModule object:", moduleObject)
		return nil
	end

	return result
end

local function buildMoveDisplayFromModule(characterName)
	local display = {}

	for slot, data in pairs(DEFAULT_MOVE_DISPLAY) do
		display[slot] = {
			Key = data.Key,
			Name = data.Name,
			Cooldown = data.Cooldown,
			LockTime = data.LockTime or 0,
		}
	end

	local moveModule = getMoveModuleForCharacter(characterName)
	if not moveModule or not moveModule.Slots or not moveModule.Moves then
		return display
	end

	local mode = getCurrentCombatMode()
	local slots = moveModule.Slots

	if moveModule.SlotSets and moveModule.SlotSets[mode] then
		slots = moveModule.SlotSets[mode]
	end

	for slot, moveId in pairs(slots) do
		local moveData = moveModule.Moves[moveId]

		if moveData then
			display[slot] = display[slot] or {}

			display[slot].Key = DEFAULT_MOVE_DISPLAY[slot] and DEFAULT_MOVE_DISPLAY[slot].Key or "?"
			display[slot].Name = moveData.DisplayName or moveId
			display[slot].Cooldown = moveData.Cooldown or 1
			display[slot].LockTime = typeof(moveData.LockTime) == "number" and math.max(0, moveData.LockTime) or 0
			display[slot].MoveId = moveId

			display[slot].RequiresTarget = moveData.RequiresTarget == true
			display[slot].RequiresAim = moveData.RequiresAim == true
			display[slot].TargetRange = moveData.TargetRange or moveData.MaxTargetRange
		end
	end

	return display
end

local function updateUltimateHud()
	local alpha = math.clamp(currentUltAlpha or 0, 0, 1)

	if currentUltMax and currentUltMax > 0 then
		alpha = math.clamp(currentUlt / currentUltMax, 0, 1)
	end

	currentUltAlpha = alpha
	currentUltFull = alpha >= 1

	if moveHudController then
		moveHudController:UpdateUltimate({
			Current = currentUlt,
			Max = currentUltMax,
			Alpha = currentUltAlpha,
			Full = currentUltFull,
			UltName = currentMoveDisplay.Ultimate and currentMoveDisplay.Ultimate.Name,
		})
	end
end

local function updateSoulBurstHud()
	local alpha = math.clamp(currentSoulBurstAlpha or 0, 0, 1)

	if currentSoulBurstMax and currentSoulBurstMax > 0 then
		alpha = math.clamp(currentSoulBurst / currentSoulBurstMax, 0, 1)
	end

	currentSoulBurstAlpha = alpha

	if moveHudController then
		moveHudController:UpdateSoulBurst({
			Current = currentSoulBurst,
			Max = currentSoulBurstMax,
			Alpha = currentSoulBurstAlpha,
		})
	end
end

local function refreshMoveDisplay()
	local characterName = getCurrentCharacterName()
	currentMoveDisplay = buildMoveDisplayFromModule(characterName)

	if moveHudController then
		moveHudController:RefreshMoveDisplay(currentMoveDisplay)
	end

	updateUltimateHud()
	updateSoulBurstHud()
end

local function canRequestAttack()
	local character = getCharacter()
	if not character then return false end

	if character:GetAttribute("Stunned") then return false end
	if character:GetAttribute("Blocking") then return false end
	if character:GetAttribute("Guardbroken") then return false end
	if character:GetAttribute("UsingMove") then return false end
	if character:GetAttribute("Emoting") then return false end

	return true
end

local function canRequestMove()
	local character = getCharacter()
	if not character then return false end

	if character:GetAttribute("Stunned") then return false end
	if character:GetAttribute("Blocking") then return false end
	if character:GetAttribute("Guardbroken") then return false end
	if character:GetAttribute("UsingMove") then return false end
	if character:GetAttribute("Emoting") then return false end

	return true
end

local function canRequestBadTimeEarlyCancel(moveSlot)
	local character = player.Character
	if moveSlot ~= "Ultimate" or not character then
		return false
	end
	if character:GetAttribute("CurrentMoveId") ~= "BadTime" then
		return false
	end

	return character:GetAttribute("UsingMove") == true
end

local function canRequestBlock()
	local character = getCharacter()
	if not character then return false end

	if character:GetAttribute("SpawnSetupActive") then return false end
	if character:GetAttribute("CharacterSwitchDebounce") then return false end
	if character:GetAttribute("Morphing") then return false end
	if character:GetAttribute("IntroLocked") then return false end
	if character:GetAttribute("MovementLocked") then return false end
	if character:GetAttribute("DashLocked") then return false end
	if character:GetAttribute("Stunned") then return false end
	if character:GetAttribute("Blocking") then return false end
	if character:GetAttribute("Guardbroken") then return false end
	if character:GetAttribute("UsingMove") then return false end
	if character:GetAttribute("Emoting") then return false end

	return true
end

local function bufferUptilt()
	uptiltBuffered = true

	task.delay(UPTILT_BUFFER_TIME, function()
		uptiltBuffered = false
	end)
end

local function requestBlockStart()
	if blocking then return true end
	if cancelEmoteIfActive() then return false end
	if not canRequestBlock() then return false end

	blocking = true
	combatRemote:FireServer("BlockStart")

	return true
end

local function clearLocalBlockState(sendEnd)
	blocking = false

	if sendEnd then
		combatRemote:FireServer("BlockEnd")
	end
end

local function lockLocalJump(duration)
	jumpLockedUntil = os.clock() + (duration or CLIENT_JUMP_LOCK_TIME)

	local character, humanoid = getCharacter()
	if humanoid then
		humanoid.Jump = false
	end
end

local function getCooldownForSlot(moveSlot)
	local data = currentMoveDisplay[moveSlot]

	if workspace:GetAttribute("DebugCooldownsEnabled") == true then
		return workspace:GetAttribute("DebugCooldownOverride") or 1
	end

	if data and typeof(data.Cooldown) == "number" then
		return data.Cooldown
	end

	return DEFAULT_MOVE_DISPLAY[moveSlot] and DEFAULT_MOVE_DISPLAY[moveSlot].Cooldown or 1
end

local function getLockTimeForSlot(moveSlot)
	local data = currentMoveDisplay[moveSlot]

	if data and typeof(data.LockTime) == "number" then
		return math.max(0, data.LockTime)
	end

	return 0
end

local function addPotentialTarget(targets, seen, model, myCharacter)
	if not model or seen[model] or model == myCharacter or not model:IsA("Model") then
		return
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")

	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	seen[model] = true
	table.insert(targets, model)
end

local function collectTargetModelsFromFolder(targets, seen, folder, myCharacter)
	if not folder then
		return
	end

	for _, child in ipairs(folder:GetChildren()) do
		addPotentialTarget(targets, seen, child, myCharacter)
	end
end

local function getPotentialTargetCharacters()
	local targets = {}
	local seen = {}
	local myCharacter = player.Character

	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		addPotentialTarget(targets, seen, otherPlayer.Character, myCharacter)
	end

	for _, folderName in ipairs(TARGETABLE_FOLDERS) do
		collectTargetModelsFromFolder(targets, seen, workspace:FindFirstChild(folderName), myCharacter)
	end

	for _, instance in ipairs(CollectionService:GetTagged("TargetableCharacter")) do
		addPotentialTarget(targets, seen, instance, myCharacter)
	end

	return targets
end

local function startLocalCooldown(moveSlot)
	local cooldown = getCooldownForSlot(moveSlot)
	local lockTime = getLockTimeForSlot(moveSlot)

	if moveHudController then
		moveHudController:StartCooldown(moveSlot, cooldown, lockTime)
	end
end

local function getMouseTargetCharacter()
	local camera = workspace.CurrentCamera
	if not camera then return nil end

	local mouse = player:GetMouse()
	local unitRay = camera:ScreenPointToRay(mouse.X, mouse.Y)

	local origin = unitRay.Origin
	local direction = unitRay.Direction.Unit
	local maxDistance = 500

	local bestCharacter = nil
	local bestScore = math.huge

	for _, model in ipairs(getPotentialTargetCharacters()) do
		local root = model:FindFirstChild("HumanoidRootPart")

		if root then
			local toTarget = root.Position - origin
			local projectedDistance = toTarget:Dot(direction)

			if projectedDistance > 0 and projectedDistance <= maxDistance then
				local closestPointOnRay = origin + direction * projectedDistance
				local distanceFromRay = (root.Position - closestPointOnRay).Magnitude

				local aimAssistRadius = 10

				if distanceFromRay <= aimAssistRadius then
					local score = distanceFromRay + (projectedDistance * 0.01)

					if score < bestScore then
						bestScore = score
						bestCharacter = model
					end
				end
			end
		end
	end

	return bestCharacter
end

local function requestMove(moveSlot)
	if localMoveCooldowns[moveSlot] then return end
	if cancelEmoteIfActive() then return end
	if not canRequestMove() then
		if canRequestBadTimeEarlyCancel(moveSlot) then
			moveRemote:FireServer({
				MoveSlot = moveSlot,
				Action = "RequestBadTimeEarlyCancel",
			})
		end

		return
	end

	local moveInfo = currentMoveDisplay[moveSlot]
	local moveId = moveInfo and moveInfo.MoveId

	local targetCharacter = getMouseTargetCharacter()

	local mouse = player:GetMouse()
	local aimPosition = nil

	if mouse and mouse.Hit then
		aimPosition = mouse.Hit.Position
	end

	if moveInfo and moveInfo.RequiresTarget and not targetCharacter then
		warn("[CombatClient] Move needs a valid mouse target:", moveId or moveSlot)
		return
	end

	if moveInfo
		and moveInfo.RequiresTarget
		and typeof(moveInfo.TargetRange) == "number"
		and targetCharacter
	then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")

		if not root or not targetRoot or (targetRoot.Position - root.Position).Magnitude > moveInfo.TargetRange then
			warn("[CombatClient] Move target out of range:", moveId or moveSlot)
			return
		end
	end

	if moveInfo and moveInfo.RequiresAim and typeof(aimPosition) ~= "Vector3" then
		warn("[CombatClient] Move needs a valid aim position:", moveId or moveSlot)
		return
	end

	local lockTime = getLockTimeForSlot(moveSlot)
	local cooldown = lockTime + getCooldownForSlot(moveSlot)

	if moveHudController then
		moveHudController:SetActiveMove(moveSlot, true)
	end

	if moveSlot == "Ultimate" then
		moveRemote:FireServer({
			MoveSlot = moveSlot,
			TargetCharacter = targetCharacter,
			AimPosition = aimPosition,
		})

		task.delay(0.35, function()
			if moveHudController then
				moveHudController:SetActiveMove(moveSlot, false)
			end
		end)

		return
	end

	localMoveCooldowns[moveSlot] = true
	lockLocalJump(0.5)

	moveRemote:FireServer({
		MoveSlot = moveSlot,
		TargetCharacter = targetCharacter,
		AimPosition = aimPosition,
	})

	startLocalCooldown(moveSlot)

	task.delay(math.max(lockTime, 0.15), function()
		if localMoveCooldowns[moveSlot] and moveHudController then
			moveHudController:SetActiveMove(moveSlot, false)
		end
	end)

	task.delay(cooldown, function()
		localMoveCooldowns[moveSlot] = false

		if moveHudController then
			moveHudController:SetActiveMove(moveSlot, false)
		end
	end)
end

local function requestAttack()
	if localM1Cooldown then return end
	if cancelEmoteIfActive() then return end
	if not canRequestAttack() then return end

	localM1Cooldown = true

	local spaceHeld = UserInputService:IsKeyDown(Enum.KeyCode.Space)
	local wantUptilt = uptiltBuffered or spaceHeld

	uptiltBuffered = false
	lockLocalJump(CLIENT_JUMP_LOCK_TIME)

	combatRemote:FireServer("M1", {
		wantUptilt = wantUptilt,
		spaceHeld = spaceHeld,
	})

	task.delay(LOCAL_M1_COOLDOWN, function()
		localM1Cooldown = false
	end)
end

local function holdM1Loop()
	while mouseHeld do
		requestAttack()
		task.wait(LOCAL_M1_COOLDOWN)
	end
end

local function startBlocking()
	requestBlockStart()
end

local function stopBlocking()
	blocking = false
	combatRemote:FireServer("BlockEnd")
end

ultRemote.OnClientEvent:Connect(function(payload)
	if DEBUG_COMBAT_CLIENT then
		print("[CombatClient] UltRemote payload:", payload)
	end

	if typeof(payload) ~= "table" then return end

	if payload.Action == "Update" or payload.Action == "Spent" then
		if typeof(payload.Current) == "number" then
			currentUlt = payload.Current
		end

		if typeof(payload.Max) == "number" and payload.Max > 0 then
			currentUltMax = payload.Max
		end

		if typeof(payload.Alpha) == "number" then
			currentUltAlpha = math.clamp(payload.Alpha, 0, 1)
		else
			currentUltAlpha = math.clamp(currentUlt / currentUltMax, 0, 1)
		end

		currentUltFull = payload.Full == true or currentUltAlpha >= 1

		updateUltimateHud()
	end
end)

soulBurstRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end

	if payload.Action == "Update" or payload.Action == "Activated" or payload.Action == "Ready" then
		local value = payload.Value or payload.Current

		if typeof(value) == "number" then
			currentSoulBurst = value
		end

		if typeof(payload.Max) == "number" and payload.Max > 0 then
			currentSoulBurstMax = payload.Max
		end

		if typeof(payload.Alpha) == "number" then
			currentSoulBurstAlpha = math.clamp(payload.Alpha, 0, 1)
		else
			currentSoulBurstAlpha = math.clamp(currentSoulBurst / currentSoulBurstMax, 0, 1)
		end

		updateSoulBurstHud()
	end
end)

--============================================================
-- CINEMATIC / MOVE-FEEL CLIENT EFFECTS
--============================================================

local activeCinematicCamera = false
local oldCameraType = nil
local oldCameraSubject = nil
local oldMouseBehavior = nil
local oldMouseIconEnabled = nil
local cameraTween = nil
local cinematicCameraToken = 0
local activeCinematicAllowsShiftLock = false

local activeCameraShakes = {}
local lastShakeTransform = CFrame.new()

local impactFrameToken = 0
local impactFrameTween = nil

local fovPunchToken = 0
local fovPunchInTween = nil
local fovPunchOutTween = nil
local fovPunchBaseFOV = nil

local activeFOVOffsets = {}
local fovOffsetTween = nil
local fovOffsetTweenToken = 0
local fovOffsetBaseFOV = nil
local fovOffsetCamera = nil

local function getCamera()
	return workspace.CurrentCamera
end

local function isCameraShakeEnabled()
	return player:GetAttribute("Setting_CameraShake") ~= false
end

local function clearActiveCameraShakes()
	table.clear(activeCameraShakes)

	local camera = getCamera()
	if camera and lastShakeTransform ~= CFrame.new() then
		camera.CFrame = camera.CFrame * lastShakeTransform:Inverse()
	end

	lastShakeTransform = CFrame.new()
end

local function ensureFOVBase(camera)
	if not camera then return nil end

	if fovOffsetCamera ~= camera then
		fovOffsetCamera = camera
		fovOffsetBaseFOV = camera.FieldOfView
	end

	if typeof(fovOffsetBaseFOV) ~= "number" then
		fovOffsetBaseFOV = camera.FieldOfView
	end

	return fovOffsetBaseFOV
end

local function getFOVOffsetTotal()
	local total = 0

	for _, amount in pairs(activeFOVOffsets) do
		if typeof(amount) == "number" then
			total += amount
		end
	end

	return total
end

local function getSustainedFOVTarget(camera)
	local baseFOV = ensureFOVBase(camera)
	if not baseFOV then return nil end

	return math.clamp(baseFOV + getFOVOffsetTotal(), 1, 120)
end

local function cancelFOVPunch()
	fovPunchToken += 1

	if fovPunchInTween then
		fovPunchInTween:Cancel()
		fovPunchInTween = nil
	end

	if fovPunchOutTween then
		fovPunchOutTween:Cancel()
		fovPunchOutTween = nil
	end

	fovPunchBaseFOV = nil
end

local function tweenToSustainedFOV(tweenTime)
	local camera = getCamera()
	if not camera then return end

	cancelFOVPunch()
	fovOffsetTweenToken += 1
	local token = fovOffsetTweenToken

	local targetFOV = getSustainedFOVTarget(camera)
	if not targetFOV then return end

	if fovOffsetTween then
		fovOffsetTween:Cancel()
		fovOffsetTween = nil
	end

	tweenTime = typeof(tweenTime) == "number" and math.max(0, tweenTime) or 0.16

	fovOffsetTween = TweenService:Create(
		camera,
		TweenInfo.new(tweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			FieldOfView = targetFOV,
		}
	)

	fovOffsetTween.Completed:Connect(function()
		if token ~= fovOffsetTweenToken then return end
		fovOffsetTween = nil
	end)

	fovOffsetTween:Play()
end

local function setFOVOffset(id, amount, tweenTime)
	if typeof(id) ~= "string" or id == "" then return end
	if typeof(amount) ~= "number" then return end

	activeFOVOffsets[id] = amount
	tweenToSustainedFOV(tweenTime or 0.12)
end

local function clearFOVOffset(id, tweenTime)
	if typeof(id) ~= "string" or id == "" then return end

	activeFOVOffsets[id] = nil
	tweenToSustainedFOV(tweenTime or 0.16)
end

local function resetFOV(tweenTime)
	table.clear(activeFOVOffsets)
	tweenToSustainedFOV(tweenTime or 0.16)
end

local function shouldAllowShiftLockForCamera(payload)
	if typeof(payload) ~= "table" then
		return false
	end

	return payload.AllowShiftLock == true
		or payload.AllowShiftLockDuringCinematic == true
		or payload.SuppressShiftLock == false
		or payload.SuppressShiftLockDuringCinematic == false
		or payload.CameraPolicy == "ShiftLockAllowed"
		or payload.CameraControlMode == "ShiftLockAllowed"
end

local function beginCinematicCamera(payload)
	local camera = getCamera()
	if not camera then return end
	local allowShiftLock = shouldAllowShiftLockForCamera(payload)

	if not activeCinematicCamera then
		oldCameraType = camera.CameraType
		oldCameraSubject = camera.CameraSubject
		oldMouseBehavior = UserInputService.MouseBehavior
		oldMouseIconEnabled = UserInputService.MouseIconEnabled
	end

	activeCinematicCamera = true
	activeCinematicAllowsShiftLock = allowShiftLock
	player:SetAttribute("CinematicCameraActive", true)
	player:SetAttribute("AllowShiftLockDuringCinematic", allowShiftLock)
	player:SetAttribute("SuppressShiftLockDuringCinematic", not allowShiftLock)

	if not allowShiftLock then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end

	camera.CameraType = Enum.CameraType.Scriptable
end

local function setCinematicCamera(cframe, payload)
	local camera = getCamera()
	if not camera then return end

	beginCinematicCamera(payload)

	if cameraTween then
		cameraTween:Cancel()
		cameraTween = nil
	end

	if not activeCinematicAllowsShiftLock then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end

	camera.CFrame = cframe
end

local function tweenCinematicCamera(cframe, tweenTime, payload)
	local camera = getCamera()
	if not camera then return end

	beginCinematicCamera(payload)

	if cameraTween then
		cameraTween:Cancel()
		cameraTween = nil
	end

	cinematicCameraToken += 1
	local token = cinematicCameraToken

	if not activeCinematicAllowsShiftLock then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end

	cameraTween = TweenService:Create(
		camera,
		TweenInfo.new(
			tweenTime or 0.25,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		),
		{
			CFrame = cframe,
		}
	)

	cameraTween.Completed:Connect(function()
		if token ~= cinematicCameraToken then return end
		cameraTween = nil
	end)

	cameraTween:Play()
end

local function resetCinematicCamera()
	local camera = getCamera()
	if not camera then return end

	cinematicCameraToken += 1

	if cameraTween then
		cameraTween:Cancel()
		cameraTween = nil
	end

	activeCinematicCamera = false

	camera.CameraType = oldCameraType or Enum.CameraType.Custom

	if oldCameraSubject then
		camera.CameraSubject = oldCameraSubject
	elseif player.Character then
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end

	UserInputService.MouseBehavior = oldMouseBehavior or Enum.MouseBehavior.Default

	if typeof(oldMouseIconEnabled) == "boolean" then
		UserInputService.MouseIconEnabled = oldMouseIconEnabled
	end

	oldCameraType = nil
	oldCameraSubject = nil
	oldMouseBehavior = nil
	oldMouseIconEnabled = nil
	activeCinematicAllowsShiftLock = false

	player:SetAttribute("CinematicCameraActive", false)
	player:SetAttribute("AllowShiftLockDuringCinematic", false)
	player:SetAttribute("SuppressShiftLockDuringCinematic", false)
end

local function startCameraShake(intensity, roughness, duration)
	if not isCameraShakeEnabled() then
		clearActiveCameraShakes()
		return
	end

	intensity = typeof(intensity) == "number" and math.max(0, intensity) or 1
	roughness = typeof(roughness) == "number" and math.max(0.1, roughness) or 8
	duration = typeof(duration) == "number" and math.max(0.01, duration) or 0.25

	table.insert(activeCameraShakes, {
		StartTime = os.clock(),
		Duration = duration,
		Intensity = intensity,
		Roughness = roughness,
		Seed = math.random() * 1000,
	})
end

player:GetAttributeChangedSignal("Setting_CameraShake"):Connect(function()
	if not isCameraShakeEnabled() then
		clearActiveCameraShakes()
	end
end)

local function getImpactFrameEffect()
	local effect = Lighting:FindFirstChild("CombatImpactFrame")

	if effect and not effect:IsA("ColorCorrectionEffect") then
		effect = nil
	end

	if not effect then
		effect = Instance.new("ColorCorrectionEffect")
		effect.Name = "CombatImpactFrame"
		effect.Enabled = false
		effect.Parent = Lighting
	end

	return effect
end

local function playImpactFrame(payload)
	local effect = getImpactFrameEffect()

	impactFrameToken += 1
	local token = impactFrameToken

	local holdTime = typeof(payload.Duration) == "number" and math.max(0.01, payload.Duration) or 0.18
	local inTime = typeof(payload.InTime) == "number" and math.max(0, payload.InTime) or 0.035
	local outTime = typeof(payload.OutTime) == "number" and math.max(0.01, payload.OutTime) or 0.18

	local tintColor = typeof(payload.Color) == "Color3" and payload.Color or Color3.new(1, 1, 1)
	local contrast = typeof(payload.Contrast) == "number" and payload.Contrast or 0.45
	local saturation = typeof(payload.Saturation) == "number" and payload.Saturation or -0.2
	local brightness = typeof(payload.Brightness) == "number" and payload.Brightness or 0.05

	if impactFrameTween then
		impactFrameTween:Cancel()
		impactFrameTween = nil
	end

	effect.Enabled = true
	effect.TintColor = Color3.new(1, 1, 1)
	effect.Contrast = 0
	effect.Saturation = 0
	effect.Brightness = 0

	local tweenIn = TweenService:Create(
		effect,
		TweenInfo.new(inTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			TintColor = tintColor,
			Contrast = contrast,
			Saturation = saturation,
			Brightness = brightness,
		}
	)

	impactFrameTween = tweenIn
	tweenIn:Play()

	tweenIn.Completed:Connect(function()
		if token ~= impactFrameToken then return end

		task.delay(holdTime, function()
			if token ~= impactFrameToken then return end
			if not effect or not effect.Parent then return end

			local tweenOut = TweenService:Create(
				effect,
				TweenInfo.new(outTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					TintColor = Color3.new(1, 1, 1),
					Contrast = 0,
					Saturation = 0,
					Brightness = 0,
				}
			)

			impactFrameTween = tweenOut
			tweenOut:Play()

			tweenOut.Completed:Connect(function()
				if token ~= impactFrameToken then return end
				if not effect or not effect.Parent then return end

				effect.Enabled = false
				effect.TintColor = Color3.new(1, 1, 1)
				effect.Contrast = 0
				effect.Saturation = 0
				effect.Brightness = 0
				impactFrameTween = nil
			end)
		end)
	end)
end

local function playFOVPunch(targetFOV, inTime, outTime, holdTime)
	local camera = getCamera()
	if not camera then return end

	fovPunchToken += 1
	local token = fovPunchToken

	if fovOffsetTween then
		fovOffsetTween:Cancel()
		fovOffsetTween = nil
	end

	local originalFOV = fovPunchBaseFOV or getSustainedFOVTarget(camera) or camera.FieldOfView
	fovPunchBaseFOV = originalFOV

	if fovPunchInTween then
		fovPunchInTween:Cancel()
		fovPunchInTween = nil
	end

	if fovPunchOutTween then
		fovPunchOutTween:Cancel()
		fovPunchOutTween = nil
	end

	targetFOV = typeof(targetFOV) == "number" and math.clamp(targetFOV, 1, 120) or math.max(1, originalFOV - 6)
	inTime = typeof(inTime) == "number" and math.max(0, inTime) or 0.08
	holdTime = typeof(holdTime) == "number" and math.max(0, holdTime) or 0
	outTime = typeof(outTime) == "number" and math.max(0, outTime) or 0.35

	fovPunchInTween = TweenService:Create(
		camera,
		TweenInfo.new(inTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			FieldOfView = targetFOV,
		}
	)

	fovPunchInTween.Completed:Connect(function()
		if token ~= fovPunchToken then return end

		task.delay(holdTime, function()
			if token ~= fovPunchToken then return end
			if not camera or not camera.Parent then return end

			fovPunchOutTween = TweenService:Create(
				camera,
				TweenInfo.new(outTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					FieldOfView = getSustainedFOVTarget(camera) or originalFOV,
				}
			)

			fovPunchOutTween.Completed:Connect(function()
				if token ~= fovPunchToken then return end
				if camera and camera.Parent then
					camera.FieldOfView = getSustainedFOVTarget(camera) or originalFOV
				end

				fovPunchBaseFOV = nil
				fovPunchOutTween = nil
			end)

			fovPunchOutTween:Play()
			fovPunchInTween = nil
		end)
	end)

	fovPunchInTween:Play()
end

RunService:BindToRenderStep("CombatCameraShake", Enum.RenderPriority.Camera.Value + 1, function()
	local camera = getCamera()
	if not camera then return end

	if lastShakeTransform ~= CFrame.new() then
		camera.CFrame = camera.CFrame * lastShakeTransform:Inverse()
		lastShakeTransform = CFrame.new()
	end

	if #activeCameraShakes == 0 then
		return
	end

	local now = os.clock()
	local totalOffset = Vector3.zero

	for index = #activeCameraShakes, 1, -1 do
		local shake = activeCameraShakes[index]
		local elapsed = now - shake.StartTime

		if elapsed >= shake.Duration then
			table.remove(activeCameraShakes, index)
		else
			local alpha = 1 - math.clamp(elapsed / shake.Duration, 0, 1)
			local time = (elapsed * shake.Roughness) + shake.Seed

			local offset = Vector3.new(
				math.noise(time, 0, 0),
				math.noise(0, time, 0),
				math.noise(0, 0, time)
			)

			totalOffset += offset * shake.Intensity * alpha * 0.18
		end
	end

	if totalOffset.Magnitude > 0 then
		lastShakeTransform = CFrame.new(totalOffset)
		camera.CFrame = camera.CFrame * lastShakeTransform
	end
end)

cinematicRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end

	if payload.Action == "SetCamera" and typeof(payload.CFrame) == "CFrame" then
		setCinematicCamera(payload.CFrame, payload)

	elseif payload.Action == "TweenCamera" and typeof(payload.CFrame) == "CFrame" then
		tweenCinematicCamera(payload.CFrame, payload.Time or 0.25, payload)

	elseif payload.Action == "ResetCamera" then
		resetCinematicCamera()

	elseif payload.Action == "CameraShakeOnce" then
		startCameraShake(payload.Intensity, payload.Roughness, payload.Duration)

	elseif payload.Action == "ImpactFrame" then
		playImpactFrame(payload)

	elseif payload.Action == "FOVPunch" then
		playFOVPunch(payload.TargetFOV, payload.InTime, payload.OutTime, payload.HoldTime)

	elseif payload.Action == "SetFOVOffset" then
		setFOVOffset(payload.Id, payload.Amount, payload.TweenTime)

	elseif payload.Action == "ClearFOVOffset" then
		clearFOVOffset(payload.Id, payload.TweenTime)

	elseif payload.Action == "ResetFOV" then
		resetFOV(payload.TweenTime)
	end
end)

UserInputService.JumpRequest:Connect(function()
	local character, humanoid = getCharacter()
	if not humanoid then return end

	if os.clock() < jumpLockedUntil then
		humanoid.Jump = false
		return
	end

	if character:GetAttribute("UsingMove") then
		humanoid.Jump = false
	end

	if character:GetAttribute("Emoting") then
		humanoid.Jump = false
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.Space then
		bufferUptilt()
	end

	local moveSlot = MOVE_KEYS[input.KeyCode]
	if moveSlot then
		requestMove(moveSlot)
		return
	end

	if input.KeyCode == BLOCK_KEY then
		startBlocking()
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if mouseHeld then return end

		mouseHeld = true
		task.spawn(holdM1Loop)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		mouseHeld = false
	end

	if input.KeyCode == BLOCK_KEY then
		stopBlocking()
	end
end)

local function hookCharacter(character)
	task.wait(0.25)

	refreshMoveDisplay()
	updateUltimateHud()
	updateSoulBurstHud()

	character:GetAttributeChangedSignal("CharacterName"):Connect(function()
		refreshMoveDisplay()
		updateUltimateHud()
		updateSoulBurstHud()
	end)

	character:GetAttributeChangedSignal("CombatMode"):Connect(function()
		refreshMoveDisplay()
		updateUltimateHud()
		updateSoulBurstHud()
	end)

	character:GetAttributeChangedSignal("Guardbroken"):Connect(function()
		if character:GetAttribute("Guardbroken") then
			clearLocalBlockState(false)
		end
	end)
end

player:GetAttributeChangedSignal("CharacterName"):Connect(function()
	refreshMoveDisplay()
	updateUltimateHud()
	updateSoulBurstHud()
end)

moveHudController = MoveHudController.new({
	Player = player,
	ReplicatedStorage = ReplicatedStorage,
	CharactersFolder = charactersFolder,
	TweenService = TweenService,
	GetCurrentCharacterName = getCurrentCharacterName,
	GetCurrentCombatMode = getCurrentCombatMode,
	OnMoveButtonPressed = function(moveSlot)
		requestMove(moveSlot)
	end,
})
moveHudController:Create()
refreshMoveDisplay()

player.CharacterAdded:Connect(hookCharacter)

if player.Character then
	hookCharacter(player.Character)
end
