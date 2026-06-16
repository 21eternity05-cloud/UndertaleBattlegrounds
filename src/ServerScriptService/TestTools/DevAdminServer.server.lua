local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DevAdminService = require(script.Parent:WaitForChild("DevAdminService")).new()

local REMOTE_NAME = "DevAdminRemote"
local warnedUnknownActions = {}

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local remote = remotes:FindFirstChild(REMOTE_NAME)
if not remote then
	remote = Instance.new("RemoteFunction")
	remote.Name = REMOTE_NAME
	remote.Parent = remotes
elseif not remote:IsA("RemoteFunction") then
	warn("[DevAdminServer] Existing DevAdminRemote is not a RemoteFunction")
	return
end

remote.OnServerInvoke = function(player, action, payload)
	if action == "GetStatus" then
		return DevAdminService:GetPermissionStatus(player)
	end

	if action == "CombatDebugAction" then
		return DevAdminService:HandleCombatDebugAction(player, payload)
	end

	if action == "GetDataManagerSnapshot" then
		return DevAdminService:GetDataManagerSnapshot(player, payload)
	end

	if action == "ApplyDataManagerAction" then
		return DevAdminService:ApplyDataManagerAction(player, payload)
	end

	if action == "AbuseAction" then
		return DevAdminService:HandleAbuseAction(player, payload)
	end

	if action == "SpawnDummy" then
		return DevAdminService:SpawnDummy(player, payload)
	end

	if action == "ClearDebugDummies" then
		return DevAdminService:ClearDebugDummies(player)
	end

	local key = tostring(player and player.UserId or "unknown") .. ":" .. tostring(action)
	if not warnedUnknownActions[key] then
		warn("[DevAdminServer] Rejected unknown action:", player and player.Name or "nil", tostring(action))
		warnedUnknownActions[key] = true
	end

	return {
		CanUseDevMenu = false,
		Role = "None",
		CanUseCombatDebug = false,
		CanUseDataManager = false,
		CanUseAbuseTools = false,
		Error = "UnknownAction",
	}
end
