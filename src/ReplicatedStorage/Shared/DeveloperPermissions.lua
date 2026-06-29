local DeveloperPermissions = {}

DeveloperPermissions.GroupId = 33686072
DeveloperPermissions.MinDeveloperRank = 200
DeveloperPermissions.OwnerRank = 255
DeveloperPermissions.PlaceOwnerCanUseDevMenu = true

DeveloperPermissions.OwnerUserIds = {
	[78551444] = true,
}

DeveloperPermissions.DeveloperUserIds = {
	[78551444] = true,
}

function DeveloperPermissions.GetGroupRank(player)
	if not player or DeveloperPermissions.GroupId <= 0 then
		return 0
	end

	local success, rank = pcall(function()
		return player:GetRankInGroup(DeveloperPermissions.GroupId)
	end)

	if not success or typeof(rank) ~= "number" then
		return 0
	end

	return rank
end

function DeveloperPermissions.IsPlaceOwner(player)
	if not player or DeveloperPermissions.PlaceOwnerCanUseDevMenu ~= true then
		return false
	end

	if game.CreatorType ~= Enum.CreatorType.User then
		return false
	end

	return player.UserId == game.CreatorId
end

function DeveloperPermissions.GetRole(player)
	if not player then
		return "None"
	end

	if DeveloperPermissions.OwnerUserIds[player.UserId] == true or DeveloperPermissions.IsPlaceOwner(player) then
		return "Owner"
	end

	local rank = DeveloperPermissions.GetGroupRank(player)

	if rank >= DeveloperPermissions.OwnerRank then
		return "Owner"
	end

	if DeveloperPermissions.DeveloperUserIds[player.UserId] == true or rank >= DeveloperPermissions.MinDeveloperRank then
		return "Developer"
	end

	return "None"
end

function DeveloperPermissions.IsDeveloper(player)
	return DeveloperPermissions.GetRole(player) ~= "None"
end

function DeveloperPermissions.IsOwner(player)
	return DeveloperPermissions.GetRole(player) == "Owner"
end

function DeveloperPermissions.IsPublicCharacter(data)
	if typeof(data) ~= "table" or data.Hidden == true then
		return false
	end

	if data.Released ~= nil then
		return data.Released == true
	end

	return data.ReleaseCharacter == true
		and data.Public ~= false
		and data.DeveloperOnly ~= true
		and data.WIP ~= true
end

function DeveloperPermissions.CanAccessCharacter(player, data)
	if DeveloperPermissions.IsPublicCharacter(data) then
		return true
	end

	if data.DeveloperOnly ~= nil then
		return data.DeveloperOnly == true and DeveloperPermissions.IsDeveloper(player)
	end

	return DeveloperPermissions.IsDeveloper(player)
end

function DeveloperPermissions.CanPreviewCharacter(player, data)
	if typeof(data) ~= "table" then
		return false
	end

	if DeveloperPermissions.CanAccessCharacter(player, data) then
		return true
	end

	if data.Hidden == true then
		return false
	end

	if data.PublicPreview ~= nil then
		return data.PublicPreview == true
	end

	return false
end

return DeveloperPermissions
