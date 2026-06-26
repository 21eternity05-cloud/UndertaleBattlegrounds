local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ShopLocationService = {}
ShopLocationService.__index = ShopLocationService

local SHOP_FOLDER_NAME = "SHOP"
local SHOP_PLACEHOLDER_NAME = "Placeholder"
local REMOTE_NAME = "ShopLocationRemote"

function ShopLocationService.new(config)
	local self = setmetatable({}, ShopLocationService)

	self.Config = config
	self.Remote = nil

	return self
end

function ShopLocationService:GetRemotesFolder()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")

	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	return remotes
end

function ShopLocationService:GetRemote()
	if self.Remote then
		return self.Remote
	end

	local remotes = self:GetRemotesFolder()
	local remote = remotes:FindFirstChild(REMOTE_NAME)

	if not remote then
		remote = Instance.new("RemoteFunction")
		remote.Name = REMOTE_NAME
		remote.Parent = remotes
	end

	self.Remote = remote
	return remote
end

function ShopLocationService:GetShopLocation()
	local shopFolder = Workspace:FindFirstChild(SHOP_FOLDER_NAME)
	local placeholder = shopFolder and shopFolder:FindFirstChild(SHOP_PLACEHOLDER_NAME)

	if placeholder and placeholder:IsA("BasePart") then
		return {
			Exists = true,
			PlaceholderCFrame = placeholder.CFrame,
			PlaceholderPosition = placeholder.Position,
		}
	end

	return {
		Exists = false,
	}
end

function ShopLocationService:Start()
	local remote = self:GetRemote()

	remote.OnServerInvoke = function()
		return self:GetShopLocation()
	end
end

return ShopLocationService
