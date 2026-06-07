local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local SpawnService = {}
SpawnService.__index = SpawnService

function SpawnService.new(config, stateService, combatStatusService)
	local self = setmetatable({}, SpawnService)

	self.Config = config
	self.StateService = stateService
	self.CombatStatusService = combatStatusService

	return self
end

function SpawnService:GetSpawnFolder()
	return workspace:FindFirstChild("ArenaSpawns")
end

function SpawnService:GetSpawnCFrame(spawnInstance)
	if not spawnInstance then
		return nil
	end

	if spawnInstance:IsA("Attachment") then
		return spawnInstance.WorldCFrame
	end

	if spawnInstance:IsA("BasePart") then
		return spawnInstance.CFrame
	end

	return nil
end

function SpawnService:GetSpawnPoints()
	local folder = self:GetSpawnFolder()
	if not folder then
		return {}
	end

	local spawns = {}

	for _, child in ipairs(folder:GetChildren()) do
		local cframe = self:GetSpawnCFrame(child)

		if cframe then
			table.insert(spawns, {
				Instance = child,
				CFrame = cframe,
			})
		end
	end

	table.sort(spawns, function(a, b)
		return a.Instance.Name < b.Instance.Name
	end)

	return spawns
end

function SpawnService:GetEnemyRoots(player)
	local roots = {}

	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player then
			local character = otherPlayer.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")

			if humanoid and humanoid.Health > 0 and root then
				table.insert(roots, root)
			end
		end
	end

	return roots
end

function SpawnService:GetClosestEnemyDistance(position, enemyRoots)
	local closest = math.huge

	for _, root in ipairs(enemyRoots or {}) do
		local distance = (root.Position - position).Magnitude

		if distance < closest then
			closest = distance
		end
	end

	return closest
end

function SpawnService:ChooseSpawn(player)
	local spawns = self:GetSpawnPoints()

	if #spawns == 0 then
		warn("[SpawnService] Missing or empty workspace.ArenaSpawns")
		return nil
	end

	local enemyRoots = self:GetEnemyRoots(player)
	local avoidRadius = self.Config.SpawnEnemyAvoidRadius or 25
	local safeSpawns = {}
	local farthestSpawn = nil
	local farthestDistance = -math.huge

	for _, spawnInfo in ipairs(spawns) do
		local distance = self:GetClosestEnemyDistance(spawnInfo.CFrame.Position, enemyRoots)

		if distance >= avoidRadius then
			table.insert(safeSpawns, spawnInfo)
		end

		if distance > farthestDistance then
			farthestDistance = distance
			farthestSpawn = spawnInfo
		end
	end

	if #safeSpawns > 0 then
		return safeSpawns[math.random(1, #safeSpawns)]
	end

	return farthestSpawn or spawns[math.random(1, #spawns)]
end

function SpawnService:ClearSpawnHighlight(character)
	local highlight = character and character:FindFirstChild("SpawnProtectionHighlight")

	if highlight then
		highlight:Destroy()
	end
end

function SpawnService:PlaySpawnHighlight(character, duration)
	if not character or not character.Parent then
		return
	end

	self:ClearSpawnHighlight(character)

	local highlight = Instance.new("Highlight")
	highlight.Name = "SpawnProtectionHighlight"
	highlight.FillColor = Color3.fromRGB(0, 0, 0)
	highlight.OutlineColor = Color3.fromRGB(0, 0, 0)
	highlight.FillTransparency = 0
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = character

	TweenService:Create(
		highlight,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			FillColor = Color3.fromRGB(255, 255, 255),
			OutlineColor = Color3.fromRGB(255, 255, 255),
			FillTransparency = 1,
			OutlineTransparency = 1,
		}
	):Play()

	task.delay(duration, function()
		if highlight and highlight.Parent then
			highlight:Destroy()
		end
	end)
end

function SpawnService:ClearSpawnProtection(character, reason)
	if not character or not character.Parent then
		return
	end

	local token = character:GetAttribute("SpawnIFrameToken")

	character:SetAttribute("SpawnProtected", false)
	character:SetAttribute("SpawnIFrameUntil", 0)
	character:SetAttribute("SpawnIFrameToken", token)

	if character:GetAttribute("IFrameActive") == true
		and character:GetAttribute("UsingMove") ~= true
		and character:GetAttribute("SoulBursting") ~= true
		and character:GetAttribute("CurrentMoveId") == nil
	then
		character:SetAttribute("IFrameActive", false)
	end

	self:ClearSpawnHighlight(character)

	if reason and self.Config.DebugEnabled == true then
		print("[SpawnService] Cleared spawn protection:", character.Name, reason)
	end
end

function SpawnService:ApplySpawnProtection(character, duration)
	if not character or not character.Parent then
		return
	end

	duration = duration or self.Config.SpawnIFrameDuration or 3

	local token = (character:GetAttribute("SpawnIFrameToken") or 0) + 1
	local expiresAt = os.clock() + duration

	character:SetAttribute("SpawnIFrameToken", token)
	character:SetAttribute("SpawnIFrameUntil", expiresAt)
	character:SetAttribute("SpawnProtected", true)
	character:SetAttribute("IFrameActive", true)

	self:PlaySpawnHighlight(character, duration)

	task.delay(duration, function()
		if not character or not character.Parent then
			return
		end
		if character:GetAttribute("SpawnIFrameToken") ~= token then
			return
		end

		character:SetAttribute("SpawnProtected", false)
		character:SetAttribute("SpawnIFrameUntil", 0)

		if character:GetAttribute("UsingMove") ~= true
			and character:GetAttribute("SoulBursting") ~= true
			and character:GetAttribute("CurrentMoveId") == nil
		then
			character:SetAttribute("IFrameActive", false)
		end
	end)
end

function SpawnService:TeleportToSpawn(player, character)
	if not character or not character.Parent then
		return false
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end

	local spawnInfo = self:ChooseSpawn(player)
	if not spawnInfo then
		return false
	end

	local yOffset = self.Config.SpawnYOffset or 3
	character:PivotTo(spawnInfo.CFrame + Vector3.new(0, yOffset, 0))

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero

	return true
end

function SpawnService:HandleCharacterSpawn(player, character)
	if not player or not character then
		return
	end

	character:WaitForChild("Humanoid", 5)
	character:WaitForChild("HumanoidRootPart", 5)

	task.wait(0.35)

	if not character or not character.Parent then
		return
	end

	self:TeleportToSpawn(player, character)
	self:ApplySpawnProtection(character, self.Config.SpawnIFrameDuration or 3)
end

function SpawnService:Start()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			self:HandleCharacterSpawn(player, character)
		end)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			task.spawn(function()
				self:HandleCharacterSpawn(player, player.Character)
			end)
		end

		player.CharacterAdded:Connect(function(character)
			self:HandleCharacterSpawn(player, character)
		end)
	end
end

return SpawnService
