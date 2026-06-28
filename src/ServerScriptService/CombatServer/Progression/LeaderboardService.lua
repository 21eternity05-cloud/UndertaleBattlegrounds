local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LeaderboardService = {}
LeaderboardService.__index = LeaderboardService

local DEFAULT_DATA_STORE_NAME = "UTB_KillsLeaderboard"
local DEFAULT_STAT_NAME = "Kills"
local DEFAULT_MAX_PLAYERS = 10
local DEFAULT_RELOAD_DELAY = 60

function LeaderboardService.new(config, progressionService)
	local self = setmetatable({}, LeaderboardService)

	self.Config = config
	self.ProgressionService = progressionService
	self.LeaderboardModel = nil
	self.OrderedDataStore = nil
	self.Warned = {}
	self.Running = false

	return self
end

function LeaderboardService:WarnOnce(key, ...)
	if self.Warned[key] then
		return
	end

	self.Warned[key] = true
	warn(...)
end

function LeaderboardService:GetConfigValue(configFolder, name, defaultValue)
	local valueObject = configFolder and configFolder:FindFirstChild(name)

	if not valueObject then
		return defaultValue
	end

	if valueObject:IsA("StringValue") then
		return valueObject.Value ~= "" and valueObject.Value or defaultValue
	end

	if valueObject:IsA("BoolValue") then
		return valueObject.Value
	end

	if valueObject:IsA("IntValue") or valueObject:IsA("NumberValue") then
		return valueObject.Value
	end

	local attributeValue = valueObject:GetAttribute("Value")
	if attributeValue ~= nil then
		return attributeValue
	end

	return defaultValue
end

function LeaderboardService:ReadConfig(model)
	local configFolder = model and model:FindFirstChild("Config")

	local maxPlayers = tonumber(self:GetConfigValue(configFolder, "MaxPlayers", DEFAULT_MAX_PLAYERS)) or DEFAULT_MAX_PLAYERS
	local reloadDelay = tonumber(self:GetConfigValue(configFolder, "ReloadDelay", DEFAULT_RELOAD_DELAY)) or DEFAULT_RELOAD_DELAY

	return {
		DataStoreName = tostring(self:GetConfigValue(configFolder, "DataStoreName", DEFAULT_DATA_STORE_NAME)),
		Enabled = self:GetConfigValue(configFolder, "Enabled", true) ~= false,
		MaxPlayers = math.clamp(math.floor(maxPlayers), 1, 100),
		ReloadDelay = math.max(15, reloadDelay),
		StatName = tostring(self:GetConfigValue(configFolder, "StatName", DEFAULT_STAT_NAME)),
	}
end

function LeaderboardService:FindLeaderboardModel()
	local mapRoot = Workspace:FindFirstChild("BattlegroundsMap")
	if mapRoot then
		local model = mapRoot:FindFirstChild("Leaderboard", true)
		if model and model:IsA("Model") then
			return model
		end
	end

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant.Name == "Leaderboard" and descendant:IsA("Model") then
			return descendant
		end
	end

	return nil
end

function LeaderboardService:GetBoardParts(model)
	local board = model and model:FindFirstChild("Board", true)
	local surfaceGui = board and board:FindFirstChildWhichIsA("SurfaceGui", true)
	local scrollingFrame = surfaceGui and surfaceGui:FindFirstChild("ScrollingFrame", true)
	local template = scrollingFrame and scrollingFrame:FindFirstChild("Template")

	if not scrollingFrame or not template then
		return nil, nil
	end

	return scrollingFrame, template
end

function LeaderboardService:GetOrderedDataStore(dataStoreName)
	if self.OrderedDataStore and self.DataStoreName == dataStoreName then
		return self.OrderedDataStore
	end

	local success, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(dataStoreName)
	end)

	if not success then
		self:WarnOnce(
			"GetOrderedDataStore",
			"[LeaderboardService] Failed to get OrderedDataStore:",
			tostring(store)
		)
		return nil
	end

	self.DataStoreName = dataStoreName
	self.OrderedDataStore = store
	return store
end

function LeaderboardService:GetPlayerStatValue(player, statName)
	local leaderstats = player:FindFirstChild("leaderstats")
	local valueObject = leaderstats and leaderstats:FindFirstChild(statName)

	if valueObject and (valueObject:IsA("IntValue") or valueObject:IsA("NumberValue")) then
		return math.max(0, math.floor(valueObject.Value))
	end

	if self.ProgressionService and self.ProgressionService.GetProfile then
		local profile = self.ProgressionService:GetProfile(player)
		local value = profile and profile[statName]

		if typeof(value) == "number" then
			return math.max(0, math.floor(value))
		end
	end

	return nil
end

function LeaderboardService:SavePlayerStat(player, statName, store)
	if not player or not store then
		return
	end

	local value = self:GetPlayerStatValue(player, statName)
	if typeof(value) ~= "number" then
		return
	end

	local success, err = pcall(function()
		store:SetAsync(tostring(player.UserId), value)
	end)

	if not success then
		self:WarnOnce(
			"SetAsync_" .. tostring(player.UserId),
			"[LeaderboardService] Failed to save leaderboard stat for",
			player.Name,
			tostring(err)
		)
	end
end

function LeaderboardService:SaveCurrentPlayers(statName, store)
	for _, player in ipairs(Players:GetPlayers()) do
		self:SavePlayerStat(player, statName, store)
	end
end

function LeaderboardService:ClearRows(scrollingFrame, template)
	for _, child in ipairs(scrollingFrame:GetChildren()) do
		if child ~= template
			and not child:IsA("UIListLayout")
			and not child:IsA("UIPadding")
			and child:GetAttribute("LeaderboardRow") == true
		then
			child:Destroy()
		end
	end
end

function LeaderboardService:GetUsername(userId)
	local success, username = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)

	if success and typeof(username) == "string" and username ~= "" then
		return username
	end

	return tostring(userId)
end

function LeaderboardService:SetRowText(row, labelName, text)
	local label = row:FindFirstChild(labelName, true)

	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

function LeaderboardService:PopulateRows(scrollingFrame, template, entries)
	template.Visible = false
	self:ClearRows(scrollingFrame, template)

	for rank, entry in ipairs(entries) do
		local row = template:Clone()
		row.Name = "Row_" .. tostring(rank)
		row:SetAttribute("LeaderboardRow", true)
		row.LayoutOrder = rank
		row.Visible = true
		row.Parent = scrollingFrame

		self:SetRowText(row, "Rank", "#" .. tostring(rank))
		self:SetRowText(row, "Username", "@" .. self:GetUsername(entry.UserId))
		self:SetRowText(row, "Value", tostring(entry.Value))
	end
end

function LeaderboardService:LoadEntries(store, maxPlayers)
	local success, pagesOrError = pcall(function()
		return store:GetSortedAsync(false, maxPlayers)
	end)

	if not success then
		self:WarnOnce("GetSortedAsync", "[LeaderboardService] Failed to load leaderboard:", tostring(pagesOrError))
		return nil
	end

	local entries = {}
	local page = pagesOrError:GetCurrentPage()

	for _, item in ipairs(page) do
		local userId = tonumber(item.key)
		local value = tonumber(item.value)

		if userId and value then
			table.insert(entries, {
				UserId = math.floor(userId),
				Value = math.floor(value),
			})
		end
	end

	return entries
end

function LeaderboardService:Refresh()
	local model = self.LeaderboardModel
	if not model or not model.Parent then
		model = self:FindLeaderboardModel()
		self.LeaderboardModel = model
	end

	if not model then
		return
	end

	local boardConfig = self:ReadConfig(model)
	if boardConfig.Enabled ~= true then
		return
	end

	local scrollingFrame, template = self:GetBoardParts(model)
	if not scrollingFrame or not template then
		self:WarnOnce("MissingTemplate", "[LeaderboardService] Leaderboard model is missing SurfaceGui.ScrollingFrame.Template.")
		return
	end

	local store = self:GetOrderedDataStore(boardConfig.DataStoreName)
	if not store then
		return
	end

	self:SaveCurrentPlayers(boardConfig.StatName, store)

	local entries = self:LoadEntries(store, boardConfig.MaxPlayers)
	if entries then
		self:PopulateRows(scrollingFrame, template, entries)
	end
end

function LeaderboardService:Start()
	if self.Running then
		return
	end

	self.Running = true

	Players.PlayerRemoving:Connect(function(player)
		local model = self.LeaderboardModel or self:FindLeaderboardModel()
		local boardConfig = model and self:ReadConfig(model)

		if not boardConfig or boardConfig.Enabled ~= true then
			return
		end

		local store = self:GetOrderedDataStore(boardConfig.DataStoreName)
		if store then
			self:SavePlayerStat(player, boardConfig.StatName, store)
		end
	end)

	task.spawn(function()
		task.wait(3)

		while self.Running do
			self:Refresh()

			local model = self.LeaderboardModel
			local boardConfig = model and model.Parent and self:ReadConfig(model) or nil
			task.wait((boardConfig and boardConfig.ReloadDelay) or DEFAULT_RELOAD_DELAY)
		end
	end)
end

return LeaderboardService
