local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LoreData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LoreData"))

local LoreCinematicService = {}
LoreCinematicService.__index = LoreCinematicService

function LoreCinematicService.new(config, progressionService)
	local self = setmetatable({}, LoreCinematicService)

	self.Config = config
	self.ProgressionService = progressionService
	self.Remote = nil
	self.HookedPrompts = {}

	return self
end

function LoreCinematicService:GetRemote()
	if self.Remote then
		return self.Remote
	end

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")

	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	local remote = remotes:FindFirstChild("LoreRemote")

	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "LoreRemote"
		remote.Parent = remotes
	end

	self.Remote = remote
	return remote
end

function LoreCinematicService:GetLoreId(instance)
	local attr = instance:GetAttribute("LoreId")
	if typeof(attr) == "string" and attr ~= "" then
		return attr
	end

	local name = instance.Name
	local fromName = string.match(name, "^SAVE_POINT_(.+)$")
	if fromName and LoreData[fromName] then
		return fromName
	end

	return "HollowRouteMemory"
end

function LoreCinematicService:GetPromptPart(instance)
	if instance:IsA("BasePart") then
		return instance
	end

	if instance:IsA("Model") then
		return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	end

	return nil
end

function LoreCinematicService:HookSavePoint(instance)
	local part = self:GetPromptPart(instance)
	if not part or self.HookedPrompts[part] then return end

	local prompt = part:FindFirstChild("LorePrompt")

	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "LorePrompt"
		prompt.ActionText = "SAVE"
		prompt.ObjectText = "Memory"
		prompt.HoldDuration = 0.2
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
	end

	self.HookedPrompts[part] = prompt

	prompt.Triggered:Connect(function(player)
		self:PlayLore(player, self:GetLoreId(instance))
	end)
end

function LoreCinematicService:ScanNamedSavePoints()
	for _, instance in ipairs(workspace:GetDescendants()) do
		if string.match(instance.Name, "^SAVE_POINT_") then
			self:HookSavePoint(instance)
		end
	end
end

function LoreCinematicService:PlayLore(player, loreId)
	if not player or not Players:FindFirstChild(player.Name) then return end

	local entry = LoreData[loreId] or LoreData.HollowRouteMemory
	if not entry then return end

	if self.ProgressionService then
		self.ProgressionService:UnlockLore(player, entry.Id)
	end

	self:GetRemote():FireClient(player, {
		Action = "PlayLore",
		Entry = entry,
	})
end

function LoreCinematicService:Start()
	self:GetRemote()

	for _, instance in ipairs(CollectionService:GetTagged("LoreSavePoint")) do
		self:HookSavePoint(instance)
	end

	CollectionService:GetInstanceAddedSignal("LoreSavePoint"):Connect(function(instance)
		self:HookSavePoint(instance)
	end)

	self:ScanNamedSavePoints()

	workspace.DescendantAdded:Connect(function(instance)
		if string.match(instance.Name, "^SAVE_POINT_") then
			self:HookSavePoint(instance)
		end
	end)
end

return LoreCinematicService
