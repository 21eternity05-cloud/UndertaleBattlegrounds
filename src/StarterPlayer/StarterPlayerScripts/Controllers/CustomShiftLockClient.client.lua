local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local SHIFT_LOCK_KEY = Enum.KeyCode.LeftShift

-- Roblox default shift-lock offset is roughly this.
-- If it ever feels backwards, flip X to -1.75.
local SHIFT_LOCK_CAMERA_OFFSET = Vector3.new(1.75, 0, 0)
local SHIFT_LOCK_CURSOR_ICON = "rbxassetid://240064847"

local PAUSE_PLAYER_ATTRIBUTES = {
	"MouseFreeMode",
	"CustomShiftLockPaused",
	"MenuOpen",
	"SuppressShiftLock",
	"SuppressShiftLockDuringCinematic",
}

local PAUSE_CHARACTER_ATTRIBUTES = {
	"CinematicLocked",
	"CinematicCameraActive",
	"Grabbed",
	"Grabbing",
	"Emoting",
	"HardLocked",
	"SuppressShiftLock",
	"SuppressShiftLockDuringCinematic",
}

local POLICY_ATTRIBUTES = {
	"AllowShiftLockDuringCinematic",
	"CinematicCameraActive",
}

local shiftLockEnabled = false
local shiftLockApplied = false
local cleanupToken = 0

local autoRotateHumanoid = nil
local oldAutoRotate = nil

local mouse = player:GetMouse()
local oldMouseIcon = nil
local mouseIconApplied = false

local characterAttributeConnections = {}

pcall(function()
	player.DevEnableMouseLock = false
end)

player:SetAttribute("CustomShiftLockEnabled", false)
player:SetAttribute("CustomShiftLockActive", false)

local function getCharacterHumanoidRoot()
	local character = player.Character
	if not character then
		return nil, nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or humanoid.Health <= 0 or not root then
		return character, nil, nil
	end

	return character, humanoid, root
end

local function hasAnyAttribute(instance, names)
	if not instance then
		return false
	end

	for _, name in ipairs(names) do
		if instance:GetAttribute(name) == true then
			return true
		end
	end

	return false
end

local function isPaused()
	if hasAnyAttribute(player, PAUSE_PLAYER_ATTRIBUTES) then
		return true
	end

	local character = player.Character
	local allowDuringCinematic = player:GetAttribute("AllowShiftLockDuringCinematic") == true
		or (character and character:GetAttribute("AllowShiftLockDuringCinematic") == true)

	if hasAnyAttribute(character, PAUSE_CHARACTER_ATTRIBUTES) and not allowDuringCinematic then
		return true
	end

	local cinematicCameraActive = player:GetAttribute("CinematicCameraActive") == true
		or (character and character:GetAttribute("CinematicCameraActive") == true)

	if cinematicCameraActive and not allowDuringCinematic then
		return true
	end

	local camera = workspace.CurrentCamera
	if camera and camera.CameraType == Enum.CameraType.Scriptable and not allowDuringCinematic then
		return true
	end

	return false
end

local function isScriptableCameraAllowed()
	local character = player.Character

	return player:GetAttribute("AllowShiftLockDuringCinematic") == true
		or (character and character:GetAttribute("AllowShiftLockDuringCinematic") == true)
end

local refreshShiftLock

local function restoreAutoRotate()
	if not autoRotateHumanoid then
		return
	end

	if autoRotateHumanoid.Parent then
		autoRotateHumanoid.AutoRotate = true
	end

	autoRotateHumanoid = nil
	oldAutoRotate = nil
end

local function forceCurrentHumanoidAutoRotate()
	local _, humanoid = getCharacterHumanoidRoot()

	if humanoid then
		humanoid.AutoRotate = true
	end
end

local function applyShiftLockCursor()
	if mouseIconApplied then
		return
	end

	mouseIconApplied = true
	oldMouseIcon = mouse.Icon
	mouse.Icon = SHIFT_LOCK_CURSOR_ICON
end

local function restoreShiftLockCursor()
	if not mouseIconApplied then
		return
	end

	mouseIconApplied = false
	mouse.Icon = oldMouseIcon or ""
	oldMouseIcon = nil
end

local function reassertShiftLockReleased(token)
	task.defer(function()
		if cleanupToken ~= token or shiftLockEnabled then
			return
		end

		for _ = 1, 2 do
			RunService.RenderStepped:Wait()

			if cleanupToken ~= token or shiftLockEnabled then
				return
			end

			shiftLockApplied = false
			player:SetAttribute("CustomShiftLockActive", false)
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			restoreShiftLockCursor()
			forceCurrentHumanoidAutoRotate()
		end
	end)
end

local function releaseShiftLock(forceFullCleanup)
	if forceFullCleanup then
		cleanupToken += 1
		shiftLockApplied = false
		player:SetAttribute("CustomShiftLockActive", false)
	end

	if not shiftLockApplied then
		restoreShiftLockCursor()
		restoreAutoRotate()
		if forceFullCleanup then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			forceCurrentHumanoidAutoRotate()
			reassertShiftLockReleased(cleanupToken)
		end
		return
	end

	shiftLockApplied = false
	player:SetAttribute("CustomShiftLockActive", false)

	UserInputService.MouseBehavior = Enum.MouseBehavior.Default

	restoreShiftLockCursor()
	restoreAutoRotate()

	if forceFullCleanup then
		forceCurrentHumanoidAutoRotate()
		reassertShiftLockReleased(cleanupToken)
	end
end

local function applyShiftLock()
	local _, humanoid = getCharacterHumanoidRoot()

	if not humanoid then
		releaseShiftLock()
		return
	end

	if autoRotateHumanoid ~= humanoid then
		restoreAutoRotate()
		autoRotateHumanoid = humanoid
		oldAutoRotate = humanoid.AutoRotate
	end

	humanoid.AutoRotate = false

	shiftLockApplied = true
	player:SetAttribute("CustomShiftLockActive", true)

	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	applyShiftLockCursor()
end

refreshShiftLock = function()
	if shiftLockEnabled and not isPaused() then
		applyShiftLock()
	else
		releaseShiftLock()
	end
end

local function setShiftLockEnabled(enabled)
	shiftLockEnabled = enabled == true
	player:SetAttribute("CustomShiftLockEnabled", shiftLockEnabled)

	if shiftLockEnabled then
		refreshShiftLock()
	else
		releaseShiftLock(true)
	end
end

local function resetShiftLockForCharacterChange()
	shiftLockEnabled = false
	player:SetAttribute("CustomShiftLockEnabled", false)
	releaseShiftLock(true)
end

local function disconnectCharacterAttributeConnections()
	for _, connection in ipairs(characterAttributeConnections) do
		connection:Disconnect()
	end

	table.clear(characterAttributeConnections)
end

local function watchCharacter(character)
	disconnectCharacterAttributeConnections()

	if character then
		for _, attributeName in ipairs(PAUSE_CHARACTER_ATTRIBUTES) do
			table.insert(characterAttributeConnections, character:GetAttributeChangedSignal(attributeName):Connect(refreshShiftLock))
		end

		for _, attributeName in ipairs(POLICY_ATTRIBUTES) do
			table.insert(characterAttributeConnections, character:GetAttributeChangedSignal(attributeName):Connect(refreshShiftLock))
		end
	end

	refreshShiftLock()
end

for _, attributeName in ipairs(PAUSE_PLAYER_ATTRIBUTES) do
	player:GetAttributeChangedSignal(attributeName):Connect(refreshShiftLock)
end

for _, attributeName in ipairs(POLICY_ATTRIBUTES) do
	player:GetAttributeChangedSignal(attributeName):Connect(refreshShiftLock)
end

player.CharacterAdded:Connect(watchCharacter)

player.CharacterRemoving:Connect(function()
	disconnectCharacterAttributeConnections()
	resetShiftLockForCharacterChange()
end)

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(refreshShiftLock)

ContextActionService:BindActionAtPriority(
	"CustomShiftLockToggle",
	function(_, inputState)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Sink
		end

		if UserInputService:GetFocusedTextBox() then
			return Enum.ContextActionResult.Pass
		end

		setShiftLockEnabled(not shiftLockEnabled)
		return Enum.ContextActionResult.Sink
	end,
	false,
	Enum.ContextActionPriority.High.Value + 1,
	SHIFT_LOCK_KEY
)

RunService:BindToRenderStep("CustomShiftLock", Enum.RenderPriority.Camera.Value + 2, function()
	if not shiftLockApplied then
		return
	end

	if isPaused() then
		refreshShiftLock()
		return
	end

	local _, humanoid, root = getCharacterHumanoidRoot()
	local camera = workspace.CurrentCamera

	if not humanoid or not root or not camera then
		refreshShiftLock()
		return
	end

	if camera.CameraType == Enum.CameraType.Scriptable and not isScriptableCameraAllowed() then
		refreshShiftLock()
		return
	end

	humanoid.AutoRotate = false
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	applyShiftLockCursor()

	if camera.CameraType == Enum.CameraType.Scriptable then
		return
	end

	-- Recreate default Roblox shift-lock shoulder offset.
	-- This runs after the normal camera update, so it layers the offset on top.
	camera.CFrame = camera.CFrame * CFrame.new(SHIFT_LOCK_CAMERA_OFFSET)

	local lookVector = camera.CFrame.LookVector
	local flatLook = Vector3.new(lookVector.X, 0, lookVector.Z)

	if flatLook.Magnitude < 0.001 then
		return
	end

	local rootPosition = root.Position
	root.CFrame = CFrame.lookAt(rootPosition, rootPosition + flatLook.Unit)
end)

watchCharacter(player.Character)
