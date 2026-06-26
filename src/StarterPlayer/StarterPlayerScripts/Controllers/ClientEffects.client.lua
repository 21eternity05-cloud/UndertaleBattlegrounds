local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local cinematicRemote = remotes:WaitForChild("CinematicRemote")

local modules = script.Parent.Parent:WaitForChild("ClientModules")
local CameraShake = require(modules:WaitForChild("CameraShake"))
local ImpactFrame = require(modules:WaitForChild("ImpactFrame"))

local function isCameraShakeEnabled()
	return player:GetAttribute("Setting_CameraShake") ~= false
end

local function refreshCameraShakeSetting()
	if not isCameraShakeEnabled() then
		CameraShake:StopAll()
	end
end

local function resetEffects()
	CameraShake:StopAll()
	ImpactFrame:Reset()
end

player:GetAttributeChangedSignal("Setting_CameraShake"):Connect(refreshCameraShakeSetting)
refreshCameraShakeSetting()

cinematicRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end

	if payload.Action == "CameraShakeOnce" then
		if not isCameraShakeEnabled() then
			return
		end

		CameraShake:ShakeOnce(payload.Intensity, payload.Roughness, payload.Duration)
	elseif payload.Action == "CameraShakeSustain" then
		if not isCameraShakeEnabled() then
			return
		end

		CameraShake:ShakeSustain(payload.Id, payload.Intensity, payload.Roughness)
	elseif payload.Action == "CameraShakeStop" then
		CameraShake:StopSustain(payload.Id)
	elseif payload.Action == "ImpactFrame" then
		if payload.Mode == "RedBlack" then
			ImpactFrame:RedBlack(payload.Duration)
		elseif payload.Mode == "Invert" then
			ImpactFrame:Invert(payload.Duration)
		else
			ImpactFrame:Flash(payload.Color, payload.Contrast, payload.Saturation, payload.Duration)
		end
	elseif payload.Action == "ResetCamera" then
		resetEffects()
	end
end)

player.CharacterAdded:Connect(function(character)
	resetEffects()

	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid then
		humanoid.Died:Connect(resetEffects)
	end
end)

if player.Character then
	local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(resetEffects)
	end
end
