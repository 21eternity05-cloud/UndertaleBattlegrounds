local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LoreFragmentData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Interactables"):WaitForChild("LoreFragmentData"))

local INTERACTABLE_TAG = "Interactable"
local DEFAULT_DISTANCE = 12

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local interactableRemote = remotes:FindFirstChild("InteractableRemote")
if not interactableRemote then
	interactableRemote = Instance.new("RemoteEvent")
	interactableRemote.Name = "InteractableRemote"
	interactableRemote.Parent = remotes
end

local function getCharacterRoot(player)
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function getPromptPart(instance)
	if not instance then
		return nil
	end

	if instance:IsA("BasePart") then
		return instance
	end

	if not instance:IsA("Model") then
		return nil
	end

	local displayPart = instance:FindFirstChild("DisplayPart")
	if displayPart and displayPart:IsA("BasePart") then
		return displayPart
	end

	if instance.PrimaryPart then
		return instance.PrimaryPart
	end

	for _, child in ipairs(instance:GetChildren()) do
		if child:IsA("BasePart") then
			return child
		end
	end

	return nil
end

local function setAttributeIfMissing(instance, name, value)
	if instance:GetAttribute(name) == nil then
		instance:SetAttribute(name, value)
	end
end

local function configureLoreSaveStar(instance)
	setAttributeIfMissing(instance, "InteractableId", "HollowSnowdin_001")
	setAttributeIfMissing(instance, "InteractableType", "LoreFragment")
	setAttributeIfMissing(instance, "InteractDistance", DEFAULT_DISTANCE)
	setAttributeIfMissing(instance, "LookRequired", true)
	setAttributeIfMissing(instance, "LookDot", 0.82)
	setAttributeIfMissing(instance, "PromptText", "E - ...")
end

local function isInteractableContainer(instance)
	return instance and (instance:IsA("Model") or instance:IsA("BasePart"))
end

local function tagInteractable(instance)
	if not isInteractableContainer(instance) then
		return
	end

	if instance.Name == "Lore_SaveStar_001" then
		configureLoreSaveStar(instance)
	end

	if instance:GetAttribute("InteractableType") == nil then
		return
	end

	if not CollectionService:HasTag(instance, INTERACTABLE_TAG) then
		CollectionService:AddTag(instance, INTERACTABLE_TAG)
	end
end

local function getInteractablesFolder()
	local mapRoot = workspace:FindFirstChild("BattlegroundsMap")
	local hollowSnowdin = mapRoot and mapRoot:FindFirstChild("HollowSnowdin")

	return hollowSnowdin and hollowSnowdin:FindFirstChild("Interactables")
end

local function scanInteractablesFolder(folder)
	if not folder then
		return
	end

	for _, child in ipairs(folder:GetChildren()) do
		tagInteractable(child)
	end

	for _, descendant in ipairs(folder:GetDescendants()) do
		tagInteractable(descendant)
	end
end

local watchedFolders = {}

local function watchInteractablesFolder(folder)
	if not folder or watchedFolders[folder] then
		return
	end

	watchedFolders[folder] = true
	scanInteractablesFolder(folder)

	folder.DescendantAdded:Connect(function(descendant)
		task.defer(tagInteractable, descendant)
	end)
end

local function startMapWatcher()
	watchInteractablesFolder(getInteractablesFolder())

	workspace.DescendantAdded:Connect(function(instance)
		if instance.Name ~= "Interactables" then
			return
		end

		local parent = instance.Parent
		if not parent or parent.Name ~= "HollowSnowdin" then
			return
		end

		local mapRoot = parent.Parent
		if not mapRoot or mapRoot.Name ~= "BattlegroundsMap" then
			return
		end

		watchInteractablesFolder(instance)
	end)
end

local function sendDenied(player, reason)
	interactableRemote:FireClient(player, {
		Action = "InteractionDenied",
		Reason = reason,
	})
end

local function handleLoreFragment(player, interactable)
	local fragmentId = interactable:GetAttribute("InteractableId")
	if typeof(fragmentId) ~= "string" or fragmentId == "" then
		sendDenied(player, "MissingFragmentId")
		return
	end

	local fragment = LoreFragmentData[fragmentId]
	if typeof(fragment) ~= "table" then
		sendDenied(player, "MissingFragmentData")
		return
	end

	local progressionService = _G.UTBGProgressionService
	if progressionService and progressionService.UnlockLore then
		progressionService:UnlockLore(player, fragmentId)
	end

	interactableRemote:FireClient(player, {
		Action = "ShowLoreDialogue",
		FragmentId = fragmentId,
		Title = fragment.Title,
		Lines = fragment.Lines,
	})
end

local function handleInteract(player, interactable)
	if not Players:FindFirstChild(player.Name) then
		return
	end

	if typeof(interactable) ~= "Instance" or not interactable:IsDescendantOf(workspace) then
		sendDenied(player, "InvalidInteractable")
		return
	end

	if not CollectionService:HasTag(interactable, INTERACTABLE_TAG) then
		sendDenied(player, "NotTagged")
		return
	end

	local promptPart = getPromptPart(interactable)
	local root = getCharacterRoot(player)
	if not promptPart or not root then
		sendDenied(player, "MissingPart")
		return
	end

	local interactDistance = interactable:GetAttribute("InteractDistance")
	if typeof(interactDistance) ~= "number" then
		interactDistance = DEFAULT_DISTANCE
	end

	if (root.Position - promptPart.Position).Magnitude > interactDistance + 2 then
		sendDenied(player, "TooFar")
		return
	end

	local interactableType = interactable:GetAttribute("InteractableType")
	if interactableType == "LoreFragment" then
		handleLoreFragment(player, interactable)
	else
		sendDenied(player, "UnsupportedType")
	end
end

interactableRemote.OnServerEvent:Connect(function(player, action, interactable)
	if action == "Interact" then
		handleInteract(player, interactable)
	end
end)

startMapWatcher()
