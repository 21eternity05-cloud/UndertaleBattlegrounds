local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local DummyFactory = require(ServerScriptService:WaitForChild("TestTools"):WaitForChild("DummyFactory"))

local ArenaRespawnDummyService = {}
ArenaRespawnDummyService.__index = ArenaRespawnDummyService

local ENABLE_ARENA_RESPAWN_DUMMIES = true
local ARENA_DUMMY_RESPAWN_DELAY = 4

local SLOT_CONFIGS = {
	{ Slot = 1, Type = "Basic", Name = "ArenaBasicDummy" },
	{ Slot = 2, Type = "Blocking", Name = "ArenaBlockingDummy" },
	{ Slot = 3, Type = "Moving", Name = "ArenaMovingDummy" },
	{ Slot = 4, Type = "Combo", Name = "ArenaComboDummy" },
	{ Slot = 5, Type = "AirCombo", Name = "ArenaAirComboDummy" },
	{ Slot = 6, Type = "SOULBURST", Name = "ArenaSOULBURSTDummy" },
	{ Slot = 7, Type = "SUPER", Name = "ArenaSUPERDummy" },
	{ Slot = 8, Type = "TRUE", Name = "ArenaTRUEDummy" },
}

local MARKER_PATHS = {
	{ "BattlegroundsMap", "HollowSnowdin", "DummySpawns" },
	{ "BattlegroundsMap", "HollowSnowdin", "ArenaDummySpawns" },
	{ "ArenaDummySpawns" },
	{ "DummySpawns" },
}

function ArenaRespawnDummyService.new(config)
	return setmetatable({
		Config = config,
		Factory = DummyFactory.new(),
		Folder = nil,
		Connections = {},
		Respawning = {},
		Started = false,
	}, ArenaRespawnDummyService)
end

function ArenaRespawnDummyService:GetFolder()
	local folder = Workspace:FindFirstChild("ArenaRespawnDummies")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ArenaRespawnDummies"
		folder.Parent = Workspace
	end

	self.Folder = folder
	return folder
end

function ArenaRespawnDummyService:GetPath(root, path)
	local current = root
	for _, name in ipairs(path) do
		current = current and current:FindFirstChild(name)
		if not current then
			return nil
		end
	end
	return current
end

function ArenaRespawnDummyService:GetMarkerCFrame(instance)
	if instance:IsA("Attachment") then
		return instance.WorldCFrame
	end
	if instance:IsA("BasePart") then
		return instance.CFrame
	end
	return nil
end

function ArenaRespawnDummyService:GetMarkerCFrames()
	for _, path in ipairs(MARKER_PATHS) do
		local folder = self:GetPath(Workspace, path)
		if folder then
			local markers = {}
			for _, child in ipairs(folder:GetChildren()) do
				local cframe = self:GetMarkerCFrame(child)
				if cframe then
					table.insert(markers, {
						Name = child.Name,
						CFrame = cframe,
					})
				end
			end

			table.sort(markers, function(a, b)
				return a.Name < b.Name
			end)

			if #markers >= #SLOT_CONFIGS then
				local cframes = {}
				for index = 1, #SLOT_CONFIGS do
					cframes[index] = markers[index].CFrame
				end
				return cframes, true
			end
		end
	end

	return nil, false
end

function ArenaRespawnDummyService:GetFallbackCenter()
	local arenaSpawns = Workspace:FindFirstChild("ArenaSpawns")
	local total = Vector3.zero
	local count = 0

	if arenaSpawns then
		for _, child in ipairs(arenaSpawns:GetChildren()) do
			local cframe = self:GetMarkerCFrame(child)
			if cframe then
				total += cframe.Position
				count += 1
			end
		end
	end

	if count > 0 then
		return total / count
	end

	return Vector3.new(0, 4, 0)
end

function ArenaRespawnDummyService:GetFallbackCFrames()
	local center = self:GetFallbackCenter()
	local radius = self.Config.ArenaRespawnDummyRadius or 38
	local cframes = {}

	for index = 1, #SLOT_CONFIGS do
		local angle = (math.pi * 2) * ((index - 1) / #SLOT_CONFIGS)
		local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local position = center + offset + Vector3.new(0, 3, 0)
		cframes[index] = CFrame.lookAt(position, center)
	end

	warn("[ArenaRespawnDummyService] Missing 8 arena dummy markers; using fallback circle.")
	return cframes
end

function ArenaRespawnDummyService:GetSpawnCFrames()
	local cframes = self:GetMarkerCFrames()
	if cframes then
		return cframes
	end

	return self:GetFallbackCFrames()
end

function ArenaRespawnDummyService:DisconnectSlot(slotId)
	local connection = self.Connections[slotId]
	if connection then
		connection:Disconnect()
		self.Connections[slotId] = nil
	end
end

function ArenaRespawnDummyService:SpawnSlot(slotConfig, cframe)
	local folder = self:GetFolder()

	self:DisconnectSlot(slotConfig.Slot)

	local spawned, spawnError = self.Factory:SpawnConfiguredDummy(slotConfig.Type, cframe, {
		Parent = folder,
		Name = slotConfig.Name,
		DebugDummy = false,
		Tags = {
			"ArenaRespawnDummy",
			"TargetableCharacter",
		},
		Attributes = {
			ArenaRespawnDummy = true,
			ArenaDummy = true,
			RespawnDummy = true,
			DebugDummy = false,
			TargetableCharacter = true,
			ArenaDummySlot = slotConfig.Slot,
			DummyType = slotConfig.Type,
		},
	})

	if not spawned then
		warn("[ArenaRespawnDummyService] Failed to spawn", slotConfig.Name, spawnError)
		return nil
	end

	local dummy = spawned.Dummy
	local humanoid = dummy and dummy:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return dummy
	end

	self.Connections[slotConfig.Slot] = humanoid.Died:Connect(function()
		self:QueueRespawn(slotConfig, cframe, dummy)
	end)

	return dummy
end

function ArenaRespawnDummyService:QueueRespawn(slotConfig, cframe, oldDummy)
	if self.Respawning[slotConfig.Slot] == true then
		return
	end

	self.Respawning[slotConfig.Slot] = true
	self:DisconnectSlot(slotConfig.Slot)

	task.delay(ARENA_DUMMY_RESPAWN_DELAY, function()
		self.Respawning[slotConfig.Slot] = nil

		if oldDummy and oldDummy.Parent then
			self.Factory:GetDummyController():Cleanup(oldDummy)
			oldDummy:Destroy()
		end

		local folder = self:GetFolder()
		if not folder or not folder.Parent then
			return
		end

		self:SpawnSlot(slotConfig, cframe)
	end)
end

function ArenaRespawnDummyService:ClearExisting()
	local folder = self:GetFolder()
	for _, child in ipairs(folder:GetChildren()) do
		if child:GetAttribute("ArenaRespawnDummy") == true
			or CollectionService:HasTag(child, "ArenaRespawnDummy")
		then
			self.Factory:GetDummyController():Cleanup(child)
			child:Destroy()
		end
	end
end

function ArenaRespawnDummyService:Start()
	if self.Started then
		return
	end
	self.Started = true

	if ENABLE_ARENA_RESPAWN_DUMMIES ~= true then
		return
	end

	self:ClearExisting()

	local cframes = self:GetSpawnCFrames()
	for index, slotConfig in ipairs(SLOT_CONFIGS) do
		self:SpawnSlot(slotConfig, cframes[index] or CFrame.new(0, 4, 0))
	end
end

return ArenaRespawnDummyService
