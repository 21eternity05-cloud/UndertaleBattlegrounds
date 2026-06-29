local Debris = game:GetService("Debris")

local DebrisVFXService = {}
DebrisVFXService.__index = DebrisVFXService

local DEFAULT_GROUND_COLOR = Color3.fromRGB(115, 115, 115)
local DEFAULT_WALL_COLOR = Color3.fromRGB(230, 230, 235)

local function randomBetween(minValue, maxValue)
	return minValue + (math.random() * (maxValue - minValue))
end

local function randomVector3(minSize, maxSize)
	return Vector3.new(
		randomBetween(minSize.X, maxSize.X),
		randomBetween(minSize.Y, maxSize.Y),
		randomBetween(minSize.Z, maxSize.Z)
	)
end

local function getPosition(value)
	if typeof(value) == "CFrame" then
		return value.Position
	end

	if typeof(value) == "Vector3" then
		return value
	end

	return nil
end

local function getPlaneCFrame(position, normal, angle)
	local back = Vector3.zAxis

	if typeof(normal) == "Vector3" and normal.Magnitude > 0.05 then
		back = normal.Unit
	end

	local up = Vector3.yAxis
	if math.abs(back:Dot(up)) > 0.92 then
		up = Vector3.xAxis
	end

	local right = up:Cross(back)
	if right.Magnitude < 0.05 then
		right = Vector3.xAxis
	else
		right = right.Unit
	end

	up = back:Cross(right)
	if up.Magnitude < 0.05 then
		up = Vector3.yAxis
	else
		up = up.Unit
	end

	return CFrame.fromMatrix(position, right, up, back) * CFrame.Angles(0, 0, angle or 0)
end

function DebrisVFXService.new(config)
	local self = setmetatable({}, DebrisVFXService)

	self.Config = config or {}
	self.RuntimeFolderName = self.Config.DebrisVFXFolderName or "VFX"

	return self
end

function DebrisVFXService:GetRuntimeFolder()
	local folder = workspace:FindFirstChild(self.RuntimeFolderName)

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = self.RuntimeFolderName
		folder.Parent = workspace
	end

	return folder
end

function DebrisVFXService:GetRaycastParams(exclude)
	local excludeList = {}
	local runtimeFolder = self:GetRuntimeFolder()

	if runtimeFolder then
		table.insert(excludeList, runtimeFolder)
	end

	if typeof(exclude) == "table" then
		for _, instance in ipairs(exclude) do
			if instance then
				table.insert(excludeList, instance)
			end
		end
	elseif exclude then
		table.insert(excludeList, exclude)
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excludeList

	return params
end

function DebrisVFXService:RaycastGround(position, distance, exclude)
	if typeof(position) ~= "Vector3" then
		return nil
	end

	return workspace:Raycast(
		position + Vector3.new(0, 1.5, 0),
		Vector3.new(0, -(distance or 14), 0),
		self:GetRaycastParams(exclude)
	)
end

function DebrisVFXService:CreateDebrisPart(name, size, cframe, color, material, lifetime)
	local part = Instance.new("Part")
	part.Name = name or "BlockyDebris"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = false
	part.Material = material or Enum.Material.Concrete
	part.Color = color or DEFAULT_GROUND_COLOR
	part.Size = size
	part.CFrame = cframe
	part.Parent = self:GetRuntimeFolder()

	Debris:AddItem(part, lifetime or 1)

	return part
end

function DebrisVFXService:SpawnGroundRing(positionOrCFrame, options)
	options = options or {}

	local origin = getPosition(positionOrCFrame)
	if not origin then
		return
	end

	local exclude = options.Exclude
	local rayResult = self:RaycastGround(origin, options.RaycastDistance or 18, exclude)
	local surfacePosition = rayResult and rayResult.Position or origin
	local surfaceColor = options.Color or (rayResult and rayResult.Instance and rayResult.Instance.Color) or DEFAULT_GROUND_COLOR
	local surfaceMaterial = options.Material or (rayResult and rayResult.Instance and rayResult.Instance.Material) or Enum.Material.Concrete

	local radius = options.Radius or 7
	local count = math.clamp(options.Count or 14, 1, 36)
	local minSize = options.MinSize or Vector3.new(0.8, 0.35, 0.8)
	local maxSize = options.MaxSize or Vector3.new(2.2, 0.7, 1.6)
	local lifetime = options.Lifetime or 1.25
	local upTilt = math.rad(options.UpTiltDegrees or 20)

	for index = 1, count do
		local angle = ((index - 1) / count) * math.pi * 2
		angle += math.rad(randomBetween(-9, 9))

		local ringRadius = radius * randomBetween(0.72, 1.08)
		local offset = Vector3.new(math.cos(angle) * ringRadius, 0, math.sin(angle) * ringRadius)
		local position = surfacePosition + offset + Vector3.new(0, 0.08, 0)
		local yaw = angle + math.rad(randomBetween(-18, 18))
		local outwardTilt = CFrame.Angles(upTilt * randomBetween(0.6, 1.25), 0, math.rad(randomBetween(-8, 8)))
		local cframe = CFrame.new(position) * CFrame.Angles(0, yaw, 0) * outwardTilt

		self:CreateDebrisPart(
			"GroundRingDebris",
			randomVector3(minSize, maxSize),
			cframe,
			surfaceColor,
			surfaceMaterial,
			lifetime * randomBetween(0.85, 1.15)
		)
	end
end

function DebrisVFXService:SpawnWallImpact(positionOrCFrame, normal, options)
	options = options or {}

	local origin = getPosition(positionOrCFrame)
	if not origin then
		return
	end

	local wallNormal = typeof(normal) == "Vector3" and normal.Magnitude > 0.05 and normal.Unit or Vector3.zAxis
	local color = options.Color or DEFAULT_WALL_COLOR
	local material = options.Material or Enum.Material.Neon
	local lifetime = options.Lifetime or 0.75
	local position = origin + wallNormal * 0.045

	local crackCount = math.clamp(options.CrackCount or 7, 3, 14)
	for index = 1, crackCount do
		local angle = ((index - 1) / crackCount) * math.pi * 2 + math.rad(randomBetween(-18, 18))
		local length = randomBetween(1.1, 3.2)
		local thickness = randomBetween(0.045, 0.09)
		local offsetDistance = randomBetween(0.35, 1.25)
		local localOffset = CFrame.Angles(0, 0, angle):VectorToWorldSpace(Vector3.new(offsetDistance, 0, 0))
		local cframe = getPlaneCFrame(position, wallNormal, angle) * CFrame.new(localOffset.X, localOffset.Y, 0)

		self:CreateDebrisPart(
			"WallCrackDebris",
			Vector3.new(length, thickness, 0.035),
			cframe,
			color,
			material,
			lifetime
		)
	end

	local chunkCount = math.clamp(options.ChunkCount or 6, 0, 16)
	for _ = 1, chunkCount do
		local tangentAngle = math.rad(randomBetween(0, 360))
		local cframe = getPlaneCFrame(position + wallNormal * randomBetween(0.04, 0.16), wallNormal, tangentAngle)
			* CFrame.new(randomBetween(-2.2, 2.2), randomBetween(-1.8, 1.8), 0)
			* CFrame.Angles(math.rad(randomBetween(-25, 25)), math.rad(randomBetween(-25, 25)), math.rad(randomBetween(-25, 25)))

		self:CreateDebrisPart(
			"WallChunkDebris",
			randomVector3(
				options.MinChunkSize or Vector3.new(0.25, 0.18, 0.08),
				options.MaxChunkSize or Vector3.new(0.75, 0.45, 0.2)
			),
			cframe,
			color,
			Enum.Material.Concrete,
			lifetime * randomBetween(0.8, 1.15)
		)
	end
end

function DebrisVFXService:GetTrailWorldPositions(character, attachmentsOrOffsets)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return {}
	end

	local points = {}
	local sources = attachmentsOrOffsets or {
		Vector3.new(-2.2, -2.6, 1.5),
		Vector3.new(2.2, -2.6, 1.5),
	}

	for _, source in ipairs(sources) do
		if typeof(source) == "Instance" and source:IsA("Attachment") then
			table.insert(points, source.WorldPosition)
		elseif typeof(source) == "Vector3" then
			table.insert(points, root.CFrame:PointToWorldSpace(source))
		end
	end

	return points
end

function DebrisVFXService:SpawnTrailChunk(position, options, exclude)
	local rayResult = self:RaycastGround(position, options.RaycastDistance or 8, exclude)
	if not rayResult then
		return
	end

	local basePosition = rayResult.Position + Vector3.new(
		randomBetween(-(options.ScatterRadius or 0.7), options.ScatterRadius or 0.7),
		0.06,
		randomBetween(-(options.ScatterRadius or 0.7), options.ScatterRadius or 0.7)
	)

	local color = options.Color
	if color == nil and options.UseGroundColor ~= false and rayResult.Instance then
		color = rayResult.Instance.Color
	end

	local material = options.Material
	if material == nil and options.UseGroundColor ~= false and rayResult.Instance then
		material = rayResult.Instance.Material
	end

	self:CreateDebrisPart(
		"DashTrailDebris",
		randomVector3(
			options.MinSize or Vector3.new(0.25, 0.15, 0.25),
			options.MaxSize or Vector3.new(0.75, 0.35, 0.75)
		),
		CFrame.new(basePosition)
			* CFrame.Angles(
				math.rad(randomBetween(-12, 12)),
				math.rad(randomBetween(0, 360)),
				math.rad(randomBetween(-12, 12))
			),
		color or DEFAULT_GROUND_COLOR,
		material or Enum.Material.Concrete,
		options.Lifetime or 0.8
	)
end

function DebrisVFXService:StartDebrisTrail(character, attachmentsOrOffsets, options)
	options = options or {}

	local handle = {
		Active = true,
		Connections = {},
	}

	local function stop()
		self:StopDebrisTrail(handle)
	end

	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		table.insert(handle.Connections, humanoid.Died:Connect(stop))
	end

	if character then
		table.insert(handle.Connections, character.AncestryChanged:Connect(function(_, parent)
			if not parent then
				stop()
			end
		end))
	end

	task.spawn(function()
		local tickRate = math.max(options.TickRate or 0.05, 0.03)
		local spawnPerSide = math.clamp(options.SpawnPerSide or 1, 1, 4)
		local exclude = options.Exclude or character

		while handle.Active do
			if not character or not character.Parent then
				break
			end

			local currentHumanoid = character:FindFirstChildOfClass("Humanoid")
			if not currentHumanoid or currentHumanoid.Health <= 0 then
				break
			end

			for _, position in ipairs(self:GetTrailWorldPositions(character, attachmentsOrOffsets)) do
				for _ = 1, spawnPerSide do
					self:SpawnTrailChunk(position, options, exclude)
				end
			end

			task.wait(tickRate)
		end

		stop()
	end)

	return handle
end

function DebrisVFXService:StopDebrisTrail(handle)
	if not handle or handle.Active == false then
		return
	end

	handle.Active = false

	for _, connection in ipairs(handle.Connections or {}) do
		connection:Disconnect()
	end

	table.clear(handle.Connections or {})
end

return DebrisVFXService
